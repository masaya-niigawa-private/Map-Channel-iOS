//
//  SpotModels.swift
//  Map-channel
//
//  Created by user on 2025/08/15.
//

import CoreLocation
import Foundation

// MARK: - Photo
// SpotModels.swift - Photo（強化版）
struct Photo: Identifiable, Decodable {
    let id: Int
    let spot_id: Int?
    let photo_path: String
    
    enum CodingKeys: String, CodingKey {
        case id, spot_id
        case photo_path
        case url, path, photoUrl, photoURL, src
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        spot_id = try? c.decodeIfPresent(Int.self, forKey: .spot_id)
        
        let candidates: [CodingKeys] = [.photo_path, .url, .path, .photoUrl, .photoURL, .src]
        var value = ""
        for key in candidates {
            if let raw = try? c.decode(String.self, forKey: key) {
                let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty {
                    value = t.replacingOccurrences(of: "\\", with: "/") // ← 重要
                    break
                }
            }
        }
        self.photo_path = value
    }
}



// MARK: - Post（posts テーブル相当：既存のまま）

struct Post: Identifiable, Decodable {
    let id: Int?
    let author: String?
    let content: String?
    let rating: Int?
    let createdAt: Date?
    
    // ネスト user のフォールバック用
    struct UserRef: Decodable {
        let name: String?
        let username: String?
        let nickname: String?
    }
    let user: UserRef?
    
    // 画面用に解決済みプロパティ
    var authorResolved: String {
        author ?? user?.name ?? user?.username ?? user?.nickname ?? "匿名"
    }
    var textResolved: String { content ?? "" }
    var ratingResolved: Int { max(0, min(5, rating ?? 0)) }
    
    enum CodingKeys: String, CodingKey {
        case id, author, content, rating
        case text, body, message
        case evaluation, stars
        case created_at, updated_at, date, time
        case user
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try? c.decodeIfPresent(Int.self, forKey: .id)
        author  = Self.string(for: [.author], in: c)
        content = Self.string(for: [.content, .text, .body, .message], in: c)
        rating  = Self.int(for: [.rating, .evaluation, .stars], in: c)
        if let s = Self.string(for: [.created_at, .updated_at, .date, .time], in: c) {
            createdAt = Self.parseDateString(s)
        } else {
            createdAt = nil
        }
        user = try? c.decodeIfPresent(UserRef.self, forKey: .user)
    }
    
    // MARK: Helpers
    private static func string(
        for keys: [CodingKeys],
        in c: KeyedDecodingContainer<CodingKeys>
    ) -> String? {
        for key in keys {
            if let v = try? c.decodeIfPresent(String.self, forKey: key), !v.isEmpty {
                return v
            }
        }
        return nil
    }
    private static func int(
        for keys: [CodingKeys],
        in c: KeyedDecodingContainer<CodingKeys>
    ) -> Int? {
        for key in keys {
            // Int として
            if let n = try? c.decodeIfPresent(Int.self, forKey: key) { return n }
            // 文字列 → 数値
            if let raw = try? c.decodeIfPresent(String.self, forKey: key) {
                let s = raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw
                if let n = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return n }
            }
        }
        return nil
    }
    private static func parseDateString(_ s: String) -> Date? {
        if let d = ISO8601DateFormatter().date(from: s) { return d }
        let f = DateFormatter()
        f.locale = .current
        for fmt in ["yyyy-MM-dd'T'HH:mm:ssZ","yyyy-MM-dd HH:mm:ss","yyyy/MM/dd HH:mm","yyyy-MM-dd"] {
            f.dateFormat = fmt
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}

// MARK: - CommentNode（comments テーブル：追加）

struct CommentNode: Identifiable, Decodable {
    let id: Int?
    let spot_id: Int?
    let comment: String?
}

// MARK: - Spot

struct Spot: Identifiable, Decodable {
    let id: Int
    let spot_name: String
    let latitude: Double
    let longitude: Double
    
    // 詳細シート用（APIに無くてもOK）
    let evaluation: String?
    let photos: [Photo]?
    
    // 追加：APIの posts / comments を受け取る
    let posts: [Post]?
    let comments: [CommentNode]?    // ← 追加
    
    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case spot_name
        case latitude = "ido"
        case longitude = "keido"
        case evaluation
        case photos
        case posts
        case comments // ← 追加
    }
    
    // プレビュー・手動生成用
    init(id: Int, spot_name: String, latitude: Double, longitude: Double,
         evaluation: String? = nil, photos: [Photo]? = nil,
         posts: [Post]? = nil, comments: [CommentNode]? = nil) {
        self.id = id
        self.spot_name = spot_name
        self.latitude = latitude
        self.longitude = longitude
        self.evaluation = evaluation
        self.photos = photos
        self.posts = posts
        self.comments = comments
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        spot_name = (try? c.decode(String.self, forKey: .spot_name)) ?? ""
        latitude = try c.decodeFlexibleDouble(forKey: .latitude)
        longitude = try c.decodeFlexibleDouble(forKey: .longitude)
        evaluation = try? c.decodeIfPresent(String.self, forKey: .evaluation)
        photos = try? c.decodeIfPresent([Photo].self, forKey: .photos)
        posts = try? c.decodeIfPresent([Post].self, forKey: .posts)
        comments = try? c.decodeIfPresent([CommentNode].self, forKey: .comments)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
        if let d = try? decode(Double.self, forKey: key) { return d }
        if let s = try? decode(String.self, forKey: key),
           let d = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return d }
        throw DecodingError.typeMismatch(
            Double.self,
            .init(codingPath: codingPath + [key],
                  debugDescription: "Expected Double or numeric String for \(key).")
        )
    }
}

