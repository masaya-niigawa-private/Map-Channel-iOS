import SwiftUI
import Foundation

// =====================================================
struct KeizibanView: View {
    @State private var selectedPrimary: KZBPrimary = .latest
    @State private var showingNewPost = false
    
    @StateObject private var vm: BoardsViewModel
    
    init(vm: BoardsViewModel? = nil) {
        if let vm {
            _vm = StateObject(wrappedValue: vm)
        } else {
            _vm = StateObject(
                wrappedValue: BoardsViewModel(
                    kzbService: BoardsAPI(baseURL: URL(string: "https://map-ch.com/api/v1")!)
                )
            )
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.kzb("#2E4A8C"), Color.kzb("#224684")]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー（🏠🔔／中央タイトル／右上＋）
                KZBHeader(onPlus: { showingNewPost = true })
                
                // 2段のカテゴリーチップ（横スクロール）
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            ForEach(KZBPrimary.allCases, id: \.self) { item in
                                KZBChip(title: item.title, prefixEmoji: item.emoji,
                                        isSelected: selectedPrimary == item) {
                                    withAnimation(.spring()) { selectedPrimary = item }
                                    Task { await vm.load(sort: item.toSort, categoryId: nil) }
                                }
                            }
                        }
                        HStack(spacing: 10) {
                            ForEach(KZBSecondary.allCases, id: \.self) { item in
                                // カテゴリID連携は別途：ここでは UI のみ
                                KZBChip(title: item.title, isSelected: false, action: {})
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                
                // カード一覧（APIデータ）
                ScrollView {
                    VStack(spacing: 20) {
                        if vm.isLoading && vm.posts.isEmpty {
                            ProgressView().padding(.top, 40)
                        }
                        ForEach(vm.posts, id: \.id) { p in
                            PostCardView(post: p)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .padding(.bottom, 28)
                }
            }
            
            // ===== 新規投稿ウィンドウ =====
            if showingNewPost {
                Color.black.opacity(0.35).ignoresSafeArea()
                    .transition(.opacity).zIndex(10)
                
                // 投稿 → VM 経由で API を叩く
                KZBNewPostView(isPresented: $showingNewPost) { form in
                    Task { await vm.submitNewPost(form: form) }
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 18)
                .transition(.scale.combined(with: .opacity))
                .zindexIfNeeded(11)
            }
        }
        .task {
            // 初回ロード
            await vm.load(sort: selectedPrimary.toSort, categoryId: nil)
            // カテゴリ名称→ID解決用のキャッシュ
            await vm.ensureCategoriesLoaded()
        }
        .alert(item: $vm.alert) { a in
            Alert(title: Text("エラー"), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showingNewPost)
    }
}

// =====================================================
// MARK: - ヘッダー／チップ（既存のまま）
// =====================================================

private struct KZBHeader: View {
    let onPlus: () -> Void
    var body: some View {
        HStack(spacing: 20) {
            Text("🏠").font(.system(size: 24))
            Text("🔔").font(.system(size: 24))
            Spacer()
            Text("KU Hub")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.kzb("#2E4A8C"))
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct KZBChip: View {
    let title: String
    var prefixEmoji: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji = prefixEmoji { Text(emoji) }
                Text(title).font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(isSelected ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }
}

private enum KZBPrimary: CaseIterable {
    case latest, trending, favorite
    var title: String { self == .latest ? "最新" : (self == .trending ? "急上昇" : "お気に入り") }
    var emoji: String { self == .trending ? "🔥" : (self == .favorite ? "⭐️" : "") }
}

private enum KZBSecondary: CaseIterable {
    case all, circle, job, itTools, influencer
    var title: String {
        switch self {
        case .all: "すべて"; case .circle: "サークル募集"; case .job: "バイト求人"
        case .itTools: "IT便利ツール"; case .influencer: "関大インフルエンサー"
        }
    }
}

// KeizibanView → BoardSort 変換
private extension KZBPrimary {
    var toSort: BoardSort {
        switch self {
        case .latest: return .latest
        case .trending: return .trending
        case .favorite: return .favorite
        }
    }
}

// =====================================================
// MARK: - PostCardView / 小物（既存そのまま）
// =====================================================
struct PostCardView: View {
    private struct CardData {
        let content: String
        let locationName: String
        let likes: Int
        let views: Int
        let authorName: String
        let authorInitial: String
        let categoryName: String
        let timeAgo: String
        let isFavorited: Bool
        let photoURL: String?
    }
    private let d: CardData
    @State private var isStarred = false
    
    init(row: BoardRow) {
        self.d = CardData(
            content: row.content, locationName: row.locationName, likes: row.likes, views: row.views,
            authorName: row.authorName, authorInitial: row.authorInitial, categoryName: row.categoryName,
            timeAgo: row.timeAgo, isFavorited: row.isFavorited, photoURL: row.photoURL
        )
        _isStarred = State(initialValue: row.isFavorited)
    }
    init(post: BoardPost) {
        self.d = CardData(
            content: post.content, locationName: post.location, likes: post.likes, views: post.views,
            authorName: post.authorName, authorInitial: post.authorInitial, categoryName: post.authorTag,
            timeAgo: post.timeAgo, isFavorited: false, photoURL: nil
        )
        _isStarred = State(initialValue: false)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 画像（上段）
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    gradient: Gradient(colors: [Color.kzb("#8E7CC3"), Color.kzb("#6B5B95")]),
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .frame(height: 220)
                
                if let url = d.photoURL, let u = URL(string: url) {
                    AsyncImage(url: u) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill().frame(height: 220).clipped()
                        case .empty:   Color.clear.frame(height: 220)
                        case .failure: Color.black.opacity(0.12).frame(height: 220)
                        @unknown default: Color.clear.frame(height: 220)
                        }
                    }
                } else {
                    Text("画像")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Text("通報")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.kzb("#544C79").opacity(0.9)))
                    .padding(.top, 12)
                    .padding(.trailing, 12)
            }
            .frame(height: 220)
            .clipShape(KZBRoundedRect(topLeft: 22, topRight: 22, bottomLeft: 0, bottomRight: 0))
            
            // 本文（下段）
            VStack(alignment: .leading, spacing: 14) {
                Text(d.content)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(.label))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 6) {
                    Text("📍")
                    Text(d.locationName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.kzb("#3676FF"))
                }
                
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                            .font(.system(size: 16, weight: .regular))
                            .opacity(0.75)
                        Text("\(d.likes)")
                    }
                    .foregroundColor(Color(.secondaryLabel))
                    
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 16, weight: .regular))
                            .opacity(0.75)
                        Text("\(d.views)")
                    }
                    .foregroundColor(Color(.secondaryLabel))
                    
                    Spacer()
                    
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Text("詳細")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
                .font(.system(size: 15))
                
                Divider()
                
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.kzb("#8E7CC3"), Color.kzb("#6B5B95")],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                        Text(String(d.authorInitial.prefix(1)))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.authorName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(.label))
                        
                        HStack(spacing: 8) {
                            Text(d.categoryName)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(Color.kzb("#5B8CFF").opacity(0.95))
                                )
                            Text(d.timeAgo)
                                .font(.system(size: 12))
                                .foregroundColor(Color(.secondaryLabel))
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        isStarred.toggle()
                    } label: {
                        Image(systemName: isStarred ? "star.fill" : "star")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(isStarred ? Color.yellow : Color.kzb("#2E4A8C"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(KZBRoundedRect(topLeft: 0, topRight: 0, bottomLeft: 22, bottomRight: 22))
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
    }
}


// Color.kzb("#RRGGBB", alpha:)
extension Color {
    static func kzb(_ hex: String, alpha: Double = 1.0) -> Color {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "0x", with: "")
            .uppercased()
        func d(_ ss: Substring) -> Double { Double(Int(ss, radix: 16) ?? 0) / 255.0 }
        switch s.count {
        case 3:
            let r = String(repeating: s[s.startIndex], count: 2)
            let g = String(repeating: s[s.index(s.startIndex, offsetBy: 1)], count: 2)
            let b = String(repeating: s[s.index(s.startIndex, offsetBy: 2)], count: 2)
            return Color(.sRGB,
                         red: d(Substring(r)), green: d(Substring(g)), blue: d(Substring(b)),
                         opacity: alpha)
        case 6:
            let r = d(s.prefix(2))
            let g = d(s.dropFirst(2).prefix(2))
            let b = d(s.dropFirst(4).prefix(2))
            return Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
        case 8:
            let a = d(s.prefix(2))
            let r = d(s.dropFirst(2).prefix(2))
            let g = d(s.dropFirst(4).prefix(2))
            let b = d(s.dropFirst(6).prefix(2))
            return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
        default:
            return Color(.sRGB, red: 0, green: 0, blue: 0, opacity: alpha)
        }
    }
}

