//
//  ShopView.swift
//  Map-channel
//
//  Created by user on 2025/08/24.
//

import SwiftUI

// MARK: - メインビュー
struct ShopView: View {
    @State private var selectedTab: ShopTab = .items
    @State private var currentPoints: Int = 1500
    @State private var showingAdBanner = false
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            ShopHeaderView(currentPoints: currentPoints)
            
            // タブビュー
            ShopTabBar(selectedTab: $selectedTab)
            
            // コンテンツ
            ScrollView {
                switch selectedTab {
                case .items:
                    ItemsTabView()
                case .decoration:
                    DecorationTabView()
                case .gacha:
                    GachaTabView()
                case .premium:
                    PremiumTabView(showingAdBanner: $showingAdBanner)
                }
            }
            .background(Color(UIColor.systemGray6))
        }
        .sheet(isPresented: $showingAdBanner) {
            AdBannerDetailView()
        }
    }
}

// MARK: - タブ列挙型
enum ShopTab: String, CaseIterable {
    case items = "アイテム"
    case decoration = "装飾"
    case gacha = "ガチャ"
    case premium = "プレミアム"
}

// MARK: - ヘッダービュー
struct ShopHeaderView: View {
    let currentPoints: Int
    
    var body: some View {
        HStack {
            Button(action: {
                // 戻るボタンの処理
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18))
                    Text("ホーム")
                        .font(.system(size: 16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                )
            }
            
            Spacer()
            
            Text("MAPCHショップ")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Image(systemName: "diamond.fill")
                .foregroundColor(.blue)
                .font(.system(size: 20))
            
            Spacer()
            
            HStack(spacing: 8) {
                Text("\(currentPoints) P")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.2))
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "4CAF50"), Color(hex: "66BB6A")]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

// MARK: - タブバー
struct ShopTabBar: View {
    @Binding var selectedTab: ShopTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ShopTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring()) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 16, weight: selectedTab == tab ? .bold : .regular))
                            .foregroundColor(selectedTab == tab ? Color(hex: "4CAF50") : .gray)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color(hex: "4CAF50") : Color.clear)
                            .frame(height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .background(Color.white)
    }
}

// MARK: - アイテムタブ
struct ItemsTabView: View {
    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // メガホン
                ShopItemCard(
                    icon: "megaphone.fill",
                    title: "メガホン",
                    description: "流れコメントで大きく強調した文字を打てる",
                    price: 150,
                    inventory: 2,
                    iconColor: .gray
                )
                
                // 修正ペン
                ShopItemCard(
                    icon: "pencil",
                    title: "修正ペン",
                    description: "Mapの位置情報を修正できる",
                    price: 250,
                    inventory: 0,
                    iconColor: .orange
                )
                
                // ハンマー
                ShopItemCard(
                    icon: "hammer.fill",
                    title: "ハンマー",
                    description: "Mapの位置情報を壊すことができる。申請用。",
                    price: 300,
                    inventory: 1,
                    iconColor: .gray
                )
                
                // 複数登録チケット
                VIPItemCard(
                    title: "複数登録チケット",
                    description: "1日3回まで登録できる制限を超えて複数のピンを一度に登録できる",
                    price: 3000,
                    inventory: 0
                )
            }
            
            // ピン強調チケット
            ShopItemCard(
                icon: "mappin",
                title: "ピン強調チケット",
                description: "Mapのピンを1週間強調できる",
                price: 300,
                inventory: 5,
                iconColor: .red,
                fullWidth: true
            )
            
            // 商品抽選券
            LotteryCard()
        }
        .padding()
    }
}

// MARK: - 装飾タブ
struct DecorationTabView: View {
    var body: some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                // ベーシックフレーム
                DecorationCard(
                    icon: "photo",
                    title: "ベーシックフレーム",
                    description: "シンプルなMapフレーム装飾",
                    price: 500,
                    isOwned: true
                )
                
