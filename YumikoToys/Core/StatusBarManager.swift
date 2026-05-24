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
        // 初始宽度设为 280，高度交由 AdaptiveHostingController 运行时根据 SwiftUI 内容动态自适应
        popover.contentSize = NSSize(width: 280, height: 100)
        popover.behavior = .transient
        popover.animates = true
        
        // 【修复】根据当前主题色设置 popover 外观
        let themeColor = DependencyContainer.shared.settingsService.settings.selectedThemeColor
        popover.appearance = themeColor.isDarkTheme ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        
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
        eventMonitor = EventMonitor(mask: mask) { [weak self] (_: NSEvent?) in
            if let self = self, self.popover?.isShown == true {
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
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 延迟 2.0 秒（即动画完全播放结束）
            
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
            .map { $0.statusBarIconStyle }
            .removeDuplicates()
            .sink { [weak self] style in
                self?.currentIconStyle = style
                if !(self?.container.preventSleepService.isPreventSleepEnabled ?? false) {
                    self?.updateStatusBarIcon()
                }
                LoggerService.shared.info("Status bar icon updated to style: \(style.displayName)")
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
        self.currentLine1 = container.anniversaryService.activeAnniversaryInfo?.anniversary.parsedStatusBarLine1(days: days) ?? "兔可可已到来"
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
        popover?.performClose(nil)
        eventMonitor?.stop()
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
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        let idealSize = self.view.fittingSize
        if idealSize.width > 0 && idealSize.height > 0 {
            if popover?.contentSize.height != idealSize.height {
                popover?.contentSize = idealSize
            }
        }
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
    }
    
    @State private var particles: [EmojiParticle] = []
    @State private var startDate = Date()
    
    private let emojiPresets = ["🐰", "🥕", "🐱", "🐶", "🐹", "🦊", "🐼", "🐸", "🐻", "🐾", "🥕", "🐰"]
    
    var body: some View {
        GeometryReader { geo in
            if !particles.isEmpty {
                TimelineView(.animation(minimumInterval: 0.016)) { context in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    
                    ZStack {
                        ForEach(particles) { p in
                            let currentY = p.startY + p.speed * CGFloat(elapsed)
                            let currentRotation = p.startRotation + p.rotationSpeed * elapsed
                            
                            Text(p.emoji)
                                .font(.system(size: 32 * p.scale))
                                .rotationEffect(.degrees(currentRotation))
                                .position(x: p.xRatio * geo.size.width, y: currentY)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startDate = Date()
            let count = 45
            
            particles = (0..<count).map { _ in
                EmojiParticle(
                    emoji: emojiPresets.randomElement()!,
                    xRatio: CGFloat.random(in: 0.02...0.98),
                    startY: CGFloat.random(in: -150...(-50)),
                    speed: CGFloat.random(in: 450...780),
                    scale: CGFloat.random(in: 0.6...1.3),
                    startRotation: Double.random(in: 0...360),
                    rotationSpeed: Double.random(in: 120...240)
                )
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
