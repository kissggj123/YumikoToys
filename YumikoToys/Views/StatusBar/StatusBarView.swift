//
//  StatusBarView.swift
//  YumikoToys
//
//  状态栏弹出视图（v4.0.1 - 稳定版与手势适配重构）
//

import SwiftUI
import Combine

// MARK: - 主题色枚举

enum ThemeColor: String, CaseIterable, Codable, Sendable, Identifiable {
    case dark       // 深色经典
    case pink       // 淡粉色
    case lavender   // 薰衣草紫
    case mint       // 薄荷绿
    case ocean      // 海洋蓝
    case sunset     // 日落橙
    case pixel      // 像素复古
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dark: return "深色"
        case .pink: return "粉色"
        case .lavender: return "紫色"
        case .mint: return "薄荷"
        case .ocean: return "海洋"
        case .sunset: return "日落"
        case .pixel: return "像素"
        }
    }
    
    var themeIcon: String {
        switch self {
        case .dark: return "moon.fill"
        case .pink: return "heart.fill"
        case .lavender: return "sparkles"
        case .mint: return "leaf.fill"
        case .ocean: return "water.waves"
        case .sunset: return "sun.max.fill"
        case .pixel: return "gamecontroller.fill"
        }
    }
    
    // MARK: - 基础颜色
    
    var backgroundColor: Color {
        switch self {
        case .dark:
            return Color(red: 0.11, green: 0.11, blue: 0.12)  // #1c1c1e
        case .pink:
            return Color(red: 0.98, green: 0.93, blue: 0.94)  // 淡粉色
        case .lavender:
            return Color(red: 0.94, green: 0.91, blue: 0.97)  // 薰衣草淡紫
        case .mint:
            return Color(red: 0.91, green: 0.97, blue: 0.95)  // 薄荷淡绿
        case .ocean:
            return Color(red: 0.90, green: 0.94, blue: 0.98)  // 海洋淡蓝
        case .sunset:
            return Color(red: 0.98, green: 0.94, blue: 0.90)  // 日落暖橙
        case .pixel:
            return Color(red: 0.13, green: 0.14, blue: 0.18)  // 像素深灰蓝
        }
    }
    
    var accentColor: Color {
        switch self {
        case .dark:
            return Color(hex: "FF6B9D")
        case .pink:
            return Color(hex: "E85D75")
        case .lavender:
            return Color(hex: "8B5CF6")
        case .mint:
            return Color(hex: "10B981")
        case .ocean:
            return Color(hex: "3B82F6")
        case .sunset:
            return Color(hex: "F59E0B")
        case .pixel:
            return Color(hex: "22D3EE")  // 像素霓虹青
        }
    }
    
    var iconGradient: [Color] {
        switch self {
        case .dark:
            return [Color(hex: "FF6B9D"), Color(hex: "C44FE2")]
        case .pink:
            return [Color(hex: "FFB6C1"), Color(hex: "E85D75")]
        case .lavender:
            return [Color(hex: "C4B5FD"), Color(hex: "8B5CF6")]
        case .mint:
            return [Color(hex: "6EE7B7"), Color(hex: "10B981")]
        case .ocean:
            return [Color(hex: "93C5FD"), Color(hex: "3B82F6")]
        case .sunset:
            return [Color(hex: "FCD34D"), Color(hex: "F59E0B")]
        case .pixel:
            return [Color(hex: "22D3EE"), Color(hex: "A78BFA")]  // 霓虹青到紫
        }
    }
    
    // MARK: - 文字颜色系统
    
    /// 主要文字颜色 - 高对比度确保可读性
    var textColor: Color {
        switch self {
        case .dark, .pixel:
            return .white
        case .pink:
            return Color(red: 0.08, green: 0.04, blue: 0.06)  // 更深的粉色
        case .lavender:
            return Color(red: 0.06, green: 0.04, blue: 0.12)  // 更深的紫色
        case .mint:
            return Color(red: 0.04, green: 0.12, blue: 0.08)  // 更深的绿色
        case .ocean:
            return Color(red: 0.04, green: 0.08, blue: 0.15)  // 更深的蓝色
        case .sunset:
            return Color(red: 0.15, green: 0.08, blue: 0.04)  // 更深的棕色
        }
    }

    /// 次要文字颜色
    var secondaryTextColor: Color {
        switch self {
        case .dark, .pixel:
            return .secondary
        case .pink:
            return Color(red: 0.25, green: 0.15, blue: 0.18)  // 更深的次要粉色
        case .lavender:
            return Color(red: 0.22, green: 0.15, blue: 0.32)  // 更深的次要紫色
        case .mint:
            return Color(red: 0.15, green: 0.28, blue: 0.2)   // 更深的次要绿色
        case .ocean:
            return Color(red: 0.15, green: 0.2, blue: 0.35)   // 更深的次要蓝色
        case .sunset:
            return Color(red: 0.35, green: 0.2, blue: 0.12)   // 更深的次要棕色
        }
    }
    
    var cardBackgroundColor: Color {
        switch self {
        case .dark, .pixel:
            return Color.primary.opacity(0.05)
        case .pink:
            return Color(hex: "FFB6C1").opacity(0.2)
        case .lavender:
            return Color(hex: "C4B5FD").opacity(0.2)
        case .mint:
            return Color(hex: "6EE7B7").opacity(0.2)
        case .ocean:
            return Color(hex: "93C5FD").opacity(0.2)
        case .sunset:
            return Color(hex: "FCD34D").opacity(0.2)
        }
    }
    
    var buttonBackgroundColor: Color {
        switch self {
        case .dark, .pixel:
            return Color.primary.opacity(0.08)
        case .pink:
            return Color(hex: "E85D75").opacity(0.1)
        case .lavender:
            return Color(hex: "8B5CF6").opacity(0.1)
        case .mint:
            return Color(hex: "10B981").opacity(0.1)
        case .ocean:
            return Color(hex: "3B82F6").opacity(0.1)
        case .sunset:
            return Color(hex: "F59E0B").opacity(0.1)
        }
    }
    
    /// 是否为深色主题（影响 NSPopover 外观）
    var isDarkTheme: Bool {
        switch self {
        case .dark, .pixel:
            return true
        default:
            return false
        }
    }
    
    // MARK: - 边框和分割线颜色
    
    /// 边框颜色
    var borderColor: Color {
        switch self {
        case .dark, .pixel:
            return Color.white.opacity(0.1)
        case .pink:
            return Color(hex: "E85D75").opacity(0.2)
        case .lavender:
            return Color(hex: "8B5CF6").opacity(0.2)
        case .mint:
            return Color(hex: "10B981").opacity(0.2)
        case .ocean:
            return Color(hex: "3B82F6").opacity(0.2)
        case .sunset:
            return Color(hex: "F59E0B").opacity(0.2)
        }
    }
    
    /// 分割线颜色
    var dividerColor: Color {
        switch self {
        case .dark, .pixel:
            return Color.white.opacity(0.08)
        case .pink:
            return Color(hex: "E85D75").opacity(0.15)
        case .lavender:
            return Color(hex: "8B5CF6").opacity(0.15)
        case .mint:
            return Color(hex: "10B981").opacity(0.15)
        case .ocean:
            return Color(hex: "3B82F6").opacity(0.15)
        case .sunset:
            return Color(hex: "F59E0B").opacity(0.15)
        }
    }
    
    // MARK: - 开关和控件颜色
    
    /// 开关开启颜色
    var toggleOnColor: Color {
        return accentColor
    }
    
    /// 开关背景颜色
    var toggleBackgroundColor: Color {
        switch self {
        case .dark, .pixel:
            return Color.white.opacity(0.15)
        default:
            return Color.gray.opacity(0.25)
        }
    }
    
    // MARK: - 按钮样式
    
    /// 主要按钮背景
    var primaryButtonBackground: Color {
        return accentColor.opacity(0.15)
    }
    
    /// 主要按钮文字颜色
    var primaryButtonTextColor: Color {
        return accentColor
    }
    
    /// 次要按钮背景
    var secondaryButtonBackground: Color {
        switch self {
        case .dark, .pixel:
            return Color.white.opacity(0.08)
        default:
            return Color.black.opacity(0.05)
        }
    }
    
    /// 危险按钮文字颜色
    var destructiveButtonColor: Color {
        switch self {
        case .dark, .pixel:
            return Color(hex: "FF453A")
        default:
            return Color(hex: "DC2626")
        }
    }
    
    // MARK: - 图标和装饰
    
    /// 图标颜色（非强调色）
    var iconColor: Color {
        switch self {
        case .dark, .pixel:
            return .secondary
        default:
            return textColor.opacity(0.6)
        }
    }
    
    /// 悬停背景色
    var hoverBackgroundColor: Color {
        switch self {
        case .dark, .pixel:
            return Color.white.opacity(0.06)
        default:
            return accentColor.opacity(0.08)
        }
    }
}

