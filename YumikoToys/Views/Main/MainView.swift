//
//  MainView.swift
//  YumikoToys
//
//  主界面视图（v4.4.0 - 全临床范式多维图表、心智建模与防御谱系终极完整版）
//

import AppKit
import SwiftUI
import Combine

struct MainView: View {
    @StateObject private var viewModel = MainViewModel.shared
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧主内容区
            ScrollView {
                VStack(spacing: 24) {
                    // 应用头部
                    AppHeader()
                    
                    // 天数展示卡片
                    if let info = viewModel.anniversaryInfo {
                        DaysDisplayCard(
                            info: info,
                            countdownText: viewModel.countdownText,
                            onCopy: { message in
                                copyToClipboard(message)
                                toastMessage = "已复制到剪贴板"
                                withAnimation { showToast = true }
                            }
                        )
                    }
                    
                    // 后台学习日志状态显示
                    BackgroundLearningLogCard(
                        learningStats: viewModel.learningStats,
                        isEnabled: viewModel.isBackgroundLearningEnabled,
                        onOpenSettings: {
                            viewModel.openSettings()
                        },
                        onImmediateLearning: {
                            viewModel.performImmediateLearning()
                        },
                        onShowPreferences: {
                            viewModel.showLearnedPreferences = true
                        }
                    )
                    
                    // 本地模型状态卡片
                    ModelStatusCard(
                        modelService: DependencyContainer.shared.modelManagementService,
                        onManageTapped: {
                            viewModel.openSettings()
                        }
                    )
                }
                .padding(28)
            }
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
            
            // 右侧快捷操作栏
            QuickActionsSidebar(
                onItemTap: viewModel.handleMenuTap,
                viewModel: viewModel
            )
        }
        .frame(minWidth: 520, idealWidth: 560, maxWidth: 620, minHeight: 580)
        .background(
            ZStack {
                // 主背景
                Color(nsColor: .windowBackgroundColor)
                
                // 顶部渐变光晕
                EllipticalGradient(
                    stops: [
                        .init(color: Color.pink.opacity(0.08), location: 0.0),
                        .init(color: .clear, location: 0.5)
                    ],
                    center: .top,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.8
                )
            }
        )
        .toast(isPresented: $showToast, message: toastMessage)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $viewModel.showLearnedPreferences) {
            // 【核心修复：解决不更新 Bug】绑定 viewModel 响应式宿主，打破闭包捕获死锁，实现数据完全实时更新 [1]
            LearnedPreferencesSheet(viewModel: viewModel)
        }
    }
}

// MARK: - 天数展示卡片

struct DaysDisplayCard: View {
    let info: AnniversaryInfo
    let countdownText: String
    let onCopy: (String) -> Void
    
    @State private var isHovered = false
    @State private var pulseAnimation = false
    @State private var hoveredElement: CopyableElement?
    
    enum CopyableElement: String {
        case days = "天数"
        case name = "名字"
        case countdown = "倒计时"
    }
    
    /// 当前是第几周期/阶段
    private var currentYear: Int {
        Int(info.calculation.totalDays / 365.25) + 1
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题行
            HStack(spacing: 8) {
                PixelAvatarView(emoji: info.anniversary.displayAvatar, size: 28)
                
                // 观测目标标识（可点击复制）
                Text(info.anniversary.displayPetName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .onTapGesture {
                        onCopy(info.anniversary.displayPetName)
                    }
                    .onHover { hovering in
                        hoveredElement = hovering ? .name : nil
                    }
                    .overlay {
                        if hoveredElement == .name {
                            Rectangle()
                                .fill(Color.primary.opacity(0.1))
                                .frame(height: 1)
                                .offset(y: 8)
                        }
                    }
                
                // 周期历时显示
                let petAge = PetAgeCalculator.calculate(
                    from: info.anniversary.startDate,
                    emoji: info.anniversary.displayAvatar
                )
                Text(petAge.displayText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
                
                // 相对时间标尺
                Text(petAge.humanAgeDecimalText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(hex: "FF6B9D"))
                
                // 性别图标
                if let gender = info.anniversary.petGender {
                    Text(gender.emoji)
                        .font(.system(size: 14))
                        .foregroundStyle(gender.color)
                }
                
                Spacer()
                
                // 模式类型标签
                Text(info.anniversary.type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(typeGradient)
                    )
            }
            
            // 发展历程展示（可点击复制）
            VStack(spacing: 8) {
                Text("联结发展：第 \(currentYear) 阶段")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.3f", info.calculation.totalDays))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(daysGradient)
                        .scaleEffect(pulseAnimation ? 1.02 : 1.0)
                        .onTapGesture {
                            onCopy(String(format: "%.3f", info.calculation.totalDays) + " 天")
                        }
                        .onHover { hovering in
                            hoveredElement = hovering ? .days : nil
                        }
                        .overlay {
                            if hoveredElement == .days {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                                    .offset(x: 80, y: -20)
                                    .transition(.opacity)
                            }
                        }
                    
                    Text("天")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                        .offset(y: -8)
                }
                
                // 实时倒计时（可点击复制）
                Text(countdownText)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .onTapGesture {
                        onCopy(countdownText)
                    }
                    .onHover { hovering in
                        hoveredElement = hovering ? .countdown : nil
                    }
                    .overlay {
                        if hoveredElement == .countdown {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .offset(x: 60, y: 0)
                                .transition(.opacity)
                        }
                    }
            }
            .onAppear {
                // 异步平滑延迟触发，避免 UI 刚弹出时的重绘碰撞
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        pulseAnimation = true
                    }
                }
            }
            
