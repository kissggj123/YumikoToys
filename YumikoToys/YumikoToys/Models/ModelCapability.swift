//
//  ModelCapability.swift
//  YumikoToys
//
//  模型能力定义
//

import Foundation

/// 模型能力需求
struct ModelCapabilityRequirement: OptionSet, Codable, Sendable {
    let rawValue: Int

    static let thinking = Self(rawValue: 1 << 0)       // 深度思考
    static let tools = Self(rawValue: 1 << 1)          // 工具调用
    static let vision = Self(rawValue: 1 << 2)         // 图像理解
    static let longContext = Self(rawValue: 1 << 3)    // 长上下文 (>32K)
    static let codeExecution = Self(rawValue: 1 << 4) // 代码执行

    static let all: ModelCapabilityRequirement = [.thinking, .tools, .vision, .longContext, .codeExecution]

    /// 获取能力描述
    var descriptions: [String] {
        var result: [String] = []
        if contains(.thinking) { result.append("深度思考") }
        if contains(.tools) { result.append("工具调用") }
        if contains(.vision) { result.append("图像理解") }
        if contains(.longContext) { result.append("长上下文") }
        if contains(.codeExecution) { result.append("代码执行") }
        return result
    }
}

/// 功能所需能力映射
enum FeatureRequirement: String, CaseIterable, Codable {
    case deepThinking
    case webSearch
    case agentMode
    case fileAnalysis
    case imageAnalysis

    var requirements: ModelCapabilityRequirement {
        switch self {
        case .deepThinking:
            return .thinking
        case .webSearch:
            return .tools
        case .agentMode:
            return .tools
        case .fileAnalysis:
            return []  // 文本分析无需特殊能力
        case .imageAnalysis:
            return .vision
        }
    }

    var displayName: String {
        switch self {
        case .deepThinking: return "深度思考"
        case .webSearch: return "联网搜索"
        case .agentMode: return "Agent 模式"
        case .fileAnalysis: return "文件分析"
        case .imageAnalysis: return "图像分析"
        }
    }

    var icon: String {
        switch self {
        case .deepThinking: return "🧠"
        case .webSearch: return "🌐"
        case .agentMode: return "🤖"
        case .fileAnalysis: return "📄"
        case .imageAnalysis: return "🖼️"
        }
    }
}

/// 模型兼容性信息
struct ModelCompatibilityInfo: Codable, Sendable {
    let modelId: String
    let capabilities: ModelCapabilityRequirement
    let recommendedFor: [FeatureRequirement]
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case modelId
        case capabilities
        case recommendedFor
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.modelId = try container.decode(String.self, forKey: .modelId)
        self.capabilities = try container.decode(ModelCapabilityRequirement.self, forKey: .capabilities)
        self.recommendedFor = try container.decode([FeatureRequirement].self, forKey: .recommendedFor)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modelId, forKey: .modelId)
        try container.encode(capabilities, forKey: .capabilities)
        try container.encode(recommendedFor, forKey: .recommendedFor)
        try container.encodeIfPresent(notes, forKey: .notes)
    }

    static func detectCapabilities(for model: AIModelInfo) -> ModelCapabilityRequirement {
        var caps: ModelCapabilityRequirement = []

        if model.supportsThinking {
            caps.insert(.thinking)
        }
        if model.supportsTools {
            caps.insert(.tools)
        }
        if model.supportsVision {
            caps.insert(.vision)
        }
        if let ctx = model.contextLength, ctx > 32000 {
            caps.insert(.longContext)
        }

        // 基于模型名称推断
        let id = model.id.lowercased()
        if id.contains("think") || id.contains("reason") || id.contains("deepseek") {
            caps.insert(.thinking)
        }
        if id.contains("vision") || id.contains("vl") || id.contains("gpt-4v") {
            caps.insert(.vision)
        }
        if id.contains("code") || id.contains("coder") {
            caps.insert(.codeExecution)
        }

        return caps
    }
}
