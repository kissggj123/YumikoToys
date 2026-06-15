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

// MARK: - Ollama Setup Integrations

/// Ollama 安装与配置状态
enum OllamaSetupStatus: Equatable {
    case idle
    case checking
    case notInstalled
    case installingOllama(progress: Double)
    case installedButNotRunning
    case startingOllama
    case running
    case pullingModel(modelId: String, progress: Double, statusText: String)
    case success(modelId: String)
    case failed(String)
    
    var displayText: String {
        switch self {
        case .idle:
            return "就绪"
        case .checking:
            return "正在检查 Ollama 本地状态..."
        case .notInstalled:
            return "本地未检测到 Ollama 运行环境"
        case .installingOllama(let progress):
            return "正在下载并配置 Ollama (\(Int(progress * 100))%)"
        case .installedButNotRunning:
            return "Ollama 已安装，但服务未启动"
        case .startingOllama:
            return "正在启动 Ollama 后台服务..."
        case .running:
            return "Ollama 本地服务运行中"
        case .pullingModel(_, let progress, let statusText):
            let percent = Int(progress * 100)
            return "正在拉取模型: \(statusText) (\(percent)%)"
        case .success(let modelId):
            return "本地模型 \(modelId) 一键配置成功！"
        case .failed(let error):
            return "配置失败: \(error)"
        }
    }
}

