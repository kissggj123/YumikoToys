//
//  ModelMemoryManager.swift
//  YumikoToys
//
//  模型内存管理器 - 监控和优化 MLX 模型内存使用
//

import Foundation
import MLX

// MARK: - Notification

extension Notification.Name {
    /// 模型内存淘汰通知，超过清理阈值时发送
    static let modelMemoryEviction = Notification.Name("com.yumikotoys.modelMemoryEviction")
}

// MARK: - MemoryUsageInfo

struct MemoryUsageInfo {
    let totalMemory: UInt64
    let usedMemory: UInt64
    let availableMemory: UInt64
    let modelMemory: UInt64
    var usedPercentage: Double
    var formattedUsed: String
    var formattedTotal: String
}

// MARK: - ModelMemoryManager

@MainActor
final class ModelMemoryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ModelMemoryManager()

    // MARK: - Published Properties

    /// 内存预算上限，默认 2 GB
    @Published var memoryBudget: UInt64 = 2 * 1024 * 1024 * 1024

    /// 当前已加载模型占用的总内存
    @Published private(set) var currentModelMemory: UInt64 = 0

    // MARK: - Private Properties

    /// 已加载模型字典：modelId -> 占用内存大小（字节）
    private var loadedModels: [String: UInt64] = [:]

    /// LRU 时间戳：modelId -> 最后使用时间
    private var lastUsedTimes: [String: Date] = [:]

    /// 内存监控定时器
    private var monitoringTask: Task<Void, Never>?

    /// 警告阈值（百分比）
    private let warningThreshold: Double = 0.80

    /// 清理阈值（百分比）
    private let cleanupThreshold: Double = 0.90

    /// 监控间隔（秒）
    private let monitoringInterval: TimeInterval = 5.0

    /// 是否已发出警告（避免重复日志）
    private var hasWarnedThisCycle: Bool = false

    /// 缓存的 ByteCountFormatter，避免重复创建
    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()

    // MARK: - Initialization

    private init() {
        startMemoryMonitoring()
        LoggerService.shared.info("[ModelMemoryManager] 初始化完成，内存预算: \(formatBytes(memoryBudget))")
    }

    deinit {
        monitoringTask?.cancel()
    }

    // MARK: - Memory Usage

    /// 获取当前内存使用信息
    func getMemoryUsage() -> MemoryUsageInfo {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        var usedMemory: UInt64 = 0

        // 通过 task_info 获取 physicalFootprint
        let footprint = getPhysicalFootprint()
        usedMemory = footprint

        let availableMemory = totalMemory > usedMemory ? totalMemory - usedMemory : 0
        let usedPercentage = totalMemory > 0 ? Double(usedMemory) / Double(totalMemory) : 0

        let formattedUsed = byteFormatter.string(fromByteCount: Int64(usedMemory))
        let formattedTotal = byteFormatter.string(fromByteCount: Int64(totalMemory))

        return MemoryUsageInfo(
            totalMemory: totalMemory,
            usedMemory: usedMemory,
            availableMemory: availableMemory,
            modelMemory: currentModelMemory,
            usedPercentage: usedPercentage,
            formattedUsed: formattedUsed,
            formattedTotal: formattedTotal
        )
    }

    // MARK: - Model Registration

    /// 注册模型加载，增加内存计数
    func registerModelLoad(modelId: String, memorySize: UInt64) {
        // 如果模型已注册，先移除旧记录
        if let existingSize = loadedModels[modelId] {
            currentModelMemory -= existingSize
            LoggerService.shared.info("[ModelMemoryManager] 模型 \(modelId) 重新加载，旧大小: \(formatBytes(existingSize))")
        }

        loadedModels[modelId] = memorySize
        lastUsedTimes[modelId] = Date()
        currentModelMemory += memorySize

        LoggerService.shared.info("[ModelMemoryManager] 模型已注册: \(modelId)，大小: \(formatBytes(memorySize))，总模型内存: \(formatBytes(currentModelMemory))")
    }

    /// 注销模型卸载，减少内存计数
    func unregisterModel(modelId: String) {
        guard let memorySize = loadedModels.removeValue(forKey: modelId) else {
            LoggerService.shared.warning("[ModelMemoryManager] 尝试注销未注册的模型: \(modelId)")
            return
        }

        lastUsedTimes.removeValue(forKey: modelId)
        currentModelMemory -= memorySize

        LoggerService.shared.info("[ModelMemoryManager] 模型已注销: \(modelId)，释放: \(formatBytes(memorySize))，剩余模型内存: \(formatBytes(currentModelMemory))")
    }

    /// 更新模型的 LRU 时间戳
    func touchModel(modelId: String) {
        guard loadedModels[modelId] != nil else {
            LoggerService.shared.warning("[ModelMemoryManager] 尝试 touch 未注册的模型: \(modelId)")
            return
        }
        lastUsedTimes[modelId] = Date()
    }

    // MARK: - Memory Check

    /// 检查是否有足够内存加载新模型
    func canLoadModel(requiredMemory: UInt64) -> Bool {
        let availableForModels = memoryBudget > currentModelMemory ? memoryBudget - currentModelMemory : 0
        let canLoad = requiredMemory <= availableForModels

        if !canLoad {
            LoggerService.shared.warning("[ModelMemoryManager] 内存不足，无法加载模型。需要: \(formatBytes(requiredMemory))，可用: \(formatBytes(availableForModels))")
        }

        return canLoad
    }

    // MARK: - Memory Cleanup

    /// 执行内存清理：MLX 缓存 + LRU 淘汰
    func performMemoryCleanup() async {
        LoggerService.shared.info("[ModelMemoryManager] 开始执行内存清理...")

        // 1. 清理 MLX 缓存
        GPU.clearCache()
        LoggerService.shared.info("[ModelMemoryManager] MLX 缓存已清理")

        // 2. LRU 淘汰：按最后使用时间排序，淘汰最久未使用的模型
        await evictLRUModelsIfNeeded()

        LoggerService.shared.info("[ModelMemoryManager] 内存清理完成，当前模型内存: \(formatBytes(currentModelMemory))")
    }

    // MARK: - Memory Report

    /// 生成内存报告文本
    func getMemoryReport() -> String {
        let usage = getMemoryUsage()
        var report = """
        ========== 模型内存报告 ==========
        系统总内存:    \(usage.formattedTotal)
        已使用内存:    \(usage.formattedUsed) (\(String(format: "%.1f", usage.usedPercentage * 100))%)
        可用内存:      \(formatBytes(usage.availableMemory))
        模型内存预算:  \(formatBytes(memoryBudget))
        模型已用内存:  \(formatBytes(usage.modelMemory))
        模型预算使用:  \(String(format: "%.1f", memoryBudget > 0 ? Double(usage.modelMemory) / Double(memoryBudget) * 100 : 0))%
        ----------------------------------------
        已加载模型 (\(loadedModels.count)):
        """

        let sortedModels = loadedModels.sorted { a, b in
            (lastUsedTimes[a.key] ?? .distantPast) > (lastUsedTimes[b.key] ?? .distantPast)
        }

        for (modelId, size) in sortedModels {
            let lastUsed = lastUsedTimes[modelId] ?? Date.distantPast
            let timeInterval = Date().timeIntervalSince(lastUsed)
            let timeDescription: String

            if timeInterval < 60 {
                timeDescription = "\(Int(timeInterval)) 秒前"
            } else if timeInterval < 3600 {
                timeDescription = "\(Int(timeInterval / 60)) 分钟前"
            } else {
                timeDescription = "\(Int(timeInterval / 3600)) 小时前"
            }

            report += "\n  - \(modelId): \(formatBytes(size)) (最后使用: \(timeDescription))"
        }

        report += "\n==================================\n"
        return report
    }

    // MARK: - Private Methods

    /// 启动内存监控定时器
    private func startMemoryMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.monitoringInterval ?? 5.0))
                self?.checkMemoryPressure()
            }
        }
    }

    /// 检查内存压力
    private func checkMemoryPressure() {
        let usage = getMemoryUsage()

        if usage.usedPercentage >= cleanupThreshold {
            // 超过清理阈值，发送淘汰通知
            hasWarnedThisCycle = false
            LoggerService.shared.warning("[ModelMemoryManager] 内存压力超过清理阈值 (\(String(format: "%.1f", cleanupThreshold * 100))%)，当前: \(String(format: "%.1f", usage.usedPercentage * 100))%")

            NotificationCenter.default.post(
                name: .modelMemoryEviction,
                object: self,
                userInfo: [
                    "usedPercentage": usage.usedPercentage,
                    "modelMemory": currentModelMemory,
                    "memoryBudget": memoryBudget
                ]
            )

            // 自动触发清理
            Task {
                await performMemoryCleanup()
            }
        } else if usage.usedPercentage >= warningThreshold && !hasWarnedThisCycle {
            // 超过警告阈值，仅记录警告
            hasWarnedThisCycle = true
            LoggerService.shared.warning("[ModelMemoryManager] 内存压力超过警告阈值 (\(String(format: "%.1f", warningThreshold * 100))%)，当前: \(String(format: "%.1f", usage.usedPercentage * 100))%")
        } else if usage.usedPercentage < warningThreshold {
            // 低于警告阈值，重置警告标记
            hasWarnedThisCycle = false
        }
    }

    /// 根据 LRU 策略淘汰模型，直到内存压力低于安全线
    private func evictLRUModelsIfNeeded() async {
        let usage = getMemoryUsage()
        let targetPercentage = warningThreshold - 0.10 // 淘汰到 70% 以下
        let targetMemory = UInt64(Double(usage.totalMemory) * targetPercentage)

        // 如果当前已用内存低于目标，无需淘汰
        if usage.usedMemory <= targetMemory {
            return
        }

        // 按最后使用时间排序（最旧的在前）
        let sortedByLRU = lastUsedTimes.sorted { a, b in
            a.value < b.value
        }

        // 记录基线内存使用，避免循环内重复调用系统接口
        var estimatedUsedMemory = usage.usedMemory

        for (modelId, _) in sortedByLRU {
            // 检查是否已达到目标
            if estimatedUsedMemory <= targetMemory {
                break
            }

            guard let modelSize = loadedModels[modelId] else { continue }

            LoggerService.shared.info("[ModelMemoryManager] LRU 淘汰模型: \(modelId)，释放: \(formatBytes(modelSize))")

            // 从记录中移除
            loadedModels.removeValue(forKey: modelId)
            lastUsedTimes.removeValue(forKey: modelId)
            currentModelMemory -= modelSize

            // 估算淘汰后的内存使用量
            estimatedUsedMemory = estimatedUsedMemory > modelSize ? estimatedUsedMemory - modelSize : 0

            // 发送逐个模型淘汰通知
            NotificationCenter.default.post(
                name: .modelMemoryEviction,
                object: self,
                userInfo: [
                    "evictedModelId": modelId,
                    "evictedModelSize": modelSize,
                    "reason": "lru_eviction"
                ]
            )
        }
    }

    /// 获取进程的 physicalFootprint
    private func getPhysicalFootprint() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return info.resident_size
        }

        // 回退：使用 physicalMemory 的估算值
        LoggerService.shared.warning("[ModelMemoryManager] 无法获取 physicalFootprint，使用估算值")
        return ProcessInfo.processInfo.physicalMemory / 4
    }

    /// 格式化字节数为可读字符串
    private func formatBytes(_ bytes: UInt64) -> String {
        return byteFormatter.string(fromByteCount: Int64(bytes))
    }
}
