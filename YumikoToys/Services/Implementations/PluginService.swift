//
//  PluginService.swift
//  YumikoToys
//
//  插件系统管理服务（v2.0.0 - 模块化、可见性控制与丰富预设版）
//

import Foundation
import Combine
import AppKit

/// 自定义插件模型
struct YumiPlugin: Codable, Identifiable, Sendable, Equatable {
    var id: String
    var name: String
    var icon: String
    var description: String
    var isEnabled: Bool
    var scriptContent: String
}

/// 快速启动应用模型
struct QuickLaunchApp: Codable, Identifiable, Sendable, Equatable {
    var id: String { name }
    var name: String
    var iconName: String?
    var bundlePath: String?
}

/// 插件系统服务
@MainActor
final class PluginService: ObservableObject {
    static let shared = PluginService()
    
    @Published var customPlugins: [YumiPlugin] = []
    @Published var quickLaunchApps: [QuickLaunchApp] = []
    
    /// 状态栏可见性控制：key 为插件 id，value 为是否在状态栏显示
    @Published var statusBarVisibility: [String: Bool] = [:]
    
    /// 是否在状态栏显示「内置快捷」功能区（截图/录屏）
    @Published var showBuiltinQuickActions: Bool = true
    
    /// 是否在状态栏显示「快速启动」功能区
    @Published var showQuickLaunchSection: Bool = true
    
    /// 是否在状态栏显示「扩展插件」功能区
    @Published var showCustomPluginsSection: Bool = true
    
    private let userDefaultsKey = "YumikoToys_CustomPlugins_v1"
    private let quickLaunchDefaultsKey = "YumikoToys_QuickLaunchApps_v1"
    private let visibilityDefaultsKey = "YumikoToys_PluginVisibility_v1"
    private let sectionVisibilityKey = "YumikoToys_SectionVisibility_v1"
    
    private init() {
        loadPlugins()
        loadQuickLaunchApps()
        loadVisibilitySettings()
        backfillMissingAppIcons()
    }
    
    // MARK: - Plugin Presets
    
    var defaultPresetPlugins: [YumiPlugin] {
        [
            YumiPlugin(
                id: "empty_trash",
                name: "清空废纸篓",
                icon: "trash.fill",
                description: "一键安全清空 macOS 废纸篓，快速释放磁盘空间",
                isEnabled: true,
                scriptContent: """
                # 安全清空废纸篓
                sys emptytrash
                notify "废纸篓已清空" "🗑️ 废纸篓已成功清空，已为您释放磁盘存储空间"
                """
            ),
            YumiPlugin(
                id: "lock_screen",
                name: "一键锁定屏幕",
                icon: "lock.shield.fill",
                description: "立即快速锁定 Mac 屏幕，离开座位时保护隐私",
                isEnabled: true,
                scriptContent: """
                # 立即锁定屏幕
                sys lock
                """
            ),
            YumiPlugin(
                id: "toggle_dark_mode",
                name: "深浅外观切换",
                icon: "circle.righthalf.filled",
                description: "在 macOS 深色外观与浅色外观之间一键快速无缝切换",
                isEnabled: true,
                scriptContent: """
                # 切换系统深色/浅色外观
                sys toggletheme
                notify "系统外观切换" "$OUTPUT"
                """
            ),
            YumiPlugin(
                id: "clean_clipboard",
                name: "剪贴板格式净化",
                icon: "doc.text.magnifyingglass",
                description: "去除剪贴板首尾多余空格、空白行与富文本格式，并统计纯文字数",
                isEnabled: true,
                scriptContent: """
                # 净化剪贴板格式并统计字数
                shell pbpaste | awk '{$1=$1};1' | pbcopy && pbpaste | wc -m | xargs -I{} echo "剪贴板文本格式已净化，共 {} 字"
                notify "剪贴板净化完成" "$OUTPUT"
                """
            ),
            YumiPlugin(
                id: "network_diagnostics",
                name: "网络与延迟诊断",
                icon: "wifi",
                description: "检测当前 Wi-Fi/内网 IP、连通性及网络延迟",
                isEnabled: true,
                scriptContent: """
                # 检测内网 IP 与 DNS 延迟
                sys ip
                notify "网络状态诊断" "$OUTPUT"
                """
            ),
            YumiPlugin(
                id: "system_status",
                name: "系统负载速查",
                icon: "cpu",
                description: "快速查看当前 CPU 占用最高的进程及系统主要负载",
                isEnabled: true,
                scriptContent: """
                # 监控当前 CPU 负载 Top 进程
                sys cpu
                notify "系统负载概览" "$OUTPUT"
                """
            ),
            YumiPlugin(
                id: "disk_analyzer",
                name: "主磁盘空间概览",
                icon: "internaldrive.fill",
                description: "快速显示当前主硬盘容量、已用空间及剩余可用百分比",
                isEnabled: true,
                scriptContent: """
                # 检查主磁盘使用情况
                sys disk
                notify "主磁盘空间" "$OUTPUT"
                """
            ),
            YumiPlugin(
                id: "purge_memory",
                name: "释放内存缓存",
                icon: "bolt.fill",
                description: "释放系统非活跃缓存与脏内存，让 Mac 运行更流畅",
                isEnabled: true,
                scriptContent: """
                # 释放系统内存缓存
                sys purge
                notify "内存优化" "⚡ 内存缓存已成功释放，系统运行更轻快"
                """
            ),
            YumiPlugin(
                id: "copy_timestamp",
                name: "复制当前时间戳",
                icon: "clock.badge.checkmark",
                description: "将标准格式的当前日期时间一键复制到剪贴板",
                isEnabled: true,
                scriptContent: """
                # 格式化日期时间并复制
                shell date "+%Y-%m-%d %H:%M:%S" | tr -d '\\n' | pbcopy
                notify "时间已复制" "📋 已将当前时间复制到剪贴板: $DATE $TIME"
                """
            ),
            YumiPlugin(
                id: "open_downloads",
                name: "打开下载目录",
                icon: "arrow.down.circle.fill",
                description: "在 Finder 中快速打开 Downloads 下载文件夹",
                isEnabled: true,
                scriptContent: """
                # 打开下载目录
                open ~/Downloads
                notify "访达快捷" "📂 已打开 Downloads 下载文件夹"
                """
            )
        ]
    }
    
