//
//  PasswordResetView.swift
//  Map-channel
//
//  Created by user on 2025/08/29.
//

import SwiftUI

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager()
    @State private var email = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                
                Spacer()
                
                // アイコン
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "key.fill")
                        .font(.system(size: 35, weight: .light))
                        .foregroundColor(.white)
                }
                
                // タイトルと説明
                VStack(spacing: 12) {
                    Text("パスワードリセット")
                        .font(.largeTitle)
                        .fontWeight(.light)
                    
                    Text("登録されているメールアドレスを入力してください。パスワードリセット用のリンクをお送りします。")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // メールアドレス入力フォーム
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            TextField("メール", text: $email)
                                .textFieldStyle(PlainTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    // 送信ボタン
                    Button(action: resetPasswordAction) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            
                            Text("リセットメールを送信")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(canReset ? Color.orange : Color.gray)
                        )
                        .foregroundColor(.white)
                    }
                    .disabled(!canReset || authManager.isLoading)
                    
                    // エラーメッセージ
                    if !authManager.errorMessage.isEmpty {
                        Text(authManager.errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 注意事項
                VStack(spacing: 8) {
                    Text("※ メールが届かない場合は、迷惑メールフォルダもご確認ください")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") {
                if alertTitle == "送信完了" {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var canReset: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    private func resetPasswordAction() {
        authManager.resetPassword(email: email) { success in
            if success {
                alertTitle = "送信完了"
                alertMessage = "パスワードリセット用のメールを送信しました。メール内のリンクからパスワードを再設定してください。"
                showingAlert = true
            } else {
                alertTitle = "エラー"
                alertMessage = authManager.errorMessage
                showingAlert = true
            }
        }
    }
}

#Preview {
    PasswordResetView()
}