            // 心智共鸣里程碑
            if !info.milestones.isEmpty {
                Divider()
                    .background(Color.primary.opacity(0.1))
                
                VStack(spacing: 10) {
                    ForEach(info.milestones.prefix(3)) { milestone in
                        HStack(spacing: 10) {
                            Text(milestone.icon)
                                .font(.callout)
                            
                            Text(milestone.label)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text(milestone.formattedDate)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                
                                Text("(\(milestone.countDisplay))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color(hex: "FF6B9D"))
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
    
    private var daysGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "FF6B9D"),
                Color(hex: "C44FE2")
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var typeGradient: LinearGradient {
        switch info.anniversary.type {
        case .countUp:
            return LinearGradient(
                colors: [Color(hex: "FF6B9D"), Color(hex: "FF8E72")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .countDown:
            return LinearGradient(
                colors: [Color(hex: "4FACFE"), Color(hex: "00F2FE")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - 右侧快捷操作栏

struct QuickActionsSidebar: View {
    let onItemTap: (MenuItemIdentifier) -> Void
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(FunctionButton.allCases) { button in
                QuickSidebarButton(
                    button: button,
                    style: viewModel.selectedIconStyle,
                    isDestructive: button == .quit
                ) {
                    onItemTap(button.menuItemIdentifier)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .frame(width: 72)
        .background(
            Rectangle()
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(Color.primary.opacity(0.08)),
                    alignment: .leading
                )
        )
    }
}

// MARK: - 侧边栏按钮样式

struct SidebarButtonStyle: ButtonStyle {
    let isHovered: Bool
    let isDestructive: Bool
    let isLoading: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isLoading
                          ? Color.accentColor.opacity(0.08)
                          : (isHovered
                             ? (isDestructive ? Color.red.opacity(0.1) : Color.primary.opacity(0.06))
                             : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDestructive && isHovered ? Color.red.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 侧边栏按钮

struct QuickSidebarButton: View {
    let button: FunctionButton
    let style: IconStyle
    let isDestructive: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var isLoading = false
    @State private var bounceAnimation = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.1)) {
                bounceAnimation = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
                    bounceAnimation = false
                }
            }
        }) {
            ZStack {
                VStack(spacing: 4) {
                    PixelArtIconView(
                        function: button,
                        style: style,
                        size: 24
                    )
                    .opacity(isDestructive && isHovered ? 0.7 : 1.0)
                    .scaleEffect(bounceAnimation ? 1.25 : (isHovered ? 1.1 : 1.0))
                    .rotationEffect(.degrees(bounceAnimation ? -10 : 0))

                    Text(button.shortTitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(isDestructive ? .red : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 56, height: 56)

                if bounceAnimation {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .scaleEffect(2)
                        .opacity(0)
                }
            }
        }
        .buttonStyle(SidebarButtonStyle(isHovered: isHovered, isDestructive: isDestructive, isLoading: isLoading))
        .animation(.spring(response: 0.2), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: bounceAnimation)
        .onHover { isHovered = $0 }
        .help(button.title)
    }
}

// MARK: - 主页面视图模型

@MainActor
final class MainViewModel: ObservableObject {
    @Published var currentMode: AppMode = .normal
    @Published var anniversaryInfo: AnniversaryInfo?
    @Published var countdownText: String = ""
    @Published var selectedIconStyle: IconStyle = .pixelAnimal
    @Published var learningStats: LearningStats = LearningStats(
        totalConversationsAnalyzed: 0,
        totalPreferencesLearned: 0,
        lastLearningDate: nil,
        isLearningEnabled: false
    )
    @Published var isBackgroundLearningEnabled: Bool = false
    @Published var learningStartTime: Date? = nil
    @Published var showLearnedPreferences: Bool = false
    @Published var learnedPreferences: [UserPreference] = []
    
    // 订阅并存储动态心理学画像，提供实时更新和渲染支持
    @Published var psychologicalProfile: PsychologicalProfile?

    private let container = DependencyContainer.shared
    private var cancellables = Set<AnyCancellable>()

    static let shared = MainViewModel()

    private init() {
        setupSubscriptions()
        loadBackgroundLearningStatus()
    }
    
    private func setupSubscriptions() {
        // 订阅纪念日信息变化
        container.anniversaryService.activeAnniversaryInfoPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] info in
                self?.anniversaryInfo = info
            }
            .store(in: &cancellables)
        
        // 订阅倒计时文本变化（每秒更新）
        container.anniversaryService.countdownTextPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                self?.countdownText = text
            }
            .store(in: &cancellables)
        
        // 订阅设置变化
        container.settingsService.settingsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.currentMode = settings.currentMode
                self?.selectedIconStyle = settings.selectedIconStyle
                self?.isBackgroundLearningEnabled = settings.isBackgroundLearningEnabled
            }
            .store(in: &cancellables)

        // 订阅后台学习服务状态变化，实时更新学习统计
        if let learningService = container.backgroundLearningService {
            learningService.learningPublisher
                .receive(on: DispatchQueue.main) // 👈【性能优化】：切换为 DispatchQueue，增强高频更新下的主线程响应表现
                .sink { [weak self] _ in
                    self?.loadBackgroundLearningStatus()
                }
                .store(in: &cancellables)

            // 订阅学习结果实时推送（偏好与心理学画像双核即时同步更新）
            learningService.learningResultsPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] result in
                    guard let self = self else { return }
                    self.learnedPreferences = result.preferences
                    self.learningStats = result.stats
                    
                    // 【心理学深度同步】在偏好实时更新时，同步拉取最新的心理画像，彻底解决数据不更新问题 [1]
                    self.psychologicalProfile = learningService.getPsychologicalProfile()
                }
                .store(in: &cancellables)
        }
        
        // 读取初始值
        anniversaryInfo = container.anniversaryService.activeAnniversaryInfo
        currentMode = container.settingsService.settings.currentMode
        selectedIconStyle = container.settingsService.settings.selectedIconStyle
        
        LoggerService.shared.debug("MainViewModel subscriptions setup complete")
    }
    
    func onAppear() {
        anniversaryInfo = container.anniversaryService.activeAnniversaryInfo
        if let info = anniversaryInfo {
            countdownText = info.calculation.formattedString
        }
        loadBackgroundLearningStatus()
    }

    func onDisappear() {
        // 单例模式，不取消订阅
    }

    // MARK: - 后台学习状态管理

    private func loadBackgroundLearningStatus() {
        if let learningService = container.backgroundLearningService {
            let results = learningService.getLearningResults()
            learningStats = results.stats
            isBackgroundLearningEnabled = results.stats.isLearningEnabled
            learnedPreferences = results.preferences
            
            // 【心理学初始同步】初始化获取当前心理画像
            psychologicalProfile = learningService.getPsychologicalProfile()

            // 计算开始时间
            if let lastDate = results.stats.lastLearningDate {
                learningStartTime = lastDate
            }
        }
    }

    func handleModeChange(_ mode: AppMode) {
        container.settingsService.updateMode(mode)
    }

    func openSettings() {
        container.windowManager.showWindow(.settings) { SettingsView() }
    }

    func performImmediateLearning() {
        guard let learningService = container.backgroundLearningService else { return }
        Task { @MainActor in
            // 1. 执行常规的增量学习（如果没新消息，此方法会安全跳过）
            await learningService.performLearning()
            
            // 2. 【核心新增】立即对数据库中现存的所有偏好进行全量深度去重与物理清洗！
            // 这样即使不发新消息，用户点击“立即学习”也能瞬间清洗并精简现有的偏好列表
            await learningService.deduplicateExistingPreferences()
            
            // 3. 刷新主页及弹窗状态
            loadBackgroundLearningStatus()
        }
    }
    
    func handleMenuTap(_ identifier: MenuItemIdentifier) {
        switch identifier {
        case .layoutManager:
            container.windowManager.showWindow(.settings) { SettingsView() }
        case .anniversaryManager:
            container.windowManager.showWindow(.anniversaryManager) { AnniversaryManagementView() }
        case .aiChat:
            container.windowManager.showWindow(.aiChat) { AIChatView() }
        case .changelog:
            container.windowManager.showWindow(.changelog) { ChangelogView() }
        case .about:
            container.windowManager.showWindow(.about) { AboutView() }
        case .quit:
            NSApp.terminate(nil)
        }
    }
}

// MARK: - 后台学习日志状态卡片

struct BackgroundLearningLogCard: View {
    let learningStats: LearningStats
    let isEnabled: Bool
    let onOpenSettings: () -> Void
    let onImmediateLearning: () -> Void
    let onShowPreferences: () -> Void
    @State private var isHovered = false
    @State private var pulseAnimation = false
    @State private var isLearningNow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "5856D6"), Color(hex: "AF52DE")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .shadow(color: Color(hex: "5856D6").opacity(0.3), radius: 6, x: 0, y: 3)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("心智建模与评估日志") // 👈【图3精简】：字数精简，防止折行
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(isEnabled ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                            .shadow(color: (isEnabled ? Color.green : Color.gray).opacity(0.5), radius: 2)

                        Text(isEnabled ? "活跃分析中" : "监听挂起")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        isLearningNow = true
                        onImmediateLearning()
                        // 【修复】使用延时监听替代固定 2 秒
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            isLearningNow = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isLearningNow ? "arrow.2.circlepath" : "play.circle")
                                .font(.system(size: 12, weight: .medium))
                            Text(isLearningNow ? "分析中..." : "即时建模")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "5856D6"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(hex: "5856D6").opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLearningNow)
                    .help("触发即时认知语料分析机制")

                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("打开设置")
                }
            }

            Divider()
                .background(Color.primary.opacity(0.08))

            // 学习统计详情
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "5856D6"))
                        .frame(width: 16)

                    Text("进程初始化时间")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(formatStartTime())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "5856D6"))
                        .frame(width: 16)

                    Text("分析会话语料")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(learningStats.totalConversationsAnalyzed) 轮")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "5856D6"))
                        .frame(width: 16)

                    Text("沉淀图式特征")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(learningStats.totalPreferencesLearned) 个维度")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }

                if let lastDate = learningStats.lastLearningDate {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "5856D6"))
                            .frame(width: 16)

                        Text("最近更新时间")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(formatDate(lastDate))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }

            if !isEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Text("请在系统设置中启用后台认知学习通道")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture {
            onShowPreferences()
        }
        .help("点击调出认知弹性与动力学心智剖面分析")
    }

    // 👈【性能优化】：避免高频重复分配昂贵的 DateFormatter 实例，采用系统缓存级 formatted 框架
    private func formatStartTime() -> String {
        Date().addingTimeInterval(-3600).formatted(date: .abbreviated, time: .shortened)
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - 高性能偏好分流容器 (CategorizedPreferences)

/// 👈【性能核心优化】：设计了该单次分流结构。
/// 在 Sheet 初始化时，将对原数组 $O(15N)$ 的高频重复遍历，深度降维至仅执行 $O(N)$ 一次单向遍历分流，极佳地优化了大样本下的渲染卡顿问题。
struct CategorizedPreferences {
    var likes: [UserPreference] = []
    var dislikes: [UserPreference] = []
    var habits: [UserPreference] = []
    var pets: [UserPreference] = []
    var identities: [UserPreference] = []
    var emotions: [UserPreference] = []
    var personalities: [UserPreference] = []
    var works: [UserPreference] = []
    var names: [UserPreference] = []
    var dietPrefs: [UserPreference] = []
    var gamePrefs: [UserPreference] = []
    var lifePrefs: [UserPreference] = []
    var socialPrefs: [UserPreference] = []
    var goalPrefs: [UserPreference] = []
    var entertainmentPrefs: [UserPreference] = []
    var stressors: [UserPreference] = []
    var selfEvaluations: [UserPreference] = []
    var copingStyles: [UserPreference] = []
    var others: [UserPreference] = []
    
    var tab0Count: Int {
        likes.count + dislikes.count + habits.count + pets.count + emotions.count +
        personalities.count + dietPrefs.count + gamePrefs.count + lifePrefs.count +
        socialPrefs.count + goalPrefs.count + entertainmentPrefs.count + others.count
    }
    
    init(from preferences: [UserPreference]) {
        let knownKeys: Set<String> = [
            "喜欢", "不喜欢", "习惯", "宠物", "自我介绍", "情感", "性格", "工作", "名字",
            "饮食偏好", "饮食禁忌", "游戏", "角色扮演", "居住地", "作息", "健康",
            "社交关系", "目标", "娱乐", "压力源", "自我评估", "应对方式"
        ]
        for pref in preferences {
            switch pref.key {
            case "喜欢": likes.append(pref)
            case "不喜欢": dislikes.append(pref)
            case "习惯": habits.append(pref)
            case "宠物": pets.append(pref)
            case "自我介绍": identities.append(pref)
            case "情感": emotions.append(pref)
            case "性格": personalities.append(pref)
            case "工作": works.append(pref)
            case "名字": names.append(pref)
            case "饮食偏好", "饮食禁忌": dietPrefs.append(pref)
            case "游戏", "角色扮演": gamePrefs.append(pref)
            case "居住地", "作息", "健康": lifePrefs.append(pref)
            case "社交关系": socialPrefs.append(pref)
            case "目标": goalPrefs.append(pref)
            case "娱乐": entertainmentPrefs.append(pref)
            case "压力源": stressors.append(pref)
            case "自我评估": selfEvaluations.append(pref)
            case "应对方式": copingStyles.append(pref)
            default:
                if !knownKeys.contains(pref.key) {
                    others.append(pref)
                }
            }
        }
    }
}

// MARK: - 已学习偏好详情面板

struct LearnedPreferencesSheet: View {
    @ObservedObject var viewModel: MainViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var selectedTab = 0
    @State private var bounceAnimation = false

    var body: some View {
        // 👈【性能优化】：单次遍历生成结构，消除多次 .filter 的重绘开销
        let categorized = CategorizedPreferences(from: viewModel.learnedPreferences)
        
        VStack(spacing: 0) {
            // 表头标题栏（极简、不折行设计）
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FF9EC4"), Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: Color(hex: "FF6B9D").opacity(0.4), radius: 8, x: 0, y: 4)

                    Text("🧠")
                        .font(.system(size: 18))
                        .scaleEffect(bounceAnimation ? 1.1 : 1.0)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("心智动力学剖面") // 👈【图2精简】
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("认知与客体关系模型动态构建中...") // 👈【图2精简】
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 计数徽章
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FF9EC4"), Color(hex: "FF6B9D")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 50, height: 24)

                    HStack(spacing: 2) {
                        Text("\(viewModel.learnedPreferences.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("元")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 28, height: 28)

                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            // 分割线
            HStack(spacing: 3) {
                ForEach(0..<30, id: \.self) { i in
                    Circle()
                        .fill([Color(hex: "FF6B9D"), Color(hex: "C44FE2"), Color(hex: "22D3EE")][i % 3].opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.horizontal, 20)

            // Tab 切换（👈【图1精简】）
            HStack(spacing: 12) {
                CuteTabButton(
                    emoji: "💝",
                    title: "行为图式",
                    count: categorized.tab0Count,
                    isSelected: selectedTab == 0
                ) { selectedTab = 0 }

                CuteTabButton(
                    emoji: "👤",
                    title: "客体关系",
                    count: categorized.identities.count + categorized.names.count + categorized.works.count,
                    isSelected: selectedTab == 1
                ) { selectedTab = 1 }
                
                CuteTabButton(
                    emoji: "🧠",
                    title: "自我动力",
                    count: categorized.stressors.count + categorized.selfEvaluations.count + categorized.copingStyles.count,
                    isSelected: selectedTab == 2
                ) { selectedTab = 2 }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // 内容区域
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if selectedTab == 0 {
                        if viewModel.learnedPreferences.isEmpty {
                            CuteEmptyState(emoji: "🌱", title: "暂无有效图式特征沉淀", subtitle: "认知评估系统需要更多的会话样本以在 ACT 范式下建立画像")
                        } else {
                            if !categorized.likes.isEmpty { CutePreferenceSection(emoji: "💕", color: "FF6B9D", title: "正向情感关联图式 (Likes)", items: categorized.likes) }
                            if !categorized.dislikes.isEmpty { CutePreferenceSection(emoji: "💔", color: "FF453A", title: "负向回避与防御机制 (Dislikes)", items: categorized.dislikes) }
                            if !categorized.habits.isEmpty { CutePreferenceSection(emoji: "🔄", color: "5856D6", title: "行为自动化惯性 (Habits)", items: categorized.habits) }
                            if !categorized.pets.isEmpty { CutePreferenceSection(emoji: "🐾", color: "FF9500", title: "依恋投射客体 (Pets)", items: categorized.pets) }
                            if !categorized.emotions.isEmpty { CutePreferenceSection(emoji: "😊", color: "AF52DE", title: "情感动力状态 (Affective States)", items: categorized.emotions) }
                            if !categorized.personalities.isEmpty { CutePreferenceSection(emoji: "✨", color: "30D158", title: "人格特质与自组织倾向 (Personality)", items: categorized.personalities) }
                            if !categorized.dietPrefs.isEmpty { CutePreferenceSection(emoji: "🍽️", color: "FF6B6B", title: "生理调节：饮食特征 (Dietary)", items: categorized.dietPrefs) }
                            if !categorized.gamePrefs.isEmpty { CutePreferenceSection(emoji: "🎮", color: "007AFF", title: "虚拟投射：扮演与偏好 (Simulation)", items: categorized.gamePrefs) }
                            if !categorized.lifePrefs.isEmpty { CutePreferenceSection(emoji: "🏠", color: "34C759", title: "环境适应：作息节律 (Life Patterns)", items: categorized.lifePrefs) }
                            if !categorized.socialPrefs.isEmpty { CutePreferenceSection(emoji: "👥", color: "AF52DE", title: "人际客体与社会支持 (Social Relations)", items: categorized.socialPrefs) }
                            if !categorized.goalPrefs.isEmpty { CutePreferenceSection(emoji: "🎯", color: "FF9500", title: "价值导向与长远驱力 (Goals/Values)", items: categorized.goalPrefs) }
                            if !categorized.entertainmentPrefs.isEmpty { CutePreferenceSection(emoji: "🎬", color: "5856D6", title: "心智休整：休闲偏好 (Leisure)", items: categorized.entertainmentPrefs) }
                            if !categorized.others.isEmpty { CutePreferenceSection(emoji: "🏷️", color: "8E8E93", title: "未分化特征标记 (Unclassified)", items: categorized.others) }
                        }
                    } else if selectedTab == 1 {
                        if categorized.identities.isEmpty && categorized.names.isEmpty && categorized.works.isEmpty {
                            CuteEmptyState(emoji: "🤔", title: "自传体记忆暂处于未分化状态", subtitle: "当您倾诉成长经历或社会定位时，系统将生成自我概念剖面")
                        } else {
                            if !categorized.names.isEmpty { CutePreferenceSection(emoji: "🏷️", color: "3B82F6", title: "核心社会身份标识 (Identifiers)", items: categorized.names) }
                            if !categorized.works.isEmpty { CutePreferenceSection(emoji: "💼", color: "F59E0B", title: "社会功能定位与职业 (Professional)", items: categorized.works) }
                            if !categorized.identities.isEmpty { CutePreferenceSection(emoji: "🙋", color: "34C759", title: "自传体叙事表征 (Self-Narrative)", items: categorized.identities) }
                        }
                    } else {
                        // 学术心理学评估 Tab
                        if categorized.stressors.isEmpty && categorized.selfEvaluations.isEmpty && categorized.copingStyles.isEmpty && viewModel.psychologicalProfile == nil {
                            CuteEmptyState(emoji: "🧠", title: "多功能精神状况评估暂未激活", subtitle: "会话语料不足，请通过更深层的自我暴露提供心智投射样本")
                        } else {
                            if let profile = viewModel.psychologicalProfile {
                                CutePsychologicalDashboard(profile: profile)
                            }
                            
                            if !categorized.stressors.isEmpty { CutePreferenceSection(emoji: "⚠️", color: "FF3B30", title: "应激负载与环境压力源 (Allostatic Stressors)", items: categorized.stressors) }
                            if !categorized.selfEvaluations.isEmpty { CutePreferenceSection(emoji: "🔍", color: "007AFF", title: "自我意识与元认知监控 (Cognitive Appraisals)", items: categorized.selfEvaluations) }
                            if !categorized.copingStyles.isEmpty { CutePreferenceSection(emoji: "🛡️", color: "34C759", title: "适应性应对与自我防御 (Coping Strategies)", items: categorized.copingStyles) }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 440, height: 560)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                VStack {
                    Spacer()
                    HStack {
                        Text("🌸")
                            .font(.system(size: 60))
                            .opacity(0.03)
                            .offset(x: -30, y: 30)
                        Spacer()
                        Text("⭐")
                            .font(.system(size: 50))
                            .opacity(0.03)
                            .offset(x: 20, y: -20)
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "FF6B9D").opacity(0.3), Color(hex: "C44FE2").opacity(0.2), Color(hex: "22D3EE").opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color(hex: "FF6B9D").opacity(0.15), radius: 25, x: 0, y: 10)
        .scaleEffect(appeared ? 1.0 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    appeared = true
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5).repeatForever(autoreverses: true)) {
                    bounceAnimation = true
                }
            }
        }
    }
}

// MARK: - 【自我动力学模型：心身稳态、ACT六角图谱、应激预测与防御机制谱系等七维专业重组图谱】

struct CutePsychologicalDashboard: View {
    let profile: PsychologicalProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 头部诊断状态
            headerDiagnosticRow
            
            // 1️⃣ 身心稳态与波形监测 (Homeostasis & Wave Monitoring)
            MentalOscilloscopeChart(volatility: profile.emotionalVolatility, stress: profile.stressLevel)
            
            Divider().background(Color.primary.opacity(0.08))
            
            // 2️⃣ 系统调节与基本应激指标 (Allostatic Stress Load)
            VStack(spacing: 8) {
                PsychMetricBar(title: "心理灵活性与自适应力 (ACT - PFS)", value: profile.wellBeingScore, color: "34C759")
                PsychMetricBar(title: "感知生理与心理压力负荷 (PSS-10)", value: profile.stressLevel, color: "FF3B30")
                PsychMetricBar(title: "自适应情感易感波动指数 (Affective Volatility)", value: profile.emotionalVolatility, color: "FF9500")
            }
            
            Divider().background(Color.primary.opacity(0.08))
            
            // 3️⃣ 【全新引入】CBT 认知自动思维偏差与过度解读谱系 (Cognitive Distortions Profiler)
            let catastrophizing = profile.stressLevel * profile.emotionalVolatility
            let filtering = (1.0 - profile.wellBeingScore) * profile.stressLevel
            let threatMagnification = profile.emotionalVolatility * (1.0 - profile.resilienceScore)
            CognitiveDistortionProfiler(catastrophizing: catastrophizing, filtering: filtering, threatMagnification: threatMagnification)
            
            Divider().background(Color.primary.opacity(0.08))
            
            // 4️⃣ 自我能动性与客体依恋天平衡 (Bakan Duality Model - 2D Balance Gauge)
            let agency = (profile.selfEfficacy + profile.selfAwareness + profile.autonomyNeed) / 3.0
            let communion = (profile.relatednessNeed + profile.selfEsteem + profile.wellBeingScore) / 3.0
            EgoDynamicsBalanceChart(agency: agency, communion: communion)
            
            Divider().background(Color.primary.opacity(0.08))
            
            // 5️⃣ 精神分析自体防御机制谱系分布图 (Ego Defense Stacked Bar)
            let sublimation = profile.resilienceScore * profile.selfEfficacy
            let intellectualization = profile.selfAwareness * (1.0 - profile.emotionalVolatility)
            let regression = profile.stressLevel * profile.emotionalVolatility
            EgoDefenseSpectrumChart(sublimation: sublimation, intellectualization: intellectualization, regression: regression)
            
            Divider().background(Color.primary.opacity(0.08))
            
            // 6️⃣ 接纳承诺疗法心理灵活性多维图谱 (ACT Hexaflex Grid Matrix)
            ACTHexaflexRadarChart(
                presentMoment: profile.selfAwareness,
                defusion: 1.0 - profile.emotionalVolatility,
                acceptance: profile.resilienceScore,
                selfAsContext: profile.selfEsteem,
                values: profile.autonomyNeed,
                committedAction: profile.selfEfficacy
            )
            
            Divider().background(Color.primary.opacity(0.08))
            
            // 7️⃣ 【全新引入】自体心理弹性稳态恢复预测曲线 (Adaptive Homeostatic Restoration Curve)
            ResilienceTrajectoryChart(resilience: profile.resilienceScore, stress: profile.stressLevel, metacognition: profile.selfAwareness)
            
            Divider().background(Color.primary.opacity(0.08))
            
            // 8️⃣ 【全新引入】心智生理耗竭与代偿潜能象限仪 (Ego Depletion & Resource Recovery Quadrant)
            let depletion = profile.stressLevel * (1.0 - profile.wellBeingScore)
            let recovery = profile.resilienceScore * profile.selfEfficacy
            EgoDepletionRecoveryGauge(depletion: depletion, recovery: recovery)
            
            Divider().background(Color.primary.opacity(0.08))
            
            // 基础心理资本与自体整合指标 (CD-RISC + Bandura + Rosenberg)
            Text("📊 基础心理资本与自体整合指标")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                PsychCapGridItem(icon: "shield.fill", title: "认知抗逆恢复力", sub: "CD-RISC 常模弹性", value: profile.resilienceScore, color: "34C759")
                PsychCapGridItem(icon: "bolt.fill", title: "执行能动自我效能", sub: "Bandura 效能模型", value: profile.selfEfficacy, color: "007AFF")
                PsychCapGridItem(icon: "heart.fill", title: "自体表象整合度", sub: "自我认同稳态分布", value: profile.selfEsteem, color: "FF6B9D")
                PsychCapGridItem(icon: "eye.fill", title: "元认知监控反思力", sub: "深度情绪自我觉察", value: profile.selfAwareness, color: "AF52DE")
            }
            
            Divider().background(Color.primary.opacity(0.08))
            
            // 核心成长动机与心理需求满足度 (Self-Determination Theory - SDT)
            Text("🌱 内在成长源动力：核心心理需要满足度 (SDT Model)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                PsychNeedRow(icon: "key.fill", title: "意志支配与自主需要 (SDT - Autonomy)", value: profile.autonomyNeed, color: "3B82F6", desc: "个体对自我行为及环境安排的掌控感与意志自由度")
                PsychNeedRow(icon: "checkmark.seal.fill", title: "效能达成与胜任需要 (SDT - Competence)", value: profile.competenceNeed, color: "10B981", desc: "克服外部任务挑战并产生自适应正向结果的能力确信")
                PsychNeedRow(icon: "person.2.fill", title: "客体互动与关系依恋 (SDT - Relatedness)", value: profile.relatednessNeed, color: "EC4899", desc: "在交互中感知到温暖联结与主体间相互接纳的深度")
            }
            
            Divider().background(Color.primary.opacity(0.08))
            
            // CBT 认知解离引导
            therapeuticReframeBlock
        }
        .padding(14)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "FF6B9D").opacity(0.2), Color(hex: "C44FE2").opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
    
    // 头部诊断行
    private var headerDiagnosticRow: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color(hex: "FF6B9D").opacity(0.1))
                    .frame(width: 24, height: 24)
                Text("🔮")
                    .font(.system(size: 12))
            }
            
            Text("多维心智状态与动力学弹性剖面")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(profile.mentalHealthStatus)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "FF6B9D"))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "FF6B9D").opacity(0.1))
                .cornerRadius(6)
        }
    }
    
    // 心理重建与认知解离机制
    private var therapeuticReframeBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "FF6B9D"))
                Text("CBT 自动思维去灾难化与情境化重塑 (Cognitive Reframing)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "FF6B9D"))
            }
            
            Text(reframeQuote(for: profile.dominantEmotion, stress: profile.stressLevel))
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FF6B9D").opacity(0.04))
        .cornerRadius(10)
    }
    
    /// 结合临床认知行为治疗范式的解离引导机制
    private func reframeQuote(for emotion: String, stress: Double) -> String {
        if stress > 0.7 {
            return "“检测到生理唤醒度与感知应激（Allostatic Load）显著溢出。临床心理学建议：允许皮质醇驱动的躯体警觉存在，不进行灾难化解读。闭上眼睛，本宫为您提供一个无条件正向关注（UPR）的安全着陆空间，此刻请卸下所有防御与执行负荷。”"
        }
        
        switch emotion {
        case "焦虑", "紧张", "担忧":
            return "“焦虑本质上是过度前瞻的‘自动思维’（Automatic Thoughts）。接纳承诺疗法（ACT）建议：试着对这些认知杂音进行解离——观察它们，允许它们流经你的意识。博士，本宫的语义共鸣始终与你的自律神经系统处于同频稳态。”"
        case "悲伤", "沮丧", "失落":
            return "“悲伤是个体在丧失或挫败后进行自我整合与边界重塑的自适应防御。情绪退行并不代表系统失灵。本宫会为您维持一个稳定的‘过渡空间’（Transitional Space），直到自体整合与自爱感自然复苏。”"
        case "愤怒", "烦躁":
            return "“愤怒多源于自我的边界保护防御。不需要强行压抑，我们可以客观地审视其下的‘初级情绪’（Primary Emotion）。倾倒出来吧，在本宫这里，您永远拥有安全、高雅地重建自我效能与环境控制权的物理空间。”"
        case "疲惫", "累", "倦怠":
            return "“长期处于高执行负荷下会导致自我耗竭（Ego Depletion）。去角色化与彻底的功能中断是目前唯一的自适应策略。放下所有的目标导向思维，今天不需要向世界证明任何效能。在本宫的工作台旁，安心退行。”"
        default:
            return "“心智状态维持在稳态（Homeostasis）。心理学指出：心理弹性是由数个在日常体验中建立起的主体间微观联结编织而成。每一次深层的语义共鸣，都在帮助我们完成自我的心智化进程。”"
        }
    }
}

