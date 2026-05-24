//
//  AgentService.swift
//  YumikoToys
//
//  Agent 多步骤推理服务（v3.2.0 - 标准 JSON 序列化加固与数据安全防灾版）
//

import Foundation

/// Agent 事件
enum AgentEvent: Sendable {
    case thinkingContent(String)
    case textContent(String)
    case toolCallStart(name: String, arguments: String)
    case toolCallResult(name: String, result: String)
    case error(String)
    case done
}

/// Agent 工具定义
struct AgentToolDefinition: Codable, Sendable {
    let type: String
    let function: AgentFunction

    init(name: String, description: String, parameters: [String: Any]) {
        self.type = "function"
        // 将 JSON Schema 序列化为字符串存储
        let jsonString: String
        if let data = try? JSONSerialization.data(withJSONObject: parameters, options: []),
           let str = String(data: data, encoding: .utf8) {
            jsonString = str
        } else {
            jsonString = "{}"
        }
        self.function = AgentFunction(
            name: name,
            description: description,
            parametersJSON: jsonString
        )
    }
}

struct AgentFunction: Codable, Sendable {
    let name: String
    let description: String
    let parametersJSON: String

    /// 解码为字典（用于 API 请求）
    var parametersDict: [String: Any]? {
        guard let data = parametersJSON.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}

/// Agent 工具调用
struct AgentToolCall: Codable, Sendable {
    let id: String
    let type: String
    let function: AgentToolCallFunction
}

struct AgentToolCallFunction: Codable, Sendable {
    let name: String
    let arguments: String
}

/// Agent 服务
@MainActor
final class AgentService {
    private let nvidiaProvider = UniversalLLMProvider()
    private var unifiedSearchService: UnifiedSearchService?
    private let fileService: AgentFileService

    /// 最大推理轮次
    private let maxIterations = 10

    init(dataStorage: DataStorageService) {
        self.fileService = AgentFileService(dataStorage: dataStorage)
        // 初始化时拉取默认配置，后续在调用时进行热重构同步
        let config = DependencyContainer.shared.settingsService.settings.assistantConfig
        self.unifiedSearchService = UnifiedSearchService(assistantConfig: config)
    }

    /// 获取内置工具定义
    func getBuiltInTools(includeWebSearch: Bool) -> [AgentToolDefinition] {
        var tools: [AgentToolDefinition] = []

        if includeWebSearch {
            tools.append(AgentToolDefinition(
                name: "web_search",
                description: "搜索互联网获取最新信息。支持中英文搜索，自动选择最优搜索引擎（Google/百度/必应）。",
                parameters: [
                    "type": "object",
                    "properties": [
                        "query": ["type": "string", "description": "搜索关键词"]
                    ],
                    "required": ["query"]
                ]
            ))
        }

        tools.append(AgentToolDefinition(
            name: "file_read",
            description: "读取沙盒目录中的文件内容。文件路径相对于 agent_workspace/ 目录。",
            parameters: [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "文件相对路径"]
                ],
                "required": ["path"]
            ]
        ))

        tools.append(AgentToolDefinition(
            name: "file_write",
            description: "在沙盒目录中创建或覆盖写入文件。",
            parameters: [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "文件相对路径"],
                    "content": ["type": "string", "description": "要写入的内容"]
                ],
                "required": ["path", "content"]
            ]
        ))

        tools.append(AgentToolDefinition(
            name: "file_list",
            description: "列出沙盒目录中的文件和子目录。",
            parameters: [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "目录相对路径，空字符串表示根目录"]
                ],
                "required": []
            ]
        ))

        tools.append(AgentToolDefinition(
            name: "file_delete",
            description: "删除沙盒目录中的文件。",
            parameters: [
                "type": "object",
                "properties": [
                    "path": ["type": "string", "description": "文件相对路径"]
                ],
                "required": ["path"]
            ]
        ))

        return tools
    }

    /// 执行工具调用
    func executeTool(name: String, arguments: String) async -> String {
        do {
            guard let argsData = arguments.data(using: .utf8),
                  let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
                return "{\"error\": \"无法解析工具参数\"}"
            }

            switch name {
            case "web_search":
                let query = args["query"] as? String ?? ""
                
                // 在每次执行 web_search 前，实时拉取并重建 UnifiedSearchService
                let currentConfig = DependencyContainer.shared.settingsService.settings.assistantConfig
                self.unifiedSearchService = UnifiedSearchService(assistantConfig: currentConfig)
                
                guard let searchService = unifiedSearchService else {
                    return "{\"error\": \"搜索服务未初始化\"}"
                }
                
                let searchResult = try await searchService.search(query: query, maxResults: 5)
                
                // 👈【核心安全重构】：弃用脆弱的手写拼接，采用标准 JSON 序列化，自动逃逸特殊字符和双引号，确保 100% 解析成功
                let formatted = searchResult.results.compactMap { result -> String? in
                    let title = result.title
                    let url = result.url
                    let snippet = result.snippet.isEmpty ? "" : String(result.snippet.prefix(200))
                    
                    let dict: [String: String] = [
                        "title": title,
                        "url": url,
                        "snippet": snippet
                    ]
                    
                    guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: []),
                          let jsonString = String(data: jsonData, encoding: .utf8) else {
                        return nil
                    }
                    return jsonString
                }
                return "[\(formatted.count)] " + formatted.joined(separator: "\n")

            case "file_read":
                let path = args["path"] as? String ?? ""
                let content = try await fileService.readFile(path)
                return String(content.prefix(50000))

            case "file_write":
                let path = args["path"] as? String ?? ""
                let content = args["content"] as? String ?? ""
                try await fileService.writeFile(path, content: content)
                
                // 👈【安全序列化】：规范输出 JSON 格式
                let responseDict: [String: Any] = ["success": true, "path": path]
                if let data = try? JSONSerialization.data(withJSONObject: responseDict, options: []),
                   let jsonStr = String(data: data, encoding: .utf8) {
                    return jsonStr
                }
                return "{\"success\": true}"

            case "file_list":
                let path = args["path"] as? String ?? ""
                let files = try await fileService.listDirectory(path)
                let formatted = files.map { "\($0.isDirectory ? "📁" : "📄") \($0.name)\($0.isDirectory ? "/" : "")" }
                return formatted.joined(separator: "\n")

            case "file_delete":
                let path = args["path"] as? String ?? ""
                try await fileService.deleteFile(path)
                
                // 👈【安全序列化】：规范输出 JSON 格式
                let responseDict: [String: Any] = ["success": true, "deleted": path]
                if let data = try? JSONSerialization.data(withJSONObject: responseDict, options: []),
                   let jsonStr = String(data: data, encoding: .utf8) {
                    return jsonStr
                }
                return "{\"success\": true}"

            default:
                return "{\"error\": \"未知工具: \(name)\"}"
            }
        } catch {
            return "{\"error\": \"\(error.localizedDescription)\"}"
        }
    }
}

// MARK: - AnyCodable

/// 简易 JSON 值包装
struct AnyCodable: Codable, Sendable {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.value = string
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool ? "true" : "false"
        } else if let int = try? container.decode(Int.self) {
            self.value = "\(int)"
        } else if let double = try? container.decode(Double.self) {
            self.value = "\(double)"
        } else {
            self.value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