@MainActor
final class OllamaSetupService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = OllamaSetupService()
    
    @Published var status: OllamaSetupStatus = .idle
    
    private let fileManager = FileManager.default
    private var downloadSession: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    
    // 轮询检查定时器
    private var pollTimer: Timer?
    
    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        // 创建专用 session
        self.downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }
    
    /// 检查 Ollama 安装及运行状态
    func checkStatus() async {
        status = .checking
        
        // 1. 先探测端口是否在运行
        let isRunning = await testOllamaPort()
        if isRunning {
            status = .running
            return
        }
        
        // 2. 端口不通，检查 Ollama.app 是否存在于常规应用程序目录
        let appPaths = [
            "/Applications/Ollama.app",
            "\(NSHomeDirectory())/Applications/Ollama.app"
        ]
        
        var isInstalled = false
        for path in appPaths {
            if fileManager.fileExists(atPath: path) {
                isInstalled = true
                break
            }
        }
        
        if isInstalled {
            status = .installedButNotRunning
        } else {
            status = .notInstalled
        }
    }
    
    /// 测试 Ollama 服务的默认端口
    private func testOllamaPort() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.5 // 快速超时
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return true
            }
            return false
        } catch {
            return false
        }
    }
    
    /// 启动已安装 of Ollama 应用程序
    func startOllama() async {
        status = .startingOllama
        
        let appPaths = [
            "/Applications/Ollama.app",
            "\(NSHomeDirectory())/Applications/Ollama.app"
        ]
        
        var launchPath: String?
        for path in appPaths {
            if fileManager.fileExists(atPath: path) {
                launchPath = path
                break
            }
        }
        
        guard let path = launchPath else {
            status = .failed("未找到 Ollama 安装路径，请重新检查。")
            return
        }
        
        // 运行 `open -a`
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        
        do {
            try task.run()
            
            // 轮询等待端口通畅 (最长等待 15 秒)
            var attempts = 0
            while attempts < 15 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 等待 1s
                let isRunning = await testOllamaPort()
                if isRunning {
                    status = .running
                    return
                }
                attempts += 1
            }
            status = .failed("Ollama 服务启动超时，请在系统菜单栏手动确认。")
        } catch {
            status = .failed("启动失败: \(error.localizedDescription)")
        }
    }
    
    /// 一键从官方下载并配置安装 Ollama
    func installOllama() {
        switch status {
        case .notInstalled, .idle, .failed:
            break
        default:
            return
        }
        
        status = .installingOllama(progress: 0.0)
        
        guard let url = URL(string: "https://ollama.com/download/Ollama-darwin.zip") else {
            status = .failed("下载地址无效")
            return
        }
        
        // 开始下载
        downloadTask = downloadSession?.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    /// 取消下载
    func cancelInstallation() {
        downloadTask?.cancel()
        downloadTask = nil
        status = .idle
    }
    
    /// 一键拉取指定的本地模型
    func pullModel(modelId: String) async {
        status = .pullingModel(modelId: modelId, progress: 0.0, statusText: "初始化中")
        
        guard let url = URL(string: "http://localhost:11434/api/pull") else {
            status = .failed("接口地址无效")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": modelId,
            "stream": true
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            status = .failed("序列化配置失败")
            return
        }
        request.httpBody = httpBody
        request.timeoutInterval = 3600 // 支持大模型下载超时，设长一些
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                status = .failed("Ollama 接口响应错误: 状态码 \(code)")
                return
            }
            
            for try await line in bytes.lines {
                guard !line.isEmpty else { continue }
                
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    let statusMsg = json["status"] as? String ?? "下载中"
                    let completed = json["completed"] as? Double ?? 0.0
                    let total = json["total"] as? Double ?? 0.0
                    
                    let progress = total > 0 ? (completed / total) : 0.0
                    
                    // 流式更新进度
                    status = .pullingModel(modelId: modelId, progress: progress, statusText: statusMsg)
                }
            }
            
            // 自动配置与绑定
            autoConfigureSelectedModel(modelId: modelId)
            status = .success(modelId: modelId)
            
        } catch {
            status = .failed("下载拉取模型出错: \(error.localizedDescription)")
        }
    }
    
    /// 拉取成功后，一键自动写入设置并激活该模型
    private func autoConfigureSelectedModel(modelId: String) {
        let settingsService = DependencyContainer.shared.apiSettingsService
        var settings = settingsService.getSettings()
        settings.currentProvider = .ollama
        
        var config = settings.providerConfigs[.ollama] ?? .ollamaDefault
        
        // 创建对应的模型结构信息
        let name: String
        let desc: String
        let isReasoning = modelId.contains("r1")
        
        if modelId == "qwen2.5:0.5b" {
            name = "Qwen 2.5 0.5B (极轻量)"
            desc = "阿里开源极轻量模型，运行如丝般顺滑"
        } else if modelId == "qwen2.5:1.5b" {
            name = "Qwen 2.5 1.5B (轻量)"
            desc = "阿里开源轻量模型，兼顾响应与逻辑能力"
        } else if modelId == "deepseek-r1:1.5b" {
            name = "DeepSeek R1 1.5B (本地推理)"
            desc = "本地超轻量思维链推理大模型"
        } else {
            name = modelId
            desc = "本地配置的 Ollama 模型"
        }
        
        let modelInfo = AIModelInfo(
            id: modelId,
            name: name,
            provider: .ollama,
            description: desc,
            supportsThinking: isReasoning,
            supportsVision: false,
            supportsTools: !isReasoning
        )
        
        // 如果列表中不存在则追加
        if !config.availableModels.contains(where: { $0.id == modelId }) {
            config.availableModels.append(modelInfo)
        }
        
        config.model = modelId
        settings.providerConfigs[.ollama] = config
        settingsService.updateSettings(settings)
        
        LoggerService.shared.info("[OllamaSetupService] 一键配置激活成功: \(modelId)")
    }
    
    // MARK: - URLSessionDownloadDelegate 实现
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0.0
        status = .installingOllama(progress: progress)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        status = .installingOllama(progress: 1.0)
        
        let tempZipURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Ollama-darwin.zip")
        
        do {
            // 清理已存在的临时文件
            if fileManager.fileExists(atPath: tempZipURL.path) {
                try fileManager.removeItem(at: tempZipURL)
            }
            
            // 移动到确定的临时 Zip 路径
            try fileManager.moveItem(at: location, to: tempZipURL)
            
            // 异步解压并安装
            Task.detached(priority: .background) { [weak self] in
                guard let self = self else { return }
                
                // 检查 Applications 写入权限
                let targetDir = "/Applications"
                let isWritable = FileManager.default.isWritableFile(atPath: targetDir)
                let finalDest = isWritable ? targetDir : "\(NSHomeDirectory())/Applications"
                
                // 创建文件夹（以防用户 ~/Applications 不存在）
                try? FileManager.default.createDirectory(atPath: finalDest, withIntermediateDirectories: true)
                
                let zipPath = tempZipURL.path
                
                // 执行解压脚本，解压完成后运行 open 启动服务
                let unzipScript = """
                unzip -o "\(zipPath)" -d "\(finalDest)/"
                open -a "\(finalDest)/Ollama.app"
                rm -f "\(zipPath)"
                """
                
                let task = Process()
                task.launchPath = "/bin/zsh"
                task.arguments = ["-c", unzipScript]
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    // 切换回主线程轮询服务状态
                    await MainActor.run {
                        self.status = .startingOllama
                        // 开启轮询
                        self.startPollingOllamaPort()
                    }
                } catch {
                    await MainActor.run {
                        self.status = .failed("解压安装出错: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            status = .failed("保存安装包出错: \(error.localizedDescription)")
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // 过滤主动取消
            if (error as NSError).code != NSURLErrorCancelled {
                status = .failed("下载失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 轮询探测
    
    private func startPollingOllamaPort() {
        pollTimer?.invalidate()
        var attempts = 0
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task {
                let isRunning = await self.testOllamaPort()
                if isRunning {
                    timer.invalidate()
                    self.status = .running
                } else {
                    attempts += 1
                    if attempts >= 15 {
                        timer.invalidate()
                        self.status = .failed("安装成功，但启动服务超时，请尝试手动运行应用程序列表中的 Ollama")
                    }
                }
            }
        }
    }
}
