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
    @State private var expandedComponentId: String? = nil
    @State private var customHexInput: String = ""

    var body: some View {
        ScrollView {
            HStack {
                Spacer(minLength: 20)
                
                VStack(spacing: 20) {
                    SettingsHeader()
                        .padding(.top, 10)
                    generalSettingsSection
                    iconStyleSection
                    statusBarIconStyleSection
                    fontSection
                    themeColorSection
                    godModeSection
                    layoutSection
                    preventSleepSection
                    timeSyncSection
                    modelManagementSection
                    backgroundLearningSection
                    psychologySettingsSection
                    proHumanSettingsSection
                    skillManagementSection
                    dataManagementSection
                    aboutSection
                    footerText
                }
                .frame(maxWidth: 460)
                
                Spacer(minLength: 20)
            }
            .padding(.top, 44) // Offset for traffic light buttons
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settingsBackground)
        .preferredColorScheme(viewModel.selectedThemeColor.isDarkTheme ? .dark : .light)
        
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
        .sheet(isPresented: $viewModel.showSkillEditor) {
            VStack(spacing: 16) {
                HStack {
                    Text(viewModel.selectedSkillToEdit == nil ? "新增自定义 Skill 技能" : "编辑自定义 Skill 技能")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    Button("关闭") {
                        viewModel.showSkillEditor = false
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // 技能名称
                        VStack(alignment: .leading, spacing: 4) {
                            Text("技能标识名称 (大模型调用名，必须为英文下划线格式)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField("例如: open_safari_url", text: $viewModel.editingSkillName)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                                .disabled(viewModel.selectedSkillToEdit != nil)
                        }
                        
                        // 描述
                        VStack(alignment: .leading, spacing: 4) {
                            Text("技能用途描述 (大模型根据此描述判断何时调用该技能)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField("例如: 用于打开指定网页链接", text: $viewModel.editingSkillDescription)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // 脚本类型
                        VStack(alignment: .leading, spacing: 4) {
                            Text("执行脚本类型")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Picker("", selection: $viewModel.editingSkillScriptType) {
                                Text("Shell 脚本").tag("shell")
                                Text("AppleScript").tag("applescript")
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        // 参数 Schema
                        VStack(alignment: .leading, spacing: 4) {
                            Text("参数 JSON Schema 定义")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextEditor(text: $viewModel.editingSkillParametersJSON)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(height: 100)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        }
                        
                        // 脚本内容
                        VStack(alignment: .leading, spacing: 4) {
                            Text("脚本源码内容 (使用 {{paramName}} 引用上述参数)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextEditor(text: $viewModel.editingSkillScriptContent)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(height: 120)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                        }
                        
                        // 测试输出
                        if !viewModel.testOutput.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("运行测试结果反馈")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                ScrollView {
                                    Text(viewModel.testOutput)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(viewModel.testOutput.contains("error") || viewModel.testOutput.contains("错误") ? .red : .primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                }
                                .frame(height: 80)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                
                HStack {
                    Button(action: {
                        viewModel.testSkill()
                    }) {
                        HStack {
                            if viewModel.isTestingSkill {
                                ProgressView().scaleEffect(0.5)
                            } else {
                                Image(systemName: "play.fill")
                            }
                            Text("运行测试 (使用 Mock 数据)")
                        }
                    }
                    .disabled(viewModel.isTestingSkill || viewModel.editingSkillName.isEmpty)
                    
                    Spacer()
                    
                    Button("取消") {
                        viewModel.showSkillEditor = false
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    Button("保存技能") {
                        viewModel.saveSkill()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(viewModel.editingSkillName.isEmpty)
                }
            }
            .padding()
            .frame(width: 480, height: 600)
        }
        .onAppear {
            viewModel.reloadSettings()
            viewModel.checkFullDiskAccess()
            customHexInput = "#" + viewModel.customThemeColorHex
        }
        .onChange(of: viewModel.customThemeColorHex) { newValue in
            if customHexInput != "#" + newValue {
                customHexInput = "#" + newValue
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.checkFullDiskAccess()
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
    
    private var themeColorSection: some View {
        SettingsSection(title: "主页及状态栏主题色", icon: "paintpalette.fill", iconColor: "FF6B9D") {
            VStack(alignment: .leading, spacing: 12) {
                // 主题选择
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                    ForEach(ThemeColor.allCases) { theme in
                        Button(action: {
                            viewModel.selectThemeColor(theme)
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: theme.themeIcon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(viewModel.selectedThemeColor == theme ? .white : theme.accentColor)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(viewModel.selectedThemeColor == theme ? theme.accentColor : Color.primary.opacity(0.06))
                                    )
                                
                                Text(theme.displayName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(viewModel.selectedThemeColor == theme ? .primary : .secondary)
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.selectedThemeColor == theme ? Color.primary.opacity(0.04) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // 如果是自定义主题，显示 ColorPicker & HEX 输入框
                if viewModel.selectedThemeColor == .custom {
                    Divider()
                        .background(Color.primary.opacity(0.08))
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "eyedropper.halftone")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        
                        Text("自定义主题色")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        TextField("#HEX", text: $customHexInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 90)
                            .onSubmit {
                                applyCustomHex()
                            }
                            .onChange(of: customHexInput) { newValue in
                                applyCustomHex(newValue)
                            }
                        
                        ColorPicker("", selection: Binding(
                            get: {
                                Color(hex: viewModel.customThemeColorHex)
                            },
                            set: { color in
                                if let hex = color.toHex() {
                                    viewModel.updateCustomThemeColorHex(hex)
                                }
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private func applyCustomHex(_ val: String? = nil) {
        let input = val ?? customHexInput
        var hex = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }
        let pattern = "^[0-9a-fA-F]{6}$"
        if hex.range(of: pattern, options: .regularExpression) != nil {
            viewModel.updateCustomThemeColorHex(hex)
        }
    }

    private var godModeSection: some View {
        SettingsSection(title: "上帝模式 (自定义 UI)", icon: "sparkles", iconColor: "AF52DE") {
            VStack(alignment: .leading, spacing: 12) {
                SettingsToggleRow(
                    icon: "wand.and.stars",
                    iconColor: "AF52DE",
                    title: "启用上帝模式",
                    subtitle: "自定义界面中所有元素的配色、描边与大小参数",
                    isOn: Binding(
                        get: { viewModel.godModeEnabled },
                        set: { viewModel.updateGodMode($0) }
                    )
                )
                
                if viewModel.godModeEnabled {
                    VStack(spacing: 10) {
                        Divider().background(Color.primary.opacity(0.08))
                        
                        // 1. Background
                        HStack {
                            Text("主背景色")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            TextField("#HEX", text: Binding(
                                get: { "#" + viewModel.customBackgroundColorHex },
                                set: { val in
                                    let clean = val.replacingOccurrences(of: "#", with: "")
                                    if clean.count == 6 {
                                        viewModel.updateGodModeColors(bg: clean)
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 80)
                            
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: viewModel.customBackgroundColorHex) },
                                set: { color in
                                    if let hex = color.toHex() {
                                        viewModel.updateGodModeColors(bg: hex)
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                        
                        // 2. Card Background
                        HStack {
                            Text("气泡卡片背景色")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            TextField("#HEX", text: Binding(
                                get: { "#" + viewModel.customCardBackgroundColorHex },
                                set: { val in
                                    let clean = val.replacingOccurrences(of: "#", with: "")
                                    if clean.count == 6 {
                                        viewModel.updateGodModeColors(card: clean)
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 80)
                            
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: viewModel.customCardBackgroundColorHex) },
                                set: { color in
                                    if let hex = color.toHex() {
                                        viewModel.updateGodModeColors(card: hex)
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                        
                        // 3. Text Color
                        HStack {
                            Text("主文本颜色")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            TextField("#HEX", text: Binding(
                                get: { "#" + viewModel.customTextColorHex },
                                set: { val in
                                    let clean = val.replacingOccurrences(of: "#", with: "")
                                    if clean.count == 6 {
                                        viewModel.updateGodModeColors(text: clean)
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 80)
                            
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: viewModel.customTextColorHex) },
                                set: { color in
                                    if let hex = color.toHex() {
                                        viewModel.updateGodModeColors(text: hex)
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                        
                        // 4. Accent Color
                        HStack {
                            Text("按钮强调色")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            TextField("#HEX", text: Binding(
                                get: { "#" + viewModel.customAccentColorHex },
                                set: { val in
                                    let clean = val.replacingOccurrences(of: "#", with: "")
                                    if clean.count == 6 {
                                        viewModel.updateGodModeColors(accent: clean)
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 80)
                            
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: viewModel.customAccentColorHex) },
                                set: { color in
                                    if let hex = color.toHex() {
                                        viewModel.updateGodModeColors(accent: hex)
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                        
                        // 5. Border Color
                        HStack {
                            Text("边框描边色")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            TextField("#HEX", text: Binding(
                                get: { "#" + viewModel.customBorderColorHex },
                                set: { val in
                                    let clean = val.replacingOccurrences(of: "#", with: "")
                                    if clean.count == 6 {
                                        viewModel.updateGodModeColors(border: clean)
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 80)
                            
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: viewModel.customBorderColorHex) },
                                set: { color in
                                    if let hex = color.toHex() {
                                        viewModel.updateGodModeColors(border: hex)
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                        
                        // 6. Divider Color
                        HStack {
                            Text("分割线颜色")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            TextField("#HEX", text: Binding(
                                get: { "#" + viewModel.customDividerColorHex },
                                set: { val in
                                    let clean = val.replacingOccurrences(of: "#", with: "")
                                    if clean.count == 6 {
                                        viewModel.updateGodModeColors(divider: clean)
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 80)
                            
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: viewModel.customDividerColorHex) },
                                set: { color in
                                    if let hex = color.toHex() {
                                        viewModel.updateGodModeColors(divider: hex)
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                        
                        // 7. Corner Radius
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("气泡卡片圆角半径")
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Text("\(Int(viewModel.customCornerRadius)) px")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(value: Binding(
                                get: { viewModel.customCornerRadius },
                                set: { viewModel.updateGodModeColors(radius: $0) }
                            ), in: 4.0...32.0, step: 1.0)
                        }
                        .padding(.top, 4)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var layoutSection: some View {
        SettingsSection(title: "自定义布局", icon: "rectangle.3.group", iconColor: "007AFF") {
            VStack(spacing: 10) {
                let sortedLayouts = ComponentLayout.sorted(viewModel.componentLayouts)
                
                ForEach(Array(sortedLayouts.enumerated()), id: \.element.id) { index, layout in
                    VStack(spacing: 0) {
                        // 头部标题栏
                        HStack(spacing: 12) {
                            // 拖动排序按钮
                            HStack(spacing: 6) {
                                Button(action: {
                                    if index > 0 {
                                        viewModel.moveComponent(from: index, to: index - 1)
                                    }
                                }) {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(index == 0 ? Color.secondary.opacity(0.3) : .secondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(index == 0)
                                
                                Button(action: {
                                    if index < sortedLayouts.count - 1 {
                                        viewModel.moveComponent(from: index, to: index + 1)
                                    }
                                }) {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(index == sortedLayouts.count - 1 ? Color.secondary.opacity(0.3) : .secondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(index == sortedLayouts.count - 1)
                            }
                            
                            // 图标
                            Text(layout.type.icon)
                                .font(.system(size: 16))
                            
                            // 名称
                            Text(layout.customTitle ?? layout.type.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            // 详情展开/收起按钮
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if expandedComponentId == layout.id {
                                        expandedComponentId = nil
                                    } else {
                                        expandedComponentId = layout.id
                                    }
                                }
                            }) {
                                Image(systemName: expandedComponentId == layout.id ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color(hex: "007AFF").opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                            
                            // 显示/隐藏开关
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
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        
                        // 展开的可编辑属性
                        if expandedComponentId == layout.id {
                            VStack(alignment: .leading, spacing: 12) {
                                Divider()
                                    .background(Color.primary.opacity(0.08))
                                    .padding(.bottom, 6)
                                
                                // 自定义标题
                                HStack(spacing: 8) {
                                    Text("自定义标题")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    TextField("默认: \(layout.type.displayName)", text: Binding(
                                        get: { layout.customTitle ?? "" },
                                        set: { val in
                                            var newLayout = layout
                                            newLayout.customTitle = val.isEmpty ? nil : val
                                            viewModel.updateComponentLayout(newLayout)
                                        }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                                }
                                
                                // 自定义字体大小
                                HStack(spacing: 8) {
                                    Text("字号大小")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    Slider(value: Binding(
                                        get: { layout.customFontSizeScale ?? 1.0 },
                                        set: { val in
                                            var newLayout = layout
                                            newLayout.customFontSizeScale = val
                                            viewModel.updateComponentLayout(newLayout)
                                        }
                                    ), in: 0.8...1.5, step: 0.05)
                                    
                                    Text("\(Int((layout.customFontSizeScale ?? 1.0) * 100))%")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 40, alignment: .trailing)
                                }
                                
                                // 自定义卡片背景/主题色
                                HStack(spacing: 8) {
                                    Text("自定义主题色")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    
                                    Toggle("开启自定义卡片颜色", isOn: Binding(
                                        get: { layout.customColorHex != nil },
                                        set: { hasColor in
                                            var newLayout = layout
                                            newLayout.customColorHex = hasColor ? "FF6B9D" : nil
                                            viewModel.updateComponentLayout(newLayout)
                                        }
                                    ))
                                    .font(.system(size: 11))
                                    .toggleStyle(.checkbox)
                                    
                                    Spacer()
                                    
                                    if let hexColor = layout.customColorHex {
                                        ColorPicker("", selection: Binding(
                                            get: {
                                                Color(hex: hexColor)
                                            },
                                            set: { color in
                                                if let hex = color.toHex() {
                                                    var newLayout = layout
                                                    newLayout.customColorHex = hex
                                                    viewModel.updateComponentLayout(newLayout)
                                                }
                                            }
                                        ))
                                        .labelsHidden()
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                            .background(Color.primary.opacity(0.01))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.02))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(expandedComponentId == layout.id ? 0.08 : 0.03), lineWidth: 1)
                            )
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

            // 完全磁盘访问权限 (FDA) 状态与一键引导开启
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.hasFullDiskAccess ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                    .shadow(color: (viewModel.hasFullDiskAccess ? Color.green : Color.orange).opacity(0.4), radius: 2)
                
                Text(viewModel.hasFullDiskAccess ? "完全磁盘访问权限：已授予" : "完全磁盘访问权限：未开启 (将暂停后台扫描以防弹窗)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !viewModel.hasFullDiskAccess {
                    Button(action: {
                        FullDiskAccessHelper.openSystemPrivacySettings()
                    }) {
                        Text("去开启")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "007AFF"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 50)
            .padding(.top, 4)

            // 【修改】显示详细的后台学习日志状态进度
            if viewModel.enableBackgroundLearning {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .background(Color.primary.opacity(0.08))
                        .padding(.vertical, 4)

                    // 状态指示
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.hasFullDiskAccess ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                            .shadow(color: (viewModel.hasFullDiskAccess ? Color.green : Color.orange).opacity(0.5), radius: 3)

                        Text(viewModel.hasFullDiskAccess ? "运行中" : "暂停 (需要完全磁盘访问权限)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(viewModel.hasFullDiskAccess ? .green : .orange)

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

    private var psychologySettingsSection: some View {
        SettingsSection(title: "专业心理陪伴设置", icon: "brain.head.profile", iconColor: "AF52DE") {
            VStack(alignment: .leading, spacing: 12) {
                SettingsToggleRow(
                    icon: "heart.text.square.fill",
                    iconColor: "AF52DE",
                    title: "启用心理学模型参数",
                    subtitle: "在 AI 聊天中启用专业心理陪伴的理论支持与底层参数优化",
                    isOn: Binding(
                        get: { viewModel.enablePsychologyParams },
                        set: { val in
                            viewModel.enablePsychologyParams = val
                            viewModel.updatePsychologySettings()
                        }
                    )
                )

                if viewModel.enablePsychologyParams {
                    VStack(alignment: .leading, spacing: 14) {
                        Divider().background(Color.primary.opacity(0.08))
                        
                        // 理论学派选择
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "graduationcap")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(hex: "AF52DE"))
                                Text("心理学理论学派支撑")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Picker("", selection: Binding(
                                    get: { viewModel.selectedPsychologyTheory },
                                    set: { val in
                                        viewModel.selectedPsychologyTheory = val
                                        viewModel.updatePsychologySettings()
                                    }
                                )) {
                                    ForEach(PsychologyTheory.allCases) { theory in
                                        Text(theory.displayName).tag(theory)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 220)
                            }
                            
                            Text(viewModel.selectedPsychologyTheory.description)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .padding(.top, 2)
                                .padding(.horizontal, 4)
                        }

                        // 陪伴专家角色身份
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "person.text.rectangle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(hex: "AF52DE"))
                                Text("心理学专家角色倾向")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Picker("", selection: Binding(
                                    get: { viewModel.selectedPsychologyPersona },
                                    set: { val in
                                        viewModel.selectedPsychologyPersona = val
                                        viewModel.updatePsychologySettings()
                                    }
                                )) {
                                    ForEach(PsychologyPersona.allCases) { persona in
                                        Text(persona.displayName).tag(persona)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 220)
                            }
                            
                            Text(viewModel.selectedPsychologyPersona.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .padding(.top, 2)
                                .padding(.horizontal, 4)
                        }

                        Divider().background(Color.primary.opacity(0.08))

                        // 发散度 Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("模型创造力 (Temperature): \(String(format: "%.2f", viewModel.psychologyTempScale))")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(viewModel.psychologyTempScale > 1.0 ? "发散/创造" : (viewModel.psychologyTempScale < 0.4 ? "严谨/保守" : "平衡陪伴"))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { viewModel.psychologyTempScale },
                                set: { val in
                                    viewModel.psychologyTempScale = val
                                    viewModel.updatePsychologySettings()
                                }
                            ), in: 0.1...1.5, step: 0.05)
                            .tint(Color(hex: "AF52DE"))
                        }

                        // Top P Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("核采样率 (Top P): \(String(format: "%.2f", viewModel.psychologyTopP))")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                            }
                            Slider(value: Binding(
                                get: { viewModel.psychologyTopP },
                                set: { val in
                                    viewModel.psychologyTopP = val
                                    viewModel.updatePsychologySettings()
                                }
                            ), in: 0.1...1.0, step: 0.05)
                            .tint(Color(hex: "AF52DE"))
                        }

                        // Presence Penalty Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("话题发散度 (Presence Penalty): \(String(format: "%.2f", viewModel.psychologyPresencePenalty))")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                            }
                            Slider(value: Binding(
                                get: { viewModel.psychologyPresencePenalty },
                                set: { val in
                                    viewModel.psychologyPresencePenalty = val
                                    viewModel.updatePsychologySettings()
                                }
                            ), in: -2.0...2.0, step: 0.1)
                            .tint(Color(hex: "AF52DE"))
                        }

                        // Frequency Penalty Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("重复词惩罚 (Frequency Penalty): \(String(format: "%.2f", viewModel.psychologyFrequencyPenalty))")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                            }
                            Slider(value: Binding(
                                get: { viewModel.psychologyFrequencyPenalty },
                                set: { val in
                                    viewModel.psychologyFrequencyPenalty = val
                                    viewModel.updatePsychologySettings()
                                }
                            ), in: -2.0...2.0, step: 0.1)
                            .tint(Color(hex: "AF52DE"))
                        }

                        // 学术理论支持说明卡片
                        VStack(alignment: .leading, spacing: 8) {
                            Text("【专业心理陪伴学术支持说明】")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hex: "AF52DE"))
                            
                            Text("本系统心理陪伴机制深度集成了认知行为重构、自我决定论的三大基础心理需求评估（主观能动性、自我成长力、关怀归属感）、罗杰斯人本主义无条件关注机制与精神分析深层动机追索。通过调控底层超参数以控制大模型的词汇发散和发散度核采样率，从而输出更具关怀深度 and 学术合理性的回应。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3.5)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.02))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.leading, 50)
                }
            }
        }
    }

    private var proHumanSettingsSection: some View {
        SettingsSection(title: "Pro Human 自定义设置", icon: "🌱", iconColor: "34C759") {
            VStack(alignment: .leading, spacing: 12) {
                // 使命重心选择
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "34C759"))
                        Text("极简三角使命重心")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { viewModel.proHumanMissionFocus },
                            set: { val in
                                viewModel.proHumanMissionFocus = val
                                viewModel.updateProHumanSettings()
                            }
                        )) {
                            ForEach(ProHumanMissionFocus.allCases) { focus in
                                Text(focus.displayName).tag(focus)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    
                    Text(viewModel.proHumanMissionFocus.promptSnippet)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .padding(.horizontal, 4)
                }
                
                Divider().background(Color.primary.opacity(0.08))
                
                // 交互风格选择
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "34C759"))
                        Text("Pro Human 交互风格")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { viewModel.proHumanInteractionStyle },
                            set: { val in
                                viewModel.proHumanInteractionStyle = val
                                viewModel.updateProHumanSettings()
                            }
                        )) {
                            ForEach(ProHumanInteractionStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    
                    Text(viewModel.proHumanInteractionStyle.promptSnippet)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .padding(.horizontal, 4)
                }
                
                Divider().background(Color.primary.opacity(0.08))
                
                // 自定义极简三角准则输入框
                VStack(alignment: .leading, spacing: 6) {
                    Text("自定义极简三角内容 (覆盖默认的 Don't get fired / bored / die)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: Binding(
                        get: { viewModel.proHumanCustomTriangleText },
                        set: { val in
                            viewModel.proHumanCustomTriangleText = val
                            viewModel.updateProHumanSettings()
                        }
                    ))
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 70)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var skillManagementSection: some View {
        SettingsSection(title: "大模型 Skill 技能管理", icon: "curlybraces", iconColor: "FF9500") {
            VStack(alignment: .leading, spacing: 12) {
                Text("配置大模型可调用的自动化脚本 (Shell / AppleScript)，支持传参执行。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                
                // 技能列表
                VStack(spacing: 8) {
                    // 系统预设技能
                    ForEach(SkillService.shared.getBuiltInSkills()) { skill in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(skill.name)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                Text(skill.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("系统预设")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(4)
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.02))
                        .cornerRadius(10)
                    }
                    
                    // 自定义技能
                    ForEach(viewModel.customSkills) { skill in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(skill.name)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                Text(skill.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    viewModel.startEditSkill(skill)
                                }) {
                                    Text("编辑")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color(hex: "007AFF"))
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    viewModel.deleteSkill(name: skill.name)
                                }) {
                                    Text("删除")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(10)
                    }
                }
                
                Button(action: {
                    viewModel.startAddSkill()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("新增自定义技能")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "FF9500"))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
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
    @Published var selectedThemeColor: ThemeColor = .dark
    @Published var customThemeColorHex: String = "FF6B9D"

    // 👈【核心新增】：上帝模式 (God Mode) 配色及圆角发布参数
    @Published var godModeEnabled = false
    @Published var customBackgroundColorHex = "1E1E2E"
    @Published var customCardBackgroundColorHex = "252538"
    @Published var customTextColorHex = "FFFFFF"
    @Published var customAccentColorHex = "8B5CF6"
    @Published var customBorderColorHex = "3F3F5F"
    @Published var customDividerColorHex = "2E2E3E"
    @Published var customCornerRadius = 16.0

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

    // 完全磁盘访问权限 (FDA) 状态
    @Published var hasFullDiskAccess: Bool = false
    
    // 专业心理陪伴配置
    @Published var enablePsychologyParams: Bool = true
    @Published var psychologyTempScale: Double = 0.7
    @Published var psychologyTopP: Double = 0.85
    @Published var psychologyPresencePenalty: Double = 0.0
    @Published var psychologyFrequencyPenalty: Double = 0.0
    @Published var selectedPsychologyTheory: PsychologyTheory = .cbt
    @Published var selectedPsychologyPersona: PsychologyPersona = .counselor

    // Pro Human 自定义调整项
    @Published var proHumanMissionFocus: ProHumanMissionFocus = .balanced
    @Published var proHumanInteractionStyle: ProHumanInteractionStyle = .warm
    @Published var proHumanCustomTriangleText: String = ""

    // 技能编辑器状态属性
    @Published var customSkills: [LLMSkill] = []
    @Published var showSkillEditor = false
    @Published var editingSkillName = ""
    @Published var editingSkillDescription = ""
    @Published var editingSkillScriptType = "shell"
    @Published var editingSkillParametersJSON = "{}"
    @Published var editingSkillScriptContent = ""
    @Published var testOutput = ""
    @Published var isTestingSkill = false
    @Published var selectedSkillToEdit: LLMSkill? = nil

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
        
        let settings = container.settingsService.settings
        selectedFont = settings.selectedFont
        selectedIconStyle = settings.selectedIconStyle
        statusBarIconStyle = settings.statusBarIconStyle
        customFontPath = settings.customFontPath
        selectedThemeColor = settings.selectedThemeColor
        customThemeColorHex = settings.customThemeColorHex
        
        // 读取上帝模式配置
        godModeEnabled = settings.godModeEnabled
        customBackgroundColorHex = settings.customBackgroundColorHex
        customCardBackgroundColorHex = settings.customCardBackgroundColorHex
        customTextColorHex = settings.customTextColorHex
        customAccentColorHex = settings.customAccentColorHex
        customBorderColorHex = settings.customBorderColorHex
        customDividerColorHex = settings.customDividerColorHex
        customCornerRadius = settings.customCornerRadius
        
        // 读取 NTP 配置
        let ntpConfig = settings.ntpConfiguration
        selectedNTPPreset = ntpConfig.selectedPreset
        customNTPServer = ntpConfig.customServer ?? ""
        showCustomNTPField = (ntpConfig.selectedPreset == .custom)
        
        // 读取后台学习配置
        if let learningService = container.backgroundLearningService {
            let results = learningService.getLearningResults()
            enableBackgroundLearning = results.stats.isLearningEnabled
            learningStats = results.stats
        }

        // 读取完全磁盘访问权限与专业心理学参数与 Pro Human 配置
        hasFullDiskAccess = FullDiskAccessHelper.hasFullDiskAccess
        enablePsychologyParams = settings.enablePsychologyParams
        psychologyTempScale = settings.psychologyTempScale
        psychologyTopP = settings.psychologyTopP
        psychologyPresencePenalty = settings.psychologyPresencePenalty
        psychologyFrequencyPenalty = settings.psychologyFrequencyPenalty
        selectedPsychologyTheory = settings.selectedPsychologyTheory
        selectedPsychologyPersona = settings.selectedPsychologyPersona

        proHumanMissionFocus = settings.proHumanMissionFocus
        proHumanInteractionStyle = settings.proHumanInteractionStyle
        proHumanCustomTriangleText = settings.proHumanCustomTriangleText

        // 初始化技能列表
        refreshSkillsList()

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
            
        // 监听设置变化
        container.settingsService.settingsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] updatedSettings in
                guard let self = self else { return }
                self.selectedThemeColor = updatedSettings.selectedThemeColor
                self.customThemeColorHex = updatedSettings.customThemeColorHex
                self.selectedFont = updatedSettings.selectedFont
                self.selectedIconStyle = updatedSettings.selectedIconStyle
                self.statusBarIconStyle = updatedSettings.statusBarIconStyle
                self.customFontPath = updatedSettings.customFontPath
                
                self.godModeEnabled = updatedSettings.godModeEnabled
                self.customBackgroundColorHex = updatedSettings.customBackgroundColorHex
                self.customCardBackgroundColorHex = updatedSettings.customCardBackgroundColorHex
                self.customTextColorHex = updatedSettings.customTextColorHex
                self.customAccentColorHex = updatedSettings.customAccentColorHex
                self.customBorderColorHex = updatedSettings.customBorderColorHex
                self.customDividerColorHex = updatedSettings.customDividerColorHex
                self.customCornerRadius = updatedSettings.customCornerRadius
            }
            .store(in: &cancellables)
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

        enablePsychologyParams = settings.enablePsychologyParams
        psychologyTempScale = settings.psychologyTempScale
        psychologyTopP = settings.psychologyTopP
        psychologyPresencePenalty = settings.psychologyPresencePenalty
        psychologyFrequencyPenalty = settings.psychologyFrequencyPenalty
        selectedPsychologyTheory = settings.selectedPsychologyTheory
        selectedPsychologyPersona = settings.selectedPsychologyPersona

        proHumanMissionFocus = settings.proHumanMissionFocus
        proHumanInteractionStyle = settings.proHumanInteractionStyle
        proHumanCustomTriangleText = settings.proHumanCustomTriangleText

        refreshSkillsList()

        // 加载上帝模式配置
        godModeEnabled = settings.godModeEnabled
        customBackgroundColorHex = settings.customBackgroundColorHex
        customCardBackgroundColorHex = settings.customCardBackgroundColorHex
        customTextColorHex = settings.customTextColorHex
        customAccentColorHex = settings.customAccentColorHex
        customBorderColorHex = settings.customBorderColorHex
        customDividerColorHex = settings.customDividerColorHex
        customCornerRadius = settings.customCornerRadius

        LoggerService.shared.debug("SettingsView: 重新加载设置，NTP服务器: \(ntpConfig.selectedPreset.displayName)")
    }

    func updateGodMode(_ enabled: Bool) {
        godModeEnabled = enabled
        var settings = container.settingsService.settings
        settings.godModeEnabled = enabled
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("God Mode status toggled to: \(enabled)")
    }

    func updateGodModeColors(
        bg: String? = nil,
        card: String? = nil,
        text: String? = nil,
        accent: String? = nil,
        border: String? = nil,
        divider: String? = nil,
        radius: Double? = nil
    ) {
        var settings = container.settingsService.settings
        if let bg = bg {
            customBackgroundColorHex = bg
            settings.customBackgroundColorHex = bg
        }
        if let card = card {
            customCardBackgroundColorHex = card
            settings.customCardBackgroundColorHex = card
        }
        if let text = text {
            customTextColorHex = text
            settings.customTextColorHex = text
        }
        if let accent = accent {
            customAccentColorHex = accent
            settings.customAccentColorHex = accent
        }
        if let border = border {
            customBorderColorHex = border
            settings.customBorderColorHex = border
        }
        if let divider = divider {
            customDividerColorHex = divider
            settings.customDividerColorHex = divider
        }
        if let radius = radius {
            customCornerRadius = radius
            settings.customCornerRadius = radius
        }
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("God Mode style parameters modified.")
    }

    func checkFullDiskAccess() {
        hasFullDiskAccess = FullDiskAccessHelper.hasFullDiskAccess
    }

    func updatePsychologySettings() {
        var settings = container.settingsService.settings
        settings.enablePsychologyParams = enablePsychologyParams
        settings.psychologyTempScale = psychologyTempScale
        settings.psychologyTopP = psychologyTopP
        settings.psychologyPresencePenalty = psychologyPresencePenalty
        settings.psychologyFrequencyPenalty = psychologyFrequencyPenalty
        settings.selectedPsychologyTheory = selectedPsychologyTheory
        settings.selectedPsychologyPersona = selectedPsychologyPersona
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Psychology settings updated in SettingsViewModel")
    }

    func updateProHumanSettings() {
        var settings = container.settingsService.settings
        settings.proHumanMissionFocus = proHumanMissionFocus
        settings.proHumanInteractionStyle = proHumanInteractionStyle
        settings.proHumanCustomTriangleText = proHumanCustomTriangleText
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Pro Human settings updated in SettingsViewModel")
    }

    func refreshSkillsList() {
        customSkills = SkillService.shared.customSkills
    }

    func startAddSkill() {
        selectedSkillToEdit = nil
        editingSkillName = ""
        editingSkillDescription = ""
        editingSkillScriptType = "shell"
        editingSkillParametersJSON = """
        {
            "type": "object",
            "properties": {
                "paramName": {
                    "type": "string",
                    "description": "参数描述"
                }
            },
            "required": ["paramName"]
        }
        """
        editingSkillScriptContent = "echo \"{{paramName}}\""
        testOutput = ""
        showSkillEditor = true
    }

    func startEditSkill(_ skill: LLMSkill) {
        selectedSkillToEdit = skill
        editingSkillName = skill.name
        editingSkillDescription = skill.description
        editingSkillScriptType = skill.scriptType
        editingSkillParametersJSON = skill.parametersJSON
        editingSkillScriptContent = skill.scriptContent
        testOutput = ""
        showSkillEditor = true
    }

    func saveSkill() {
        guard !editingSkillName.isEmpty else { return }
        
        var parameters = editingSkillParametersJSON
        if parameters.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parameters = "{\"type\": \"object\", \"properties\": {}}"
        }
        
        let newSkill = LLMSkill(
            name: editingSkillName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: editingSkillDescription,
            parametersJSON: parameters,
            scriptType: editingSkillScriptType,
            scriptContent: editingSkillScriptContent
        )
        
        SkillService.shared.addOrUpdateSkill(newSkill)
        refreshSkillsList()
        showSkillEditor = false
    }

    func deleteSkill(name: String) {
        SkillService.shared.deleteSkill(name: name)
        refreshSkillsList()
    }

    func testSkill() {
        guard !editingSkillName.isEmpty else {
            testOutput = "错误: 技能名称不能为空"
            return
        }
        isTestingSkill = true
        testOutput = "正在测试运行中..."
        
        Task {
            var mockArgs: [String: Any] = [:]
            if let data = editingSkillParametersJSON.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let properties = json["properties"] as? [String: Any] {
                for (key, val) in properties {
                    if let propDict = val as? [String: Any] {
                        if let type = propDict["type"] as? String {
                            if type == "string" {
                                mockArgs[key] = "测试文本"
                            } else if type == "number" || type == "integer" {
                                mockArgs[key] = 42
                            } else if type == "boolean" {
                                mockArgs[key] = true
                            }
                        }
                    } else {
                        mockArgs[key] = "测试值"
                    }
                }
            }
            
            let tempSkill = LLMSkill(
                name: editingSkillName,
                description: editingSkillDescription,
                parametersJSON: editingSkillParametersJSON,
                scriptType: editingSkillScriptType,
                scriptContent: editingSkillScriptContent
            )
            SkillService.shared.addOrUpdateSkill(tempSkill)
            
            let output = await SkillService.shared.executeSkill(name: editingSkillName, arguments: mockArgs)
            
            if selectedSkillToEdit == nil {
                SkillService.shared.deleteSkill(name: editingSkillName)
            }
            
            await MainActor.run {
                self.testOutput = output
                self.isTestingSkill = false
                self.refreshSkillsList()
            }
        }
    }

    func toggleComponentVisibility(_ type: ComponentType) {
        container.componentLayoutService.toggleVisibility(for: type)
    }
    
    func moveComponent(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        container.componentLayoutService.moveLayout(from: sourceIndex, to: destination)
    }
    
    func moveComponent(from sourceIndex: Int, to destinationIndex: Int) {
        container.componentLayoutService.moveLayout(from: sourceIndex, to: destinationIndex)
    }
    
    func updateComponentLayout(_ layout: ComponentLayout) {
        container.componentLayoutService.updateLayout(layout)
    }
    
    func selectThemeColor(_ theme: ThemeColor) {
        selectedThemeColor = theme
        var settings = container.settingsService.settings
        settings.selectedThemeColor = theme
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Theme color changed to: \(theme.rawValue)")
    }
    
    func updateCustomThemeColorHex(_ hex: String) {
        customThemeColorHex = hex
        selectedThemeColor = .custom
        var settings = container.settingsService.settings
        settings.customThemeColorHex = hex
        settings.selectedThemeColor = .custom
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Custom theme color hex changed to: \(hex)")
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