// 角丸を4隅別々に指定できる Shape
struct KZBRoundedRect: InsettableShape {
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var bottomRight: CGFloat = 0
    var insetAmount: CGFloat = 0
    
    init(topLeft: CGFloat = 0, topRight: CGFloat = 0,
         bottomLeft: CGFloat = 0, bottomRight: CGFloat = 0) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
    
    func inset(by amount: CGFloat) -> KZBRoundedRect {
        var c = self; c.insetAmount += amount; return c
    }
    
    func path(in rect: CGRect) -> Path {
        var tl = max(0, topLeft - insetAmount)
        var tr = max(0, topRight - insetAmount)
        var bl = max(0, bottomLeft - insetAmount)
        var br = max(0, bottomRight - insetAmount)
        let maxR = min(rect.width, rect.height) / 2
        tl = min(tl, maxR); tr = min(tr, maxR); bl = min(bl, maxR); br = min(br, maxR)
        
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                 radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                 radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                 radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                 radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// zindexIfNeeded
extension View {
    func zindexIfNeeded(_ value: Double) -> some View { self.zIndex(value) }
    func zindexIfNeeded(_ enabled: Bool, value: Double = 1000) -> some View { self.zIndex(enabled ? value : 0) }
}

//#if DEBUG
///// プレビュー専用のモック
//final class MockBoardsService: BoardsService, BoardsCategoriesService, BoardsCreateService {
//    func fetchBoards(
//        sort: BoardSort,
//        categoryId: Int?,
//        page: Int,
//        perPage: Int
//    ) async throws -> PagedResponse<BoardDTO> {
//        let items: [BoardDTO] = (0..<6).map { i in
//            BoardDTO(
//                id: i + 1,
//                description: "プレビュー用の投稿 \(i + 1)（\(sort.rawValue)）",
//                location: .init(name: "千里山キャンパス", lat: 34.77, lng: 135.51),
//                favorite_count: Int.random(in: 0..<50),
//                view_count: Int.random(in: 50..<999),
//                author: .init(id: nil, uid: nil, name: "User \(i + 1)"),
//                category: .init(id: 1, name: "サークル募集", sort_order: 1),
//                created_at: ISO8601DateFormatter().string(from: Date()),
//                is_favorited: false,
//                photo_url: nil
//            )
//        }
//        return .init(data: items, meta: .init(page: page, per_page: perPage, total: 60))
//    }
//
//    // カテゴリ一覧（名称→ID 突合用）
//    func fetchCategories() async throws -> [BoardDTO.Category] {
//        return [
//            .init(id: 1, name: "サークル募集", sort_order: 1),
//            .init(id: 2, name: "就活情報", sort_order: 2),
//            .init(id: 3, name: "イベント", sort_order: 3),
//            .init(id: 4, name: "バイト求人", sort_order: 4),
//            .init(id: 5, name: "IT便利ツール", sort_order: 5),
//            .init(id: 6, name: "関大インフルエンサー", sort_order: 6),
//            .init(id: 99, name: "その他", sort_order: 999)
//        ]
//    }
//
//    // 新規作成（プレビュー用ダミー）
//    func createBoard(categoryId: Int, description: String,
//                     linkURL: String?, locationName: String?,
//                     locationLat: Double?, locationLng: Double?,
//                     photo: BoardPhoto?) async throws -> BoardDTO {
//        return BoardDTO(
//            id: Int.random(in: 1000...9999),
//            description: description,
//            location: .init(name: locationName, lat: locationLat, lng: locationLng),
//            favorite_count: 0,
//            view_count: 0,
//            author: .init(id: nil, uid: nil, name: "You"),
//            category: .init(id: categoryId, name: "その他", sort_order: nil),
//            created_at: ISO8601DateFormatter().string(from: Date()),
//            is_favorited: false,
//            photo_url: nil
//        )
//    }
//}
//
///// KeizibanView のプレビュー
//struct KeizibanView_Previews: PreviewProvider {
//    static var previews: some View {
//        KeizibanView(vm: BoardsViewModel(kzbService: MockBoardsService()))
//            .previewDisplayName("KeizibanView / Mock")
//    }
//}
//#endif

// 実APIで動かしたい Preview（Mock 不使用）
#Preview("KeizibanView / Live API") {
    let api = BoardsAPI(
        baseURL: URL(string: "https://map-ch.com/api/v1")!
    )
    let vm = BoardsViewModel(kzbService: api)
    KeizibanView(vm: vm)   // ← 最後の式をそのまま置く
}
