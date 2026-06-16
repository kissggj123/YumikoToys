//
//  StatusBarManager.swift
//  YumikoToys
//
//  状态栏管理器（v4.0.9 - 窗口内存生命周期修复 + 自定义字体桥接版）
//

import Cocoa
import SwiftUI
import Combine

@MainActor
final class StatusBarManager: NSObject {
    
    // MARK: - Properties
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: EventMonitor?
    
    private let container = DependencyContainer.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 状态栏 SwiftUI 承载宿主
    private var statusBarHostingView: NSHostingView<StatusBarButtonView>?
    
    // 当前渲染状态缓存
    private var currentDays: Double = 0.0
    private var currentLine1: String = "兔可可已到来"
    private var currentImage: NSImage?
    
    // MARK: - 全屏表情雨窗口与延迟任务持有者
    private var rainWindow: NSWindow?
    private var rainTask: Task<Void, Never>? // 使用 Task 进行协作式取消，确保多线程下生命周期安全
    
    // MARK: - 图标动画系统（Combine 优化版）
    
    private var iconAnimationCancellable: AnyCancellable?
    private var currentIconIndex = 0
    private let animatedIcons = ["hattie on 1", "hattie on 2", "hattie on 3"]
    private let staticIcon = "hattie off"
    private let animationInterval: TimeInterval = 0.5
    
    /// 当前图标风格
    private var currentIconStyle: IconStyle = .pixelAnimal
    private var statusBarLine1: String = "兔可可已到来"
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        currentIconStyle = container.settingsService.settings.statusBarIconStyle
        setupStatusBar()
        setupEventMonitor()
        bindToServices()
        
        // 立即同步初始状态和数据
        updateStatusBarIcon()
        if let info = container.anniversaryService.activeAnniversaryInfo {
            updateStatusBarTitle(withDays: info.calculation.totalDays)
        }
        
