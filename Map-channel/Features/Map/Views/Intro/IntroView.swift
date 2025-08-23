//  IntroView.swift
//  Map-channel
//
//  A clean, modern launch animation (SwiftUI, iOS 16+/17+)

import SwiftUI
import MapKit

// MARK: - Root coordinator
struct RootView: View {
    @State private var showIntro = true

    var body: some View {
        ZStack {
            SpotsMapView()
                .ignoresSafeArea()                 // ← 追加：全面描画
                .opacity(showIntro ? 0 : 1)
                // .scaleEffect(showIntro ? 1.02 : 1)  // ← 外す（白縁が見えやすくなるため）
                .animation(.easeOut(duration: 0.45), value: showIntro)

            if showIntro {
                LaunchIntroView {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        showIntro = false
                    }
                }
                .transition(.opacity)
            }
        }
        // 予防策として背景も敷いておくとより堅牢
        .background(Color.black.ignoresSafeArea())  // ← 追加（任意）
    }
}

// MARK: - Launch / Intro animation
struct LaunchIntroView: View {
    var onFinished: () -> Void
    
    @State private var appear = false
    @State private var reveal = false
    
    // 表示時間
    private let totalDuration: TimeInterval = 2.4
    
    var body: some View {
        ZStack {
            RotatingGradient()
                .ignoresSafeArea()
            
            // 軽量パーティクル
            SparkleField()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            
            VStack(spacing: 14) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 84, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.55))
                    .scaleEffect(appear ? 1 : 0.72)
                    .rotation3DEffect(.degrees(appear ? 0 : -14), axis: (x: 1, y: 0, z: 0))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appear)
                
                Text("Map-channel")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                
                Text("あなたの“いま”を地図に刻む")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)
                    .animation(.easeOut(duration: 0.6).delay(0.08), value: appear)
            }
            .padding(.horizontal, 24)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("Loading…")
                    .foregroundStyle(.white.opacity(0.85))
                    .font(.subheadline)
            }
            .padding(.bottom, 40)
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.3), value: appear)
        }
        .task {
            appear = true
            try? await Task.sleep(nanoseconds: UInt64(totalDuration * 1_000_000_000))
            withAnimation(.easeInOut(duration: 0.6)) { reveal = true }
            onFinished()
        }
        .scaleEffect(reveal ? 1.02 : 1)
        .opacity(reveal ? 0 : 1)
        .animation(.easeInOut(duration: 0.6), value: reveal)
        .preferredColorScheme(.dark)    // ダークで映える
    }
}

// MARK: - 背景：ゆっくり回転するグラデーション
private struct RotatingGradient: View {
    @State private var angle: Angle = .degrees(0)
    var body: some View {
        TimelineView(.animation) { _ in
            Rectangle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(#colorLiteral(red: 0.38, green: 0.53, blue: 0.98, alpha: 1)),
                            Color(#colorLiteral(red: 0.36, green: 0.86, blue: 0.98, alpha: 1)),
                            Color(#colorLiteral(red: 0.45, green: 0.94, blue: 0.76, alpha: 1)),
                            Color(#colorLiteral(red: 0.78, green: 0.95, blue: 0.62, alpha: 1)),
                            Color(#colorLiteral(red: 0.96, green: 0.73, blue: 0.53, alpha: 1)),
                            Color(#colorLiteral(red: 0.89, green: 0.54, blue: 0.69, alpha: 1)),
                            Color(#colorLiteral(red: 0.66, green: 0.45, blue: 0.90, alpha: 1))
                        ]),
                        center: .center
                    )
                )
                .overlay(Rectangle().fill(.black.opacity(0.25)))
                .rotationEffect(angle)
                .task {
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                        angle = .degrees(360)
                    }
                }
        }
    }
}

// MARK: - 軽量パーティクル（Canvas）
private struct SparkleField: View {
    @State private var time: Double = 0
    private let count = 60
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let dt = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                time = dt
                for i in 0..<count {
                    var rng = SeededRandom(seed: UInt64(i) * 9973)
                    let x = Double.random(in: 0...Double(size.width), using: &rng)
                    let baseY = Double.random(in: 0...Double(size.height), using: &rng)
                    let speed = Double.random(in: 10...30, using: &rng)
                    let amp = Double.random(in: 8...22, using: &rng)
                    let phase = Double.random(in: 0...(.pi * 2), using: &rng)
                    
                    let y = baseY + sin((dt + phase) * speed / 30.0) * amp
                    let r = Double.random(in: 1.5...3.8, using: &rng)
                    let alpha = 0.20 + 0.15 * sin((dt + Double(i)) * 2.0)
                    let rect = CGRect(x: x, y: y, width: r*2, height: r*2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .blendMode(.screen)
    }
}

// MARK: - Utilities
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

// MARK: - Preview
#Preview("Intro → Map") {
    RootView()
        .environment(\.colorScheme, .dark)  // ← 修正ポイント（_colorScheme ではない）
}

