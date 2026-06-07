//
//  ModelManagementService.swift
//  YumikoToys
//
//  统一模型管理服务 - 协调模型下载、加载、推理和内存管理（v4.1.2 - 健壮性无损重载与防误删安全版）
//

import Foundation
import Combine
import AppKit

// MARK: - 数据模型

/// 模型状态
enum ModelStatus: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case loading(progress: Double)
    case ready
    case inference(active: Bool)
    case error(String)

    var displayText: String {
        switch self {
        case .notDownloaded:
            return "未下载"
        case .downloading(let progress):
            return "下载中 \(String(format: "%.0f", progress * 100))%"
        case .downloaded:
            return "已下载"
        case .loading(let progress):
            return "加载中 \(String(format: "%.0f", progress * 100))%"
        case .ready:
            return "就绪"
        case .inference(let active):
            return active ? "推理中" : "推理完成"
        case .error(let message):
            return "错误: \(message)"
        }
    }

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

/// 模型类型
enum ModelType: String, CaseIterable, Identifiable {
    case embedding = "语义理解"
    case sentiment = "情感分析"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .embedding:
            return "brain.head.profile"
        case .sentiment:
            return "heart.text.square"
        }
    }
}

/// 模型信息
struct ModelInfo: Identifiable {
    let id: String
    let name: String
    let type: ModelType
    let size: String
    let sizeInBytes: UInt64
    let description: String
    let isRequired: Bool
    let downloadURL: URL
    var status: ModelStatus
    var isLoaded: Bool
    var inferenceCount: Int
    var averageInferenceTime: TimeInterval
    var lastUsed: Date?
    var localPath: URL?
}

/// 模型性能统计
struct ModelPerformanceStats {
    let modelId: String
    let modelName: String
    let inferenceCount: Int
    let averageInferenceTime: TimeInterval
    let totalInferenceTime: TimeInterval
    let lastUsed: Date?
    let memoryUsage: UInt64
    let isCurrentlyActive: Bool
}

// MARK: - 错误类型

/// 模型管理错误
enum ModelManagementError: Error, LocalizedError {
    case modelNotDownloaded
    case modelNotFound
    case insufficientMemory
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "模型尚未下载，请先下载模型"
        case .modelNotFound:
            return "未找到指定模型"
        case .insufficientMemory:
            return "可用内存不足，无法加载模型"
        case .loadFailed(let reason):
            return "模型加载失败: \(reason)"
        }
    }
}

// MARK: - ModelManagementService

/// 统一模型管理服务
///
/// 协调模型下载、加载、推理和内存管理，提供统一的模型生命周期管理接口。
/// 通过 Combine 订阅下载状态变化，并通过 NotificationCenter 响应内存淘汰事件。
@MainActor
final class ModelManagementService: ObservableObject {

    // MARK: - Published Properties

    /// 所有模型信息
    @Published private(set) var models: [ModelInfo] = []

    /// 当前推理中的模型 ID
    @Published private(set) var activeInference: String?

    /// 模型总内存使用量（字节）
    @Published private(set) var totalMemoryUsage: UInt64 = 0

    /// 服务是否已完成初始化
    @Published private(set) var isInitialized: Bool = false

    /// 是否需要认证（401/403 错误时设置）
    @Published var authenticationRequired: String? = nil

    /// 登录页面 URL
    @Published var loginURL: URL? = nil

    // MARK: - Private Properties

    private let downloadManager: ModelDownloadManager
    private let embeddingService: LocalEmbeddingService
    private let sentimentService: LocalSentimentService
    private let memoryManager: ModelMemoryManager

    private let fileManager = FileManager.default
    private let modelsDirectoryURL: URL

    private var cancellables = Set<AnyCancellable>()
    private var inferenceTimers: [String: CFAbsoluteTime] = [:]

    /// 推理累计时间追踪（用于计算平均推理时间）
    private var cumulativeInferenceTime: [String: TimeInterval] = [:]

    // MARK: - Initialization

