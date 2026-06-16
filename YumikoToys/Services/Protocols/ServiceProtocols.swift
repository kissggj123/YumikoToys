//
//  ServiceProtocols.swift
//  YumikoToys
//
//  服务协议定义（性能优化版）
//

import Foundation
import Combine

// MARK: - 服务生命周期协议

protocol ServiceLifecycle: AnyObject {
    var serviceName: String { get }
    func initialize() async
    func start() async
    func stop()
}

// MARK: - 存储服务协议

protocol StorageServiceProtocol: ServiceLifecycle {
    func save<T: Codable & Sendable>(_ value: T, forKey key: String)
    func load<T: Codable & Sendable>(forKey key: String) -> T?
    func loadWithFallback<T: Codable & Sendable>(forKey key: String, fallback: T) -> T
    func remove(forKey key: String)
    func saveData(_ data: Data, forKey key: String)
    func loadData(forKey key: String) -> Data?
}

// MARK: - 纪念日服务协议（拆分秒级和数据级 Publisher）

protocol AnniversaryServiceProtocol: ServiceLifecycle {
    var anniversaries: [Anniversary] { get }
    var activeAnniversary: Anniversary? { get }
    var activeAnniversaryInfo: AnniversaryInfo? { get }
    
    /// 纪念日列表变化（低频）
    var anniversariesPublisher: AnyPublisher<[Anniversary], Never> { get }
    /// 完整纪念日信息变化（仅在数据变化时推送，不含秒级更新）
    var activeAnniversaryInfoPublisher: AnyPublisher<AnniversaryInfo?, Never> { get }
    /// 秒级倒计时文本（每秒推送，仅包含轻量字符串）
    var countdownTextPublisher: AnyPublisher<String, Never> { get }
    /// 状态栏短文本（分钟级精度即可）
    var statusBarTextPublisher: AnyPublisher<String, Never> { get }
    var statusBarLine1Publisher: AnyPublisher<String, Never> { get }
    
    func addAnniversary(_ anniversary: Anniversary)
    func updateAnniversary(_ anniversary: Anniversary)
    func deleteAnniversary(id: UUID)
    func deleteAllAnniversaries()
    func setActiveAnniversary(id: UUID)
    func calculateAnniversaryInfo(for anniversary: Anniversary) -> AnniversaryInfo
}

// MARK: - 防休眠服务协议

protocol PreventSleepServiceProtocol: ServiceLifecycle {
    var isPreventSleepEnabled: Bool { get }
    var isPreventSleepEnabledPublisher: AnyPublisher<Bool, Never> { get }
    
    func enablePreventSleep()
    func disablePreventSleep()
    func togglePreventSleep()
}

// MARK: - 设置服务协议

protocol SettingsServiceProtocol: ServiceLifecycle {
    var settings: AppSettings { get }
    var settingsPublisher: AnyPublisher<AppSettings, Never> { get }
    
    func updateSettings(_ settings: AppSettings)
    func updateMode(_ mode: AppMode)
    func updatePreventSleep(_ enabled: Bool)
    func updateLaunchAtLogin(_ enabled: Bool)
}

// MARK: - 开机自启动服务协议

protocol LaunchAtLoginServiceProtocol: ServiceLifecycle {
    var isEnabled: Bool { get }
    var isEnabledPublisher: AnyPublisher<Bool, Never> { get }
    
    func enable()
    func disable()
    func toggle()
}

// MARK: - 数据导出服务协议

protocol DataExportServiceProtocol: ServiceLifecycle {
    func exportData() async throws -> URL
    func importData(from url: URL) async throws
}

// MARK: - 时间同步服务协议

protocol TimeSyncServiceProtocol: ServiceLifecycle {
    /// 当前时间偏移量（秒），正值表示本地时间慢
    var timeOffset: TimeInterval { get }
    
    /// 上次同步时间
    var lastSyncTime: Date? { get }
    
    /// 同步状态 Publisher
    var syncStatePublisher: AnyPublisher<TimeSyncState, Never> { get }
    
    /// 手动触发同步
    func syncNow() async
    
    /// 获取当前准确时间
    func currentTime() -> Date
    
    /// 重置偏移量
    func resetOffset()
}

// MARK: - 时间同步状态

enum TimeSyncState: Equatable {
    case idle
    case syncing
    case success(offset: TimeInterval)
    case failed(error: String)
}
