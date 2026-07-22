//
//  ChatMode.swift
//  YumikoToys
//
//  对话模式枚举（Pro Human 重构版）
//

import Foundation

/// 对话模式
enum ChatMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case petCompanion = "petCompanion"
    case aiAssistant = "aiAssistant"
    case universalAgent = "universalAgent"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .petCompanion: return "宠物陪伴"
        case .aiAssistant: return "Yumiko Claw"
        case .universalAgent: return "全能 Agent"
        }
    }

    var icon: String {
        switch self {
        case .petCompanion: return "🐰"
        case .aiAssistant: return "🌱"
        case .universalAgent: return "⚡"
        }
    }

    var description: String {
        switch self {
        case .petCompanion:
            return "以宠物身份陪伴您，带有情感交互和人设记忆"
        case .aiAssistant:
            return "Stay Human, Stay Strong — 拆解认知工具、守护身心完整性，支持深度思考、联网搜索与 Agent 模式"
        case .universalAgent:
            return "全能 AI 管家 — 日程管理、邮件操作、系统控制、文件分析、心理专精，所有工具随时调用"
        }
    }

    /// 是否为 Agent 类模式（共享 assistant 的 UI 框架）
    var isAgentMode: Bool {
        self == .aiAssistant || self == .universalAgent
    }

    /// 模式主题色（渐变色对）
    var themeGradient: [String] {
        switch self {
        case .petCompanion: return ["FF6B9D", "C44FE2"]     // 粉紫
        case .aiAssistant: return ["059669", "0891B2"]      // 深绿+蓝
        case .universalAgent: return ["1E3A5F", "D4A853"]   // 深蓝+金
        }
    }
}
