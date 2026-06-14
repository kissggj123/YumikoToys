//
//  AIProviderProtocol.swift
//  YumikoToys
//
//  AI 提供商协议定义
//

import Foundation

/// AI 提供商协议
protocol AIProvider: AnyObject {
    var providerName: String { get }
    var providerType: AIProviderType { get }

    func streamChat(
        messages: [ChatMessage],
        systemPrompt: String?,
        model: String
    ) -> AsyncThrowingStream<String, Error>

    func fetchAvailableModels(apiKey: String) async throws -> [AIModelInfo]
}

/// AI 提供商类型
enum AIProviderType: String, Codable, CaseIterable, Identifiable, Sendable {
    case glm = "glm"
    case openai = "openai"
    case anthropic = "anthropic"
    case gemini = "gemini"
    case deepseek = "deepseek"
    case siliconflow = "siliconflow"
    case ollama = "ollama"
    case nvidia = "nvidia"
    case poke = "poke"
    case mimo = "mimo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .glm: return "智谱 GLM"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic Claude"
        case .gemini: return "Google Gemini"
        case .deepseek: return "DeepSeek"
        case .siliconflow: return "硅基流动"
        case .ollama: return "Ollama (本地)"
        case .nvidia: return "NVIDIA NIM"
        case .poke: return "Poke AI (MCP)"
        case .mimo: return "小米 MiMo"
        }
    }

    var icon: String {
        switch self {
        case .glm: return "🅖"
        case .openai: return "🅾️"
        case .anthropic: return "🅰️"
        case .gemini: return "♊"
        case .deepseek: return "🐳"
        case .siliconflow: return "⚡"
        case .ollama: return "🦙"
        case .nvidia: return "🅝"
        case .poke: return "🅟"
        case .mimo: return "🅜"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .glm:
            return "https://open.bigmodel.cn/api/paas/v4"
        case .openai:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta"
        case .deepseek:
            return "https://api.deepseek.com/v1"
        case .siliconflow:
            return "https://api.siliconflow.cn/v1"
        case .ollama:
            return "http://localhost:11434"
        case .nvidia:
            return "https://integrate.api.nvidia.com/v1"
        case .poke:
            return "https://poke.com/api/v1/inbound-sms/webhook"
        case .mimo:
            return "https://api.xiaomimimo.com/v1"
        }
    }
}
