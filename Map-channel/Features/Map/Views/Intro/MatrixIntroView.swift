import SwiftUI

// MARK: - Public Gate (最短時間 + 外部のロード完了で閉じる)
struct MatrixIntroGate: View {
    var isDataReady: Bool
    var minDuration: TimeInterval = 2.0
    
    @State private var minDone = false
    @State private var vanished = false
    
    var body: some View {
        Group {
            if !vanished {
                MatrixIntroView()
                    .transition(.opacity.animation(.easeOut(duration: 0.45)))
            }
        }
        .allowsHitTesting(!vanished) // ← 消えたらタップを通す
        .task {
            // 最低表示時間を満たしたらチェック
            try? await Task.sleep(nanoseconds: UInt64(minDuration * 1_000_000_000))
            minDone = true
            await checkAndVanish()
        }
        .onChange(of: isDataReady) { _ in
            Task { await checkAndVanish() }
        }
    }
    
    @MainActor
    private func checkAndVanish() async {
        guard !vanished, minDone, isDataReady else { return }
        withAnimation(.easeInOut(duration: 0.45)) { vanished = true }
    }
}

// MARK: - Main Intro View
private struct MatrixIntroView: View {
    @State private var bootProgress: Double = 0.0   // 0.0〜1.0：タイプライタ進捗
    @State private var bootFinished: Bool = false   // テキスト完了フラグ
    
    var body: some View {
        ZStack {
            // 1) 背景：漆黒
            Color.black.ignoresSafeArea()
            
            // 2) ネオングリッド（遠近）
            NeonGridLayer()
                .blendMode(.screen)
                .opacity(0.25)
            
            // 3) デジタルレイン
            DigitalRainLayer()
                .blendMode(.screen)
                .opacity(0.95)
            
            // 4) スキャンライン + ノイズ
            ScanlineNoiseLayer()
                .allowsHitTesting(false)
            
            // 5) 中央HUD：タイトル + タイプライターログ + プログレス
            VStack(spacing: 16) {
                // ロゴ
                VStack(spacing: 6) {
                    Text("MAP:CHANNEL")
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hue: 0.35, saturation: 1, brightness: 0.85)) // ネオングリーン
                        .shadow(color: .green.opacity(0.35), radius: 8, y: 0)
                    Text("Initializing geospatial stack...")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.75))
                }
                .padding(.top, 6)
                
                // タイプライターログ（擬似ブート）→ 進捗コールバック
                BootLogView(
                    lines: [
                        "[OK]  Linking tileset shaders",
                        "[OK]  Compiling symbol layers",
                        "[OK]  Establishing data channels",
                        "[OK]  Warming glyph atlas",
                        "[OK]  Requesting visible bounds"
                    ],
                    speed: 0.035,
                    onProgress: { p in
                        withAnimation(.easeInOut(duration: 0.18)) { bootProgress = p }
                    },
                    onCompleted: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            bootFinished = true
                            bootProgress = 1.0
                        }
                    }
                )
                .frame(maxWidth: 420)
                
                // プログレスバー：タイプライタ進捗と完全同期
                MatrixProgressBar(progress: bootProgress)
                    .frame(width: 300, height: 6)
                    .padding(.top, 6)
                    .accessibilityLabel("Initialization progress")
                    .accessibilityValue("\(Int(bootProgress * 100)) percent")
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Digital Rain
private struct DigitalRainLayer: View {
    @State private var seed: UInt64 = .random(in: .min ... .max)
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                drawDigitalRain(ctx: &ctx, size: size, time: t, seed: seed)
            }
        }
        .onTapGesture { seed = .random(in: .min ... .max) } // 叩くと乱数シード更新（開発用）
    }
    
    private func drawDigitalRain(ctx: inout GraphicsContext, size: CGSize, time: TimeInterval, seed: UInt64) {
        let colW: CGFloat = 14
        let cols = Int(ceil(size.width / colW))
        
        let glyphs: [String] = {
            let kata = "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝ"
            let nums = "0123456789"
            let syms = "#$%&*+-/<>"
            return Array((kata + kata + nums + syms)).map { String($0) }
        }()
        let font = Font.system(size: 12, weight: .regular, design: .monospaced)
        
        for c in 0..<cols {
            let cx = (CGFloat(c) + 0.5) * colW
            let r = rand01(hash: seed &+ UInt64(c) &+ UInt64(time * 60))
            let speed = CGFloat(80 + 180 * r)      // px/sec
            let trail = Int(10 + 22 * r)           // 尾の長さ（文字数）
            let y = (CGFloat(time) * speed + CGFloat(c) * 200).truncatingRemainder(dividingBy: (size.height + 300)) - 150
            
            for i in 0..<trail {
                let gy = y - CGFloat(i) * 16
                guard gy > -24, gy < size.height + 24 else { continue }
                let g = glyphs[Int((UInt64(i) &+ UInt64(c * 131)) % UInt64(glyphs.count))]
                let text = Text(g).font(font)
                let headAlpha = max(0, 1 - CGFloat(i) * 0.06)
                let color = i == 0
                ? Color(hue: 0.31, saturation: 1.0, brightness: 1.0)  // ヘッド
                : Color(hue: 0.33, saturation: 0.9, brightness: 0.65).opacity(0.85 * headAlpha)
                ctx.draw(text.foregroundStyle(color), at: CGPoint(x: cx, y: gy), anchor: .center)
            }
            
            if Int(time * 10 + Double(c)).isMultiple(of: 37) {
                let gy = y - 32
                let w: CGFloat = .random(in: 24...80)
                var p = Path()
                p.addRect(CGRect(x: cx - w/2, y: gy, width: w, height: 1))
                ctx.fill(p, with: .color(.green.opacity(0.15)))
            }
        }
    }
    
    private func rand01(hash: UInt64) -> CGFloat {
        var x = hash &* 0x9E3779B97F4A7C15
        x ^= x >> 33
        x &*= 0xC2B2AE3D27D4EB4F
        x ^= x >> 29
        return CGFloat((x & 0xFFFF) % 1000) / 1000.0
    }
}

