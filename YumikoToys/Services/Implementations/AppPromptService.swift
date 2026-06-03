//
//  AppPromptService.swift
//  YumikoToys
//
//  应用提示词模板服务 - 从 JSON 文件加载，支持热更新
//

import Foundation

// MARK: - 模板数据模型

struct PromptTemplatesFile: Codable {
    let version: String
    let description: String
    let templates: [String: PromptTemplateEntry]
    let searchBypassKeywords: SearchBypassKeywords?
}

struct PromptTemplateEntry: Codable {
    let description: String
    var template: String?
    var system: String?
    var userPrefix: String?
    var userSuffix: String?
    var withSearch: String?
    var withoutSearch: String?
    var searching: String?
    var noResultsLog: String?

    enum CodingKeys: String, CodingKey {
        case description, template, system
        case userPrefix = "user_prefix"
        case userSuffix = "user_suffix"
        case withSearch = "with_search"
        case withoutSearch = "without_search"
        case searching
        case noResultsLog = "no_results_log"
    }
}

struct SearchBypassKeywords: Codable {
    let description: String
    let greetings: [String]
    let codeOrText: [String]

    enum CodingKeys: String, CodingKey {
        case description, greetings
        case codeOrText = "code_or_text"
    }
}

// MARK: - 应用提示词服务

final class AppPromptService {
    static let shared = AppPromptService()

    private var templatesFile: PromptTemplatesFile?
    private var templates: [String: PromptTemplateEntry] = [:]

    private init() {
        loadTemplates()
    }

    /// 重新加载模板（热更新）
    func reload() {
        loadTemplates()
    }

    /// 获取模板内容
    func template(_ key: String) -> String {
        templates[key]?.template ?? ""
    }

    /// 获取模板的系统 prompt
    func system(_ key: String) -> String {
        templates[key]?.system ?? ""
    }

    /// 获取带变量替换的模板
    func template(_ key: String, variables: [String: String]) -> String {
        var result = template(key)
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    /// 获取搜索决策 prompt
    func searchDecisionSystem() -> String {
        system("search_decision")
    }

    /// 获取搜索注入模板（带变量替换）
    func searchInjection(snippet: String, question: String) -> String {
        template("search_injection", variables: [
            "search_snippet": snippet,
            "user_question": question
        ])
    }

    /// 获取深度思考强制指令
    func deepThinkingEnforcer() -> String {
        template("deep_thinking_enforcer")
    }

    /// 获取联网搜索指令
    func webSearchInstruction() -> String {
        template("web_search_instruction")
    }

    /// 获取默认助手 prompt
    func defaultAssistantPrompt() -> String {
        template("default_assistant")
    }

    /// 获取 Agent 模式指令
    func agentModeInstruction() -> String {
        template("agent_mode_instruction")
    }

    /// 获取搜索状态消息
    func searchStatusMessage(_ key: String) -> String {
        switch key {
        case "searching":
            return templates["search_status_messages"]?.searching ?? "🔍 正在检索..."
        case "no_results_log":
            return templates["search_status_messages"]?.noResultsLog ?? ""
        default:
            return ""
        }
    }

    /// 获取流式输出为空时的兜底消息
    func streamEmptyFallback(hasSearch: Bool) -> String {
        let t = templates["stream_empty_fallback"]
        if hasSearch {
            return t?.withSearch ?? "模型未能生成有效回复，请稍后重试。"
        } else {
            return t?.withoutSearch ?? "模型未能生成有效回复，请稍后重试。"
        }
    }

    /// 获取本地快速过滤关键词
    func bypassKeywords() -> (greetings: [String], codeOrText: [String]) {
        let keywords = templatesFile?.searchBypassKeywords
        return (keywords?.greetings ?? [], keywords?.codeOrText ?? [])
    }

    // MARK: - Private

    private func loadTemplates() {
        guard let url = Bundle.main.url(forResource: "PromptTemplates", withExtension: "json") else {
            LoggerService.shared.error("PromptTemplates.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            templatesFile = try decoder.decode(PromptTemplatesFile.self, from: data)
            templates = templatesFile?.templates ?? [:]
            LoggerService.shared.info("Prompt templates loaded. Version: \(templatesFile?.version ?? "unknown"), Count: \(templates.count)")
        } catch {
            LoggerService.shared.error("Failed to load prompt templates: \(error)")
        }
    }
}
