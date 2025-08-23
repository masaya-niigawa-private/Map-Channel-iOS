//
//  CinematicIntroView.swift
//  Map-channel
//

import SwiftUI
import UIKit   // ハプティクス

// MARK: - App ルート（Intro → Map 出し分け）
struct AppRootView<MapContent: View>: View {
    enum Phase { case intro, ready }
    @State private var phase: Phase = .intro
    let mapContent: () -> MapContent
    
    var body: some View {
        ZStack {
            if phase == .ready {
                mapContent()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            if phase == .intro {
                CinematicIntroView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        phase = .ready
                    }
                }
                .transition(.opacity)
                .ignoresSafeArea()
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - メインのシネマティック・イントロ（フルスクリーン + 上下エッジ演出）
struct CinematicIntroView: View {
    var onFinished: () -> Void
    
    @State private var start = Date()
    @State private var logoIn: CGFloat = 0
    @State private var flash: CGFloat = 0
    
    private let totalDuration: TimeInterval = 3.2
    
    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let t: TimeInterval = timeline.date.timeIntervalSince(start)
                
                ZStack {
                    // 0) ベース背景
                    RadialGradient(
                        gradient: Gradient(colors: [
                            .black,
                            Color(hue: 0.60, saturation: 0.75, brightness: 0.12),
                            .black
                        ]),
                        center: .center,
                        startRadius: 20,
                        endRadius: 800
                    )
                    .opacity(0.9)
                    .ignoresSafeArea()
                    
                    // 1) 六角グリッド（広域）
                    HexGridParallax(time: t)
                        .blendMode(.plusLighter)
                        .opacity(0.45)
                    
                    // 2) 光条（端まで届く）
                    LightRays(time: t)
                        .blendMode(.screen)
                        .opacity(0.65)
                    
                    // 3) 粒子（全面分布）
                    NebulaParticles(time: t)
                        .blendMode(.plusLighter)
                        .opacity(0.95)
                    
                    // 4) 上下エッジ・オーロラ（上端の非対称を解消）
                    EdgeAuroraLayer(time: t)
                        .blendMode(.screen)
                        .opacity(0.85)
                    
                    // 5) 中央ゲート
                    GateRings(progress: CGFloat(min(1.0, t / 1.6)))
                        .blendMode(.screen)
                        .opacity(0.9)
                    
                    // 6) ロゴ
                    NeonLogo(progress: logoIn)
                        .padding(.horizontal, 24)
                        .accessibilityHidden(true)
                }
                .overlay(
                    Color.white
                        .opacity(Double(flash))
                        .ignoresSafeArea()
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .onAppear { start = Date() }
        .task {
            // 0.6秒後にロゴ出現
            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run {
                withAnimation(.interpolatingSpring(stiffness: 220, damping: 20)) {
                    logoIn = 1
                }
            }
            // 白フラ → Map へ
            let remaining = max(0, totalDuration - 0.6)
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            await MainActor.run {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.easeIn(duration: 0.18)) { flash = 1 }
            }
            try? await Task.sleep(nanoseconds: 180_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.22)) { flash = 0 }
                onFinished()
            }
        }
    }
}

// MARK: - 近未来グリッド（六角形）
private struct HexGridParallax: View {
    let time: TimeInterval
    var body: some View {
        Canvas { ctx, size in
            let cell: CGFloat = 26
            let lineWidth: CGFloat = 0.7
            let cols: Int = Int(ceil(size.width / cell)) + 6
            let rows: Int = Int(ceil(size.height / (cell * 0.86))) + 6
            
            let driftX: CGFloat = CGFloat(sin(time * 0.35)) * 10
            let driftY: CGFloat = CGFloat(time) * 14
            
            var path = Path()
            for r in -3..<rows {
                for c in -3..<cols {
                    let x = (CGFloat(c) * cell)
                    + ((r % 2 == 0) ? 0 : cell * 0.5)
                    + driftX.truncatingRemainder(dividingBy: cell)
                    let y = (CGFloat(r) * cell * 0.86)
                    + driftY.truncatingRemainder(dividingBy: cell * 0.86)
                    path.addPath(hexPath(center: CGPoint(x: x, y: y), radius: cell * 0.55))
                }
            }
            
            let grad = Gradient(colors: [Color.cyan.opacity(0.25), Color.blue.opacity(0.10), .clear])
            ctx.stroke(
                path,
                with: .conicGradient(grad, center: CGPoint(x: size.width/2, y: size.height/2)),
                lineWidth: lineWidth
            )
        }
        .drawingGroup(opaque: false, colorMode: .linear)
    }
    
