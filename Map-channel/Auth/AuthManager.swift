//
//  AuthManager.swift
//  Map-channel
//
//  Created by user on 2025/08/31.
//

import Foundation
import FirebaseAuth
import UIKit

final class AuthManager: ObservableObject {
    // MARK: - Published States
    @Published var isAuthenticated = false
    @Published var currentUser: FirebaseAuth.User?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // MARK: - Backend Endpoint（環境に合わせて変更）
    // 例: https://map-ch.com/api/storeUser  または  https://your-domain.example.com/api/users
    private let usersRegisterEndpoint = URL(string: "https://map-ch.com/api/storeUser")
    
    // MARK: - Init
    init() {
        checkAuthStatus()
        
        // サインイン/アウトの変化を監視
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.runOnMain {
                self?.currentUser = user
                self?.isAuthenticated = (user != nil)
            }
        }
        
        // ★ サーバ上の削除/無効化/失効を素早く検知
        Auth.auth().addIDTokenDidChangeListener { [weak self] _, user in
            guard let self = self, let user = user else { return }
            user.getIDTokenResult(forcingRefresh: true) { _, error in
                if let err = error as NSError? { self.handleAuthError(err, user: user) }
            }
        }
        
        // ★ 起動直後にもサーバ最新で整合を取る
        refreshAuthFromServer()
        
