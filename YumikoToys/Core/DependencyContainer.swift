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

    /// 主动助理服务
    var proactiveAgentService: ProactiveAgentService? {
        services["proactiveAgent"] as? ProactiveAgentService
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

        // 初始化主动助理服务
        let proactiveAgent = ProactiveAgentService(
            settingsService: settingsService,
            apiSettingsService: apiSettingsService,
            backgroundLearningService: backgroundLearningService
        )
        await proactiveAgent.initialize()
        services["proactiveAgent"] = proactiveAgent

        // 第四阶段：启动时间同步
        await timeSyncService.start()

        LoggerService.shared.info("DependencyContainer initialized all services")
        
        // 发送启动就绪通知
        sendStartupNotification()
    }
    
    @MainActor
    func shutdown() {
        proactiveAgentService?.stopService()
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
        case .aiChat: return "Yumiko Claw"
        }
    }
    
    var defaultSize: NSSize {
        switch self {
        case .main: return NSSize(width: 560, height: 720)
        case .settings: return NSSize(width: 780, height: 600)
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
                    self?.updateAllWindowsTheme(
                        color: settings.mainWindowThemeColor,
                        customHex: settings.customMainWindowThemeColorHex
                    )
                }
                .store(in: &self.cancellables)
        }
    }
    
    func updateAllWindowsTheme(color: ThemeColor, customHex: String) {
        let nsBg = color.nsBackgroundColor(customHex: customHex)
        let isDark = color.isDarkTheme(customHex: customHex)
        for window in windows.values {
            window.backgroundColor = nsBg
            window.appearance = isDark ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
            window.hasShadow = true
            window.invalidateShadow()
        }
    }
    
    // MARK: - Window Management
    
    /// 激活并使窗口轻微弹动 (微交互动效)
    private func activateAndPulseWindow(_ window: NSWindow) {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        
        window.orderFrontRegardless()
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        
        let currentFrame = window.frame
        let pulseFrame = currentFrame.insetBy(dx: -3, dy: -3)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(pulseFrame, display: true)
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                window.animator().setFrame(currentFrame, display: true)
            }, completionHandler: nil)
        })
    }
    
    /// 显示窗口（单例模式）
    func showWindow(_ type: WindowType, content: () -> NSView) {
        
        // 1. 如果窗口已存在，直接激活且弹动反馈
        if let existingWindow = windows[type] {
            DispatchQueue.main.async {
                self.activateAndPulseWindow(existingWindow)
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
                self.activateAndPulseWindow(existingWindow)
                return
            }
            
            // 使用窗口类型的默认尺寸并限制不能大于屏幕工作区（留出一些边距）
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let maxWidth = screenFrame.width - 40
            let maxHeight = screenFrame.height - 40
            
            var targetWidth = min(type.defaultSize.width, maxWidth)
            var targetHeight = min(type.defaultSize.height, maxHeight)
            
            if type == .main {
                let customWidth = UserDefaults.standard.double(forKey: "customWindowWidth")
                let customHeight = UserDefaults.standard.double(forKey: "customWindowHeight")
                if customWidth > 0 && customHeight > 0 {
                    // customWidth/customHeight are window frame sizes, convert to content sizes
                    let dummyWindow = NSWindow(contentRect: .zero, styleMask: type.styleMask, backing: .buffered, defer: false)
                    let contentRect = dummyWindow.contentRect(forFrameRect: NSRect(x: 0, y: 0, width: CGFloat(customWidth), height: CGFloat(customHeight)))
                    targetWidth = min(contentRect.width, maxWidth)
                    targetHeight = min(contentRect.height, maxHeight)
                } else {
                    let settings = DependencyContainer.shared.settingsService.settings
                    let layouts = DependencyContainer.shared.componentLayoutService.loadLayouts()
                    let visibleLayouts = ComponentLayout.visible(layouts)
                    let maxWidthScale = visibleLayouts.map { $0.customWidthScale ?? 1.0 }.max() ?? 1.0
                    let calcWidth = max(520, 364 * CGFloat(maxWidthScale) + 56 + 72)
                    
                    var elementsHeights: [CGFloat] = []
                    for layout in visibleLayouts {
                        let defaultHeight: CGFloat
                        switch layout.type {
                        case .header: defaultHeight = 60
                        case .daysDisplay: defaultHeight = 230
                        case .backgroundLearning: defaultHeight = 180
                        case .modelStatus: defaultHeight = 150
                        }
                        elementsHeights.append(CGFloat(layout.customHeight ?? Double(defaultHeight)))
                    }
                    let totalSpacing: CGFloat = elementsHeights.isEmpty ? 0 : CGFloat(elementsHeights.count - 1) * 24
                    let bottomPadding: CGFloat = settings.godModeEnabled ? 100 : 28
                    let calcHeight = max(580, elementsHeights.reduce(0, +) + totalSpacing + 28 + bottomPadding)
                    
                    targetWidth = min(calcWidth, maxWidth)
                    targetHeight = min(calcHeight, maxHeight)
                }
            }
            
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
            
            // 根据主界面主题色设置背景和外观
            let settings = DependencyContainer.shared.settingsService.settings
            let mainThemeColor = settings.mainWindowThemeColor
            let mainCustomHex = settings.customMainWindowThemeColorHex
            window.backgroundColor = mainThemeColor.nsBackgroundColor(customHex: mainCustomHex)
            window.appearance = mainThemeColor.isDarkTheme(customHex: mainCustomHex) ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
            window.hasShadow = true
            
            // 设定最小和最大窗口尺寸
            if type.styleMask.contains(.resizable) {
                let minW = (type == .main) ? 460.0 : min(type.defaultSize.width * 0.8, targetWidth)
                let minH = (type == .main) ? 450.0 : min(type.defaultSize.height * 0.8, targetHeight)
                window.contentMinSize = NSSize(width: minW, height: minH)
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
            
            // 【弹出过渡动画】设定初始透明度为0，并向下偏移15pt以实现向上弹跳弹出效果
            window.alphaValue = 0.0
            let finalFrame = window.frame
            let startFrame = finalFrame.offsetBy(dx: 0, dy: -15)
            window.setFrame(startFrame, display: false)
            
            window.orderFrontRegardless()
            window.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.32
                // 经典缓动曲线，高品质交互感
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
                window.animator().alphaValue = 1.0
                window.animator().setFrame(finalFrame, display: true)
            }, completionHandler: nil)
            
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
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let identifier = sender.identifier?.rawValue,
              let _ = WindowType(rawValue: identifier) else {
            return true
        }
        
        // 如果已经开始淡出，则直接允许关闭
        if sender.alphaValue == 0.0 {
            return true
        }
        
        // 退出过渡动画：淡出并向下偏移15pt以实现滑落效果
        let currentFrame = sender.frame
        let exitFrame = currentFrame.offsetBy(dx: 0, dy: -15)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            sender.animator().alphaValue = 0.0
            sender.animator().setFrame(exitFrame, display: true)
        }, completionHandler: {
            sender.close()
        })
        
        return false
    }
    
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

