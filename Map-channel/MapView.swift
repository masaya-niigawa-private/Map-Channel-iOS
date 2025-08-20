import SwiftUI
import MapKit
import UIKit

// =====================================================
// 1) SpotsMapView（全体View）
// =====================================================
struct SpotsMapView: View {
    @StateObject private var vm = SpotsViewModel()
    
    // ← Map は coordinateRegion バインディングで駆動
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 34.773451, longitude: 135.509102),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @State private var selectedSpot: Spot? = nil
    @State private var showRegisterSheet = false
    @State private var registerCoord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    
    // EditSpotView を開くためのプリセット（Identifiable）
    @State private var editPreset: EditSpotPreset? = nil
    
    @State private var isInteracting = false
    @State private var interactionToken = UUID()
    private let settleDelay: TimeInterval = 0.40
    @State private var hudVisible = false
    @State private var hudShownAt: Date? = nil
    private let minHUDShow: TimeInterval = 0.40
    
    var body: some View {
        ZStack(alignment: .top) {
            MapReader { _ in
                ZStack {
                    // Map本体（軽量ラッパー）
                    SpotsMap(
                        coordinateRegion: $region,
                        showsUserLocation: true,
                        spots: vm.spots
                    ) { tapped in
                        selectedSpot = tapped
                    }
                    .ignoresSafeArea()
                    
                    // 任意地点タップで登録シート
                    MapTapCatcher { coord in
                        registerCoord = coord
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            if selectedSpot == nil { showRegisterSheet = true }
                        }
                    }
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
                }
            }
            
            // HUD
            if hudVisible {
                HStack {
                    Spacer()
                    ProgressView("読み込み中…")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Spacer()
                }
                .padding(.top, 8)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        // 地図変化でのフェッチ（既存ロジック）
        .onChange(of: EquatableRegion(region)) {
            isInteracting = true
            showHUDIfNeeded()
            
            let token = UUID()
            interactionToken = token
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(settleDelay * 1_000_000_000))
                guard token == interactionToken else { return }
                isInteracting = false
                hideHUDIfPossible()
            }
            
            vm.fetchAfterDelay(for: region, delay: settleDelay)
        }
        // 初回ロード
        .task {
            await vm.fetch(for: region)
        }
        // HUD表示制御
        .onChange(of: vm.isLoading) {
            if vm.isLoading { showHUDIfNeeded() } else { hideHUDIfPossible() }
        }
        .animation(.easeOut(duration: 0.15), value: hudVisible)
        
        // スポット詳細
        .sheet(item: $selectedSpot) { spot in
            SpotDetailSheet(spot: spot)
                .presentationDetents([.fraction(0.35), .medium, .large])
                .presentationDragIndicator(.visible)
        }
        // 登録シート
        .sheet(isPresented: $showRegisterSheet) {
            RegisterSpotSheet(isPresented: $showRegisterSheet, coordinate: registerCoord)
                .presentationDetents([.fraction(0.35), .medium, .large])
                .presentationDragIndicator(.visible)
        }
        // 編集シート（EditSpotView）— Map 側で一元表示
        .sheet(item: $editPreset) { preset in
            EditSpotView(
                preset: preset,
                onSaved: { _, _ in
                    // 保存後は最新反映（選択中カードやピン）
                    Task { await vm.refresh(for: region) }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        
        // 登録
        .onReceive(NotificationCenter.default.publisher(for: .spotCreated)) { _ in
            Task { await vm.refresh(for: region) }
        }
        
        // ★ 詳細シート側の「修正」ボタンから通知を受けて EditSpotView を表示
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SpotEditRequested"))) { note in
            guard let info = note.userInfo else { return }
            guard let preset = Self.makeEditPresetFlexible(from: info) else { return }
            
            // ★ まず詳細シートを閉じる（同時に2つのシートを出さない）
            if selectedSpot != nil {
                selectedSpot = nil
                // シートが閉じ終わるのを待ってから開く
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    editPreset = preset
                }
            } else {
                editPreset = preset
            }
        }
        
        // 削除
        .onReceive(NotificationCenter.default.publisher(for: .spotDeleted)) { _ in
            Task { await vm.refresh(for: region) }
        }
    }
}

