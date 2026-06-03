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
    
    // MARK: - ServiceLifecycle
    
    func initialize() async {
        healthStatus = await checkLaunchItemHealth()
        healthStatusSubject.send(healthStatus)
        
        if let enabled: Bool = storageService.load(forKey: settingsKey) {
            if enabled && healthStatus != .healthy {
                LoggerService.shared.warning("Launch item unhealthy, attempting repair...")
                do {
                    try await repairLaunchItem()
                    healthStatus = await checkLaunchItemHealth()
                    healthStatusSubject.send(healthStatus)
                } catch {
                    LoggerService.shared.error("Failed to repair launch item: \(error)")
                }
            }
            
            isEnabled = (SMAppService.mainApp.status == .enabled) && (healthStatus == .healthy)
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
                try await enableWithRetry()
                sendNotification(title: "🐰 开机自启动", body: "已成功开启，兔可可将在登录时自动启动")
            } catch {
                LoggerService.shared.error("Failed to enable launch at login after retries: \(error)")
                sendNotification(title: "🐰 开机自启动", body: "开启失败：\(error.localizedDescription)")
            }
        }
    }
    
    func disable() {
        Task {
            do {
                try await disableWithRetry()
                sendNotification(title: "🐰 开机自启动", body: "已关闭开机自启动")
            } catch {
                LoggerService.shared.error("Failed to disable launch at login after retries: \(error)")
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
    
    // MARK: - 【特权提权功能】利用钥匙串密码部署系统级守护进程 (System Daemon)
    
    /// 部署系统级永久防休眠自启守护进程 (需要钥匙串中的管理员密码)
    func deploySystemWideDaemon() async -> Bool {
        // 安全尝试从钥匙串中提取已存储的管理员密码
        guard let savedPassword = YumikoToysKeychain.getSavedPassword(), !savedPassword.isEmpty else {
            LoggerService.shared.warning("No administrator password found in Keychain. Cannot deploy System Daemon.")
            return false
        }
        
        LoggerService.shared.info("Retrieved authorization credentials. Preparing System Daemon installation...")
        
        let daemonLabel = "com.yumikotoys.sleepdaemon"
        let plistPath = "/Library/LaunchDaemons/\(daemonLabel).plist"
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(daemonLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/pmset</string>
                <string>-a</string>
                <string>disablesleep</string>
                <string>1</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """
        
        let tempPlistURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(daemonLabel).plist")
        try? plistContent.write(to: tempPlistURL, atomically: true, encoding: .utf8)
        
        let scriptText = """
        mkdir -p /Library/LaunchDaemons && \\
        cp -f "\(tempPlistURL.path)" "\(plistPath)" && \\
        chown root:wheel "\(plistPath)" && \\
        chmod 644 "\(plistPath)" && \\
        launchctl load -w "\(plistPath)"
        """
        
        return await withCheckedContinuation { continuation in
            let escapedScript = scriptText.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let appleScriptSource = """
            do shell script "\(escapedScript)" with administrator privileges user name "\(NSUserName())" password "\(savedPassword)"
            """
            
            if let appleScript = NSAppleScript(source: appleScriptSource) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let err = error {
                    let msg = err[NSAppleScript.errorMessage] as? String ?? "未知特权指令错误"
                    LoggerService.shared.error("System Daemon deployment failed: \(msg)")
                    continuation.resume(returning: false)
                } else {
                    LoggerService.shared.info("✅ System Daemon deployed and loaded successfully at system-level")
                    continuation.resume(returning: true)
                }
            } else {
                continuation.resume(returning: false)
            }
        }
    }
    
    /// 注销并清除系统自启守护进程 (需要钥匙串中的管理员密码)
    func removeSystemWideDaemon() async -> Bool {
        guard let savedPassword = YumikoToysKeychain.getSavedPassword(), !savedPassword.isEmpty else { return false }
        
        let plistPath = "/Library/LaunchDaemons/com.yumikotoys.sleepdaemon.plist"
        let scriptText = """
        launchctl unload -w "\(plistPath)" && \\
        rm -f "\(plistPath)"
        """
        
        return await withCheckedContinuation { continuation in
            let escapedScript = scriptText.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let appleScriptSource = """
            do shell script "\(escapedScript)" with administrator privileges user name "\(NSUserName())" password "\(savedPassword)"
            """
            
            if let appleScript = NSAppleScript(source: appleScriptSource) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if error != nil {
                    continuation.resume(returning: false)
                } else {
                    LoggerService.shared.info("✅ System Daemon removed successfully")
                    continuation.resume(returning: true)
                }
            } else {
                continuation.resume(returning: false)
            }
        }
    }
    
    // MARK: - Health Check
    
    func checkLaunchItemHealth() async -> LaunchItemStatus {
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
        
        try? await SMAppService.mainApp.unregister()
        try await Task.sleep(nanoseconds: 500_000_000)
        try await SMAppService.mainApp.register()
        try await Task.sleep(nanoseconds: 300_000_000)
        let newStatus = await checkLaunchItemHealth()
        
        guard newStatus == .healthy else {
            throw LaunchAtLoginError.repairFailed(status: newStatus)
        }
        
        LoggerService.shared.info("Launch item repaired successfully")
    }
    
    // MARK: - Private Methods
    
    private func enableWithRetry(retryCount: Int = 0) async throws {
            do {
                try await SMAppService.mainApp.register()
                try await Task.sleep(nanoseconds: 200_000_000)
                let status = await checkLaunchItemHealth()
                
                guard status == .healthy else {
                    throw LaunchAtLoginError.registrationFailed(status: status)
                }
                
                // 【架构闭环】自启开启成功后，若检测到钥匙串有密码，在底层自动同步部署系统级守护进程
                if YumikoToysKeychain.getSavedPassword() != nil {
                    _ = await deploySystemWideDaemon()
                }
                
                await MainActor.run {
                    isEnabled = true
                    isEnabledSubject.send(true)
                    healthStatus = status
                    healthStatusSubject.send(status)
                    storageService.save(true, forKey: settingsKey)
                }
                
                LoggerService.shared.info("Launch at login enabled successfully")
            } catch {
                if retryCount < maxRetryCount {
                    LoggerService.shared.warning("Enable failed, retrying (\(retryCount + 1)/\(maxRetryCount))...")
                    try await Task.sleep(nanoseconds: 500_000_000)
                    try await enableWithRetry(retryCount: retryCount + 1)
                } else {
                    throw error
                }
            }
        }
        
        private func disableWithRetry(retryCount: Int = 0) async throws {
            do {
                try await SMAppService.mainApp.unregister()
                try await Task.sleep(nanoseconds: 200_000_000)
                let status = await checkLaunchItemHealth()
                
                guard status == .notRegistered || status == .notFound else {
                    throw LaunchAtLoginError.unregistrationFailed(status: status)
                }
                
                // 【架构闭环】自启关闭成功后，同步在底层卸载并清除特权自启守护进程
                _ = await removeSystemWideDaemon()
                
                await MainActor.run {
                    isEnabled = false
                    isEnabledSubject.send(false)
                    healthStatus = status
                    healthStatusSubject.send(status)
                    storageService.save(false, forKey: settingsKey)
                }
                
                LoggerService.shared.info("Launch at login disabled successfully")
            } catch {
                if retryCount < maxRetryCount {
                    LoggerService.shared.warning("Disable failed, retrying (\(retryCount + 1)/\(maxRetryCount))...")
                    try await Task.sleep(nanoseconds: 500_000_000)
                    try await disableWithRetry(retryCount: retryCount + 1)
                } else {
                    throw error
                }
            }
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
                center.add(center.add(request) as! UNNotificationRequest) // 兼容性调用
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
