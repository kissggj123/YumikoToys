//
//  APISettings.swift
//  YumikoToys
//
//  API设置模型 - 支持多提供商配置
//

import Foundation

/// API 设置 - 支持多提供商
struct APISettings: Codable, Sendable {
    /// 当前使用的 API 提供商
    var currentProvider: AIProviderType

    /// 各提供商的配置（使用数组存储以支持 Codable）
    private var providerConfigsArray: [ProviderConfigEntry]
    
    /// 提供商配置字典（计算属性）
    var providerConfigs: [AIProviderType: ProviderConfig] {
        get {
            Dictionary(uniqueKeysWithValues: providerConfigsArray.map { ($0.provider, $0.config) })
        }
        set {
            providerConfigsArray = newValue.map { ProviderConfigEntry(provider: $0.key, config: $0.value) }
        }
    }

    /// Token 统计
    var estimatedSentTokens: Int
    var estimatedReceivedTokens: Int

    init(
        currentProvider: AIProviderType = .glm,
        providerConfigs: [AIProviderType: ProviderConfig]? = nil,
        estimatedSentTokens: Int = 0,
        estimatedReceivedTokens: Int = 0
    ) {
        self.currentProvider = currentProvider
        let configs = providerConfigs ?? [
            .glm: .glmDefault,
            .openai: .openaiDefault,
            .anthropic: .anthropicDefault,
            .gemini: .geminiDefault,
            .deepseek: .deepseekDefault,
            .siliconflow: .siliconflowDefault,
            .ollama: .ollamaDefault,
            .nvidia: .nvidiaDefault,
            .poke: .pokeDefault
        ]
        self.providerConfigsArray = configs.map { ProviderConfigEntry(provider: $0.key, config: $0.value) }
        self.estimatedSentTokens = estimatedSentTokens
        self.estimatedReceivedTokens = estimatedReceivedTokens
    }
    
    /// 用于 Codable 的存储结构
    private struct ProviderConfigEntry: Codable {
        let provider: AIProviderType
        let config: ProviderConfig
    }

    var totalEstimatedTokens: Int {
        estimatedSentTokens + estimatedReceivedTokens
    }

    /// 当前提供商的配置
    var currentConfig: ProviderConfig {
        get {
            providerConfigs[currentProvider] ??
            (currentProvider == .glm ? .glmDefault : .openaiDefault)
        }
        set {
            providerConfigs[currentProvider] = newValue
        }
    }

    var currentAPIURL: String {
        currentConfig.apiURL
    }

    var currentAPIKey: String {
        currentConfig.apiKey
    }

    var currentModel: String {
        currentConfig.model
    }

    static let `default` = APISettings()

