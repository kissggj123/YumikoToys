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

    init(
        enableDeepThinking: Bool = false,
        thinkingModel: String = "qwen/qwen3-next-80b-a3b-thinking",
        enableWebSearch: Bool = true,
        autoWebSearch: Bool = true,
        searchAPIURL: String = "",
        searchAPIKey: String = "",
        tavilyAPIKey: String = "",
        enableAgentMode: Bool = false,
        customSystemPrompt: String = ""
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
    }

    static let `default` = AssistantConfig()
}
