//
//  DependencyContainer.swift
//  YumikoToys
//
//  依赖注入容器（v4.2.0 - 端侧双核 MLX 推理重构与 AppKit 线程安全加固版）
//

import Foundation
import AppKit
import SwiftUI
import Combine
import UserNotifications // 引入系统通知服务

/// 依赖注入容器
@MainActor
final class DependencyContainer: ObservableObject {

    // MARK: - Singleton

    static let shared = DependencyContainer()

    // MARK: - Services

    let storageService: StorageServiceProtocol
    let dataStorageService: DataStorageService
    let anniversaryService: AnniversaryService
    let preventSleepService: PreventSleepService
    let settingsService: SettingsService
    let launchAtLoginService: LaunchAtLoginService
    let glmService: GLMService
    let windowManager: WindowManager
    let timeSyncService: TimeSyncService
    let componentLayoutService: ComponentLayoutService

    // 新增服务
    let personaService: PersonaService
    let userAvatarService: UserAvatarService
    let apiSettingsService: APISettingsService
    
    // MLX 本地 AI 服务
    let localEmbeddingService: LocalEmbeddingService
    let semanticDeduplicationService: SemanticDeduplicationService
    let localSentimentService: LocalSentimentService
    let modelDownloadManager: ModelDownloadManager
    let modelManagementService: ModelManagementService

    // 动态存储的服务（在 initialize 中创建）
    private var services: [String: Any] = [:]

    /// 后台学习服务
    var backgroundLearningService: BackgroundLearningService? {
        services["backgroundLearning"] as? BackgroundLearningService
    }

    // MARK: - Initialization

    private init() {
        // 创建基础服务（先创建无依赖的服务）
        let storage = StorageService()
        let dataStorage = DataStorageService()

        self.storageService = storage
        self.dataStorageService = dataStorage

        // 创建 TimeSyncService（AnniversaryService 依赖它）
        let timeSync = TimeSyncService()
        self.timeSyncService = timeSync

        // 创建 GLM Service（其他服务可能依赖它）
        let glm = GLMService(dataStorageService: dataStorage)
        self.glmService = glm

        // 创建依赖其他服务的服务
        self.anniversaryService = AnniversaryService(storageService: storage, timeSyncService: timeSync)
        self.preventSleepService = PreventSleepService(storageService: storage)
        self.settingsService = SettingsService(storageService: storage)
        self.launchAtLoginService = LaunchAtLoginService(storageService: storage)
        self.windowManager = WindowManager()
        self.componentLayoutService = ComponentLayoutService(
            storageService: storage,
            migrationService: SettingsMigrationService(storageService: storage)
        )

        // 创建新增服务
        self.personaService = PersonaService(dataStorageService: dataStorage, glmService: glm)
        self.userAvatarService = UserAvatarService(dataStorageService: dataStorage)
        self.apiSettingsService = APISettingsService(dataStorageService: dataStorage)
        
        // 创建 MLX 本地 AI 服务
        let embeddingService = LocalEmbeddingService()
        self.localEmbeddingService = embeddingService
        self.semanticDeduplicationService = SemanticDeduplicationService(embeddingService: embeddingService)
        self.localSentimentService = LocalSentimentService()
        self.modelDownloadManager = ModelDownloadManager()
        self.modelManagementService = ModelManagementService(
            downloadManager: modelDownloadManager,
            embeddingService: embeddingService,
            sentimentService: localSentimentService
        )
    }
    
    // MARK: - Lifecycle