// MARK: - SpotEditRequested → EditSpotPreset 生成（堅牢版）
private extension SpotsMapView {
    // ★ 全角数字・空白・文字列混在を吸収して Int 化
    static func asIntFlexible(_ any: Any?) -> Int? {
        if let v = any as? Int { return v }
        if let v = any as? Double { return Int(v) }
        if let s = any as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalizeDigits(trimmed)               // 全角→半角
            // 数字以外を取り除く（"評価:５" のようなケースも救済）
            let onlyDigits = normalized.filter { $0.isNumber }
            return onlyDigits.isEmpty ? nil : Int(onlyDigits)
        }
        return nil
    }
    
    // ★ 全角→半角
    static func normalizeDigits(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s.unicodeScalars {
            let v = ch.value
            if (0xFF10...0xFF19).contains(v) {             // '０'〜'９'
                let ascii = UnicodeScalar(v - 0xFF10 + 0x30)!
                out.unicodeScalars.append(ascii)
            } else {
                out.unicodeScalars.append(ch)
            }
        }
        return out
    }
    
    static func makeEditPresetFlexible(from userInfo: [AnyHashable: Any]) -> EditSpotPreset? {
        // 必須: spot_id のみ（まずは開くことを優先）
        func str(_ key: String) -> String? { userInfo[key] as? String }
        
        guard
            let spotID: Int = asIntFlexible(userInfo["spot_id"])
        else { return nil }
        
        let name: String = (str("spot_name") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let rating: Int = {
            if let v = asIntFlexible(userInfo["evaluation"]), (1...5).contains(v) { return v }
            return 3 // ★ フォールバック
        }()
        
        // 写真は2パターン吸収:
        // 1) "photos": [ { "id": Int, "photo_path": String }, ... ]
        // 2) "photo_ids": [Int], "photo_paths": [String]
        var photos: [EditSpotPhoto] = []
        if let arr = userInfo["photos"] as? [[String: Any]] {
            for dict in arr {
                if let pid = asIntFlexible(dict["id"]),
                   let path = dict["photo_path"] as? String,
                   let url = URL(string: path) {
                    photos.append(.init(id: pid, url: url))
                }
            }
        } else if
            let ids = userInfo["photo_ids"] as? [Any],
            let paths = userInfo["photo_paths"] as? [String],
            ids.count == paths.count {
            for (i, anyID) in ids.enumerated() {
                if let pid = asIntFlexible(anyID),
                   let url = URL(string: paths[i]) {
                    photos.append(.init(id: pid, url: url))
                }
            }
        }
        return .init(spotID: spotID, name: name, rating: rating, photos: photos)
    }
}

// =====================================================
// 1.5) Mapの薄いラッパー（旧シグネチャ対応：annotationItems）
// =====================================================
private struct SpotsMap: View {
    @Binding var coordinateRegion: MKCoordinateRegion
    var showsUserLocation: Bool
    var spots: [Spot]
    var onTap: (Spot) -> Void
    
    var body: some View {
        Map(
            coordinateRegion: $coordinateRegion,
            interactionModes: .all,
            showsUserLocation: showsUserLocation,
            userTrackingMode: .constant(.none),
            annotationItems: spots
        ) { spot in
            MapAnnotation(coordinate: spot.coordinate) {
                SpotPin(spot: spot, onTap: onTap)
            }
        }
    }
}

// ピン1個分（既存のまま）
private struct SpotPin: View {
    let spot: Spot
    let onTap: (Spot) -> Void
    var body: some View {
        Text("📍")
            .font(.system(size: 35))
            .padding(6)
            .background(Color.clear)
            .contentShape(Rectangle())
            .shadow(radius: 1, y: 2)
            .accessibilityLabel(spot.spot_name)
            .onTapGesture { onTap(spot) }
    }
}

// =====================================================
// タップ座標取得（既存）
// =====================================================
struct MapTapCatcher: UIViewRepresentable {
    var onTap: (CLLocationCoordinate2D) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }
    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.backgroundColor = .clear
        DispatchQueue.main.async { context.coordinator.attachIfNeeded(from: v) }
        return v
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { context.coordinator.attachIfNeeded(from: uiView) }
    }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let onTap: (CLLocationCoordinate2D) -> Void
        weak var mapView: MKMapView?
        var attached = false
        init(onTap: @escaping (CLLocationCoordinate2D) -> Void) { self.onTap = onTap }
        func attachIfNeeded(from probe: UIView) {
            guard !attached else { return }
            guard let map = findMKMapView(upFrom: probe) else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.delegate = self
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            map.addGestureRecognizer(tap)
            self.mapView = map
            attached = true
        }
        @objc func handleTap(_ gr: UITapGestureRecognizer) {
            guard gr.state == .ended, let map = mapView else { return }
            let p = gr.location(in: map)
            let coord = map.convert(p, toCoordinateFrom: map)
            onTap(coord)
        }
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
        private func findMKMapView(upFrom view: UIView) -> MKMapView? {
            var v: UIView? = view
            while let cur = v {
                if let m = findMKMapView(in: cur) { return m }
                v = cur.superview
            }
            return nil
        }
        private func findMKMapView(in root: UIView) -> MKMapView? {
            for sub in root.subviews {
                if let m = sub as? MKMapView { return m }
                if let m = findMKMapView(in: sub) { return m }
            }
            return nil
        }
    }
}

