//
//  LaunchAtLoginService.swift
//  YumikoToys
//
//  开机自启动与系统级守护进程管理服务（自建安全钥匙串版）
//

import Foundation
import ServiceManagement
import Combine
import UserNotifications
import Security // 引入 macOS 安全钥匙串框架

/// 启动项健康状态
enum LaunchItemStatus: String, Sendable {
    case healthy = "healthy"
    case missing = "missing"
    case notFound = "notFound"
    case notRegistered = "notRegistered"
    case disabled = "disabled"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .healthy: return "✅ 正常"
        case .missing: return "⚠️ 缺失"
        case .notFound: return "⚠️ 未找到"
        case .notRegistered: return "❌ 未注册"
        case .disabled: return "🚫 已禁用"
        case .unknown: return "❓ 未知"
        }
    }
}

/// 开机自启动服务实现
final class LaunchAtLoginService: LaunchAtLoginServiceProtocol {
    
    // MARK: - Properties
    
    private(set) var isEnabled: Bool = false
    private(set) var healthStatus: LaunchItemStatus = .unknown
    
    private var isEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    private var healthStatusSubject = CurrentValueSubject<LaunchItemStatus, Never>(.unknown)
    
    var isEnabledPublisher: AnyPublisher<Bool, Never> {
        isEnabledSubject.eraseToAnyPublisher()
    }
    
    var healthStatusPublisher: AnyPublisher<LaunchItemStatus, Never> {
        healthStatusSubject.eraseToAnyPublisher()
    }
    
    private let storageService: StorageServiceProtocol
    private let settingsKey = "yumikotoys.launchAtLogin"
    private let maxRetryCount = 3
    
    var serviceName: String { "LaunchAtLoginService" }
    
    // MARK: - Initialization
    
