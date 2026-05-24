//
//  SettingsMigrationService.swift
//  YumikoToys
//
//  设置迁移服务 - 处理旧格式到新格式的迁移
//

import Foundation

/// 设置迁移服务
@MainActor
final class SettingsMigrationService {
    
    // MARK: - Properties
    
    private let storageService: StorageServiceProtocol
    private let currentVersion = 2  // 当前设置格式版本
    private let versionKey = "yumikotoys.settingsVersion"
    
    // MARK: - Initialization
    
    init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }
    
    // MARK: - Migration
    
    /// 检查并执行迁移
    func migrateIfNeeded() async {
        let storedVersion = storageService.load(forKey: versionKey) ?? 1
        
        guard storedVersion < currentVersion else {
            LoggerService.shared.debug("Settings up to date (version \(storedVersion))")
            return
        }
        
        LoggerService.shared.info("Migrating settings from version \(storedVersion) to \(currentVersion)")
        
        // 执行迁移步骤
        for version in storedVersion..<currentVersion {
            await migrate(from: version, to: version + 1)
        }
        
        // 更新版本号
        storageService.save(currentVersion, forKey: versionKey)
        LoggerService.shared.info("Settings migration completed")
    }
    
    // MARK: - Private Migration Steps
    
    private func migrate(from: Int, to: Int) async {
        LoggerService.shared.info("Migrating from version \(from) to \(to)")
        
        switch (from, to) {
        case (1, 2):
            await migrateV1ToV2()
        default:
            LoggerService.shared.warning("Unknown migration path: \(from) -> \(to)")
        }
    }
    
    /// 迁移 V1 -> V2
    /// - 添加组件布局配置
    /// - 添加 NTP 配置（保留用户已有设置）
    /// - 添加字体配置
    private func migrateV1ToV2() async {
        LoggerService.shared.info("Performing V1 -> V2 migration")

        // 首先尝试加载现有设置（可能已经是 V2 格式）
        if let existingSettings: AppSettings = storageService.load(forKey: "yumikotoys.settings") {
            // 设置已经是 V2 格式，只需初始化组件布局
            LoggerService.shared.info("Settings already in V2 format, preserving user preferences")
        } else if let oldSettings: OldAppSettingsV1 = storageService.load(forKey: "yumikotoys.settings") {
            // 迁移旧版设置到新版 AppSettings
            var newSettings = AppSettings.default

            // 保留旧设置值
            newSettings.currentMode = oldSettings.currentMode
            newSettings.isPreventSleepEnabled = oldSettings.isPreventSleepEnabled
            newSettings.isLaunchAtLoginEnabled = oldSettings.isLaunchAtLoginEnabled
            newSettings.showStatusBarIcon = oldSettings.showStatusBarIcon
            newSettings.activeAnniversaryId = oldSettings.activeAnniversaryId

            // 检查是否有独立的 NTP 配置存储（用户可能之前设置过）
            if let savedNTP: NTPConfiguration = storageService.load(forKey: "yumikotoys.ntpConfiguration") {
                newSettings.ntpConfiguration = savedNTP
                LoggerService.shared.info("Preserved existing NTP configuration from separate storage")
            }
            // 否则使用默认 NTP 配置（阿里云），但用户可以在设置中更改

            // 保存新版设置
            storageService.save(newSettings, forKey: "yumikotoys.settings")
            LoggerService.shared.info("Migrated old settings to new format")
        }

        // 初始化默认组件布局
        let defaultLayouts = ComponentLayout.defaultLayout
        storageService.save(defaultLayouts, forKey: "yumikotoys.componentLayouts")
        LoggerService.shared.info("Initialized default component layouts")
    }
}

// MARK: - Old Settings V1

/// 旧版应用设置 V1（用于迁移）
private struct OldAppSettingsV1: Codable {
    var currentMode: AppMode
    var isPreventSleepEnabled: Bool
    var isLaunchAtLoginEnabled: Bool
    var showStatusBarIcon: Bool
    var activeAnniversaryId: UUID?
}
