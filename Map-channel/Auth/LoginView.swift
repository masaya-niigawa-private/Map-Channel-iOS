//
//  AuthView.swift
//  Map-channel
//
//  Created by user on 2025/08/28.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager()
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingPasswordReset = false
    @State private var showingAlert = false
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
                            .fill(Color.blue)
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "map")
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(.white)
                    }
                    
                    Text("Map Channel")
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
                                .autocapitalization(.none)
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
                    
                    // ログインボタン
                    Button(action: loginAction) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            
                            Text("サインイン")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(canLogin ? Color.blue : Color.gray)
                        )
                        .foregroundColor(.white)
                    }
                    .disabled(!canLogin || authManager.isLoading)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    
                    // パスワードを忘れた場合
                    Button("パスワードをお忘れですか？") {
                        showingPasswordReset = true
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .padding(.top, 12)
                    
                    // エラーメッセージ
                    if !authManager.errorMessage.isEmpty {
                        Text(authManager.errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.top, 8)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 30)
                .background(Color(.secondarySystemBackground))
                
                // フッター
                VStack(spacing: 10) {
                    Divider()
                    
                    HStack {
                        Text("アカウントをお持ちでない場合")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Button("新規登録") {
                            showingSignUp = true
                        }
                        .font(.footnote)
                        .foregroundColor(.blue)
                    }
                    .padding(.bottom, 20)
                }
                .background(Color(.systemBackground))
            }
            .navigationBarHidden(true)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showingPasswordReset) {
            PasswordResetView()
        }
        .alert("エラー", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var canLogin: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6
    }
    
    private func loginAction() {
        authManager.signIn(email: email, password: password) { success in
            if !success && !authManager.errorMessage.isEmpty {
                alertMessage = authManager.errorMessage
                showingAlert = true
            }
        }
    }
}

#Preview {
    LoginView()
}
