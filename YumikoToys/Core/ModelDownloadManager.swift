//
//  ModelDownloadManager.swift
//  YumikoToys
//
//  模型下载管理器 - 自动下载和管理 MLX 模型文件（v4.1.1 - 镜像闭环自适应下载版）
//

import Foundation

/// 模型下载状态
enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded(path: URL)
    case failed(error: String)
}

/// 可下载模型信息
struct DownloadableModel: Identifiable {
    let id: String
    let name: String
    let description: String
    let size: String  // 如 "560 MB"
    let downloadURL: URL
    let localPath: String
    let isRequired: Bool
}

/// 模型下载管理器
@MainActor
final class ModelDownloadManager: ObservableObject {
    @Published var models: [DownloadableModel] = []
    @Published var downloadStates: [String: ModelDownloadState] = [:]
    @Published var authenticationRequired: String? = nil  // 需要认证的 host
    @Published var loginURL: URL? = nil
    
    private let fileManager = FileManager.default
    private let baseURL: URL
    
    // 预定义的模型列表 (已替换为极速、轻量的 MLX 社区量化版)
    static let availableModels: [DownloadableModel] = [
        DownloadableModel(
            id: "bge-m3-mlx",
            name: "BGE-M3 Embedding (MLX 8-Bit)",
            description: "本地语义理解模型（社区极速量化版，运行内存减半且速度大幅提升）",
            size: "560 MB", // 原版 1.1GB，社区 8-Bit 量化后仅需 560MB 左右
            downloadURL: URL(string: "https://huggingface.co/mlx-community/bge-m3-mlx-8bit/resolve/main/model.safetensors")!,
            localPath: "models/bge-m3-mlx",
            isRequired: true
        ),
        DownloadableModel(
            id: "distilbert-sentiment-zh",
            name: "DistilBERT 情感分析",
            description: "中文情感分类模型（原版即轻量，已原生兼容 MLX 极速加载）",
            size: "250 MB", // 原版已非常轻量，safetensors 大小约 268MB
            downloadURL: URL(string: "https://huggingface.co/lxyuan/distilbert-base-multilingual-cased-sentiments-student/resolve/main/model.safetensors")!,
            localPath: "models/distilbert-sentiment-zh",
            isRequired: false
        )
    ]
    
    init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.baseURL = documents.appendingPathComponent("YumikoToys Data")
        self.models = Self.availableModels
        
