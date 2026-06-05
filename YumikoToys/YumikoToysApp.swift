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
        Task { @MainActor in
            await initializeApp()
            
            let settings = DependencyContainer.shared.settingsService.settings
            let isAutoLaunch = launchedAsLogInItem
            
            if isAutoLaunch {
                if settings.showMainWindowOnAutoLaunch {
                    showMainWindow()
                }
            } else {
                if settings.showMainWindowOnManualLaunch {
                    showMainWindow()
                }
            }
        }
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
                if let data = argsStr.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    arguments = dict
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
    private var launchedAsLogInItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            return false
        }
        // eventID 'oapp' = 0x6f617070, eventClass 'aevt' = 0x61657674
        let isOapp = event.eventClass == 0x61657674 && event.eventID == 0x6f617070
        guard isOapp else { return false }
        
        // keyAEPropData 'prpt' = 0x70727074
        if let propData = event.paramDescriptor(forKeyword: 0x70727074) {
            // 'lgin' = 0x6c67696e
            return propData.enumCodeValue == 0x6c67696e
        }
        return false
    }
    
    nonisolated func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
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
    
    // MARK: - Initialization
    
    private func initializeApp() async {
        LoggerService.shared.info("Application starting...")
        
        // 注册可爱字体
        FontManager.shared.registerFonts()
        
        // 先显示 UI，让用户立即看到界面
        setupUI()
        
        // 标记初始化完成（UI 已就绪）
        AppState.shared.markInitialized()
        
        // 后台并行初始化所有服务
        await DependencyContainer.shared.initialize()
        
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