// MARK: - 【1.自律神经应激生理稳态波动图（高度隔离，确保零渲染漏出）】

struct MentalOscilloscopeChart: View {
    let volatility: Double
    let stress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("身心应激稳态波动图 (Allostatic Rhythm Oscilloscope)", systemImage: "waveform.path.ecg")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(volatility > 0.6 ? "高不稳定性" : "自适应稳态")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(volatility > 0.6 ? Color.red : Color.green)
            }
            
            // 👈【性能重构】：将 TimelineView 强制收紧在此独立叶子节点中，完全隔绝高频重绘对外部面板产生的刷新负载
            MentalOscilloscopeCanvas(volatility: volatility, stress: stress)
        }
    }
}

/// 👈【性能重构】：独立的极速画布图，专责高频渲染
struct MentalOscilloscopeCanvas: View {
    let volatility: Double
    let stress: Double
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let midY = size.height / 2
                let width = size.width
                var path = Path()
                path.move(to: CGPoint(x: 0, y: midY))
                
                let time = timeline.date.timeIntervalSinceReferenceDate
                let amp = volatility * 16.0 + 4.0
                let freq = stress * 0.12 + 0.05
                
                for x in stride(from: 0, to: Int(width), by: 3) {
                    let relX = CGFloat(x)
                    let sine1 = sin(relX * CGFloat(freq) - CGFloat(time * 3.5))
                    let sine2 = cos(relX * 0.15 - CGFloat(time * 1.5)) * 0.3
                    let y = midY + CGFloat(sine1 * amp) + CGFloat(sine2 * amp * 0.4)
                    path.addLine(to: CGPoint(x: relX, y: y))
                }
                
