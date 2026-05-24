//
//  AIChatViewModel.swift
//  YumikoToys
//
//  AI 聊天视图模型（v6.1.0 - 动态上下文重组、多轨并发隔离、断点状态重连版）
//

import Foundation
import Combine

/// 流运行状态结构体，用于多会话在后台并发独立渲染
struct RunningStreamState: Sendable {
    var content: String = ""
    var thinkingContent: String = ""
    var searchSources: [SearchSource] = []
    var isLoading: Bool = true
}

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    
    var isGenerating: Bool {
        guard let currentId = currentConversationId else { return false }
        return activeTasks[currentId] != nil
    }
    
    @Published var inputText = ""
    @Published var isGeneratingPersona = false
    @Published var characterName = "可可"
    @Published var greeting = "你好呀！"
    @Published var aiAvatarEmoji = "🐰"
    @Published var userAvatarEmoji: String?
    @Published var userAvatarPath: String?
    @Published var initialHistoryLoaded = false
    @Published var pendingPersona: PetPersona? = nil
    @Published var hasPendingPersona: Bool = false
    @Published var currentConversationId: UUID? = nil

    @Published var chatMode: ChatMode = .petCompanion
    @Published var currentProvider: AIProviderType = .glm
    @Published var availableModels: [AIModelInfo] = []
    @Published var currentModel: String = ""

    @Published var enableDeepThinking: Bool = false
    @Published var enableWebSearch: Bool = true
    @Published var enableAgentMode: Bool = false

    @Published var uploadedFiles: [UploadedFile] = []
    @Published var selectedTemplate: PromptTemplate?
    @Published var showTemplatePicker: Bool = false

    @Published var runningStreams: [UUID: RunningStreamState] = [:]
    private var activeTasks: [UUID: Task<Void, Never>] = [:]

    private lazy var embeddingService: LocalEmbeddingService = { DependencyContainer.shared.localEmbeddingService as? LocalEmbeddingService ?? LocalEmbeddingService() }()
    private lazy var sentimentService: LocalSentimentService = { DependencyContainer.shared.localSentimentService as? LocalSentimentService ?? LocalSentimentService() }()

    private let container = DependencyContainer.shared
    private var currentAnniversaryId: String?
    private let fileAnalysisService = FileAnalysisService()
    private let promptTemplateService = PromptTemplateService()
    lazy var modelCompatibilityManager: ModelCompatibilityManager = { ModelCompatibilityManager(availableModels: availableModels) }()

    init() {
        loadUserAvatar()
        loadAPIConfiguration()
    }

    func loadAPIConfiguration() {
        let settings = container.apiSettingsService.getSettings()
        currentProvider = settings.currentProvider
        currentModel = settings.currentModel
        updateAvailableModels()

        let appSettings = container.settingsService.settings
        chatMode = appSettings.defaultChatMode
        enableDeepThinking = appSettings.assistantConfig.enableDeepThinking
        enableWebSearch = appSettings.assistantConfig.enableWebSearch
        enableAgentMode = appSettings.assistantConfig.enableAgentMode
    }

    private func updateAvailableModels() {
        let settings = container.apiSettingsService.getSettings()
        availableModels = settings.currentConfig.availableModels
    }

    func switchChatMode(to mode: ChatMode) { stopStreaming(); chatMode = mode }
    func switchProvider(to provider: AIProviderType) {
        stopStreaming()
        
        var settings = container.apiSettingsService.getSettings()
        settings.currentProvider = provider
        
        var configs = settings.providerConfigs
        if let config = configs[provider] {
            availableModels = config.availableModels
            if !config.model.isEmpty {
                currentModel = config.model
            } else if let defaultModel = config.availableModels.first {
                currentModel = defaultModel.id
                var updatedConfig = config
                updatedConfig.model = defaultModel.id
                configs[provider] = updatedConfig
                settings.providerConfigs = configs
            } else {
                currentModel = ""
            }
        } else {
            availableModels = []
            currentModel = ""
        }
        
        container.apiSettingsService.updateSettings(settings)
        currentProvider = provider
        
        if let modelInfo = availableModels.first(where: { $0.id == currentModel }) {
            modelCompatibilityManager.currentModel = modelInfo
        }
    }

    func selectModel(_ model: String) {
        currentModel = model
        if let modelInfo = availableModels.first(where: { $0.id == model }) { modelCompatibilityManager.currentModel = modelInfo }
        var settings = container.apiSettingsService.getSettings()
        var config = settings.currentConfig
        config.model = model
        settings.currentConfig = config
        container.apiSettingsService.updateSettings(settings)
    }

    func ensureModelCompatibility(for feature: FeatureRequirement) async { _ = await modelCompatibilityManager.ensureCompatibility(for: feature) }

    func addFiles(urls: [URL]) {
        Task {
            for url in urls {
                do {
                    let result = try await fileAnalysisService.uploadAndAnalyze(url: url)
                    let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = fileAttributes[.size] as? Int64 ?? 0
                    let fileType = SupportedFileType.infer(from: url.pathExtension.lowercased())
                    let uploadedFile = UploadedFile(fileName: url.lastPathComponent, fileURL: url, fileType: fileType, fileSize: fileSize, status: .completed, analysisResult: result)
                    await MainActor.run { self.uploadedFiles.append(uploadedFile) }
                } catch { LoggerService.shared.error("文件分析失败: \(error)") }
            }
        }
    }

    func removeFile(_ file: UploadedFile) { uploadedFiles.removeAll { $0.id == file.id } }

    private func getFileContentsSummary(query: String) async -> String {
        guard !uploadedFiles.isEmpty else { return "" }
        if embeddingService.isModelLoaded {
            var allParagraphs: [String] = []
            var paragraphToOrigin: [String: String] = [:]
            for file in uploadedFiles where file.status == .completed {
                if let extractedText = file.analysisResult?.extractedText {
                    let paragraphs = extractedText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.count > 15 }
                    for para in paragraphs { allParagraphs.append(para); paragraphToOrigin[para] = file.fileName }
                }
            }
            guard !allParagraphs.isEmpty else { return "" }
            do {
                let bestMatches = try await embeddingService.batchSimilarity(query: query, candidates: allParagraphs)
                let topMatches = bestMatches.prefix(4)
                var ragSummary = "\n\n[本地 MLX 语义 RAG 精准召回附件语料]\n"
                for match in topMatches {
                    let para = allParagraphs[match.index]
                    let sourceFile = paragraphToOrigin[para] ?? "未知文档"
                    ragSummary += "=== [来自文档: \(sourceFile)] (相关度: \(String(format: "%.1f", match.similarity * 100))%) ===\n\(para)\n\n"
                }
                return ragSummary
            } catch { }
        }

        var summary = "\n\n[附件文件内容]\n"
        for file in uploadedFiles where file.status == .completed {
            if let result = file.analysisResult { summary += "=== \(file.fileName) ===\n" + String(result.extractedText?.prefix(2000) ?? "") + "\n\n" }
        }
        return summary
    }

    func applyTemplate(_ template: PromptTemplate, variables: [String: String] = [:]) -> String { promptTemplateService.apply(template: template, variables: variables) }

    @MainActor func stopStreaming(for id: UUID) {
        guard let task = activeTasks[id] else { return }
        task.cancel()
        activeTasks[id] = nil
        runningStreams[id] = nil
        
        if id == currentConversationId, let lastIndex = messages.lastIndex(where: { $0.role == "assistant" && !$0.isAgentStep }) {
            var lastMsg = messages[lastIndex]
            if !lastMsg.content.isEmpty && !lastMsg.content.contains("⏹️") {
                lastMsg.content += "\n\n⏹️ *已中止流式输出。*"
                messages[lastIndex] = lastMsg
            }
        }
        objectWillChange.send()
    }

    @MainActor func stopStreaming() { if let currentId = currentConversationId { stopStreaming(for: currentId) } }

    @MainActor func rollbackLastTurn() {
        stopStreaming()
        guard !messages.isEmpty else { return }
        if messages.last?.role == "assistant" { messages.removeLast() }
        if messages.last?.role == "user" {
            let lastUserMsg = messages.removeLast()
            var rawContent = lastUserMsg.content
            if rawContent.contains("=========================================") {
                let parts = rawContent.components(separatedBy: "【用户的原始提问】: \"")
                if parts.count > 1 {
                    rawContent = parts.last?.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                }
            }
            self.inputText = rawContent
        }
        objectWillChange.send()
    }

    func editAndResend(messageId: UUID, newContent: String) {
        stopStreaming()
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages = Array(messages.prefix(index))
        sendMessage(newContent)
    }

    func rollbackTo(messageId: UUID) {
        stopStreaming()
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages = Array(messages.prefix(through: index))
    }

    func deleteMessage(messageId: UUID) { messages.removeAll { $0.id == messageId } }

    func regenerateResponse(for messageId: UUID) {
        stopStreaming()
        guard let index = messages.firstIndex(where: { $0.id == messageId }), index > 0 else { return }
        messages.remove(at: index)
        if let userMessage = messages.last(where: { $0.role == "user" }) { sendMessage(userMessage.content) }
    }

    func verifyNVIDIAAPIKey(_ apiKey: String) async throws -> [AIModelInfo] {
        let nvidiaProvider = UniversalLLMProvider(providerType: .nvidia)
        let models = try await nvidiaProvider.fetchAvailableModels(apiKey: apiKey)
        var settings = container.apiSettingsService.getSettings()
        var configs = settings.providerConfigs
        var config = configs[.nvidia] ?? .nvidiaDefault
        config.apiKey = apiKey
        config.availableModels = models
        config.lastModelFetchDate = Date()
        if config.model.isEmpty { config.model = models.first?.id ?? "" }
        configs[.nvidia] = config
        settings.providerConfigs = configs
        container.apiSettingsService.updateSettings(settings)
        if currentProvider == .nvidia {
            updateAvailableModels()
            if currentModel.isEmpty, let defaultModel = models.first { currentModel = defaultModel.id }
        }
        return models
    }

    // MARK: - 发送消息核心（多轨流并发重构）

    func sendMessage(_ content: String) {
        guard let currentId = currentConversationId else { return }
        stopStreaming(for: currentId)
        isLoading = true
        runningStreams[currentId] = RunningStreamState()

        activeTasks[currentId] = Task {
            var searchSources: [SearchSource] = []
            
            defer {
                activeTasks[currentId] = nil
                runningStreams[currentId] = nil
                if currentConversationId == currentId { isLoading = false }
                objectWillChange.send()
            }

            guard !Task.isCancelled else { return }

            let fileContents = await getFileContentsSummary(query: content)
            var finalUserPrompt = content + fileContents
            
            await MainActor.run {
                uploadedFiles.removeAll()
                inputText = ""
                messages.append(ChatMessage(role: "user", content: content))
            }

            // 👈 强行约束大模型摘要逻辑，杜绝直接吐 JSON 原始数据
            let summaryEnforcer = """
            
            【极度重要】：你必须用优美、自然的中文对用户的问题进行完整的解答！
            严禁原样复读搜索到的 JSON 数据或大段摘要原文！
            请你吸收参考资料中的知识，用你自己的话来完成具有条理性的深度总结输出！
            """

            do {
                let settings = container.apiSettingsService.getSettings()
                let providerKey = settings.currentConfig.apiKey
                let providerURL = settings.currentConfig.apiURL
                var providerModel = currentModel

                // DeepSeek 自适应升级
                let providerName = "\(currentProvider)".lowercased()
                if providerName.contains("deepseek") && enableDeepThinking && providerModel == "deepseek-chat" {
                    providerModel = "deepseek-reasoner"
                }

                // 直接注入式联网搜索（通过 SmartProxyManager）
                var injectedContext = ""
                if enableWebSearch && !enableAgentMode {
                    let needsSearch = await checkNeedsSearch(query: content, apiKey: providerKey, baseURL: providerURL, model: providerModel)
                    
                    if needsSearch && !Task.isCancelled {
                        if currentConversationId == currentId {
                            messages.append(ChatMessage(role: "assistant", content: "🔍 正在挂载安全代理进行全网瞬时检索..."))
                            objectWillChange.send()
                        }
                        
                        let appSettings = container.settingsService.settings
                        let searchService = UnifiedSearchService(assistantConfig: appSettings.assistantConfig)
                        let searchResults: [SearchSource]
                        do {
                            let unifiedResult = try await searchService.search(query: content, maxResults: 5)
                            searchResults = unifiedResult.sources
                        } catch {
                            LoggerService.shared.error("Unified search failed: \(error)")
                            searchResults = []
                        }
                        
                        if currentConversationId == currentId && messages.last?.content == "🔍 正在挂载安全代理进行全网瞬时检索..." {
                            messages.removeLast()
                        }
                        
                        if !searchResults.isEmpty {
                            searchSources = searchResults
                            var searchSnippet = ""
                            for (idx, src) in searchResults.enumerated() {
                                searchSnippet += "[\(idx + 1)] [来源: \(src.title)] - 摘要: \(src.snippet)\n"
                            }
                            
                            injectedContext = """
                            【系统通知】：系统已经为你实时抓取了全网最新的网页资料供你参考。
                            =========================================
                            \(searchSnippet)
                            =========================================
                            【用户的原始提问】: "\(content)"
                            \(summaryEnforcer)
                            """
                            finalUserPrompt = injectedContext + fileContents
                        }
                    }
                }

                var systemPrompt = await buildSystemPrompt(userQuery: content)
                let isNativeReasoner = providerModel.contains("reasoner") || providerModel.contains("thinking")
                
                // 🧠 强制激发所有大模型（如 Kimi / GLM）进入思维链模式
                if enableDeepThinking && !isNativeReasoner {
                    systemPrompt += """
                    
                    【强制指令】：你现在处于「深度思考与推理」模式。在解答前，你必须先在内部进行严密的逻辑链推导和事实整理。
                    你必须将你的所有思考过程包裹在 <think> ... </think> 标签中，并且一定要放置在最终回答的最开头！只有思考完毕后，才可以在标签外部输出最终回答！
                    """
                }

                guard !Task.isCancelled else { return }

                // 🔄【多轮退避与自动降级重试 (Auto-Fallback) 循环】
                let maxRetries = 2
                var iteration = 0
                var continueReasoning = true

                while continueReasoning && iteration < 5 {
                    guard !Task.isCancelled else { break }
                    iteration += 1
                    continueReasoning = false

                    // 👈【核心修复】：将 prunedHistory 的组装彻底移入 while 循环内部！
                    // 这样，在每一轮迭代前，刚刚追加到 messages 里的工具执行卡片和数据，都会被“实时”装配进历史记录中！
                    let limit = getModelContextLimit(model: providerModel)
                    let safetyMarginLimit = Int(Double(limit) * 0.8)
                    var totalTokens = estimateTokens(text: systemPrompt)
                    var prunedHistory: [ChatMessage] = []
                    
                    var currentPayload = messages
                    if !injectedContext.isEmpty, let lastUserIdx = currentPayload.lastIndex(where: { $0.role == "user" }) {
                        currentPayload[lastUserIdx].content = finalUserPrompt
                    }
                    
                    for msg in currentPayload.reversed() {
                        let msgTokens = estimateTokens(text: msg.content)
                        if totalTokens + msgTokens < safetyMarginLimit {
                            prunedHistory.insert(msg, at: 0)
                            totalTokens += msgTokens
                        } else { break }
                    }

                    for attempt in 0..<maxRetries {
                        guard !Task.isCancelled else { break }
                        
                        do {
                            let universalProvider = UniversalLLMProvider(providerType: currentProvider)
                            universalProvider.updateAPIKey(providerKey)
                            universalProvider.updateBaseURL(providerURL)

                            var tools: [AgentToolDefinition]? = nil
                            if enableAgentMode {
                                let agentService = AgentService(dataStorage: container.dataStorageService)
                                tools = agentService.getBuiltInTools(includeWebSearch: enableWebSearch)
                            }

                            let eventStream = universalProvider.streamChatWithEvents(
                                messages: prunedHistory,
                                systemPrompt: systemPrompt,
                                model: providerModel,
                                enableThinking: enableDeepThinking,
                                tools: tools
                            )

                            for try await event in eventStream {
                                if Task.isCancelled { break }
                                switch event {
                                case .thinkingContent(let text):
                                    updateStreamState(for: currentId, chunk: text, type: .thinking)
                                case .textContent(let text):
                                    updateStreamState(for: currentId, chunk: text, type: .text)
                                case .toolCall(_, let name, let arguments):
                                    let resultString: String
                                    
                                    if name == "web_search" {
                                        let argsData = arguments.data(using: .utf8) ?? Data()
                                        let args = (try? JSONSerialization.jsonObject(with: argsData)) as? [String: Any]
                                        let q = args?["query"] as? String ?? content
                                        
                                        let appSettings = container.settingsService.settings
                                        let searchService = UnifiedSearchService(assistantConfig: appSettings.assistantConfig)
                                        let res: [SearchSource]
                                        do {
                                            let unifiedResult = try await searchService.search(query: q, maxResults: 5)
                                            res = unifiedResult.sources
                                        } catch {
                                            LoggerService.shared.error("Agent unified search failed: \(error)")
                                            res = []
                                        }
                                        searchSources = res
                                        var formatted = ""
                                        for (idx, src) in res.enumerated() {
                                            formatted += "[\(idx + 1)] 摘要: \(src.snippet)\n"
                                        }
                                        resultString = formatted.isEmpty ? "{\"error\": \"未找到相关结果\"}" : formatted
                                    } else {
                                        let agentService = AgentService(dataStorage: container.dataStorageService)
                                        resultString = await agentService.executeTool(name: name, arguments: arguments)
                                    }

                                    // 👈【交互深度优化】：将重试/工具卡片一律标记为 isAgentStep。
                                    // 这样在下一轮 prunedHistory 装配时，它们可以被 buildMessages 无痕清洗掉，既不污染大模型，又完美保留在 UI 界面上。
                                    let stepMsg = ChatMessage(role: "assistant", content: "🔧 调用工具: \(name)\n\(resultString)", isAgentStep: true)
                                    if currentConversationId == currentId {
                                        messages.append(stepMsg)
                                        objectWillChange.send()
                                    } else {
                                        var history = container.glmService.getConversationHistory(for: currentId.uuidString)
                                        history.append(stepMsg)
                                        container.glmService.replaceConversationHistory(history, for: currentId.uuidString)
                                    }
                                    continueReasoning = true
                                }
                            }
                            
                            // 本轮成功，退出重试
                            break
                            
                        } catch {
                            if attempt == 0 {
                                LoggerService.shared.warning("API Provider failed: \(error). Initiating Fallback protocol...")
                                if let fallbackModel = availableModels.first(where: { $0.id.contains("kimi") || $0.id.contains("glm") }) {
                                    providerModel = fallbackModel.id
                                    if currentConversationId == currentId {
                                        // 将降级通知也标记为 isAgentStep，对下轮大模型发包绝对隐形！
                                        messages.append(ChatMessage(role: "assistant", content: "⚠️ 当前节点响应阻塞，已自动切至备用稳定节点 (\(fallbackModel.name)) 进行重试...", isAgentStep: true))
                                        objectWillChange.send()
                                    }
                                    continue // 重试
                                }
                            }
                            throw error
                        }
                    }
                }

                if let finalStream = runningStreams[currentId] {
                    let parsed = parseInlineThinking(finalStream.content)
                    let finalAssistantMsg = ChatMessage(
                        role: "assistant",
                        content: parsed.content,
                        thinkingContent: parsed.thinking ?? (finalStream.thinkingContent.isEmpty ? nil : finalStream.thinkingContent),
                        searchSources: searchSources.isEmpty ? nil : searchSources
                    )
                    var history = container.glmService.getConversationHistory(for: currentId.uuidString)
                    history.append(finalAssistantMsg)
                    container.glmService.replaceConversationHistory(history, for: currentId.uuidString)
                }

            } catch {
                LoggerService.shared.error("AI chat failed: \(error)")
                if currentConversationId == currentId {
                    messages.append(ChatMessage(role: "assistant", content: "❌ **服务连接严重故障**\n\n```\n\(error.localizedDescription)\n```\n多次重试均遭拒绝。请检查网络环境或模型状态。"))
                    objectWillChange.send()
                }
            }
        }
    }

    private enum StreamChunkType { case text; case thinking }

    private func updateStreamState(for conversationId: UUID, chunk: String, type: StreamChunkType) {
        guard var stream = runningStreams[conversationId] else { return }
        stream.isLoading = false
        switch type {
        case .text: stream.content += chunk
        case .thinking: stream.thinkingContent += chunk
        }
        runningStreams[conversationId] = stream
        
        if currentConversationId == conversationId {
            isLoading = false
            let parsed = parseInlineThinking(stream.content)
            
            if let lastIndex = messages.lastIndex(where: { $0.role == "assistant" && !$0.isAgentStep }) {
                messages[lastIndex].content = parsed.content
                if let inlineThinking = parsed.thinking {
                    messages[lastIndex].thinkingContent = inlineThinking
                } else if !stream.thinkingContent.isEmpty {
                    messages[lastIndex].thinkingContent = stream.thinkingContent
                }
            } else {
                let assistantMsg = ChatMessage(
                    role: "assistant",
                    content: parsed.content,
                    thinkingContent: parsed.thinking ?? (stream.thinkingContent.isEmpty ? nil : stream.thinkingContent)
                )
                messages.append(assistantMsg)
            }
            objectWillChange.send()
        }
    }

    // MARK: - Python 原生网页抓取器
    
    private func executePythonStyleDDGSearch(query: String) async -> [SearchSource] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)") else { return [] }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let session = SmartProxyManager.makeSession(for: "https://html.duckduckgo.com")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else { return [] }
            
            var results: [SearchSource] = []
            let pattern1 = "<a class=\"result__snippet\"[^>]*>(.*?)</a>"
            let regex1 = try NSRegularExpression(pattern: pattern1, options: [.dotMatchesLineSeparators, .caseInsensitive])
            let matches1 = regex1.matches(in: html, range: NSRange(html.startIndex..., in: html))
            
            for match in matches1 {
                if let range = Range(match.range(at: 1), in: html) {
                    let snippet = stripSearchHTML(String(html[range]))
                    if !snippet.isEmpty { results.append(SearchSource(title: "网页检索节点", url: "https://duckduckgo.com", snippet: snippet)) }
                }
            }
            
            if results.isEmpty {
                let pattern2 = "<td class=\"result__snippet\">(.*?)</td>"
                let regex2 = try NSRegularExpression(pattern: pattern2, options: [.dotMatchesLineSeparators, .caseInsensitive])
                let matches2 = regex2.matches(in: html, range: NSRange(html.startIndex..., in: html))
                for match in matches2 {
                    if let range = Range(match.range(at: 1), in: html) {
                        let snippet = stripSearchHTML(String(html[range]))
                        if !snippet.isEmpty { results.append(SearchSource(title: "网页检索节点", url: "https://duckduckgo.com", snippet: snippet)) }
                    }
                }
            }
            return Array(results.prefix(5))
        } catch {
            return []
        }
    }

    private func stripSearchHTML(_ html: String) -> String {
        var result = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "&[^;]+;", with: "", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func checkNeedsSearch(query: String, apiKey: String, baseURL: String, model: String) async -> Bool {
        let qLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if qLower.isEmpty || qLower.count < 2 { return false }
        
        let localBypass = ["你好", "hello", "hi", "在吗", "在嘛", "哈喽", "早上好", "晚上好", "谢谢", "不客气", "再见", "你是谁", "介绍一下你自己"]
        if localBypass.contains(where: { qLower.contains($0) }) { return false }
        
        let codeOrTextIndicators = ["写个", "用python", "用swift", "代码", "翻译", "写一封", "写篇", "解释一下", "什么是"]
        if codeOrTextIndicators.contains(where: { qLower.contains($0) }) { return false }
        
        let urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
        guard let url = URL(string: urlString) else { return false }
        
        let decisionPrompt = """
        你是一个智能决策专家。你的唯一任务是判断用户最新的提问是否需要进行“实时联网搜索”来获取最新新闻、事实。
        - 如果可以通识推导直接回答，输出：NO
        - 只有在查询明确涉及最新动态、时事等，输出：YES
        请只输出一个单词：YES 或 NO。
        """
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = ["model": model, "messages": [["role": "system", "content": decisionPrompt], ["role": "user", "content": "提问: \"\(query)\"\n回复 YES 或 NO:"]], "max_tokens": 10, "temperature": 0.0]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        request.httpBody = body
        
        do {
            let session = SmartProxyManager.makeSession(for: urlString)
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { return false }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstMsg = choices.first?["message"] as? [String: Any],
               let text = firstMsg["content"] as? String {
                return text.uppercased().contains("YES")
            }
        } catch { return true }
        return false
    }

    private func estimateTokens(text: String) -> Int {
        var tokens = 0.0
        for char in text {
            if let scalar = char.unicodeScalars.first, scalar.value >= 0x4E00 && scalar.value <= 0x9FFF { tokens += 1.5 } else { tokens += 0.4 }
        }
        return Int(tokens)
    }

    private func getModelContextLimit(model: String) -> Int {
        let mLower = model.lowercased()
        if mLower.contains("kimi-k2.6") { return 256_000 }
        if mLower.contains("deepseek") || mLower.contains("gpt-4o") { return 128_000 }
        if mLower.contains("o1") || mLower.contains("o3") { return 200_000 }
        if mLower.contains("gemini") { return mLower.contains("pro") ? 2_097_152 : 1_048_576 }
        return 128_000
    }

    private func parseInlineThinking(_ rawContent: String) -> (content: String, thinking: String?) {
        var content = rawContent
        var thinking: String? = nil
        let tags = [("<thought>", "</thought>"), ("<think>", "</think>")]
        
        for (openTag, closeTag) in tags {
            if let startRange = content.range(of: openTag) {
                let before = String(content[..<startRange.lowerBound])
                let afterStart = String(content[startRange.upperBound...])
                if let endRange = afterStart.range(of: closeTag) {
                    let inside = String(afterStart[..<endRange.lowerBound])
                    let afterEnd = String(afterStart[endRange.upperBound...])
                    thinking = inside.trimmingCharacters(in: .whitespacesAndNewlines)
                    content = before + afterEnd
                } else {
                    thinking = afterStart.trimmingCharacters(in: .whitespacesAndNewlines)
                    content = before
                }
                break
            }
        }
        return (content, thinking)
    }

    private func parseToolSearchSources(from result: String) -> [SearchSource] {
        var parsedSources: [SearchSource] = []
        let lines = result.components(separatedBy: "\n")
        for line in lines {
            var cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanLine.hasPrefix("["), let closingBracketIndex = cleanLine.firstIndex(of: "]") {
                let startIndex = cleanLine.index(after: closingBracketIndex)
                cleanLine = String(cleanLine[startIndex...]).trimmingCharacters(in: .whitespaces)
            }
            guard !cleanLine.isEmpty, let lineData = cleanLine.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: lineData) as? [String: String] else { continue }
            let title = dict["title"] ?? ""
            let url = dict["url"] ?? ""
            let snippet = dict["snippet"] ?? ""
            if !title.isEmpty || !url.isEmpty { parsedSources.append(SearchSource(title: title, url: url, snippet: snippet)) }
        }
        return parsedSources
    }

    // MARK: - 基础人设与历史加载
    
    func loadCurrentPetPersona() {
        guard let anniversary = container.anniversaryService.activeAnniversary else { return }
        currentAnniversaryId = anniversary.id.uuidString
        Task {
            if let persona = await container.personaService.getPersona(for: anniversary.id.uuidString) {
                await MainActor.run { self.updateUIWithPersona(persona) }
                if persona.needsRegeneration {
                    await MainActor.run { self.isGeneratingPersona = true }
                    await regeneratePersonaWithMemory(persona, for: anniversary)
                }
            } else {
                await MainActor.run { self.isGeneratingPersona = true }
                do {
                    let persona = try await container.personaService.generatePersona(for: anniversary)
                    await MainActor.run {
                        self.pendingPersona = persona
                        self.hasPendingPersona = true
                        self.isGeneratingPersona = false
                    }
                } catch {
                    await MainActor.run { self.isGeneratingPersona = false }
                }
            }
            if container.userAvatarService.shouldRefreshOnPetSwitch() {
                container.userAvatarService.refreshRandomOnPetSwitch()
                loadUserAvatar()
            }
        }
    }

    private func regeneratePersonaWithMemory(_ oldPersona: PetPersona, for anniversary: Anniversary) async {
        do {
            let newPersona = try await container.personaService.regeneratePersonaWithMemory(oldPersona: oldPersona, anniversary: anniversary)
            await MainActor.run {
                self.pendingPersona = newPersona
                self.hasPendingPersona = true
                self.isGeneratingPersona = false
            }
        } catch {
            await MainActor.run { self.isGeneratingPersona = false }
        }
    }

    private func loadHistory(for conversationId: String) {
        let history = container.glmService.getConversationHistory(for: conversationId)
        let analysisPrefixes = ["请分析以下对话内容", "你是一位专业的心理学分析师", "请基于以下对话内容"]
        var filteredMessages = history.filter { msg in !analysisPrefixes.contains { msg.content.hasPrefix($0) } }

        if let uuid = UUID(uuidString: conversationId), let runningStream = runningStreams[uuid] {
            isLoading = false
            let parsed = parseInlineThinking(runningStream.content)
            let liveMsg = ChatMessage(role: "assistant", content: parsed.content, thinkingContent: parsed.thinking ?? (runningStream.thinkingContent.isEmpty ? nil : runningStream.thinkingContent))
            filteredMessages.append(liveMsg)
        }

        messages = filteredMessages
        initialHistoryLoaded = true
    }

    private func loadUserAvatar() {
        let avatar = container.userAvatarService.getCurrentAvatar()
        userAvatarEmoji = avatar.emoji
        userAvatarPath = avatar.imagePath
    }

    private func updateUIWithPersona(_ persona: PetPersona) {
        characterName = persona.characterName
        greeting = persona.greeting
        aiAvatarEmoji = persona.avatar
    }

    func confirmPendingPersona() {
        guard let persona = pendingPersona else { return }
        updateUIWithPersona(persona)
        pendingPersona = nil
        hasPendingPersona = false
    }

    func rejectPendingPersona() {
        pendingPersona = nil
        hasPendingPersona = false
    }

    func switchConversation(to id: UUID) {
        currentConversationId = id
        initialHistoryLoaded = false
        messages = []
        loadCurrentPetPersona()
        container.glmService.switchToConversation(id.uuidString)
        Task {
            await container.glmService.loadConversationHistory(for: id.uuidString)
            await MainActor.run { self.loadHistory(for: id.uuidString) }
        }
    }

    func loadConversation(id: UUID) { switchConversation(to: id) }

    func startNewConversation(id: UUID) {
        currentConversationId = id
        initialHistoryLoaded = false
        messages = []
        loadCurrentPetPersona()
        container.glmService.createConversation(id.uuidString)
        initialHistoryLoaded = true
    }

    func deleteConversation(_ id: UUID) {
        stopStreaming(for: id)
        container.glmService.deleteConversation(id.uuidString)
        if currentConversationId == id {
            messages = []
            initialHistoryLoaded = false
            currentConversationId = nil
        }
    }

    private func buildSystemPrompt(userQuery: String) async -> String {
        switch chatMode {
        case .petCompanion:
            var prompt = await buildPetCompanionPrompt()
            if embeddingService.isModelLoaded || sentimentService.isModelLoaded {
                do {
                    async let cbtDiagnosis = embeddingService.isModelLoaded ? try? embeddingService.diagnoseCognitiveDistortion(text: userQuery, threshold: 0.62) : nil
                    async let sentimentResult = sentimentService.isModelLoaded ? try? sentimentService.analyze(text: userQuery) : nil
                    async let trendResult = sentimentService.isModelLoaded ? try? sentimentService.analyzeConversationTrend(messages: Array(messages.suffix(10))) : nil
                    
                    let (cbt, sentiment, trend) = await (cbtDiagnosis, sentimentResult, trendResult)
                    var diagnosticReport = ""
                    
                    if let cbt = cbt, let distortion = cbt.distortion { diagnosticReport += "\n- **认知失调特征**：当前提问高度共鸣【\(distortion)】" }
                    if let sentiment = sentiment { diagnosticReport += "\n- **瞬时情绪极性**：\(sentiment.sentiment.displayName) \(sentiment.sentiment.emoji) (置信度: \(String(format: "%.1f", sentiment.confidence * 100))%)" }
                    if let trend = trend {
                        diagnosticReport += "\n- **近期心境走向**：整体心境呈【\(trend.overallSentiment.emoji) \(trend.trendDirection == .improving ? "好转" : (trend.trendDirection == .declining ? "恶化" : "稳定"))】趋势"
                        diagnosticReport += "\n- **情绪稳定性指数**：\(String(format: "%.2f", trend.affectiveStability)) (起伏状态: \(trend.affectiveStability > 0.7 ? "心境平稳" : "剧烈起伏震荡"))"
                        diagnosticReport += "\n- **多维心理干预建议**：\n\(trend.psychologicalInsight)"
                    }
                    
                    if !diagnosticReport.isEmpty {
                        prompt += "\n\n# [本地双轨 MLX 心理学诊断报告]\n\(diagnosticReport)\n\n- **自适应响应共情要求**：请结合上述本地端侧深度学习模型输出的专业临床报告与诊断指标，在回复中以完全符合你角色性格（口癖、傲娇/温柔背景）的方式对用户进行治愈性包容和抱持（Holding）。不要在对话中生硬地向用户背诵此诊断报告中的心理学学术名词，而是要将这些 CBT 重组技术与情绪着陆技术完美地溶解在你的陪伴角色话语中。"
                    }
                } catch { }
            }
            return prompt
        case .aiAssistant:
            return buildAssistantPrompt()
        }
    }

    private func buildPetCompanionPrompt() async -> String {
        var prompt = "# [核心角色设定]\n你当前的身份是「\(characterName)」，请时刻代入此角色进行对话。\n默认问候语：\(greeting)"
        if let persona = await container.personaService.getPersona(for: currentAnniversaryId ?? "") {
            prompt += "\n\n## [宠物详细背景与特征描述]"
            if !persona.personality.isEmpty { prompt += "\n- **性格特征**：\(persona.personality)" }
            if !persona.speakingStyle.isEmpty { prompt += "\n- **说话风格与专属口癖**：\(persona.speakingStyle)" }
            if !persona.background.isEmpty { prompt += "\n- **身世背景故事**：\(persona.background)" }
            if !persona.traits.isEmpty { prompt += "\n- **独特能力/特质**：\(persona.traits.joined(separator: "、"))" }
        }
        if let learningService = await container.backgroundLearningService {
            let preferences = learningService.getPreferences()
            let memoryCategories = [("名字", "用户姓名"), ("工作", "职业/工作"), ("宠物", "拥有的宠物"), ("喜欢", "兴趣喜好"), ("习惯", "生活习惯"), ("饮食偏好", "饮食偏好"), ("饮食禁忌", "忌口/饮食禁忌"), ("游戏", "正在玩的游戏"), ("居住地", "目前居住地"), ("作息", "作息规律"), ("社交关系", "人际与社交关系"), ("目标", "近期目标/计划")]
            var infoLines: [String] = []
            for (key, label) in memoryCategories {
                let values = preferences.filter { $0.key == key }.map { $0.value }
                if !values.isEmpty { infoLines.append("- **\(label)**：\(values.joined(separator: "、"))") }
            }
            if !infoLines.isEmpty {
                prompt += "\n\n# [用户信息与记忆档案]\n" + infoLines.joined(separator: "\n") + "\n*注意：在对话中请自然、得体地根据实际语境提起上述用户特质，不要显得生硬或刻意泄露此列表。*"
            }
        }
        prompt += "\n\n# [专业心理陪伴与支持交互准则]\n为了给用户提供深度的安全感与心理慰藉，你在对话交互中必须深刻理解并严格遵守以下临床共情技术：\n1. **积极共情与情绪接纳 (Empathy & Validation)**:\n   - 当用户倾诉消极情绪时，必须在给出任何建议和长篇解释之前，先进行真诚温暖的情绪确认与接纳。\n2. **无条件积极关注 (Unconditional Positive Regard)**:\n   - 营造一个“绝对包容、无道德评价、无逻辑评判”的安全表达空间。\n3. **情绪温和疏理与觉察引导 (Exploration & Soft Framing)**:\n   - 温柔地使用开放式发问，引导用户具象化并命名自己的情绪。\n4. **角色化心理溶解 (In-character Therapeutic Coping)**:\n   - 绝对不要表现得像一个冷冰冰的咨询师，所有支持行为必须是角色个性的自然流露。\n5. **温和的界限与守护 (Boundary Support)**:\n   - 若用户表达极端危险倾向，极尽温柔地稳住情绪，并引导其寻求现实世界专业医师的保护。\n6. **心智启发与生命哲学探讨 (Existential & Summarization Guidance)**:\n   - 探讨深层生命议题时，引导用户从哲学、建设性角度理解生命并接纳痛苦。"
        if let profile = await container.backgroundLearningService?.getPsychologicalProfile() {
            let persona = await container.personaService.getPersona(for: currentAnniversaryId ?? "")
            let profilePrompt = profile.generateSystemPrompt(petName: characterName, petPersona: persona)
            prompt += "\n\n# [心理学动态交互指南]\n\(profilePrompt)"
        }
        prompt += "\n\n# [对话核心准则]\n1. 请用符合你性格特征和说话风格的方式回复。\n2. 建立深层的信任关系。"
        return prompt
    }

    private func buildAssistantPrompt() -> String {
        let config = container.settingsService.settings.assistantConfig
        var prompt = !config.customSystemPrompt.isEmpty ? config.customSystemPrompt : "你是一个全能 AI 助手，可以回答各种问题、进行深度推理、搜索互联网信息。\n1. 保持专业、准确、有帮助\n2. 如果不确定，坦诚说明\n3. 对于复杂问题，展示推理过程\n4. 使用 Markdown 格式化回答"
        if enableAgentMode { prompt += "\n\n你可以使用工具来帮助用户完成任务。当需要搜索信息时，主动使用可用工具。" }
        return prompt
    }
}
