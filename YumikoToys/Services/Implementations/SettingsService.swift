//
//  SettingsService.swift
//  YumikoToys
//
//  设置服务实现
//

import Foundation
import Combine

/// 设置服务实现
final class SettingsService: SettingsServiceProtocol {
    
    // MARK: - Properties
    
    private(set) var settings: AppSettings = .default
    
    private var settingsSubject = CurrentValueSubject<AppSettings, Never>(.default)
    
    var settingsPublisher: AnyPublisher<AppSettings, Never> {
        settingsSubject.eraseToAnyPublisher()
    }
    
    private let storageService: StorageServiceProtocol
    private let settingsKey = "yumikotoys.settings"
    
    var serviceName: String { "SettingsService" }
    
    // MARK: - Initialization
    
    init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }
    
    // MARK: - ServiceLifecycle
    
    func initialize() async {
        loadSettings()
        LoggerService.shared.info("SettingsService initialized")
    }
    
    func start() async {
        // 服务已启动
    }
    
    func stop() {
        saveSettings()
        LoggerService.shared.info("SettingsService stopped")
    }
    
    // MARK: - SettingsServiceProtocol
    
    func updateSettings(_ settings: AppSettings) {
        self.settings = settings
        settingsSubject.send(settings)
        saveSettings()
        LoggerService.shared.debug("Settings updated")
    }
    
    func updateMode(_ mode: AppMode) {
        settings.currentMode = mode
        settingsSubject.send(settings)
        saveSettings()
        LoggerService.shared.info("Mode updated to: \(mode.displayName)")
    }
    
    func updatePreventSleep(_ enabled: Bool) {
        settings.isPreventSleepEnabled = enabled
        settingsSubject.send(settings)
        saveSettings()
        LoggerService.shared.info("Prevent sleep setting updated: \(enabled)")
    }
    
    func updateLaunchAtLogin(_ enabled: Bool) {
        settings.isLaunchAtLoginEnabled = enabled
        settingsSubject.send(settings)
        saveSettings()
        LoggerService.shared.info("Launch at login setting updated: \(enabled)")
    }
    
    // MARK: - Private Methods
    
    private func saveSettings() {
        storageService.save(settings, forKey: settingsKey)
    }
    
    private func loadSettings() {
        if let loaded: AppSettings = storageService.load(forKey: settingsKey) {
            settings = loaded
            settingsSubject.send(settings)
            LoggerService.shared.debug("Settings loaded from storage")
        }
    }
}
