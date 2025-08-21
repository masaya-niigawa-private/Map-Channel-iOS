//
//  EditSpotView.swift
//  Map-channel
//
//  Updated: 2025/08/20
//  - SpotsAPI の仕様に合わせて multipart + _method=PATCH で更新
//  - 名称/評価/画像の追加・削除を一括更新
//  - 保存成功時に SpotPhotosUpdated(spot_id, photo_paths) を通知
//  - エラーアラートを iOS 17 準拠の Binding で表示
//

import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

// MARK: - 公開モデル（呼び出し元から渡される最小限）
public struct EditSpotPhoto: Identifiable, Hashable, Codable {
    public let id: Int
    public let url: URL
    public init(id: Int, url: URL) { self.id = id; self.url = url }
}

public struct EditSpotPreset: Identifiable, Hashable {
    public var id: Int { spotID }                  // ← sheet(item:) 用の一意キー
    public let spotID: Int
    public let name: String
    public let rating: Int
    public let photos: [EditSpotPhoto]
    public init(spotID: Int, name: String, rating: Int, photos: [EditSpotPhoto]) {
        self.spotID = spotID
        self.name = name
        self.rating = rating
        self.photos = photos
    }
}

// MARK: - アップロード画像
struct UploadImage: Identifiable, Hashable {
    let id = UUID()
    let data: Data
    let filename: String
    let mime: String
}

// MARK: - 更新サービス
protocol SpotEditingService {
    /// 成功時はサーバが返す最新の photo_paths（文字列URL配列）を返す。返らない場合は空配列。
    func updateSpot(
        id: Int,
        name: String,
        rating: Int,
        newImages: [UploadImage],
        deletePhotoIDs: [Int]
    ) async throws -> [String]
}

// MARK: - 既定実装（HTTP）: SpotsAPI と整合（baseURL, フィールド名, メソッドスプーフィング）
struct DefaultSpotEditingService: SpotEditingService {
    enum ServiceError: Error { case invalidURL, httpError(Int, String), badResponse }
    
    // 最小DTO
    private struct SpotDTO: Decodable {
        struct PhotoDTO: Decodable { let id: Int?; let photo_path: String? }
        let id: Int?
        let photos: [PhotoDTO]?
    }
    
