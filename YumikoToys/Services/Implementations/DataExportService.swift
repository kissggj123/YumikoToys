//
//  DataExportService.swift
//  YumikoToys
//
//  数据导出服务
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// 导出数据模型
struct ExportData: Codable, Sendable {
    let version: String
    let exportDate: Date
    let anniversaries: [Anniversary]
    let settings: AppSettings
    
    static let currentVersion = "3.1.1"
}

/// 数据导出服务实现
@MainActor
final class DataExportService: DataExportServiceProtocol {
    
    // MARK: - Properties
    
    var serviceName: String { "DataExportService" }
    
    private let container = DependencyContainer.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    
    // MARK: - ServiceLifecycle
    
    func initialize() async {
        LoggerService.shared.debug("DataExportService initialized")
    }
    
    func start() async {}
    
    func stop() {}
    
    // MARK: - DataExportServiceProtocol
    
    /// 导出数据到文件
    func exportData() async throws -> URL {
        // 准备导出数据
        let exportData = ExportData(
            version: ExportData.currentVersion,
            exportDate: Date(),
            anniversaries: container.anniversaryService.anniversaries,
            settings: container.settingsService.settings
        )
        
        // 编码数据
        let data = try encoder.encode(exportData)
        
        // 显示保存面板
        let url = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.json]
                panel.nameFieldStringValue = "YumikoToys_Export_\(Self.dateString()).json"
                panel.message = "选择导出数据保存位置"
                
                if panel.runModal() == .OK, let url = panel.url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: ExportError.cancelled)
                }
            }
        }
        
        // 写入文件
        try data.write(to: url)
        LoggerService.shared.info("Data exported to: \(url.path)")
        
        return url
    }
    
    /// 从文件导入数据
    func importData(from url: URL) async throws {
        // 读取文件
        let data = try Data(contentsOf: url)
        
        // 解码数据
        let importData = try decoder.decode(ExportData.self, from: data)
        
        // 验证版本
        LoggerService.shared.info("Importing data from version: \(importData.version)")
        
        // 导入纪念日
        for anniversary in importData.anniversaries {
            container.anniversaryService.addAnniversary(anniversary)
        }
        
        // 导入设置
        container.settingsService.updateSettings(importData.settings)
        
        LoggerService.shared.info("Data imported successfully from: \(url.path)")
    }
    
    /// 显示导入面板并导入数据
    func showImportPanel() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.json]
                panel.message = "选择要导入的数据文件"
                panel.allowsMultipleSelection = false
                
                if panel.runModal() == .OK, let url = panel.url {
                    Task {
                        do {
                            try await self.importData(from: url)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                } else {
                    continuation.resume(throwing: ExportError.cancelled)
                }
            }
        }
    }
    
    // MARK: - Helper
    
    private static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Export Error

enum ExportError: LocalizedError {
    case cancelled
    case invalidFormat
    case unsupportedVersion(String)
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "操作已取消"
        case .invalidFormat:
            return "数据格式无效"
        case .unsupportedVersion(let version):
            return "不支持的数据版本: \(version)"
        }
    }
}
