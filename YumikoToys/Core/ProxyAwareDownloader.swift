//
//  ProxyAwareDownloader.swift
//  YumikoToys
//
//  代理感知下载器 - 自动检测系统代理设置，用于从 HuggingFace 下载 MLX 模型文件。
//  支持 CFNetwork 系统代理检测、环境变量回退、下载进度回调及 async/await 并发模型。
//  集成 HuggingFaceAuthService 进行 Token 认证。
//

import Foundation
import CFNetwork
import AppKit

// MARK: - 代理配置

/// 系统代理配置信息
struct ProxyConfiguration: Sendable {
    /// HTTP 代理地址（如 http://127.0.0.1:7897）
    let httpProxy: URL?
    /// HTTPS 代理地址
    let httpsProxy: URL?
    /// 是否启用了任何代理
    var isEnabled: Bool {
        httpProxy != nil || httpsProxy != nil
    }
}

// MARK: - 下载错误

/// 下载过程中可能出现的错误
enum DownloadError: Error, LocalizedError {
    /// 服务器返回了无效响应
    case invalidResponse
    /// 未收到任何数据
    case noData
    /// HTTP 状态码错误
    case httpError(statusCode: Int)
    /// 文件移动失败
    case fileMoveFailed(source: URL, destination: URL)
    /// 目标目录创建失败
    case directoryCreationFailed(path: String)
    /// 未授权（401）
    case unauthorized
    /// 禁止访问（403）
    case forbidden
    /// 需要登录认证
    case authenticationRequired(host: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器返回了无效响应"
        case .noData:
            return "未收到任何数据"
        case .httpError(let statusCode):
            return "HTTP 请求失败，状态码: \(statusCode)"
        case .fileMoveFailed(let source, let destination):
            return "无法将临时文件从 \(source.lastPathComponent) 移动到 \(destination.path)"
        case .directoryCreationFailed(let path):
            return "无法创建目标目录: \(path)"
        case .unauthorized:
            return "未授权访问（401），请检查认证信息"
        case .forbidden:
            return "禁止访问（403），权限不足"
        case .authenticationRequired(let host):
            return "需要登录 \(host) 才能下载此资源"
        }
    }
}

// MARK: - 代理感知下载器

/// 代理感知下载器，自动检测系统代理并创建支持代理的 URLSession。
/// 用于从 HuggingFace 等外部源下载 MLX 模型文件。
final class ProxyAwareDownloader: Sendable {

    /// 共享单例
    static let shared = ProxyAwareDownloader()

    /// 内部使用的 URLSession（已配置代理）
    private let session: URLSession

    /// 当前生效的代理配置
    private let proxyConfiguration: ProxyConfiguration

    // MARK: - Cookie 管理

    /// 保存 Cookie 到 SecureStorage
    func saveCookie(_ cookieString: String, for host: String) {
        let secureKey = "hfcookie_\(host)"
        
        // 先删除旧的系统钥匙串项
        clearCookieFromKeychainExplicit(for: host)

        // 保存新的到本地加密存储
        SecureStorage.saveSecureItem(cookieString, key: secureKey)

        // 更新 URLSession 的 cookie 存储
        updateSessionCookies(for: host, cookieString: cookieString)
        LoggerService.shared.info("Cookie saved for \(host)")
    }

    /// 从 SecureStorage/Keychain 读取 Cookie
    func loadCookie(for host: String) -> String? {
        let secureKey = "hfcookie_\(host)"
        // 1. 优先从免密码弹窗的本地加密存储读取
        if let cookie = SecureStorage.retrieveSecureItem(key: secureKey) {
            return cookie
        }
        
        // 2. 如果本地加密存储没有，从系统钥匙串读取并执行单向静默迁移
        let key = "com.yumikotoys.hfcookie.\(host)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data, let cookie = String(data: data, encoding: .utf8) {
            // 写入本地加密存储
            SecureStorage.saveSecureItem(cookie, key: secureKey)
            // 从系统钥匙串中彻底抹除，后续更新版本将不再触发系统钥匙串弹窗
            clearCookieFromKeychainExplicit(for: host)
            LoggerService.shared.info("Cookie for \(host) migrated from Keychain to SecureStorage successfully.")
            return cookie
        }

