//
//  ProviderConfig.swift
//  YumikoToys
//
//  提供商配置模型
//

import Foundation

/// 提供商配置
struct ProviderConfig: Codable, Sendable {
    var apiURL: String
    var apiKey: String
    var model: String
    var autoSelect: Bool
    var fallbackModels: [String]
    var availableModels: [AIModelInfo]
    var lastModelFetchDate: Date?

    init(
        apiURL: String,
        apiKey: String = "",
        model: String,
        autoSelect: Bool = false,
        fallbackModels: [String] = [],
        availableModels: [AIModelInfo] = [],
        lastModelFetchDate: Date? = nil
    ) {
        self.apiURL = apiURL
        self.apiKey = apiKey
        self.model = model
        self.autoSelect = autoSelect
        self.fallbackModels = fallbackModels
        self.availableModels = availableModels
        self.lastModelFetchDate = lastModelFetchDate
    }
}

// MARK: - 默认配置

extension ProviderConfig {
    /// GLM 默认配置
    static var glmDefault: ProviderConfig {
        ProviderConfig(
            apiURL: AIProviderType.glm.defaultBaseURL,
            apiKey: "",
            model: "glm-4.7",
            autoSelect: true,
            fallbackModels: ["glm-4.7", "glm-4"],
            availableModels: GLMModelInfo.availableModels.map { $0.toAIModelInfo() }
        )
    }

    /// OpenAI 默认配置
    static var openaiDefault: ProviderConfig {
        ProviderConfig(
            apiURL: AIProviderType.openai.defaultBaseURL,
            apiKey: "",
            model: "gpt-4o-mini",
            autoSelect: false,
            fallbackModels: ["gpt-4o-mini", "gpt-4o"],
            availableModels: [
                AIModelInfo(id: "gpt-4o-mini", name: "GPT-4o Mini", provider: .openai, description: "轻量高效旗舰模型", supportsThinking: false, supportsVision: true, supportsTools: true),
                AIModelInfo(id: "gpt-4o", name: "GPT-4o", provider: .openai, description: "全能多模态旗舰模型", supportsThinking: false, supportsVision: true, supportsTools: true),
                AIModelInfo(id: "o1-mini", name: "o1-mini", provider: .openai, description: "原生思维推理模型", supportsThinking: true, supportsVision: false, supportsTools: true),
                AIModelInfo(id: "o3-mini", name: "o3-mini", provider: .openai, description: "最新高性能思维推理模型", supportsThinking: true, supportsVision: false, supportsTools: true)
            ]
        )
    }

    /// Anthropic Claude 默认配置
    static var anthropicDefault: ProviderConfig {
        ProviderConfig(
            apiURL: AIProviderType.anthropic.defaultBaseURL,
            apiKey: "",
            model: "claude-3-5-sonnet-latest",
            autoSelect: false,
            fallbackModels: ["claude-3-5-sonnet-latest", "claude-3-5-haiku-latest"],
            availableModels: [
                AIModelInfo(id: "claude-3-5-sonnet-latest", name: "Claude 3.5 Sonnet", provider: .anthropic, description: "最强智能旗舰模型", supportsThinking: false, supportsVision: true, supportsTools: true),
                AIModelInfo(id: "claude-3-5-haiku-latest", name: "Claude 3.5 Haiku", provider: .anthropic, description: "极速响应智能模型", supportsThinking: false, supportsVision: false, supportsTools: true),
                AIModelInfo(id: "claude-3-opus-latest", name: "Claude 3 Opus", provider: .anthropic, description: "深度学术推理模型", supportsThinking: false, supportsVision: true, supportsTools: true)
            ]
        )
    }