    func initialize() async {
        // 第一阶段：并行初始化无依赖的基础服务
        async let storageInit = storageService.initialize()
        async let dataStorageInit = dataStorageService.initialize()
        async let settingsInit = settingsService.initialize()
        async let timeSyncInit = timeSyncService.initialize()

        await storageInit
        await dataStorageInit
        await settingsInit
        await timeSyncInit

        // 第二阶段：并行初始化依赖基础服务的服务
        async let anniversaryInit = anniversaryService.initialize()
        async let preventSleepInit = preventSleepService.initialize()
        async let launchAtLoginInit = launchAtLoginService.initialize()
        async let glmInit = glmService.initialize()
        async let layoutInit = componentLayoutService.initialize()

        await anniversaryInit
        await preventSleepInit
        await launchAtLoginInit
        await glmInit
        await layoutInit

        // 第三阶段：初始化新增服务（👈 并行加载并热装载端侧双轨深度学习推理模型）
        async let personaInit = personaService.initialize()
        async let userAvatarInit = userAvatarService.initialize()
        async let apiSettingsInit = apiSettingsService.initialize()
        async let embeddingInit = localEmbeddingService.start()
        async let dedupInit = semanticDeduplicationService.start()
        async let sentimentInit = localSentimentService.start()
        async let modelManagementInit = modelManagementService.initialize()

        await personaInit
        await userAvatarInit
        await apiSettingsInit
        await embeddingInit
        await dedupInit
        await sentimentInit
        await modelManagementInit

        // 确保在所有异步加载任务完成后重新校准模型状态
        await modelManagementService.refreshAllStatus()

        // 初始化后台学习服务
        let backgroundLearningService = BackgroundLearningService(
            dataStorageService: dataStorageService,
            glmService: glmService,
            semanticDeduplicationService: semanticDeduplicationService,
            sentimentService: localSentimentService
        )
        await backgroundLearningService.initialize()

        // 后台学习完全由设置中的独立开关控制
        let isLearningEnabled = settingsService.settings.isBackgroundLearningEnabled
        backgroundLearningService.setLearningEnabled(isLearningEnabled)

        services["backgroundLearning"] = backgroundLearningService

        // 第四阶段：启动时间同步
        await timeSyncService.start()

        LoggerService.shared.info("DependencyContainer initialized all services")
        
        // 发送启动就绪通知
        sendStartupNotification()
    }
    
    @MainActor
    func shutdown() {
        anniversaryService.stop()
        preventSleepService.stop()
        settingsService.stop()
        glmService.stop()
        timeSyncService.stop()
        storageService.stop()
        dataStorageService.stop()
        windowManager.closeAllWindows()
        
        LoggerService.shared.info("DependencyContainer shutdown complete")
    }
    
    // MARK: - 系统启动通知机制
    
    /// 当程序启动在后台静默完成所有重置、服务预热和配置文件加载后，向 macOS 发送就绪通知
    private func sendStartupNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else {
                if let err = error {
                    LoggerService.shared.error("Failed to request notification permission: \(err)")
                }
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "🐰 可可皇后已就绪"
            content.body = "所有底层高权配置及宠物名片档案已安全预加载，随时听候调遣。"
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "com.yumikotoys.startup_complete",
                content: content,
                trigger: nil
            )
            
            center.add(request) { error in
                if let err = error {
                    LoggerService.shared.error("Failed to post startup notification: \(err)")
                }
            }
        }
    }
}

// MARK: - Environment Key

struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = DependencyContainer.shared
}

extension EnvironmentValues {
    var container: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - Window Manager

/// 窗口类型标识
enum WindowType: String, CaseIterable {
    case main = "main"
    case settings = "settings"
    case anniversaryManager = "anniversaryManager"
    case changelog = "changelog"
    case about = "about"
    case aiChat = "aiChat"
    
    var title: String {
        switch self {
        case .main: return "YumikoToys"
        case .settings: return "设置"
        case .anniversaryManager: return "宠物名片"
        case .changelog: return "更新日志"
        case .about: return "关于 YumikoToys"
        case .aiChat: return "AI 对话"
        }
    }
    
    var defaultSize: NSSize {
        switch self {
        case .main: return NSSize(width: 560, height: 720)
        case .settings: return NSSize(width: 500, height: 720)
        case .anniversaryManager: return NSSize(width: 540, height: 500)
        case .changelog: return NSSize(width: 460, height: 550)
        case .about: return NSSize(width: 350, height: 450)
        case .aiChat: return NSSize(width: 800, height: 600)
        }
    }
    
