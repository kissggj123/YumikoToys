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
    
    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            await initializeApp()
        }
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