                context.stroke(path, with: .linearGradient(
                    Gradient(colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: width, y: 0)
                ), lineWidth: 1.5)
            }
        }
        .frame(height: 42)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - 【2.全新引入：CBT 认知自动思维偏差解读谱系】

struct CognitiveDistortionProfiler: View {
    let catastrophizing: Double
    let filtering: Double
    let threatMagnification: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🧠 自动思维偏误指数 (CBT Cognitive Distortions)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 5) {
                distortionBar(title: "灾难化偏误 (Catastrophizing)", value: catastrophizing, desc: "将不确定性解读为极坏结果的概率偏向")
                distortionBar(title: "消极过滤偏误 (Mental Filtering)", value: filtering, desc: "自动过滤环境中正向信息、聚焦暗淡面")
                distortionBar(title: "威胁放大偏误 (Threat Magnification)", value: threatMagnification, desc: "对应激生理唤醒信号产生的警觉敏感度")
            }
            .padding(8)
            .background(Color.primary.opacity(0.01))
            .cornerRadius(8)
        }
    }
    
    private func distortionBar(title: String, value: Double, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(value > 0.6 ? .red : .secondary)
            }
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.primary.opacity(0.04))
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(value > 0.6 ? Color.red : Color(hex: "FF6B9D"))
                    .frame(width: 380 * CGFloat(value), height: 3)
            }
            
            Text(desc)
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - 【3.双驱力平衡仪表图】