        // ★ フォアグラウンド復帰時にも再チェック（任意だが実運用で安定）
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAuthFromServer()
        }
    }
    
    private func checkAuthStatus() {
        currentUser = Auth.auth().currentUser
        isAuthenticated = (currentUser != nil)
    }
    
    // MARK: - Sign Up (Firebase作成 → Laravel登録 → 失敗時ロールバック)
    func signUp(email: String, password: String, completion: @escaping (Bool) -> Void) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください"
            completion(false)
            return
        }
        
        runOnMain { self.isLoading = true; self.errorMessage = "" }
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.runOnMain {
                    self.isLoading = false
                    self.errorMessage = self.getLocalizedErrorMessage(error)
                    completion(false)
                }
                return
            }
            
            guard let user = result?.user else {
                self.runOnMain {
                    self.isLoading = false
                    self.errorMessage = "ユーザー取得に失敗しました"
                    completion(false)
                }
                return
            }
            
            // JWT は必須ではない設計：取れなければ nil のまま送る
            user.getIDToken { [weak self] idToken, _ in
                guard let self = self else { return }
                
                self.registerUser(uid: user.uid, email: email, idToken: idToken, attempt: 0) { ok, apiErr in
                    if ok {
                        self.runOnMain {
                            self.isLoading = false
                            completion(true) // APIまで成功して初めて成功扱い
                        }
                    } else {
                        // API失敗 → Firebaseユーザーを削除してロールバック
                        self.rollbackFirebaseUser(user: user, email: email, password: password) { _ in
                            self.runOnMain {
                                self.isLoading = false
                                self.errorMessage = apiErr ?? "登録APIに失敗しました"
                                completion(false)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください"
            completion(false)
            return
        }
        
        runOnMain { self.isLoading = true; self.errorMessage = "" }
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            guard let self = self else { return }
            self.runOnMain {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = self.getLocalizedErrorMessage(error)
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Reset Password
    func resetPassword(email: String, completion: @escaping (Bool) -> Void) {
        guard !email.isEmpty else {
            errorMessage = "メールアドレスを入力してください"
            completion(false)
            return
        }
        
        runOnMain { self.isLoading = true; self.errorMessage = "" }
        
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            guard let self = self else { return }
            self.runOnMain {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = self.getLocalizedErrorMessage(error)
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()
            runOnMain {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        } catch {
            runOnMain { self.errorMessage = "ログアウトに失敗しました" }
        }
    }
    
    // MARK: - Backend Registration (1回だけリトライ)
    private func registerUser(uid: String,
                              email: String,
                              idToken: String?,
                              attempt: Int,
                              completion: @escaping (Bool, String?) -> Void) {
        
        guard let url = usersRegisterEndpoint else {
            completion(false, "登録APIのURLが不正です")
            return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 15 // ハング防止
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let idToken, !idToken.isEmpty {
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        
        struct Payload: Codable { let uid: String; let email: String }
        do {
            req.httpBody = try JSONEncoder().encode(Payload(uid: uid, email: email))
        } catch {
            completion(false, "リクエスト生成に失敗しました")
            return
        }
        
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            // ネットワーク例外
            if let err = err as? URLError {
                if attempt == 0, [.timedOut, .networkConnectionLost, .notConnectedToInternet].contains(err.code) {
                    // 一過性エラーは1回だけリトライ
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        self?.registerUser(uid: uid, email: email, idToken: idToken, attempt: 1, completion: completion)
                    }
                    return
                }
                completion(false, err.localizedDescription)
                return
            } else if let err = err {
                completion(false, err.localizedDescription)
                return
            }
            
            guard let http = resp as? HTTPURLResponse else {
                completion(false, "不明な応答です")
                return
            }
            
            // 5xx も1回だけリトライ
            if attempt == 0, (500...599).contains(http.statusCode) {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    self?.registerUser(uid: uid, email: email, idToken: idToken, attempt: 1, completion: completion)
                }
                return
            }
            
            if (200...299).contains(http.statusCode) {
                completion(true, nil)
            } else {
                let body = String(data: data ?? Data(), encoding: .utf8) ?? ""
                completion(false, "APIエラー: \(http.statusCode) \(body)")
            }
        }.resume()
    }
    
    // MARK: - Rollback (Firebase User Deletion)
    private func rollbackFirebaseUser(user: FirebaseAuth.User,
                                      email: String,
                                      password: String,
                                      completion: @escaping (Bool) -> Void) {
        user.delete { [weak self] err in
            // 新規作成直後は recent sign-in を満たすため通常ここで成功
            if err == nil { completion(true); return }
            
            // 念のためのフォールバック：再認証してから削除
            let cred = EmailAuthProvider.credential(withEmail: email, password: password)
            user.reauthenticate(with: cred) { _, _ in
                user.delete { _ in completion(true) }
            }
        }
    }
    
    // MARK: - Server-side Auth Refresh
    /// サーバ側の最新状態で currentUser を検証（削除/無効化/失効を即検出）
    func refreshAuthFromServer() {
        guard let user = Auth.auth().currentUser else {
            runOnMain { self.isAuthenticated = false; self.currentUser = nil }
            return
        }
        user.reload { [weak self] error in
            guard let self = self else { return }
            if let err = error as NSError? {
                self.handleAuthError(err, user: user)
            } else {
                self.runOnMain {
                    self.currentUser = Auth.auth().currentUser
                    self.isAuthenticated = (self.currentUser != nil)
                }
            }
        }
    }
    
    // MARK: - Auth Error Handling（削除/無効化/失効なら即サインアウト）
    private func handleAuthError(_ nsError: NSError, user: FirebaseAuth.User?) {
        // FirebaseAuth のバージョン差を吸収：rawValue で直接比較
        switch nsError.code {
        case AuthErrorCode.userNotFound.rawValue,
            AuthErrorCode.userDisabled.rawValue,
            AuthErrorCode.invalidUserToken.rawValue,
            AuthErrorCode.userTokenExpired.rawValue:
            // サーバ上で削除/無効化/失効 → 即サインアウトしてログイン画面へ
            try? Auth.auth().signOut()
            runOnMain {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        default:
            break
        }
    }
    
    // MARK: - Utilities
    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async { work() } }
    }
    
    private func getLocalizedErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "このメールアドレスは既に使用されています"
        case AuthErrorCode.invalidEmail.rawValue:
            return "メールアドレスの形式が正しくありません"
        case AuthErrorCode.weakPassword.rawValue:
            return "パスワードは6文字以上で入力してください"
        case AuthErrorCode.userNotFound.rawValue:
            return "ユーザーが見つかりません"
        case AuthErrorCode.wrongPassword.rawValue:
            return "パスワードが間違っています"
        case AuthErrorCode.userDisabled.rawValue:
            return "このアカウントは無効化されています"
        default:
            return error.localizedDescription
        }
    }
}

