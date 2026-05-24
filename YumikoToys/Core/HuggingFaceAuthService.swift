//
//  HuggingFaceAuthService.swift
//  YumikoToys
//
//  HuggingFace 认证服务 - 基于 swift-huggingface 官方库设计
//  支持 Token 自动检测、手动输入和 Keychain 安全存储
//

import Foundation
import Security
import SwiftUI

/// HuggingFace 认证服务
/// 参考 swift-huggingface 库的认证机制实现
@MainActor
final class HuggingFaceAuthService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 当前是否已认证
    @Published private(set) var isAuthenticated: Bool = false
    
    /// 当前用户名（如果已获取）
    @Published private(set) var username: String?
    
    /// 认证错误信息
    @Published private(set) var lastError: String?
    
    // MARK: - Constants
    
    private let keychainService = "com.yumikotoys.huggingface"
    private let keychainAccount = "hf_token"
    private let tokenFilePath = "~/.cache/huggingface/token"
    
    // MARK: - Singleton
    
    static let shared = HuggingFaceAuthService()
    
    private init() {
        // 初始化时检查是否已有存储的 Token
        Task {
            await checkAuthentication()
        }
    }
    
    // MARK: - Public Methods
    
    /// 检查当前认证状态
    func checkAuthentication() async {
        // 1. 优先检查 Keychain 存储的 Token
        if let token = loadTokenFromKeychain() {
            await validateToken(token)
            return
        }
        
        // 2. 检查环境变量
        if let token = loadTokenFromEnvironment() {
            await validateToken(token)
            return
        }
        
        // 3. 检查 HF CLI 存储的 Token 文件
        if let token = loadTokenFromFile() {
            await validateToken(token)
            return
        }
        
        // 未找到 Token
        await MainActor.run {
            self.isAuthenticated = false
            self.username = nil
        }
    }
    
    /// 使用用户提供的 Token 进行认证
    /// - Parameter token: HuggingFace Access Token (从 https://huggingface.co/settings/tokens 获取)
    func authenticate(with token: String) async -> Bool {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedToken.isEmpty else {
            await MainActor.run {
                self.lastError = "Token 不能为空"
            }
            return false
        }
        
        // 验证 Token 有效性
        let isValid = await validateToken(trimmedToken)
        
        if isValid {
            // 保存到 Keychain
            saveTokenToKeychain(trimmedToken)
            LoggerService.shared.info("[HuggingFaceAuthService] Token 验证成功并已保存")
        } else {
            await MainActor.run {
                self.lastError = "Token 验证失败，请检查 Token 是否正确"
            }
            LoggerService.shared.error("[HuggingFaceAuthService] Token 验证失败")
        }
        
        return isValid
    }
    
    /// 退出登录，清除存储的 Token
    func signOut() {
        deleteTokenFromKeychain()
        isAuthenticated = false
        username = nil
        lastError = nil
        LoggerService.shared.info("[HuggingFaceAuthService] 已退出登录")
    }
    
    /// 获取当前 Token（用于下载请求）
    func getCurrentToken() -> String? {
        // 优先 Keychain
        if let token = loadTokenFromKeychain() {
            return token
        }
        // 其次环境变量
        if let token = loadTokenFromEnvironment() {
            return token
        }
        // 最后文件
        return loadTokenFromFile()
    }
    
    /// 获取认证头（用于 HTTP 请求）
    func getAuthorizationHeader() -> String? {
        guard let token = getCurrentToken() else { return nil }
        return "Bearer \(token)"
    }
    
    // MARK: - Private Methods
    
    /// 从环境变量读取 Token
    private func loadTokenFromEnvironment() -> String? {
        // 检查 HF_TOKEN
        if let token = ProcessInfo.processInfo.environment["HF_TOKEN"], !token.isEmpty {
            LoggerService.shared.debug("[HuggingFaceAuthService] 从 HF_TOKEN 环境变量读取 Token")
            return token
        }
        
        // 检查 HUGGING_FACE_HUB_TOKEN
        if let token = ProcessInfo.processInfo.environment["HUGGING_FACE_HUB_TOKEN"], !token.isEmpty {
            LoggerService.shared.debug("[HuggingFaceAuthService] 从 HUGGING_FACE_HUB_TOKEN 环境变量读取 Token")
            return token
        }
        
        return nil
    }
    
    /// 从 HF CLI Token 文件读取
    private func loadTokenFromFile() -> String? {
        let fileManager = FileManager.default
        
        // 检查 HF_HOME/token
        if let hfHome = ProcessInfo.processInfo.environment["HF_HOME"] {
            let tokenPath = (hfHome as NSString).appendingPathComponent("token")
            if let token = try? String(contentsOfFile: tokenPath, encoding: .utf8) {
                LoggerService.shared.debug("[HuggingFaceAuthService] 从 HF_HOME/token 读取 Token")
                return token.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // 检查 HF_TOKEN_PATH
        if let tokenPath = ProcessInfo.processInfo.environment["HF_TOKEN_PATH"] {
            if let token = try? String(contentsOfFile: tokenPath, encoding: .utf8) {
                LoggerService.shared.debug("[HuggingFaceAuthService] 从 HF_TOKEN_PATH 读取 Token")
                return token.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // 检查默认路径 ~/.cache/huggingface/token
        let homeDir = fileManager.homeDirectoryForCurrentUser.path
        let defaultPath = (homeDir as NSString).appendingPathComponent(".cache/huggingface/token")
        if fileManager.fileExists(atPath: defaultPath),
           let token = try? String(contentsOfFile: defaultPath, encoding: .utf8) {
            LoggerService.shared.debug("[HuggingFaceAuthService] 从 ~/.cache/huggingface/token 读取 Token")
            return token.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 检查旧版路径 ~/.huggingface/token
        let legacyPath = (homeDir as NSString).appendingPathComponent(".huggingface/token")
        if fileManager.fileExists(atPath: legacyPath),
           let token = try? String(contentsOfFile: legacyPath, encoding: .utf8) {
            LoggerService.shared.debug("[HuggingFaceAuthService] 从 ~/.huggingface/token 读取 Token")
            return token.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    /// 从 Keychain 读取 Token
    private func loadTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    /// 保存 Token 到 Keychain
    private func saveTokenToKeychain(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        
        // 先删除旧的
        deleteTokenFromKeychain()
        
        // 保存新的
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            LoggerService.shared.error("[HuggingFaceAuthService] 保存 Token 到 Keychain 失败: \(status)")
        }
    }
    
    /// 从 Keychain 删除 Token
    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    /// 验证 Token 有效性（调用 HuggingFace API）
    private func validateToken(_ token: String) async -> Bool {
        guard let url = URL(string: "https://huggingface.co/api/whoami-v2") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            if httpResponse.statusCode == 200 {
                // 解析用户名
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let name = json["name"] as? String {
                    await MainActor.run {
                        self.username = name
                        self.isAuthenticated = true
                        self.lastError = nil
                    }
                    LoggerService.shared.info("[HuggingFaceAuthService] Token 验证成功，用户: \(name)")
                    return true
                }
            } else if httpResponse.statusCode == 401 {
                await MainActor.run {
                    self.lastError = "Token 无效或已过期"
                }
            }
            
            return false
        } catch {
            LoggerService.shared.error("[HuggingFaceAuthService] Token 验证请求失败: \(error)")
            return false
        }
    }
}

// MARK: - 便捷扩展

extension HuggingFaceAuthService {
    
    /// 获取 Token 申请页面的 URL
    var tokenSettingsURL: URL {
        URL(string: "https://huggingface.co/settings/tokens")!
    }
    
    /// 获取 HuggingFace 主页 URL
    var huggingFaceHomeURL: URL {
        URL(string: "https://huggingface.co")!
    }
    
    /// 打开 Token 设置页面
    func openTokenSettings() {
        NSWorkspace.shared.open(tokenSettingsURL)
    }
}
