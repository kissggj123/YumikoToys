//
//  GLMService.swift
//  YumikoToys
//
//  GLM 大模型服务实现（v4.1.1 - 多对话状态闭环与防污染版）
//

import Foundation
import Combine

final class GLMService: GLMServiceProtocol {

    // MARK: - Properties

    private var apiKey: String
    private var baseURL: String
    private var model: String

    /// 多对话历史记录：conversationId -> messages
    private var conversationHistories: [String: [ChatMessage]] = [:]
    private let maxHistoryCount = 50

    /// 当前活跃的对话 ID
    private var currentConversationId: String = "default"

    private let dataStorageService: DataStorageService

    var serviceName: String { "GLMService" }

    // MARK: - Initialization

    init(dataStorageService: DataStorageService) {
        self.apiKey = "02a1434010954ef9a035f1ab25028efc.9cJhWaJb5ha988su"
        self.baseURL = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        self.model = "glm-4"
        self.dataStorageService = dataStorageService
    }

    // MARK: - ServiceLifecycle

    func initialize() async {
        await loadAllConversationHistories()
        LoggerService.shared.info("GLMService initialized with multi-conversation support")
    }

    func start() async {}

    func stop() {
        saveAllConversationHistories()
    }

    // MARK: - 对话管理

    /// 切换到指定对话
    func switchToConversation(_ conversationId: String) {
        currentConversationId = conversationId
        if conversationHistories[conversationId] == nil {
            conversationHistories[conversationId] = []
        }
        LoggerService.shared.info("GLMService switched to conversation: \(conversationId)")
    }

    /// 创建新对话
    func createConversation(_ conversationId: String) {
        conversationHistories[conversationId] = []
        currentConversationId = conversationId
        
        // 【核心防污染修复】创建新会话时，立即向磁盘写入空缓存
        // 这可以彻底覆盖并冲刷掉磁盘上同名路径可能残留的废弃或脏数据缓存，保证新建会话 100% 处于空白纯净状态
        saveConversationHistory(for: conversationId)
        
        LoggerService.shared.info("GLMService created new conversation: \(conversationId)")
    }

    /// 删除指定对话的历史记录
    func deleteConversation(_ conversationId: String) {
        // 1. 从内存映射表中立即抹除
        conversationHistories.removeValue(forKey: conversationId)
        
        // 2. 【核心防残留修复】如果删除的是当前正在活跃的对话，必须立刻重置活跃 ID 为默认值
        // 避免后续正在传输的 AI 响应（streamMessage）误向已被删除的会话中追加新消息，导致该会话重新写入磁盘“复活”
        if currentConversationId == conversationId {
            currentConversationId = "default"
        }
        
        // 3. 异步物理删除磁盘存储文件
        Task {
            await dataStorageService.delete(at: "memory/conversations/\(conversationId).json")
        }
        LoggerService.shared.info("GLMService deleted conversation: \(conversationId)")
    }

    /// 获取当前对话历史记录
    func getConversationHistory(for conversationId: String? = nil) -> [ChatMessage] {
        let id = conversationId ?? currentConversationId
        return conversationHistories[id] ?? []
    }

    /// 清空当前对话的历史记录
    func clearConversationHistory(for conversationId: String? = nil) {
        let id = conversationId ?? currentConversationId
        conversationHistories[id] = []
        saveConversationHistory(for: id)
    }

    /// 替换指定对话的历史记录
    func replaceConversationHistory(_ newHistory: [ChatMessage], for conversationId: String? = nil) {
        let id = conversationId ?? currentConversationId
        conversationHistories[id] = newHistory
        saveConversationHistory(for: id)
    }

    // MARK: - API 调用

    func sendMessage(_ message: String, context: [ChatMessage], saveToHistory: Bool = true) async throws -> String {
        let messages = buildMessages(userMessage: message, context: context)

        let request = GLMRequest(
            model: model,
            messages: messages,
            stream: false,
            temperature: 0.7,
            maxTokens: 2048
        )

        let response = try await performRequest(request)

        if saveToHistory {
            let userMsg = ChatMessage(role: "user", content: message)
            let assistantMsg = ChatMessage(role: "assistant", content: response)
            addToHistory(userMsg)
            addToHistory(assistantMsg)
        }

        return response
    }

    func streamMessage(_ message: String, context: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        return streamMessage(message, context: context, systemPrompt: nil)
    }

