//
//  YumikoToysApp.swift
//  YumikoToys
//
//  应用入口
//

import SwiftUI

@main
struct YumikoToysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarManager: StatusBarManager?
    private var isSecondInstance = false
    
    // MARK: - Lifecycle
    
    nonisolated func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(0x4755524c), // 'GURL'
            andEventID: AEEventID(0x6775726c)        // 'gurl'
        )
    }
    
    nonisolated func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { @MainActor in
                handleIncomingURL(url)
            }
        }
    }
    
    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        let isAutoLaunch = launchedAsLogInItem
        Task { @MainActor in
            await initializeApp()
            
            let settings = DependencyContainer.shared.settingsService.settings
            
            // 检查是否允许多开
            if !settings.allowMultipleInstances {
                let runningApps = NSRunningApplication.runningApplications(
                    withBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
                )
                if runningApps.count > 1 {
                    isSecondInstance = true
                    // 通知已有实例并退出
                    DistributedNotificationCenter.default().postNotificationName(
                        Notification.Name("com.Lite.YumikoToys.ActivateExistingInstance"),
                        object: nil
                    )
                    NSApp.terminate(nil)
                    return
                }
            }
            
            // 监听激活通知
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(activateExistingInstance),
                name: Notification.Name("com.Lite.YumikoToys.ActivateExistingInstance"),
                object: nil
            )
            
            if isAutoLaunch {
                if settings.showMainWindowOnAutoLaunch {
                    LoggerService.shared.info("Auto launch: Showing main window per user setting.")
                    showMainWindow()
                } else {
                    LoggerService.shared.info("Auto launch: Skipping main window display per user setting.")
                }
            } else {
                if settings.showMainWindowOnManualLaunch {
                    LoggerService.shared.info("Manual launch: Showing main window per user setting.")
                    showMainWindow()
                } else {
                    LoggerService.shared.info("Manual launch: Skipping main window display per user setting.")
                }
            }
        }
    }
    
    @objc private func activateExistingInstance() {
        NSApp.activate(ignoringOtherApps: true)
        showMainWindow()
    }
    
    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }
        handleIncomingURL(url)
    }
    
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "yumikotoys" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        
        let action = components.queryItems?.first(where: { $0.name == "action" })?.value
        let output = components.queryItems?.first(where: { $0.name == "output" })?.value
        
        if action == "list" {
            let skills = SkillService.shared.getAllSkills()
            var listText = ""
            for skill in skills {
                listText += "\(skill.name) - \(skill.description)\n"
            }
            if let output = output {
                do {
                    try listText.write(toFile: output, atomically: true, encoding: .utf8)
                    LoggerService.shared.info("Successfully wrote list output to \(output)")
                } catch {
                    LoggerService.shared.error("Failed to write list output to \(output): \(error)")
                }
            }
        } else if action == "run" {
            let name = components.queryItems?.first(where: { $0.name == "name" })?.value
            let argsStr = components.queryItems?.first(where: { $0.name == "args" })?.value ?? "{}"
            
            guard let name = name else {
                if let output = output {
                    do {
                        try "Error: Missing skill name".write(toFile: output, atomically: true, encoding: .utf8)
                    } catch {
                        LoggerService.shared.error("Failed to write missing skill name error to \(output): \(error)")
                    }
                }
                return
            }
            
            Task {
                var arguments: [String: Any] = [:]
                if let data = argsStr.data(using: .utf8) {
                    if let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        arguments = dict
                    } else if argsStr != "{}" && !argsStr.isEmpty {
                        LoggerService.shared.warning("Skill arguments were provided but could not be parsed as [String: Any]: \(argsStr)")
                    }
                }
                
                let result = await SkillService.shared.executeSkill(name: name, arguments: arguments)
                if let output = output {
                    do {
                        try result.write(toFile: output, atomically: true, encoding: .utf8)
                        LoggerService.shared.info("Successfully wrote run result to \(output)")
                    } catch {
                        LoggerService.shared.error("Failed to write run result to \(output): \(error)")
                    }
                }
            }
        }
    }
    
    /// 检测是否为开机自启动
    private nonisolated var launchedAsLogInItem: Bool {
        // 1. 命令行参数检测（Plist / LaunchAgent / SMAppService 自动启动触发特征）
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--autostart") ||
           args.contains("-autostart") ||
           args.contains("-RegisterForSystemEvents") ||
           args.contains("--launched-at-login") ||
           args.contains("-launchedAtLogin") ||
           args.contains("LaunchAtLogin") {
            return true
        }
        
        // 2. 环境变量检测（系统的 XPC Service LoginItem 环境）
        if let xpcService = ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"],
           xpcService.lowercased().contains("login") {
            return true
        }
        
        // 3. 传统 Apple Event 检测
        if let event = NSAppleEventManager.shared().currentAppleEvent {
            let isOapp = event.eventClass == 0x61657674 && event.eventID == 0x6f617070
            if isOapp, let propData = event.paramDescriptor(forKeyword: 0x70727074) {
                return propData.enumCodeValue == 0x6c67696e
            }
        }
        
        return false
    }
    
    nonisolated func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated {
            GlobalHotkeyManager.shared.unregisterHotkey()
            DependencyContainer.shared.shutdown()
            LoggerService.shared.info("Application will terminate")
        }
    }
    
    nonisolated func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Task { @MainActor in showMainWindow() }
        }
        return true
    }
    
    nonisolated func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        
        let mainItem = NSMenuItem(title: "🐾 打开主界面", action: #selector(DockMenuHelper.showMain), keyEquivalent: "")
        mainItem.target = DockMenuHelper.shared
        menu.addItem(mainItem)
        
        let ideItem = NSMenuItem(title: "⚡ YumiScript Studio IDE (脚本编辑器)", action: #selector(DockMenuHelper.showIDE), keyEquivalent: "")
        ideItem.target = DockMenuHelper.shared
        menu.addItem(ideItem)
        
        let settingsItem = NSMenuItem(title: "⚙️ 偏好设置...", action: #selector(DockMenuHelper.showSettings), keyEquivalent: "")
        settingsItem.target = DockMenuHelper.shared
        menu.addItem(settingsItem)
        
        let aboutItem = NSMenuItem(title: "✨ 关于 YumikoToys", action: #selector(DockMenuHelper.showAbout), keyEquivalent: "")
        aboutItem.target = DockMenuHelper.shared
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "退出 YumikoToys", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        return menu
    }
    
    // MARK: - Initialization
    
    private func initializeApp() async {
        LoggerService.shared.info("Application starting...")

        // 签名环境诊断（不影响主流程）
        SigningDiagnostics.logCurrentSigningStatus()
        
        // 注册可爱字体
        FontManager.shared.registerFonts()
        
        // 先显示 UI，让用户立即看到界面
        setupUI()
        
        // 标记初始化完成（UI 已就绪）
        AppState.shared.markInitialized()
        
        // 后台并行初始化所有服务
        await DependencyContainer.shared.initialize()
        
        // Setup global hotkey for screenshot
        let preset = DependencyContainer.shared.settingsService.settings.screenshotHotkeyPreset
        GlobalHotkeyManager.shared.setupHotkey(preset: preset)
        
        // 服务初始化完成后，刷新状态栏标题（此时数据已就绪）
        statusBarManager?.refreshAfterServicesInitialized()
        
        LoggerService.shared.info("Application initialized successfully")
    }
    
    private func setupUI() {
        // 初始化状态栏（不显示主窗口）
        statusBarManager = StatusBarManager()
    }
    
    // MARK: - Window Management
    
    private func showMainWindow() {
        DependencyContainer.shared.windowManager.showWindow(.main) {
            MainView()
        }
    }
}

// MARK: - Dock 栏菜单辅助器

final class DockMenuHelper: NSObject, @unchecked Sendable {
    static let shared = DockMenuHelper()
    
    @objc func showMain() {
        Task { @MainActor in
            DependencyContainer.shared.windowManager.showWindow(.main) {
                MainView()
            }
        }
    }
    
    @objc func showIDE() {
        Task { @MainActor in
            YumiScriptIDEManager.shared.open(plugin: nil)
        }
    }
    
    @objc func showSettings() {
        Task { @MainActor in
            DependencyContainer.shared.windowManager.showWindow(.settings) {
                SettingsView()
            }
        }
    }
    
    @objc func showAbout() {
        Task { @MainActor in
            DependencyContainer.shared.windowManager.showWindow(.about) {
                AboutView()
            }
        }
    }
}
