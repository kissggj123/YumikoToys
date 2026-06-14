//
//  NVIDIAProvider.swift
//  YumikoToys
//
//  万能大模型 API 驱动器（v7.0.0 - 全新多厂商原生深度集成版）
//

import Foundation

// MARK: - 智能网络路由代理管理器
struct SmartProxyManager {
    static func makeSession(for urlString: String) -> URLSession {
        let config = URLSessionConfiguration.default

        // 大陆白名单：国内大模型域名（Kimi/智谱/硅基/百度等），强制直连，享受极致低延迟
        let mainlandDomains = [
            "moonshot.cn", "zhipuai.cn", "siliconflow.cn", "baidu.com",
            "volcengine.com",
        ]
        let isMainland = mainlandDomains.contains { urlString.contains($0) }

        if !isMainland {
            // 海外地址（OpenAI / DeepSeek / DuckDuckGo / Anthropic 等）：强制挂载指定的 7897 代理端口
            config.connectionProxyDictionary = [
                kCFNetworkProxiesHTTPEnable as String: 1,
                kCFNetworkProxiesHTTPProxy as String: "127.0.0.1",
                kCFNetworkProxiesHTTPPort as String: 7897,
                kCFNetworkProxiesHTTPSEnable as String: 1,
                kCFNetworkProxiesHTTPSProxy as String: "127.0.0.1",
                kCFNetworkProxiesHTTPSPort as String: 7897,
                kCFNetworkProxiesSOCKSEnable as String: 1,
                kCFNetworkProxiesSOCKSProxy as String: "127.0.0.1",
                kCFNetworkProxiesSOCKSPort as String: 7897,
            ]
        }

        // 降低超时时间，一旦 30 秒无响应立刻掐断，供上层触发“自动切换保底模型”逻辑
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }
}

final class UniversalLLMProvider: AIProvider {
    let providerName = "Universal LLM Provider"
    let providerType: AIProviderType
    
    private var apiKey: String = ""
    private var baseURL: String = ""
    
    init(providerType: AIProviderType = .openai) {
        self.providerType = providerType
        self.baseURL = providerType.defaultBaseURL
    }
    
    func updateAPIKey(_ key: String) {
        self.apiKey = key
    }
    
    func updateBaseURL(_ url: String) {
        if !url.isEmpty {
            self.baseURL = url
        }
    }
    
    // MARK: - AIProvider Protocol
    