        // 检查现有模型状态
        checkDownloadedModels()
    }
    
    /// 检查已下载的模型
    private func checkDownloadedModels() {
        for model in models {
            let modelPath = baseURL.appendingPathComponent(model.localPath)
            let weightsFile = modelPath.appendingPathComponent("model.safetensors")
            
            if fileManager.fileExists(atPath: weightsFile.path) {
                downloadStates[model.id] = .downloaded(path: modelPath)
            } else {
                downloadStates[model.id] = .notDownloaded
            }
        }
    }
    
    /// 获取模型状态
    func state(for modelId: String) -> ModelDownloadState {
        downloadStates[modelId] ?? .notDownloaded
    }
    
    /// 检查模型是否已下载
    func isModelDownloaded(_ modelId: String) -> Bool {
        if case .downloaded = state(for: modelId) {
            return true
        }
        return false
    }
    
    /// 获取模型本地路径
    func modelPath(for modelId: String) -> URL? {
        guard case .downloaded(let path) = state(for: modelId) else {
            return nil
        }
        return path
    }
    
    /// 下载模型
    func downloadModel(_ modelId: String) async {
        guard let model = models.first(where: { $0.id == modelId }) else {
            downloadStates[modelId] = .failed(error: "模型不存在")
            return
        }
        
        // 检查是否已在下载中
        if case .downloading = state(for: modelId) {
            return
        }
        
        downloadStates[modelId] = .downloading(progress: 0.0)
        
        do {
            // 创建目标目录
            let modelDir = baseURL.appendingPathComponent(model.localPath)
            try fileManager.createDirectory(at: modelDir, withIntermediateDirectories: true)
            
            // 1. 下载主权重文件（.safetensors）
            let weightsURL = modelDir.appendingPathComponent("model.safetensors")
            try await downloadFile(from: model.downloadURL, to: weightsURL, modelId: modelId)
            
            // 2. 下载主配置文件（config.json）
            let configURL = model.downloadURL.deletingLastPathComponent().appendingPathComponent("config.json")
            let localConfigURL = modelDir.appendingPathComponent("config.json")
            try? await downloadFile(from: configURL, to: localConfigURL, modelId: nil) // 不追踪进度
            
            // 3. 【核心修正】下载现代分词字典文件（tokenizer.json，BGE-M3 的核心依赖）
            let tokenizerJSONURL = model.downloadURL.deletingLastPathComponent().appendingPathComponent("tokenizer.json")
            let localTokenizerJSONURL = modelDir.appendingPathComponent("tokenizer.json")
            try? await downloadFile(from: tokenizerJSONURL, to: localTokenizerJSONURL, modelId: nil)
            
            // 4. 下载传统词表文件（vocab.txt，用 try? 兼容，没有也不报错）
            let vocabURL = model.downloadURL.deletingLastPathComponent().appendingPathComponent("vocab.txt")
            let localVocabURL = modelDir.appendingPathComponent("vocab.txt")
            try? await downloadFile(from: vocabURL, to: localVocabURL, modelId: nil)
            
            // 5. 下载分词器基础配置（tokenizer_config.json）
            let tokenizerConfigURL = model.downloadURL.deletingLastPathComponent().appendingPathComponent("tokenizer_config.json")
            let localTokenizerConfigURL = modelDir.appendingPathComponent("tokenizer_config.json")
            try? await downloadFile(from: tokenizerConfigURL, to: localTokenizerConfigURL, modelId: nil)
            
            downloadStates[modelId] = .downloaded(path: modelDir)
            LoggerService.shared.info("Model \(modelId) downloaded successfully to \(modelDir.path)")
            
        } catch {
            if let authError = error as? DownloadError, case .authenticationRequired(let host) = authError {
                downloadStates[modelId] = .failed(error: "需要登录 \(host)")
                authenticationRequired = host
                loginURL = URL(string: "https://\(host)/login")
            } else {
                downloadStates[modelId] = .failed(error: error.localizedDescription)
            }
            LoggerService.shared.error("Failed to download model \(modelId): \(error)")
        }
    }
    
    /// 下载单个文件并追踪真实进度
        private func downloadFile(from remoteURL: URL, to localURL: URL, modelId: String?) async throws {
            if let modelId = modelId {
                // 如果提供了 modelId，说明是主模型文件，采用断点续传器追踪真实下载进度
                try await ProxyAwareDownloader.shared.downloadResumable(from: remoteURL, to: localURL) { [weak self] progress in
                    guard let self = self else { return }
                    // 由于下载是在后台流式执行，必须将进度回调分发回 @MainActor 更新发布属性
                    Task { @MainActor in
                        // 映射进度到 0.0 ~ 0.95，给后续几个配置文件（config、tokenizer）留一点点进度余量
                        let mappedProgress = progress * 0.95
                        self.downloadStates[modelId] = .downloading(progress: mappedProgress)
                    }
                }
            } else {
                // 辅助配置文件（config.json、tokenizer.json）直接进行静默下载，不报告进度
                try await ProxyAwareDownloader.shared.downloadResumable(from: remoteURL, to: localURL, progress: nil)
            }
        }
    
    /// 删除模型
    func deleteModel(_ modelId: String) throws {
        guard let model = models.first(where: { $0.id == modelId }) else {
            throw ModelDownloadError.modelNotFound
        }
        
        let modelDir = baseURL.appendingPathComponent(model.localPath)
        if fileManager.fileExists(atPath: modelDir.path) {
            try fileManager.removeItem(at: modelDir)
        }
        
        downloadStates[modelId] = .notDownloaded
        LoggerService.shared.info("Model \(modelId) deleted")
    }
    
    /// 获取已下载模型总大小
    func downloadedModelsSize() -> String {
        var totalSize: Int64 = 0
        
        for (modelId, state) in downloadStates {
            if case .downloaded(let path) = state,
               let model = models.first(where: { $0.id == modelId }) {
                let weightsPath = path.appendingPathComponent("model.safetensors")
                if let attributes = try? fileManager.attributesOfItem(atPath: weightsPath.path),
                   let size = attributes[.size] as? Int64 {
                    totalSize += size
                }
            }
        }
        
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    /// 下载所有必需模型
    func downloadRequiredModels() async {
        let requiredModels = models.filter { $0.isRequired }
        for model in requiredModels {
            if !isModelDownloaded(model.id) {
                await downloadModel(model.id)
            }
        }
    }

    // MARK: - 认证管理

    /// 保存认证 Cookie
    func saveAuthenticationCookie(_ cookieString: String) {
        guard let host = authenticationRequired else { return }
        ProxyAwareDownloader.shared.saveCookie(cookieString, for: host)
        authenticationRequired = nil
        LoggerService.shared.info("Authentication cookie saved, ready to retry download")
    }

    /// 打开登录页面
    func openLoginPage() {
        guard let host = authenticationRequired else { return }
        ProxyAwareDownloader.shared.openLoginPage(for: URL(string: "https://\(host)")!)
    }

    /// 清除认证 Cookie
    func clearAuthenticationCookie() {
        guard let host = authenticationRequired else { return }
        ProxyAwareDownloader.shared.clearCookie(for: host)
    }
}

// MARK: - 错误类型

enum ModelDownloadError: Error {
    case downloadFailed
    case modelNotFound
    case invalidURL
    case insufficientStorage
}