// MARK: - Neon Grid (遠近感あるワイヤーフレーム)
private struct NeonGridLayer: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                drawGrid(ctx: &ctx, size: size, time: t)
            }
        }
    }
    
    private func drawGrid(ctx: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let base = Path { p in
            let rows = 12
            for i in 0...rows {
                let yy = CGFloat(i) / CGFloat(rows)
                let y = size.height * (0.55 + pow(yy, 2.2) * 0.45)
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
            }
            let cols = 16
            for i in 0...cols {
                let xx = CGFloat(i) / CGFloat(cols)
                let x = size.width * xx
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: size.width/2 + (x - size.width/2) * 0.2, y: size.height * 0.42))
            }
        }
        let pulse = 0.6 + 0.4 * CGFloat(sin(time * 1.8))
        let neon = Color(hue: 0.35, saturation: 1, brightness: 1)
        ctx.stroke(base, with: .color(neon.opacity(0.12 + 0.06 * pulse)), lineWidth: 1)
        ctx.addFilter(.blur(radius: 2))
        ctx.stroke(base, with: .color(neon.opacity(0.08)), lineWidth: 1)
    }
}

// MARK: - Scanlines + Subtle Noise
private struct ScanlineNoiseLayer: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let spacing: CGFloat = 3
                var path = Path()
                var y: CGFloat = 0
                while y < size.height {
                    path.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
                    y += spacing
                }
                ctx.fill(path, with: .color(.white.opacity(0.05)))
                
                let bandY = (CGFloat(t).truncatingRemainder(dividingBy: 3)) / 3 * size.height
                let bandRect = CGRect(x: 0, y: bandY, width: size.width, height: 60)
                ctx.fill(
                    Path(bandRect),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .green.opacity(0.10), location: 0.5),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: CGPoint(x: 0, y: bandRect.minY),
                        endPoint: CGPoint(x: 0, y: bandRect.maxY)
                    )
                )
            }
        }
        .blendMode(.plusLighter)
    }
}