        LoggerService.shared.info("StatusBarManager initialized")
    }
    
    deinit {
        let item = statusItem
        let monitor = eventMonitor
        let anim = iconAnimationCancellable
        let task = rainTask
        let hosting = statusBarHostingView
        
        // 【防闪退核心修复】强行将 AppKit 组件的注销与静态析构释放分发至主线程
        // 杜绝因 deinit 被后台 Combine 线程调用而导致 `NSStatusItem` 在非 UI 线程释放引起的 EXC_BAD_ACCESS
        DispatchQueue.main.async {
            monitor?.stop()
            anim?.cancel()
            task?.cancel()
            hosting?.removeFromSuperview()
            if let item = item {
                NSStatusBar.system.removeStatusItem(item)
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let statusItem = statusItem else { return }
        
        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        let popover = NSPopover()
        // 初始宽度设为 340，高度交由 AdaptiveHostingController 运行时根据 SwiftUI 内容动态自适应
        popover.contentSize = NSSize(width: 340, height: 100)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        
        // 【修复】根据当前主题色设置 popover 外观
        let settings = DependencyContainer.shared.settingsService.settings
        let themeColor = settings.selectedThemeColor
        popover.appearance = themeColor.isDarkTheme(customHex: settings.customThemeColorHex) ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        
        let contentView = StatusBarView(
            onShowMainWindow: { [weak self] in
                guard let self = self else { return }
                self.closePopover()
                
                // 开启表情雨并在后台安静结算 300ms 后置前拉起窗口
                self.triggerEmojiRain()
                
                // 【防闪退修复】使用 [weak self] 弱引用防护，防止延时执行期间生命周期提前结束造成崩溃
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.showMainWindow()
                }
            },
            onQuit: { [weak self] in
                self?.quitApp()
            },
            onScreenshotTriggered: { [weak self] in
                self?.closePopover()
            }
        )
        
        // 使用自适应 HostingController 替换普通 NSHostingController
        let hostingController = AdaptiveHostingController(rootView: contentView)
        hostingController.popover = popover
        
        popover.contentViewController = hostingController
        self.popover = popover
    }
    
    private func setupEventMonitor() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        eventMonitor = EventMonitor(mask: mask) { [weak self] (event: NSEvent?) in
            guard let self = self else { return }
            if self.popover?.isShown == true {
                // 如果系统颜色面板打开着，且点击在该面板内，则不关闭 popover
                if NSColorPanel.shared.isVisible {
                    if let clickedWindow = event?.window {
                        if clickedWindow == NSColorPanel.shared || clickedWindow.className.contains("ColorPanel") || clickedWindow.level == .floating || clickedWindow.level == .modalPanel {
                            return
                        }
                    }
                }
                self.closePopover()
            }
        }
    }
    
    // MARK: - 物理下落粒子雨 (Emoji Rain)
    
    private func triggerEmojiRain() {
        // 【核心修复】没消失前只生成一次：若上一次的动画（窗口或延迟任务）未完全销毁，则直接忽略本次触发
        guard rainWindow == nil && rainTask == nil else { return }
        
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // 【防闪退关键修复】必须关闭 AppKit 默认的销毁行为，改由 Swift ARC 引用计数安全托管析构流程
        window.isReleasedWhenClosed = false
        
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.level = .statusBar
        
        let rainView = EmojiRainView(screenHeight: screenFrame.height)
        window.contentView = NSHostingView(rootView: rainView)
        self.rainWindow = window
        window.orderFrontRegardless()
        
        // 使用主线程绑定的 Task 管理延迟释放，保障销毁完全闭环
        rainTask = Task { [weak self, weak window] in
            try? await Task.sleep(nanoseconds: 3_500_000_000) // 延迟 3.5 秒（即动画完全播放结束）
            
            guard !Task.isCancelled else { return }
            
            if let activeWindow = window {
                activeWindow.close()
            }
            if let self = self, self.rainWindow == window {
                self.rainWindow = nil
                self.rainTask = nil // 彻底置空，释放排他锁，允许下一次动画正常触发
            }
        }
    }
    
    // MARK: - 图标动画系统
    
    /// 根据防休眠状态更新图标
    func updateIconForPreventSleepState(_ isEnabled: Bool) {
        if isEnabled {
            startIconAnimation()
        } else {
            stopIconAnimation()
            updateStatusBarIcon()
        }
    }
    
    private func startIconAnimation() {
        stopIconAnimation()
        currentIconIndex = 0
        
        iconAnimationCancellable = Timer.publish(every: animationInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cycleIcon()
            }
    }
    
    private func stopIconAnimation() {
        iconAnimationCancellable?.cancel()
        iconAnimationCancellable = nil
    }
    
    private func cycleIcon() {
        if currentIconStyle == .originalHattie {
            let iconName = animatedIcons[currentIconIndex % animatedIcons.count]
            setIcon(iconName)
        } else {
            guard let baseImage = currentIconStyle.renderStatusBarIcon(size: 22).copy() as? NSImage else { return }
            let scale: CGFloat = 1.0 + 0.08 * sin(Double(currentIconIndex) * 0.5)
            let newSize = NSSize(width: 22 * scale, height: 22 * scale)
            baseImage.size = newSize
            self.currentImage = baseImage
            updateStatusBarRepresentation()
        }
        currentIconIndex += 1
    }
    
    private func setIcon(_ name: String) {
        if let baseImage = NSImage(named: name)?.copy() as? NSImage {
            baseImage.size = NSSize(width: 22, height: 22)
            baseImage.isTemplate = true
            self.currentImage = baseImage
            updateStatusBarRepresentation()
        }
    }
    
    private func updateStatusBarIcon() {
        guard let baseImage = currentIconStyle.renderStatusBarIcon(size: 22).copy() as? NSImage else { return }
        baseImage.size = NSSize(width: 22, height: 22)
        self.currentImage = baseImage
        updateStatusBarRepresentation()
    }
    
    func refreshAfterServicesInitialized() {
        Task { @MainActor in
            updateStatusBarIcon()
            if let info = container.anniversaryService.activeAnniversaryInfo {
                updateStatusBarTitle(withDays: info.calculation.totalDays)
            }
            updateIconForPreventSleepState(container.preventSleepService.isPreventSleepEnabled)
        }
    }
    
    // MARK: - 绑定服务
    
    private func bindToServices() {
        container.anniversaryService.countdownTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                if let info = self.container.anniversaryService.activeAnniversaryInfo {
                    self.updateStatusBarTitle(withDays: info.calculation.totalDays)
                }
            }
            .store(in: &cancellables)
        
        container.preventSleepService.isPreventSleepEnabledPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.updateIconForPreventSleepState(isEnabled)
            }
            .store(in: &cancellables)
        
        container.settingsService.settingsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self = self else { return }
                
                // 更新图标风格
                let style = settings.statusBarIconStyle
                if self.currentIconStyle != style {
                    self.currentIconStyle = style
                    if !self.container.preventSleepService.isPreventSleepEnabled {
                        self.updateStatusBarIcon()
                    }
                    LoggerService.shared.info("Status bar icon updated to style: \(style.displayName)")
                }
                
                // 动态同步更新 popover 外观与窗口背景色（确保小箭头颜色同步跟随主题）
                let themeColor = settings.selectedThemeColor
                self.popover?.appearance = themeColor.isDarkTheme(customHex: settings.customThemeColorHex) ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
                if let window = self.popover?.contentViewController?.view.window {
                    let nsBg = themeColor.nsBackgroundColor(customHex: settings.customThemeColorHex)
                    window.backgroundColor = nsBg
                    if let frameView = window.contentView?.superview {
                        colorizePopoverBackground(in: frameView, color: nsBg)
                    }
                }
            }
            .store(in: &cancellables)
        
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.container.preventSleepService.isPreventSleepEnabled {
                    self.updateStatusBarIcon()
                }
            }
            .store(in: &cancellables)
        
        container.anniversaryService.statusBarLine1Publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] line1 in
                self?.statusBarLine1 = line1
            }
            .store(in: &cancellables)
        
        if let info = container.anniversaryService.activeAnniversaryInfo {
            updateStatusBarTitle(withDays: info.calculation.totalDays)
        }
        
        updateIconForPreventSleepState(container.preventSleepService.isPreventSleepEnabled)
    }
    
    private func parseDays(from text: String) -> Double? {
        let components = text.components(separatedBy: " ")
        guard let daysComponent = components.first else { return nil }
        // 使用非 mutating 的标准 Foundation 替换
        let daysString = daysComponent.replacingOccurrences(of: "天", with: "")
        return Double(daysString)
    }
    
    // MARK: - 【数据模型更新入口】
    
    private func updateStatusBarTitle(withDays days: Double) {
        self.currentDays = days
        let settings = container.settingsService.settings
        let textMode = settings.statusBarTextMode
        
        var line1: String
        
        switch textMode {
        case .godMode:
            // 上帝模式：使用完全自定义文本
            line1 = settings.customStatusBarText.isEmpty ? "兔可可已到来" : settings.customStatusBarText
            // 支持模板变量替换
            if let info = container.anniversaryService.activeAnniversaryInfo {
                line1 = line1.replacingOccurrences(of: "{name}", with: info.anniversary.displayPetName)
                line1 = line1.replacingOccurrences(of: "{days}", with: String(format: "%.0f", days))
                line1 = line1.replacingOccurrences(of: "{emoji}", with: info.anniversary.displayAvatar)
                line1 = line1.replacingOccurrences(of: "{species}", with: info.anniversary.species ?? "宠物")
            }
            
        case .originalName:
            // 始终使用原始宠物名
            line1 = container.anniversaryService.activeAnniversaryInfo?.anniversary.parsedStatusBarLine1(days: days) ?? "兔可可已到来"
            
        case .customTitle:
            // 使用自定义标题（优先使用用户输入的 customStatusBarText，其次使用布局组件中的 customTitle）
            line1 = container.anniversaryService.activeAnniversaryInfo?.anniversary.parsedStatusBarLine1(days: days) ?? "兔可可已到来"
            
            if let info = container.anniversaryService.activeAnniversaryInfo {
                let originalName = info.anniversary.displayPetName
                let customText = settings.customStatusBarText
                
                if !customText.isEmpty {
                    // 用户在设置中输入了自定义名称，直接替换
                    line1 = line1.replacingOccurrences(of: originalName, with: customText)
                } else {
                    // 回退到布局组件中的 customTitle
                    let layouts = container.componentLayoutService.currentLayouts
                    if let layout = layouts.first(where: { $0.type == .daysDisplay }),
                       let customTitle = layout.customTitle, !customTitle.isEmpty {
                        line1 = line1.replacingOccurrences(of: originalName, with: customTitle)
                    }
                }
            }
        }
        
        self.currentLine1 = line1
        updateStatusBarRepresentation()
    }
    
    // MARK: - 【SwiftUI 全包裹自适应管道】
    
    private func updateStatusBarRepresentation() {
        guard let button = statusItem?.button else { return }
        
        let buttonView = StatusBarButtonView(
            days: currentDays,
            line1: currentLine1,
            currentImage: currentImage
        )
        
        if let hostingView = statusBarHostingView {
            // 已存在宿主：直接热更新 SwiftUI 的数据源（底层极速渲染，完全无闪烁）
            hostingView.rootView = buttonView
            
            // 重新计算并同步物理宽度
            let size = hostingView.fittingSize
            hostingView.frame = NSRect(origin: .zero, size: size)
            statusItem?.length = size.width
        } else {
            // 首次渲染：清除 AppKit 默认的前景，防止视觉重合
            button.title = ""
            button.image = nil
            
            let hostingView = NSHostingView(rootView: buttonView)
            let size = hostingView.fittingSize
            hostingView.frame = NSRect(origin: .zero, size: size)
            
            // 确保尺寸拉伸与 AppKit 按钮容器完美对齐
            hostingView.autoresizingMask = [.width, .height]
            
            button.addSubview(hostingView)
            self.statusBarHostingView = hostingView
            statusItem?.length = size.width
        }
    }
    
    // MARK: - Popover Actions
    
    @objc private func togglePopover() {
        if let popover = popover, popover.isShown {
            closePopover()
        } else {
            showPopover()
            triggerEmojiRain()
        }
    }
    
    private func showPopover() {
        guard let statusItem = statusItem, let button = statusItem.button else { return }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        eventMonitor?.start()
    }
    
    private func closePopover() {
        popover?.close()
        eventMonitor?.stop()
        // 随 popover 关闭一同关闭可能遗留的系统颜色选择器面板
        if NSColorPanel.shared.isVisible {
            NSColorPanel.shared.close()
        }
    }
    
    // MARK: - Window Actions
    
    @MainActor
    private func showMainWindow() {
        container.windowManager.showWindow(.main) {
            MainView()
        }
    }
    
    private func quitApp() {
        closePopover()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.terminate(nil)
        }
    }
}