    func updateSpot(
        id: Int,
        name: String,
        rating: Int,
        newImages: [UploadImage],
        deletePhotoIDs: [Int]
    ) async throws -> [String] {
        guard let url = URL(string: "api/spots/update/\(id)", relativeTo: SpotsAPI.baseURL) else {
            throw ServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST" // multipart のため POST + _method=PATCH
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        func appendFile(_ name: String, filename: String, mime: String, data: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // メソッドスプーフィング + テキスト項目
        appendField("_method", "PATCH")
        appendField("spot_name", name)
        appendField("evaluation", String(rating))
        
        // 追加画像（SpotsAPI.createSpot と同じ配列名候補の先頭 "photo[]" を使用）
        for img in newImages {
            appendFile("photo[]", filename: img.filename, mime: img.mime, data: img.data)
        }
        // 削除ID（バックエンド側で受ける配列名に合わせる）
        for pid in deletePhotoIDs {
            appendField("delete_photo_ids[]", String(pid))
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse else { throw ServiceError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.httpError(http.statusCode, bodyText)
        }
        
        // サーバが JSON で最新の写真配列を返す場合はそれを採用
        if let spot = try? JSONDecoder().decode(SpotDTO.self, from: data),
           let photos = spot.photos {
            let paths = photos.compactMap { $0.photo_path?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return paths
        }
        return []
    }
}

// MARK: - ViewModel
@MainActor
final class EditSpotViewModel: ObservableObject {
    @Published var name: String
    @Published var rating: Int
    
    // 既存（サーバ）写真
    @Published var existing: [EditSpotPhoto]
    @Published var deletePhotoIDs = Set<Int>() // 削除マーク中のID群
    
    // 新規追加（保存前ローカル）
    @Published var newImages: [UploadImage] = []
    
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    let spotID: Int
    private let service: SpotEditingService
    
    init(preset: EditSpotPreset, service: SpotEditingService = DefaultSpotEditingService()) {
        self.spotID = preset.spotID
        self.name = preset.name
        self.rating = preset.rating
        self.existing = preset.photos
        self.service = service
    }
    
    var canSave: Bool {
        (1...5).contains(rating) && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func toggleDelete(_ photo: EditSpotPhoto) {
        if deletePhotoIDs.contains(photo.id) { deletePhotoIDs.remove(photo.id) }
        else { deletePhotoIDs.insert(photo.id) }
    }
    func removeNewImage(_ image: UploadImage) {
        newImages.removeAll { $0.id == image.id }
    }
    
    func save(completion: @escaping () -> Void) {
        guard canSave else { return }
        isSaving = true
        Task {
            do {
                let serverPaths = try await service.updateSpot(
                    id: spotID,
                    name: name,
                    rating: rating,
                    newImages: newImages,
                    deletePhotoIDs: Array(deletePhotoIDs)
                )
                
                // サーバが paths を返さない場合はフォールバック（既存 − 削除）
                let fallbackPaths: [String] = existing
                    .filter { !deletePhotoIDs.contains($0.id) }
                    .map { $0.url.absoluteString }
                let finalPaths = serverPaths.isEmpty ? fallbackPaths : serverPaths
                
                // 即時反映（詳細シート側が監視）
                NotificationCenter.default.post(
                    name: Notification.Name("SpotPhotosUpdated"),
                    object: nil,
                    userInfo: ["spot_id": spotID, "photo_paths": finalPaths]
                )
                
                isSaving = false
                completion() // 呼び出し側へ名称/評価も反映
            } catch DefaultSpotEditingService.ServiceError.httpError(let status, let body) {
                isSaving = false
                errorMessage = "HTTP \(status)\n\(body)"
            } catch {
                isSaving = false
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }
}

// MARK: - View
struct EditSpotView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: EditSpotViewModel
    
    private let onSaved: ((String, Int) -> Void)?
    @State private var pickerItems: [PhotosPickerItem] = []
    
    init(
        preset: EditSpotPreset,
        service: SpotEditingService = DefaultSpotEditingService(),
        onSaved: ((String, Int) -> Void)? = nil
    ) {
        _vm = StateObject(wrappedValue: EditSpotViewModel(preset: preset, service: service))
        self.onSaved = onSaved
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("場所名", text: $vm.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                    
                    HStack {
                        Text("評価")
                        Spacer()
                        StarRatingPicker(value: $vm.rating) // ⭐️で表示・選択（1〜5）
                    }
                }
                
                Section("写真") {
                    existingPhotosSection
                    newPhotosSection
                    
                    PhotosPicker("写真を追加", selection: $pickerItems, maxSelectionCount: 6, matching: .images)
                        .onChange(of: pickerItems) { _, items in
                            Task { await loadPickerItems(items) }
                        }
                    
                    if !vm.deletePhotoIDs.isEmpty || !vm.newImages.isEmpty {
                        HStack(spacing: 12) {
                            if !vm.deletePhotoIDs.isEmpty {
                                Label("削除予定 \(vm.deletePhotoIDs.count)件", systemImage: "trash")
                            }
                            if !vm.newImages.isEmpty {
                                Label("追加 \(vm.newImages.count)件", systemImage: "plus")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("スポットを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        vm.save {
                            onSaved?(vm.name, vm.rating)
                            dismiss()
                        }
                    }
                    .disabled(!vm.canSave || vm.isSaving)
                }
            }
            .overlay {
                if vm.isSaving {
                    ZStack {
                        Color.black.opacity(0.05).ignoresSafeArea()
                        ProgressView().progressViewStyle(.circular)
                    }
                }
            }
            // iOS 17 形式の Binding でアラート制御
            .alert("保存に失敗しました",
                   isPresented: .init(
                    get: { vm.errorMessage != nil },
                    set: { if !$0 { vm.errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - 既存写真一覧（削除トグル）
    private var existingPhotosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.existing.isEmpty {
                Text("登録済みの写真はありません").foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(vm.existing) { photo in
                            VStack(spacing: 6) {
                                AsyncImage(url: photo.url) { phase in
                                    switch phase {
                                    case .empty:
                                        ZStack { Color.gray.opacity(0.12); ProgressView() }
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    case .failure:
                                        ZStack {
                                            Color.gray.opacity(0.12)
                                            Image(systemName: "photo")
                                                .imageScale(.large)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .frame(width: 120, height: 90)
                                .clipped()
                                .overlay {
                                    if vm.deletePhotoIDs.contains(photo.id) {
                                        ZStack {
                                            Color.red.opacity(0.28)
                                            Image(systemName: "trash.fill")
                                                .foregroundStyle(.white)
                                                .font(.title2)
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                Button(vm.deletePhotoIDs.contains(photo.id) ? "削除を取り消す" : "削除") {
                                    vm.toggleDelete(photo)
                                }
                                .font(.caption)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - 追加（ローカル）写真一覧
    private var newPhotosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.newImages.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(vm.newImages) { img in
                            if let uiimg = UIImage(data: img.data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiimg)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 90)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    
                                    Button {
                                        vm.removeNewImage(img)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black.opacity(0.6))
                                            .padding(4)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - PhotosPicker 読み込み（Data化 & MIME推定）
    @MainActor
    private func loadPickerItems(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let (filename, mime) = Self.filenameAndMime(for: item)
                vm.newImages.append(.init(data: data, filename: filename, mime: mime))
            }
        }
        pickerItems = []
    }
    
    // MARK: - UTType → 拡張子/MIME
    private static func filenameAndMime(for item: PhotosPickerItem) -> (String, String) {
        let type = item.supportedContentTypes.first
        let (ext, mime) = extAndMime(for: type)
        return (randomName(ext: ext), mime)
    }
    private static func extAndMime(for type: UTType?) -> (String, String) {
        guard let t = type else { return ("bin", "application/octet-stream") }
        if t.conforms(to: .heic) { return ("heic", "image/heic") }
        if t.conforms(to: .heif) { return ("heif", "image/heif") }
        if t.conforms(to: .jpeg) { return ("jpg", "image/jpeg") }
        if t.conforms(to: .png)  { return ("png", "image/png") }
        if t.identifier.lowercased().contains("webp") { return ("webp", "image/webp") }
        if let ext = t.preferredFilenameExtension, let mime = t.preferredMIMEType { return (ext, mime) }
        return ("bin", "application/octet-stream")
    }
    private static func randomName(ext: String) -> String { "image_\(UUID().uuidString.prefix(8)).\(ext)" }
}

// MARK: - ⭐️ピッカー（1〜5）
private struct StarRatingPicker: View {
    @Binding var value: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    value = i
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: i <= value ? "star.fill" : "star")
                        .imageScale(.large)
                        .foregroundStyle(i <= value ? .yellow : .secondary)
                        .contentShape(Rectangle())
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            Text("\(value)/5")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("評価")
        .accessibilityValue("\(value) / 5")
    }
}

// MARK: - Preview（ダミーデータ）
#if DEBUG
struct EditSpotView_Previews: PreviewProvider {
    static var previews: some View {
        EditSpotView(
            preset: .init(
                spotID: 101,
                name: "サンプルスポット",
                rating: 4,
                photos: [
                    .init(id: 1, url: URL(string: "https://picsum.photos/id/10/400/300")!),
                    .init(id: 2, url: URL(string: "https://picsum.photos/id/20/400/300")!)
                ]
            ),
            onSaved: { _, _ in }
        )
    }
}
#endif

