//
//  GLMServiceProtocol.swift
//  YumikoToys
//
//  GLM 服务协议（v4.1.0 - 支持多对话隔离）
//

import Foundation

/// 聊天消息模型
struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: String // "user" | "assistant" | "system"
    var content: String
    let timestamp: Date

    /// 深度思考内容
    var thinkingContent: String?

    /// 搜索来源
    var searchSources: [SearchSource]?

    /// 是否为 Agent 步骤
    var isAgentStep: Bool

    /// 是否为主动工具建议
    var isProactiveSuggestion: Bool

    /// 主动建议的工具名称
    var proactiveToolName: String?

    /// 主动建议的工具参数
    var proactiveToolArgs: String?

    /// 工具执行结果 JSON
    var toolResultJSON: String?

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date(),
        thinkingContent: String? = nil,
        searchSources: [SearchSource]? = nil,
        isAgentStep: Bool = false,
        isProactiveSuggestion: Bool = false,
        proactiveToolName: String? = nil,
        proactiveToolArgs: String? = nil,
        toolResultJSON: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.thinkingContent = thinkingContent
        self.searchSources = searchSources
        self.isAgentStep = isAgentStep
        self.isProactiveSuggestion = isProactiveSuggestion
        self.proactiveToolName = proactiveToolName
        self.proactiveToolArgs = proactiveToolArgs
        self.toolResultJSON = toolResultJSON
    }

    // MARK: - Codable (向后兼容)

    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp
        case thinkingContent, searchSources, isAgentStep
        case isProactiveSuggestion, proactiveToolName, proactiveToolArgs, toolResultJSON
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(String.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        thinkingContent = try container.decodeIfPresent(String.self, forKey: .thinkingContent)
        searchSources = try container.decodeIfPresent([SearchSource].self, forKey: .searchSources)
        isAgentStep = try container.decodeIfPresent(Bool.self, forKey: .isAgentStep) ?? false
        isProactiveSuggestion = try container.decodeIfPresent(Bool.self, forKey: .isProactiveSuggestion) ?? false
        proactiveToolName = try container.decodeIfPresent(String.self, forKey: .proactiveToolName)
        proactiveToolArgs = try container.decodeIfPresent(String.self, forKey: .proactiveToolArgs)
        toolResultJSON = try container.decodeIfPresent(String.self, forKey: .toolResultJSON)
    }
}

/// GLM 服务协议
protocol GLMServiceProtocol: ServiceLifecycle {
    /// 发送消息并获取完整回复
    /// - Parameters:
    ///   - message: 消息内容
    ///   - context: 上下文消息
    ///   - saveToHistory: 是否保存到对话历史（后台分析应传 false）
    func sendMessage(_ message: String, context: [ChatMessage], saveToHistory: Bool) async throws -> String

    /// 流式发送消息
    func streamMessage(_ message: String, context: [ChatMessage]) -> AsyncThrowingStream<String, Error>

    /// 流式发送消息（带系统提示词）
    func streamMessage(_ message: String, context: [ChatMessage], systemPrompt: String?) -> AsyncThrowingStream<String, Error>

    /// 更新配置
    func updateConfiguration(apiURL: String, apiKey: String, model: String)

    /// 保存对话到记忆
    func saveToMemory(messages: [ChatMessage])

    /// 获取相关记忆
    func getRelevantMemory(for query: String, limit: Int) -> [ChatMessage]

    /// 获取指定对话的历史记录
    /// - Parameter conversationId: 对话 ID，nil 表示当前对话
    func getConversationHistory(for conversationId: String?) -> [ChatMessage]

    /// 清空指定对话的历史记录
    /// - Parameter conversationId: 对话 ID，nil 表示当前对话
    func clearConversationHistory(for conversationId: String?)

    /// 替换指定对话的历史记录
    /// - Parameters:
    ///   - messages: 新的历史记录
    ///   - conversationId: 对话 ID，nil 表示当前对话
    func replaceConversationHistory(_ messages: [ChatMessage], for conversationId: String?)

    /// 切换到指定对话
    func switchToConversation(_ conversationId: String)

    /// 创建新对话
    func createConversation(_ conversationId: String)

    /// 删除指定对话
    func deleteConversation(_ conversationId: String)

    /// 加载指定对话的历史记录
    func loadConversationHistory(for conversationId: String) async
}

/// GLM API 请求模型
struct GLMRequest: Codable {
    let model: String
    let messages: [GLMMessage]
    let stream: Bool
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case maxTokens = "max_tokens"
    }
}

/// GLM API 消息模型
struct GLMMessage: Codable {
    let role: String
    let content: String
}

/// GLM API 响应模型
struct GLMResponse: Codable {
    let choices: [GLMChoice]
    let usage: GLMUsage?
}

struct GLMChoice: Codable {
    let message: GLMMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct GLMUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

/// GLM 流式响应模型
struct GLMStreamResponse: Codable {
    let choices: [GLMStreamChoice]
}

struct GLMStreamChoice: Codable {
    let delta: GLMMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

/// GLM 错误类型
enum GLMError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 API URL"
        case .invalidResponse:
            return "无效的 API 响应"
        case .apiError(let message):
            return "API 错误: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        }
    }
}