    private func hexPath(center: CGPoint, radius: CGFloat) -> Path {
        var p = Path()
        for i in 0..<6 {
            let a = CGFloat(i) * CGFloat.pi / 3.0
            let pt = CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - 光条
private struct LightRays: View {
    let time: TimeInterval
    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width/2, y: size.height/2)
            let diag: CGFloat = hypot(size.width, size.height)
            let rays: Int = max(80, Int(diag / 12.0))
            let base: Double = time * 0.7
            
            for i in 0..<rays {
                let a = (Double(i) / Double(rays)) * .pi * 2.0
                let wobble = sin(base + Double(i) * 0.73) * 0.2
                let angle = a + wobble
                
                var path = Path()
                path.move(to: center)
                
                let len: CGFloat = diag * (0.55 + CGFloat(sin(base * 1.8 + Double(i))) * 0.18)
                let end = CGPoint(x: center.x + len * CGFloat(cos(angle)),
                                  y: center.y + len * CGFloat(sin(angle)))
                path.addLine(to: end)
                
                let baseWidth: CGFloat = 0.25 + (CGFloat(sin(base*2 + Double(i)*1.1)) + 1) / 3.5
                let scale: CGFloat = max(1.0, diag / 1000.0)
                let lineWidth: CGFloat = baseWidth * scale
                
                ctx.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [Color.white.opacity(0.7), Color.cyan.opacity(0.0)]),
                        startPoint: center,
                        endPoint: end
                    ),
                    lineWidth: lineWidth
                )
            }
        }
        .blur(radius: 10)
    }
}

// MARK: - 粒子（全面分布）
private struct NebulaParticles: View {
    let time: TimeInterval
    var body: some View {
        Canvas { ctx, size in
            let cx: CGFloat = size.width  * 0.5
            let cy: CGFloat = size.height * 0.5
            let diag: CGFloat = hypot(size.width, size.height)
            let count: Int = max(220, Int(diag * 0.25))
            
            for i in 0..<count {
                let seed = Double(i)
                let baseAng  = seed*0.618*2*Double.pi + time*0.7 + sin(seed*1.31)*0.5
                let ringD   = 0.22*Double(diag) + sin(time*0.6 + seed)*0.10*Double(diag)
                + Double((i % 40)) * 1.6
                let x = cx + CGFloat(cos(baseAng) * ringD * 1.6) + CGFloat(sin(time*0.35 + seed) * 18.0)
                let y = cy + CGFloat(sin(baseAng) * ringD * 0.95)
                + (CGFloat(sin(time*0.9 + seed*0.4)) * diag * 0.02)
                
                let r: CGFloat = 1.8 + CGFloat(i % 7) * 0.6
                let pulse = (sin(time*1.3 + seed*0.9) + 1) * 0.5
                let alpha = 0.14 + 0.55 * pulse
                let hue   = 0.55 + 0.07 * sin(seed*0.2)
                
                let rect = CGRect(x: x - r, y: y - r, width: r*2, height: r*2)
                let col  = Color(hue: hue, saturation: 0.9, brightness: 1.0, opacity: alpha)
                ctx.fill(Path(ellipseIn: rect), with: .color(col))
            }
        }
        .blur(radius: 2)
        .drawingGroup(opaque: false, colorMode: .linear)
    }
}