// MARK: - NSHostingController 动态自适应高度子类

/// 专门解决 AppKit 弹出框内部 SwiftUI 布局动态伸缩的 Hosting 封装控制器
final class AdaptiveHostingController<Content: View>: NSHostingController<Content> {
    weak var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSettingsObserver()
    }
    
    private func setupSettingsObserver() {
        DependencyContainer.shared.settingsService.settingsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePopoverColors()
            }
            .store(in: &cancellables)
    }
    
    private func updatePopoverColors() {
        guard let window = self.view.window else { return }
        let settings = DependencyContainer.shared.settingsService.settings
        let themeColor = settings.selectedThemeColor
        let nsBg = themeColor.nsBackgroundColor(customHex: settings.customThemeColorHex)
        window.backgroundColor = nsBg
        if let frameView = window.contentView?.superview {
            colorizePopoverBackground(in: frameView, color: nsBg)
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        let idealSize = self.view.fittingSize
        if idealSize.width > 0 && idealSize.height > 0 {
            let maxHeight = (NSScreen.main?.frame.height ?? 800) * 0.7
            let cappedHeight = min(idealSize.height, maxHeight)
            if popover?.contentSize.height != cappedHeight {
                DispatchQueue.main.async { [weak self] in
                    self?.popover?.contentSize = NSSize(width: idealSize.width, height: cappedHeight)
                }
            }
        }
        
        updatePopoverColors()
    }
}