    func streamChat(
        messages: [ChatMessage],
        systemPrompt: String?,
        model: String
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let stream = streamChatWithEvents(
                        messages: messages,
                        systemPrompt: systemPrompt,
                        model: model,
                        enableThinking: false
                    )
                    for try await event in stream {
                        if case .textContent(let text) = event {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func fetchAvailableModels(apiKey: String) async throws -> [AIModelInfo] {
        if providerType == .anthropic {
            throw AIProviderError.apiError("Anthropic does not support standard /models endpoint. Using preset models.")
        }
        
        let endpoint: String
        let cleanBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanBaseURL.hasSuffix("chat/completions") {
            endpoint = cleanBaseURL.replacingOccurrences(of: "chat/completions", with: "models")
        } else {
            endpoint = cleanBaseURL.hasSuffix("/") ? cleanBaseURL + "models" : cleanBaseURL + "/models"
        }
        
        guard let url = URL(string: endpoint) else {
            throw AIProviderError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if providerType != .ollama && !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            if providerType == .mimo {
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            }
        }
        
        let session = SmartProxyManager.makeSession(for: endpoint)
        var dataAndResponse: (Data, URLResponse)? = nil
        do {
            dataAndResponse = try await session.data(for: request)
        } catch {
            LoggerService.shared.warning("Proxy session failed for \(endpoint): \(error). Falling back to direct connection...")
            dataAndResponse = try await URLSession.shared.data(for: request)
        }
        
        guard let (data, response) = dataAndResponse else {
            throw AIProviderError.apiError("Failed to fetch available models")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIProviderError.apiError("HTTP status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        let modelsResponse = try JSONDecoder().decode(NVIDIAModelsResponse.self, from: data)
        return modelsResponse.data.map { model in
            let id = model.id
            let supportsThinking = id.contains("thinking") || id.contains("think") || id.contains("reasoner") || id.contains("r1")
            let supportsVision = id.contains("vision") || id.contains("vl") || id.contains("v")
            return AIModelInfo(
                id: id,
                name: id.components(separatedBy: "/").last ?? id,
                provider: providerType,
                description: "",
                supportsThinking: supportsThinking,
                supportsVision: supportsVision,
                supportsTools: !supportsThinking
            )
        }
    }
    
    // MARK: - SSE Event Stream
    
    func streamChatWithEvents(
        messages: [ChatMessage],
        systemPrompt: String?,
        model: String,
        enableThinking: Bool = false,
        tools: [AgentToolDefinition]? = nil,
        temperature: Double? = nil,
        topP: Double? = nil,
        presencePenalty: Double? = nil,
        frequencyPenalty: Double? = nil
    ) -> AsyncThrowingStream<UniversalStreamEvent, Error> {
        let capturedApiKey = self.apiKey
        let capturedBaseURL = self.baseURL
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let cleanBaseURL = capturedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if providerType == .poke {
                        let endpoint = cleanBaseURL.isEmpty ? "https://poke.com/api/v1/inbound-sms/webhook" : cleanBaseURL
                        guard let url = URL(string: endpoint) else { throw AIProviderError.invalidURL }
                        
                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.setValue("Bearer \(capturedApiKey)", forHTTPHeaderField: "Authorization")
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        
                        let userMessage = messages.last(where: { $0.role == "user" })?.content ?? ""
                        let payload: [String: Any] = [
                            "message": userMessage
                        ]
                        
                        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
                        
                        let session = SmartProxyManager.makeSession(for: endpoint)
                        var dataAndResponse: (Data, URLResponse)? = nil
                        do {
                            dataAndResponse = try await session.data(for: request)
                        } catch {
                            LoggerService.shared.warning("Proxy session failed for \(endpoint): \(error). Falling back to direct connection...")
                            dataAndResponse = try await URLSession.shared.data(for: request)
                        }
                        
                        guard let (data, response) = dataAndResponse else {
                            throw AIProviderError.apiError("Failed to fetch from Poke")
                        }
                        
                        guard let httpResponse = response as? HTTPURLResponse else {
                            throw AIProviderError.invalidResponse
                        }
                        
                        guard (200...299).contains(httpResponse.statusCode) else {
                            let errorStr = String(data: data, encoding: .utf8) ?? "Status \(httpResponse.statusCode)"
                            throw AIProviderError.apiError("HTTP \(httpResponse.statusCode): \(errorStr)")
                        }
                        
                        func parsePokeResponse(_ data: Data) -> String? {
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                var extracted: String? = nil
                                if let responseVal = json["response"] as? String { extracted = responseVal }
                                else if let replyVal = json["reply"] as? String { extracted = replyVal }
                                else if let messageVal = json["message"] as? String { extracted = messageVal }
                                else if let contentVal = json["content"] as? String { extracted = contentVal }
                                else if let textVal = json["text"] as? String { extracted = textVal }
                                else if let outputVal = json["output"] as? String { extracted = outputVal }
                                else if let choices = json["choices"] as? [[String: Any]],
                                   let firstChoice = choices.first,
                                   let msgDict = firstChoice["message"] as? [String: Any],
                                   let contentVal = msgDict["content"] as? String {
                                    extracted = contentVal
                                } else {
                                    for (_, value) in json {
                                        if let str = value as? String {
                                            extracted = str
                                            break
                                        }
                                    }
                                }
                                
                                if let extracted = extracted {
                                    if extracted == "Message sent successfully" {
                                        return "Message sent successfully! 🚀\n\n您的消息已成功投递至 Poke。Poke 助理将会直接在您的绑定渠道（如 iMessage / SMS / WhatsApp / Telegram）中为您发送并同步该条回复。"
                                    }
                                    return extracted
                                }
                            }
                            if let plainText = String(data: data, encoding: .utf8) {
                                let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed == "Message sent successfully" {
                                    return "Message sent successfully! 🚀\n\n您的消息已成功投递至 Poke。Poke 助理将会直接在您的绑定渠道（如 iMessage / SMS / WhatsApp / Telegram）中为您发送并同步该条回复。"
                                }
                                return trimmed
                            }
                            return nil
                        }
                        
                        if let reply = parsePokeResponse(data) {
                            continuation.yield(.textContent(reply))
                        } else {
                            throw AIProviderError.apiError("Empty response body")
                        }
                        continuation.finish()
                        return
                    }
                    
                    let urlRequest: URLRequest
                    
                    if providerType == .anthropic {
                        let endpoint = cleanBaseURL.hasSuffix("/") ? cleanBaseURL + "v1/messages" : cleanBaseURL + "/v1/messages"
                        guard let url = URL(string: endpoint) else { throw AIProviderError.invalidURL }
                        
                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.setValue(capturedApiKey, forHTTPHeaderField: "x-api-key")
                        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                        
                        let anthropicMessages = buildAnthropicMessages(messages)
                        var payload: [String: Any] = [
                            "model": model,
                            "messages": anthropicMessages,
                            "max_tokens": 4096,
                            "stream": true
                        ]
                        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
                            payload["system"] = systemPrompt
                        }
                        if let temp = temperature {
                            payload["temperature"] = temp
                        }
                        if let tp = topP {
                            payload["top_p"] = tp
                        }
                        
                        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
                        urlRequest = request
                    } else {
                        let endpoint: String
                        if cleanBaseURL.hasSuffix("chat/completions") {
                            endpoint = cleanBaseURL
                        } else {
                            endpoint = cleanBaseURL.hasSuffix("/") ? cleanBaseURL + "chat/completions" : cleanBaseURL + "/chat/completions"
                        }
                        
                        guard let url = URL(string: endpoint) else { throw AIProviderError.invalidURL }
                        
                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        
                        if providerType != .ollama && !capturedApiKey.isEmpty {
                            request.setValue("Bearer \(capturedApiKey)", forHTTPHeaderField: "Authorization")
                            if providerType == .mimo {
                                request.setValue(capturedApiKey, forHTTPHeaderField: "api-key")
                            }
                        }
                        
                        let openAIMessages = buildOpenAIMessages(messages, systemPrompt: systemPrompt)
                        
                        var payload: [String: Any] = [
                            "model": model,
                            "messages": openAIMessages,
                            "stream": true,
                            "temperature": temperature ?? 0.6
                        ]
                        if let tp = topP {
                            payload["top_p"] = tp
                        }
                        if let pp = presencePenalty {
                            payload["presence_penalty"] = pp
                        }
                        if let fp = frequencyPenalty {
                            payload["frequency_penalty"] = fp
                        }
                        
                        let isReasoningModel = model.lowercased().contains("reasoner") || model.lowercased().contains("thinking") || model.lowercased().contains("think") || model.lowercased().contains("r1")
                        if let tools = tools, !tools.isEmpty && !isReasoningModel {
                            var toolsArray: [[String: Any]] = []
                            for tool in tools {
                                var toolDict: [String: Any] = [
                                    "type": tool.type
                                ]
                                let parametersData = tool.function.parametersJSON.data(using: .utf8) ?? Data()
                                let parametersObj = (try? JSONSerialization.jsonObject(with: parametersData)) ?? [String: Any]()
                                toolDict["function"] = [
                                    "name": tool.function.name,
                                    "description": tool.function.description,
                                    "parameters": parametersObj
                                ]
                                toolsArray.append(toolDict)
                            }
                            payload["tools"] = toolsArray
                        }
                        
                        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
                        urlRequest = request
                    }
                    
                    let session = SmartProxyManager.makeSession(for: urlRequest.url?.absoluteString ?? "")
                    var bytesAndResponse: (URLSession.AsyncBytes, URLResponse)? = nil
                    do {
                        bytesAndResponse = try await session.bytes(for: urlRequest)
                    } catch {
                        LoggerService.shared.warning("Proxy chat stream failed: \(error). Falling back to direct connection...")
                        bytesAndResponse = try await URLSession.shared.bytes(for: urlRequest)
                    }
                    
                    guard let (bytes, response) = bytesAndResponse else {
                        throw AIProviderError.apiError("Failed to connect to stream")
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line + "\n"
                        }
                        throw AIProviderError.apiError("HTTP \(statusCode): \(errorBody)")
                    }
                    
                    var currentThinking = ""
                    var currentContent = ""
                    var currentToolCallsByIndex: [Int: (id: String, name: String, arguments: String)] = [:]
                    var isInsideThinkingTag = false
                    
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }
                        
                        if trimmed.hasPrefix("data: ") {
                            let jsonString = String(trimmed.dropFirst(6))
                            if jsonString == "[DONE]" {
                                break
                            }
                            
                            guard let data = jsonString.data(using: .utf8) else { continue }
                            
                            if providerType == .anthropic {
                                if let anthropicEvent = try? JSONDecoder().decode(AnthropicStreamEvent.self, from: data) {
                                    switch anthropicEvent.type {
                                    case "content_block_delta":
                                        if let text = anthropicEvent.delta?.text {
                                            currentContent += text
                                            if enableThinking {
                                                let (cleanText, thinkingPart) = parseIncrementalThinking(text: text, isInside: &isInsideThinkingTag)
                                                if !thinkingPart.isEmpty {
                                                    continuation.yield(.thinkingContent(thinkingPart))
                                                }
                                                if !cleanText.isEmpty {
                                                    continuation.yield(.textContent(cleanText))
                                                }
                                            } else {
                                                continuation.yield(.textContent(text))
                                            }
                                        }
                                    default:
                                        break
                                    }
                                }
                            } else {
                                if let streamResponse = try? JSONDecoder().decode(NVIDIAStreamResponseV2.self, from: data),
                                   let choice = streamResponse.choices.first {
                                    let delta = choice.delta
                                    
                                    if let reasoning = delta.reasoningContent, !reasoning.isEmpty {
                                        currentThinking += reasoning
                                        continuation.yield(.thinkingContent(reasoning))
                                    }
                                    
                                    if let content = delta.content, !content.isEmpty {
                                        currentContent += content
                                        if enableThinking && delta.reasoningContent == nil {
                                            let (cleanText, thinkingPart) = parseIncrementalThinking(text: content, isInside: &isInsideThinkingTag)
                                            if !thinkingPart.isEmpty {
                                                continuation.yield(.thinkingContent(thinkingPart))
                                            }
                                            if !cleanText.isEmpty {
                                                continuation.yield(.textContent(cleanText))
                                            }
                                        } else {
                                            continuation.yield(.textContent(content))
                                        }
                                    }
                                    
                                    if let toolCalls = delta.toolCalls {
                                        for tc in toolCalls {
                                            let idx = tc.index ?? 0
                                            if currentToolCallsByIndex[idx] == nil {
                                                currentToolCallsByIndex[idx] = (
                                                    id: tc.id ?? "tc_\(idx)",
                                                    name: tc.function.name ?? "",
                                                    arguments: tc.function.arguments ?? ""
                                                )
                                            } else {
                                                if let newArgs = tc.function.arguments {
                                                    currentToolCallsByIndex[idx]?.arguments += newArgs
                                                }
                                                if let newId = tc.id {
                                                    currentToolCallsByIndex[idx]?.id = newId
                                                }
                                                if let newName = tc.function.name, !newName.isEmpty {
                                                    currentToolCallsByIndex[idx]?.name = newName
                                                }
                                            }
                                        }
                                    }
                                    
                                    if let finishReason = choice.finishReason {
                                        if finishReason == "tool_calls" || finishReason == "function_call" {
                                            for (_, tc) in currentToolCallsByIndex {
                                                continuation.yield(.toolCall(id: tc.id, name: tc.name, arguments: tc.arguments))
                                            }
                                            currentToolCallsByIndex.removeAll()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Message Helpers
    
    private func buildOpenAIMessages(_ messages: [ChatMessage], systemPrompt: String?) -> [[String: Any]] {
        var result: [[String: Any]] = []
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            result.append(["role": "system", "content": systemPrompt])
        }
        
        for message in messages {
            if message.isAgentStep { continue }
            result.append([
                "role": message.role,
                "content": message.content
            ])
        }
        return result
    }
    
    private func buildAnthropicMessages(_ messages: [ChatMessage]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        for message in messages {
            if message.isAgentStep { continue }
            let role = message.role == "assistant" ? "assistant" : "user"
            result.append([
                "role": role,
                "content": message.content
            ])
        }
        return result
    }
    
    // MARK: - Incremental Think Parser
    
    private func parseIncrementalThinking(text: String, isInside: inout Bool) -> (cleanText: String, thinkingPart: String) {
        var clean = ""
        var think = ""
        var remaining = text
        
        while !remaining.isEmpty {
            if isInside {
                if let endRange = remaining.range(of: "</think>") {
                    let inner = remaining[..<endRange.lowerBound]
                    think += inner
                    isInside = false
                    remaining = String(remaining[endRange.upperBound...])
                } else {
                    think += remaining
                    remaining = ""
                }
            } else {
                if let startRange = remaining.range(of: "<think>") {
                    let before = remaining[..<startRange.lowerBound]
                    clean += before
                    isInside = true
                    remaining = String(remaining[startRange.upperBound...])
                } else {
                    clean += remaining
                    remaining = ""
                }
            }
        }
        
        return (clean, think)
    }
}

// MARK: - Models

enum UniversalStreamEvent: Sendable {
    case thinkingContent(String)
    case textContent(String)
    case toolCall(id: String, name: String, arguments: String)
}

// MARK: - Anthropic Codable Models

struct AnthropicStreamEvent: Codable {
    let type: String
    let delta: AnthropicDelta?
}

struct AnthropicDelta: Codable {
    let type: String?
    let text: String?
}

// MARK: - OpenAI/NVIDIA Models V2

struct NVIDIAModelsResponse: Codable {
    let data: [NVIDIAModel]
}

struct NVIDIAModel: Codable {
    let id: String
}

struct NVIDIAStreamResponseV2: Codable {
    let choices: [NVIDIAStreamChoiceV2]
}

struct NVIDIAStreamChoiceV2: Codable {
    let delta: NVIDIAStreamDeltaV2
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

struct NVIDIAStreamDeltaV2: Codable {
    let content: String?
    let reasoningContent: String?
    let toolCalls: [NVIDIAToolCallV2]?

    enum CodingKeys: String, CodingKey {
        case content
        case reasoningContent = "reasoning_content"
        case toolCalls = "tool_calls"
    }
}

struct NVIDIAToolCallV2: Codable {
    let index: Int?
    let id: String?
    let type: String?
    let function: NVIDIAToolCallFunctionV2
}

struct NVIDIAToolCallFunctionV2: Codable {
    let name: String?
    let arguments: String?
}

// MARK: - Legacy Compatibility Stub
// 为确保 Xcode project.pbxproj 的文件引用可以正常定位 NVIDIAProvider，我们提供兼容性包装
typealias NVIDIAProvider = UniversalLLMProvider
typealias NVIDIAStreamEvent = UniversalStreamEvent
