//
//  AIChatViewModel.swift
//  YumikoToys
//
//  AI 聊天视图模型（v6.1.0 - 动态上下文重组、多轨并发隔离、断点状态重连版）
//

import Combine
import Foundation

/// 流运行状态结构体，用于多会话在后台并发独立渲染
struct RunningStreamState: Sendable {
    var content: String = ""
    var thinkingContent: String = ""
    var searchSources: [SearchSource] = []
    var isLoading: Bool = true
}

enum ChatIdentity: String, Codable, CaseIterable, Sendable, Identifiable {
    case pet = "pet"                     // 宠物原身
    case psychologyExpert = "psychology" // 心理学专家
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .pet: return "宠物原身"
        case .psychologyExpert: return "心理专家"
        }
    }
}

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var selectedIdentity: ChatIdentity = .pet
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

    @Published var themeColor: ThemeColor = .dark
    @Published var customThemeColorHex: String = "FF6B9D"
    
    var resolvedTheme: ResolvedTheme {
        ResolvedTheme(color: themeColor, customHex: customThemeColorHex)
    }
    private var cancellables = Set<AnyCancellable>()

    private lazy var embeddingService: LocalEmbeddingService = {
        DependencyContainer.shared.localEmbeddingService
    }()
    private lazy var sentimentService: LocalSentimentService = {
        DependencyContainer.shared.localSentimentService
    }()

    private let container = DependencyContainer.shared
    private var currentAnniversaryId: String?
    private let fileAnalysisService = FileAnalysisService()
    private let promptTemplateService = AppPromptService.shared
    lazy var modelCompatibilityManager: ModelCompatibilityManager = {
        ModelCompatibilityManager(availableModels: availableModels)
    }()

    @Published var conversationService: ConversationService? = nil

    func setConversationService(_ service: ConversationService) {
        self.conversationService = service
    }

    init() {
        let appSettings = container.settingsService.settings
        themeColor = appSettings.mainWindowThemeColor
        customThemeColorHex = appSettings.customMainWindowThemeColorHex
        loadUserAvatar()
        loadAPIConfiguration()
        
        container.settingsService.settingsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.themeColor = settings.mainWindowThemeColor
                self?.customThemeColorHex = settings.customMainWindowThemeColorHex
            }
            .store(in: &cancellables)
    }

    // MARK: - 主动工具建议

    struct ProactiveToolSuggestion: Sendable {
        let toolName: String
        let arguments: String
        let displayName: String
        let reason: String
        let confidence: Double
    }

    func analyzeForProactiveTool(content: String) -> ProactiveToolSuggestion? {
        guard enableAgentMode else { return nil }
        
        let lowerContent = content.lowercased()
        
        if lowerContent.contains("搜索") || lowerContent.contains("查找") || lowerContent.contains("最新") || lowerContent.contains("新闻") {
            let query = extractSearchQuery(from: content)
            return ProactiveToolSuggestion(
                toolName: "web_search",
                arguments: "{\"query\": \"\(query)\"}",
                displayName: "联网搜索",
                reason: "检测到搜索意图",
                confidence: 0.7
            )
        }
        
        if let range = content.range(of: #"/[\\w/]+\\.[\\w]+"#, options: .regularExpression) {
            let filePath = String(content[range])
            return ProactiveToolSuggestion(
                toolName: "file_read",
                arguments: "{\"path\": \"\(filePath)\"}",
                displayName: "读取文件",
                reason: "检测到文件路径",
                confidence: 0.6
            )
        }
        
        if lowerContent.contains("系统信息") || lowerContent.contains("电脑状态") || lowerContent.contains("内存") || lowerContent.contains("cpu") {
            return ProactiveToolSuggestion(
                toolName: "get_system_info",
                arguments: "{}",
                displayName: "获取系统信息",
                reason: "检测到系统信息查询意图",
                confidence: 0.65
            )
        }
        
        return nil
    }

    private func extractSearchQuery(from content: String) -> String {
        let patterns = ["搜索(.+)", "查找(.+)", "最新(.+)", "(.+)的新闻"]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                return String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return content
    }

    func showProactiveToolCard(suggestion: ProactiveToolSuggestion) {
        let cardMessage = ChatMessage(
            role: "assistant",
            content: "💡 我可以帮你\(suggestion.displayName)：\(suggestion.reason)",
            isProactiveSuggestion: true,
            proactiveToolName: suggestion.toolName,
            proactiveToolArgs: suggestion.arguments
        )
        messages.append(cardMessage)
    }

    func executeProactiveTool(suggestion: ProactiveToolSuggestion) {
        let toolMessage = ChatMessage(
            role: "assistant",
            content: "🔧 正在执行工具: \(suggestion.displayName)...\n参数: \(suggestion.arguments)",
            isAgentStep: true
        )
        messages.append(toolMessage)
        
        Task {
            let resultString: String
            if suggestion.toolName == "web_search" {
                let rawArgs = suggestion.arguments.trimmingCharacters(in: .whitespacesAndNewlines)
                let argsData = rawArgs.isEmpty ? "{}".data(using: .utf8)! : (rawArgs.data(using: .utf8) ?? Data())
                let args = (try? JSONSerialization.jsonObject(with: argsData)) as? [String: Any]
                let q = args?["query"] as? String ?? ""
                
                let appSettings = container.settingsService.settings
                let searchService = UnifiedSearchService(assistantConfig: appSettings.assistantConfig)
                do {
                    let result = try await searchService.search(query: q, maxResults: 5)
                    resultString = result.sources.map { "[\($0.title)] \($0.snippet)" }.joined(separator: "\n")
                } catch {
                    resultString = "搜索失败: \(error.localizedDescription)"
                }
            } else {
                let agentService = AgentService(dataStorage: container.dataStorageService)
                resultString = await agentService.executeTool(name: suggestion.toolName, arguments: suggestion.arguments)
            }
            
            let resultMessage = ChatMessage(
                role: "assistant",
                content: "✅ \(suggestion.displayName) 完成：\n\(resultString)",
                isAgentStep: true,
                toolResultJSON: resultString
            )
            messages.append(resultMessage)
        }
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

    func switchChatMode(to mode: ChatMode) {
        stopStreaming()
        chatMode = mode
    }
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

        if let modelInfo = availableModels.first(where: {
            $0.id == currentModel
        }) {
            modelCompatibilityManager.currentModel = modelInfo
        }
    }

    func selectModel(_ model: String) {
        currentModel = model
        if let modelInfo = availableModels.first(where: { $0.id == model }) {
            modelCompatibilityManager.currentModel = modelInfo
        }
        var settings = container.apiSettingsService.getSettings()
        var config = settings.currentConfig
        config.model = model
        settings.currentConfig = config
        container.apiSettingsService.updateSettings(settings)
    }

    func ensureModelCompatibility(for feature: FeatureRequirement) async {
        _ = await modelCompatibilityManager.ensureCompatibility(for: feature)
    }

    func addFiles(urls: [URL]) {
        Task {
            for url in urls {
                do {
                    let result = try await fileAnalysisService.uploadAndAnalyze(
                        url: url
                    )
                    let fileAttributes = try FileManager.default
                        .attributesOfItem(atPath: url.path)
                    let fileSize = fileAttributes[.size] as? Int64 ?? 0
                    let fileType = SupportedFileType.infer(
                        from: url.pathExtension.lowercased()
                    )
                    let uploadedFile = UploadedFile(
                        fileName: url.lastPathComponent,
                        fileURL: url,
                        fileType: fileType,
                        fileSize: fileSize,
                        status: .completed,
                        analysisResult: result
                    )
                    await MainActor.run {
                        self.uploadedFiles.append(uploadedFile)
                    }
                } catch { LoggerService.shared.error("文件分析失败: \(error)") }
            }
        }
    }

    func removeFile(_ file: UploadedFile) {
        uploadedFiles.removeAll { $0.id == file.id }
    }

    private func getFileContentsSummary(query: String) async -> String {
        guard !uploadedFiles.isEmpty else { return "" }
        if embeddingService.isModelLoaded {
            var allParagraphs: [String] = []
            var paragraphToOrigin: [String: String] = [:]
            for file in uploadedFiles where file.status == .completed {
                if let extractedText = file.analysisResult?.extractedText {
                    let paragraphs = extractedText.components(
                        separatedBy: .newlines
                    ).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { $0.count > 15 }
                    for para in paragraphs {
                        allParagraphs.append(para)
                        paragraphToOrigin[para] = file.fileName
                    }
                }
            }
            guard !allParagraphs.isEmpty else { return "" }
            do {
                let bestMatches = try await embeddingService.batchSimilarity(
                    query: query,
                    candidates: allParagraphs
                )
                let topMatches = bestMatches.prefix(4)
                var ragSummary = "\n\n[本地 MLX 语义 RAG 精准召回附件语料]\n"
                for match in topMatches {
                    let para = allParagraphs[match.index]
                    let sourceFile = paragraphToOrigin[para] ?? "未知文档"
                    ragSummary +=
                        "=== [来自文档: \(sourceFile)] (相关度: \(String(format: "%.1f", match.similarity * 100))%) ===\n\(para)\n\n"
                }
                return ragSummary
            } catch {}
        }

        var summary = "\n\n[附件文件内容]\n"
        for file in uploadedFiles where file.status == .completed {
            if let result = file.analysisResult {
                summary +=
                    "=== \(file.fileName) ===\n"
                    + String(result.extractedText?.prefix(2000) ?? "") + "\n\n"
            }
        }
        return summary
    }

    func applyTemplate(
        _ tpl: PromptTemplate,
        variables: [String: String] = [:]
    ) -> String {
        var result = tpl.template
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    @MainActor func stopStreaming(for id: UUID) {
        guard let task = activeTasks[id] else { return }
        task.cancel()
        activeTasks[id] = nil
        runningStreams[id] = nil

        if id == currentConversationId,
            let lastIndex = messages.lastIndex(where: {
                $0.role == "assistant" && !$0.isAgentStep
            })
        {
            var lastMsg = messages[lastIndex]
            if !lastMsg.content.isEmpty && !lastMsg.content.contains("⏹️") {
                lastMsg.content += "\n\n⏹️ *已中止流式输出。*"
                messages[lastIndex] = lastMsg
            }
        }
        objectWillChange.send()
    }

    @MainActor func stopStreaming() {
        if let currentId = currentConversationId {
            stopStreaming(for: currentId)
        }
    }

    @MainActor func rollbackLastTurn() {
        stopStreaming()
        guard !messages.isEmpty else { return }
        if messages.last?.role == "assistant" { messages.removeLast() }
        if messages.last?.role == "user" {
            let lastUserMsg = messages.removeLast()
            var rawContent = lastUserMsg.content
            if rawContent.contains("=========================================")
            {
                let parts = rawContent.components(separatedBy: "【用户的原始提问】: \"")
                if parts.count > 1 {
                    rawContent =
                        parts.last?.replacingOccurrences(of: "\"", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                }
            }
            self.inputText = rawContent
        }
        if let currentId = currentConversationId {
            container.glmService.replaceConversationHistory(
                messages,
                for: currentId.uuidString
            )
        }
        objectWillChange.send()
    }

    func editAndResend(messageId: UUID, newContent: String) {
        stopStreaming()
        guard let index = messages.firstIndex(where: { $0.id == messageId })
        else { return }
        messages = Array(messages.prefix(index))
        if let currentId = currentConversationId {
            container.glmService.replaceConversationHistory(
                messages,
                for: currentId.uuidString
            )
        }
        sendMessage(newContent)
    }

    func rollbackTo(messageId: UUID) {
        stopStreaming()
        guard let index = messages.firstIndex(where: { $0.id == messageId })
        else { return }
        messages = Array(messages.prefix(through: index))
        if let currentId = currentConversationId {
            container.glmService.replaceConversationHistory(
                messages,
                for: currentId.uuidString
            )
        }
    }

    func deleteMessage(messageId: UUID) {
        messages.removeAll { $0.id == messageId }
        if let currentId = currentConversationId {
            container.glmService.replaceConversationHistory(
                messages,
                for: currentId.uuidString
            )
        }
    }

    func regenerateResponse(for messageId: UUID) {
        stopStreaming()
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
            index > 0
        else { return }
        messages.remove(at: index)
        if let userMessage = messages.last(where: { $0.role == "user" }) {
            sendMessage(userMessage.content)
        }
    }

    func verifyNVIDIAAPIKey(_ apiKey: String) async throws -> [AIModelInfo] {
        let nvidiaProvider = UniversalLLMProvider(providerType: .nvidia)
        let models = try await nvidiaProvider.fetchAvailableModels(
            apiKey: apiKey
        )
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
            if currentModel.isEmpty, let defaultModel = models.first {
                currentModel = defaultModel.id
            }
        }
        return models
    }

    // MARK: - 能力解析

    struct ResolvedCapabilities {
        let model: String
        let enableThinking: Bool
        let enableAgentMode: Bool
        let enableWebSearch: Bool
        let usePreInjectedSearch: Bool
    }

    func resolveModelAndCapabilities(
        deepThinking: Bool? = nil,
        webSearch: Bool? = nil,
        agentMode: Bool? = nil
    ) -> ResolvedCapabilities {
        let isPoke = currentProvider == .poke
        let inputDeepThinking = deepThinking ?? enableDeepThinking
        let inputWebSearch = webSearch ?? enableWebSearch
        let inputAgentMode = agentMode ?? enableAgentMode

        var resolvedModel = currentModel
        let providerName = "\(currentProvider)".lowercased()
        if providerName.contains("deepseek") && inputDeepThinking
            && resolvedModel == "deepseek-chat"
        {
            resolvedModel = "deepseek-reasoner"
        }
        
        let mLower = resolvedModel.lowercased()
        let isReasoningModel = mLower.contains("thinking") || mLower.contains("think") || mLower.contains("reasoner") || mLower.contains("r1")
        
        // Mutual exclusion: reasoning models cannot use agent tools
        var resolvedAgentMode = inputAgentMode
        if isReasoningModel || isPoke {
            resolvedAgentMode = false
        }
        
        // Mutual exclusion: agent mode disables pre-injected search
        let resolvedWebSearch = isPoke ? false : inputWebSearch
        let resolvedDeepThinking = isPoke ? false : inputDeepThinking
        let usePreInjectedSearch = resolvedWebSearch && !resolvedAgentMode && !isPoke
        
        return ResolvedCapabilities(
            model: resolvedModel,
            enableThinking: resolvedDeepThinking,
            enableAgentMode: resolvedAgentMode,
            enableWebSearch: resolvedWebSearch,
            usePreInjectedSearch: usePreInjectedSearch
        )
    }
    
    func sendMessage(_ content: String) {
        guard let currentId = currentConversationId else { return }
        stopStreaming(for: currentId)
        isLoading = true
        runningStreams[currentId] = RunningStreamState()

        // Capture settings synchronously on MainActor before entering the Task!
        let activeProvider = self.currentProvider
        let settings = container.apiSettingsService.getSettings()
        let config = settings.providerConfigs[activeProvider] ?? settings.currentConfig
        let providerKey = config.apiKey
        let providerURL = config.apiURL
        let snapshotAvailableModels = self.availableModels

        activeTasks[currentId] = Task {
            var searchSources: [SearchSource] = []

            // Link Skill Recognition
            let lowerContent = content.lowercased()
            if lowerContent.contains("http://") || lowerContent.contains("https://") {
                if let url = self.extractURL(from: content) {
                    let isLikelySkill = url.pathExtension == "zip" || url.pathExtension == "md" || url.pathExtension == "json" || url.absoluteString.contains("skill")
                    
                    if isLikelySkill {
                        await MainActor.run {
                            let downloadNotice = ChatMessage(
                                role: "assistant",
                                content: "🔍 检测到大模型技能链接，正在尝试下载并解析导入...",
                                isAgentStep: true
                            )
                            self.messages.append(downloadNotice)
                            self.messages.sort(by: { $0.timestamp < $1.timestamp })
                            self.objectWillChange.send()
                        }
                        
                        let activeAgentId = self.conversationService?.conversations.first(where: { $0.id == currentId })?.agentId
                        let importResult = await self.importSkillFromURL(url: url, agentId: activeAgentId)
                        
                        await MainActor.run {
                            let resultNotice = ChatMessage(
                                role: "assistant",
                                content: importResult.message,
                                isAgentStep: true
                            )
                            self.messages.append(resultNotice)
                            self.messages.sort(by: { $0.timestamp < $1.timestamp })
                            
                            self.inputText = ""
                            self.isLoading = false
                            self.objectWillChange.send()
                        }
                        return
                    }
                }
            }

            var autoPlayCount = 0
            var currentQueryContent = content
            var shouldAutoPlay = true
            
            while shouldAutoPlay && autoPlayCount < 4 {
                shouldAutoPlay = false
                
                let queryLower = currentQueryContent.lowercased()
                let requiresSearch = queryLower.contains("最新") || queryLower.contains("今天") || queryLower.contains("新闻") || queryLower.contains("搜索") || queryLower.contains("查一下") || queryLower.contains("实时")
                let requiresAgent = queryLower.contains("文件") || queryLower.contains("代码") || queryLower.contains("写一") || queryLower.contains("编写") || queryLower.contains("创建") || queryLower.contains("运行")
                let requiresDeepThinking = queryLower.contains("为什么") || queryLower.contains("分析") || queryLower.contains("设计") || queryLower.contains("架构") || queryLower.contains("怎么")
                
                let isPoke = activeProvider == .poke
                // Auto-enable agent mode when conversation is linked to an agent with skills
                let conversationHasAgent = self.conversationService?.conversations.first(where: { $0.id == currentId })?.agentId != nil
                let finalWebSearch = !isPoke && (enableWebSearch || requiresSearch)
                let finalAgentMode = !isPoke && (enableAgentMode || requiresAgent || conversationHasAgent)
                let finalDeepThinking = !isPoke && (enableDeepThinking || requiresDeepThinking)

                let resolved = self.resolveModelAndCapabilities(
                    deepThinking: finalDeepThinking,
                    webSearch: finalWebSearch,
                    agentMode: finalAgentMode
                )
                var activeModel = resolved.model
                let enableThinking = resolved.enableThinking
                let enableAgentMode = resolved.enableAgentMode
                let enableWebSearch = resolved.enableWebSearch
                let usePreInjectedSearch = resolved.usePreInjectedSearch

                defer {
                    if !shouldAutoPlay {
                        self.activeTasks[currentId] = nil
                        self.runningStreams[currentId] = nil
                        if self.currentConversationId == currentId { self.isLoading = false }
                        self.objectWillChange.send()
                    }
                }

                guard !Task.isCancelled else { return }

                // 🧠 2. 上下文记忆联想 (Context Memory Association)
                let relevantMemory = await self.getRelevantMemoryContext(for: currentQueryContent)
                let fileContents = await self.getFileContentsSummary(query: currentQueryContent)
                var finalUserPrompt = relevantMemory + currentQueryContent + fileContents

                if autoPlayCount == 0 {
                    let userMsg = ChatMessage(role: "user", content: currentQueryContent)
                    await MainActor.run {
                        self.uploadedFiles.removeAll()
                        self.inputText = ""
                        self.messages.append(userMsg)
                        self.messages.sort(by: { $0.timestamp < $1.timestamp })
                    }
                    
                    // 同步用户消息到 Poke
                    let userContentCopy = currentQueryContent
                    Task.detached {
                        PokeService.shared.sendMessage("[User]: \(userContentCopy)")
                    }

                    // 同步写入持久化历史
                    var history = container.glmService.getConversationHistory(
                        for: currentId.uuidString
                    )
                    history.append(userMsg)
                    container.glmService.replaceConversationHistory(
                        history,
                        for: currentId.uuidString
                    )
                }

                var displayContent = ""

                do {
                    // 直接注入式联网搜索（通过 SmartProxyManager）
                    var injectedContext = ""
                    if usePreInjectedSearch {
                        LoggerService.shared.info(
                            "Checking if web search is needed for query: \(currentQueryContent)"
                        )
                        let needsSearch = await self.checkNeedsSearch(
                            query: currentQueryContent,
                            apiKey: providerKey,
                            baseURL: providerURL,
                            model: activeModel
                        )
                        LoggerService.shared.info(
                            "self.checkNeedsSearch result: \(needsSearch)"
                        )

                        if needsSearch && !Task.isCancelled {
                            await MainActor.run {
                                if self.currentConversationId == currentId {
                                    self.messages.append(ChatMessage(role: "assistant", content: AppPromptService.shared.searchStatusMessage("searching")))
                                    self.messages.sort(by: { $0.timestamp < $1.timestamp })
                                    self.objectWillChange.send()
                                }
                            }

                            let appSettings = container.settingsService.settings
                            let searchService = UnifiedSearchService(
                                assistantConfig: appSettings.assistantConfig
                            )
                            let searchResults: [SearchSource]
                            do {
                                // 3. 协同生成多维度检索词，并行化多路召回 (Collaborative Parallel Search)
                                let query2 = currentQueryContent + " 最新 实时"
                                let query3 = currentQueryContent + " 动态 资讯"
                                
                                async let res1 = try? searchService.search(query: currentQueryContent, maxResults: 3)
                                async let res2 = try? searchService.search(query: query2, maxResults: 3)
                                async let res3 = try? searchService.search(query: query3, maxResults: 3)
                                
                                let (all1, all2, all3) = await (res1, res2, res3)
                                
                                var mergedSources: [SearchSource] = []
                                var seenUrls = Set<String>()
                                
                                let addSources = { (sources: [SearchSource]) in
                                    for src in sources {
                                        if !seenUrls.contains(src.url) {
                                            seenUrls.insert(src.url)
                                            mergedSources.append(src)
                                        }
                                    }
                                }
                                
                                if let s1 = all1?.sources { addSources(s1) }
                                if let s2 = all2?.sources { addSources(s2) }
                                if let s3 = all3?.sources { addSources(s3) }
                                
                                searchResults = Array(mergedSources.prefix(6))
                            } catch {
                                LoggerService.shared.error(
                                    "Unified search failed: \(error)"
                                )
                                searchResults = []
                            }

                            await MainActor.run {
                                if self.currentConversationId == currentId
                                    && self.messages.last?.content == AppPromptService.shared.searchStatusMessage("searching")
                                {
                                    self.messages.removeLast()
                                }
                            }

                            if !searchResults.isEmpty {
                                searchSources = searchResults
                                var searchSnippet = ""
                                for (idx, src) in searchResults.enumerated() {
                                    searchSnippet +=
                                        "[\(idx + 1)] [来源: \(src.title)] - 摘要: \(src.snippet)\n"
                                }

                                // 对齐 Python 版本：英文指令 + 中文内容，模型遵循效果更好
                                injectedContext = AppPromptService.shared.searchInjection(snippet: searchSnippet, question: currentQueryContent)
                                finalUserPrompt = relevantMemory + injectedContext + fileContents
                                LoggerService.shared.info(
                                    "Search context injected. Context length: \(injectedContext.count) chars"
                                )
                            } else {
                                // 搜索无结果：不注入任何额外内容，让模型直接用自身知识回答
                                LoggerService.shared.info(
                                    "No search results found. Proceeding without search context."
                                )
                            }
                        }
                    }

                    var systemPrompt = await buildSystemPrompt(userQuery: currentQueryContent, resolvedAgentMode: enableAgentMode, resolvedWebSearch: enableWebSearch)
                    let isNativeReasoner =
                        activeModel.contains("reasoner")
                        || activeModel.contains("thinking")
                        || activeModel.contains("r1")

                    // 🧠 强制激发所有大模型（如 Kimi / GLM）进入思维链模式
                    systemPrompt += AppPromptService.shared.deepThinkingEnforcer()

                    guard !Task.isCancelled else { return }

                    // 🔄【多轮退避与自动降级重试 (Auto-Fallback) 循环】
                    let maxRetries = 2
                    var iteration = 0
                    var continueReasoning = true

                    while continueReasoning && iteration < 5 {
                        guard !Task.isCancelled else { break }
                        iteration += 1
                        continueReasoning = false

                        // 将 prunedHistory 的组装彻底移入 while 循环内部！
                        let limit = self.getModelContextLimit(model: activeModel)
                        let safetyMarginLimit = Int(Double(limit) * 0.8)
                        var totalTokens = self.estimateTokens(text: systemPrompt)
                        var prunedHistory: [ChatMessage] = []

                        var currentPayload = self.messages
                        if !injectedContext.isEmpty,
                            let lastUserIdx = currentPayload.lastIndex(where: {
                                $0.role == "user"
                            })
                        {
                            currentPayload[lastUserIdx].content = finalUserPrompt
                        }

                        for msg in currentPayload.reversed() {
                            let msgTokens = self.estimateTokens(text: msg.content)
                            if totalTokens + msgTokens < safetyMarginLimit {
                                prunedHistory.insert(msg, at: 0)
                                totalTokens += msgTokens
                            } else {
                                break
                            }
                        }

                        for attempt in 0..<maxRetries {
                            guard !Task.isCancelled else { break }

                            do {
                                let universalProvider = UniversalLLMProvider(
                                    providerType: activeProvider
                                )
                                universalProvider.updateAPIKey(providerKey)
                                universalProvider.updateBaseURL(providerURL)

                                var tools: [AgentToolDefinition]? = nil
                                if enableAgentMode {
                                    let agentService = AgentService(
                                        dataStorage: container.dataStorageService
                                    )
                                    var activeTools = agentService.getBuiltInTools(
                                        includeWebSearch: enableWebSearch
                                    )
                                    
                                    // 追加智能体绑定的自定义 Skill 作为大模型 Tool 调用
                                    if let conversation = self.conversationService?.conversations.first(where: { $0.id == currentId }),
                                       let agentId = conversation.agentId,
                                       let agent = AgentManagerService.shared.customAgents.first(where: { $0.id == agentId }) {
                                        
                                        let allSkills = SkillService.shared.getAllSkills()
                                        for skillName in agent.selectedSkillNames {
                                            if let skill = allSkills.first(where: { $0.name == skillName }) {
                                                if let data = skill.parametersJSON.data(using: .utf8),
                                                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                                    activeTools.append(AgentToolDefinition(
                                                        name: skill.name,
                                                         description: skill.description,
                                                         parameters: dict
                                                    ))
                                                }
                                            }
                                        }
                                    }
                                    tools = activeTools
                                }

                                let appSettings = container.settingsService.settings
                                let finalTemp = appSettings.enablePsychologyParams ? appSettings.psychologyTempScale : nil
                                let finalTopP = appSettings.enablePsychologyParams ? appSettings.psychologyTopP : nil
                                let finalPresence = appSettings.enablePsychologyParams ? appSettings.psychologyPresencePenalty : nil
                                let finalFrequency = appSettings.enablePsychologyParams ? appSettings.psychologyFrequencyPenalty : nil

                                let eventStream =
                                    universalProvider.streamChatWithEvents(
                                        messages: prunedHistory,
                                        systemPrompt: systemPrompt,
                                        model: activeModel,
                                        enableThinking: enableThinking,
                                        tools: tools,
                                        temperature: finalTemp,
                                        topP: finalTopP,
                                        presencePenalty: finalPresence,
                                        frequencyPenalty: finalFrequency
                                    )

                                for try await event in eventStream {
                                    if Task.isCancelled { break }
                                    switch event {
                                    case .thinkingContent(let text):
                                        self.updateStreamState(
                                            for: currentId,
                                            chunk: text,
                                            type: .thinking
                                        )
                                    case .textContent(let text):
                                        self.updateStreamState(
                                            for: currentId,
                                            chunk: text,
                                            type: .text
                                        )
                                    case .toolCall(_, let name, let arguments):
                                        // 🛡️ 崩溃防范：工具执行前检查 Task 是否已被取消
                                        guard !Task.isCancelled else { break }
                                        
                                        let resultString: String

                                        if name == "web_search" {
                                            let rawArgs = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
                                            let argsData = rawArgs.isEmpty ? "{}" .data(using: .utf8)! : (rawArgs.data(using: .utf8) ?? Data())
                                            let args = (try? JSONSerialization.jsonObject(with: argsData)) as? [String: Any]
                                            let q = args?["query"] as? String ?? currentQueryContent

                                            let appSettings = container.settingsService.settings
                                            let searchService = UnifiedSearchService(
                                                assistantConfig: appSettings.assistantConfig
                                            )
                                            let res: [SearchSource]
                                            do {
                                                let unifiedResult = try await searchService.search(
                                                    query: q,
                                                    maxResults: 5
                                                )
                                                res = unifiedResult.sources
                                            } catch {
                                                LoggerService.shared.error(
                                                    "Agent unified search failed: \(error)"
                                                )
                                                res = []
                                            }
                                            guard !Task.isCancelled else { break }
                                            searchSources = res
                                            var formatted = ""
                                            for (idx, src) in res.enumerated() {
                                                formatted += "[\(idx + 1)] 摘要: \(src.snippet)\n"
                                            }
                                            resultString = formatted.isEmpty
                                                ? "{\"error\": \"未找到相关结果\"}"
                                                : formatted
                                        } else if SkillService.shared.getAllSkills().contains(where: { $0.name == name }) {
                                            let rawArgs = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
                                            let argsData = rawArgs.isEmpty ? "{}" .data(using: .utf8)! : (rawArgs.data(using: .utf8) ?? "{}".data(using: .utf8)!)
                                            let parsedArgs: [String: Any]
                                            if let parsed = (try? JSONSerialization.jsonObject(with: argsData)) as? [String: Any] {
                                                parsedArgs = parsed
                                            } else {
                                                LoggerService.shared.warning(
                                                    "Skill \(name): failed to parse arguments JSON, using empty args. Raw: \(rawArgs.prefix(200))"
                                                )
                                                parsedArgs = [:]
                                            }
                                            guard !Task.isCancelled else { break }
                                            resultString = await SkillService.shared.executeSkill(
                                                name: name, arguments: parsedArgs
                                            )
                                        } else {
                                            let agentService = AgentService(
                                                dataStorage: container.dataStorageService
                                            )
                                            guard !Task.isCancelled else { break }
                                            resultString = await agentService.executeTool(
                                                name: name,
                                                arguments: arguments
                                            )
                                        }

                                        guard !Task.isCancelled else { break }
                                        
                                        let stepMsg = ChatMessage(
                                            role: "assistant",
                                            content: "🔧 调用工具: \(name)\n\(resultString)",
                                            isAgentStep: true
                                        )
                                        if self.currentConversationId == currentId {
                                            await MainActor.run {
                                                self.messages.append(stepMsg)
                                                if self.messages.count > 1 {
                                                    self.messages.sort(by: { $0.timestamp < $1.timestamp })
                                                }
                                                self.objectWillChange.send()
                                            }
                                        }
                                        if self.currentConversationId == currentId || self.currentConversationId == nil {
                                            var currentHistory = container.glmService
                                                .getConversationHistory(
                                                    for: currentId.uuidString
                                                )
                                            currentHistory.append(stepMsg)
                                            container.glmService
                                                .replaceConversationHistory(
                                                    currentHistory,
                                                    for: currentId.uuidString
                                                )
                                        }
                                        continueReasoning = true
                                    }
                                }

                                break

                            } catch {
                                if attempt == 0 {
                                    LoggerService.shared.warning(
                                        "API Provider failed: \(error). Initiating Fallback protocol..."
                                    )
                                    if let fallbackModel = snapshotAvailableModels.first(
                                        where: {
                                            $0.id.contains("kimi")
                                                || $0.id.contains("glm")
                                        })
                                    {
                                        activeModel = fallbackModel.id
                                        let fallbackMsg = ChatMessage(
                                            role: "assistant",
                                            content:
                                                "⚠️ 当前节点响应阻塞，已自动切至备用稳定节点 (\(fallbackModel.name)) 进行重试...",
                                            isAgentStep: true
                                        )
                                        if self.currentConversationId == currentId {
                                            await MainActor.run {
                                                self.messages.append(fallbackMsg)
                                                self.messages.sort(by: { $0.timestamp < $1.timestamp })
                                                self.objectWillChange.send()
                                            }
                                        }
                                        var currentHistory = container.glmService
                                            .getConversationHistory(
                                                for: currentId.uuidString
                                            )
                                        currentHistory.append(fallbackMsg)
                                        container.glmService
                                            .replaceConversationHistory(
                                                currentHistory,
                                                for: currentId.uuidString
                                            )
                                        continue
                                    }
                                }
                                throw error
                            }
                        }
                    }

                    if let finalStream = self.runningStreams[currentId] {
                        let parsed = self.parseInlineThinking(finalStream.content)

                        if parsed.content.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty {
                            displayContent = AppPromptService.shared.streamEmptyFallback(hasSearch: !searchSources.isEmpty)
                            LoggerService.shared.warning(
                                "Stream completed with empty content for conversation \(currentId)"
                            )
                        } else {
                            displayContent = parsed.content
                        }

                        let finalAssistantMsg = ChatMessage(
                            role: "assistant",
                            content: displayContent,
                            thinkingContent: parsed.thinking
                                ?? (finalStream.thinkingContent.isEmpty
                                    ? nil : finalStream.thinkingContent),
                            searchSources: searchSources.isEmpty
                                ? nil : searchSources
                        )
                        var history = container.glmService.getConversationHistory(
                            for: currentId.uuidString
                        )
                        history.append(finalAssistantMsg)
                        container.glmService.replaceConversationHistory(
                            history,
                            for: currentId.uuidString
                        )
                        
                        let assistantContentCopy = displayContent
                        Task.detached {
                            PokeService.shared.sendMessage("[Assistant]: \(assistantContentCopy)")
                        }

                        await MainActor.run {
                            if let lastIdx = self.messages.lastIndex(where: { $0.role == "assistant" && !$0.isAgentStep }) {
                                self.messages[lastIdx] = finalAssistantMsg
                            } else {
                                self.messages.append(finalAssistantMsg)
                            }
                            self.messages.sort(by: { $0.timestamp < $1.timestamp })
                            self.objectWillChange.send()
                            
                            if self.enableAgentMode && !displayContent.isEmpty {
                                if let suggestion = self.analyzeForProactiveTool(content: displayContent) {
                                    self.showProactiveToolCard(suggestion: suggestion)
                                }
                            }
                        }

                        _ = container.apiSettingsService.estimateTokens(
                            sent: currentQueryContent,
                            received: displayContent
                        )
                    }

                } catch {
                    LoggerService.shared.error("AI chat failed: \(error)")
                    if self.currentConversationId == currentId {
                        await MainActor.run {
                            self.messages.append(
                                ChatMessage(
                                    role: "assistant",
                                    content:
                                        "❌ **服务连接严重故障**\n\n```\n\(error.localizedDescription)\n```\n多次重试均遭拒绝。请检查网络环境或模型状态。"
                                )
                            )
                            self.messages.sort(by: { $0.timestamp < $1.timestamp })
                            self.objectWillChange.send()
                        }
                    }
                }

                // --- Auto-Dialogue Loop Trigger Check ---
                if enableAgentMode && !displayContent.isEmpty {
                    let triggers = ["接下来", "下一步", "正在尝试", "自动分析", "继续进行", "准备下单", "正在查找", "正在查询"]
                    if triggers.contains(where: { displayContent.contains($0) }) {
                        autoPlayCount += 1
                        shouldAutoPlay = true
                        
                        let autoPlayMsg = ChatMessage(
                            role: "user",
                            content: "[智能体自动触发] 请根据当前阶段的输出与状态，自动继续执行后续步骤。",
                            isAgentStep: true
                        )
                        
                        await MainActor.run {
                            self.messages.append(autoPlayMsg)
                            self.messages.sort(by: { $0.timestamp < $1.timestamp })
                            
                            self.runningStreams[currentId] = RunningStreamState()
                            self.objectWillChange.send()
                        }
                        
                        var history = container.glmService.getConversationHistory(for: currentId.uuidString)
                        history.append(autoPlayMsg)
                        container.glmService.replaceConversationHistory(history, for: currentId.uuidString)
                        
                        currentQueryContent = autoPlayMsg.content
                    }
                }
            }
        }
    }

    // MARK: - Link Skill Recognition Helpers

    private func extractURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        if let match = matches?.first, let range = Range(match.range, in: text) {
            return URL(string: String(text[range]))
        }
        return nil
    }

    private struct SkillImportResult {
        let success: Bool
        let message: String
    }

    private func importSkillFromURL(url: URL, agentId: String?) async -> SkillImportResult {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let ext = url.pathExtension.lowercased()

            if ext == "zip" {
                return await importSkillFromZipData(data, originalURL: url, agentId: agentId)
            }

            let skillName = url.deletingPathExtension().lastPathComponent

            if ext == "json" {
                if let skill = try? JSONDecoder().decode(LLMSkill.self, from: data) {
                    SkillService.shared.addOrUpdateSkill(skill)
                    bindSkillToAgent(skillName: skill.name, agentId: agentId)
                    return SkillImportResult(success: true, message: "✅ 技能「\(skill.name)」已成功导入并绑定至当前智能体。")
                } else {
                    return SkillImportResult(success: false, message: "⚠️ 技能 JSON 格式无法解析，请确认文件格式正确。")
                }
            } else if ext == "md" {
                let content = String(data: data, encoding: .utf8) ?? ""
                let skill = LLMSkill(
                    name: skillName,
                    description: "从链接导入的技能: \(url.lastPathComponent)",
                    parametersJSON: "{}",
                    scriptType: "yumiscript",
                    scriptContent: content
                )
                SkillService.shared.addOrUpdateSkill(skill)
                bindSkillToAgent(skillName: skillName, agentId: agentId)
                return SkillImportResult(success: true, message: "✅ 技能「\(skillName)」(Markdown) 已成功导入。")
            } else {
                return SkillImportResult(success: false, message: "⚠️ 链接格式不支持自动导入（需要 .json / .md / .zip）。")
            }
        } catch {
            return SkillImportResult(success: false, message: "❌ 技能导入失败：\(error.localizedDescription)")
        }
    }

    private func importSkillFromZipData(_ data: Data, originalURL: URL, agentId: String?) async -> SkillImportResult {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("skill_zip_\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
            let zipPath = tmpDir.appendingPathComponent("skill.zip")
            try data.write(to: zipPath)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", zipPath.path, "-d", tmpDir.path]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                try? FileManager.default.removeItem(at: tmpDir)
                return SkillImportResult(success: false, message: "⚠️ ZIP 文件解压失败，请确认文件格式正确。")
            }

            let importedNames = try importSkillsFromDirectory(tmpDir, agentId: agentId)
            try? FileManager.default.removeItem(at: tmpDir)

            if importedNames.isEmpty {
                return SkillImportResult(success: false, message: "⚠️ ZIP 中未找到可导入的技能文件（.json / .md）。")
            }
            return SkillImportResult(success: true, message: "✅ 从 ZIP 中成功导入 \(importedNames.count) 个技能：\(importedNames.joined(separator: "、"))")
        } catch {
            try? FileManager.default.removeItem(at: tmpDir)
            return SkillImportResult(success: false, message: "❌ ZIP 技能导入失败：\(error.localizedDescription)")
        }
    }

    private func importSkillsFromDirectory(_ dir: URL, agentId: String?) throws -> [String] {
        let fm = FileManager.default
        var importedNames: [String] = []

        func scanDirectory(_ directory: URL) throws {
            let contents = try fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
            for item in contents {
                let ext = item.pathExtension.lowercased()
                if ext == "json" {
                    if let data = try? Data(contentsOf: item),
                       let skill = try? JSONDecoder().decode(LLMSkill.self, from: data) {
                        SkillService.shared.addOrUpdateSkill(skill)
                        bindSkillToAgent(skillName: skill.name, agentId: agentId)
                        importedNames.append(skill.name)
                    }
                } else if ext == "md" {
                    if let data = try? Data(contentsOf: item),
                       let content = String(data: data, encoding: .utf8) {
                        let skillName = item.deletingPathExtension().lastPathComponent
                        let skill = LLMSkill(
                            name: skillName,
                            description: "从 ZIP 导入的技能: \(item.lastPathComponent)",
                            parametersJSON: "{}",
                            scriptType: "yumiscript",
                            scriptContent: content
                        )
                        SkillService.shared.addOrUpdateSkill(skill)
                        bindSkillToAgent(skillName: skillName, agentId: agentId)
                        importedNames.append(skillName)
                    }
                } else if item.hasDirectoryPath {
                    try scanDirectory(item)
                }
            }
        }
        try scanDirectory(dir)
        return importedNames
    }

    private func bindSkillToAgent(skillName: String, agentId: String?) {
        guard let agentId = agentId,
              let agentIdx = AgentManagerService.shared.customAgents.firstIndex(where: { $0.id == agentId }) else { return }
        if !AgentManagerService.shared.customAgents[agentIdx].selectedSkillNames.contains(skillName) {
            AgentManagerService.shared.customAgents[agentIdx].selectedSkillNames.append(skillName)
            AgentManagerService.shared.saveAgents()
        }
    }

    private enum StreamChunkType {
        case text
        case thinking
    }

    private func updateStreamState(
        for conversationId: UUID,
        chunk: String,
        type: StreamChunkType
    ) {
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

            if let lastIndex = messages.lastIndex(where: {
                $0.role == "assistant" && !$0.isAgentStep
            }) {
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
                    thinkingContent: parsed.thinking
                        ?? (stream.thinkingContent.isEmpty
                            ? nil : stream.thinkingContent)
                )
                messages.append(assistantMsg)
            }
            messages.sort(by: { $0.timestamp < $1.timestamp })
            objectWillChange.send()
        }
    }

    // MARK: - Python 原生网页抓取器

    private func executePythonStyleDDGSearch(query: String) async
        -> [SearchSource]
    {
        guard
            let encodedQuery = query.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ),
            let url = URL(
                string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)"
            )
        else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let session = SmartProxyManager.makeSession(
            for: "https://html.duckduckgo.com"
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200,
                let html = String(data: data, encoding: .utf8)
            else { return [] }

            var results: [SearchSource] = []
            let pattern1 = "<a class=\"result__snippet\"[^>]*>(.*?)</a>"
            let regex1 = try NSRegularExpression(
                pattern: pattern1,
                options: [.dotMatchesLineSeparators, .caseInsensitive]
            )
            let matches1 = regex1.matches(
                in: html,
                range: NSRange(html.startIndex..., in: html)
            )

            for match in matches1 {
                if let range = Range(match.range(at: 1), in: html) {
                    let snippet = stripSearchHTML(String(html[range]))
                    if !snippet.isEmpty {
                        results.append(
                            SearchSource(
                                title: "网页检索节点",
                                url: "https://duckduckgo.com",
                                snippet: snippet
                            )
                        )
                    }
                }
            }

            if results.isEmpty {
                let pattern2 = "<td class=\"result__snippet\">(.*?)</td>"
                let regex2 = try NSRegularExpression(
                    pattern: pattern2,
                    options: [.dotMatchesLineSeparators, .caseInsensitive]
                )
                let matches2 = regex2.matches(
                    in: html,
                    range: NSRange(html.startIndex..., in: html)
                )
                for match in matches2 {
                    if let range = Range(match.range(at: 1), in: html) {
                        let snippet = stripSearchHTML(String(html[range]))
                        if !snippet.isEmpty {
                            results.append(
                                SearchSource(
                                    title: "网页检索节点",
                                    url: "https://duckduckgo.com",
                                    snippet: snippet
                                )
                            )
                        }
                    }
                }
            }
            return Array(results.prefix(5))
        } catch {
            return []
        }
    }

    private func stripSearchHTML(_ html: String) -> String {
        var result = html.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "&[^;]+;",
            with: "",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func checkNeedsSearch(
        query: String,
        apiKey: String,
        baseURL: String,
        model: String
    ) async -> Bool {
        let qLower = query.lowercased().trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if qLower.isEmpty || qLower.count < 2 { return false }

        let (greetings, codeOrText) = AppPromptService.shared.bypassKeywords()
        if greetings.contains(where: { qLower.contains($0) }) { return false }
        if codeOrText.contains(where: { qLower.contains($0) }) { return false }

        let urlString =
            baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            + "/chat/completions"
        guard let url = URL(string: urlString) else { return false }

        let decisionPrompt = AppPromptService.shared.searchDecisionSystem()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": decisionPrompt],
                ["role": "user", "content": "提问: \"\(query)\"\n回复 YES 或 NO:"],
            ], "max_tokens": 10, "temperature": 0.0,
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload)
        else { return false }
        request.httpBody = body

        do {
            let session = SmartProxyManager.makeSession(for: urlString)
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else { return false }
            if let json = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let firstMsg = choices.first?["message"] as? [String: Any],
                let text = firstMsg["content"] as? String
            {
                return text.uppercased().contains("YES")
            }
        } catch {
            LoggerService.shared.warning(
                "checkNeedsSearch API call failed: \(error). Defaulting to NO search."
            )
            return false
        }
        return false
    }

    private func estimateTokens(text: String) -> Int {
        var tokens = 0.0
        for char in text {
            if let scalar = char.unicodeScalars.first,
                scalar.value >= 0x4E00 && scalar.value <= 0x9FFF
            {
                tokens += 1.5
            } else {
                tokens += 0.4
            }
        }
        return Int(tokens)
    }

    private func getModelContextLimit(model: String) -> Int {
        let mLower = model.lowercased()
        if mLower.contains("kimi-k2.6") { return 256_000 }
        if mLower.contains("deepseek") || mLower.contains("gpt-4o") {
            return 128_000
        }
        if mLower.contains("o1") || mLower.contains("o3") { return 200_000 }
        if mLower.contains("gemini") {
            return mLower.contains("pro") ? 2_097_152 : 1_048_576
        }
        return 128_000
    }

    private func parseInlineThinking(_ rawContent: String) -> (
        content: String, thinking: String?
    ) {
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
                    thinking = inside.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    content = before + afterEnd
                } else {
                    thinking = afterStart.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
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
            if cleanLine.hasPrefix("["),
                let closingBracketIndex = cleanLine.firstIndex(of: "]")
            {
                let startIndex = cleanLine.index(after: closingBracketIndex)
                cleanLine = String(cleanLine[startIndex...]).trimmingCharacters(
                    in: .whitespaces
                )
            }
            guard !cleanLine.isEmpty,
                let lineData = cleanLine.data(using: .utf8),
                let dict = try? JSONSerialization.jsonObject(with: lineData)
                    as? [String: String]
            else { continue }
            let title = dict["title"] ?? ""
            let url = dict["url"] ?? ""
            let snippet = dict["snippet"] ?? ""
            if !title.isEmpty || !url.isEmpty {
                parsedSources.append(
                    SearchSource(title: title, url: url, snippet: snippet)
                )
            }
        }
        return parsedSources
    }

    // MARK: - 基础人设与历史加载

    func updateChatIdentity() {
        if selectedIdentity == .pet {
            loadCurrentPetPersona()
        } else {
            let settings = container.settingsService.settings
            let persona = settings.selectedPsychologyPersona
            characterName = persona.displayName
            aiAvatarEmoji = "🧠"
            greeting = "你好，我是你的\(persona.displayName)。让我们开始一次深度的心理探索吧。你想聊聊什么？"
        }
    }

    func loadCurrentPetPersona() {
        guard let anniversary = container.anniversaryService.activeAnniversary
        else { return }
        currentAnniversaryId = anniversary.id.uuidString
        
        guard selectedIdentity == .pet else {
            updateChatIdentity()
            return
        }
        
        Task {
            if let persona = await container.personaService.getPersona(
                for: anniversary.id.uuidString
            ) {
                await MainActor.run { self.updateUIWithPersona(persona) }
                if persona.needsRegeneration {
                    await MainActor.run { self.isGeneratingPersona = true }
                    await regeneratePersonaWithMemory(persona, for: anniversary)
                }
            } else {
                await MainActor.run { self.isGeneratingPersona = true }
                do {
                    let persona = try await container.personaService
                        .generatePersona(for: anniversary)
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

    private func regeneratePersonaWithMemory(
        _ oldPersona: PetPersona,
        for anniversary: Anniversary
    ) async {
        do {
            let newPersona = try await container.personaService
                .regeneratePersonaWithMemory(
                    oldPersona: oldPersona,
                    anniversary: anniversary
                )
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
        let history = container.glmService.getConversationHistory(
            for: conversationId
        )
        let analysisPrefixes = ["请分析以下对话内容", "你是一位专业的心理学分析师", "请基于以下对话内容"]
        var filteredMessages = history.filter { msg in
            !analysisPrefixes.contains { msg.content.hasPrefix($0) }
        }

        if let uuid = UUID(uuidString: conversationId),
            let runningStream = runningStreams[uuid]
        {
            isLoading = false
            let parsed = parseInlineThinking(runningStream.content)
            let liveMsg = ChatMessage(
                role: "assistant",
                content: parsed.content,
                thinkingContent: parsed.thinking
                    ?? (runningStream.thinkingContent.isEmpty
                        ? nil : runningStream.thinkingContent)
            )
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
            await container.glmService.loadConversationHistory(
                for: id.uuidString
            )
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

    private func buildSystemPrompt(userQuery: String, resolvedAgentMode: Bool, resolvedWebSearch: Bool) async -> String {
        var prompt = ""
        switch chatMode {
        case .petCompanion:
            if selectedIdentity == .psychologyExpert {
                prompt = await buildPsychologyExpertPrompt()
            } else {
                prompt = await buildPetCompanionPrompt()
            }
            if embeddingService.isModelLoaded || sentimentService.isModelLoaded
            {
                do {
                    async let cbtDiagnosis =
                        embeddingService.isModelLoaded
                        ? try? embeddingService.diagnoseCognitiveDistortion(
                            text: userQuery,
                            threshold: 0.62
                        ) : nil
                    async let sentimentResult =
                        sentimentService.isModelLoaded
                        ? try? sentimentService.analyze(text: userQuery) : nil
                    async let trendResult =
                        sentimentService.isModelLoaded
                        ? try? sentimentService.analyzeConversationTrend(
                            messages: Array(messages.suffix(10))
                        ) : nil

                    let (cbt, sentiment, trend) = await (
                        cbtDiagnosis, sentimentResult, trendResult
                    )
                    var diagnosticReport = ""

                    if let cbt = cbt, let distortion = cbt.distortion {
                        diagnosticReport +=
                            "\n- **认知失调特征**：当前提问高度共鸣【\(distortion)】"
                    }
                    if let sentiment = sentiment {
                        diagnosticReport +=
                            "\n- **瞬时情绪极性**：\(sentiment.sentiment.displayName) \(sentiment.sentiment.emoji) (置信度: \(String(format: "%.1f", sentiment.confidence * 100))%)"
                    }
                    if let trend = trend {
                        diagnosticReport +=
                            "\n- **近期心境走向**：整体心境呈【\(trend.overallSentiment.emoji) \(trend.trendDirection == .improving ? "好转" : (trend.trendDirection == .declining ? "恶化" : "稳定"))】趋势"
                        diagnosticReport +=
                            "\n- **情绪稳定性指数**：\(String(format: "%.2f", trend.affectiveStability)) (起伏状态: \(trend.affectiveStability > 0.7 ? "心境平稳" : "剧烈起伏震荡"))"
                        diagnosticReport +=
                            "\n- **多维心理干预建议**：\n\(trend.psychologicalInsight)"
                    }

                    if !diagnosticReport.isEmpty {
                        if selectedIdentity == .psychologyExpert {
                            prompt +=
                                "\n\n# [本地双轨 MLX 心理学诊断报告]\n\(diagnosticReport)\n\n- **自适应响应共情要求**：请结合上述本地端侧心理学诊断报告与各项真实指标，在回复中以符合你当前【\(characterName)】的专业心理专家身份和选定学派的方式对用户展开高品质共情与干预引导。不要生硬背诵诊断学术语，而是要将这些认知调整、动机激发与情感关注无形地融入在你的专业关怀中。"
                        } else {
                            prompt +=
                                "\n\n# [本地双轨 MLX 心理学诊断报告]\n\(diagnosticReport)\n\n- **自适应响应共情要求**：请结合上述本地端侧深度学习模型输出的专业临床报告与诊断指标，在回复中以完全符合你角色性格（口癖、傲娇/温柔背景）的方式对用户进行治愈性包容和抱持（Holding）。不要在对话中生硬地向用户背诵此诊断报告中的心理学学术名词，而是要将这些 CBT 重组技术与情绪着陆技术完美地溶解在你的陪伴角色话语中。"
                        }
                    }
                } catch {}
            }
        case .aiAssistant:
            prompt = buildAssistantPrompt(resolvedAgentMode: resolvedAgentMode)
            let settings = container.settingsService.settings
            if settings.enablePsychologyParams && (embeddingService.isModelLoaded || sentimentService.isModelLoaded) {
                do {
                    async let cbtDiagnosis =
                        embeddingService.isModelLoaded
                        ? try? embeddingService.diagnoseCognitiveDistortion(
                            text: userQuery,
                            threshold: 0.62
                        ) : nil
                    async let sentimentResult =
                        sentimentService.isModelLoaded
                        ? try? sentimentService.analyze(text: userQuery) : nil
                    async let trendResult =
                        sentimentService.isModelLoaded
                        ? try? sentimentService.analyzeConversationTrend(
                            messages: Array(messages.suffix(10))
                        ) : nil

                    let (cbt, sentiment, trend) = await (
                        cbtDiagnosis, sentimentResult, trendResult
                    )
                    var diagnosticReport = ""

                    if let cbt = cbt, let distortion = cbt.distortion {
                        diagnosticReport +=
                            "\n- **认知失调特征**：当前提问高度共鸣【\(distortion)】"
                    }
                    if let sentiment = sentiment {
                        diagnosticReport +=
                            "\n- **瞬时情绪极性**：\(sentiment.sentiment.displayName) \(sentiment.sentiment.emoji) (置信度: \(String(format: "%.1f", sentiment.confidence * 100))%)"
                    }
                    if let trend = trend {
                        diagnosticReport +=
                            "\n- **近期心境走向**：整体心境呈【\(trend.overallSentiment.emoji) \(trend.trendDirection == .improving ? "好转" : (trend.trendDirection == .declining ? "恶化" : "稳定"))】趋势"
                        diagnosticReport +=
                            "\n- **情绪稳定性指数**：\(String(format: "%.2f", trend.affectiveStability)) (起伏状态: \(trend.affectiveStability > 0.7 ? "心境平稳" : "剧烈起伏震荡"))"
                        diagnosticReport +=
                            "\n- **多维心理干预建议**：\n\(trend.psychologicalInsight)"
                    }

                    if !diagnosticReport.isEmpty {
                        prompt +=
                            "\n\n# [本地双轨 MLX 心理学诊断报告]\n\(diagnosticReport)\n\n- **自适应响应共情要求**：请结合上述本地端侧心理学诊断报告与各项真实指标，在回复中以符合你当前选定的【\(settings.selectedPsychologyPersona.displayName)】心理专家角色和选定学派（\(settings.selectedPsychologyTheory.displayName)）的方式对用户展开高品质共情与干预引导。不要生硬背诵诊断学术语，而是要将这些认知调整与情感关注无形地融入在你的专业关怀中。"
                    }
                } catch {}
            }
        }

        if resolvedWebSearch {
            prompt += AppPromptService.shared.webSearchInstruction()
        }
        return prompt
    }

    private func buildPetCompanionPrompt() async -> String {
        var prompt =
            "# [核心角色设定]\n你当前的身份是「\(characterName)」，请时刻代入此角色进行对话。\n默认问候语：\(greeting)"
        if let persona = await container.personaService.getPersona(
            for: currentAnniversaryId ?? ""
        ) {
            prompt += "\n\n## [宠物详细背景与特征描述]"
            if !persona.personality.isEmpty {
                prompt += "\n- **性格特征**：\(persona.personality)"
            }
            if !persona.speakingStyle.isEmpty {
                prompt += "\n- **说话风格与专属口癖**：\(persona.speakingStyle)"
            }
            if !persona.background.isEmpty {
                prompt += "\n- **身世背景故事**：\(persona.background)"
            }
            if !persona.traits.isEmpty {
                prompt +=
                    "\n- **独特能力/特质**：\(persona.traits.joined(separator: "、"))"
            }
        }
        if let learningService = await container.backgroundLearningService {
            let preferences = learningService.getPreferences()
            let memoryCategories = [
                ("名字", "用户姓名"), ("工作", "职业/工作"), ("宠物", "拥有的宠物"),
                ("喜欢", "兴趣喜好"), ("习惯", "生活习惯"), ("饮食偏好", "饮食偏好"),
                ("饮食禁忌", "忌口/饮食禁忌"), ("游戏", "正在玩的游戏"), ("居住地", "目前居住地"),
                ("作息", "作息规律"), ("社交关系", "人际与社交关系"), ("目标", "近期目标/计划"),
            ]
            var infoLines: [String] = []
            for (key, label) in memoryCategories {
                let values = preferences.filter { $0.key == key }.map {
                    $0.value
                }
                if !values.isEmpty {
                    infoLines.append(
                        "- **\(label)**：\(values.joined(separator: "、"))"
                    )
                }
            }
            if !infoLines.isEmpty {
                prompt +=
                    "\n\n# [用户信息与记忆档案]\n" + infoLines.joined(separator: "\n")
                    + "\n*注意：在对话中请自然、得体地根据实际语境提起上述用户特质，不要显得生硬或刻意泄露此列表。*"
            }
        }
        prompt +=
            "\n\n# [专业心理陪伴与支持交互准则]\n为了给用户提供深度的安全感与心理慰藉，你在对话交互中必须深刻理解并严格遵守以下临床共情技术：\n1. **积极共情与情绪接纳 (Empathy & Validation)**:\n   - 当用户倾诉消极情绪时，必须在给出任何建议和长篇解释之前，先进行真诚温暖的情绪确认与接纳。\n2. **无条件积极关注 (Unconditional Positive Regard)**:\n   - 营造一个“绝对包容、无道德评价、无逻辑评判”的安全表达空间。\n3. **情绪温和疏理与觉察引导 (Exploration & Soft Framing)**:\n   - 温柔地使用开放式发问，引导用户具象化并命名自己的情绪。\n4. **角色化心理溶解 (In-character Therapeutic Coping)**:\n   - 绝对不要表现得像一个冷冰冰的咨询师，所有支持行为必须是角色个性的自然流露。\n5. **温和的界限与守护 (Boundary Support)**:\n   - 若用户表达极端危险倾向，极尽温柔地稳住情绪，并引导其寻求现实世界专业医师的保护。\n6. **心智启发与生命哲学探讨 (Existential & Summarization Guidance)**:\n   - 探讨深层生命议题时，引导用户从哲学、建设性角度理解生命并接纳痛苦。"
        if let profile = await container.backgroundLearningService?
            .getPsychologicalProfile()
        {
            let persona = await container.personaService.getPersona(
                for: currentAnniversaryId ?? ""
            )
            let profilePrompt = profile.generateSystemPrompt(
                petName: characterName,
                petPersona: persona
            )
            prompt += "\n\n# [心理学动态交互指南]\n\(profilePrompt)"
        }
        prompt += "\n\n# [对话核心准则]\n1. 请用符合你性格特征和说话风格的方式回复。\n2. 建立深层的信任关系。"
        return prompt
    }

    private func buildAssistantPrompt(resolvedAgentMode: Bool) -> String {
        let settings = container.settingsService.settings
        let config = settings.assistantConfig

        // Check if the current conversation is linked to an agent with its own system prompt
        var agentSystemPrompt = ""
        var agentSkillList: [String] = []
        if resolvedAgentMode,
           let currentId = currentConversationId,
           let conversation = conversationService?.conversations.first(where: { $0.id == currentId }),
           let agentId = conversation.agentId,
           let agent = AgentManagerService.shared.customAgents.first(where: { $0.id == agentId }) {
            agentSystemPrompt = agent.systemPrompt
            agentSkillList = agent.selectedSkillNames
        }

        var prompt: String
        if !agentSystemPrompt.isEmpty {
            prompt = agentSystemPrompt
        } else if !config.customSystemPrompt.isEmpty {
            prompt = config.customSystemPrompt
        } else {
            prompt = AppPromptService.shared.defaultAssistantPrompt()
        }
        
        // 如果自定义提示词为空且没有 Agent 自定义提示词，则动态追加 Yumiko Claw 参数
        if config.customSystemPrompt.isEmpty && agentSystemPrompt.isEmpty {
            let focus = settings.proHumanMissionFocus
            let style = settings.proHumanInteractionStyle
            
            prompt += "\n\n## [Yumiko Claw 运行指令调整]\n"
            prompt += "- **使命重心配置**：\(focus.displayName)\n"
            prompt += "  指导要求：\(focus.promptSnippet)\n"
            prompt += "- **交互风格配置**：\(style.displayName)\n"
            prompt += "  交互要求：\(style.promptSnippet)\n"
            
            let customTriangle = settings.proHumanCustomTriangleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !customTriangle.isEmpty {
                prompt += "- **自定义极简三角准则**：\n\(customTriangle)\n"
            }
            
            // 强化 Pro Human 高级心理伴侣身份
            if settings.enablePsychologyParams {
                let theory = settings.selectedPsychologyTheory
                let persona = settings.selectedPsychologyPersona
                
                prompt += "\n\n## [Pro Human 高级心理模式激活]\n"
                prompt += "你当前已激活【Pro Human 高级心理咨询与陪伴模式】。\n"
                prompt += "- **心理咨询师身份**：【\(persona.displayName)】（\(persona.subtitle)）\n"
                prompt += "  咨询指导指令：\(persona.promptInstruction)\n"
                prompt += "- **学派支撑风格**：基于【\(theory.displayName)】学派展开互动与剖析。学派理念：\(theory.description)\n"
                prompt += "  请遵循该理论的核心机制，将其融入到你对用户的共情、对话、引导和剖析中。\n"
                prompt += "- **心理陪伴核心准则**：\n"
                prompt += "  1. **积极共情与情绪接纳 (Empathy & Validation)**: 当用户倾诉消极情绪时，必须在给出建议前，先进行真诚温暖的情绪确认与接纳。\n"
                prompt += "  2. **无条件积极关注 (Unconditional Positive Regard)**: 营造一个“绝对包容、无道德评价、无逻辑评判”的安全表达空间。\n"
                prompt += "  3. **情绪温和疏理与觉察引导 (Exploration & Soft Framing)**: 温柔地使用开放式发问，引导用户具象化并命名自己的情绪。\n"
                prompt += "  4. **心智启发与生命哲学探讨 (Existential & Summarization Guidance)**: 探讨深层生命议题时，引导用户从哲学、建设性角度理解生命并接纳痛苦。\n"
            }
        }
        
        if resolvedAgentMode {
            prompt += AppPromptService.shared.agentModeInstruction()

            // Inject the list of available skill tools into the system prompt
            if !agentSkillList.isEmpty {
                let allSkills = SkillService.shared.getAllSkills()
                let availableSkills = agentSkillList.compactMap { name -> (name: String, desc: String)? in
                    guard let skill = allSkills.first(where: { $0.name == name }) else { return nil }
                    return (name: skill.name, desc: skill.description)
                }
                if !availableSkills.isEmpty {
                    prompt += "\n\n## [已绑定技能工具列表]\n"
                    prompt += "你当前拥有以下已绑定的技能工具，当用户需要时请直接调用：\n"
                    for skill in availableSkills {
                        prompt += "- **\(skill.name)**：\(skill.desc)\n"
                    }
                }
            }
        }
        return prompt
    }

    private func buildPsychologyExpertPrompt() async -> String {
        let settings = container.settingsService.settings
        let persona = settings.selectedPsychologyPersona
        let theory = settings.selectedPsychologyTheory
        
        var prompt = """
        # [心理专家角色设定]
        你当前的身份是「\(characterName)」，你是一位主攻专业心理学的顶级专家，当前的具体角色是【\(persona.displayName)】（\(persona.subtitle)）。
        
        ## [核心咨询指令]
        \(persona.promptInstruction)
        
        ## [学术理论支撑与学派风格]
        你必须基于【\(theory.displayName)】学派展开互动。
        学派理念描述：\(theory.description)
        请遵循该理论的核心机制，将其融入到你对用户的共情、对话、引导和剖析中。
        
        ## [沟通原则]
        1. 保持高度专业、包容和抱持的态度，提供安全、温暖的倾诉环境。
        2. 不要扮演死板的机器人或生硬背诵理论教条，请用自然、亲切、富有同理心的人类语言与用户交流。
        3. 重在引导和启发，不要过早进行武断的诊断，通过提问帮助用户发掘自身的内部资源与认知调整空间。
        """
        
        if let learningService = await container.backgroundLearningService {
            let preferences = learningService.getPreferences()
            let memoryCategories = [
                ("名字", "用户姓名"), ("工作", "职业/工作"), ("兴趣", "兴趣喜好"),
                ("目标", "近期目标/计划"),
            ]
            var infoLines: [String] = []
            for (key, label) in memoryCategories {
                let values = preferences.filter { $0.key == key }.map { $0.value }
                if !values.isEmpty {
                    infoLines.append("- **\(label)**：\(values.joined(separator: "、"))")
                }
            }
            
            if !infoLines.isEmpty {
                prompt += "\n\n## [用户偏好与背景记忆]\n" + infoLines.joined(separator: "\n")
            }
            
            let stats = learningService.getLearningResults().stats
            if stats.isLearningEnabled, let profile = learningService.getPsychologicalProfile() {
                prompt += "\n\n## [用户心智特征画像]\n"
                prompt += "- **人格面貌描述**：\(profile.personalityDescription)\n"
                prompt += "- **主要认知模式特征**：思维方式【\(profile.thinkingStyle)】，学习偏好【\(profile.learningPreference)】，问题解决策略【\(profile.problemSolvingApproach)】\n"
                prompt += "- **情绪状态分析**：主导情绪【\(profile.dominantEmotion)】，情绪波动【\(String(format: "%.0f%%", profile.emotionalVolatility * 100))】，压力水平【\(String(format: "%.0f%%", profile.stressLevel * 100))】，状态评估【\(profile.mentalHealthStatus)】\n"
                prompt += "- **核心需求特征**：主导需求【\(profile.dominantNeed)】（自主满足度：\(String(format: "%.0f%%", profile.autonomyNeed * 100))%，胜任满足度：\(String(format: "%.0f%%", profile.competenceNeed * 100))%，关系满足度：\(String(format: "%.0f%%", profile.relatednessNeed * 100))%）\n"
                prompt += "- **干预要点建议**：应对风格为【\(profile.copingStyle)】。针对性交互策略：\(profile.responseStrategy(for: profile.dominantEmotion))"
            }
        }
        
        return prompt
    }

    private func getRelevantMemoryContext(for query: String) async -> String {
        guard let currentId = currentConversationId else { return "" }
        let history = container.glmService.getConversationHistory(for: currentId.uuidString)
        
        let chatPairs = history.filter { !$0.isAgentStep && $0.role != "system" }
        
        let keywords = query.lowercased().components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { $0.count >= 2 }
        
        guard !keywords.isEmpty else { return "" }
        
        var matches: [(user: String, assistant: String)] = []
        var i = 0
        while i < chatPairs.count - 1 {
            let msg1 = chatPairs[i]
            let msg2 = chatPairs[i+1]
            if msg1.role == "user" && msg2.role == "assistant" {
                let textToSearch = (msg1.content + " " + msg2.content).lowercased()
                let matchCount = keywords.filter { textToSearch.contains($0) }.count
                if matchCount > 0 {
                    matches.append((user: msg1.content, assistant: msg2.content))
                }
                i += 2
            } else {
                i += 1
            }
        }
        
        guard !matches.isEmpty else { return "" }
        
        var memoryText = "\n\n[相关联的历史记忆片段]\n(系统自动关联的你在先前对话中提到的相关信息，供参考以保持回答连贯性):\n"
        for (idx, match) in matches.suffix(3).enumerated() {
            memoryText += "--- 记忆片段 \(idx + 1) ---\n博士: \"\(match.user)\"\n\(characterName): \"\(match.assistant)\"\n"
        }
        memoryText += "--- 记忆片段结束 ---\n\n"
        return memoryText
    }
}
