//
//  RegisterSpotSheet.swift
//  Map-channel
//
//  Created by user on 2025/08/16.
//

import SwiftUI
import MapKit
import PhotosUI

/// 画像1枚ぶん（プレビューとアップロード用データ）
struct SelectedImage: Identifiable, Hashable {
    let id = UUID()
    let uiImage: UIImage
    let filename: String
    
    var jpegData: Data {
        // すべてJPEGでアップロード（サーバー側で受けやすい）
        uiImage.jpegData(compressionQuality: 0.85) ?? Data()
    }
}

struct RegisterSpotSheet: View {
    // 呼び出し元で制御
    @Binding var isPresented: Bool
    
    // 登録したい座標（マップ上の場所）
    let coordinate: CLLocationCoordinate2D
    
    // 入力項目
    @State private var placeName: String = ""
    @State private var registrant: String = ""
    @State private var comment: String = ""
    
    // 評価（内部はIntで扱い、送信時は String("1"..."5") に変換）
    @State private var rating: Int = 3
    
    // 画像選択
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [SelectedImage] = []
    
    // 送信状態
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // --- Appleマップ風の「グラバー」 ---
            Capsule()
                .fill(.secondary)
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 6)
            
            // タイトル（現在地／座標の簡易表示）
            VStack(spacing: 2) {
                Text("スポットを登録")
                    .font(.headline)
                Text(String(format: "緯度 %.5f, 経度 %.5f", coordinate.latitude, coordinate.longitude))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
            
            // --- 入力フォーム（List風のまとまり） ---
            ScrollView {
                VStack(spacing: 12) {
                    // 場所名
                    FormRow {
                        TextField("場所名（必須）", text: $placeName)
                            .textInputAutocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.body)
                            .padding(.vertical, 8)
                    } label: {
                        Label("場所名", systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // 評価
                    FormRow {
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= rating ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                                    .onTapGesture { rating = i }
                            }
                            Spacer()
                            Text("現在: \(rating)/5")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } label: {
                        Label("評価", systemImage: "star.leadinghalf.filled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // 登録者（任意）
                    FormRow {
                        TextField("登録者名（任意）", text: $registrant)
                            .textInputAutocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.body)
                            .padding(.vertical, 8)
                    } label: {
                        Label("登録者", systemImage: "person")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // コメント（任意）
                    FormRow {
                        TextEditor(text: $comment)
                            .frame(minHeight: 90)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(UIColor.separator), lineWidth: 0.5)
                            )
                    } label: {
                        Label("コメント", systemImage: "text.bubble")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // 写真
                    VStack(alignment: .leading, spacing: 8) {
                        Label("画像", systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("画像を追加")
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(8)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                        .onChange(of: photoItems) { newItems in
                            Task { await loadSelectedImages(from: newItems) }
                        }
                        
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(selectedImages) { item in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: item.uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 110, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            Button {
                                                withAnimation { selectedImages.removeAll { $0.id == item.id } }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.white, .black.opacity(0.4))
                                            }
                                            .offset(x: 6, y: -6)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding(.bottom, 20)
            }
            
            // --- フッター（登録ボタン） ---
            VStack(spacing: 8) {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(isSubmitting ? "送信中…" : "登録する")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(placeName.isEmpty || isSubmitting ? Color.gray : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(placeName.isEmpty || isSubmitting)
                
                Button("キャンセル") {
                    isPresented = false
                }
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial)
        }
        .alert("登録に失敗しました", isPresented: $showAlert, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "不明なエラー")
        })
        // Appleマップ風の見た目調整
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
        .padding(.horizontal, 16)
    }
    
    // MARK: - 画像の読み込み
    private func loadSelectedImages(from items: [PhotosPickerItem]) async {
        do {
            var result: [SelectedImage] = []
            for item in items {
                if let data = try await item.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data) {
                    let name = (item.itemIdentifier ?? UUID().uuidString) + ".jpg"
                    result.append(SelectedImage(uiImage: ui, filename: name))
                }
            }
            await MainActor.run { selectedImages = result }
        } catch {
            // 読み込み失敗はスキップ
            print("PhotosPicker load error:", error)
        }
    }
    
    // MARK: - 送信（SpotsAPI を呼ぶ）
    private func submit() async {
        
        // --- 入力バリデーション（座標） ---
        // 0,0 は「未選択」扱い。DB 側には (ido, keido) の一意制約があり、既に 0,0 が登録されていると重複エラーになります。
        // また、緯度経度の範囲も軽く検証します。
        if !(coordinate.latitude.isFinite && coordinate.longitude.isFinite) ||
            abs(coordinate.latitude) > 90 || abs(coordinate.longitude) > 180 ||
            (coordinate.latitude == 0 && coordinate.longitude == 0) {
            errorMessage = "場所が未設定です。地図で場所を選択してから登録してください。"
            showAlert = true
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        
        do {
            // ★ 修正: [UploadImage] → [SpotsAPI.UploadImage]
            let uploads: [SpotsAPI.UploadImage] = selectedImages.map {
                .init(data: $0.jpegData, filename: $0.filename, mime: "image/jpeg")
            }
            let form = SpotsAPI.CreateSpotForm(
                spotName: placeName,
                evaluation: rating,
                userName: registrant.isEmpty ? nil : registrant,
                comment: comment.isEmpty ? nil : comment,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                images: uploads
            )
            try await SpotsAPI.createSpot(form)
            
            // 登録完了 → Map に即反映
            NotificationCenter.default.post(
                name: Notification.Name("SpotCreated"),
                object: nil,
                userInfo: [
                    "spot_name": placeName,
                    "evaluation": rating,
                    "lat": coordinate.latitude,
                    "lng": coordinate.longitude
                ]
            )
            isPresented = false
        } catch {
            if let apiErr = error as? APIError, case let .server(underlying) = apiErr {
                var msg = (underlying as NSError).localizedDescription
                // 重複エラー（ido_keido のユニーク制約）をユーザに分かりやすく
                if msg.contains("Duplicate entry") || msg.contains("ido_keido_unique") || msg.contains("1062") {
                    msg = "同じ緯度・経度のスポットが既に登録されています。地図で場所を選び直すか、既存のスポットを修正してください。"
                }
                errorMessage = msg
            } else {
                errorMessage = (error as NSError).localizedDescription
            }
            showAlert = true
        }
    }
}

// MARK: - Appleマップ風 行レイアウト（左にラベル、右が内容）
private struct FormRow<Content: View, LabelView: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var label: () -> LabelView
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                label()
                    .frame(width: 86, alignment: .leading)
                    .foregroundStyle(.primary)
                content()
            }
            .padding(.vertical, 10)
            
            Divider()
                .overlay(Color(UIColor.separator))
        }
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - マルチパート組み立て（参考: 使っていませんが将来用）
private struct MultipartData {
    let boundary: String
    private(set) var body = Data()
    
    init() {
        boundary = "Boundary-\(UUID().uuidString)"
    }
    
    mutating func appendField(name: String, value: String) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendString("\(value)\r\n")
    }
    
    mutating func appendFile(name: String, filename: String, mimeType: String, fileData: Data) {
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        append(fileData)
        appendString("\r\n")
    }
    
    mutating func finalize() {
        appendString("--\(boundary)--\r\n")
    }
    
    private mutating func append(_ data: Data) { body.append(data) }
    private mutating func appendString(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }
}

#Preview {
    // プレビュー用にダミーの Binding と座標を渡す
    RegisterSpotSheet(
        isPresented: .constant(true),
        coordinate: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671) // 東京駅あたり
    )
}

