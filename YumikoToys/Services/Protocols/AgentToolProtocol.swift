//
//  AgentToolProtocol.swift
//  YumikoToys
//
//  统一 Agent 工具协议 - 标准化内置工具与自定义 Skill 的接口
//

import Foundation

/// Agent 工具参数类型
enum AgentToolParameterType: String, Codable, Sendable {
    case string
    case number
    case boolean
    case object
    case array
}

/// Agent 工具参数定义
struct AgentToolParameter: Codable, Sendable, Identifiable {
    let name: String
    let type: AgentToolParameterType
    let description: String
    let required: Bool
    let defaultValue: String?
    
    var id: String { name }
}

/// Agent 工具执行结果
struct AgentToolResult: Codable, Sendable {
    let success: Bool
    let output: String
    let error: String?
    let metadata: [String: String]?
    
    static func success(_ output: String, metadata: [String: String]? = nil) -> AgentToolResult {
        AgentToolResult(success: true, output: output, error: nil, metadata: metadata)
    }
    
    static func failure(_ error: String) -> AgentToolResult {
        AgentToolResult(success: false, output: "", error: error, metadata: nil)
    }
}

/// Agent 工具协议 - 所有内置工具和自定义 Skill 统一实现此协议
protocol AgentTool: Sendable {
    /// 工具名称（唯一标识，用于 LLM function calling）
    var name: String { get }
    
    /// 工具描述（给 LLM 理解工具用途）
    var description: String { get }
    
    /// 参数列表
    var parameters: [AgentToolParameter] { get }
    
    /// 是否需要用户确认才能执行
    var requiresConfirmation: Bool { get }
    
    /// 执行工具
    func execute(arguments: [String: Any]) async -> AgentToolResult
    
    /// 生成 OpenAI function calling 格式的 JSON schema
    func toFunctionSchema() -> [String: Any]
}

extension AgentTool {
    var requiresConfirmation: Bool { false }
    
    func toFunctionSchema() -> [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []
        
        for param in parameters {
            var prop: [String: Any] = [
                "type": param.type.rawValue,
                "description": param.description
            ]
            if let defaultVal = param.defaultValue {
                prop["default"] = defaultVal
            }
            properties[param.name] = prop
            if param.required {
                required.append(param.name)
            }
        }
        
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required
                ]
            ]
        ]
    }
}
