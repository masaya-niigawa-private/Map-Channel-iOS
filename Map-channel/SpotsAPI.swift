// SpotsAPI.swift
import Foundation

// 地図の可視範囲を API パラメータに渡すための構造体
struct MapBounds {
    let swlat: Double
    let swlng: Double
    let nelat: Double
    let nelng: Double
}

enum APIError: Error {
    case badURL
    case server(Error)
    case invalidResponse
    case decoding(Error)
}

struct SpotsAPI {
    // ルート URL
    static let baseURL = URL(string: "https://map-ch.com")!
    
    // 追加：相対パス("photo/…")を解決するS3ベースURL
    static let imageBaseURL = URL(string: "https://mapappp.s3.ap-northeast-3.amazonaws.com")!
    
    // 可視範囲のスポット取得
    static func fetchSpots(bounds: MapBounds, limit: Int = 500) async throws -> [Spot] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/spots/in-bounds"),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            .init(name: "swlat", value: String(bounds.swlat)),
            .init(name: "swlng", value: String(bounds.swlng)),
            .init(name: "nelat", value: String(bounds.nelat)),
            .init(name: "nelng", value: String(bounds.nelng)),
            .init(name: "limit", value: String(limit))
        ]
        guard let url = comps?.url else { throw APIError.badURL }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw APIError.invalidResponse
            }
            do { return try JSONDecoder().decode([Spot].self, from: data) }
            catch { throw APIError.decoding(error) }
        } catch {
            throw APIError.server(error)
        }
    }
    
    // 投稿(コメント)作成
    private struct CreatePostPayload: Encodable {
        let spot_id: Int
        let author: String?
        let content: String
    }
    static func submitPost(spotID: Int, author: String?, content: String) async throws {
        let url = baseURL.appendingPathComponent("api/posts/store")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(CreatePostPayload(spot_id: spotID, author: author, content: content))
        
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw APIError.invalidResponse
            }
        } catch {
            throw APIError.server(error)
        }
    }
    
    // ====== posts の取得（強化版） ======
    struct APIPost: Decodable {
        let id: Int?
        let spot_id: Int?
        let author: String?
        let user_name: String?
        
        // 本文のキー揺れに対応
        let content: String?
        let comment: String?
        let text: String?
        let body: String?
        let message: String?
        
        let rating: Int?
        
        // 日付キーの揺れに対応
        let createdAt: String?
        let created_at: String?
        let date: String?
        let time: String?
    }
    
    private struct PostListEnvelope: Decodable { let posts: [APIPost]? }
    private struct DataEnvelope: Decodable { let data: [APIPost]? }
    private struct ItemsEnvelope: Decodable { let items: [APIPost]? }
    private struct SpotDetailsEnvelope: Decodable {
        struct SpotNode: Decodable { let posts: [APIPost]? }
        let spot: SpotNode?
    }
    private struct SpotEnvelope: Decodable { let posts: [APIPost]? }
    
    static func fetchPosts(spotID: Int) async throws -> [APIPost] {
        // 1) まず GET の候補（一般的パターン + AdminController::getPosts 対応）
        var getCandidates: [URL] = []
        if let u = URL(string: "api/posts/by-spot/\(spotID)", relativeTo: baseURL) { getCandidates.append(u) }
        if var c = URLComponents(url: baseURL.appendingPathComponent("api/posts"), resolvingAgainstBaseURL: false) {
            c.queryItems = [.init(name: "spot_id", value: String(spotID))]
            if let u = c.url { getCandidates.append(u) }
        }
        if let u = URL(string: "api/spots/\(spotID)", relativeTo: baseURL) { getCandidates.append(u) }
        // ★ AdminController::getPosts は id を要求
        if var c = URLComponents(url: baseURL.appendingPathComponent("api/getPosts"), resolvingAgainstBaseURL: false) {
            c.queryItems = [.init(name: "id", value: String(spotID))]
            if let u = c.url { getCandidates.append(u) }
        }
        if var c = URLComponents(url: baseURL.appendingPathComponent("api/posts/get"), resolvingAgainstBaseURL: false) {
            c.queryItems = [.init(name: "id", value: String(spotID))]
            if let u = c.url { getCandidates.append(u) }
        }
        // 万が一 /api が付かないルーティングでも拾えるように
        if var c = URLComponents(url: baseURL.appendingPathComponent("getPosts"), resolvingAgainstBaseURL: false) {
            c.queryItems = [.init(name: "id", value: String(spotID))]
            if let u = c.url { getCandidates.append(u) }
        }
        if var c = URLComponents(url: baseURL.appendingPathComponent("posts/get"), resolvingAgainstBaseURL: false) {
            c.queryItems = [.init(name: "id", value: String(spotID))]
            if let u = c.url { getCandidates.append(u) }
        }
        
        let decoder = JSONDecoder()
        for url in getCandidates {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { continue }
                if let arr = try? decoder.decode([APIPost].self, from: data) { return arr }
                if let env = try? decoder.decode(PostListEnvelope.self, from: data), let arr = env.posts { return arr }
                if let env = try? decoder.decode(DataEnvelope.self, from: data), let arr = env.data { return arr }
                if let env = try? decoder.decode(ItemsEnvelope.self, from: data), let arr = env.items { return arr }
                if let env = try? decoder.decode(SpotDetailsEnvelope.self, from: data), let arr = env.spot?.posts { return arr }
                if let env = try? decoder.decode(SpotEnvelope.self, from: data), let arr = env.posts { return arr }
            } catch {
                continue
            }
        }
        
        // 2) POST フォールバック（id を form で送る実装向け）
        let postCandidates = [
            baseURL.appendingPathComponent("api/getPosts"),
            baseURL.appendingPathComponent("api/posts/get"),
            baseURL.appendingPathComponent("getPosts"),
            baseURL.appendingPathComponent("posts/get"),
        ]
        for url in postCandidates {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.httpBody = "id=\(spotID)".data(using: .utf8)
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { continue }
                if let arr = try? decoder.decode([APIPost].self, from: data) { return arr }
                if let env = try? decoder.decode(PostListEnvelope.self, from: data), let arr = env.posts { return arr }
                if let env = try? decoder.decode(DataEnvelope.self, from: data), let arr = env.data { return arr }
                if let env = try? decoder.decode(ItemsEnvelope.self, from: data), let arr = env.items { return arr }
            } catch {
                continue
            }
        }
        
        return []
    }
    
    // --- 作成（multipart：画像あり対応を強化） ---
    struct UploadImage: Hashable {
        let data: Data
        let filename: String
        let mime: String
    }
    struct CreateSpotForm {
        var spotName: String
        var evaluation: Int
        var userName: String?
        var comment: String?
        var latitude: Double
        var longitude: Double
        var images: [UploadImage]
    }
    
    /// 与えられたフィールド名で multipart を組み立てて送信
    private static func createSpotMultipart(_ form: CreateSpotForm, fileFieldName: String) async throws -> (status: Int, data: Data) {
        let url = baseURL.appendingPathComponent("api/spots/store")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        func append(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        func appendFile(_ name: String, filename: String, mime: String, data: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // --- テキスト項目
        append("spot_name", form.spotName)
        append("evaluation", String(form.evaluation))
        append("ido", String(form.latitude))
        append("keido", String(form.longitude))
        if let name = form.userName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            append("user_name", name)
            append("author", name) // バックエンドでどちらかを見るケースに備える
        }
        if let c = form.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            append("comment", c)
            append("content", c) // 同上
        }
        
        // --- 画像（常に配列名で送る想定）
        for img in form.images {
            appendFile(fileFieldName, filename: img.filename, mime: img.mime, data: img.data)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        return (code, data)
    }
    
    /// 画像付きでの登録: まず `photo[]` で送り、非2xxならフィールド名を替えて再試行
    static func createSpot(_ form: CreateSpotForm) async throws {
        // 画像が無いときは従来通り（多くの環境がこれで通る）
        if form.images.isEmpty {
            let (code, data) = try await createSpotMultipart(form, fileFieldName: "photo[]")
            guard (200..<300).contains(code) else {
                // 画像なしでも非2xxなら本文から理由を拾って返す
                let msg = String(data: data, encoding: .utf8) ?? "Invalid response (\(code))"
                throw APIError.server(NSError(domain: "SpotsAPI", code: code, userInfo: [NSLocalizedDescriptionKey: msg]))
            }
            return
        }
        
        // 画像あり：まず photo[]、ダメなら候補を順に試す
        let fieldCandidates = ["photo[]", "photos[]", "image[]", "images[]", "file", "files[]", "photo"]
        var lastData: Data = Data()
        var lastCode: Int = -1
        
        for field in fieldCandidates {
            do {
                let (code, data) = try await createSpotMultipart(form, fileFieldName: field)
                if (200..<300).contains(code) {
                    return
                } else {
                    lastCode = code
                    lastData = data
                    // 次の候補へ
                }
            } catch {
                // 通信層の例外は最終的にまとめて返す
                throw APIError.server(error)
            }
        }
        // すべて非2xxだった場合：サーバ本文をエラーにのせて返す
        let msg = String(data: lastData, encoding: .utf8) ?? "Invalid response (\(lastCode))"
        throw APIError.server(NSError(domain: "SpotsAPI", code: lastCode, userInfo: [NSLocalizedDescriptionKey: msg]))
    }
    
    // ====== ★ ここから修正・削除 API 追加 ======
    
    /// 共通: 2xx なら OK を返す
    private static func is2xx(_ resp: URLResponse?) -> Bool {
        guard let http = resp as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }
    
    /// 共通: URLRequest を実行
    @discardableResult
    private static func send(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do { return try await URLSession.shared.data(for: req) }
        catch { throw APIError.server(error) }
    }
    
    /// スポット更新（候補ルート/メソッドを順に試す）
    static func updateSpot(spotID: Int, spotName: String?, evaluation: Int?) async throws {
        // ペイロード（JSON）
        struct UpdatePayload: Encodable {
            var spot_name: String?
            var evaluation: String? // サーバ側が文字列の可能性もあるので String で送る
        }
        let payload = UpdatePayload(
            spot_name: spotName?.isEmpty == false ? spotName : nil,
            evaluation: evaluation.map { String($0) }
        )
        let json = try JSONEncoder().encode(payload)
        
        // 1) PATCH /api/spots/update/{id}
        var candidates: [URLRequest] = []
        // PATCH JSON
        if let u = URL(string: "api/spots/update/\(spotID)", relativeTo: baseURL) {
            var r = URLRequest(url: u); r.httpMethod = "PATCH"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue("application/json", forHTTPHeaderField: "Accept")
            r.httpBody = json; candidates.append(r)
        }
        // PUT JSON
        if let u = URL(string: "api/spots/\(spotID)", relativeTo: baseURL) {
            var r = URLRequest(url: u); r.httpMethod = "PUT"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.setValue("application/json", forHTTPHeaderField: "Accept")
            r.httpBody = json; candidates.append(r)
        }
        // POST _method=PATCH フォーム
        if let u = URL(string: "api/spots/update/\(spotID)", relativeTo: baseURL) {
            var r = URLRequest(url: u); r.httpMethod = "POST"
            let pairs: [String: String] = [
                "_method": "PATCH",
                "spot_name": spotName ?? "",
                "evaluation": evaluation.map { String($0) } ?? ""
            ]
            r.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            r.setValue("application/json", forHTTPHeaderField: "Accept")
            r.httpBody = urlEncoded(pairs).data(using: .utf8); candidates.append(r)
        }
        // POST /api/spots/update （id を付与）
        if let u = URL(string: "api/spots/update", relativeTo: baseURL) {
            var r = URLRequest(url: u); r.httpMethod = "POST"
            let pairs: [String: String] = [
                "id": String(spotID),
                "spot_name": spotName ?? "",
                "evaluation": evaluation.map { String($0) } ?? ""
            ]
            r.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            r.setValue("application/json", forHTTPHeaderField: "Accept")
            r.httpBody = urlEncoded(pairs).data(using: .utf8); candidates.append(r)
        }
        
        for var req in candidates {
            // 一部サーバはヘッダで override に対応
            if req.httpMethod == "POST" {
                req.setValue("PATCH", forHTTPHeaderField: "X-HTTP-Method-Override")
            }
            let (data, resp) = try await send(req)
            if is2xx(resp) { return }
            // JSON で {success: true} などが来る系に対応（2xx 以外は無視）
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) { return }
            // fallthrough to next candidate
            _ = data
        }
        throw APIError.invalidResponse
    }
    
    /// スポット削除（候補ルート/メソッドを順に試す）
    static func deleteSpot(spotID: Int) async throws {
        var candidates: [URLRequest] = []
        // DELETE /api/spots/delete/{id}
        if let u = URL(string: "api/spots/delete/\(spotID)", relativeTo: baseURL) {
            var r = URLRequest(url: u); r.httpMethod = "DELETE"
            r.setValue("application/json", forHTTPHeaderField: "Accept")
            candidates.append(r)
        }
        // DELETE /api/spots/{id}
        if let u = URL(string: "api/spots/\(spotID)", relativeTo: baseURL) {
            var r = URLRequest(url: u); r.httpMethod = "DELETE"
            r.setValue("application/json", forHTTPHeaderField: "Accept")
            candidates.append(r)
        }
        // POST _method=DELETE /api/spots/delete/{id}
        if let u = URL(string: "api/spots/delete/\(spotID)", relativeTo: baseURL) {
            var r = URLRequest(url: u); r.httpMethod = "POST"
            r.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            r.setValue("application/json", forHTTPHeaderField: "Accept")
            r.httpBody = urlEncoded(["_method": "DELETE"]).data(using: .utf8)
            candidates.append(r)
        }
        // POST /api/spots/delete （id を form）
        if let u = URL(string: "api/spots/delete", relativeTo: baseURL) {
            var r = URLRequest(url: u); r.httpMethod = "POST"
            r.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            r.setValue("application/json", forHTTPHeaderField: "Accept")
            r.httpBody = urlEncoded(["id": String(spotID)]).data(using: .utf8)
            candidates.append(r)
        }
        for var req in candidates {
            if req.httpMethod == "POST" {
                req.setValue("DELETE", forHTTPHeaderField: "X-HTTP-Method-Override")
            }
            let (_, resp) = try await send(req)
            if is2xx(resp) { return }
        }
        throw APIError.invalidResponse
    }
    
    /// application/x-www-form-urlencoded の組み立て
    private static func urlEncoded(_ dict: [String: String]) -> String {
        dict.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
    }
    
    // 以降に他の更新系／写真系の既存メソッドがある場合はそのまま据え置き
}