    init(
        downloadManager: ModelDownloadManager,
        embeddingService: LocalEmbeddingService,
        sentimentService: LocalSentimentService
    ) {
        self.downloadManager = downloadManager
        self.embeddingService = embeddingService
        self.sentimentService = sentimentService
        self.memoryManager = .shared

        // 构建存储路径：~/Documents/YumikoToys Data/models/
        let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        self.modelsDirectoryURL = documentsURL
            .appendingPathComponent("YumikoToys Data")
            .appendingPathComponent("models")

        // 初始化模型信息列表
        self.models = Self.buildModelList(downloadManager: downloadManager)

        // 订阅下载状态变化
        subscribeToDownloadStates()

        // 订阅认证需求变化
        subscribeToAuthenticationRequired()

        // 订阅内存淘汰通知
        subscribeToMemoryEviction()

        LoggerService.shared.info("[ModelManagementService] 初始化完成")
    }

    // MARK: - 模型禁用控制 (Model Disabling Controls)
    
    /// 检查指定模型是否已被禁用
    func isModelDisabled(_ modelId: String) -> Bool {
        let disabledIDs = UserDefaults.standard.stringArray(forKey: "disabledModelIDs") ?? []
        return disabledIDs.contains(modelId)
    }
    
    /// 设置模型的禁用状态
    func setModelDisabled(_ modelId: String, disabled: Bool) {
        var disabledIDs = UserDefaults.standard.stringArray(forKey: "disabledModelIDs") ?? []
        if disabled {
            if !disabledIDs.contains(modelId) {
                disabledIDs.append(modelId)
                UserDefaults.standard.set(disabledIDs, forKey: "disabledModelIDs")
                LoggerService.shared.info("[ModelManagementService] 禁用模型: \(modelId)")
                // 如果已加载，则立即卸载
                if let model = models.first(where: { $0.id == modelId }), model.isLoaded {
                    unloadModel(modelId)
                }
            }
        } else {
            if let index = disabledIDs.firstIndex(of: modelId) {
                disabledIDs.remove(at: index)
                UserDefaults.standard.set(disabledIDs, forKey: "disabledModelIDs")
                LoggerService.shared.info("[ModelManagementService] 启用模型: \(modelId)")
            }
        }
        objectWillChange.send()
    }
    
    /// 一键禁用所有模型
    func disableAllModels() {
        var disabledIDs: [String] = []
        for model in models {
            disabledIDs.append(model.id)
            if model.isLoaded {
                unloadModel(model.id)
            }
        }
        UserDefaults.standard.set(disabledIDs, forKey: "disabledModelIDs")
        LoggerService.shared.info("[ModelManagementService] 一键禁用所有模型")
        objectWillChange.send()
    }
    
    /// 一键启用所有模型
    func enableAllModels() {
        UserDefaults.standard.removeObject(forKey: "disabledModelIDs")
        LoggerService.shared.info("[ModelManagementService] 一键启用所有模型")
        objectWillChange.send()
    }

    // MARK: - 公开方法