                // プレミアムフレーム
                DecorationCard(
                    icon: "star.fill",
                    title: "プレミアムフレーム",
                    description: "豪華なMapフレーム装飾",
                    price: 1200,
                    isOwned: false,
                    iconColor: .yellow
                )
                
                // カラフルピン
                DecorationCard(
                    icon: "mappin",
                    title: "カラフルピン",
                    description: "カラフルなピンデザイン",
                    price: 300,
                    isOwned: true,
                    iconColor: .red
                )
                
                // ダイヤモンドピン
                DecorationCard(
                    icon: "diamond.fill",
                    title: "ダイヤモンドピン",
                    description: "高級感のあるピンデザイン",
                    price: 800,
                    isOwned: false,
                    iconColor: .cyan
                )
                
                // アイコンボーダー
                DecorationCard(
                    icon: "paintpalette.fill",
                    title: "アイコンボーダー",
                    description: "プロフィールアイコンの枠装飾",
                    price: 200,
                    isOwned: true
                )
                
                // キラキラエフェクト
                DecorationCard(
                    icon: "sparkles",
                    title: "キラキラエフェクト",
                    description: "アイコンにキラキラ効果を追加",
                    price: 600,
                    isOwned: false,
                    iconColor: .yellow
                )
                
                // ベーシックテーマ
                DecorationCard(
                    icon: "person.fill",
                    title: "ベーシックテーマ",
                    description: "プロフィールページの基本テーマ",
                    price: 400,
                    isOwned: false,
                    iconColor: .blue
                )
                
                // レインボーテーマ
                DecorationCard(
                    icon: "rainbow",
                    title: "レインボーテーマ",
                    description: "カラフルなプロフィールテーマ",
                    price: 1500,
                    isOwned: false,
                    isHighlighted: true
                )
            }
        }
        .padding()
    }
}

// MARK: - ガチャタブ
struct GachaTabView: View {
    var body: some View {
        VStack(spacing: 20) {
            // 単発ガチャ
            GachaCard(
                title: "単発ガチャ",
                price: 200,
                description: "アイテムがランダムで1個当たる",
                type: .single
            )
            
            // 5連ガチャ
            GachaCard(
                title: "5連ガチャ",
                price: 1000,
                description: "アイテムがランダムで5個当たる",
                type: .five,
                isRareUp: true
            )
            
            // 10連ガチャ
            GachaCard(
                title: "10連ガチャ",
                price: 2000,
                description: "アイテム10個 + 商品抽選券がもらえる！",
                type: .ten,
                isRareUp: true,
                hasBonus: true
            )
        }
        .padding()
    }
}

// MARK: - プレミアムタブ
struct PremiumTabView: View {
    @Binding var showingAdBanner: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // 広告バナー枠
            VStack(spacing: 12) {
                Image(systemName: "tv.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                
                Text("広告バナー枠")
                    .font(.system(size: 20, weight: .bold))
                
                Text("月額2万円（税込）")
                    .font(.system(size: 18))
                    .foregroundColor(.red)
                
                Text("アプリ内の各ページに広告バナーを掲載できます")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    showingAdBanner = true
                }) {
                    Text("募集中")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "66BB6A"))
                        .cornerRadius(25)
                }
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(20)
            
            // バトルパス
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "swords")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    
                    Text("バトルパス")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("月300円")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("特別なミッションとボーナスポイントが獲得できます")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                Button(action: {}) {
                    Text("購入する")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(20)
        }
        .padding()
    }
}

// MARK: - アイテムカード
struct ShopItemCard: View {
    let icon: String
    let title: String
    let description: String
    let price: Int
    let inventory: Int
    var iconColor: Color = .blue
    var fullWidth: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(iconColor)
            
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 8)
            
            Text("\(price)P")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.orange)
            
            Text("所持: \(inventory)個")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Button(action: {}) {
                Text("購入する")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "66BB6A"))
                    .cornerRadius(20)
            }
        }
        .padding()
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}

