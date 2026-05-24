//
//  UserAvatarService.swift
//  YumikoToys
//
//  用户头像服务
//

import Foundation

final class UserAvatarService: UserAvatarServiceProtocol {

    var serviceName: String { "UserAvatarService" }

    private let dataStorageService: DataStorageService
    private var settings: UserAvatarSettings = .default
    private let settingsKey = "user_avatar_settings"

    private let petEmojis = ["🐰", "🐱", "🐶", "🐹", "🐻", "🐼", "🦊", "🐸", "🐧", "🦜", "🐢", "🐟", "🦎", "🐾"]

    init(dataStorageService: DataStorageService) {
        self.dataStorageService = dataStorageService
    }

    func initialize() async {
        await loadSettings()
        LoggerService.shared.info("UserAvatarService initialized, mode: \(settings.mode.rawValue)")
    }

    func getCurrentAvatar() -> UserAvatar {
        switch settings.mode {
        case .randomPixelEmoji:
            let emoji = settings.randomSeed.map { seed in
                petEmojis[abs(seed) % petEmojis.count]
            } ?? generateRandomPixelEmoji()
            return .pixelEmoji(emoji)

        case .customImage:
            if let path = settings.customImagePath {
                return .customImage(path)
            }
            return .pixelEmoji("🐾")
        }
    }

    func setMode(_ mode: UserAvatarMode) {
        settings.mode = mode
        if mode == .randomPixelEmoji {
            settings.randomSeed = Int.random(in: 0..<10000)
        }
        Task { await saveSettings() }
    }

    func setCustomImage(_ imageData: Data) async throws -> String {
        let fileName = "avatars/user_custom.png"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)

        try imageData.write(to: url)

        settings.mode = .customImage
        settings.customImagePath = fileName
        await saveSettings()

        return fileName
    }

    func generateRandomPixelEmoji() -> String {
        let seed = settings.randomSeed ?? Int.random(in: 0..<10000)
        settings.randomSeed = seed
        Task { await saveSettings() }
        return petEmojis[abs(seed) % petEmojis.count]
    }

    func shouldRefreshOnPetSwitch() -> Bool {
        return settings.mode == .randomPixelEmoji
    }

    func refreshRandomOnPetSwitch() {
        if settings.mode == .randomPixelEmoji {
            settings.randomSeed = Int.random(in: 0..<10000)
            Task { await saveSettings() }
        }
    }

    // MARK: - Private

    private func loadSettings() async {
        if let loaded: UserAvatarSettings = await dataStorageService.load(UserAvatarSettings.self, from: settingsKey) {
            settings = loaded
        }
    }

    private func saveSettings() async {
        await dataStorageService.save(settings, to: settingsKey)
    }
}