// MARK: - 上下エッジ・オーロラ（上端の非対称を解消）
private struct EdgeAuroraLayer: View {
    let time: TimeInterval
    var body: some View {
        Canvas { ctx, size in
            let w: CGFloat = size.width
            let h: CGFloat = size.height
            let t: CGFloat = CGFloat(time)
            
            for band in 0..<4 {
                let bandF: CGFloat = CGFloat(band)
                let phase: CGFloat = t * (0.6 + 0.12 * bandF) + bandF * 0.8
                let amp: CGFloat   = 10 + bandF * 10
                let thick: CGFloat = max(60, h * 0.10) + bandF * 10
                let freq: CGFloat  = 2.0 + bandF * 0.6
                
                // --- TOP band（画面外から滑り込ませて下端と対称に）
                let baseTop: CGFloat = -thick * 0.6 + 12 * bandF
                let topPath = wavyBand(width: w,
                                       baseY: baseTop,
                                       thickness: thick,
                                       amp: amp, freq: freq, phase: phase,
                                       inverted: false)
                ctx.fill(
                    topPath,
                    with: .linearGradient(
                        Gradient(stops: [
                            // 画面最上端側（外側）を明るく、内側に向かってフェード
                            .init(color: .cyan.opacity(0.25), location: 0.0),
                            .init(color: .blue.opacity(0.18), location: 0.5),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: CGPoint(x: 0, y: baseTop),
                        endPoint: CGPoint(x: 0, y: baseTop + thick)
                    )
                )
                
                // --- BOTTOM band（従来と同じ式だが座標も帯基準に固定）
                let baseBottom: CGFloat = h - thick - 12 * bandF
                let bottomPath = wavyBand(width: w,
                                          baseY: baseBottom,
                                          thickness: thick,
                                          amp: amp, freq: freq, phase: -phase * 1.05,
                                          inverted: true)
                ctx.fill(
                    bottomPath,
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .blue.opacity(0.18), location: 0.5),
                            .init(color: .cyan.opacity(0.25), location: 1.0)
                        ]),
                        startPoint: CGPoint(x: 0, y: baseBottom),
                        endPoint: CGPoint(x: 0, y: baseBottom + thick)
                    )
                )
            }
        }
        .drawingGroup(opaque: false, colorMode: .linear)
    }
    
    // うねる帯シェイプ
    private func wavyBand(width: CGFloat, baseY: CGFloat, thickness: CGFloat,
                          amp: CGFloat, freq: CGFloat, phase: CGFloat, inverted: Bool) -> Path {
        var path = Path()
        let step: CGFloat = max(4.0, width / 120.0)
        func waveY(_ x: CGFloat) -> CGFloat {
            let p = (x / width) * CGFloat.pi * 2 * freq + phase
            return baseY + sin(p) * amp
        }
        // 上辺
        path.move(to: CGPoint(x: 0, y: waveY(0)))
        var x: CGFloat = 0
        while x <= width {
            path.addLine(to: CGPoint(x: x, y: waveY(x)))
            x += step
        }
        // 下辺（帯の厚み分ずらす）
        x = width
        while x >= 0 {
            let offset: CGFloat = inverted ? -thickness : thickness
            path.addLine(to: CGPoint(x: x, y: waveY(x) + offset))
            x -= step
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 中央ゲート
private struct GateRings: View {
    let progress: CGFloat // 0...1
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<3) { i in
                    let p = (progress - CGFloat(i) * 0.14).clamped01
                    RingGlow()
                        .stroke(style: StrokeStyle(lineWidth: 2 + p * 6, lineCap: .round))
                        .foregroundStyle(
                            AngularGradient(
                                gradient: Gradient(colors: [Color.cyan, .white, Color.blue, .cyan]),
                                center: .center
                            )
                        )
                        .scaleEffect(0.3 + 0.9 * p, anchor: .center)
                        .opacity(Double((1 - (p*0.9)).clamped01))
                        .blur(radius: (1 - p) * 3)
                }
            }
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private struct RingGlow: Shape {
        func path(in rect: CGRect) -> Path {
            Path(ellipseIn: rect.insetBy(dx: rect.width*0.18, dy: rect.height*0.18))
        }
    }
}

// MARK: - ネオンロゴ
private struct NeonLogo: View {
    let progress: CGFloat // 0→1
    private let title = "MAP-CHANNEL"
    private let subtitle = "Discover. Share. Explore."
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Text(title)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .cyan.opacity(0.6), radius: 20)
                    .shadow(color: .blue.opacity(0.3), radius: 40)
                
                LinearGradient(colors: [.cyan, .white, .blue],
                               startPoint: .leading, endPoint: .trailing)
                .mask(
                    Text(title)
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .tracking(6)
                )
                .opacity(0.8)
                
                Text(title)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.red.opacity(0.5))
                    .offset(x: -1, y: 0.5)
                    .blendMode(.plusLighter)
                
                Text(title)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.blue.opacity(0.5))
                    .offset(x: 1, y: -0.5)
                    .blendMode(.plusLighter)
            }
            .scaleEffect(0.82 + 0.18 * progress)
            .opacity(progress)
            
            Text(subtitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .tracking(1.2)
                .opacity(Double((progress - 0.25).clamped01))
                .offset(y: (CGFloat(1) - progress).clamped01 * 8)
        }
    }
}

// MARK: - Helpers
private extension CGFloat {
    var clamped01: CGFloat { Swift.min(1, Swift.max(0, self)) }
}

#if DEBUG
// =====================
// MARK: - Previews
// =====================

// 1) イントロ演出だけを確認
#Preview("Intro Only") {
    CinematicIntroView { /* no-op */ }
        .ignoresSafeArea()
        .background(.black)
}

// 2) イントロ→マップの遷移を確認（モック地図）
#Preview("AppRoot Transition (Mock Map)") {
    AppRootView {
        MockMapView()
    }
    .ignoresSafeArea()
}

// 3) ループ試験：一定間隔で再実行
#Preview("Intro Loop Host") {
    IntroLoopHost()
        .ignoresSafeArea()
        .background(.black)
}

// プレビュー用の簡易“地図”ダミー
private struct MockMapView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.green.opacity(0.25)],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 48, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
                Text("Mock Map")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green.opacity(0.9))
            }
        }
    }
}

// イントロを繰り返し確認するためのホスト
private struct IntroLoopHost: View {
    @State private var token = UUID()
    var body: some View {
        VStack(spacing: 0) {
            CinematicIntroView {
                Task {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    await MainActor.run { token = UUID() }
                }
            }
            .id(token)
        }
    }
}
#endif

