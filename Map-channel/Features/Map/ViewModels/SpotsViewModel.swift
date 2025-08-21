//
//  SpotsViewModel.swift
//  Map-channel
//
//  Created by user on 2025/08/21.
//

import Foundation
import SwiftUI
import MapKit

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
