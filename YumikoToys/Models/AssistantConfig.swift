//
//  AssistantConfig.swift
//  YumikoToys
//
//  助手模式配置模型
//

import Foundation

/// 助手模式配置
struct AssistantConfig: Codable, Sendable {
    /// 是否启用深度思考
    var enableDeepThinking: Bool

    /// 深度思考默认模型
    var thinkingModel: String

    /// 是否启用联网搜索
    var enableWebSearch: Bool

    /// 是否自动判断联网需求
    var autoWebSearch: Bool

    /// 搜索 API 地址
    var searchAPIURL: String

    /// 搜索 API Key
    var searchAPIKey: String

    /// Tavily Search API Key
    var tavilyAPIKey: String

    /// 是否启用 Agent 模式
    var enableAgentMode: Bool

    /// 自定义系统提示词
    var customSystemPrompt: String

    /// 是否启用联网搜索增强模式
    var enableEnhancedSearchMode: Bool

    init(
        enableDeepThinking: Bool = false,
        thinkingModel: String = "qwen/qwen3-next-80b-a3b-thinking",
        enableWebSearch: Bool = true,
        autoWebSearch: Bool = true,
        searchAPIURL: String = "",
        searchAPIKey: String = "",
        tavilyAPIKey: String = "",
        enableAgentMode: Bool = false,
        customSystemPrompt: String = "",
        enableEnhancedSearchMode: Bool = false
    ) {
        self.enableDeepThinking = enableDeepThinking
        self.thinkingModel = thinkingModel
        self.enableWebSearch = enableWebSearch
        self.autoWebSearch = autoWebSearch
        self.searchAPIURL = searchAPIURL
        self.searchAPIKey = searchAPIKey
        self.tavilyAPIKey = tavilyAPIKey
        self.enableAgentMode = enableAgentMode
        self.customSystemPrompt = customSystemPrompt
        self.enableEnhancedSearchMode = enableEnhancedSearchMode
    }

    static let `default` = AssistantConfig()

    // MARK: - Codable Custom Decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enableDeepThinking = try container.decodeIfPresent(Bool.self, forKey: .enableDeepThinking) ?? false
        thinkingModel = try container.decodeIfPresent(String.self, forKey: .thinkingModel) ?? "qwen/qwen3-next-80b-a3b-thinking"
        enableWebSearch = try container.decodeIfPresent(Bool.self, forKey: .enableWebSearch) ?? true
        autoWebSearch = try container.decodeIfPresent(Bool.self, forKey: .autoWebSearch) ?? true
        searchAPIURL = try container.decodeIfPresent(String.self, forKey: .searchAPIURL) ?? ""
        searchAPIKey = try container.decodeIfPresent(String.self, forKey: .searchAPIKey) ?? ""
        tavilyAPIKey = try container.decodeIfPresent(String.self, forKey: .tavilyAPIKey) ?? ""
        enableAgentMode = try container.decodeIfPresent(Bool.self, forKey: .enableAgentMode) ?? false
        customSystemPrompt = try container.decodeIfPresent(String.self, forKey: .customSystemPrompt) ?? ""
        enableEnhancedSearchMode = try container.decodeIfPresent(Bool.self, forKey: .enableEnhancedSearchMode) ?? false
    }
}