// 遍历并设置 window 的背景视图以让 window.backgroundColor 能够透出并契合主题（包含小箭头）
fileprivate func colorizePopoverBackground(in view: NSView, color: NSColor) {
    let className = String(describing: type(of: view))
    if let effectView = view as? NSVisualEffectView {
        effectView.wantsLayer = true
        effectView.layer?.backgroundColor = color.cgColor
        effectView.alphaValue = 1.0
        effectView.state = .inactive
    } else if className.contains("Popover") || className.contains("NSThemeFrame") || className.contains("NSView") {
        view.wantsLayer = true
        view.layer?.backgroundColor = color.cgColor
    }
    for subview in view.subviews {
        colorizePopoverBackground(in: subview, color: color)
    }
}

// MARK: - Event Monitor

private class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: ((NSEvent?) -> Void)?
    
    init(mask: NSEvent.EventTypeMask, handler: ((NSEvent?) -> Void)?) {
        self.mask = mask
        self.handler = handler
    }
    
    deinit { stop() }
    
    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handler?(event)
        }
    }
    
    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

// MARK: - 无状态物理下落粒子雨 (Emoji Rain - Timeline 驱动)

// MARK: - 无状态物理下落粒子雨 (Emoji Rain - Timeline 驱动)

struct EmojiRainView: View {
    let screenHeight: CGFloat
    
