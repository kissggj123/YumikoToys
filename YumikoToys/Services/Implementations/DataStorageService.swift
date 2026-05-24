//
//  DataStorageService.swift
//  YumikoToys
//
//  数据存储服务（v5.0.0 - Actor 模式，纯 Swift Concurrency）
//

import Foundation

/// 数据存储服务（Actor 模式，线程安全）
actor DataStorageService: ServiceLifecycle {
    
    // MARK: - Properties
    
    /// 基础存储路径: ~/Documents/YumikoToys Data/
    private let basePath: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("YumikoToys Data", isDirectory: true)
    }()
    
    /// 记忆存储路径
    private var memoryPath: URL { basePath.appendingPathComponent("memory", isDirectory: true) }
    
    /// 配置存储路径
    private var configPath: URL { basePath.appendingPathComponent("config", isDirectory: true) }
    
    /// 缓存存储路径
    private var cachePath: URL { basePath.appendingPathComponent("cache", isDirectory: true) }
    
    nonisolated var serviceName: String { "DataStorageService" }
    
    // MARK: - Initialization
    
    nonisolated init() {
        // 目录创建在 initialize() 中执行
    }
    
    // MARK: - ServiceLifecycle
    
    nonisolated func initialize() async {
        await createDirectories()
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let basePath = documents.appendingPathComponent("YumikoToys Data", isDirectory: true)
        LoggerService.shared.info("DataStorageService initialized at \(basePath.path)")
    }
    
    nonisolated func start() async {}
    
    nonisolated func stop() {
        // Actor 模式下无需手动同步，所有操作已串行化
    }
    
    // MARK: - Directory Management
    
    private nonisolated func createDirectories() async {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let basePath = documents.appendingPathComponent("YumikoToys Data", isDirectory: true)
        let memoryPath = basePath.appendingPathComponent("memory", isDirectory: true)
        let configPath = basePath.appendingPathComponent("config", isDirectory: true)
        let cachePath = basePath.appendingPathComponent("cache", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: basePath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: memoryPath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: configPath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: cachePath, withIntermediateDirectories: true)
        } catch {
            LoggerService.shared.error("Failed to create directories: \(error)")
        }
    }
    
    // MARK: - Save Methods
    
    /// 保存对象到指定路径（Actor 隔离，后台执行）
    func save<T: Codable>(_ object: T, to relativePath: String) async {
        let url = basePath.appendingPathComponent(relativePath)
        let parentDir = url.deletingLastPathComponent()
        
        await Task.detached(priority: .utility) {
            do {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(object)
                try data.write(to: url)
                LoggerService.shared.debug("Saved to \(relativePath)")
            } catch {
                LoggerService.shared.error("Failed to save \(relativePath): \(error)")
            }
        }.value
    }
    
    /// 同步保存（用于小数据快速访问，nonisolated 避免阻塞 Actor）
    nonisolated func saveSync<T: Codable>(_ object: T, to relativePath: String) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let basePath = documents.appendingPathComponent("YumikoToys Data", isDirectory: true)
        let url = basePath.appendingPathComponent(relativePath)
        let parentDir = url.deletingLastPathComponent()
        
        do {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(object)
            try data.write(to: url)
        } catch {
            LoggerService.shared.error("Failed to save \(relativePath): \(error)")
        }
    }
    
    // MARK: - Load Methods
    
    /// 从指定路径加载对象（Actor 隔离，后台执行）
    func load<T: Codable>(_ type: T.Type, from relativePath: String) async -> T? {
        let url = basePath.appendingPathComponent(relativePath)
        
        return await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url) else {
                return nil
            }
            
            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                LoggerService.shared.error("Failed to load \(relativePath): \(error)")
                return nil
            }
        }.value
    }
    
    /// 同步加载（用于小数据快速访问）
    nonisolated func loadSync<T: Codable>(_ type: T.Type, from relativePath: String) -> T? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let basePath = documents.appendingPathComponent("YumikoToys Data", isDirectory: true)
        let url = basePath.appendingPathComponent(relativePath)
        
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            LoggerService.shared.error("Failed to load \(relativePath): \(error)")
            return nil
        }
    }
    
    // MARK: - Delete Methods
    
    /// 删除指定路径的文件
    func delete(at relativePath: String) async {
        let url = basePath.appendingPathComponent(relativePath)
        
        await Task.detached(priority: .utility) {
            do {
                try FileManager.default.removeItem(at: url)
                LoggerService.shared.debug("Deleted \(relativePath)")
            } catch {
                LoggerService.shared.error("Failed to delete \(relativePath): \(error)")
            }
        }.value
    }
    
    // MARK: - List Methods
    
    /// 列出指定目录下的所有文件
    func listFiles(in relativePath: String = "") async -> [String] {
        let url = basePath.appendingPathComponent(relativePath)
        
        return await Task.detached(priority: .utility) {
            do {
                return try FileManager.default.contentsOfDirectory(atPath: url.path)
            } catch {
                LoggerService.shared.error("Failed to list files in \(relativePath): \(error)")
                return []
            }
        }.value
    }
    
    // MARK: - Utility Methods
    
    /// 获取文件的完整路径
    nonisolated func fullPath(for relativePath: String) -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("YumikoToys Data", isDirectory: true)
            .appendingPathComponent(relativePath)
    }
    
    /// 检查文件是否存在
    func fileExists(at relativePath: String) async -> Bool {
        let url = basePath.appendingPathComponent(relativePath)
        return await Task.detached(priority: .utility) {
            FileManager.default.fileExists(atPath: url.path)
        }.value
    }
    
    /// 获取文件大小（字节）
    func fileSize(at relativePath: String) async -> Int64? {
        let url = basePath.appendingPathComponent(relativePath)
        
        return await Task.detached(priority: .utility) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                return attributes[.size] as? Int64
            } catch {
                return nil
            }
        }.value
    }
    
    /// 清空缓存目录
    func clearCache() async {
        await Task.detached(priority: .utility) { [cachePath] in
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: cachePath, includingPropertiesForKeys: nil)
                for url in contents {
                    try FileManager.default.removeItem(at: url)
                }
                LoggerService.shared.info("Cache cleared")
            } catch {
                LoggerService.shared.error("Failed to clear cache: \(error)")
            }
        }.value
    }
    
    /// 获取存储使用情况
    func storageUsage() async -> (total: Int64, memory: Int64, config: Int64, cache: Int64) {
        async let total = directorySize(at: basePath)
        async let memory = directorySize(at: memoryPath)
        async let config = directorySize(at: configPath)
        async let cache = directorySize(at: cachePath)
        
        return await (total, memory, config, cache)
    }
    
    private func directorySize(at url: URL) async -> Int64 {
        await Task.detached(priority: .utility) {
            var size: Int64 = 0
            
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
                return 0
            }
            
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
            
            return size
        }.value
    }
}