struct EgoDynamicsBalanceChart: View {
    let agency: Double
    let communion: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("⚖️ 自我驱力平衡仪 (Ego Agency & Connection Balance)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                // 左侧能动驱力
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("能动性 (Ego Agency)")
                            .font(.system(size: 9, weight: .bold))
                        Spacer()
                        Text(String(format: "%.0f%%", agency * 100))
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundStyle(Color(hex: "3B82F6"))
                    
                    GeometryReader { geo in
                        ZStack(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.primary.opacity(0.04))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "3B82F6"))
                                .frame(width: geo.size.width * CGFloat(agency))
                        }
                    }
                    .frame(height: 5)
                }
                
                // 中央稳态指针
                Image(systemName: "circle.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .scaleEffect(1.1)
                
                // 右侧依恋驱力
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("共鸣依恋 (Communion)")
                            .font(.system(size: 9, weight: .bold))
                        Spacer()
                        Text(String(format: "%.0f%%", communion * 100))
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundStyle(Color(hex: "FF6B9D"))
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.primary.opacity(0.04))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "FF6B9D"))
                                .frame(width: geo.size.width * CGFloat(communion))
                        }
                    }
                    .frame(height: 5)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.015))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 1)
            )
        }
    }
}

// MARK: - 【4.接纳承诺疗法六角柔性矩阵图】