// MARK: - Typewriter Boot Logs
private struct BootLogView: View {
    let lines: [String]
    let speed: Double // 1文字あたり秒
    var onProgress: (Double) -> Void
    var onCompleted: () -> Void
    
    @State private var shownCount: Int = 0
    @State private var textProgress: Int = 0
    @State private var timer: Timer? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<shownCount, id: \.self) { i in
                Text(lines[i])
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.85))
            }
            if shownCount < lines.count {
                let current = lines[shownCount]
                let prefix = String(current.prefix(textProgress))
                Text(prefix + "▌")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.green)
            }
        }
        .onAppear { start() }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func start() {
        timer?.invalidate()
        guard !lines.isEmpty else {
            onProgress(1.0); onCompleted()
            return
        }
        
        // 事前計算：各行の文字数と合計
        let lens = lines.map { $0.count }
        let total = max(1, lens.reduce(0, +))
        
        var idx = 0            // 現在の行
        var char = 0           // 現在行のカーソル位置
        var doneBefore = 0     // これまでに確定表示された総文字数
        
        timer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { t in
            if idx >= lines.count {
                t.invalidate()
                onProgress(1.0)
                onCompleted()
                return
            }
            
            let currentLen = lens[idx]
            if char < currentLen {
                char += 1
                textProgress = char
                let typedGlobal = doneBefore + char
                onProgress(min(1.0, Double(typedGlobal) / Double(total)))
            } else {
                // 行を確定 → 次の行へ
                shownCount = idx + 1
                doneBefore += currentLen
                char = 0
                textProgress = 0
                idx += 1
                // 行確定時点でも進捗を通知（段差が出ないよう補正）
                onProgress(min(1.0, Double(doneBefore) / Double(total)))
                
                // すべて完了した瞬間
                if idx >= lines.count {
                    t.invalidate()
                    onProgress(1.0)
                    onCompleted()
                }
            }
        }
    }
}

// MARK: - Progress Bar (外部進捗を描画)
private struct MatrixProgressBar: View {
    var progress: Double // 0.0〜1.0
    
    var body: some View {
        GeometryReader { geo in
            let clamped = max(0, min(1, progress))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(0.15))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green)
                    .frame(width: geo.size.width * clamped)
                    .shadow(color: .green.opacity(0.6 * clamped), radius: 8, x: 0, y: 0)
            }
            .animation(.easeInOut(duration: 0.18), value: clamped)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(height: 6)
    }
}

#if DEBUG
// MARK: - SwiftUI Previews (このファイル単体で完結)

// 1) 純粋にアニメ層だけを見るプレビュー
#Preview("Matrix Intro (Animation Only)") {
    MatrixIntroView()
        .ignoresSafeArea()
}

// 2) ゲートが即時に閉じる（isDataReady = true）ケース
#Preview("Gate - Ready Immediately") {
    ZStack {
        LinearGradient(colors: [.black, .green.opacity(0.2)], startPoint: .top, endPoint: .bottom)
        MatrixIntroGate(isDataReady: true, minDuration: 0.8)
    }
    .ignoresSafeArea()
}

// 3) ゲートが遅延で閉じる（2秒後に isDataReady = true）
#Preview("Gate - Delayed Ready (2s)") {
    MatrixIntroDelayedPreview()
        .ignoresSafeArea()
}

/// プレビュー専用：2秒後に isReady を true にしてフェードアウトを確認
private struct MatrixIntroDelayedPreview: View {
    @State private var ready = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .green.opacity(0.25)],
                           startPoint: .top, endPoint: .bottom)
            MatrixIntroGate(isDataReady: ready, minDuration: 1.2)
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            ready = true
        }
    }
}
#endif