    init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }
    
    // MARK: - LaunchAgent Plist Helper
    
    private var launchAgentPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.yumikotoys.autostart.plist")
    }
    
    private var appExecutablePath: String {
        Bundle.main.executablePath ?? (Bundle.main.bundlePath + "/Contents/MacOS/YumikoToys")
    }
    
    // MARK: - ServiceLifecycle
    
    func initialize() async {
        healthStatus = await checkLaunchItemHealth()
        healthStatusSubject.send(healthStatus)
        
        // 自动卸载并清除过时的旧版 system level sleep daemon（如果残留）
        let legacyDaemonPath = "/Library/LaunchDaemons/com.yumikotoys.sleepdaemon.plist"
        if FileManager.default.fileExists(atPath: legacyDaemonPath) {
            LoggerService.shared.warning("Removing legacy system sleep daemon: \(legacyDaemonPath)")
            let process = Process()
            process.launchPath = "/bin/rm"
            process.arguments = ["-f", legacyDaemonPath]
            try? process.run()
        }
        
        if let enabled: Bool = storageService.load(forKey: settingsKey) {
            isEnabled = enabled && (healthStatus == .healthy)
            isEnabledSubject.send(isEnabled)
        } else {
            isEnabled = (healthStatus == .healthy)
            isEnabledSubject.send(isEnabled)
        }
        
        LoggerService.shared.info("LaunchAtLoginService initialized, enabled: \(isEnabled), health: \(healthStatus.rawValue)")
    }
    
    func start() async {
        // 服务启动
    }
    
    func stop() {
        LoggerService.shared.info("LaunchAtLoginService stopped")
    }
    
    // MARK: - LaunchAtLoginServiceProtocol
    
    func enable() {
        Task {
            do {
                try await enableLaunchAgentPlist()
                sendNotification(title: "🐰 开机自启动", body: "已成功开启，兔可可将在登录时自动在后台启动")
            } catch {
                LoggerService.shared.error("Failed to enable launch at login: \(error)")
                sendNotification(title: "🐰 开机自启动", body: "开启失败：\(error.localizedDescription)")
            }
        }
    }
    
    func disable() {
        Task {
            do {
                try await disableLaunchAgentPlist()
                sendNotification(title: "🐰 开机自启动", body: "已关闭开机自启动")
            } catch {
                LoggerService.shared.error("Failed to disable launch at login: \(error)")
                sendNotification(title: "🐰 开机自启动", body: "关闭失败：\(error.localizedDescription)")
            }
        }
    }
    
    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }
    
    // MARK: - LaunchAgent Plist Implementation
    
    private func enableLaunchAgentPlist() async throws {
        let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
        if !FileManager.default.fileExists(atPath: launchAgentsDir.path) {
            try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        }
        
        let plistLabel = "com.yumikotoys.autostart"
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(plistLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(appExecutablePath)</string>
                <string>--autostart</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>
        """
        
        try plistContent.write(to: launchAgentPlistURL, atomically: true, encoding: .utf8)
        
        // 加载 LaunchAgent
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["load", "-w", launchAgentPlistURL.path]
        try? process.run()
        process.waitUntilExit()
        
        // 尝试 SMAppService 兼容注册（不抛错）
        try? await SMAppService.mainApp.register()
        
        await MainActor.run {
            isEnabled = true
            isEnabledSubject.send(true)
            healthStatus = .healthy
            healthStatusSubject.send(.healthy)
            storageService.save(true, forKey: settingsKey)
        }
        LoggerService.shared.info("LaunchAgent plist deployed successfully to \(launchAgentPlistURL.path)")
    }
    
    private func disableLaunchAgentPlist() async throws {
        if FileManager.default.fileExists(atPath: launchAgentPlistURL.path) {
            let process = Process()
            process.launchPath = "/bin/launchctl"
            process.arguments = ["unload", "-w", launchAgentPlistURL.path]
            try? process.run()
            process.waitUntilExit()
            
            try? FileManager.default.removeItem(at: launchAgentPlistURL)
        }
        
        // 尝试 SMAppService 注销
        try? await SMAppService.mainApp.unregister()
        
        await MainActor.run {
            isEnabled = false
            isEnabledSubject.send(false)
            healthStatus = .notRegistered
            healthStatusSubject.send(.notRegistered)
            storageService.save(false, forKey: settingsKey)
        }
        LoggerService.shared.info("LaunchAgent plist removed successfully")
    }
    
    // MARK: - Health Check
    
    func checkLaunchItemHealth() async -> LaunchItemStatus {
        if FileManager.default.fileExists(atPath: launchAgentPlistURL.path) {
            return .healthy
        }
        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:
            return .healthy
        case .notFound:
            return .missing
        case .notRegistered:
            return .notRegistered
        case .requiresApproval:
            return .disabled
        @unknown default:
            return .unknown
        }
    }
    
    func repairLaunchItem() async throws {
        LoggerService.shared.info("Repairing launch item...")
        try await enableLaunchAgentPlist()
    }
    
    // MARK: - Notifications
    
    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                center.add(request)
            }
        }
    }
}

// MARK: - 自启动异常错误类型

enum LaunchAtLoginError: Error, LocalizedError {
    case repairFailed(status: LaunchItemStatus)
    case registrationFailed(status: LaunchItemStatus)
    case unregistrationFailed(status: LaunchItemStatus)
    
    var errorDescription: String? {
        switch self {
        case .repairFailed(let status):
            return "修复启动项失败，当前状态: \(status.displayName)"
        case .registrationFailed(let status):
            return "注册启动项失败，当前状态: \(status.displayName)"
        case .unregistrationFailed(let status):
            return "注销启动项失败，当前状态: \(status.displayName)"
        }
    }
}

// MARK: - 【新增安全工具】YumikoToysKeychain 安全密钥钥匙串管理器 [1]

struct YumikoToysKeychain {
    private static let service = "com.Lite.YumikoToys"
    private static let account = NSUserName()
    private static let secureStorageKey = "admin_password"
    
    /// 从安全存储或系统级加密钥匙串中取出密码 [1]
    static func getSavedPassword() -> String? {
        // 1. 优先从免密码弹窗的本地加密存储读取
        if let password = SecureStorage.retrieveSecureItem(key: secureStorageKey) {
            return password
        }
        
        // 2. 如果本地加密存储没有，从系统钥匙串读取并执行单向静默迁移
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data, let password = String(data: data, encoding: .utf8) {
            // 写入本地加密存储
            SecureStorage.saveSecureItem(password, key: secureStorageKey)
            // 从系统钥匙串中彻底抹除，后续更新版本将不再触发系统钥匙串弹窗
            deleteSavedPasswordFromKeychain()
            LoggerService.shared.info("Administrator password migrated from Keychain to SecureStorage successfully.")
            return password
        }
        
        return nil
    }
    
    /// 将密码安全持久化写入本地加密存储 [1]
    @discardableResult
    static func saveCurrentPassword(_ password: String) -> Bool {
        // 先抹除系统钥匙串
        deleteSavedPasswordFromKeychain()
        // 保存至本地加密存储
        return SecureStorage.saveSecureItem(password, key: secureStorageKey)
    }
    
    /// 从安全存储中永久销毁密码 [1]
    @discardableResult
    static func deleteSavedPassword() -> Bool {
        deleteSavedPasswordFromKeychain()
        return SecureStorage.deleteSecureItem(key: secureStorageKey)
    }
    
    /// 仅抹除系统钥匙串的辅助方法
    @discardableResult
    private static func deleteSavedPasswordFromKeychain() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