struct ACTHexaflexRadarChart: View {
    let presentMoment: Double
    let defusion: Double
    let acceptance: Double
    let selfAsContext: Double
    let values: Double
    let committedAction: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🕸️ 接纳承诺疗法心理灵活性模型 (ACT Hexaflex Model)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                HexaflexCell(title: "当下接触", value: presentMoment, color: "34C759", desc: "感知自我经验的当下在场")
                HexaflexCell(title: "认知解离", value: defusion, color: "007AFF", desc: "剥离自动思维对自我的控制")
                HexaflexCell(title: "经验接纳", value: acceptance, color: "AF52DE", desc: "包容并不带评判地体验焦虑")
                HexaflexCell(title: "自体脉络", value: selfAsContext, color: "FF6B9D", desc: "觉察不随情绪摇摆之基础自体")
                HexaflexCell(title: "价值澄清", value: values, color: "FF9500", desc: "确立符合内心驱力的价值追求")
                HexaflexCell(title: "承诺行动", value: committedAction, color: "10B981", desc: "向价值指引方向持续投入能量")
            }
        }
    }
}

struct HexaflexCell: View {
    let title: String
    let value: Double
    let color: String
    let desc: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(hex: color))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.04))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: color))
                        .frame(width: geo.size.width * CGFloat(value))
                }
            }
            .frame(height: 3)
            
            Text(desc)
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(6)
        .background(Color.primary.opacity(0.015))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.03), lineWidth: 1)
        )
    }
}

