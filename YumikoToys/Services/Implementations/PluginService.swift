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
    
    private var defaultPresetPlugins: [YumiPlugin] {
        [
            YumiPlugin(
                id: "quick_launch",
                name: "快速启动应用",
                icon: "rocket",
                description: "通过自研 YumiScript 脚本一键启动常用 macOS 开发或办公应用程序",
                isEnabled: true,
                scriptContent: """
                # 启动内置 Terminal 终端
                launch Terminal
                # 等待一秒
                wait 1.0
                notify "快速启动" "Terminal 终端已成功拉起！"
                """
            ),
            YumiPlugin(
                id: "screen_media",
                name: "截图与录屏助手",
                icon: "camera.viewfinder",
                description: "执行屏幕截图或指定时长的快速屏幕录制，自动化保存至桌面",
                isEnabled: true,
                scriptContent: """
                # 一键截全屏，自动保存到桌面（按当前时间戳命名）
                # 不带参数 = 使用默认桌面路径 + screencapture 退出码 0 才算成功
                screenshot
                wait 0.3
                # 弹一条通知告诉用户结果
                notify "截图插件" "桌面已生成最新截图（如未生成，请到 系统设置 → 隐私与安全性 → 屏幕录制 授予权限）。"
                """
            ),
            YumiPlugin(
                id: "terminal_tool",
                name: "终端指令执行插件",
                icon: "terminal",
                description: "通过 YumiScript 提供的 shell 指令执行自定义终端 Shell 指令并输出结果",
                isEnabled: true,
                scriptContent: """
                # 执行 Shell 命令
                shell echo "Hello from YumikoToys Terminal Plugin!"
                """
            ),
            YumiPlugin(
                id: "text_tools",
                name: "文本处理工具",
                icon: "text.badge.star",
                description: "快速统计剪贴板文本字数、转换大小写、去除多余空格等文本处理操作",
                isEnabled: true,
                scriptContent: """
                # 获取剪贴板文本并统计字数
                shell pbpaste | wc -c | xargs -I{} echo "当前剪贴板字符数: {}"
                notify "文本工具" "已统计剪贴板文本字数"
                """
            ),
            YumiPlugin(
                id: "network_status",
                name: "网络状态检测",
                icon: "wifi",
                description: "快速检测当前 Wi-Fi 连接状态与网络延迟，并显示通知结果",
                isEnabled: true,
                scriptContent: """
                # 检测网络连通性
                shell ping -c 1 -t 2 8.8.8.8 > /dev/null 2>&1 && echo "网络正常" || echo "网络异常"
                notify "网络检测" "网络状态检测完成"
                """
            ),
            YumiPlugin(
                id: "process_monitor",
                name: "进程监控",
                icon: "cpu",
                description: "快速查看当前 CPU 占用最高的前 5 个进程，输出至运行日志",
                isEnabled: true,
                scriptContent: """
                # 查看 CPU 占用前 5
                shell ps -Ao pid,pcpu,comm -r | head -6
                notify "进程监控" "已获取 CPU 占用前 5 进程"
                """
            ),
            YumiPlugin(
                id: "disk_analyzer",
                name: "磁盘空间分析",
                icon: "internaldrive",
                description: "快速显示当前磁盘使用情况（总量/已用/可用）并通过通知展示结果",
                isEnabled: true,
                scriptContent: """
                # 磁盘空间分析
                shell df -h / | tail -1 | awk '{print "磁盘: 总量" $2 " 已用" $3 " 可用" $4}'
                notify "磁盘分析" "已完成磁盘空间分析"
                """
            ),
            YumiPlugin(
                id: "clipboard_history",
                name: "剪贴板快捷",
                icon: "doc.on.clipboard",
                description: "将当前日期时间复制到剪贴板，或清除剪贴板内容",
                isEnabled: true,
                scriptContent: """
                # 将当前时间复制到剪贴板
                shell date '+%Y-%m-%d %H:%M:%S' | tr -d '\n' | pbcopy
                notify "剪贴板" "当前时间已复制到剪贴板"
                """
            ),
            YumiPlugin(
                id: "finder_quick",
                name: "Finder 快速操作",
                icon: "folder.badge.gearshape",
                description: "快速打开桌面文件夹、清理废纸篓或在 Finder 中显示当前用户目录",
                isEnabled: true,
                scriptContent: """
                # 打开桌面文件夹
                launch Finder
                shell open ~/Desktop
                notify "Finder" "已在 Finder 中打开桌面"
                """
            )
        ]
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