    /// 初始化服务：创建存储目录并刷新所有模型状态
    func initialize() async {
        LoggerService.shared.info("[ModelManagementService] 开始初始化...")

        // 创建模型存储目录
        do {
            try fileManager.createDirectory(
                at: modelsDirectoryURL,
                withIntermediateDirectories: true
            )
            LoggerService.shared.info(
                "[ModelManagementService] 模型目录已就绪: \(modelsDirectoryURL.path)"
            )
        } catch {
            LoggerService.shared.error(
                "[ModelManagementService] 创建模型目录失败: \(error.localizedDescription)"
            )
        }

        // 刷新所有模型状态
        await refreshAllStatus()

        // 自动加载所有已经下载但尚未加载的本地模型（若启用了启动时自动加载）
        if UserDefaults.standard.bool(forKey: "autoLoadModels") {
            for model in models {
                // 如果模型已被禁用，跳过自动加载
                if isModelDisabled(model.id) {
                    LoggerService.shared.info("[ModelManagementService] 模型 \(model.id) 已被禁用，跳过自动加载")
                    continue
                }
                
                if case .downloaded = downloadManager.state(for: model.id) {
                    let isLoaded: Bool
                    switch model.type {
                    case .embedding:
                        isLoaded = embeddingService.isModelLoaded
                    case .sentiment:
                        isLoaded = sentimentService.isModelLoaded
                    }
                    if !isLoaded {
                        LoggerService.shared.info("[ModelManagementService] 发现已下载但未加载的模型 \(model.id)，执行自动加载...")
                        do {
                            try await loadModel(model.id)
                        } catch {
                            LoggerService.shared.error("[ModelManagementService] 自动加载模型 \(model.id) 失败: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } else {
            LoggerService.shared.info("[ModelManagementService] 启动时自动加载已禁用，跳过加载已下载模型")
        }

        isInitialized = true
        LoggerService.shared.info("[ModelManagementService] 初始化完成")
    }

    /// 刷新所有模型状态：检查文件是否存在，检查服务是否已加载
    func refreshAllStatus() async {
        LoggerService.shared.info("[ModelManagementService] 刷新模型状态...")

        for index in models.indices {
            let modelId = models[index].id
            
            // 检查下载状态
            let downloadState = downloadManager.state(for: modelId)
            switch downloadState {
            case .notDownloaded:
                models[index].status = .notDownloaded
                models[index].localPath = nil

            case .downloading(let progress):
                models[index].status = .downloading(progress: progress)

            case .downloaded(let path):
                // 如果当前属于未下载或者错误的过渡状态，更新路径并刷新为已下载
                if models[index].status == .notDownloaded || models[index].localPath == nil {
                    models[index].status = .downloaded
                }
                models[index].localPath = path

            case .failed(let error):
                models[index].status = .error(error)
            }

            // 检查服务加载状态
            let isLoaded: Bool
            switch models[index].type {
            case .embedding:
                isLoaded = embeddingService.isModelLoaded
            case .sentiment:
                isLoaded = sentimentService.isModelLoaded
            }

            models[index].isLoaded = isLoaded
            if isLoaded {
                models[index].status = .ready
            }
        }

        // 更新总内存使用量
        updateTotalMemoryUsage()

        LoggerService.shared.info("[ModelManagementService] 模型状态刷新完成")
    }

    /// 下载指定模型
    func downloadModel(_ modelId: String) async {
        guard let index = models.firstIndex(where: { $0.id == modelId }) else {
            LoggerService.shared.warning(
                "[ModelManagementService] 下载请求: 模型 \(modelId) 不存在"
            )
            return
        }

        // 避免重复下载
        if case .downloading = models[index].status {
            LoggerService.shared.info(
                "[ModelManagementService] 模型 \(modelId) 已在下载中，跳过"
            )
            return
        }

        models[index].status = .downloading(progress: 0.0)
        LoggerService.shared.info(
            "[ModelManagementService] 开始下载模型: \(modelId)"
        )

        await downloadManager.downloadModel(modelId)

        // 下载完成后刷新状态
        let newState = downloadManager.state(for: modelId)
        switch newState {
        case .downloaded(let path):
            models[index].status = .downloaded
            models[index].localPath = path
            LoggerService.shared.info(
                "[ModelManagementService] 模型 \(modelId) 下载完成: \(path.path)"
            )
        case .failed(let error):
            models[index].status = .error(error)
            LoggerService.shared.error(
                "[ModelManagementService] 模型 \(modelId) 下载失败: \(error)"
            )
        default:
            break
        }
    }

    /// 删除指定模型（集成 native modal 确认拦截）
    func deleteModel(_ modelId: String, requiresConfirmation: Bool = true) async throws {
        guard let index = models.firstIndex(where: { $0.id == modelId }) else {
            throw ModelManagementError.modelNotFound
        }

        let modelName = models[index].name

        // 【安全确认强化】如果需要确认，弹出 macOS 系统级原生窗口阻断操作，防止用户误触
        if requiresConfirmation {
            let confirmed = await showDeletionConfirmationAlert(modelName: modelName)
            guard confirmed else {
                LoggerService.shared.info("[ModelManagementService] 用户已取消模型「\(modelName)」的删除清理。")
                return // 安全退出，不触碰任何本地文件
            }
        }

        LoggerService.shared.info("[ModelManagementService] 确认删除模型: \(modelId)")

        // 先安全卸载已加载的权重
        unloadModel(modelId)

        // 通过 downloadManager 清理本地磁盘文件
        try downloadManager.deleteModel(modelId)

        // 重置内存中的状态机数据
        models[index].status = .notDownloaded
        models[index].isLoaded = false
        models[index].localPath = nil
        models[index].inferenceCount = 0
        models[index].averageInferenceTime = 0
        models[index].lastUsed = nil
        cumulativeInferenceTime.removeValue(forKey: modelId)

        LoggerService.shared.info("[ModelManagementService] 模型 \(modelId) 及磁盘缓存已安全删除。")
    }

    /// 加载指定模型（强化失败重试逻辑：无损、不清除文件、支持路径寻回）
    func loadModel(_ modelId: String) async throws {
        guard let index = models.firstIndex(where: { $0.id == modelId }) else {
            throw ModelManagementError.modelNotFound
        }

        let model = models[index]

        // 【健壮性强化】如果没有成功加载（处于 .error 状态），重新加载绝不删除本地文件。
        // 寻回机制：若内存中的 localPath 意外为空，尝试从 downloadManager 动态读取正确的物理路径，杜绝要求用户重装。
        let resolvedPath = model.localPath ?? downloadManager.modelPath(for: modelId)
        guard let localPath = resolvedPath else {
            throw ModelManagementError.modelNotDownloaded
        }

        // 检查权重文件是否存在
        let weightsPath = localPath.appendingPathComponent("model.safetensors")
        guard fileManager.fileExists(atPath: weightsPath.path) else {
            throw ModelManagementError.modelNotDownloaded
        }

        // 检查内存预算
        let requiredMemory = model.sizeInBytes
        guard memoryManager.canLoadModel(requiredMemory: requiredMemory) else {
            throw ModelManagementError.insufficientMemory
        }

        // 标记为加载中
        models[index].status = .loading(progress: 0.0)
        LoggerService.shared.info(
            "[ModelManagementService] 开始加载模型: \(modelId)"
        )

        do {
            // 加载权重文件
            let weights = try MLXModelLoader.loadWeights(from: localPath)
            models[index].status = .loading(progress: 0.5)

            // 根据模型类型调用对应服务的加载方法
            switch model.type {
            case .embedding:
                try await embeddingService.loadWeights(weights, from: localPath)
            case .sentiment:
                try await sentimentService.loadWeights(weights, from: localPath)
            }

            models[index].status = .loading(progress: 0.9)

            // 注册内存占用
            memoryManager.registerModelLoad(modelId: modelId, memorySize: requiredMemory)

            // 更新状态
            models[index].isLoaded = true
            models[index].status = .ready
            models[index].lastUsed = Date()

            // 更新总内存
            updateTotalMemoryUsage()

            LoggerService.shared.info(
                "[ModelManagementService] 模型 \(modelId) 加载完成，占用内存: \(ByteCountFormatter.string(fromByteCount: Int64(requiredMemory), countStyle: .memory))"
            )

        } catch let error as ModelManagementError {
            models[index].status = .error(error.localizedDescription)
            throw error
        } catch {
            let message = error.localizedDescription
            models[index].status = .error(message)
            throw ModelManagementError.loadFailed(message)
        }
    }

    /// 卸载指定模型（停止服务，注销内存）
    func unloadModel(_ modelId: String) {
        guard let index = models.firstIndex(where: { $0.id == modelId }) else {
            LoggerService.shared.warning(
                "[ModelManagementService] 卸载请求: 模型 \(modelId) 不存在"
            )
            return
        }

        let model = models[index]
        guard model.isLoaded else {
            LoggerService.shared.info(
                "[ModelManagementService] 模型 \(modelId) 未加载，无需卸载"
            )
            return
        }

        LoggerService.shared.info("[ModelManagementService] 卸载模型: \(modelId)")

        // 停止对应服务
        switch model.type {
        case .embedding:
            embeddingService.stop()
        case .sentiment:
            sentimentService.stop()
        }

        // 注销内存
        memoryManager.unregisterModel(modelId: modelId)

        // 释放 MLX 缓存
        MLXModelLoader.releaseWeights()

        // 更新状态
        models[index].isLoaded = false
        if case .ready = models[index].status {
            models[index].status = .downloaded
        }

        // 清除推理追踪数据
        inferenceTimers.removeValue(forKey: modelId)
        cumulativeInferenceTime.removeValue(forKey: modelId)

        // 更新总内存
        updateTotalMemoryUsage()

        LoggerService.shared.info("[ModelManagementService] 模型 \(modelId) 已卸载")
    }

    /// 开始推理追踪
    func beginInference(modelId: String) {
        guard let index = models.firstIndex(where: { $0.id == modelId }),
              models[index].isLoaded else {
            LoggerService.shared.warning(
                "[ModelManagementService] beginInference: 模型 \(modelId) 未加载"
            )
            return
        }

        activeInference = modelId
        models[index].status = .inference(active: true)
        inferenceTimers[modelId] = CFAbsoluteTimeGetCurrent()

        // 更新 LRU 时间戳
        memoryManager.touchModel(modelId: modelId)

        LoggerService.shared.info("[ModelManagementService] 推理开始: \(modelId)")
    }

    /// 结束推理追踪
    func endInference(modelId: String, inferenceTime: TimeInterval) {
        guard let index = models.firstIndex(where: { $0.id == modelId }) else {
            return
        }

        // 清除计时器
        inferenceTimers.removeValue(forKey: modelId)

        // 更新推理统计
        models[index].inferenceCount += 1
        let previousTotal = cumulativeInferenceTime[modelId] ?? 0
        let newTotal = previousTotal + inferenceTime
        cumulativeInferenceTime[modelId] = newTotal
        models[index].averageInferenceTime = newTotal / Double(models[index].inferenceCount)
        models[index].lastUsed = Date()

        // 恢复状态
        models[index].status = .ready
        if activeInference == modelId {
            activeInference = nil
        }

        LoggerService.shared.info(
            "[ModelManagementService] 推理结束: \(modelId)，"
                + "耗时: \(String(format: "%.2f", inferenceTime * 1000))ms，"
                + "平均: \(String(format: "%.2f", models[index].averageInferenceTime * 1000))ms"
        )
    }

    /// 打开登录页面
    func openLoginPage() {
        guard let host = authenticationRequired else {
            LoggerService.shared.warning("[ModelManagementService] 无法打开登录页面：未设置认证需求")
            return
        }
        let url = URL(string: "https://\(host)/login")!
        NSWorkspace.shared.open(url)
        LoggerService.shared.info("[ModelManagementService] 已打开登录页面: \(url.absoluteString)")
    }

    /// 保存认证 Cookie
    /// - Parameters:
    ///   - cookieString: Cookie 字符串
    ///   - host: 可选，指定 host，如果不传则使用当前的 authenticationRequired
    func saveAuthenticationCookie(_ cookieString: String, host: String? = nil) {
        let targetHost = host ?? authenticationRequired ?? "huggingface.co"
        ProxyAwareDownloader.shared.saveCookie(cookieString, for: targetHost)
        // 设置认证状态以便后续使用
        if authenticationRequired == nil {
            authenticationRequired = targetHost
        }
        LoggerService.shared.info("[ModelManagementService] 已保存认证 Cookie for \(targetHost)")
    }

    /// 清除认证状态
    func clearAuthentication() {
        guard let host = authenticationRequired else { return }
        ProxyAwareDownloader.shared.clearCookie(for: host)
        authenticationRequired = nil
        loginURL = nil
        LoggerService.shared.info("[ModelManagementService] 已清除认证状态")
    }

    /// 获取指定模型的性能统计
    func getPerformanceStats(_ modelId: String) -> ModelPerformanceStats? {
        guard let model = models.first(where: { $0.id == modelId }) else {
            return nil
        }

        let totalInferenceTime = cumulativeInferenceTime[modelId] ?? 0
        let isActive = activeInference == modelId

        // 获取该模型的内存占用
        let memoryUsage: UInt64
        if model.isLoaded {
            memoryUsage = model.sizeInBytes
        } else {
            memoryUsage = 0
        }

        return ModelPerformanceStats(
            modelId: model.id,
            modelName: model.name,
            inferenceCount: model.inferenceCount,
            averageInferenceTime: model.averageInferenceTime,
            totalInferenceTime: totalInferenceTime,
            lastUsed: model.lastUsed,
            memoryUsage: memoryUsage,
            isCurrentlyActive: isActive
        )
    }

    // MARK: - Private Methods

    /// 构建初始模型信息列表
    private static func buildModelList(downloadManager: ModelDownloadManager) -> [ModelInfo] {
        downloadManager.models.map { downloadable in
            let modelType: ModelType
            let sizeInBytes: UInt64

            switch downloadable.id {
            case "bge-m3-mlx":
                modelType = .embedding
                sizeInBytes = 450 * 1024 * 1024  // 450 MB
            case "distilbert-sentiment-zh":
                modelType = .sentiment
                sizeInBytes = 250 * 1024 * 1024  // 250 MB
            default:
                modelType = .embedding
                sizeInBytes = 0
            }

            return ModelInfo(
                id: downloadable.id,
                name: downloadable.name,
                type: modelType,
                size: downloadable.size,
                sizeInBytes: sizeInBytes,
                description: downloadable.description,
                isRequired: downloadable.isRequired,
                downloadURL: downloadable.downloadURL,
                status: .notDownloaded,
                isLoaded: false,
                inferenceCount: 0,
                averageInferenceTime: 0,
                lastUsed: nil,
                localPath: nil
            )
        }
    }

    /// 订阅 downloadManager 的下载状态变化
    private func subscribeToDownloadStates() {
        downloadManager.$downloadStates
            .receive(on: RunLoop.main)
            .sink { [weak self] states in
                guard let self = self else { return }

                for (modelId, state) in states {
                    guard let index = self.models.firstIndex(where: { $0.id == modelId }) else {
                        continue
                    }

                    switch state {
                    case .notDownloaded:
                        self.models[index].status = .notDownloaded
                        self.models[index].localPath = nil

                    case .downloading(let progress):
                        // 【自适应整合修复】去掉原有的 if case 状态前置约束，
                        // 即使状态初始化同步存在些许毫秒级的延迟，也强制将其推入并维持在 .downloading 状态，确保进度条能立即刷新更新
                        self.models[index].status = .downloading(progress: progress)

                    case .downloaded(let path):
                        self.models[index].status = .downloaded
                        self.models[index].localPath = path

                    case .failed(let error):
                        self.models[index].status = .error(error)
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// 订阅认证需求变化
    private func subscribeToAuthenticationRequired() {
        downloadManager.$authenticationRequired
            .receive(on: RunLoop.main)
            .sink { [weak self] host in
                self?.authenticationRequired = host
            }
            .store(in: &cancellables)

        downloadManager.$loginURL
            .receive(on: RunLoop.main)
            .sink { [weak self] url in
                self?.loginURL = url
            }
            .store(in: &cancellables)
    }

    /// 订阅内存淘汰通知，自动卸载被淘汰的模型
    private func subscribeToMemoryEviction() {
        NotificationCenter.default
            .publisher(for: .modelMemoryEviction)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self else { return }

                // 检查是否是逐个模型淘汰通知
                if let evictedModelId = notification.userInfo?["evictedModelId"] as? String {
                    let reason = notification.userInfo?["reason"] as? String ?? "unknown"
                    LoggerService.shared.warning(
                        "[ModelManagementService] 收到内存淘汰通知，"
                            + "模型: \(evictedModelId)，原因: \(reason)"
                    )

                    // 自动卸载被淘汰的模型
                    if let index = self.models.firstIndex(where: { $0.id == evictedModelId }),
                       self.models[index].isLoaded {
                        self.unloadModel(evictedModelId)
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// 更新总内存使用量
    private func updateTotalMemoryUsage() {
        totalMemoryUsage = models
            .filter { $0.isLoaded }
            .reduce(0) { $0 + $1.sizeInBytes }
    }
    
    // MARK: - 辅助原生确认弹窗
    
    /// 弹出 macOS 原生删除确认弹窗
    private func showDeletionConfirmationAlert(modelName: String) async -> Bool {
        let alert = NSAlert()
        alert.messageText = "确定要删除该模型吗？"
        alert.informativeText = "您将删除本地模型「\(modelName)」。删除后，如果需要重新使用，您必须再次进行下载。此操作无法撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定删除")
        alert.addButton(withTitle: "取消")
        
        // 确保在主线程上安全渲染并运行模态
        let response = alert.runModal()
        return response == .alertFirstButtonReturn
    }
}
