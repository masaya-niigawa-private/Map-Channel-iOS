//
//  KZBNewPostView.swift
//  Map-channel
//
//  Created by user on 2025/09/13.
//

import SwiftUI
import PhotosUI

// 投稿フォームの値をまとめて受け取るための型（必要なければ無視してOK）
public struct KZBNewPostForm {
    public var category: String?
    public var photoData: Data?
    public var pin: String?
    public var descriptionText: String
    public var link: String
}

public struct KZBNewPostView: View {
    @Binding var isPresented: Bool
    public var onSubmit: ((KZBNewPostForm) -> Void)? = nil
    
    // MARK: - Form States
    @State private var selectedCategory: String? = nil
    @State private var selectedPin: String? = nil
    @State private var descriptionText: String = ""
    @State private var linkURL: String = ""
    
    // Photo
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    
    // Options
    private let categoryOptions: [String] = [
        "サークル募集", "就活情報", "イベント", "バイト求人",
        "IT便利ツール", "関大インフルエンサー", "その他"
    ]
    private let pinOptions: [String] = [
        "千里山キャンパス 中央広場", "凜風館", "KU シンフォニーホール",
        "関大前駅", "高槻キャンパス", "堺キャンパス", "梅田キャンパス"
    ]
    
    private let limit = 150
    
    public init(isPresented: Binding<Bool>, onSubmit: ((KZBNewPostForm) -> Void)? = nil) {
        self._isPresented = isPresented
        self.onSubmit = onSubmit
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.08)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    
                    // カテゴリー
                    sectionLabel("カテゴリー")
                    KZBMenuField(
                        title: selectedCategory ?? "選択してください",
                        placeholderTinted: selectedCategory == nil,
                        items: categoryOptions,
                        chevron: true
                    ) { choice in
                        selectedCategory = choice
                    }
                    
                    // 写真
                    sectionLabel("写真")
                    HStack(alignment: .center, spacing: 14) {
                        thumbnail
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text("タップして写真を選択")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color(.label))
                        }
                        .onChange(of: photoItem) { _, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    photoData = data
                                }
                            }
                        }
                    }
                    
                    // 位置情報ピン（任意）
                    HStack(spacing: 6) {
                        Text("📍")
                        sectionLabel("位置情報ピン（任意）")
                    }
                    .padding(.bottom, -4)
                    
                    KZBMenuField(
                        title: selectedPin ?? "ピンを選択",
                        placeholderTinted: selectedPin == nil,
                        items: pinOptions,
                        chevron: true
                    ) { choice in
                        selectedPin = choice
                    }
                    
                    Text("※TOPページでピンを追加できます")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    // 説明文
                    sectionLabel("説明文")
                    descriptionEditor
                    
                    // リンク（任意）
                    sectionLabel("リンク（任意）")
                    TextField("https://example.com", text: $linkURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
        )
    }
    
    // MARK: - Header
    private var header: some View {
        ZStack {
            // Center Title
            Text("新規投稿")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.kzb("#1F2E5C"))
            
            HStack {
                // Close
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(.secondaryLabel))
                }
                
                Spacer()
                
                // 投稿ボタン
                Button(action: submit) {
                    Text("投稿")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.kzb("#2E4A8C"))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 14)
        .clipShape(KZBRoundedRect(topLeft: 24, topRight: 24, bottomLeft: 0, bottomRight: 0))
    }
    
    // MARK: - Subviews
    
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(Color(.label))
    }
    
    private var thumbnail: some View {
        Group {
            if let data = photoData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            } else {
                Image(systemName: "camera.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color(.secondaryLabel))
                    .frame(width: 64, height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
        }
        .accessibilityLabel("写真プレビュー")
    }
    
    private var descriptionEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $descriptionText)
                    .frame(minHeight: 140)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .onChange(of: descriptionText) { _, newValue in
                        if newValue.count > limit {
                            descriptionText = String(newValue.prefix(limit))
                        }
                    }
                
                if descriptionText.isEmpty {
                    Text("150文字まで")
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                        .padding(.leading, 20)
                }
            }
            
            HStack {
                Spacer()
                Text("\(descriptionText.count)/\(limit)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func submit() {
        let form = KZBNewPostForm(
            category: selectedCategory,
            photoData: photoData,
            pin: selectedPin,
            descriptionText: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines),
            link: linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSubmit?(form)
        isPresented = false
    }
}

// MARK: - 共通: プルダウン見た目のフィールド
fileprivate struct KZBMenuField: View {
    let title: String
    var placeholderTinted: Bool = false
    let items: [String]
    var chevron: Bool = true
    let choose: (String) -> Void
    
    var body: some View {
        Menu {
            ForEach(items, id: \.self) { item in
                Button(item) { choose(item) }
            }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(placeholderTinted ? Color.kzb("#3A6CFF") : Color(.label))
                Spacer()
                if chevron {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.kzb("#2E4A8C"), Color.kzb("#224684")],
            startPoint: .top, endPoint: .bottom
        ).ignoresSafeArea()
        KZBNewPostView(isPresented: .constant(true)) { _ in }
            .frame(maxWidth: 680)
            .padding(.horizontal, 18)
    }
}

