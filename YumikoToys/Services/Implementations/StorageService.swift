//
//  StorageService.swift
//  YumikoToys
//
//  存储服务实现
//

import Foundation

/// 存储服务实现
final class StorageService: StorageServiceProtocol {
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    var serviceName: String { "StorageService" }
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    
    // MARK: - ServiceLifecycle
    
    func initialize() async {
        // 初始化存储服务
        LoggerService.shared.debug("StorageService initialized")
    }
    
    func start() async {
        // 启动存储服务
    }
    
    func stop() {
        // 停止存储服务
    }
    
    // MARK: - StorageServiceProtocol
    
    func save<T: Codable & Sendable>(_ value: T, forKey key: String) {
        do {
            let data = try encoder.encode(value)
            userDefaults.set(data, forKey: key)
            LoggerService.shared.debug("Saved data for key: \(key)")
        } catch {
            LoggerService.shared.error("Failed to save data for key \(key): \(error)")
        }
    }
    
    func load<T: Codable & Sendable>(forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            LoggerService.shared.debug("No data found for key: \(key)")
            return nil
        }
        do {
            let value = try decoder.decode(T.self, from: data)
            return value
        } catch {
            LoggerService.shared.error("Failed to load data for key \(key): \(error)")
            return nil
        }
    }
    
    func loadWithFallback<T: Codable & Sendable>(forKey key: String, fallback: T) -> T {
        guard let data = userDefaults.data(forKey: key) else {
            LoggerService.shared.debug("No data found for key: \(key), using fallback")
            return fallback
        }
        do {
            let value = try decoder.decode(T.self, from: data)
            return value
        } catch {
            LoggerService.shared.error("Decode failed for \(key): \(error). Using fallback.")
            let backupKey = "\(key)_backup_\(Int(Date().timeIntervalSince1970))"
            userDefaults.set(data, forKey: backupKey)
            LoggerService.shared.info("Backed up corrupted data to: \(backupKey)")
            return fallback
        }
    }
    
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        LoggerService.shared.debug("Removed data for key: \(key)")
    }
    
    func saveData(_ data: Data, forKey key: String) {
        userDefaults.set(data, forKey: key)
    }
    
    func loadData(forKey key: String) -> Data? {
        return userDefaults.data(forKey: key)
    }
}

// MARK: - Logger Service

/// 日志服务
final class LoggerService {
    static let shared = LoggerService()
    
    private let dateFormatter: DateFormatter
    private var isDebugEnabled = true
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    func debug(_ message: String) {
        guard isDebugEnabled else { return }
        print("[DEBUG] [\(timestamp())] \(message)")
    }
    
    func info(_ message: String) {
        print("[INFO] [\(timestamp())] \(message)")
    }
    
    func warning(_ message: String) {
        print("[WARNING] [\(timestamp())] \(message)")
    }
    
    func error(_ message: String) {
        print("[ERROR] [\(timestamp())] \(message)")
    }
    
    private func timestamp() -> String {
        return dateFormatter.string(from: Date())
    }
}