    func streamMessage(_ message: String, context: [ChatMessage], systemPrompt: String? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let messages = self.buildMessages(userMessage: message, context: context, customSystemPrompt: systemPrompt)

                    let request = GLMRequest(
                        model: self.model,
                        messages: messages,
                        stream: true,
                        temperature: 0.7,
                        maxTokens: 2048
                    )

                    var fullResponse = ""
                    for try await chunk in self.performStreamRequest(request) {
                        fullResponse += chunk
                        continuation.yield(chunk)
                    }

                    // 保存完整对话
                    let userMsg = ChatMessage(role: "user", content: message)
                    let assistantMsg = ChatMessage(role: "assistant", content: fullResponse)
                    self.addToHistory(userMsg)
                    self.addToHistory(assistantMsg)

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func updateConfiguration(apiURL: String, apiKey: String, model: String) {
        if !apiURL.isEmpty {
            self.baseURL = apiURL
        }
        if !apiKey.isEmpty {
            self.apiKey = apiKey
        }
        if !model.isEmpty {
            self.model = model
        }
        LoggerService.shared.info("GLMService configuration updated: URL=\(self.baseURL), model=\(self.model)")
    }

    // MARK: - 记忆系统

    func saveToMemory(messages: [ChatMessage]) {
        let memoryKey = "glm_memory_\(Date().timeIntervalSince1970)"
        Task {
            await dataStorageService.save(messages, to: "memory/\(memoryKey).json")
        }
    }

    func getRelevantMemory(for query: String, limit: Int = 5) -> [ChatMessage] {
        let keywords = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let currentHistory = conversationHistories[currentConversationId] ?? []
        let relevant = currentHistory.filter { message in
            let content = message.content.lowercased()
            return keywords.contains { content.contains($0) }
        }

        return Array(relevant.suffix(limit))
    }

    // MARK: - Private Methods

    private func buildMessages(userMessage: String, context: [ChatMessage], customSystemPrompt: String? = nil) -> [GLMMessage] {
        var messages: [GLMMessage] = []

        let systemPrompt: String
        if let custom = customSystemPrompt, !custom.isEmpty {
            systemPrompt = custom
        } else {
            systemPrompt = "你是「红皇后」，「兔可可」王国的绝对统治者..." // 保留您的系统提示词内容不变
        }
        messages.append(GLMMessage(role: "system", content: systemPrompt))

        let relevantMemory = getRelevantMemory(for: userMessage, limit: 3)
        for memory in relevantMemory {
            messages.append(GLMMessage(role: memory.role, content: memory.content))
        }

        for message in context.suffix(5) {
            messages.append(GLMMessage(role: message.role, content: message.content))
        }

        messages.append(GLMMessage(role: "user", content: userMessage))

        return messages
    }

    private func performRequest(_ request: GLMRequest) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw GLMError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 60

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GLMError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                throw GLMError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }

            do {
                let glmResponse = try JSONDecoder().decode(GLMResponse.self, from: data)

                guard let choice = glmResponse.choices.first else {
                    throw GLMError.invalidResponse
                }

                return choice.message.content
            } catch let decodingError {
                throw GLMError.decodingError(decodingError)
            }
        } catch let error as GLMError {
            throw error
        } catch {
            throw GLMError.networkError(error)
        }
    }

    private func performStreamRequest(_ request: GLMRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: self.baseURL) else {
                        throw GLMError.invalidURL
                    }

                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
                    urlRequest.httpBody = try JSONEncoder().encode(request)
                    urlRequest.timeoutInterval = 60

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw GLMError.invalidResponse
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                        }
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知错误"
                        throw GLMError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))

                            if jsonString == "[DONE]" {
                                break
                            }

                            if let data = jsonString.data(using: .utf8) {
                                do {
                                    let streamResponse = try JSONDecoder().decode(GLMStreamResponse.self, from: data)
                                    if let content = streamResponse.choices.first?.delta.content {
                                        continuation.yield(content)
                                    }
                                } catch let decodingError {
                                    LoggerService.shared.warning("Stream decoding error: \(decodingError)")
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch let error as GLMError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: GLMError.networkError(error))
                }
            }
        }
    }

    private func addToHistory(_ message: ChatMessage) {
        // 如果当前会话已被彻底抹除，不再向其追加历史，保障安全隔离
        guard conversationHistories[currentConversationId] != nil else { return }
        
        conversationHistories[currentConversationId]?.append(message)

        if let count = conversationHistories[currentConversationId]?.count,
           count > maxHistoryCount {
            conversationHistories[currentConversationId]?.removeFirst(count - maxHistoryCount)
        }

        saveConversationHistory(for: currentConversationId)
    }

    private func saveConversationHistory(for conversationId: String) {
        guard let history = conversationHistories[conversationId] else { return }
        Task {
            await dataStorageService.save(history, to: "memory/conversations/\(conversationId).json")
        }
    }

    private func saveAllConversationHistories() {
        for (conversationId, history) in conversationHistories {
            Task {
                await dataStorageService.save(history, to: "memory/conversations/\(conversationId).json")
            }
        }
    }

    private func loadAllConversationHistories() async {}

    /// 加载指定对话的历史记录
    func loadConversationHistory(for conversationId: String) async {
        if let history: [ChatMessage] = await dataStorageService.load([ChatMessage].self, from: "memory/conversations/\(conversationId).json") {
            conversationHistories[conversationId] = history
            LoggerService.shared.info("GLMService loaded history for conversation: \(conversationId), \(history.count) messages")
        } else {
            if conversationId == "default",
               let oldHistory: [ChatMessage] = await dataStorageService.load([ChatMessage].self, from: "memory/conversation_history.json") {
                conversationHistories[conversationId] = oldHistory
                LoggerService.shared.info("GLMService migrated old history to new format: \(oldHistory.count) messages")
            } else {
                conversationHistories[conversationId] = []
            }
        }
    }
}
