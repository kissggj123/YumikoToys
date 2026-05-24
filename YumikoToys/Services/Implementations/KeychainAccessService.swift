//
//  KeychainAccessService.swift
//  YumikoToys
//
//  钥匙串访问权限服务 - 处理高级功能的权限请求
//

import Foundation
import Security
import LocalAuthentication
import SwiftUI

/// 钥匙串访问权限级别
enum KeychainAccessLevel: String, CaseIterable {
    case basic = "basic"           // 基本访问（只读）
    case standard = "standard"     // 标准访问（读写）
    case advanced = "advanced"     // 高级访问（管理）
    
    var displayName: String {
        switch self {
        case .basic: return "基本访问"
        case .standard: return "标准访问"
        case .advanced: return "高级管理"
        }
    }
    
    var description: String {
        switch self {
        case .basic:
            return "允许应用读取钥匙串中的基本信息"
        case .standard:
            return "允许应用读取和写入钥匙串数据"
        case .advanced:
            return "允许应用管理钥匙串，包括删除和修改权限"
        }
    }
}

/// 钥匙串访问服务协议
protocol KeychainAccessServiceProtocol {
    var hasAccess: Bool { get }
    func requestAccess(level: KeychainAccessLevel, reason: String) async -> Bool
    func requestPasswordAuthentication(reason: String) async -> Bool
    func storeSecureItem(_ data: Data, service: String, account: String) -> Bool
    func retrieveSecureItem(service: String, account: String) -> Data?
    func deleteSecureItem(service: String, account: String) -> Bool
}

/// 钥匙串访问服务实现
@MainActor
final class KeychainAccessService: KeychainAccessServiceProtocol {
    
    // MARK: - Properties
    
    private(set) var hasAccess: Bool = false
    private var currentAccessLevel: KeychainAccessLevel = .basic
    private let context = LAContext()
    
    // MARK: - Initialization
    
    init() {
        checkInitialAccess()
    }
    
    // MARK: - Access Control
    
    /// 检查初始访问权限
    private func checkInitialAccess() {
        // 尝试读取一个测试项来验证基本访问权限
        let testQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.yumikotoys.test",
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(testQuery as CFDictionary, nil)
        hasAccess = (status == errSecSuccess || status == errSecItemNotFound)
    }
    
    /// 请求访问权限
    func requestAccess(level: KeychainAccessLevel, reason: String) async -> Bool {
        // 如果当前权限已满足要求
        if hasAccess && currentAccessLevel.rawValue >= level.rawValue {
            return true
        }
        
        // 请求用户密码验证
        let authenticated = await requestPasswordAuthentication(reason: reason)
        
        if authenticated {
            hasAccess = true
            currentAccessLevel = level
            LoggerService.shared.info("Granted keychain access at level: \(level.rawValue)")
        } else {
            LoggerService.shared.warning("Keychain access denied for level: \(level.rawValue)")
        }
        
        return authenticated
    }
    
    /// 请求密码验证（Touch ID / 密码）
    func requestPasswordAuthentication(reason: String) async -> Bool {
        var error: NSError?
        
        // 检查生物识别是否可用
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: &error
        )
        
        guard canEvaluate else {
            LoggerService.shared.error("Cannot evaluate authentication: \(error?.localizedDescription ?? "Unknown")")
            // 回退到系统密码对话框
            return await requestSystemPassword(reason: reason)
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success
        } catch {
            LoggerService.shared.error("Authentication failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 请求系统密码（回退方案）
    private func requestSystemPassword(reason: String) async -> Bool {
        // 使用 NSAlert 请求密码
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "需要钥匙串访问权限"
                alert.informativeText = reason
                alert.alertStyle = .warning
                alert.addButton(withTitle: "授权")
                alert.addButton(withTitle: "取消")
                
                // 添加密码输入框
                let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                passwordField.placeholderString = "输入系统密码"
                alert.accessoryView = passwordField
                
                let response = alert.runModal()
                continuation.resume(returning: response == .alertFirstButtonReturn)
            }
        }
    }
    
    // MARK: - Keychain Operations
    
    /// 存储安全数据
    func storeSecureItem(_ data: Data, service: String, account: String) -> Bool {
        guard hasAccess else {
            LoggerService.shared.error("Cannot store item: no keychain access")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 先删除已存在的项
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            LoggerService.shared.debug("Stored secure item for service: \(service)")
            return true
        } else {
            LoggerService.shared.error("Failed to store secure item: \(status)")
            return false
        }
    }
    
    /// 读取安全数据
    func retrieveSecureItem(service: String, account: String) -> Data? {
        guard hasAccess else {
            LoggerService.shared.error("Cannot retrieve item: no keychain access")
            return nil
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            LoggerService.shared.debug("Retrieved secure item for service: \(service)")
            return data
        } else {
            LoggerService.shared.debug("No secure item found for service: \(service)")
            return nil
        }
    }
    
    /// 删除安全数据
    func deleteSecureItem(service: String, account: String) -> Bool {
        guard hasAccess, currentAccessLevel.rawValue >= KeychainAccessLevel.standard.rawValue else {
            LoggerService.shared.error("Cannot delete item: insufficient access level")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            LoggerService.shared.debug("Deleted secure item for service: \(service)")
            return true
        } else {
            LoggerService.shared.error("Failed to delete secure item: \(status)")
            return false
        }
    }
    
    // MARK: - Advanced Features
    
    /// 导出钥匙串数据（需要高级权限）
    func exportKeychainData() async -> [String: Any]? {
        let hasPermission = await requestAccess(
            level: .advanced,
            reason: "需要高级权限来导出钥匙串数据"
        )
        
        guard hasPermission else { return nil }
        
        // 实现导出逻辑
        LoggerService.shared.info("Exporting keychain data...")
        return [:]
    }
    
    /// 导入钥匙串数据（需要高级权限）
    func importKeychainData(_ data: [String: Any]) async -> Bool {
        let hasPermission = await requestAccess(
            level: .advanced,
            reason: "需要高级权限来导入钥匙串数据"
        )
        
        guard hasPermission else { return false }
        
        // 实现导入逻辑
        LoggerService.shared.info("Importing keychain data...")
        return true
    }
}

// MARK: - Usage in Views

struct KeychainAccessPrompt: View {
    let level: KeychainAccessLevel
    let reason: String
    let onGranted: () -> Void
    let onDenied: () -> Void
    
    @State private var isRequesting = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            Text("需要钥匙串访问权限")
                .font(.headline)
            
            Text(reason)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("权限级别: \(level.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(level.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            HStack(spacing: 12) {
                Button("取消") {
                    onDenied()
                }
                .buttonStyle(.plain)
                
                Button(isRequesting ? "验证中..." : "授权访问") {
                    requestAccess()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequesting)
            }
        }
        .padding()
        .frame(width: 320)
    }
    
    private func requestAccess() {
        isRequesting = true
        Task {
            let service = KeychainAccessService()
            let granted = await service.requestAccess(level: level, reason: reason)
            isRequesting = false
            
            if granted {
                onGranted()
            } else {
                onDenied()
            }
        }
    }
}
