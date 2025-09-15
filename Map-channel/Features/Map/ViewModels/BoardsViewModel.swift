//
//  BoardsViewModel.swift
//

import Foundation
import SwiftUI

// ===== KZB が無い環境用のブリッジ =====
// ※ プロジェクトに KZBBoardsService / KZBBoardSort が「存在しない」場合のみ有効。
//   もし別ファイルで KZB* を定義しているなら、この 3 行は削除してください。
typealias KZBBoardsService = BoardsService
typealias KZBBoardSort = BoardSort
typealias KZBBoardDTO = BoardDTO
// =====================================

// MARK: - KUChannelView 用の表示モデル
public struct BoardRow: Identifiable {
    public let id: Int
    public let content: String
    public let locationName: String
    public let likes: Int
    public let views: Int
    public let authorName: String
    public let authorInitial: String
    public let categoryName: String
    public let timeAgo: String
    public let isFavorited: Bool
    public let photoURL: String?
    
    init(dto: BoardDTO) {
        self.id = dto.id
        self.content = dto.description
        self.locationName = dto.location.name ?? ""
        self.likes = dto.favorite_count
        self.views = dto.view_count
        self.authorName = dto.author.name
        self.authorInitial = String(dto.author.name.prefix(1))
        self.categoryName = dto.category.name
        self.timeAgo = Self.relative(dto.created_at)
        self.isFavorited = dto.is_favorited
        self.photoURL = dto.photo_url
    }
    
    static func relative(_ iso: String?) -> String {
        guard let s = iso else { return "" }
        let f = ISO8601DateFormatter()
        if let d = f.date(from: s) ?? f.date(from: s + "Z") {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .short
            return rel.localizedString(for: d, relativeTo: Date())
        }
        return ""
    }
}

// MARK: - KeizibanView 用の表示モデル
public struct BoardPost: Identifiable {
    public let id = UUID()
    public let content: String
    public let location: String
    public let likes: Int
    public let views: Int
    public let authorName: String
    public let authorInitial: String
    public let authorTag: String
    public let timeAgo: String
}

@MainActor
final class BoardsViewModel: ObservableObject {
    
    // —— KUChannelView が参照するプロパティ
    @Published var rows: [BoardRow] = []
    
    // —— KeizibanView が参照するプロパティ
    @Published var posts: [BoardPost] = []
    
    @Published var isLoading = false
    @Published var alert: AlertItem?
    
    struct AlertItem: Identifiable { let id = UUID(); let message: String }
    
    // どちらか片方だけ注入される
    private let boardsService: BoardsService?
    private let kzbService: KZBBoardsService?
    
    // ページング状態
    private var page = 1
    private var per = 20
    private var currentSort: BoardSort = .latest
    private var currentCategoryId: Int?
    
    // —— KUChannelView：BoardsService を使用
    init(service: BoardsService) {
        self.boardsService = service
        self.kzbService = nil
    }
    
    // —— KeizibanView：KZBBoardsService を使用（なければ上の typealias で BoardsService と同義）
    init(kzbService: KZBBoardsService) {
        self.boardsService = nil
        self.kzbService = kzbService
    }
    
    // 画面から呼ばれる API（両画面共通）
    func load(sort: BoardSort, categoryId: Int?) async {
        currentSort = sort
        currentCategoryId = categoryId
        page = 1
        await fetch(reset: true)
    }
    
    func reload() async { await fetch(reset: true) }
    
    func loadMoreIfNeeded(currentItem item: BoardRow?) async {
        guard let item,
              let idx = rows.firstIndex(where: { $0.id == item.id }) else { return }
        let threshold = max(rows.count - 5, 0)
        if idx >= threshold { await fetch(reset: false) }
    }
    
    private func fetch(reset: Bool) async {
        if reset { isLoading = true }
        defer { if reset { isLoading = false } }
        
        do {
            let next = reset ? 1 : page
            
            if let svc = boardsService {
                // —— KUChannelView 経路：BoardDTO → BoardRow
                let paged = try await svc.fetchBoards(
                    sort: currentSort,
                    categoryId: currentCategoryId,
                    page: next,
                    perPage: per
                )
                let newRows = paged.data.map(BoardRow.init(dto:))
                rows = reset ? newRows : (rows + newRows)
                
            } else if let svc = kzbService {
                // —— KeizibanView 経路：KZBBoardDTO → BoardPost
                let paged = try await svc.fetchBoards(
                    sort: KZBBoardSort(rawValue: currentSort.rawValue) ?? .latest,
                    categoryId: currentCategoryId,
                    page: next,
                    perPage: per
                )
                let newPosts = paged.data.map { d in
                    BoardPost(
                        content: d.description,
                        location: d.location.name ?? "",
                        likes: d.favorite_count,
                        views: d.view_count,
                        authorName: d.author.name,
                        authorInitial: String(d.author.name.prefix(1)),
                        authorTag: d.category.name,
                        timeAgo: BoardRow.relative(d.created_at)
                    )
                }
                posts = reset ? newPosts : (posts + newPosts)
                
            } else {
                throw NSError(domain: "BoardsViewModel", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Service not injected"])
            }
            
            page = next + 1
        } catch {
            alert = .init(message: error.localizedDescription)
        }
    }
}
