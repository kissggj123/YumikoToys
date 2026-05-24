//
//  PersonaServiceProtocol.swift
//  YumikoToys
//

import Foundation

protocol PersonaServiceProtocol {
    var serviceName: String { get }
    func initialize() async
    func generatePersona(for anniversary: Anniversary) async throws -> PetPersona
    func regeneratePersonaWithMemory(oldPersona: PetPersona, anniversary: Anniversary) async throws -> PetPersona
    func getPersona(for anniversaryId: String) async -> PetPersona?
    func deletePersona(for anniversaryId: String) async
}