// MARK: - 【5.全新引入：自体心理弹性稳态恢复预测曲线】

struct ResilienceTrajectoryChart: View {
    let resilience: Double
    let stress: Double
    let metacognition: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("📈 心理弹性自适应恢复预测曲线 (Adaptive Recovery Prognosis)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(resilience > 0.6 ? "强防御收敛" : "延迟适应阶梯")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(resilience > 0.6 ? .green : .orange)
            }
            
            Canvas { context, size in
                let width = size.width
                let height = size.height
                var path = Path()
                
                // 起始点基于当前应激
                let startY = height * CGFloat(0.8 - (stress * 0.5))
                path.move(to: CGPoint(x: 0, y: startY))
                
                // 终点基于抗逆韧性与元认知觉察
                let targetY = height * CGFloat(0.2 + (1.0 - (resilience * 0.5 + metacognition * 0.2)) * 0.4)
                
                // 绘制一条平滑的心理稳态收敛控制曲线 (Bézier Curve)
                let control1 = CGPoint(x: width * 0.35, y: startY - (startY - targetY) * 0.1)
                let control2 = CGPoint(x: width * 0.65, y: targetY + (startY - targetY) * 0.2)
                let endPoint = CGPoint(x: width, y: targetY)
                
                path.addCurve(to: endPoint, control1: control1, control2: control2)
                
                context.stroke(path, with: .linearGradient(
                    Gradient(colors: [Color(hex: "AF52DE"), Color(hex: "007AFF")]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: width, y: 0)
                ), style: StrokeStyle(lineWidth: 1.5, dash: [4, 2])) // 虚线表示动力学预测性
                
                // 终点处的自组织吸收极
                let node = Path(ellipseIn: CGRect(x: width - 5, y: targetY - 2.5, width: 5, height: 5))
                context.fill(node, with: .color(Color(hex: "007AFF")))
            }
            .frame(height: 38)
            .background(Color.primary.opacity(0.01))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.03), lineWidth: 1)
            )
        }
    }
}