        return nil
    }

    /// 清除 Cookie
    func clearCookie(for host: String) {
        clearCookieFromKeychainExplicit(for: host)
        let secureKey = "hfcookie_\(host)"
        SecureStorage.deleteSecureItem(key: secureKey)
        LoggerService.shared.info("Cookie cleared for \(host)")
    }
    
    /// 仅从系统钥匙串清除 Cookie 的辅助方法
    private func clearCookieFromKeychainExplicit(for host: String) {
        let key = "com.yumikotoys.hfcookie.\(host)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// 打开登录页面
    func openLoginPage(for remoteURL: URL) {
        let host = remoteURL.host ?? "huggingface.co"
        let loginURL = URL(string: "https://\(host)/login")!
        NSWorkspace.shared.open(loginURL)
        LoggerService.shared.info("Opened login page: \(loginURL.absoluteString)")
    }

    /// 更新 URLSession 的 cookie 存储
    private func updateSessionCookies(for host: String, cookieString: String) {
        let config = session.configuration
        guard let url = URL(string: "https://\(host)") else { return }

        // 解析 cookie 字符串
        let cookiePairs = cookieString.components(separatedBy: ";")
        for pair in cookiePairs {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            guard let range = trimmed.range(of: "=") else { continue }
            let name = String(trimmed[..<range.lowerBound])
            let value = String(trimmed[range.upperBound...])

            let cookie = HTTPCookie(properties: [
                .name: name,
                .value: value,
                .domain: "." + host,
                .path: "/"
            ])

            config.httpCookieStorage?.setCookie(cookie!)
        }
    }

    private init() {
        let configuration = Self.createProxyAwareConfiguration()
        self.proxyConfiguration = Self.getSystemProxyConfiguration()
        self.session = URLSession(configuration: configuration)

        if proxyConfiguration.isEnabled {
            LoggerService.shared.info("ProxyAwareDownloader initialized with proxy - HTTP: \(proxyConfiguration.httpProxy?.absoluteString ?? "none"), HTTPS: \(proxyConfiguration.httpsProxy?.absoluteString ?? "none")")
        } else {
            LoggerService.shared.info("ProxyAwareDownloader initialized without proxy (direct connection)")
        }
    }

    // MARK: - 代理检测

    /// 检测系统代理配置。
    /// 优先使用 CFNetworkCopySystemProxySettings() 读取 macOS 系统代理设置，
    /// 若未检测到则回退到环境变量 HTTP_PROXY / HTTPS_PROXY。
    ///
    /// - Returns: 包含 HTTP/HTTPS 代理地址的配置信息
    static func getSystemProxyConfiguration() -> ProxyConfiguration {
        var httpProxy: URL?
        var httpsProxy: URL?

        // 1. 尝试从 CFNetwork 读取系统代理设置
        if let proxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] {
            httpProxy = Self.extractProxyURL(from: proxySettings, key: kCFProxyTypeHTTP as String)
            httpsProxy = Self.extractProxyURL(from: proxySettings, key: kCFProxyTypeHTTPS as String)
        }

        // 2. 回退到环境变量
        if httpProxy == nil, let envHTTP = ProcessInfo.processInfo.environment["HTTP_PROXY"] ?? ProcessInfo.processInfo.environment["http_proxy"] {
            httpProxy = URL(string: envHTTP)
            if httpProxy != nil {
                LoggerService.shared.info("Using HTTP proxy from environment variable: \(envHTTP)")
            }
        }

        if httpsProxy == nil, let envHTTPS = ProcessInfo.processInfo.environment["HTTPS_PROXY"] ?? ProcessInfo.processInfo.environment["https_proxy"] {
            httpsProxy = URL(string: envHTTPS)
            if httpsProxy != nil {
                LoggerService.shared.info("Using HTTPS proxy from environment variable: \(envHTTPS)")
            }
        }

        return ProxyConfiguration(httpProxy: httpProxy, httpsProxy: httpsProxy)
    }

    // MARK: - URLSession 配置

    /// 创建支持代理的 URLSessionConfiguration。
    /// 配置包括：代理设置、超时时间、最大连接数。
    ///
    /// - Returns: 已配置代理的 URLSessionConfiguration
    static func createProxyAwareConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default

        let proxy = getSystemProxyConfiguration()

        if proxy.isEnabled {
            var proxyDict: [String: Any] = [:]

            // HTTP 代理
            if let httpProxy = proxy.httpProxy {
                proxyDict[kCFNetworkProxiesHTTPEnable as String] = true
                proxyDict[kCFNetworkProxiesHTTPProxy as String] = httpProxy.host
                proxyDict[kCFNetworkProxiesHTTPPort as String] = httpProxy.port
            }

            // HTTPS 代理
            if let httpsProxy = proxy.httpsProxy {
                proxyDict[kCFNetworkProxiesHTTPSEnable as String] = true
                proxyDict[kCFNetworkProxiesHTTPSProxy as String] = httpsProxy.host
                proxyDict[kCFNetworkProxiesHTTPSPort as String] = httpsProxy.port
            }

            configuration.connectionProxyDictionary = proxyDict
        } else {
            // 无代理时显式禁用代理，避免使用系统代理缓存
            configuration.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as String: false,
                kCFNetworkProxiesHTTPSEnable as String: false
            ]
        }

        // 超时设置
        configuration.timeoutIntervalForRequest = 5 * 60       // 请求超时：5 分钟
        configuration.timeoutIntervalForResource = 60 * 60     // 资源超时：1 小时

        // 最大连接数
        configuration.httpMaximumConnectionsPerHost = 4

        // 允许蜂窝网络（macOS 上通常无影响，但保持兼容性）
        configuration.allowsCellularAccess = true

        // 等待网络连接
        configuration.waitsForConnectivity = true

        return configuration
    }

    // MARK: - 下载方法（带进度回调）

    /// 下载文件到指定路径，支持进度回调和完成回调。
    ///
    /// - Parameters:
    ///   - remoteURL: 远程文件 URL
    ///   - destinationURL: 本地保存路径
    ///   - progress: 进度回调，参数为 0.0 ~ 1.0 的进度值
    ///   - completion: 完成回调，成功时返回目标 URL，失败时返回错误
    func download(
        from remoteURL: URL,
        to destinationURL: URL,
        progress: (@Sendable (Double) -> Void)? = nil,
        completion: (@Sendable @MainActor (Result<URL, Error>) -> Void)? = nil
    ) {
        LoggerService.shared.info("Starting download from \(remoteURL.absoluteString) to \(destinationURL.path)")

        let task = session.downloadTask(with: remoteURL) { [weak self] tempURL, response, error in
            if let error = error {
                LoggerService.shared.error("Download failed for \(remoteURL.lastPathComponent): \(error.localizedDescription)")
                Task { @MainActor in
                    completion?(.failure(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                LoggerService.shared.error("Download failed: invalid response for \(remoteURL.lastPathComponent)")
                Task { @MainActor in
                    completion?(.failure(DownloadError.invalidResponse))
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                LoggerService.shared.error("Download failed: HTTP \(httpResponse.statusCode) for \(remoteURL.lastPathComponent)")
                Task { @MainActor in
                    completion?(.failure(DownloadError.httpError(statusCode: httpResponse.statusCode)))
                }
                return
            }

            guard let tempURL = tempURL else {
                LoggerService.shared.error("Download failed: no data received for \(remoteURL.lastPathComponent)")
                Task { @MainActor in
                    completion?(.failure(DownloadError.noData))
                }
                return
            }

            // 移动临时文件到目标路径
            do {
                let fileManager = FileManager.default
                let destinationDirectory = destinationURL.deletingLastPathComponent()

                // 确保目标目录存在
                if !fileManager.fileExists(atPath: destinationDirectory.path) {
                    try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
                }

                // 移除已存在的文件
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }

                try fileManager.moveItem(at: tempURL, to: destinationURL)

                LoggerService.shared.info("Download completed: \(remoteURL.lastPathComponent) -> \(destinationURL.path)")
                Task { @MainActor in
                    completion?(.success(destinationURL))
                }
            } catch {
                LoggerService.shared.error("Failed to move downloaded file: \(error.localizedDescription)")
                Task { @MainActor in
                    completion?(.failure(DownloadError.fileMoveFailed(source: tempURL, destination: destinationURL)))
                }
            }
        }

        // 设置进度观察
        if let progress = progress {
            let observation = task.progress.observe(\.fractionCompleted) { observedProgress, _ in
                DispatchQueue.main.async {
                    progress(observedProgress.fractionCompleted)
                }
            }
            // observation 将随 task 生命周期自动释放
            _ = observation
        }

        task.resume()
    }

    // MARK: - 断点续传下载

    /// 断点续传下载（async/await，带进度）
    @discardableResult
    func downloadResumable(
        from remoteURL: URL,
        to destinationURL: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        LoggerService.shared.info("Starting resumable download from \(remoteURL.absoluteString)")

        let fileManager = FileManager.default
        let partFileURL = destinationURL.appendingPathExtension("part")

        // 确保目标目录存在
        let destinationDirectory = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: destinationDirectory.path) {
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        }

        // 检查已有部分文件大小
        var downloadedBytes: Int64 = 0
        if fileManager.fileExists(atPath: partFileURL.path) {
            let attributes = try fileManager.attributesOfItem(atPath: partFileURL.path)
            downloadedBytes = attributes[.size] as? Int64 ?? 0
            LoggerService.shared.info("Found partial file: \(downloadedBytes) bytes already downloaded")
        }

        // 构建请求
        var request = URLRequest(url: remoteURL)
        request.timeoutInterval = 5 * 60

        // 如果有已下载的部分，设置 Range 头
        if downloadedBytes > 0 {
            request.setValue("bytes=\(downloadedBytes)-", forHTTPHeaderField: "Range")
        }

        // 添加 HuggingFace Token 认证（如果已配置）
        if let authHeader = await HuggingFaceAuthService.shared.getAuthorizationHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            LoggerService.shared.debug("[ProxyAwareDownloader] 已添加 HuggingFace Token 认证")
        }

        // 检查是否有保存的 Cookie（兼容旧版）
        if let host = remoteURL.host, let cookie = loadCookie(for: host) {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        }

        let (asyncBytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse
        }

        // 处理认证错误
        if httpResponse.statusCode == 401 {
            throw DownloadError.unauthorized
        }
        if httpResponse.statusCode == 403 {
            if let host = remoteURL.host {
                throw DownloadError.authenticationRequired(host: host)
            }
            throw DownloadError.forbidden
        }

        // 验证响应状态码
        if httpResponse.statusCode != 206 && !(200...299).contains(httpResponse.statusCode) {
            throw DownloadError.httpError(statusCode: httpResponse.statusCode)
        }

        // 获取总文件大小
        let totalExpectedSize: Int64
        if httpResponse.statusCode == 206 {
            // 续传：从 Content-Range 解析总大小
            // 格式: bytes 0-999/10000
            if let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range") {
                let parts = contentRange.components(separatedBy: "/")
                if parts.count == 2, let total = Int64(parts[1]) {
                    totalExpectedSize = total
                } else {
                    totalExpectedSize = httpResponse.expectedContentLength + downloadedBytes
                }
            } else {
                totalExpectedSize = httpResponse.expectedContentLength + downloadedBytes
            }
        } else {
            // 全新下载
            totalExpectedSize = httpResponse.expectedContentLength
            downloadedBytes = 0
        }

        // 打开文件（追加模式或新建）
        let fileHandle: FileHandle
        if fileManager.fileExists(atPath: partFileURL.path) && downloadedBytes > 0 {
            fileHandle = try FileHandle(forWritingTo: partFileURL)
            try fileHandle.seekToEnd()
        } else {
            // 【核心修复】如果文件不存在，直接使用 FileHandle(forWritingTo:) 会抛出 "The file doesn't exist" 异常。
            // 必须先调用 fileManager.createFile() 创建一个空白物理临时文件
            fileManager.createFile(atPath: partFileURL.path, contents: nil, attributes: nil)
            fileHandle = try FileHandle(forWritingTo: partFileURL)
        }

        defer {
            try? fileHandle.close()
        }

        // 流式写入
        var buffer = Data()
        let bufferSize = 64 * 1024  // 64KB 缓冲区

        for try await byte in asyncBytes {
            buffer.append(byte)

            if buffer.count >= bufferSize {
                try fileHandle.write(contentsOf: buffer)
                downloadedBytes += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)

                // 报告进度
                if let progress = progress, totalExpectedSize > 0 {
                    let fraction = Double(downloadedBytes) / Double(totalExpectedSize)
                    await MainActor.run { progress(fraction) }
                }
            }
        }

        // 写入剩余数据
        if !buffer.isEmpty {
            try fileHandle.write(contentsOf: buffer)
            downloadedBytes += Int64(buffer.count)
        }

        // 完成进度
        if let progress = progress {
            await MainActor.run { progress(1.0) }
        }

        // 重命名为正式文件
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: partFileURL, to: destinationURL)

        LoggerService.shared.info("Resumable download completed: \(remoteURL.lastPathComponent) (\(downloadedBytes) bytes)")
        return destinationURL
    }

    // MARK: - 下载方法（async/await）

    /// 异步下载文件到指定路径。
    ///
    /// - Parameters:
    ///   - remoteURL: 远程文件 URL
    ///   - destinationURL: 本地保存路径
    /// - Returns: 下载完成后的本地文件 URL
    /// - Throws: DownloadError 或底层网络错误
    @discardableResult
    func download(from remoteURL: URL, to destinationURL: URL) async throws -> URL {
        return try await downloadResumable(from: remoteURL, to: destinationURL)
    }

    // MARK: - 带进度的 async/await 下载

    /// 异步下载文件到指定路径，支持进度回调。
    ///
    /// - Parameters:
    ///   - remoteURL: 远程文件 URL
    ///   - destinationURL: 本地保存路径
    ///   - progress: 进度回调，参数为 0.0 ~ 1.0 的进度值
    /// - Returns: 下载完成后的本地文件 URL
    /// - Throws: DownloadError 或底层网络错误
    @discardableResult
    func download(
        from remoteURL: URL,
        to destinationURL: URL,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> URL {
        LoggerService.shared.info("Starting async download with progress from \(remoteURL.absoluteString)")

        return try await withCheckedThrowingContinuation { continuation in
            download(from: remoteURL, to: destinationURL, progress: progress) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - 私有辅助方法

    /// 从 CFNetwork 代理字典中提取指定类型的代理 URL。
    ///
    /// - Parameters:
    ///   - proxySettings: CFNetwork 返回的代理设置字典
    ///   - key: 代理类型键（如 kCFProxyTypeHTTP）
    /// - Returns: 代理 URL，若未找到则返回 nil
    private static func extractProxyURL(from proxySettings: [String: Any], key: String) -> URL? {
        guard let proxies = proxySettings[key] as? [[String: Any]] else {
            return nil
        }

        for proxy in proxies {
            guard let proxyType = proxy[kCFProxyTypeKey as String] as? String else {
                continue
            }

            // 匹配代理类型
            if proxyType == key,
               let host = proxy[kCFProxyHostNameKey as String] as? String,
               let port = proxy[kCFProxyPortNumberKey as String] as? Int {
                var components = URLComponents()
                components.scheme = "http"
                components.host = host
                components.port = port
                return components.url
            }
        }

        return nil
    }
}
