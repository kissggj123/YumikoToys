//
//  ChatMode.swift
//  YumikoToys
//
//  对话模式枚举
//

import Foundation

/// 对话模式
enum ChatMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case petCompanion = "petCompanion"
    case aiAssistant = "aiAssistant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .petCompanion: return "宠物陪伴"
        case .aiAssistant: return "全能助手"
        }
    }

    var icon: String {
        switch self {
        case .petCompanion: return "🐰"
        case .aiAssistant: return "🤖"
        }
    }

    var description: String {
        switch self {
        case .petCompanion:
            return "以宠物身份陪伴您，带有情感交互和人设记忆"
        case .aiAssistant:
            return "全能 AI 助手，支持深度思考、联网搜索、Agent 模式"
        }
    }
}
