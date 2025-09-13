//
//  SignUpView.swift
//  Map-channel
//
//  Created by user on 2025/08/29.
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager()
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー部分
                VStack(spacing: 20) {
                    Spacer()
                    
                    // アプリアイコン風の円形アイコン
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 35, weight: .light))
                            .foregroundColor(.white)
                    }
                    
                    Text("新規登録")
                        .font(.largeTitle)
                        .fontWeight(.light)
                    
                    Spacer()
                }
                .frame(maxHeight: .infinity)
                .background(Color(.systemBackground))
                
                // フォーム部分
                VStack(spacing: 0) {
                    // メールアドレス入力
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            TextField("メール", text: $email)
                                .textFieldStyle(PlainTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .textContentType(.emailAddress)
                                .disableAutocorrection(true)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        
                        Divider()
                            .padding(.horizontal, 16)
                    }
                    
                    // パスワード入力
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "lock")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            SecureField("パスワード（6文字以上）", text: $password)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        
                        Divider()
                            .padding(.horizontal, 16)
                    }
                    
                    // パスワード確認入力
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            SecureField("パスワード確認", text: $confirmPassword)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                        // パスワード一致チェック表示
                        if !password.isEmpty && !confirmPassword.isEmpty {
                            HStack {
                                Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(passwordsMatch ? .green : .red)
                                Text(passwordsMatch ? "パスワードが一致しています" : "パスワードが一致しません")
                                    .font(.footnote)
                                    .foregroundColor(passwordsMatch ? .green : .red)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                        }
                    }
                    
                    // 登録ボタン
                    Button(action: signUpAction) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            
                            Text("アカウント作成")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(canSignUp ? Color.green : Color.gray)
                        )
                        .foregroundColor(.white)
                    }
                    .disabled(!canSignUp || authManager.isLoading)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    
                    // エラーメッセージ
                    if !authManager.errorMessage.isEmpty {
                        Text(authManager.errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.top, 12)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 30)
                .background(Color(.secondarySystemBackground))
                
                // フッター
                VStack(spacing: 10) {
                    Divider()
                    
                    HStack {
                        Text("既にアカウントをお持ちの場合")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Button("サインイン") {
                            dismiss()
                        }
                        .font(.footnote)
                        .foregroundColor(.blue)
                    }
                    .padding(.bottom, 20)
                }
                .background(Color(.systemBackground))
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
                if alertTitle == "登録完了" {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var passwordsMatch: Bool {
        password == confirmPassword && !password.isEmpty
    }
    
    private var canSignUp: Bool {
        !email.isEmpty &&
        password.count >= 6 &&
        passwordsMatch
    }
    
    private func signUpAction() {
        authManager.signUp(email: email, password: password) { success in
            if success {
                alertTitle = "登録完了"
                alertMessage = "アカウントが正常に作成されました。"
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
    SignUpView()
}
