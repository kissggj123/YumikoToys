//
//  UserAvatarServiceProtocol.swift
//  YumikoToys
//

import Foundation

protocol UserAvatarServiceProtocol {
    var serviceName: String { get }
    func initialize() async
    func getCurrentAvatar() -> UserAvatar
    func setMode(_ mode: UserAvatarMode)
    func setCustomImage(_ imageData: Data) async throws -> String
    func generateRandomPixelEmoji() -> String
    func shouldRefreshOnPetSwitch() -> Bool
    func refreshRandomOnPetSwitch()
}

enum UserAvatar {
    case pixelEmoji(String)
    case customImage(String)

    var emoji: String? {
        if case .pixelEmoji(let e) = self { return e }
        return nil
    }

    var imagePath: String? {
        if case .customImage(let p) = self { return p }
        return nil
    }
}