    // MARK: - Codable (向后兼容旧版 APISettings)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 尝试新格式
        if let provider = try? container.decode(AIProviderType.self, forKey: .currentProvider) {
            currentProvider = provider
            let loadedConfigs = (try? container.decode([ProviderConfigEntry].self, forKey: .providerConfigsArray)) ?? []
            
            // 为缺失配置的提供商补全默认值
            var configsMap = Dictionary(uniqueKeysWithValues: loadedConfigs.map { ($0.provider, $0.config) })
            let allDefaults: [AIProviderType: ProviderConfig] = [
                .glm: .glmDefault,
                .openai: .openaiDefault,
                .anthropic: .anthropicDefault,
                .gemini: .geminiDefault,
                .deepseek: .deepseekDefault,
                .siliconflow: .siliconflowDefault,
                .ollama: .ollamaDefault,
                .nvidia: .nvidiaDefault,
                .poke: .pokeDefault
            ]
            
            for (p, defaultConfig) in allDefaults {
                if configsMap[p] == nil {
                    configsMap[p] = defaultConfig
                }
            }
            
            providerConfigsArray = configsMap.map { ProviderConfigEntry(provider: $0.key, config: $0.value) }
            estimatedSentTokens = try container.decodeIfPresent(Int.self, forKey: .estimatedSentTokens) ?? 0
            estimatedReceivedTokens = try container.decodeIfPresent(Int.self, forKey: .estimatedReceivedTokens) ?? 0
        } else {
            // 旧格式迁移
            currentProvider = .glm
            let legacyAPIURL = (try? container.decode(String.self, forKey: CodingKeys.apiURL)) ?? AIProviderType.glm.defaultBaseURL
            let legacyAPIKey = (try? container.decode(String.self, forKey: CodingKeys.apiKey)) ?? ""
            let legacyModel = (try? container.decode(String.self, forKey: CodingKeys.model)) ?? "glm-4.7"
            let legacyAutoSelect = (try? container.decode(Bool.self, forKey: CodingKeys.autoSelect)) ?? true
            let legacyFallbackModels = (try? container.decode([String].self, forKey: CodingKeys.fallbackModels)) ?? ["glm-4.7", "glm-4"]
            estimatedSentTokens = (try? container.decode(Int.self, forKey: .estimatedSentTokens)) ?? 0
            estimatedReceivedTokens = (try? container.decode(Int.self, forKey: .estimatedReceivedTokens)) ?? 0

            var configsMap: [AIProviderType: ProviderConfig] = [
                .glm: ProviderConfig(
                    apiURL: legacyAPIURL,
                    apiKey: legacyAPIKey,
                    model: legacyModel,
                    autoSelect: legacyAutoSelect,
                    fallbackModels: legacyFallbackModels,
                    availableModels: GLMModelInfo.availableModels.map { $0.toAIModelInfo() }
                ),
                .openai: .openaiDefault,
                .anthropic: .anthropicDefault,
                .gemini: .geminiDefault,
                .deepseek: .deepseekDefault,
                .siliconflow: .siliconflowDefault,
                .ollama: .ollamaDefault,
                .nvidia: .nvidiaDefault,
                .poke: .pokeDefault
            ]
            
            providerConfigsArray = configsMap.map { ProviderConfigEntry(provider: $0.key, config: $0.value) }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentProvider, forKey: .currentProvider)
        try container.encode(providerConfigsArray, forKey: .providerConfigsArray)
        try container.encode(estimatedSentTokens, forKey: .estimatedSentTokens)
        try container.encode(estimatedReceivedTokens, forKey: .estimatedReceivedTokens)
    }

    private enum CodingKeys: String, CodingKey {
        case currentProvider, providerConfigsArray
        case estimatedSentTokens, estimatedReceivedTokens
        // 旧格式字段
        case apiURL = "apiURL"
        case apiKey = "apiKey"
        case model = "model"
        case autoSelect = "autoSelect"
        case fallbackModels = "fallbackModels"
    }
}

// MARK: - 向后兼容迁移

extension APISettings {
    /// 从旧版 APISettings 迁移
    static func migrateFromLegacy(
        apiURL: String,
        apiKey: String,
        model: String,
        autoSelect: Bool,
        fallbackModels: [String],
        estimatedSentTokens: Int,
        estimatedReceivedTokens: Int
    ) -> APISettings {
        var settings = APISettings.default
        settings.providerConfigs[.glm] = ProviderConfig(
            apiURL: apiURL,
            apiKey: apiKey,
            model: model,
            autoSelect: autoSelect,
            fallbackModels: fallbackModels,
            availableModels: GLMModelInfo.availableModels.map { $0.toAIModelInfo() }
        )
        settings.estimatedSentTokens = estimatedSentTokens
        settings.estimatedReceivedTokens = estimatedReceivedTokens
        return settings
    }
}

// MARK: - GLM 模型信息

struct GLMModelInfo {
    let id: String
    let name: String
    let description: String
    let isRecommended: Bool

    static let availableModels: [GLMModelInfo] = [
        GLMModelInfo(id: "glm-4.7", name: "GLM-4.7", description: "最新旗舰模型，5M tokens额度", isRecommended: true),
        GLMModelInfo(id: "glm-4.6v", name: "GLM-4.6v", description: "6M tokens额度", isRecommended: false),
        GLMModelInfo(id: "glm-4", name: "GLM-4", description: "标准旗舰模型", isRecommended: false),
        GLMModelInfo(id: "glm-4-flash", name: "GLM-4-Flash", description: "快速响应", isRecommended: false),
        GLMModelInfo(id: "glm-3-turbo", name: "GLM-3-Turbo", description: "轻量级模型", isRecommended: false)
    ]
}