    struct EmojiParticle: Identifiable {
        let id = UUID()
        let emoji: String
        let xRatio: CGFloat
        let startY: CGFloat
        let speed: CGFloat
        let scale: CGFloat
        let startRotation: Double
        let rotationSpeed: Double
        let swaySpeed: Double
        let swayAmplitude: CGFloat
        let swayPhase: Double
        let pulseSpeed: Double
        
        // Advanced properties for special effects (snowflake, firework, bubble)
        var fireworkGroup: Int = 0
        var fireworkAngle: Double = 0.0
        var fireworkSpeed: CGFloat = 0.0
        var fireworkStartOffset: Double = 0.0
        var fireworkExplosionXRatio: CGFloat = 0.5
        var fireworkExplosionY: CGFloat = 0.0
        
        init(
            emoji: String,
            xRatio: CGFloat,
            startY: CGFloat,
            speed: CGFloat,
            scale: CGFloat,
            startRotation: Double,
            rotationSpeed: Double,
            swaySpeed: Double,
            swayAmplitude: CGFloat,
            swayPhase: Double,
            pulseSpeed: Double,
            fireworkGroup: Int = 0,
            fireworkAngle: Double = 0.0,
            fireworkSpeed: CGFloat = 0.0,
            fireworkStartOffset: Double = 0.0,
            fireworkExplosionXRatio: CGFloat = 0.5,
            fireworkExplosionY: CGFloat = 0.0
        ) {
            self.emoji = emoji
            self.xRatio = xRatio
            self.startY = startY
            self.speed = speed
            self.scale = scale
            self.startRotation = startRotation
            self.rotationSpeed = rotationSpeed
            self.swaySpeed = swaySpeed
            self.swayAmplitude = swayAmplitude
            self.swayPhase = swayPhase
            self.pulseSpeed = pulseSpeed
            self.fireworkGroup = fireworkGroup
            self.fireworkAngle = fireworkAngle
            self.fireworkSpeed = fireworkSpeed
            self.fireworkStartOffset = fireworkStartOffset
            self.fireworkExplosionXRatio = fireworkExplosionXRatio
            self.fireworkExplosionY = fireworkExplosionY
        }
    }
    
    @State private var particles: [EmojiParticle] = []
    @State private var startDate = Date()
    
