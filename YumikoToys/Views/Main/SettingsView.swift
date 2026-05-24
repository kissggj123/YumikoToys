//
//  SettingsView.swift
//  YumikoToys
//
//  设置视图（v4.0.0 - 包含自启钥匙串免密授权重构版）
//

import SwiftUI
import Combine

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsHeader()
                generalSettingsSection
                iconStyleSection
                statusBarIconStyleSection
                fontSection
                layoutSection
                preventSleepSection
                timeSyncSection
                modelManagementSection
                backgroundLearningSection
                dataManagementSection
                aboutSection
                footerText
            }
            .padding(28)
        }
        .frame(minWidth: 460, idealWidth: 500, maxWidth: 560)
        .background(settingsBackground)
        
        // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
        //  【新增】密码输入弹窗 - 用于重新授权或首次写入钥匙串
        // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
        .alert("钥匙串管理员密码授权", isPresented: $viewModel.showKeychainInput) {
            SecureField("请输入当前 Mac 登录密码", text: $viewModel.keychainInputPassword)
            
            Button("取消", role: .cancel) {
                viewModel.keychainInputPassword = ""
            }
            
            Button("授权并储存") {
                viewModel.saveKeychainPassword()
            }
        } message: {
            Text("您的密码将采用系统级加密技术存入 macOS 钥匙串，仅用于本机静默配置开机系统级不休眠（LaunchDaemon）服务。")
        }
        
        // 核心重置与导入导出弹窗
        .alert("确认重置", isPresented: $viewModel.showResetConfirmation) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                viewModel.resetAllData()
            }
        } message: {
            Text("指挥官，此操作将清除所有纪念日与设置数据，且不可撤销。确定要继续吗？")
        }
        .alert("导入成功", isPresented: $viewModel.showImportSuccess) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("数据已成功导入，兔可可已更新。")
        }
        .alert("导出成功", isPresented: $viewModel.showExportSuccess) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("数据已成功导出至指定位置。")
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .onAppear {
            viewModel.reloadSettings()
        }
    }

    // MARK: - Section Views

    private var generalSettingsSection: some View {
        SettingsSection(title: "通用", icon: "gearshape.fill", iconColor: "007AFF") {
            VStack(alignment: .leading, spacing: 10) {
                SettingsToggleRow(
                    icon: "power",
                    iconColor: "34C759",
                    title: "开机自启动",
                    subtitle: "登录时自动运行兔可可",
                    isOn: $viewModel.launchAtLogin,
                    onToggle: viewModel.toggleLaunchAtLogin
                )

                // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
                //  【新增核心 UI】钥匙串已存密码状态检测与重新授权按钮
                // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
                HStack(spacing: 8) {
                    // 状态提示彩点
                    Circle()
                        .fill(viewModel.isKeychainAuthorized ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                        .shadow(color: (viewModel.isKeychainAuthorized ? Color.green : Color.orange).opacity(0.4), radius: 2)
                    
                    Text(viewModel.isKeychainAuthorized ? "密码读取正常 (系统自启防休眠已解锁)" : "密码未授权 (系统级自启政策将受限)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // 重新授权按钮
                    Button(action: {
                        viewModel.keychainInputPassword = ""
                        viewModel.showKeychainInput = true
                    }) {
                        Text(viewModel.isKeychainAuthorized ? "重新授权" : "立即授权")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "007AFF"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 50) // 缩进对齐上面的 Toggle Row 文本
                .padding(.bottom, 4)
            }

            SettingsToggleRow(
                icon: "menubar.rectangle",
                iconColor: "007AFF",
                title: "显示状态栏图标",
                subtitle: "在菜单栏中显示兔可可",
                isOn: $viewModel.showStatusBarIcon
            )
        }
    }
    
    private var iconStyleSection: some View {
        SettingsSection(title: "图标风格", icon: "paintbrush.fill", iconColor: "FF6B9D") {
            VStack(spacing: 8) {
                ForEach(IconStyle.uiStyles) { style in
                    SettingsIconStyleRow(
                        style: style,
                        isSelected: viewModel.selectedIconStyle == style,
                        action: { viewModel.selectIconStyle(style) }
                    )
                }
            }
        }
    }
    
    private var layoutSection: some View {
        SettingsSection(title: "自定义布局", icon: "rectangle.3.group", iconColor: "007AFF") {
            VStack(spacing: 6) {
                // 组件列表（可拖拽排序）
                let sortedLayouts = ComponentLayout.sorted(viewModel.componentLayouts)
                
                ForEach(Array(sortedLayouts.enumerated()), id: \.element.id) { index, layout in
                    HStack(spacing: 12) {
                        // 拖拽手柄
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.tertiary)
                        
                        // 图标
                        Text(layout.type.icon)
                            .font(.system(size: 16))
                        
                        // 名称
                        Text(layout.type.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        // 显示/隐藏开关（核心组件不可隐藏）
                        if layout.type.isOptional {
                            Toggle("", isOn: Binding(
                                get: { layout.isVisible },
                                set: { _ in viewModel.toggleComponentVisibility(layout.type) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        } else {
                            Text("必选")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.02))
                    )
                }
                
                // 重置按钮
                Button(action: { viewModel.resetComponentLayout() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12))
                        Text("恢复默认布局")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var statusBarIconStyleSection: some View {
        SettingsSection(title: "状态栏图标", icon: "menubar.rectangle", iconColor: "FF6B9D") {
            VStack(spacing: 8) {
                ForEach(IconStyle.allCases) { style in
                    SettingsIconStyleRow(
                        style: style,
                        isSelected: viewModel.statusBarIconStyle == style,
                        action: { viewModel.selectStatusBarIconStyle(style) }
                    )
                }
            }
        }
    }
    
    private var fontSection: some View {
        SettingsSection(title: "字体设置", icon: "textformat", iconColor: "5856D6") {
            VStack(spacing: 8) {
                ForEach(AppFont.allCases) { font in
                    SettingsFontRow(
                        icon: font.icon,
                        title: font.displayName,
                        isSelected: viewModel.selectedFont == font,
                        action: { viewModel.selectFont(font) }
                    )
                }
                
                if viewModel.selectedFont == .custom {
                    SettingsButtonRow(
                        icon: "doc.text",
                        iconColor: "FF9500",
                        title: "选择外部字体",
                        subtitle: viewModel.customFontPath ?? "点击选择字体文件"
                    ) {
                        Task { await viewModel.selectCustomFont() }
                    }
                }
            }
        }
    }

    private var preventSleepSection: some View {
        SettingsSection(title: "防休眠", icon: "shield.lefthalf.filled", iconColor: "FF9500") {
            SettingsToggleRow(
                icon: viewModel.isPreventSleepEnabled ? "display.trianglebadge.exclamationmark" : "display",
                iconColor: viewModel.isPreventSleepEnabled ? "34C759" : "FF9500",
                title: "不休眠模式",
                subtitle: viewModel.isPreventSleepEnabled
                    ? "系统与显示器休眠均已阻止"
                    : "开启后阻止系统与显示器休眠",
                isOn: $viewModel.preventSleep,
                onToggle: viewModel.togglePreventSleep
            )

            if viewModel.isPreventSleepEnabled {
                preventSleepActiveIndicator
            }
        }
    }

    private var preventSleepActiveIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .shadow(color: .green.opacity(0.5), radius: 3)

            Text("防休眠断言已激活")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var timeSyncSection: some View {
        SettingsSection(title: "时间同步", icon: "clock.arrow.circlepath", iconColor: "F4A261") {
            // NTP 服务器选择
            VStack(spacing: 6) {
                ForEach(NTPServerPreset.allCases) { preset in
                    Button(action: { viewModel.selectNTPServer(preset) }) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                
                                Text(preset.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if viewModel.selectedNTPPreset == preset {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color(hex: "F4A261"))
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.selectedNTPPreset == preset
                                      ? Color(hex: "F4A261").opacity(0.08)
                                      : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // 自定义服务器输入框
                if viewModel.showCustomNTPField {
                    HStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        
                        TextField("ntp.example.com", text: $viewModel.customNTPServer)
                            .font(.system(size: 13, design: .monospaced))
                            .textFieldStyle(.plain)
                            .onSubmit { viewModel.updateCustomNTPServer(viewModel.customNTPServer) }
                        
                        Button(action: { viewModel.updateCustomNTPServer(viewModel.customNTPServer) }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.showCustomNTPField)
            
            Divider()
                .background(Color.primary.opacity(0.08))
                .padding(.vertical, 4)
            
            // 同步按钮
            SettingsButtonRow(
                icon: viewModel.isTimeSyncing ? "arrow.clockwise" : "globe",
                iconColor: viewModel.timeSyncSuccess ? "22C55E" : "F4A261",
                title: viewModel.isTimeSyncing ? "正在同步..." : "同步 NTP 时间",
                subtitle: viewModel.timeSyncStatus
            ) {
                guard !viewModel.isTimeSyncing else { return }
                Task { await viewModel.syncTime() }
            }

            if viewModel.timeOffset != 0 {
                SettingsInfoRow(
                    icon: "arrow.left.arrow.right",
                    iconColor: "8E8E93",
                    title: "时间偏移",
                    value: viewModel.formattedTimeOffset
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.timeOffset)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isTimeSyncing)
    }

    private var modelManagementSection: some View {
        ModelManagementSection(modelService: DependencyContainer.shared.modelManagementService)
    }

    private var backgroundLearningSection: some View {
        SettingsSection(title: "AI 学习", icon: "brain.head.profile", iconColor: "5856D6") {
            SettingsToggleRow(
                icon: "brain",
                iconColor: "5856D6",
                title: "启用后台学习",
                subtitle: "分析对话记录，学习您的偏好",
                isOn: $viewModel.enableBackgroundLearning,
                onToggle: viewModel.toggleBackgroundLearning
            )

            // 【修改】显示详细的后台学习日志状态进度
            if viewModel.enableBackgroundLearning {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color.primary.opacity(0.08))
                        .padding(.vertical, 4)

                    // 状态指示
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .shadow(color: .green.opacity(0.5), radius: 3)

                        Text("运行中")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.green)

                        Spacer()
                    }

                    // 已分析对话
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "5856D6"))
                            .frame(width: 16)

                        Text("已分析对话")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(viewModel.learningStats.totalConversationsAnalyzed) 条")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                    // 已学习偏好
                    HStack(spacing: 8) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "5856D6"))
                            .frame(width: 16)

                        Text("已学习偏好")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(viewModel.learningStats.totalPreferencesLearned) 个")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                    // 上次学习时间
                    if let lastDate = viewModel.learningStats.lastLearningDate {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "5856D6"))
                                .frame(width: 16)

                            Text("上次学习")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(viewModel.formatDate(lastDate))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.leading, 50)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.enableBackgroundLearning)
    }

    private var dataManagementSection: some View {
        SettingsSection(title: "数据管理", icon: "externaldrive.fill", iconColor: "5856D6") {
            SettingsButtonRow(
                icon: "square.and.arrow.up",
                iconColor: "34C759",
                title: "导出数据",
                subtitle: "将纪念日与设置导出为文件"
            ) {
                Task { await viewModel.exportData() }
            }

            SettingsButtonRow(
                icon: "square.and.arrow.down",
                iconColor: "007AFF",
                title: "导入数据",
                subtitle: "从文件恢复纪念日与设置"
            ) {
                Task { await viewModel.importData() }
            }

            SettingsButtonRow(
                icon: "trash",
                iconColor: "FF3B30",
                title: "重置所有数据",
                subtitle: "清除全部纪念日与设置，不可撤销",
                isDestructive: true
            ) {
                viewModel.showResetConfirmation = true
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "关于", icon: "info.circle.fill", iconColor: "8E8E93") {
            SettingsInfoRow(
                icon: "number",
                iconColor: "8E8E93",
                title: "版本",
                value: "v\(AppConfig.version)"
            )

            SettingsButtonRow(
                icon: "doc.text.magnifyingglass",
                iconColor: "007AFF",
                title: "更新日志",
                subtitle: "查看各版本变更记录"
            ) {
                viewModel.showChangelog()
            }

            SettingsButtonRow(
                icon: "heart.fill",
                iconColor: "FF6B9D",
                title: "关于 YumikoToys",
                subtitle: "了解兔可可的故事"
            ) {
                viewModel.showAbout()
            }
        }
    }

    private var footerText: some View {
        Text("© 2026 YumikoToys · Made with 🐰")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .padding(.top, 8)
    }

    private var settingsBackground: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            EllipticalGradient(
                stops: [
                    .init(color: Color(hex: "5856D6").opacity(0.04), location: 0.0),
                    .init(color: .clear, location: 0.5)
                ],
                center: .bottomLeading,
                startRadiusFraction: 0,
                endRadiusFraction: 0.8
            )
        }
    }
}

// MARK: - 页面标题

private struct SettingsHeader: View, Equatable {
    static func == (lhs: SettingsHeader, rhs: SettingsHeader) -> Bool { true }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "5856D6"), Color(hex: "AF52DE")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .shadow(color: Color(hex: "5856D6").opacity(0.3), radius: 10, x: 0, y: 4)

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("设置")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("CONFIGURATION")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(1.5)
            }

            Spacer()
        }
    }
}