struct StatusBarView: View {
    @StateObject private var viewModel = StatusBarViewModel()
    let onShowMainWindow: () -> Void
    let onQuit: () -> Void

    // 主题色选择
    @State private var themeColor: ThemeColor = .dark
    @State private var showThemePicker: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            // 天数展示
            if let info = viewModel.anniversaryInfo {
                daysPreview(info: info, countdown: viewModel.shortCountdown)
                    .padding(16)

                Divider()
                    .padding(.horizontal, 16)
            }

            // 防休眠开关
            preventSleepSection
                .padding(16)

            Divider()
                .padding(.horizontal, 16)

            // 底部按钮
            bottomButtons
                .padding(16)

            // 主题色选择器（底部）
            if showThemePicker {
                themeColorPicker
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(width: 280)
        // 关键：允许垂直方向完全自适应内容高度，防止 popover 被裁剪或留下空白
        .fixedSize(horizontal: false, vertical: true)
        // 【修复】根据主题色设置背景
        .background(themeColor.backgroundColor)
        .onAppear {
            viewModel.onAppear()
            // 【修复】在 onAppear 中读取保存的主题色
            themeColor = DependencyContainer.shared.settingsService.settings.selectedThemeColor
        }
        .onDisappear { viewModel.onDisappear() }
    }
    