    /// Gemini 默认配置
    static var geminiDefault: ProviderConfig {
        ProviderConfig(
            apiURL: AIProviderType.gemini.defaultBaseURL,
            apiKey: "",
            model: "gemini-1.5-flash",
            autoSelect: false,
            fallbackModels: ["gemini-1.5-flash", "gemini-1.5-pro"],
            availableModels: [
                AIModelInfo(id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", provider: .gemini, description: "极速轻量多模态模型", supportsThinking: false, supportsVision: true, supportsTools: true),
                AIModelInfo(id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", provider: .gemini, description: "超长上下文多模态旗舰模型", supportsThinking: false, supportsVision: true, supportsTools: true),
                AIModelInfo(id: "gemini-2.0-flash-exp", name: "Gemini 2.0 Flash Exp", provider: .gemini, description: "最新一代闪电体验版", supportsThinking: false, supportsVision: true, supportsTools: true)
            ]
        )
    }

    /// DeepSeek 默认配置
    static var deepseekDefault: ProviderConfig {
        ProviderConfig(
            apiURL: AIProviderType.deepseek.defaultBaseURL,
            apiKey: "",
            model: "deepseek-chat",
            autoSelect: false,
            fallbackModels: ["deepseek-chat", "deepseek-reasoner"],
            availableModels: [
                AIModelInfo(id: "deepseek-chat", name: "DeepSeek-V3", provider: .deepseek, description: "通用旗舰大模型 (DeepSeek-Chat)", supportsThinking: false, supportsVision: false, supportsTools: true),
                AIModelInfo(id: "deepseek-reasoner", name: "DeepSeek-R1 (深度思考)", provider: .deepseek, description: "最新开源超强推理模型 (DeepSeek-Reasoner)", supportsThinking: true, supportsVision: false, supportsTools: false)
            ]
        )
    }

    /// SiliconFlow 默认配置
    static var siliconflowDefault: ProviderConfig {
        ProviderConfig(
            apiURL: AIProviderType.siliconflow.defaultBaseURL,
            apiKey: "",
            model: "deepseek-ai/DeepSeek-V3",
            autoSelect: false,
            fallbackModels: ["deepseek-ai/DeepSeek-V3", "deepseek-ai/DeepSeek-R1"],
            availableModels: [
                AIModelInfo(id: "deepseek-ai/DeepSeek-V3", name: "DeepSeek-V3", provider: .siliconflow, description: "极低成本超强通用大模型", supportsThinking: false, supportsVision: false, supportsTools: true),
                AIModelInfo(id: "deepseek-ai/DeepSeek-R1", name: "DeepSeek-R1 (深度思考)", provider: .siliconflow, description: "深度思维链推理模型", supportsThinking: true, supportsVision: false, supportsTools: false),
                AIModelInfo(id: "Qwen/Qwen2.5-72B-Instruct", name: "Qwen 2.5 72B", provider: .siliconflow, description: "阿里开源旗舰对齐模型", supportsThinking: false, supportsVision: false, supportsTools: true),
                AIModelInfo(id: "internlm/internlm2_5-20b-chat", name: "书生·浦源 20B", provider: .siliconflow, description: "轻量级长文本对话模型", supportsThinking: false, supportsVision: false, supportsTools: true)
            ]
        )
    }

    /// Ollama 默认配置
    static var ollamaDefault: ProviderConfig {
        ProviderConfig(
            apiURL: AIProviderType.ollama.defaultBaseURL,
            apiKey: "",
            model: "llama3",
            autoSelect: false,
            fallbackModels: ["llama3", "qwen2.5"],
            availableModels: [
                AIModelInfo(id: "llama3", name: "Llama 3", provider: .ollama, description: "Meta 开源模型", supportsThinking: false, supportsVision: false, supportsTools: true),
                AIModelInfo(id: "qwen2.5", name: "Qwen 2.5", provider: .ollama, description: "阿里开源千问大模型", supportsThinking: false, supportsVision: false, supportsTools: true),
                AIModelInfo(id: "deepseek-r1", name: "DeepSeek R1", provider: .ollama, description: "本地跑的 R1 推理模型", supportsThinking: true, supportsVision: false, supportsTools: false)
            ]
        )
    }

    /// NVIDIA 默认配置
    static var nvidiaDefault: ProviderConfig {
        ProviderConfig(
            apiURL: AIProviderType.nvidia.defaultBaseURL,
            apiKey: "",
            model: "",
            autoSelect: false,
            fallbackModels: [],
            availableModels: []
        )
    }
}