// MARK: - Premium Interactive Click & Hover Styles

/// 交互式按键样式 - 包含轻微按下缩放与弹簧反馈
struct PremiumButtonStyle: ButtonStyle {
    let scaleOnPress: CGFloat
    let animation: Animation
    
    init(scaleOnPress: CGFloat = 0.94, animation: Animation = .spring(response: 0.22, dampingFraction: 0.55, blendDuration: 0)) {
        self.scaleOnPress = scaleOnPress
        self.animation = animation
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleOnPress : 1.0)
            .animation(animation, value: configuration.isPressed)
    }
}

/// 交互式悬停修饰符
struct PremiumHoverModifier: ViewModifier {
    @State private var isHovered = false
    
    let scaleOnHover: CGFloat
    let hoverGlow: Bool
    
    init(scaleOnHover: CGFloat = 1.03, hoverGlow: Bool = true) {
        self.scaleOnHover = scaleOnHover
        self.hoverGlow = hoverGlow
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scaleOnHover : 1.0)
            .shadow(color: hoverGlow && isHovered ? Color.primary.opacity(0.08) : Color.clear, radius: 8, x: 0, y: 4)
            .brightness(isHovered ? 0.02 : 0.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
            .onHover { hovering in
                self.isHovered = hovering
            }
    }
}

extension View {
    /// 添加高端质感的交互式悬浮微动效果（缩放、亮度和阴影）
    func premiumHover(scale: CGFloat = 1.03, glow: Bool = true) -> some View {
        self.modifier(PremiumHoverModifier(scaleOnHover: scale, hoverGlow: glow))
    }
}

extension ButtonStyle where Self == PremiumButtonStyle {
    /// 具有轻微弹动反馈的 Premium 按钮样式
    static var premium: PremiumButtonStyle {
        PremiumButtonStyle()
    }
    
    /// 自定义缩放比例的 Premium 按钮样式
    static func premium(scale: CGFloat) -> PremiumButtonStyle {
        PremiumButtonStyle(scaleOnPress: scale)
    }
}

