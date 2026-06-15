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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .petCompanion: return "宠物陪伴"
        case .aiAssistant: return "Yumiko Claw"
        }
    }

    var icon: String {
        switch self {
        case .petCompanion: return "🐰"
        case .aiAssistant: return "🌱"
        }
    }

    var description: String {
        switch self {
        case .petCompanion:
            return "以宠物身份陪伴您，带有情感交互和人设记忆"
        case .aiAssistant:
            return "Stay Human, Stay Strong — 拆解认知工具、守护身心完整性，支持深度思考、联网搜索与 Agent 模式"
        }
    }
}
