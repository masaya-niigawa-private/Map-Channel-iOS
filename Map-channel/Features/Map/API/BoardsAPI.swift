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
public final class BoardsAPI: BoardsService {
    private let api: APIClient
    private let tokenStore: TokenStore
    
    /// - Parameter baseURL: 例）https://example.com/api/v1
    public init(baseURL: URL, session: URLSession = .shared, tokenStore: TokenStore = .shared) {
        self.api = APIClient(baseURL: baseURL, session: session)
        self.tokenStore = tokenStore
    }
    
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
        // sort=favorite は通常 認証必須：トークンがあれば自動付与
        let needsAuth = (sort == .favorite)
        return try await api.get(
            "boards",
            query: query,
            bearerToken: needsAuth ? await tokenStore.bearerToken : nil,
            as: PagedResponse<BoardDTO>.self
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
            case .http(let s, let body):
                return "サーバーエラー（\(s)）\(body.map { ": \($0)" } ?? "")"
            case .decoding(let e): return "レスポンス解析に失敗: \(e.localizedDescription)"
            case .transport(let e): return "通信エラー: \(e.localizedDescription)"
            }
        }
    }
    
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    
    public init(baseURL: URL, session: URLSession) {
        self.baseURL = baseURL
        self.session = session
        let d = JSONDecoder()
        // ★ BoardDTOは snake_case プロパティのため、変換は使わない（デフォルトのまま）
        // d.keyDecodingStrategy = .useDefaultKeys
        self.decoder = d
    }
    
    /// GET /{path}?query...
    public func get<T: Decodable>(
        _ path: String,
        query: [String: Any?] = [:],
        bearerToken: String? = nil,
        as: T.Type
    ) async throws -> T {
        guard var comp = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
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
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(underlying: error)
            }
        } catch {
            throw APIError.transport(underlying: error)
        }
    }
}

// MARK: - トークン保管（任意）
// ログイン成功時に `await TokenStore.shared.setBearerToken("...")` を呼んでください。
public actor TokenStore {
    public static let shared = TokenStore()
    private var _bearerToken: String = ""
    public init() {}
    
    public var bearerToken: String { _bearerToken }
    public func setBearerToken(_ token: String) { _bearerToken = token }
    public func clear() { _bearerToken = "" }
}

