//
//  AIProvider.swift
//  YumikoToys
//
//  AI 提供商模型信息
//

import Foundation

/// AI 模型信息
struct AIModelInfo: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let name: String
    let provider: AIProviderType
    let description: String
    let supportsThinking: Bool
    let supportsVision: Bool
    let supportsTools: Bool
    let contextLength: Int?

    init(
        id: String,
        name: String,
        provider: AIProviderType,
        description: String = "",
        supportsThinking: Bool = false,
        supportsVision: Bool = false,
        supportsTools: Bool = false,
        contextLength: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.description = description
        self.supportsThinking = supportsThinking
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
        self.contextLength = contextLength
    }
}

// MARK: - GLM 模型转换扩展

extension GLMModelInfo {
    func toAIModelInfo() -> AIModelInfo {
        AIModelInfo(
            id: id,
            name: name,
            provider: .glm,
            description: description,
            supportsThinking: false,
            supportsVision: id.contains("v") || id.contains("vision"),
            supportsTools: id.contains("4"),
            contextLength: id.contains("4.7") ? 131072 : 8192
        )
    }
}

// MARK: - AI 提供商错误

enum AIProviderError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 API 地址"
        case .invalidResponse:
            return "无效的服务器响应"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}
