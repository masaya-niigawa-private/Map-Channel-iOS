//
//  CommentComposeView.swift
//  Map-channel
//
//  Created by user on 2025/08/18.
//

import SwiftUI

enum CommentComposeAction {
    case cancel
    case post(String, String?)   // (text, author)
}

struct CommentComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var author: String = ""   // ★ 追加：任意のユーザー名
    @FocusState private var isFocused: Bool
    
    let handler: (CommentComposeAction) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // 任意のユーザー名（TextField）
                HStack {
                    Image(systemName: "person.circle.fill")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                    TextField("ユーザー名（任意）", text: $author)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.done)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                // コメント入力（TextEditor）
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    
                    // プレースホルダー
                    if text.isEmpty {
                        Text("コメントを入力")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 160)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                )
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .navigationTitle("コメント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左：キャンセル
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        handler(.cancel)
                        dismiss()
                    }
                }
                // 右：投稿（空白のみは無効）
                ToolbarItem(placement: .confirmationAction) {
                    Button("投稿") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let name = author.trimmingCharacters(in: .whitespacesAndNewlines)
                        handler(.post(trimmed, name.isEmpty ? nil : name))
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        // 表示直後にキーボードフォーカス（最新SwiftUI挙動に合わせて軽い遅延）
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isFocused = true
            }
        }
    }
}

#Preview("入力開始（空）") {
    CommentComposeView { _ in }
}

#Preview("投稿イベントを確認") {
    CommentComposePreviewHost()
}

private struct CommentComposePreviewHost: View {
    @State private var lastAction: String = "—"
    @State private var isPresented = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("最後のアクション: \(lastAction)")
                    .foregroundStyle(.secondary)
                
                Button("入力画面を開く") {
                    isPresented = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("CommentCompose プレビュー")
            .sheet(isPresented: $isPresented) {
                CommentComposeView { action in
                    switch action {
                    case .cancel:
                        lastAction = "キャンセル"
                    case .post(let text, let author):
                        lastAction = "投稿: \(text) / author=\(author ?? "nil")"
                    }
                }
            }
        }
    }
}