// =====================================================
// 2) HUD制御（既存）
// =====================================================
private extension SpotsMapView {
    func showHUDIfNeeded() {
        if !hudVisible {
            hudVisible = true
            hudShownAt = Date()
        }
    }
    func hideHUDIfPossible() {
        guard !isInteracting && !vm.isLoading else { return }
        let elapsed = Date().timeIntervalSince(hudShownAt ?? .distantPast)
        let remain = max(0, minHUDShow - elapsed)
        if remain == 0 {
            hudVisible = false
        } else {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(remain * 1_000_000_000))
                if !isInteracting && !vm.isLoading {
                    hudVisible = false
                }
            }
        }
    }
}

// =====================================================
// 3) ViewModel（既存）
// =====================================================
@MainActor
final class SpotsViewModel: ObservableObject {
    @Published var spots: [Spot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var fetchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var lastBounds: MapBounds?
    
    func fetchAfterDelay(for region: MKCoordinateRegion, delay: TimeInterval = 0.5) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await self.fetch(for: region)
        }
    }
    
    func fetch(for region: MKCoordinateRegion) async {
        let bounds = Self.bounds(from: region)
        if let last = lastBounds, Self.isAlmostSame(a: last, b: bounds) { return }
        lastBounds = bounds
        
        fetchTask?.cancel()
        fetchTask = Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                let result = try await SpotsAPI.fetchSpots(bounds: bounds, limit: 800)
                spots = result
            } catch {
                if (error as? URLError)?.code != .cancelled {
#if DEBUG
                    print("Spots API error:", error)
#endif
                    errorMessage = nil
                }
            }
        }
    }
    
    // 同一範囲でも必ず再取得したいときに使う
    func refresh(for region: MKCoordinateRegion) async {
        lastBounds = nil       // ← これで early-return を回避
        await fetch(for: region)
    }
    
    // Helpers（既存）
    static func bounds(from region: MKCoordinateRegion) -> MapBounds {
        let latDelta = region.span.latitudeDelta / 2
        let lonDelta = region.span.longitudeDelta / 2
        var swLat = region.center.latitude - latDelta
        var neLat = region.center.latitude + latDelta
        var swLng = region.center.longitude - lonDelta
        var neLng = region.center.longitude + lonDelta
        swLat = max(-90, min(90, swLat))
        neLat = max(-90, min(90, neLat))
        swLng = normalizeLng(swLng)
        neLng = normalizeLng(neLng)
        return .init(swlat: swLat, swlng: swLng, nelat: neLat, nelng: neLng)
    }
    static func normalizeLng(_ v: Double) -> Double {
        var x = fmod(v + 180.0, 360.0)
        if x < 0 { x += 360.0 }
        return x - 180.0
    }
    static func isAlmostSame(a: MapBounds, b: MapBounds) -> Bool {
        func close(_ x: Double, _ y: Double) -> Bool { abs(x - y) < 0.0005 }
        return close(a.swlat, b.swlat)
        && close(a.swlng, b.swlng)
        && close(a.nelat, b.nelat)
        && close(a.nelng, b.nelng)
    }
}

// =====================================================
// 4) 補助型（既存）
// =====================================================
struct EquatableRegion: Equatable {
    var centerLatitude: Double
    var centerLongitude: Double
    var spanLatitudeDelta: Double
    var spanLongitudeDelta: Double
    
    init(_ region: MKCoordinateRegion) {
        centerLatitude = region.center.latitude
        centerLongitude = region.center.longitude
        spanLatitudeDelta = region.span.latitudeDelta
        spanLongitudeDelta = region.span.longitudeDelta
    }
}

// =====================================================
// 5) Preview（任意）
// =====================================================
#Preview {
    SpotsMapView()
}

