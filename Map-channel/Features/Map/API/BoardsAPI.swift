//
//  BoardsAPI.swift
//  MAPCH - Keiziban API (URLSession)
//

import Foundation

// MARK: - 公開 Service プロトコル
public protocol BoardsService {
    func fetchBoards(
        sort: BoardSort,
        categoryId: Int?,
        page: Int,
        perPage: Int
    ) async throws -> PagedResponse<BoardDTO>
}

// MARK: - 具象実装
public final class BoardsAPI: BoardsService, BoardsCategoriesService, BoardsCreateService {
    private let api: APIClient
    private let tokenStore: TokenStore
    
    /// 例）baseURL = https://map-ch.com/api/v1
    public init(baseURL: URL, session: URLSession = .shared, tokenStore: TokenStore = .shared) {
        self.api = APIClient(baseURL: baseURL, session: session)
        self.tokenStore = tokenStore
    }
    
    // 一覧取得
    public func fetchBoards(
        sort: BoardSort,
        categoryId: Int?,
        page: Int,
        perPage: Int
    ) async throws -> PagedResponse<BoardDTO> {
        let query: [String: Any?] = [
            "sort": sort.rawValue,
            "category_id": categoryId,
            "page": page,
            "per_page": perPage
        ]
        let needsAuth = (sort == .favorite)
        return try await api.get(
            "boards",
            query: query,
            bearerToken: needsAuth ? await tokenStore.bearerToken : nil,
            as: PagedResponse<BoardDTO>.self
        )
    }
    
    // カテゴリ取得（ラップ/非ラップ両対応）
    public func fetchCategories() async throws -> [BoardDTO.Category] {
        struct Wrap<T: Decodable>: Decodable { let data: T }
        let candidates = ["boards/categories", "board-categories", "categories"]
        for path in candidates {
            if let arr: [BoardDTO.Category] = try? await api.get(path, as: [BoardDTO.Category].self) {
                return arr
            }
            if let wrapped: Wrap<[BoardDTO.Category]> = try? await api.get(path, as: Wrap<[BoardDTO.Category]>.self) {
                return wrapped.data
            }
        }
        throw APIClient.APIError.http(status: 404, body: "categories endpoint not found")
    }
    
    // 新規投稿（POST /boards, multipart/form-data）
    // createBoard 内の先頭でトークンを取得し、未設定なら早期に分かりやすくエラー
    public func createBoard(
        categoryId: Int,
        description: String,
        linkURL: String?,
        locationName: String?,
        locationLat: Double?,
        locationLng: Double?,
        photo: BoardPhoto?
    ) async throws -> BoardDTO {
        
        // ★追加: 未ログイン防止（サーバ500の回避・切り分け）
        let token = await tokenStore.bearerToken
        if token.isEmpty {
            throw NSError(domain: "BoardsAPI", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "ログインが必要です（トークン未設定）。"])
        }
        
        var fields: [String: String] = [
            "category_id": String(categoryId),
            "description": description
        ]
        if let linkURL, !linkURL.isEmpty { fields["link_url"] = linkURL }
        if let locationName, !locationName.isEmpty { fields["location_name"] = locationName }
        if let locationLat { fields["location_lat"] = String(locationLat) }
        if let locationLng { fields["location_lng"] = String(locationLng) }
        
        let files: [APIClient.FilePart] = {
            guard let p = photo else { return [] }
            return [APIClient.FilePart(name: "photo", filename: p.filename, mimeType: p.mimeType, data: p.data)]
        }()
        
        // 以降はそのまま
        return try await api.postMultipart(
            "boards",
            fields: fields,
            files: files,
            bearerToken: token,
            as: BoardDTO.self
        )
    }
    
}

// MARK: - 軽量APIクライアント
public struct APIClient {
    public enum APIError: LocalizedError {
        case invalidURL
        case http(status: Int, body: String?)
        case decoding(underlying: Error)
        case transport(underlying: Error)
        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "不正なURLです。"
            case .http(let s, let body): return "サーバーエラー（\(s)）\(body.map { ": \($0)" } ?? "")"
            case .decoding(let e): return "レスポンス解析に失敗: \(e.localizedDescription)"
            case .transport(let e): return "通信エラー: \(e.localizedDescription)"
            }
        }
    }
    
    public struct FilePart {
        public let name: String
        public let filename: String
        public let mimeType: String
        public let data: Data
        public init(name: String, filename: String, mimeType: String, data: Data) {
            self.name = name; self.filename = filename; self.mimeType = mimeType; self.data = data
        }
    }
    
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    
    public init(baseURL: URL, session: URLSession) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
    }
    
    // GET /{path}?query...
    public func get<T: Decodable>(
        _ path: String,
        query: [String: Any?] = [:],
        bearerToken: String? = nil,
        as: T.Type
    ) async throws -> T {
        // GET は元から安全な作り
        guard var comp = URLComponents(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
                                       resolvingAgainstBaseURL: false)
        else { throw APIError.invalidURL }
        if !query.isEmpty {
            comp.queryItems = query.compactMap { (k, v) in
                guard let v else { return nil }
                return URLQueryItem(name: k, value: String(describing: v))
            }
        }
        guard let url = comp.url else { throw APIError.invalidURL }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = bearerToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw APIError.transport(underlying: URLError(.badServerResponse)) }
            guard (200..<300).contains(http.statusCode) else {
                let body = String(data: data, encoding: .utf8)
                throw APIError.http(status: http.statusCode, body: body)
            }
            do { return try decoder.decode(T.self, from: data) }
            catch { throw APIError.decoding(underlying: error) }
        } catch { throw APIError.transport(underlying: error) }
    }
    
    // POST multipart/form-data /{path}
    public func postMultipart<T: Decodable>(
        _ path: String,
        fields: [String: String],
        files: [FilePart],
        bearerToken: String? = nil,
        as: T.Type
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        for (k, v) in fields {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n")
            body.appendString("\(v)\r\n")
        }
        for file in files {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n")
            body.appendString("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            body.appendString("\r\n")
        }
        body.appendString("--\(boundary)--\r\n")
        
        // ★ 修正点：相対URL解決をやめ、GETと同じく appendingPathComponent を使用
        let clean = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = baseURL.appendingPathComponent(clean)
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        if let token = bearerToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw APIError.transport(underlying: URLError(.badServerResponse)) }
            guard (200..<300).contains(http.statusCode) else {
                let bodyStr = String(data: data, encoding: .utf8)
                throw APIError.http(status: http.statusCode, body: bodyStr)
            }
            do { return try decoder.decode(T.self, from: data) }
            catch { throw APIError.decoding(underlying: error) }
        } catch { throw APIError.transport(underlying: error) }
    }
}

// MARK: - ユーティリティ
private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}

// MARK: - トークン保管
public actor TokenStore {
    public static let shared = TokenStore()
    private var _bearerToken: String = ""
    public init() {}
    public var bearerToken: String { _bearerToken }
    public func setBearerToken(_ token: String) { _bearerToken = token }
    public func clear() { _bearerToken = "" }
}