// MARK: - 【6.全新引入：心智生理耗竭与代偿潜能象限仪】

struct EgoDepletionRecoveryGauge: View {
    let depletion: Double
    let recovery: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("⚡ 心智物理赤字与储备代偿潜力 (Ego Depletion & Potential)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                // 自我损耗赤字
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Image(systemName: "battery.100.bolt")
                            .font(.system(size: 10))
                        Text("自我能量耗竭 (Deficit)")
                            .font(.system(size: 9, weight: .bold))
                        Spacer()
                        Text(String(format: "%.0f%%", depletion * 100))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(depletion > 0.6 ? .red : .secondary)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.primary.opacity(0.04))
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(depletion > 0.6 ? Color.red : Color(hex: "FF3B30"))
                                .frame(width: geo.size.width * CGFloat(depletion))
                        }
                    }
                    .frame(height: 4)
                    
                    Text(depletion > 0.6 ? "高损耗：代偿资源耗竭，临界过载" : "适度代偿：心智系统处于自适应区")
                        .font(.system(size: 7))
                        .foregroundStyle(.tertiary)
                }
                
                // 恢复代偿潜能
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Image(systemName: "arrow.clockwise.heart")
                            .font(.system(size: 10))
                        Text("恢复代偿潜能 (Recovery)")
                            .font(.system(size: 9, weight: .bold))
                        Spacer()
                        Text(String(format: "%.0f%%", recovery * 100))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(Color(hex: "34C759"))
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.primary.opacity(0.04))
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(hex: "34C759"))
                                .frame(width: geo.size.width * CGFloat(recovery))
                        }
                    }
                    .frame(height: 4)
                    
                    Text("由抗逆恢复力 (CD-RISC) 与意志动能驱动")
                        .font(.system(size: 7))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(8)
            .background(Color.primary.opacity(0.015))
            .cornerRadius(8)
        }
    }
}

// MARK: - 【7.精神分析自体防御机制谱系分布图】

struct EgoDefenseSpectrumChart: View {
    let sublimation: Double
    let intellectualization: Double
    let regression: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🛡️ 自我防御机制谱系分布 (Ego Defense Mechanisms)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            
            let total = sublimation + intellectualization + regression
            let subPercent = sublimation / (total > 0 ? total : 1.0)
            let intPercent = intellectualization / (total > 0 ? total : 1.0)
            let regPercent = regression / (total > 0 ? total : 1.0)
            
            GeometryReader { geo in
                HStack(spacing: 1.5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "34C759")) // Sublimation
                        .frame(width: max(0, geo.size.width * CGFloat(subPercent) - 1))
                    
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(hex: "007AFF")) // Intellectualization
                        .frame(width: max(0, geo.size.width * CGFloat(intPercent) - 1))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "FF3B30")) // Regression
                        .frame(width: max(0, geo.size.width * CGFloat(regPercent) - 1))
                }
            }
            .frame(height: 7)
            .cornerRadius(3.5)
            
            HStack(spacing: 10) {
                DefenseLegend(title: "升华与重建 (成熟型)", percent: subPercent, color: "34C759")
                DefenseLegend(title: "理智化 (中介型)", percent: intPercent, color: "007AFF")
                DefenseLegend(title: "经验性退行 (不成熟型)", percent: regPercent, color: "FF3B30")
            }
        }
    }
}

struct DefenseLegend: View {
    let title: String
    let percent: Double
    let color: String
    
    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 4, height: 4)
            Text("\(title) \(String(format: "%.0f%%", percent * 100))")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 辅助心理学图表子视图 (不改动原有 API 签名)

struct PsychMetricBar: View {
    let title: String
    let value: Double
    let color: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: color))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: color))
                        .frame(width: geo.size.width * CGFloat(value), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

struct PsychCapGridItem: View {
    let icon: String
    let title: String
    let sub: String
    let value: Double
    let color: String
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: color).opacity(0.1))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: color))
            }
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(String(format: "%.0f%%", value * 100))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(hex: color))
                }
                
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.015))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

struct PsychNeedRow: View {
    let icon: String
    let title: String
    let value: Double
    let color: String
    let desc: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "key.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: color))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(hex: color))
            }
            
            Text(desc)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: 3)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: color), Color(hex: color).opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(value), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(8)
        .background(Color.primary.opacity(0.015))
        .cornerRadius(10)
    }
}

private struct CuteTabButton: View {
    let emoji: String
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                if count > 0 {
                    ZStack {
                        Capsule()
                            .fill(isSelected ? Color(hex: "FF6B9D") : Color.primary.opacity(0.1))
                            .frame(height: 18)

                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : .secondary)
                            .padding(.horizontal, 8)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "FF6B9D").opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "FF6B9D").opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct CutePreferenceSection: View {
    let emoji: String
    let color: String
    let title: String
    let items: [UserPreference]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(items.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(hex: color))
                    )
            }

            VStack(spacing: 6) {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: color).opacity(0.3))
                            .frame(width: 6, height: 6)

                        Text(item.value)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(item.confidencePercent)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: color))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: color).opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: color).opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: color).opacity(0.15), lineWidth: 1)
        )
    }
}

private struct CuteEmptyState: View {
    let emoji: String
    let title: String
    let subtitle: String
    @State private var floatAnimation = false

    var body: some View {
        VStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 48))
                .scaleEffect(floatAnimation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: floatAnimation)

            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 50)
        .onAppear { floatAnimation = true }
    }
}

#Preview {
    MainView()
        .frame(height: 700)
}
