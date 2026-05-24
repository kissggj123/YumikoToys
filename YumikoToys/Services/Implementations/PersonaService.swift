//
//  PersonaService.swift
//  YumikoToys
//
//  宠物人设生成服务
//

import Foundation

final class PersonaService: PersonaServiceProtocol {

    var serviceName: String { "PersonaService" }

    private let dataStorageService: DataStorageService
    private let glmService: GLMServiceProtocol

    init(dataStorageService: DataStorageService, glmService: GLMServiceProtocol) {
        self.dataStorageService = dataStorageService
        self.glmService = glmService
    }

    func initialize() async {
        LoggerService.shared.info("PersonaService initialized")
    }

    func generatePersona(for anniversary: Anniversary) async throws -> PetPersona {
        let prompt = buildPersonaPrompt(for: anniversary)

        let response = try await glmService.sendMessage(prompt, context: [], saveToHistory: false)

        guard let persona = parsePersonaResponse(response, anniversaryId: anniversary.id.uuidString) else {
            throw PersonaError.parseFailed
        }

        await savePersona(persona)
        return persona
    }

    // 【新增】带记忆融合的重新生成
    func regeneratePersonaWithMemory(oldPersona: PetPersona, anniversary: Anniversary) async throws -> PetPersona {
        // 构建包含历史记忆的提示词
        let prompt = buildMemoryPrompt(oldPersona: oldPersona, anniversary: anniversary)
        let response = try await glmService.sendMessage(prompt, context: [], saveToHistory: false)

        guard let persona = parsePersonaResponse(response, anniversaryId: anniversary.id.uuidString) else {
            throw PersonaError.parseFailed
        }

        // 融合历史记忆：创建带历史的新 persona
        let newPersona = PetPersona(
            anniversaryId: anniversary.id.uuidString,
            characterName: persona.characterName,
            tagline: persona.tagline,
            personality: persona.personality,
            greeting: persona.greeting,
            speakingStyle: persona.speakingStyle,
            background: persona.background,
            traits: persona.traits,
            avatar: persona.avatar,
            createdAt: oldPersona.createdAt,
            lastRegeneratedAt: Date(),
            memoryHistory: [
                PersonaMemory(
                    id: UUID(),
                    regeneratedAt: Date(),
                    previousTraits: oldPersona.traits,
                    conversationHighlights: []
                )
            ]
        )

        await savePersona(newPersona)
        LoggerService.shared.info("Persona regenerated with memory fusion")
        return newPersona
    }

    func getPersona(for anniversaryId: String) async -> PetPersona? {
        let path = "persona/\(anniversaryId).json"
        return await dataStorageService.load(PetPersona.self, from: path)
    }

    func deletePersona(for anniversaryId: String) async {
        let path = "persona/\(anniversaryId).json"
        let emptyPersona = PetPersona.empty(for: anniversaryId)
        await dataStorageService.save(emptyPersona, to: path)
    }

    // MARK: - Private

    private func buildPersonaPrompt(for anniversary: Anniversary) -> String {
        let genderSymbol = anniversary.petGender?.emoji ?? "❓"
        let species = anniversary.species ?? "未知"
        let birthday = formatDate(anniversary.startDate)

        return """
        你是一个人设生成器。基于以下宠物档案，生成一个完整的人设设定。

        【宠物档案】
        - 名字：\(anniversary.displayPetName)
        - 种类：\(species)
        - 性别：\(genderSymbol)
        - 头像：\(anniversary.displayAvatar)
        - 生日：\(birthday)

        请生成JSON格式的人设（仅生成JSON，不要其他内容）：
        {
            "characterName": "角色名（基于原名发挥，1-2个字可爱风格）",
            "tagline": "一句话简介",
            "personality": "性格描述（2-3句话）",
            "greeting": "开场白（用*包裹动作描写*）",
            "speakingStyle": "说话风格（如：活泼可爱/温柔体贴/傲娇等）",
            "background": "简短背景故事（1句话）",
            "traits": ["特点1", "特点2", "特点3"]
        }
        """
    }

    private func parsePersonaResponse(_ response: String, anniversaryId: String) -> PetPersona? {
        var jsonString = response

        if let range = response.range(of: "{"),
           let endRange = response.range(of: "}", options: .backwards) {
            // 【修复】确保 range 有效，避免越界崩溃
            let startIndex = range.lowerBound
            let endIndex = endRange.upperBound
            guard startIndex <= endIndex else {
                LoggerService.shared.warning("Invalid JSON range in persona response")
                return nil
            }
            jsonString = String(response[startIndex..<endIndex])
        }

        guard let data = jsonString.data(using: .utf8) else { return nil }

        do {
            let decoder = JSONDecoder()
            var persona = try decoder.decode(PetPersona.self, from: data)
            persona = PetPersona(
                anniversaryId: anniversaryId,
                characterName: persona.characterName.isEmpty ? "可可" : persona.characterName,
                tagline: persona.tagline,
                personality: persona.personality,
                greeting: persona.greeting,
                speakingStyle: persona.speakingStyle,
                background: persona.background,
                traits: persona.traits,
                avatar: persona.avatar.isEmpty ? "🐾" : persona.avatar,
                createdAt: Date(),
                lastRegeneratedAt: Date(),
                memoryHistory: []
            )
            return persona
        } catch {
            LoggerService.shared.error("Persona parse error: \(error)")
            return nil
        }
    }

    private func savePersona(_ persona: PetPersona) async {
        let path = "persona/\(persona.anniversaryId).json"
        await dataStorageService.save(persona, to: path)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // 【新增】构建带记忆的提示词
    private func buildMemoryPrompt(oldPersona: PetPersona, anniversary: Anniversary) -> String {
        let genderSymbol = anniversary.petGender?.emoji ?? "❓"
        let species = anniversary.species ?? "未知"
        let birthday = formatDate(anniversary.startDate)

        let memoryContext = oldPersona.memoryHistory.isEmpty ? "首次生成" : "基于历史人设进行演化"

        return """
        你是一个人设演化生成器。基于以下宠物档案和历史人设，生成一个进化后的人设设定。

        【宠物档案】
        - 名字：\(anniversary.displayPetName)
        - 种类：\(species)
        - 性别：\(genderSymbol)
        - 头像：\(anniversary.displayAvatar)
        - 生日：\(birthday)

        【历史人设】（请保留其中的优秀特点）
        - 角色名：\(oldPersona.characterName)
        - 性格：\(oldPersona.personality)
        - 说话风格：\(oldPersona.speakingStyle)
        - 特点：\(oldPersona.traits.joined(separator: "、"))

        请生成JSON格式的人设（仅生成JSON，\(memoryContext)）：
        {
            "characterName": "角色名（可保持原名或微调）",
            "tagline": "一句话简介",
            "personality": "性格描述（2-3句话）",
            "greeting": "开场白（用*包裹动作描写*）",
            "speakingStyle": "说话风格",
            "background": "简短背景故事（1句话）",
            "traits": ["特点1", "特点2", "特点3"]
        }
        """
    }
}

enum PersonaError: Error {
    case parseFailed
    case generationFailed
}