    func restoreDefaultPresets() {
        self.customPlugins = defaultPresetPlugins
        savePlugins()
    }
    
    func loadPlugins() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           var list = try? JSONDecoder().decode([YumiPlugin].self, from: data) {
            // 补充缺失的预设插件（版本升级迁移）
            for preset in defaultPresetPlugins {
                if !list.contains(where: { $0.id == preset.id }) {
                    list.append(preset)
                }
            }
            // 升级旧插件脚本内容为 v2.5 新脚本
            for preset in defaultPresetPlugins {
                if let idx = list.firstIndex(where: { $0.id == preset.id }) {
                    // 如果旧插件脚本包含老旧代码，自动无缝升级
                    if list[idx].scriptContent.contains("v1.0") || list[idx].scriptContent.contains("一键截全屏") || list[idx].id == "screen_media" {
                        list[idx] = preset
                    }
                }
            }
            self.customPlugins = list
            savePlugins()
        } else {
            self.customPlugins = defaultPresetPlugins
            savePlugins()
        }
    }
    
    func savePlugins() {
        if let data = try? JSONEncoder().encode(customPlugins) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    func addOrUpdatePlugin(_ plugin: YumiPlugin) {
        if let index = customPlugins.firstIndex(where: { $0.id == plugin.id }) {
            customPlugins[index] = plugin
        } else {
            customPlugins.append(plugin)
        }
        savePlugins()
    }
    
    func deletePlugin(id: String) {
        customPlugins.removeAll(where: { $0.id == id })
        savePlugins()
    }
    
    // MARK: - Quick Launch Persist Methods
    
    func loadQuickLaunchApps() {
        if let data = UserDefaults.standard.data(forKey: quickLaunchDefaultsKey),
           let list = try? JSONDecoder().decode([QuickLaunchApp].self, from: data) {
            self.quickLaunchApps = list
        } else {
            // Seed defaults: Terminal, Safari, Xcode
            self.quickLaunchApps = [
                QuickLaunchApp(name: "Terminal"),
                QuickLaunchApp(name: "Safari"),
                QuickLaunchApp(name: "Xcode")
            ]
            saveQuickLaunchApps()
        }
    }
    
    func saveQuickLaunchApps() {
        if let data = try? JSONEncoder().encode(quickLaunchApps) {
            UserDefaults.standard.set(data, forKey: quickLaunchDefaultsKey)
        }
    }
    
    func addQuickLaunchApp(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !quickLaunchApps.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            let (iconName, appPath) = Self.resolveAppIconInfo(for: trimmed)
            quickLaunchApps.append(QuickLaunchApp(name: trimmed, iconName: iconName, bundlePath: appPath))
            saveQuickLaunchApps()
        }
    }
    
    func backfillMissingAppIcons() {
        var updated = false
        for i in quickLaunchApps.indices {
            if quickLaunchApps[i].iconName == nil || quickLaunchApps[i].bundlePath == nil {
                let (iconName, appPath) = Self.resolveAppIconInfo(for: quickLaunchApps[i].name)
                quickLaunchApps[i].iconName = quickLaunchApps[i].iconName ?? iconName
                quickLaunchApps[i].bundlePath = quickLaunchApps[i].bundlePath ?? appPath
                updated = true
            }
        }
        // 也回退 bundlePath 有效但 iconName 为空的情况
        for i in quickLaunchApps.indices {
            if quickLaunchApps[i].iconName == nil, let path = quickLaunchApps[i].bundlePath, FileManager.default.fileExists(atPath: path) {
                if let bundle = Bundle(path: path) {
                    quickLaunchApps[i].iconName = Self.extractIconName(from: bundle)
                    updated = true
                }
            }
        }
        if updated {
            saveQuickLaunchApps()
        }
    }
    
    /// 后台异步刷新所有快速启动应用的图标
    func refreshAllAppIcons() {
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            await MainActor.run {
                for i in self.quickLaunchApps.indices {
                    let (iconName, appPath) = Self.resolveAppIconInfo(for: self.quickLaunchApps[i].name)
                    self.quickLaunchApps[i].iconName = iconName ?? self.quickLaunchApps[i].iconName
                    self.quickLaunchApps[i].bundlePath = appPath ?? self.quickLaunchApps[i].bundlePath
                }
                self.saveQuickLaunchApps()
            }
        }
    }
    
    static func resolveAppIconInfo(for appName: String) -> (iconName: String?, bundlePath: String?) {
        let searchDirs = ["/Applications", "/System/Applications", "/System/Library/CoreServices", "/Library/CoreServices"]
        
        // 1. 精确匹配：直接拼接路径
        for dir in searchDirs {
            let appPath = (dir as NSString).appendingPathComponent("\(appName).app")
            if FileManager.default.fileExists(atPath: appPath),
               let bundle = Bundle(path: appPath) {
                return (extractIconName(from: bundle), appPath)
            }
        }
        
        // 2. 扩展名变体匹配 (如 Xcode → Xcode.app)
        for dir in searchDirs {
            let appPath = (dir as NSString).appendingPathComponent("\(appName).app")
            if !FileManager.default.fileExists(atPath: appPath) {
                // 尝试带空格/特殊字符的变体
                let variants = [
                    "\(appName).app",
                    "\(appName).app",
                    appName.replacingOccurrences(of: " ", with: "").appending(".app")
                ]
                for variant in variants {
                    let path = (dir as NSString).appendingPathComponent(variant)
                    if FileManager.default.fileExists(atPath: path),
                       let bundle = Bundle(path: path) {
                        return (extractIconName(from: bundle), path)
                    }
                }
            }
        }
        
        // 3. 模糊匹配：遍历目录中的 .app 文件
        for dir in searchDirs {
            if let items = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                for item in items where item.hasSuffix(".app") {
                    let nameWithoutExt = (item as NSString).deletingPathExtension
                    if nameWithoutExt.localizedCaseInsensitiveContains(appName) || appName.localizedCaseInsensitiveContains(nameWithoutExt) {
                        let fullPath = (dir as NSString).appendingPathComponent(item)
                        if let bundle = Bundle(path: fullPath) {
                            return (extractIconName(from: bundle), fullPath)
                        }
                    }
                }
            }
        }
        
        // 4. 最终回退：使用 NSWorkspace 查找已安装应用
        let commonBundleIdentifiers = [
            "Terminal": "com.apple.Terminal",
            "Safari": "com.apple.Safari",
            "Xcode": "com.apple.dt.Xcode",
            "Finder": "com.apple.finder",
            "Notes": "com.apple.Notes",
            "Calendar": "com.apple.iCal",
            "Photos": "com.apple.Photos",
            "Music": "com.apple.Music",
            "Messages": "com.apple.MobileSMS",
            "Mail": "com.apple.mail",
            "Maps": "com.apple.Maps",
            "FaceTime": "com.apple.FaceTime",
            "System Preferences": "com.apple.systempreferences",
            "System Settings": "com.apple.systempreferences"
        ]
        if let bundleId = commonBundleIdentifiers[appName],
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let path = appURL.path
            if let bundle = Bundle(path: path) {
                return (extractIconName(from: bundle), path)
            }
        }
        
        return (nil, nil)
    }
    
    private static func extractIconName(from bundle: Bundle) -> String? {
        if let iconFiles = bundle.infoDictionary?["CFBundleIconName"] as? String, !iconFiles.isEmpty {
            return iconFiles
        }
        if let iconFilename = bundle.infoDictionary?["CFBundleIconFile"] as? String, !iconFilename.isEmpty {
            let name = (iconFilename as NSString).deletingPathExtension
            return name.isEmpty ? nil : name
        }
        return nil
    }
    
    static func resolveAppIconName(for appName: String) -> String? {
        return resolveAppIconInfo(for: appName).iconName
    }
    
    func deleteQuickLaunchApp(id: String) {
        quickLaunchApps.removeAll(where: { $0.id == id })
        saveQuickLaunchApps()
    }
    
    // MARK: - 状态栏可见性设置
    
    func loadVisibilitySettings() {
        if let data = UserDefaults.standard.data(forKey: visibilityDefaultsKey),
           let dict = try? JSONDecoder().decode([String: Bool].self, from: data) {
            self.statusBarVisibility = dict
        }
        
        if let data = UserDefaults.standard.data(forKey: sectionVisibilityKey),
           let dict = try? JSONDecoder().decode([String: Bool].self, from: data) {
            self.showBuiltinQuickActions = dict["builtin"] ?? true
            self.showQuickLaunchSection = dict["quicklaunch"] ?? true
            self.showCustomPluginsSection = dict["custom"] ?? true
        }
        
        if let raw = UserDefaults.standard.string(forKey: "YumikoToys_PluginActivePreset_v1"),
           let preset = PluginLayoutPreset(rawValue: raw) {
            self.activeLayoutPreset = preset
        } else {
            self.activeLayoutPreset = .all
        }
    }
    
    func saveVisibilitySettings() {
        if let data = try? JSONEncoder().encode(statusBarVisibility) {
            UserDefaults.standard.set(data, forKey: visibilityDefaultsKey)
        }
        let sectionDict: [String: Bool] = [
            "builtin": showBuiltinQuickActions,
            "quicklaunch": showQuickLaunchSection,
            "custom": showCustomPluginsSection
        ]
        if let data = try? JSONEncoder().encode(sectionDict) {
            UserDefaults.standard.set(data, forKey: sectionVisibilityKey)
        }
    }
    
    /// 获取指定插件在状态栏的显示状态（默认显示）
    func isVisibleInStatusBar(pluginId: String) -> Bool {
        return statusBarVisibility[pluginId] ?? true
    }
    
    /// 设置指定插件在状态栏的显示状态
    func setVisibility(pluginId: String, visible: Bool) {
        statusBarVisibility[pluginId] = visible
        saveVisibilitySettings()
    }
    
    /// 切换区域显示状态并保存
    func toggleBuiltinQuickActions() {
        showBuiltinQuickActions.toggle()
        saveVisibilitySettings()
    }
    
    func toggleQuickLaunchSection() {
        showQuickLaunchSection.toggle()
        saveVisibilitySettings()
    }
    
    func toggleCustomPluginsSection() {
        showCustomPluginsSection.toggle()
        saveVisibilitySettings()
    }
    
    // MARK: - Preset Configurations
    
    @Published var activeLayoutPreset: PluginLayoutPreset = .all
    
    func applyPreset(_ preset: PluginLayoutPreset) {
        self.activeLayoutPreset = preset
        switch preset {
        case .all:
            showBuiltinQuickActions = true
            showQuickLaunchSection = true
            showCustomPluginsSection = true
        case .onlyBuiltin:
            showBuiltinQuickActions = true
            showQuickLaunchSection = false
            showCustomPluginsSection = false
        case .onlyQuickLaunch:
            showBuiltinQuickActions = false
            showQuickLaunchSection = true
            showCustomPluginsSection = false
        case .onlyCustom:
            showBuiltinQuickActions = false
            showQuickLaunchSection = false
            showCustomPluginsSection = true
        case .hideAll:
            showBuiltinQuickActions = false
            showQuickLaunchSection = false
            showCustomPluginsSection = false
        }
        saveVisibilitySettings()
        UserDefaults.standard.set(preset.rawValue, forKey: "YumikoToys_PluginActivePreset_v1")
    }
}

enum PluginLayoutPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case all = "all"
    case onlyBuiltin = "onlyBuiltin"
    case onlyQuickLaunch = "onlyQuickLaunch"
    case onlyCustom = "onlyCustom"
    case hideAll = "hideAll"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "显示全部 (默认)"
        case .onlyBuiltin: return "仅内置快捷"
        case .onlyQuickLaunch: return "仅快速启动"
        case .onlyCustom: return "仅扩展插件"
        case .hideAll: return "全部隐藏"
        }
    }
}
