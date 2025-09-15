//
//  BoardModels.swift
//  MAPCH - Keiziban API Models
//

import Foundation

// 並び順（BoardsViewModel 側の KZBBoardSort と互換）
public enum BoardSort: String, Codable, CaseIterable {
    case latest, trending, favorite
}

// ページングレスポンス
public struct PagedResponse<T: Decodable>: Decodable {
    public let data: [T]
    public let meta: Meta
    
    public struct Meta: Decodable {
        public let page: Int
        public let per_page: Int
        public let total: Int
    }
}

// Board DTO（BoardsViewModel.BoardRow.init(dto:) がこの形を期待）
public struct BoardDTO: Decodable {
    public let id: Int
    public let description: String
    public let location: Location
    public let favorite_count: Int
    public let view_count: Int
    public let author: Author
    public let category: Category
    public let created_at: String?
    public let is_favorited: Bool
    public let photo_url: String?
    
    public struct Author: Decodable {
        public let id: Int?
        public let uid: String?
        public let name: String
    }
    public struct Category: Decodable {
        public let id: Int
        public let name: String
        public let sort_order: Int?
    }
    public struct Location: Decodable {
        public let name: String?
        public let lat: Double?
        public let lng: Double?
    }
}