// MARK: - VIPアイテムカード
struct VIPItemCard: View {
    let title: String
    let description: String
    let price: Int
    let inventory: Int
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("LIVE\nCONCERT\nTICKET")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.black)
                    .padding(8)
                    .background(Color.yellow)
                    .cornerRadius(5)
                
                Image(systemName: "person.3.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
            }
            
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 8)
            
            Text("\(price)P")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.orange)
            
            Text("所持: \(inventory)個")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Button(action: {}) {
                Text("購入する")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "66BB6A"))
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}

// MARK: - 装飾カード
struct DecorationCard: View {
    let icon: String
    let title: String
    let description: String
    let price: Int
    let isOwned: Bool
    var iconColor: Color = .gray
    var isHighlighted: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(iconColor)
            
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text("\(price)P")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.orange)
            
            if isOwned {
                Text("所持済み")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "66BB6A"))
            } else {
                Text("未所持")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Button(action: {}) {
                Text("購入")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isOwned ? Color.gray : Color(hex: "66BB6A"))
                    .cornerRadius(20)
            }
            .disabled(isOwned)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .overlay(
            isHighlighted ?
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color(hex: "66BB6A"), lineWidth: 3)
            : nil
        )
        .shadow(radius: 2)
    }
}

// MARK: - ガチャカード
struct GachaCard: View {
    let title: String
    let price: Int
    let description: String
    let type: GachaType
    var isRareUp: Bool = false
    var hasBonus: Bool = false
    
    enum GachaType {
        case single, five, ten
        
        var icon: String {
            switch self {
            case .single: return "die.face.1.fill"
            case .five: return "die.face.5.fill"
            case .ten: return "diamond.fill"
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .single: return .white
            case .five: return .white
            case .ten: return Color(hex: "FFD700")
            }
        }
        
        var buttonColor: Color {
            switch self {
            case .single, .five: return Color(hex: "FF8C00")
            case .ten: return Color(hex: "FF8C00")
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: type.icon)
                .font(.system(size: 50))
                .foregroundColor(type == .ten ? .blue : .gray)
            
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
            
            Text("\(price)P")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.orange)
            
            if isRareUp {
                Text("レア確率アップ")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "66BB6A"))
            }
            
            if hasBonus {
                Text("+ 商品抽選券1枚")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(action: {}) {
                Text("ガチャを引く")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(type.buttonColor)
                    .cornerRadius(25)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(type.backgroundColor)
        .cornerRadius(20)
        .shadow(radius: type == .ten ? 5 : 2)
    }
}

// MARK: - 抽選券カード
struct LotteryCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 40))
                .foregroundColor(.white)
                .rotationEffect(.degrees(-15))
            
            Text("商品抽選券")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text("今後開催される商品券があたる抽選券のイベントで使用できるチケット")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("1000P")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("所持: 3個")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            Button(action: {}) {
                Text("購入する")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "66BB6A"))
                    .cornerRadius(25)
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "E53935"), Color(hex: "D32F2F")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(radius: 3)
    }
}

// MARK: - 広告バナー詳細ビュー
struct AdBannerDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("広告バナー枠について")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.top)
                    
                    Text("アプリ内の各ページに広告バナーを掲載いたします。")
                        .font(.system(size: 16))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("•")
                            Text("月額2万円（税込）")
                        }
                        HStack {
                            Text("•")
                            Text("バナーサイズ: 320×50px")
                        }
                        HStack {
                            Text("•")
                            Text("月間表示回数: 約10万回")
                        }
                        HStack {
                            Text("•")
                            Text("審査あり（3営業日以内）")
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    
                    Text("ご興味のある方はお気軽にお申し込みください。")
                        .font(.system(size: 14))
                        .padding(.top)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            // 申請処理
                        }) {
                            Text("申請する")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "66BB6A"))
                                .cornerRadius(25)
                        }
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("閉じる")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(25)
                        }
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
struct ShopView_Previews: PreviewProvider {
    static var previews: some View {
        ShopView()
    }
}
