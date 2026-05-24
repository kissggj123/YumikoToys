//
//  AgentFileService.swift
//  YumikoToys
//
//  Agent 文件操作沙盒服务
//

import Foundation

/// 文件信息
struct AgentFileInfo: Codable, Sendable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64?
}

/// Agent 文件操作沙盒服务
actor AgentFileService {
    /// 沙盒根目录（相对于 DataStorageService 基础路径）
    static let sandboxRelativePath = "agent_workspace"

    /// 最大文件大小 10MB
    private let maxFileSize: Int64 = 10 * 1024 * 1024

    /// 最大目录深度
    private let maxDepth: Int = 5

    private let dataStorage: DataStorageService

    init(dataStorage: DataStorageService) {
        self.dataStorage = dataStorage
    }

    /// 读取文件内容
    func readFile(_ relativePath: String) async throws -> String {
        let safePath = try validatePath(relativePath)
        let content: String? = await dataStorage.loadSync(String.self, from: safePath)
        guard let content = content else {
            throw AgentFileError.fileNotFound(relativePath)
        }
        return content
    }

    /// 写入文件
    func writeFile(_ relativePath: String, content: String) async throws {
        let safePath = try validatePath(relativePath)
        try validateFileSize(content)
        await dataStorage.saveSync(content, to: safePath)
    }

    /// 列出目录
    func listDirectory(_ relativePath: String) async throws -> [AgentFileInfo] {
        let safePath = try validatePath(relativePath.isEmpty ? "." : relativePath)
        let fullURL = await dataStorage.fullPath(for: safePath)
        let files = try FileManager.default.contentsOfDirectory(
            at: fullURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]
        )

        return files.compactMap { url -> AgentFileInfo? in
            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]) else { return nil }
            let name = url.lastPathComponent
            let relativeToSandbox = String(url.path.dropFirst(fullURL.path.count + 1))
            return AgentFileInfo(
                name: name,
                path: relativeToSandbox,
                isDirectory: resourceValues.isDirectory ?? false,
                size: resourceValues.fileSize.map { Int64($0) }
            )
        }.sorted { $0.name < $1.name }
    }

    /// 删除文件
    func deleteFile(_ relativePath: String) async throws {
        let safePath = try validatePath(relativePath)
        await dataStorage.delete(at: safePath)
    }

    // MARK: - 安全检查

    /// 验证路径安全性
    private func validatePath(_ relativePath: String) throws -> String {
        // 移除开头的斜杠
        var cleaned = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath

        // 禁止路径遍历
        if cleaned.contains("../") || cleaned.contains("..\\") {
            throw AgentFileError.pathTraversalBlocked
        }

        // 检查目录深度
        let components = cleaned.split(separator: "/").filter { !$0.isEmpty }
        if components.count > maxDepth {
            throw AgentFileError.depthExceeded(maxDepth)
        }

        // 确保路径在沙盒内
        let fullPath = "\(AgentFileService.sandboxRelativePath)/\(cleaned)"
        return fullPath
    }

    /// 验证文件大小
    private func validateFileSize(_ content: String) throws {
        guard let data = content.data(using: .utf8) else { return }
        guard data.count <= maxFileSize else {
            throw AgentFileError.fileTooLarge(maxFileSize)
        }
    }
}

// MARK: - 错误

enum AgentFileError: Error, LocalizedError {
    case fileNotFound(String)
    case pathTraversalBlocked
    case depthExceeded(Int)
    case fileTooLarge(Int64)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "文件不存在: \(path)"
        case .pathTraversalBlocked: return "路径遍历被阻止：禁止访问沙盒外的目录"
        case .depthExceeded(let max): return "目录深度超过限制（最大 \(max) 层）"
        case .fileTooLarge(let max): return "文件大小超过限制（最大 \(max / 1024 / 1024)MB）"
        case .writeFailed(let path): return "写入文件失败: \(path)"
        }
    }
}