    var body: some View {
        GeometryReader { geo in
            if !particles.isEmpty {
                TimelineView(.animation(minimumInterval: 0.016)) { context in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    let effectType = DependencyContainer.shared.settingsService.settings.activeSpecialEffect
                    
                    Canvas { canvasContext, size in
                        for p in particles {
                            var currentX: CGFloat = 0
                            var currentY: CGFloat = 0
                            var currentRotation: Double = 0
                            var currentScale: CGFloat = 1.0
                            var opacity: Double = 1.0
                            var currentEmoji = p.emoji
                            
                            switch effectType {
                            case .emoji:
                                currentY = p.startY + p.speed * CGFloat(elapsed)
                                currentX = p.xRatio * size.width
                                currentRotation = p.startRotation + p.rotationSpeed * elapsed
                                currentScale = p.scale
                                opacity = 1.0
                                
                            case .sakura:
                                currentY = p.startY + p.speed * CGFloat(elapsed)
                                let sway = sin(elapsed * p.swaySpeed + p.swayPhase) * p.swayAmplitude
                                currentX = p.xRatio * size.width + sway
                                currentRotation = p.startRotation + p.rotationSpeed * elapsed
                                currentScale = p.scale
                                opacity = 1.0
                                
                            case .star:
                                currentY = p.startY + p.speed * CGFloat(elapsed)
                                currentX = p.xRatio * size.width
                                currentRotation = p.startRotation + p.rotationSpeed * elapsed
                                let scalePulsation = 1.0 + 0.25 * sin(elapsed * p.pulseSpeed)
                                currentScale = p.scale * CGFloat(scalePulsation)
                                opacity = 1.0
                                
                            case .heart:
                                currentY = p.startY + p.speed * CGFloat(elapsed)
                                let sway = sin(elapsed * p.swaySpeed + p.swayPhase) * p.swayAmplitude
                                currentX = p.xRatio * size.width + sway
                                currentRotation = p.startRotation + p.rotationSpeed * elapsed
                                currentScale = p.scale
                                opacity = 1.0
                                
                            case .snowflake:
                                currentY = p.startY + p.speed * 0.45 * CGFloat(elapsed)
                                let sway = sin(elapsed * p.swaySpeed * 0.8 + p.swayPhase) * p.swayAmplitude * 1.3
                                currentX = p.xRatio * size.width + sway
                                currentRotation = p.startRotation + p.rotationSpeed * 0.5 * elapsed
                                currentScale = p.scale
                                let bottomDist = size.height - currentY
                                if bottomDist < 150 {
                                    opacity = max(0.0, Double(bottomDist / 150.0))
                                } else {
                                    opacity = 1.0
                                }
                                
                            case .bubble:
                                currentY = p.startY + p.speed * 0.55 * CGFloat(elapsed)
                                let sway = sin(elapsed * p.swaySpeed + p.swayPhase) * p.swayAmplitude * 1.5
                                currentX = p.xRatio * size.width + sway
                                currentRotation = 0.0
                                let pulse = 1.0 + 0.15 * sin(elapsed * p.pulseSpeed)
                                currentScale = p.scale * CGFloat(pulse)
                                if currentY < 150 {
                                    opacity = max(0.0, Double(currentY / 150.0))
                                } else {
                                    opacity = 1.0
                                }
                                
                            case .firework:
                                let t = elapsed - p.fireworkStartOffset
                                if t < 0 {
                                    opacity = 0.0
                                } else if t < 0.75 {
                                    let ratio = t / 0.75
                                    let explosionX = p.fireworkExplosionXRatio * size.width
                                    currentX = size.width / 2.0 + (explosionX - size.width / 2.0) * ratio
                                    currentY = size.height - (size.height - p.fireworkExplosionY) * ratio
                                    currentRotation = 0.0
                                    currentScale = 0.8
                                    opacity = 1.0
                                    currentEmoji = "☄️"
                                } else {
                                    let sparkTime = t - 0.75
                                    let sparkLifetime = 0.95
                                    if sparkTime >= sparkLifetime {
                                        opacity = 0.0
                                    } else {
                                        let explosionX = p.fireworkExplosionXRatio * size.width
                                        let drag: Double = 1.8
                                        let gravity: Double = 320.0
                                        let decay = (1.0 - exp(-sparkTime * drag)) / drag
                                        let dx = p.fireworkSpeed * cos(p.fireworkAngle) * CGFloat(decay)
                                        let dy = p.fireworkSpeed * sin(p.fireworkAngle) * CGFloat(decay) + 0.5 * CGFloat(gravity * sparkTime * sparkTime)
                                        
                                        currentX = explosionX + dx
                                        currentY = p.fireworkExplosionY + dy
                                        currentRotation = p.startRotation + p.rotationSpeed * sparkTime
                                        currentScale = p.scale * (1.0 - CGFloat(sparkTime / sparkLifetime))
                                        opacity = max(0.0, 1.0 - sparkTime / sparkLifetime)
                                    }
                                }
                            case .matrix:
                                currentY = p.startY + p.speed * 1.15 * CGFloat(elapsed)
                                currentX = p.xRatio * size.width
                                currentRotation = 0.0
                                currentScale = p.scale
                                opacity = 1.0
                                
                            case .halo:
                                currentY = p.startY + p.speed * 0.45 * CGFloat(elapsed)
                                let sway = sin(elapsed * p.swaySpeed * 0.6 + p.swayPhase) * p.swayAmplitude * 1.2
                                currentX = p.xRatio * size.width + sway
                                currentRotation = p.startRotation + p.rotationSpeed * 0.3 * elapsed
                                let pulse = 1.0 + 0.15 * sin(elapsed * p.pulseSpeed * 0.7)
                                currentScale = p.scale * CGFloat(pulse)
                                opacity = 1.0
                                
                            case .gravityBubble:
                                let gravity: CGFloat = 750.0
                                currentY = p.startY + p.speed * CGFloat(elapsed) + 0.5 * gravity * CGFloat(elapsed * elapsed)
                                currentX = p.xRatio * size.width
                                currentRotation = 0.0
                                currentScale = p.scale
                                opacity = 1.0
                            }
                            
                            if opacity > 0 {
                                var particleContext = canvasContext
                                particleContext.opacity = opacity
                                
                                let resolved: GraphicsContext.ResolvedText
                                if effectType == .matrix {
                                    resolved = canvasContext.resolve(
                                        Text(currentEmoji)
                                            .font(.system(size: 26 * currentScale, weight: .bold, design: .monospaced))
                                            .foregroundColor(Color(red: 0.0, green: 0.95, blue: 0.15))
                                    )
                                } else if effectType == .halo {
                                    resolved = canvasContext.resolve(
                                        Text(currentEmoji)
                                            .font(.system(size: 30 * currentScale))
                                            .foregroundColor(Color(red: 1.0, green: 0.88, blue: 0.2))
                                    )
                                } else {
                                    resolved = canvasContext.resolve(
                                        Text(currentEmoji)
                                            .font(.system(size: 32 * currentScale))
                                    )
                                }
                                
                                particleContext.translateBy(x: currentX, y: currentY)
                                particleContext.rotate(by: Angle(degrees: currentRotation))
                                particleContext.draw(resolved, at: .zero)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startDate = Date()
            let effectType = DependencyContainer.shared.settingsService.settings.activeSpecialEffect
            
            let emojiPresets: [String]
            switch effectType {
            case .emoji:
                emojiPresets = ["🐰", "🥕", "🐱", "🐶", "🐹", "🦊", "🐼", "🐸", "🐻", "🐾", "🥕", "🐰"]
            case .sakura:
                emojiPresets = ["🌸", "💮", "🌺", "🍃", "🌸", "💮"]
            case .star:
                emojiPresets = ["⭐", "✨", "🌟", "💫", "⭐", "✨"]
            case .heart:
                emojiPresets = ["❤️", "💖", "💝", "💕", "💘", "💓"]
            case .snowflake:
                emojiPresets = ["❄️", "🌨️", "✨", "❄️", "🌨️"]
            case .bubble:
                emojiPresets = ["🫧", "🫧", "🔵", "⚪", "🫧"]
            case .firework:
                emojiPresets = ["🎆", "🎇", "✨", "💥", "🔴", "🔵", "🟡", "🟢", "⭐"]
            case .matrix:
                emojiPresets = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "X", "Y"]
            case .halo:
                emojiPresets = ["😇", "✨", "👑", "💫", "🌟", "🪽"]
            case .gravityBubble:
                emojiPresets = ["💧", "💦", "🌧️", "💧", "🔵", "💦"]
            }
            
            let count = 45
            if effectType == .firework {
                particles = (0..<count).map { idx in
                    let fireworkIndex = idx / 15
                    let startOffset = Double(fireworkIndex) * 0.45 // 0.0s, 0.45s, 0.9s
                    let explosionXRatio = CGFloat(0.25 + Double(fireworkIndex) * 0.25) + CGFloat.random(in: -0.05...0.05)
                    let explosionY = screenHeight * CGFloat.random(in: 0.22...0.42)
                    
                    let angle = Double(idx % 15) / 15.0 * 2.0 * .pi + Double.random(in: -0.12...0.12)
                    let sparkSpeed = CGFloat.random(in: 180...380)
                    
                    return EmojiParticle(
                        emoji: emojiPresets.randomElement()!,
                        xRatio: explosionXRatio,
                        startY: screenHeight,
                        speed: 0,
                        scale: CGFloat.random(in: 0.7...1.2),
                        startRotation: Double.random(in: 0...360),
                        rotationSpeed: Double.random(in: 60...180),
                        swaySpeed: 0,
                        swayAmplitude: 0,
                        swayPhase: 0,
                        pulseSpeed: 0,
                        fireworkGroup: fireworkIndex,
                        fireworkAngle: angle,
                        fireworkSpeed: sparkSpeed,
                        fireworkStartOffset: startOffset,
                        fireworkExplosionXRatio: explosionXRatio,
                        fireworkExplosionY: explosionY
                    )
                }
            } else {
                particles = (0..<count).map { _ in
                    let isHeart = effectType == .heart
                    let isBubble = effectType == .bubble
                    let isHalo = effectType == .halo
                    
                    let startY: CGFloat
                    let speed: CGFloat
                    if isHeart || isBubble || isHalo {
                        startY = screenHeight + CGFloat.random(in: 50...150)
                        speed = CGFloat.random(in: -480...(-280))
                    } else {
                        startY = CGFloat.random(in: -150...(-50))
                        speed = CGFloat.random(in: 450...780)
                    }
                    
                    return EmojiParticle(
                        emoji: emojiPresets.randomElement()!,
                        xRatio: CGFloat.random(in: 0.02...0.98),
                        startY: startY,
                        speed: speed,
                        scale: CGFloat.random(in: 0.6...1.3),
                        startRotation: Double.random(in: 0...360),
                        rotationSpeed: effectType == .sakura ? Double.random(in: 30...90) : Double.random(in: 120...240),
                        swaySpeed: Double.random(in: 2.0...5.0),
                        swayAmplitude: CGFloat.random(in: 15...40),
                        swayPhase: Double.random(in: 0...(2 * .pi)),
                        pulseSpeed: Double.random(in: 8.0...15.0)
                    )
                }
            }
        }
    }
}

// MARK: - SwiftUI 状态栏纯包裹自适应控件

struct StatusBarButtonView: View {
    let days: Double
    let line1: String
    let currentImage: NSImage?
    
    // 【修复】直接使用非可选的 NSFont 进行桥接转换，无需 if let
    private var font1: Font {
        let nsFont = NSFont.cute(9)
        return Font(nsFont as CTFont)
    }
    
    private var font2: Font {
        let nsFont = NSFont.cute(11)
        return Font(nsFont as CTFont)
    }
    
    var body: some View {
        HStack(spacing: 5) {
            if let img = currentImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            }
            
            VStack(alignment: .center, spacing: -1) {
                Text(line1)
                    .font(font1) // 完美套用 AppKit 自定义字体 1
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(String(format: "%.3f天", days))
                    .font(font2) // 完美套用 AppKit 自定义字体 2
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22) // 严格贴合标准的菜单栏活跃区内容高度限制
    }
}

private extension CGFloat {
    static func random(in range: ClosedRange<CGFloat>) -> CGFloat {
        return CGFloat(Double.random(in: Double(range.lowerBound)...Double(range.upperBound)))
    }
}

// MARK: - NSPopoverDelegate

extension StatusBarManager: NSPopoverDelegate {
    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        // 如果系统颜色面板是打开的，阻断 NSPopover 失去焦点时自动关闭的行为
        if NSColorPanel.shared.isVisible {
            return false
        }
        return true
    }
}
