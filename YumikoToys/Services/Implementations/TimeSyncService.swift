//
//  TimeSyncService.swift
//  YumikoToys
//
//  时间同步服务 - 管理 NTP 时间偏移
//

import Foundation
import Combine

// MARK: - 时间同步服务实现

@MainActor
final class TimeSyncService: ObservableObject, TimeSyncServiceProtocol {
    
    // MARK: - 属性
    
    var serviceName: String { "TimeSyncService" }
    
    @Published private(set) var timeOffset: TimeInterval = 0
    @Published private(set) var lastSyncTime: Date?
    @Published private(set) var syncState: TimeSyncState = .idle
    
    var syncStatePublisher: AnyPublisher<TimeSyncState, Never> {
        $syncState.eraseToAnyPublisher()
    }
    
    private let ntpClient: NTPClient
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 3600  // 1小时自动同步一次
    
    // MARK: - 初始化
    
    init(ntpClient: NTPClient = NTPClient()) {
        self.ntpClient = ntpClient
    }
    
    // MARK: - 生命周期
    
    func initialize() async {
        LoggerService.shared.info("TimeSyncService initialized")
    }
    
    func start() async {
        // 启动时立即同步一次
        await syncNow()
        
        // 设置定时同步
        startPeriodicSync()
        
        LoggerService.shared.info("TimeSyncService started")
    }
    
    func stop() {
        syncTimer?.invalidate()
        syncTimer = nil
        LoggerService.shared.info("TimeSyncService stopped")
    }
    
    // MARK: - 公共方法
    
    /// 手动触发同步
    func syncNow() async {
        syncState = .syncing
        
        do {
            let offset = try await ntpClient.sync()
            self.timeOffset = offset
            self.lastSyncTime = Date()
            self.syncState = .success(offset: offset)
            
            LoggerService.shared.info("Time sync completed, offset: \(String(format: "%.3f", offset))s")
        } catch {
            let errorMessage = error.localizedDescription
            self.syncState = .failed(error: errorMessage)
            LoggerService.shared.error("Time sync failed: \(errorMessage)")
        }
    }
    
    /// 获取当前准确时间（应用偏移量）
    func currentTime() -> Date {
        Date().addingTimeInterval(timeOffset)
    }
    
    /// 重置偏移量
    func resetOffset() {
        timeOffset = 0
        lastSyncTime = nil
        syncState = .idle
        LoggerService.shared.info("Time offset reset")
    }
    
    // MARK: - 私有方法
    
    private func startPeriodicSync() {
        syncTimer?.invalidate()
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.syncNow()
            }
        }
    }
}

// MARK: - 辅助扩展

extension TimeSyncService {
    /// 格式化偏移量显示
    var formattedOffset: String {
        let absOffset = abs(timeOffset)
        let sign = timeOffset >= 0 ? "+" : "-"
        
        if absOffset < 1 {
            return "\(sign)\(String(format: "%.0f", absOffset * 1000))ms"
        } else if absOffset < 60 {
            return "\(sign)\(String(format: "%.1f", absOffset))s"
        } else {
            let minutes = Int(absOffset / 60)
            let seconds = Int(absOffset.truncatingRemainder(dividingBy: 60))
            return "\(sign)\(minutes)m \(seconds)s"
        }
    }
    
    /// 上次同步时间的友好显示
    var lastSyncFormatted: String {
        guard let lastSync = lastSyncTime else {
            return "从未同步"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}
