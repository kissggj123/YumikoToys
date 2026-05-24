//
//  PetPersonaTests.swift
//  YumikoToysTests
//

import XCTest
@testable import YumikoToys

final class PetPersonaTests: XCTestCase {

    func testEmptyPersonaCreation() {
        let persona = PetPersona.empty(for: "test-id")
        XCTAssertEqual(persona.anniversaryId, "test-id")
        XCTAssertEqual(persona.characterName, "")
        XCTAssertEqual(persona.avatar, "🐾")
    }

    func testPersonaEncoding() throws {
        let persona = PetPersona(
            anniversaryId: "id-123",
            characterName: "可可",
            tagline: "可爱小兔",
            personality: "活泼可爱",
            greeting: "你好呀！",
            speakingStyle: "撒娇型",
            background: "来自兔兔王国",
            traits: ["爱萝卜", "耳朵会动"],
            avatar: "🐰",
            createdAt: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(persona)
        let decoded = try JSONDecoder().decode(PetPersona.self, from: data)

        XCTAssertEqual(decoded.characterName, "可可")
        XCTAssertEqual(decoded.avatar, "🐰")
        XCTAssertEqual(decoded.traits.count, 2)
    }
}
