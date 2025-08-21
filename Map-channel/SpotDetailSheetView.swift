// SpotDetailSheetView.swift
import SwiftUI
import Foundation

// MARK: - 通知名（欠けていた拡張を追加）
extension Notification.Name {
    static let spotCreated = Notification.Name("SpotCreated")
    static let spotUpdated  = Notification.Name("spotUpdated")
    static let spotDeleted  = Notification.Name("SpotDeleted")
    static let spotPhotosUpdated = Notification.Name("SpotPhotosUpdated") // 既存の文字列名を保持
}

struct SpotDetailSheet: View {
    let spot: Spot
    
    @Environment(\.dismiss) private var dismiss
    
    // 表示用 State（非 Optional）
    @State private var displayName: String
    @State private var displayRating: Int
    @State private var displayPhotoPaths: [String] = []
    
    // コメント（UI）
    @State private var shownReviews: [Review] = []
    @State private var leadCommentText: String?
    
    // 画面状態
    @State private var isPresentingCommentComposer = false
    @State private var showEdit = false
    
    // 削除
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    init(spot: Spot) {
        self.spot = spot
        
        // 名称
        _displayName = State(initialValue: spot.spot_name)
        
        // 評価（"５" など全角→半角に寄せて 0...5 へ丸め）
        let raw = spot.evaluation ?? ""
        let half = raw.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? raw
        let n = Int(half.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        _displayRating = State(initialValue: max(0, min(5, n)))
        
        // 写真（キャッシュ優先）※ photo_path は非Optional想定に修正
        var initialPhotoPaths = (spot.photos ?? []).map { $0.photo_path.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let cached = UserDefaults.standard.array(forKey: Self.photoCacheKey(for: spot.id)) as? [String] {
            initialPhotoPaths = cached
        }
        _displayPhotoPaths = State(initialValue: cleanedUnique(initialPhotoPaths))
        
        // リードコメント（comments の最新非空を1件）
        let head = spot.comments?
            .sorted { ($0.id ?? 0) > ($1.id ?? 0) }
            .compactMap { ($0.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        _leadCommentText = State(initialValue: head)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // ヘッダー画像
                headerImage
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 15)
                
                // タイトル + レーティング
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayName)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        StarsView(rating: displayRating)
                        Text(displayRating > 0 ? "\(displayRating) / 5" : "未評価")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // アクション
                HStack(spacing: 12) {
                    ActionButton(title: "コメントを書く", systemName: "text.bubble") {
                        isPresentingCommentComposer = true
                    }
                    ActionButton(title: "修正する", systemName: "square.and.pencil") {
                        showEdit = true
                    }
                    Spacer()
                    ActionButton(title: "削除", systemName: "trash") {
                        showDeleteConfirm = true
                    }
                }
                
                // リードコメント
                if let lead = leadCommentText {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("詳細情報")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(lead)
                    }
                }
                
                // 写真一覧
                if let urls = photoURLs(), !urls.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("写真")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(urls, id: \.absoluteString) { url in
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ZStack {
                                                Rectangle().fill(Color(UIColor.secondarySystemFill))
                                                ProgressView()
                                            }
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .failure:
                                            ZStack {
                                                Rectangle().fill(Color(UIColor.secondarySystemFill))
                                                Image(systemName: "photo")
                                                    .imageScale(.large)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        @unknown default:
                                            ZStack {
                                                Rectangle().fill(Color(UIColor.secondarySystemFill))
                                                Image(systemName: "photo")
                                                    .imageScale(.large)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                    .frame(width: 140, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("写真")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("まだ写真はありません")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                
                // コメント（最新が左）
                if !shownReviews.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("コメント")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(shownReviews) { r in
                                    ReviewCard(review: r)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear { applyPhotoUpdate(from: spot); loadReviewsIfNeeded() }
        
        // EditSpotView が出す通知を受けて写真を即時更新（既存名を利用）
        .onReceive(NotificationCenter.default.publisher(for: .spotPhotosUpdated)) { note in
            guard
                let info = note.userInfo as? [String: Any],
                let sid = info["spot_id"] as? Int, sid == spot.id,
                let paths = info["photo_paths"] as? [String]
            else { return }
            displayPhotoPaths = cleanedUnique(paths)
            UserDefaults.standard.set(displayPhotoPaths, forKey: Self.photoCacheKey(for: spot.id))
        }
        
        .onReceive(NotificationCenter.default.publisher(for: .spotCreated)) { _ in
            loadReviewsIfNeeded()
        }
        
        // コメント入力（CommentComposeView を使用）
        .sheet(isPresented: $isPresentingCommentComposer) {
            CommentComposeView { action in
                switch action {
                case .cancel:
                    break
                case .post(let text, let author):
                    Task {
                        do {
                            try await SpotsAPI.submitPost(
                                spotID: spot.id,
                                author: author,           // nil 可
                                content: text
                            )
                            // 画面を即時更新（先頭に挿入）
                            let displayAuthor = (author?.isEmpty == false) ? author! : "匿名"
                            let new = Review(author: displayAuthor, rating: 0, text: text, timestamp: Date())
                            shownReviews.insert(new, at: 0)
                            if (leadCommentText ?? "").isEmpty { leadCommentText = text }
                        } catch {
                            // 必要ならエラー表示を追加
                            // 例: self.deleteError = (error as NSError).localizedDescription
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        
        
        // 修正後（SpotDetailSheetView.swift）
        .sheet(isPresented: $showEdit) {
            let photosForEdit: [EditSpotPhoto] = (spot.photos ?? []).compactMap { p in
                let id = p.id                          // ★ ここを修正
                let path = p.photo_path
                guard let url = makeURL(from: path) else { return nil }
                return EditSpotPhoto(id: id, url: url)
            }
            let preset = EditSpotPreset(
                spotID: spot.id,
                name: displayName,
                rating: displayRating,
                photos: photosForEdit
            )
            EditSpotView(
                preset: preset,
                onSaved: { newName, newRating in
                    displayName = newName
                    displayRating = newRating
                    NotificationCenter.default.post(
                        name: .spotUpdated,
                        object: nil,
                        userInfo: ["spot_id": spot.id, "spot_name": newName, "evaluation": newRating]
                    )
                }
            )
            .presentationDetents([.large])
        }
        
        
        // 削除ダイアログ
        .confirmationDialog("このスポットを削除しますか？", isPresented: $showDeleteConfirm) {
            Button(isDeleting ? "削除中…" : "削除", role: .destructive) {
                guard !isDeleting else { return }
                isDeleting = true
                Task {
                    do {
                        try await SpotsAPI.deleteSpot(spotID: spot.id)
                        NotificationCenter.default.post(name: .spotDeleted, object: nil, userInfo: ["spot_id": spot.id])
                        dismiss()
                    } catch {
                        deleteError = (error as NSError).localizedDescription
                    }
                    isDeleting = false
                }
            }
            .disabled(isDeleting)
            Button("キャンセル", role: .cancel) {}
        }
        .alert("削除に失敗しました",
               isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "不明なエラー")
        }
    }
}

// MARK: - Header Image

private extension SpotDetailSheet {
    var headerImage: some View {
        Group {
            if let url = firstValidPhotoURL() {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle().fill(Color(UIColor.secondarySystemFill))
                            ProgressView()
                        }
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        ZStack {
                            Rectangle().fill(Color(UIColor.secondarySystemFill))
                            Image(systemName: "photo")
                                .imageScale(.large)
                                .foregroundStyle(.tertiary)
                        }
                    @unknown default:
                        ZStack {
                            Rectangle().fill(Color(UIColor.secondarySystemFill))
                            Image(systemName: "photo")
                                .imageScale(.large)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } else {
                ZStack {
                    Rectangle().fill(Color(UIColor.secondarySystemFill))
                    Image(systemName: "photo")
                        .imageScale(.large)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

private struct ActionButton: View {
    let title: String
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers
extension SpotDetailSheet {
    //static func photoCacheKey(for id: Int) -> String { "photo_cache_spot_\(id)" }
    static func photoCacheKey(for id: Int) -> String { "photo_cache_spot_v2_\(id)" }
    
    /// 先頭に表示する1枚（存在する最初のURL）
    func firstValidPhotoURL() -> URL? {
        for p in displayPhotoPaths {
            if let u = makeURL(from: p) { return u }
        }
        return nil
    }
    
    /// 一覧表示用
    func photoURLs() -> [URL]? {
        let urls = displayPhotoPaths.compactMap { makeURL(from: $0) }
        return urls.isEmpty ? nil : urls
    }
    
    func makeURL(from path: String) -> URL? {
        var s = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        
        // すでに http(s) などスキーム付きならそのまま
        if let abs = URL(string: s), abs.scheme != nil { return abs }
        
        // 相対パスは S3 を基準に解決（"photo/..." 前提）
        if !s.hasPrefix("/") { s = "/" + s }
        return URL(string: s, relativeTo: SpotsAPI.imageBaseURL)
    }
    
    func cleanedUnique(_ paths: [String]) -> [String] {
        var set = Set<String>()
        var out: [String] = []
        for p in paths {
            let t = p.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, !set.contains(t) else { continue }
            set.insert(t)
            out.append(t)
        }
        return out
    }
    
    /// onAppear での初期写真補強（photo_path を非Optional前提に修正）
    func applyPhotoUpdate(from spot: Spot) {
        let serverPaths = (spot.photos ?? []).map { $0.photo_path.trimmingCharacters(in: .whitespacesAndNewlines) }
        let merged = cleanedUnique(displayPhotoPaths + serverPaths)
        displayPhotoPaths = merged
    }
    
    func loadReviewsIfNeeded() {
        Task {
            do {
                let posts = try await SpotsAPI.fetchPosts(spotID: spot.id)
                // APIPost → Review へマッピング（本文は複数キーのどれか）
                let mapped: [Review] = posts.compactMap { p in
                    let author = (p.author ?? p.user_name)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "匿名"
                    let text = [p.content, p.comment, p.text, p.body, p.message]
                        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .first { !$0.isEmpty }
                    guard let text = text else { return nil }
                    let rating = p.rating ?? 0
                    return Review(author: author, rating: rating, text: text, timestamp: nil)
                }
                await MainActor.run {
                    self.shownReviews = mapped
                    if self.leadCommentText == nil {
                        self.leadCommentText = self.shownReviews.first?.text
                    }
                }
            } catch {
                // 失敗時は無視 or エラー表示を検討
            }
        }
    }
}