    // MARK: - 主题色切换按钮

    private var themeToggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showThemePicker.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: themeColor.themeIcon)
                    .font(.system(size: 10))
                Circle()
                    .fill(themeColor.accentColor)
                    .frame(width: 8, height: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .medium))
                    .rotationEffect(.degrees(showThemePicker ? 180 : 0))
            }
            .foregroundStyle(themeColor.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(themeColor.buttonBackgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(themeColor.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("切换主题色")
    }

    // MARK: - 底部主题色选择器

    private var themeColorPicker: some View {
        VStack(spacing: 10) {
            Text("选择主题")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(themeColor.secondaryTextColor)

            HStack(spacing: 8) {
                ForEach(ThemeColor.allCases) { theme in
                    ThemeColorButton(
                        theme: theme,
                        isSelected: themeColor == theme,
                        action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                themeColor = theme
                                saveThemeColor(theme)
                            }
                            // 选择后延迟隐藏
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showThemePicker = false
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColor.cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.borderColor, lineWidth: 1)
        )
    }

    /// 保存主题色到 AppSettings
    private func saveThemeColor(_ theme: ThemeColor) {
        var settings = DependencyContainer.shared.settingsService.settings
        settings.selectedThemeColor = theme
        DependencyContainer.shared.settingsService.updateSettings(settings)
    }
    
    // MARK: - 头部
    
    private var headerView: some View {
        HStack(spacing: 10) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: themeColor.iconGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                if let customImage = NSImage(named: "YumikoToys") {
                    Image(nsImage: customImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "rabbit.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(AppConfig.appName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeColor.textColor)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("🥕")
                        .font(.system(size: 10))
                    Text("可可皇后")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(themeColor.accentColor)
                        .lineLimit(1)
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(themeColor.secondaryTextColor)
                    Text("v\(AppConfig.version)")
                        .font(.system(size: 10))
                        .foregroundStyle(themeColor.secondaryTextColor)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 主题切换按钮
            themeToggleButton
            
            // 状态指示器
            if viewModel.isPreventSleepEnabled {
                Circle()
                    .fill(themeColor.accentColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: themeColor.accentColor.opacity(0.5), radius: 4)
            }
        }
    }
    
    // MARK: - 天数预览
    
    private func daysPreview(info: AnniversaryInfo, countdown: String) -> some View {
        VStack(spacing: 10) {
            // 标题
            HStack(spacing: 6) {
                PixelAvatarView(emoji: info.anniversary.displayAvatar, size: 20)
                
                Text(info.anniversary.displayPetName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // 天数（支持字号和内容自适应缩放）
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.3f", info.calculation.totalDays))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6) // 避免天数过长时换行或被截断
                    .lineLimit(1)
                    .foregroundStyle(
                        LinearGradient(
                            colors: themeColor.iconGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("天")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(themeColor.secondaryTextColor)
                
                Spacer()
            }
            
            // 倒计时
            Text(countdown)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(themeColor.secondaryTextColor.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColor.cardBackgroundColor)
        )
    }
    
    // MARK: - 防休眠开关
    
    private var preventSleepSection: some View {
        Button(action: {
            viewModel.togglePreventSleep()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.isPreventSleepEnabled ? themeColor.accentColor.opacity(0.15) : themeColor.secondaryButtonBackground)
                        .frame(width: 36, height: 36)
                    
                    PixelArtIconView(
                        function: .settings,
                        style: viewModel.uiIconStyle,
                        size: 18
                    )
                    .foregroundStyle(viewModel.isPreventSleepEnabled ? themeColor.accentColor : themeColor.iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("不休眠模式")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(themeColor.textColor)
                        .lineLimit(1)
                    
                    Text(viewModel.isPreventSleepEnabled ? "已开启" : "已关闭")
                        .font(.caption2)
                        .foregroundStyle(viewModel.isPreventSleepEnabled ? themeColor.accentColor : themeColor.secondaryTextColor)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { viewModel.isPreventSleepEnabled },
                    set: { _ in viewModel.togglePreventSleep() }
                ))
                .toggleStyle(.switch)
                .tint(themeColor.toggleOnColor)
                .labelsHidden()
                .allowsHitTesting(false) // 【核心修复】阻断 Toggle 本身对鼠标的响应，统一由外层整行手势接管，消除冲突 [1]
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 底部按钮
    
    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button(action: onShowMainWindow) {
                HStack(spacing: 6) {
                    PixelArtIconView(
                        function: .anniversary,
                        style: viewModel.uiIconStyle,
                        size: 14
                    )
                    Text("主界面")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .foregroundStyle(themeColor.textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColor.secondaryButtonBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeColor.borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            
            Button(action: onQuit) {
                HStack(spacing: 6) {
                    PixelArtIconView(
                        function: .quit,
                        style: viewModel.uiIconStyle,
                        size: 14
                    )
                    Text("退出")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .foregroundStyle(themeColor.destructiveButtonColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColor.destructiveButtonColor.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeColor.destructiveButtonColor.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 视图模型

@MainActor
final class StatusBarViewModel: ObservableObject {
    @Published var anniversaryInfo: AnniversaryInfo?
    @Published var shortCountdown: String = ""
    @Published var isPreventSleepEnabled: Bool = false
    @Published var selectedIconStyle: IconStyle = .pixelAnimal
    
    var uiIconStyle: IconStyle {
        selectedIconStyle.isStatusBarOnly ? .pixelAnimal : selectedIconStyle
    }
    
    private let container = DependencyContainer.shared
    private var cancellables = Set<AnyCancellable>()
    
    func onAppear() {
        cancellables.removeAll()
        
        container.anniversaryService.activeAnniversaryInfoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                guard let self = self else { return }
                self.anniversaryInfo = info
            }
            .store(in: &cancellables)
        
        container.anniversaryService.countdownTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                self.shortCountdown = text
            }
            .store(in: &cancellables)
        
        container.preventSleepService.isPreventSleepEnabledPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self = self else { return }
                self.isPreventSleepEnabled = enabled
            }
            .store(in: &cancellables)
        
        container.settingsService.settingsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self = self else { return }
                self.selectedIconStyle = settings.selectedIconStyle
            }
            .store(in: &cancellables)
        
        self.anniversaryInfo = container.anniversaryService.activeAnniversaryInfo
        self.isPreventSleepEnabled = container.preventSleepService.isPreventSleepEnabled
        self.selectedIconStyle = container.settingsService.settings.selectedIconStyle
        if let info = self.anniversaryInfo {
            self.shortCountdown = info.calculation.shortString
        }
    }
    
    func onDisappear() {
        cancellables.removeAll()
    }
    
    func togglePreventSleep() {
        container.preventSleepService.togglePreventSleep()
    }
}

// MARK: - 主题色选择按钮

struct ThemeColorButton: View {
    let theme: ThemeColor
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // 颜色方块
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: theme.iconGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)

                    // 选中指示
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? .white : Color.clear, lineWidth: 2)
                )
                .shadow(color: theme.accentColor.opacity(isHovered ? 0.5 : 0.3), radius: isHovered ? 6 : 3)

                // 主题名称
                Text(theme.displayName)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? theme.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
