//
//  PetPersona.swift
//  YumikoToys
//
//  宠物人设模型
//

import Foundation

/// 人设历史记忆模型
struct PersonaMemory: Codable, Identifiable {
    var id: UUID
    var regeneratedAt: Date
    var previousTraits: [String]  // 之前保留的特点
    var conversationHighlights: [String]  // 对话高光
}

struct PetPersona: Codable, Identifiable {
    var id: String { anniversaryId }
    let anniversaryId: String
    let characterName: String
    let tagline: String
    let personality: String
    let greeting: String
    let speakingStyle: String
    let background: String
    let traits: [String]
    let avatar: String
    let createdAt: Date

    // 【新增】支持24小时限制和记忆融合的字段
    var lastRegeneratedAt: Date?      // 上次重新生成时间
    var memoryHistory: [PersonaMemory] // 历史记忆列表

    static func empty(for anniversaryId: String) -> PetPersona {
        PetPersona(
            anniversaryId: anniversaryId,
            characterName: "",
            tagline: "",
            personality: "",
            greeting: "",
            speakingStyle: "",
            background: "",
            traits: [],
            avatar: "🐾",
            createdAt: Date(),
            lastRegeneratedAt: nil,
            memoryHistory: []
        )
    }

    /// 检查是否超过24小时需要重新生成
    var needsRegeneration: Bool {
        guard let lastRegenerated = lastRegeneratedAt else {
            return true  // 首次生成
        }
        let hoursSinceLastRegenerate = Date().timeIntervalSince(lastRegenerated) / 3600
        return hoursSinceLastRegenerate >= 24
    }
}
