// NeoIntroView.swift
// 近未来感・今風の起動アニメ（SwiftUIのみ / 依存なし）
// - ネオングラデーション + スキャンライン + サイバーグリッド
// - ロゴのホログラム的出現（グロー/ブラー/拡大縮小）
// - 数字レイン風の粒子
// - フェード＋クロスズームで Map に無縁（白帯なし）で遷移
// iOS 16+（Canvas/TimelineView使用）

import SwiftUI
import MapKit

// MARK: - ルーター（Intro→Map）
struct NeoRootView: View {
    @State private var showIntro = true
    var body: some View {
        ZStack {
            SpotsMapView()
                .ignoresSafeArea()                 // ← 白縁対策：先に全面で置いておく
                .opacity(showIntro ? 0 : 1)
                .animation(.easeOut(duration: 0.45), value: showIntro)
            
            if showIntro {
                NeoIntroView(onFinished: {
                    withAnimation(.easeInOut(duration: 0.45)) { showIntro = false }
                })
                .transition(.opacity)
                .ignoresSafeArea()
            }
        }
        .background(Color.black.ignoresSafeArea()) // ← 最背面を黒で固定
    }
}

// MARK: - 本体
struct NeoIntroView: View {
    var onFinished: () -> Void
    
    @State private var t: Double = 0
    @State private var appear = false
    @State private var reveal = false
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                // 1) 背景（ネオングラデーション + スキャンライン）
                NeonGradient(t: now)
                Scanlines(t: now)
                
                // 2) サイバーグリッド（パース付き）
                CyberGrid(t: now)
                    .blendMode(.plusLighter)
                    .opacity(0.75)
                
                // 3) 数字レイン風のパーティクル
                MatrixDigits(t: now)
                    .blendMode(.screen)
                    .opacity(0.8)
                
                // 4) ロゴ（ホログラム出現）
                VStack(spacing: 14) {
                    ZStack {
                        // グロー層
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 120, weight: .regular))
                            .foregroundStyle(.white)
                            .blur(radius: 18)
                            .opacity(appear ? 0.45 : 0.0)
                            .scaleEffect(appear ? 1.0 : 0.8)
                        // 本体
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 90, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .cyan)
                            .scaleEffect(appear ? 1.0 : 0.92)
                            .rotation3DEffect(.degrees(appear ? 0 : -18), axis: (x: 1, y: 0, z: 0))
                            .shadow(color: .cyan.opacity(0.55), radius: 20, y: 8)
                    }
                    .animation(.spring(response: 0.65, dampingFraction: 0.82), value: appear)
                    
                    Text("MAP CHANNEL")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(3)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 10)
                        .overlay(
                            Text("MAP CHANNEL")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .tracking(3)
                                .foregroundStyle(.cyan.opacity(0.8))
                                .blur(radius: 6)
                                .opacity(appear ? 1 : 0)
                        )
                }
                
                // 5) 下部の細いロードバー（サイバー風）
                VStack { Spacer()
                    HoloProgress(progress: min(1, max(0, (now - t) / 2.0)))
                        .frame(height: 3)
                        .padding(.horizontal, 48)
                        .padding(.bottom, 28)
                }
            }
            .onAppear { t = now; withAnimation { appear = true } }
            .onChange(of: now) { _, new in
                // 2.2秒後に終了
                if !reveal && (new - t) > 2.2 {
                    reveal = true
                    onFinished()
                }
            }
        }
        // 無縁で消える（Intro側だけをズーム）
        .scaleEffect(reveal ? 1.05 : 1)
        .opacity(reveal ? 0 : 1)
        .animation(.easeInOut(duration: 0.55), value: reveal)
        .background(Color.black)
    }
}

