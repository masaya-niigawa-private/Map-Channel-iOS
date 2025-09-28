//
//  BoardsViewModel.swift
//

import Foundation
import SwiftUI

// ===== KZB が無い環境用のブリッジ =====
typealias KZBBoardsService = BoardsService
typealias KZBBoardSort = BoardSort
typealias KZBBoardDTO = BoardDTO
// =====================================

// MARK: - Service 拡張用プロトコル（POST /boards, GET /categories）
public struct BoardPhoto {
    public let data: Data
    public let filename: String
    public let mimeType: String
    public init(data: Data, filename: String, mimeType: String) {
        self.data = data; self.filename = filename; self.mimeType = mimeType
    }
}

public protocol BoardsCategoriesService {
    func fetchCategories() async throws -> [BoardDTO.Category]
}

public protocol BoardsCreateService {
    func createBoard(categoryId: Int, description: String,
                     linkURL: String?, locationName: String?,
                     locationLat: Double?, locationLng: Double?,
                     photo: BoardPhoto?) async throws -> BoardDTO
}

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
    
    // カテゴリキャッシュ（名称→ID）
    private var categoryByName: [String: Int] = [:]
    
    // —— KUChannelView：BoardsService を使用
    init(service: BoardsService) {
        self.boardsService = service
        self.kzbService = nil
    }
    
    // —— KeizibanView：KZBBoardsService を使用
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
                // —— KeizibanView 経路
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
    
    // ========== ここから投稿実装 ==========
    /// カテゴリ一覧（名称→ID）の lazy ロード
    func ensureCategoriesLoaded() async {
        guard categoryByName.isEmpty else { return }
        do {
            if let svc = (boardsService as? BoardsCategoriesService) ?? (kzbService as? BoardsCategoriesService) {
                let cs = try await svc.fetchCategories()
                categoryByName = Dictionary(uniqueKeysWithValues: cs.map { ($0.name, $0.id) })
            }
        } catch {
            // ここで失敗しても投稿時に再取得を試みる
        }
    }
    
    /// 新規投稿 → POST /boards → 成功時に一覧へ即反映
    func submitNewPost(form: KZBNewPostForm) async {
        let desc = form.descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !desc.isEmpty else {
            alert = .init(message: "説明文を入力してください")
            return
        }
        
        do {
            isLoading = true
            defer { isLoading = false }
            
            // カテゴリID解決（未ロードならここで取得）
            if categoryByName.isEmpty {
                await ensureCategoriesLoaded()
            }
            guard let catName = form.category,
                  let catId = categoryByName[catName] ?? categoryByName.values.sorted().first
            else {
                throw NSError(domain: "BoardsViewModel", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "カテゴリを選択してください"])
            }
            
            // 画像 MIME/拡張子の推定（jpeg/png/webp）
            var photo: BoardPhoto? = nil
            if let data = form.photoData, !data.isEmpty {
                let mime: String
                let filename: String
                if data.starts(with: [0xFF, 0xD8, 0xFF]) { mime = "image/jpeg"; filename = "photo.jpg" }
                else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { mime = "image/png"; filename = "photo.png" }
                else if data.count >= 12,
                        String(data: data[8..<12], encoding: .ascii) == "WEBP" { mime = "image/webp"; filename = "photo.webp" }
                else { mime = "image/jpeg"; filename = "photo.jpg" } // サーバ側の image バリデーション対策
                photo = BoardPhoto(data: data, filename: filename, mimeType: mime)
            }
            
            // Service が投稿APIを実装している方を使う
            if let svc = (boardsService as? BoardsCreateService) ?? (kzbService as? BoardsCreateService) {
                let dto = try await svc.createBoard(
                    categoryId: catId,
                    description: desc,
                    linkURL: form.link.isEmpty ? nil : form.link,
                    locationName: form.pin,
                    locationLat: nil,
                    locationLng: nil,
                    photo: photo
                )
                
                // 成功 → 先頭に反映
                let created = BoardPost(
                    content: dto.description,
                    location: dto.location.name ?? "",
                    likes: dto.favorite_count,
                    views: dto.view_count,
                    authorName: dto.author.name,
                    authorInitial: String(dto.author.name.prefix(1)),
                    authorTag: dto.category.name,
                    timeAgo: BoardRow.relative(dto.created_at)
                )
                posts.insert(created, at: 0)
                
            } else {
                throw NSError(domain: "BoardsViewModel", code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "投稿APIが未実装（BoardsAPI 側に createBoard を実装してください）"])
            }
        } catch {
            alert = .init(message: error.localizedDescription)
        }
    }
}

