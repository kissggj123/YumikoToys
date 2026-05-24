//
//  UserAvatarSettings.swift
//  YumikoToys
//
//  用户头像设置模型
//

import Foundation

enum UserAvatarMode: String, Codable {
    case randomPixelEmoji
    case customImage
}

struct UserAvatarSettings: Codable {
    var mode: UserAvatarMode
    var customImagePath: String?
    var randomSeed: Int?

    static var `default`: UserAvatarSettings {
        UserAvatarSettings(
            mode: .randomPixelEmoji,
            customImagePath: nil,
            randomSeed: nil
        )
    }
}