// MARK: - 设置分组

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 分组标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: iconColor))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // 分组内容
            VStack(spacing: 2) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
    }
}

// MARK: - 开关行

private struct SettingsToggleRow: View {
    let icon: String
    let iconColor: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var onToggle: ((Bool) -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: iconColor).opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: iconColor))
            }

            // 文字
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 开关
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    isOn = newValue
                    onToggle?(newValue)
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - 按钮行

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.1), value: configuration.isPressed)
    }
}

private struct SettingsButtonRow: View {
    let icon: String
    let iconColor: String
    let title: String
    let subtitle: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.08)) {
                isPressed = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isDestructive
                                ? Color.red.opacity(0.12)
                                : Color(hex: iconColor).opacity(0.12)
                        )
                        .frame(width: 36, height: 36)
                        // 【新增】点击时发光效果
                        .shadow(
                            color: (isDestructive ? Color.red : Color(hex: iconColor)).opacity(isPressed ? 0.5 : 0),
                            radius: isPressed ? 8 : 0
                        )

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            isDestructive ? .red : Color(hex: iconColor)
                        )
                        // 【新增】点击时图标弹跳
                        .scaleEffect(isPressed ? 0.85 : 1.0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isDestructive ? .red : .primary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    // 【新增】悬停时移动
                    .offset(x: isHovered ? 3 : 0)
            }
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered
                          ? (isDestructive ? Color.red.opacity(0.06) : Color.primary.opacity(0.04))
                          : Color.clear)
            )
        }
        .buttonStyle(BounceScaleButtonStyle())
        .animation(.spring(response: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 图标风格选择行

private struct SettingsIconStyleRow: View {
    let style: IconStyle
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // 预览图标
                HStack(spacing: 4) {
                    PixelArtIconView(
                        function: .anniversary,
                        style: style,
                        size: 22
                    )
                    PixelArtIconView(
                        function: .aiChat,
                        style: style,
                        size: 22
                    )
                }
                .frame(width: 56, height: 36)
                
                // 文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    
                    Text(style.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 选中指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(hex: "FF6B9D"))
                }
            }
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.spring(response: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 字体选择行

private struct SettingsFontRow: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // 动物表情图标
                Text(icon)
                    .font(.system(size: 24))
                    .frame(width: 36, height: 36)
                
                // 文字
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // 选中指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(hex: "5856D6"))
                }
            }
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.spring(response: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 信息行

private struct SettingsInfoRow: View {
    let icon: String
    let iconColor: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: iconColor).opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: iconColor))
            }

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - 视图模型

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var launchAtLogin = false
    @Published var showStatusBarIcon = true
    @Published var preventSleep = false
    @Published var selectedFont: AppFont = .cute
    @Published var selectedIconStyle: IconStyle = .pixelAnimal
    @Published var statusBarIconStyle: IconStyle = .originalHattie
    @Published var customFontPath: String?
    @Published var enableBackgroundLearning: Bool = true

    @Published var showResetConfirmation = false
    @Published var showImportSuccess = false
    @Published var showExportSuccess = false
    @Published var showError = false
    @Published var errorMessage = ""

    // 时间同步状态
    @Published var isTimeSyncing = false
    @Published var timeSyncSuccess = false
    @Published var timeSyncStatus = "点击同步 NTP 时间"
    @Published var timeOffset: TimeInterval = 0
    
    // NTP 服务器配置
    @Published var selectedNTPPreset: NTPServerPreset = .aliyun
    @Published var customNTPServer: String = ""
    @Published var showCustomNTPField: Bool = false
    
    // 组件布局配置
    @Published var componentLayouts: [ComponentLayout] = []
    
    // 学习统计
    @Published var learningStats: LearningStats = LearningStats(
        totalConversationsAnalyzed: 0,
        totalPreferencesLearned: 0,
        lastLearningDate: nil,
        isLearningEnabled: true
    )

    // 【新增】钥匙串状态管理属性
    @Published var isKeychainAuthorized: Bool = false
    @Published var showKeychainInput: Bool = false
    @Published var keychainInputPassword: String = ""

    private let container = DependencyContainer.shared
    private let exportService = DataExportService()
    private var cancellables = Set<AnyCancellable>()

    var isPreventSleepEnabled: Bool {
        preventSleep
    }

    var formattedTimeOffset: String {
        let absOffset = abs(timeOffset)
        let sign = timeOffset >= 0 ? "+" : "-"
        if absOffset < 1 {
            return "\(sign)\(String(format: "%.0f", absOffset * 1000))ms"
        } else {
            return "\(sign)\(String(format: "%.2f", absOffset))s"
        }
    }

    init() {
        preventSleep = container.preventSleepService.isPreventSleepEnabled
        launchAtLogin = container.launchAtLoginService.isEnabled
        timeOffset = container.timeSyncService.timeOffset
        selectedFont = container.settingsService.settings.selectedFont
        selectedIconStyle = container.settingsService.settings.selectedIconStyle
        statusBarIconStyle = container.settingsService.settings.statusBarIconStyle
        customFontPath = container.settingsService.settings.customFontPath
        
        // 读取 NTP 配置
        let ntpConfig = container.settingsService.settings.ntpConfiguration
        selectedNTPPreset = ntpConfig.selectedPreset
        customNTPServer = ntpConfig.customServer ?? ""
        showCustomNTPField = (ntpConfig.selectedPreset == .custom)
        
        // 读取后台学习配置
        if let learningService = container.backgroundLearningService {
            let results = learningService.getLearningResults()
            enableBackgroundLearning = results.stats.isLearningEnabled
            learningStats = results.stats
        }

        // 【新增】检测钥匙串中是否存在已存的管理员密码，初始化授权状态指示灯
        checkKeychainStatus()

        container.preventSleepService.isPreventSleepEnabledPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$preventSleep)

        container.launchAtLoginService.isEnabledPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$launchAtLogin)

        // 监听时间同步状态
        container.timeSyncService.syncStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleTimeSyncState(state)
            }
            .store(in: &cancellables)
        
        // 监听组件布局变化
        container.componentLayoutService.layoutsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$componentLayouts)
    }
    
    // MARK: - 【新增】钥匙串授权状态核心逻辑
    
    /// 检查钥匙串是否已安全保存本地登录密码
    func checkKeychainStatus() {
        isKeychainAuthorized = YumikoToysKeychain.getSavedPassword() != nil
    }
    
    /// 手动保存输入的管理员密码至系统钥匙串
    func saveKeychainPassword() {
        let trimmedPassword = keychainInputPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPassword.isEmpty else { return }
        
        let success = YumikoToysKeychain.saveCurrentPassword(trimmedPassword)
        if success {
            LoggerService.shared.info("Administrator password securely synchronized into system Keychain.")
            checkKeychainStatus()
            keychainInputPassword = ""
            
            // 【系统集成】如果用户之前开启了开机自启动，我们在保存完密码后，在后台静默尝试部署/修复系统级守护进程
            if launchAtLogin {
                Task {
                    _ = await container.launchAtLoginService.deploySystemWideDaemon()
                }
            }
        } else {
            errorMessage = "无法写入钥匙串：系统安全限制失败。"
            showError = true
        }
    }
    
    func selectFont(_ font: AppFont) {
        selectedFont = font
        var settings = container.settingsService.settings
        settings.selectedFont = font
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Font changed to: \(font.displayName)")
    }
    
    func selectIconStyle(_ style: IconStyle) {
        selectedIconStyle = style
        var settings = container.settingsService.settings
        settings.selectedIconStyle = style
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Icon style changed to: \(style.displayName)")
    }
    
    func selectStatusBarIconStyle(_ style: IconStyle) {
        statusBarIconStyle = style
        var settings = container.settingsService.settings
        settings.statusBarIconStyle = style
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Status bar icon style changed to: \(style.displayName)")
    }
    
    func selectNTPServer(_ preset: NTPServerPreset) {
        selectedNTPPreset = preset
        showCustomNTPField = (preset == .custom)
        var settings = container.settingsService.settings
        settings.ntpConfiguration.selectedPreset = preset
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("NTP server changed to: \(preset.displayName)")
    }
    
    func updateCustomNTPServer(_ server: String) {
        customNTPServer = server
        var settings = container.settingsService.settings
        settings.ntpConfiguration.customServer = server.isEmpty ? nil : server
        container.settingsService.updateSettings(settings)
    }

    /// 重新加载设置（在视图出现时调用，确保获取已持久化的设置）
    func reloadSettings() {
        let settings = container.settingsService.settings

        // 重新加载 NTP 配置
        let ntpConfig = settings.ntpConfiguration
        selectedNTPPreset = ntpConfig.selectedPreset
        customNTPServer = ntpConfig.customServer ?? ""
        showCustomNTPField = (ntpConfig.selectedPreset == .custom)

        LoggerService.shared.debug("SettingsView: 重新加载设置，NTP服务器: \(ntpConfig.selectedPreset.displayName)")
    }

    func toggleComponentVisibility(_ type: ComponentType) {
        container.componentLayoutService.toggleVisibility(for: type)
    }
    
    func moveComponent(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        container.componentLayoutService.moveLayout(from: sourceIndex, to: destination)
    }
    
    func resetComponentLayout() {
        container.componentLayoutService.resetToDefault()
    }
    
    func selectCustomFont() async {
        do {
            let url = try await showFontPicker()
            customFontPath = url.path
            var settings = container.settingsService.settings
            settings.customFontPath = url.path
            settings.selectedFont = .custom
            container.settingsService.updateSettings(settings)
            selectedFont = .custom
            LoggerService.shared.info("Custom font selected: \(url.path)")
        } catch {
            if let error = error as? FontPickerError, error == .cancelled {
                return
            }
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func showFontPicker() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.font]
                panel.message = "选择字体文件"
                panel.allowsMultipleSelection = false
                
                if panel.runModal() == .OK, let url = panel.url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: FontPickerError.cancelled)
                }
            }
        }
    }

    private func handleTimeSyncState(_ state: TimeSyncState) {
        switch state {
        case .idle:
            isTimeSyncing = false
            timeSyncSuccess = false
            timeSyncStatus = "点击同步 NTP 时间"
        case .syncing:
            isTimeSyncing = true
            timeSyncSuccess = false
            timeSyncStatus = "正在同步 NTP 服务器..."
        case .success(let offset):
            isTimeSyncing = false
            timeSyncSuccess = true
            timeOffset = offset
            let absOffset = abs(offset)
            if absOffset < 0.001 {
                timeSyncStatus = "时间已同步，无偏移"
            } else {
                let sign = offset > 0 ? "慢" : "快"
                timeSyncStatus = "时间已同步，本地时间\(sign) \(formattedTimeOffset)"
            }
        case .failed(let error):
            isTimeSyncing = false
            timeSyncSuccess = false
            timeSyncStatus = "同步失败: \(error)"
        }
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
            if enabled {
                container.launchAtLoginService.enable() // 底层会通过上面重构的代码，自动寻找钥匙串部署
            } else {
                container.launchAtLoginService.disable() // 底层会自动安全清除
            }
        }

    func togglePreventSleep(_ enabled: Bool) {
        if enabled {
            container.preventSleepService.enablePreventSleep()
        } else {
            container.preventSleepService.disablePreventSleep()
        }
    }

    func exportData() async {
        do {
            _ = try await exportService.exportData()
            showExportSuccess = true
        } catch {
            if case ExportError.cancelled = error { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func importData() async {
        do {
            try await exportService.showImportPanel()
            showImportSuccess = true
        } catch {
            if case ExportError.cancelled = error { return }
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func resetAllData() {
        container.anniversaryService.deleteAllAnniversaries()
        container.settingsService.updateSettings(.default)
        LoggerService.shared.info("All data reset")
    }

    func showChangelog() {
        container.windowManager.showWindow(.changelog) {
            ChangelogView()
        }
    }

    func showAbout() {
        container.windowManager.showWindow(.about) {
            AboutView()
        }
    }

    func syncTime() async {
        await container.timeSyncService.syncNow()
    }
    
    func toggleBackgroundLearning(_ enabled: Bool) {
        if let service = container.backgroundLearningService {
            // 【修复】同步更新 AppMode 和 isBackgroundLearningEnabled
            let newMode: AppMode = enabled ? .study : .normal
            container.settingsService.updateMode(newMode)

            // 同时更新 isBackgroundLearningEnabled 字段
            var settings = container.settingsService.settings
            settings.isBackgroundLearningEnabled = enabled
            container.settingsService.updateSettings(settings)

            // 同步更新服务状态
            service.setLearningEnabled(enabled)

            // 更新本地状态
            var results = service.getLearningResults()
            learningStats = results.stats
            enableBackgroundLearning = enabled
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Font Picker Error

enum FontPickerError: Error, Equatable {
    case cancelled
}

#Preview {
    SettingsView()
        .frame(height: 700)
}