    var styleMask: NSWindow.StyleMask {
        switch self {
        case .main: return [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        case .aiChat: return [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        default: return [.titled, .closable, .fullSizeContentView]
        }
    }
}

/// 窗口管理器
@MainActor
final class WindowManager {
    
    // MARK: - Properties
    
    fileprivate var windows: [WindowType: NSWindow] = [:]
    private let windowQueue = DispatchQueue(label: "com.yumikotoys.windowmanager", qos: .userInteractive)
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupThemeObserver()
    }
    
    private func setupThemeObserver() {
        // 延迟监听以确保 settingsService 完全就绪
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            DependencyContainer.shared.settingsService.settingsPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] settings in
                    self?.updateAllWindowsTheme(settings.selectedThemeColor)
                }
                .store(in: &self.cancellables)
        }
    }
    
    func updateAllWindowsTheme(_ themeColor: ThemeColor) {
        for window in windows.values {
            window.backgroundColor = themeColor.nsBackgroundColor
            window.appearance = themeColor.isDarkTheme ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
            window.hasShadow = true
            window.invalidateShadow()
        }
    }
    
    // MARK: - Window Management
    
    /// 显示窗口（单例模式）
    func showWindow(_ type: WindowType, content: () -> NSView) {
        
        // 1. 如果窗口已存在，直接激活
        if let existingWindow = windows[type] {
            DispatchQueue.main.async {
                existingWindow.orderFrontRegardless()
                existingWindow.makeKey()
                NSApp.activate(ignoringOtherApps: true)
                
                if existingWindow.isMiniaturized {
                    existingWindow.deminiaturize(nil)
                }
            }
            LoggerService.shared.debug("Activated existing window: \(type.rawValue)")
            return
        }
        
        // 2. 同步获取 View（保持对非 Escaping 闭包的兼容）
        let view = content()
        
        // 3. 将新窗口的初始化与排版配置整体推迟到下一个 RunLoop 执行
        DispatchQueue.main.async {
            // 二次防重检查
            if let existingWindow = self.windows[type] {
                existingWindow.orderFrontRegardless()
                existingWindow.makeKey()
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            
            // 使用窗口类型的默认尺寸并限制不能大于屏幕工作区（留出一些边距）
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let maxWidth = screenFrame.width - 40
            let maxHeight = screenFrame.height - 40
            
            let targetWidth = min(type.defaultSize.width, maxWidth)
            let targetHeight = min(type.defaultSize.height, maxHeight)
            
            // 创建新窗口
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: NSSize(width: targetWidth, height: targetHeight)),
                styleMask: type.styleMask,
                backing: .buffered,
                defer: false
            )
            
            window.title = type.title
            window.contentView = view
            
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = WindowDelegate.shared
            window.identifier = NSUserInterfaceItemIdentifier(type.rawValue)
            
            // 窗口美化设置
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            
            // 根据主题色设置背景和外观
            let themeColor = DependencyContainer.shared.settingsService.settings.selectedThemeColor
            window.backgroundColor = themeColor.nsBackgroundColor
            window.appearance = themeColor.isDarkTheme ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
            window.hasShadow = true
            
            // 设定最小和最大窗口尺寸
            if type.styleMask.contains(.resizable) {
                window.contentMinSize = NSSize(width: min(type.defaultSize.width * 0.8, targetWidth),
                                               height: min(type.defaultSize.height * 0.8, targetHeight))
            } else {
                window.contentMinSize = NSSize(width: targetWidth, height: targetHeight)
                window.contentMaxSize = NSSize(width: targetWidth, height: targetHeight)
            }
            
            // 配置标题栏按钮样式
            if let closeButton = window.standardWindowButton(.closeButton) {
                closeButton.isHidden = false
            }
            if let miniaturizeButton = window.standardWindowButton(.miniaturizeButton) {
                miniaturizeButton.isHidden = !type.styleMask.contains(.miniaturizable)
            }
            if let zoomButton = window.standardWindowButton(.zoomButton) {
                zoomButton.isHidden = !type.styleMask.contains(.resizable)
            }
            
            self.windows[type] = window
            
            window.orderFrontRegardless()
            window.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            
            LoggerService.shared.info("Created new window: \(type.rawValue)")
        }
    }
    
    /// 显示 SwiftUI 视图窗口
    func showWindow<Content: View>(_ type: WindowType, @ViewBuilder content: () -> Content) {
        showWindow(type) {
            NSHostingView(rootView: content())
        }
    }
    
    /// 关闭指定窗口
    func closeWindow(_ type: WindowType) {
        guard let window = windows[type] else { return }
        window.close()
    }
    
    /// 关闭所有窗口
    func closeAllWindows() {
        windows.values.forEach { $0.close() }
        LoggerService.shared.info("Closed all windows")
    }
    
    /// 检查窗口是否打开
    func isWindowOpen(_ type: WindowType) -> Bool {
        return windows[type] != nil
    }
    
    /// 获取窗口
    func getWindow(_ type: WindowType) -> NSWindow? {
        return windows[type]
    }
}

// MARK: - Window Delegate

/// 窗口代理
@MainActor
private class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let identifier = window.identifier?.rawValue,
              let windowType = WindowType(rawValue: identifier) else {
            return
        }
        
        DependencyContainer.shared.windowManager.windows.removeValue(forKey: windowType)
        LoggerService.shared.debug("Window will close: \(windowType.rawValue)")
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        LoggerService.shared.debug("Window became key: \(window.title ?? "Unknown")")
    }
}