// MARK: - 背景グラデーション
private struct NeonGradient: View {
    let t: Double
    var body: some View {
        ZStack {
            AngularGradient(
                colors: [
                    Color.cyan, Color.blue, Color.purple, Color.pink,
                    Color.orange, Color.yellow, Color.green, Color.cyan
                ],
                center: .center,
                startAngle: .degrees(t * 12),
                endAngle: .degrees(t * 12 + 300)
            )
            .saturation(1.2)
            .brightness(0.02)
            .blur(radius: 50)
            
            RadialGradient(colors: [ .white.opacity(0.18), .clear ],
                           center: .init(x: 0.3 + 0.2 * sin(t*0.6), y: 0.35),
                           startRadius: 10, endRadius: 420)
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}

// MARK: - スキャンライン
private struct Scanlines: View {
    let t: Double
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(colors: [
                    .white.opacity(0.02), .clear, .white.opacity(0.02)
                ], startPoint: .top, endPoint: .bottom)
            )
            .mask(
                GeometryReader { geo in
                    let h = geo.size.height
                    Canvas { ctx, size in
                        let rows = Int(h / 4)
                        for i in 0..<rows {
                            let y = CGFloat(i) * 4 + CGFloat((t*80).truncatingRemainder(dividingBy: 4))
                            ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white))
                        }
                    }
                }
            )
            .blendMode(.plusLighter)
            .ignoresSafeArea()
    }
}

// MARK: - サイバーグリッド（遠近）
private struct CyberGrid: View {
    let t: Double
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, _ in
                ctx.translateBy(x: size.width/2, y: size.height*0.62)
                // 角度と奥行き
                let tilt: CGFloat = .pi/2.8
                let depth: CGFloat = 520
                // 横線（遠近）
                let rows = 28
                for i in 0..<rows {
                    let z = CGFloat(i) / CGFloat(rows)
                    let y = -depth * pow(1 - z, 2)
                    var path = Path()
                    path.move(to: CGPoint(x: -size.width, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(path, with: .color(.cyan.opacity(0.25)), lineWidth: z < 0.1 ? 1.2 : 0.8)
                }
                // 縦線（斜め）
                let cols = 18
                for c in 0..<cols {
                    let x = CGFloat(c - cols/2) * 40 + CGFloat(sin(t*1.2 + Double(c))*6)
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: -depth))
                    path.addLine(to: CGPoint(x: x, y: 10))
                    ctx.stroke(path, with: .color(.cyan.opacity(0.22)), lineWidth: 0.7)
                }
                // フチのネオン
                var border = Path()
                border.addRoundedRect(in: CGRect(x: -size.width*0.46, y: -depth*0.86, width: size.width*0.92, height: depth*0.9), cornerSize: .init(width: 22, height: 22))
                ctx.stroke(border, with: .color(.cyan.opacity(0.18)), lineWidth: 1.0)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 数字レイン風
private struct MatrixDigits: View {
    let t: Double
    let count = 80
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                for i in 0..<count {
                    var rng = SeededRandom(seed: UInt64(i*9973))
                    let x = Double.random(in: 0...Double(size.width), using: &rng)
                    let phase = Double.random(in: 0...(2*Double.pi), using: &rng)
                    let speed = Double.random(in: 30...80, using: &rng)
                    let len = Double.random(in: 20...120, using: &rng)
                    let head = fmod(t * speed + phase, Double(size.height) + len)
                    let rect = CGRect(x: x, y: head-len, width: 1.2, height: len)
                    ctx.fill(Path(rect), with: .linearGradient(
                        Gradient(colors: [.clear, .white.opacity(0.9), .cyan.opacity(0.6), .clear]),
                        startPoint: CGPoint(x: x, y: rect.minY),
                        endPoint: CGPoint(x: x, y: rect.maxY)
                    ))
                }
            }
        }
        .opacity(0.6)
        .blur(radius: 0.3)
        .ignoresSafeArea()
    }
}

// MARK: - サイバー風プログレスバー
private struct HoloProgress: View {
    var progress: Double // 0..1
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: [.white, .cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, w*progress))
                    .shadow(color: .cyan.opacity(0.8), radius: 6, y: 0)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(.white)
                            .frame(width: 2)
                            .offset(x: -1)
                            .opacity(progress > 0 ? 1 : 0)
                    }
            }
        }
        .clipShape(Capsule())
    }
}

// MARK: - 乱数（再現性あり）
private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - プレビュー
#Preview("Neo Intro → Map") {
    NeoRootView()
        .environment(\.colorScheme, .dark)
}

