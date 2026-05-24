//
//  APISettingsService.swift
//  YumikoToys
//
//  API设置服务
//

import Foundation

final class APISettingsService: APISettingsServiceProtocol {

    var serviceName: String { "APISettingsService" }

    private let dataStorageService: DataStorageService
    private var settings: APISettings = .default
    private let settingsKey = "api_settings"

    init(dataStorageService: DataStorageService) {
        self.dataStorageService = dataStorageService
    }

    func initialize() async {
        await loadSettings()
        LoggerService.shared.info("APISettingsService initialized, model: \(settings.currentModel)")
    }

    func getSettings() -> APISettings {
        settings
    }

    func updateSettings(_ newSettings: APISettings) {
        settings = newSettings
        Task { await saveSettings() }
    }

    func estimateTokens(sent: String, received: String) -> (sent: Int, received: Int) {
        let sentEstimate = estimateTokenCount(sent)
        let receivedEstimate = estimateTokenCount(received)

        settings.estimatedSentTokens += sentEstimate
        settings.estimatedReceivedTokens += receivedEstimate
        Task { await saveSettings() }

        return (sentEstimate, receivedEstimate)
    }

    // MARK: - Private

    private func loadSettings() async {
        if let loaded: APISettings = await dataStorageService.load(APISettings.self, from: settingsKey) {
            settings = loaded
        }
    }

    private func saveSettings() async {
        await dataStorageService.save(settings, to: settingsKey)
    }

    private func estimateTokenCount(_ text: String) -> Int {
        var count = 0
        for char in text {
            if char.isASCII {
                count += 1
            } else {
                count += 2
            }
        }
        return count / 3
    }
}
