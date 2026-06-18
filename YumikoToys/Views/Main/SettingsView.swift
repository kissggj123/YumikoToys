//
//  SettingsView.swift
//  YumikoToys
//
//  设置视图（v4.0.0 - 包含自启钥匙串免密授权重构版）
//

import SwiftUI
import Combine
import WidgetKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case appearance = "appearance"
    case godMode = "godMode"
    case ai = "ai"
    case proactive = "proactive"
    case system = "system"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .appearance: return "外观设置"
        case .godMode: return "上帝模式"
        case .ai: return "心智与 AI"
        case .proactive: return "智能助理"
        case .system: return "系统与数据"
        }
    }
    
    var iconName: String {
        switch self {
        case .appearance: return "paintbrush.fill"
        case .godMode: return "wand.and.stars"
        case .ai: return "brain.headset"
        case .proactive: return "sparkles"
        case .system: return "cpu"
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedTab: SettingsTab = .appearance
    @State private var expandedComponentId: String? = nil
    @State private var customHexInput: String = ""
    @State private var customMainHexInput: String = ""

    var body: some View {
        HStack(spacing: 0) {
            // 左侧分类选择栏
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                    .frame(height: 52)
                
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "5856D6"))
                    Text("分类设置")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 18, height: 18)
                                .foregroundStyle(selectedTab == tab ? .white : .secondary)
                            
                            Text(tab.displayName)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundStyle(selectedTab == tab ? .white : .primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? 
                                      LinearGradient(
                                          colors: [Color(hex: "5856D6"), Color(hex: "AF52DE")],
                                          startPoint: .leading,
                                          endPoint: .trailing
                                      ) : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                }
                
                Spacer()
            }
            .frame(width: 160)
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            // 右侧内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer()
                        .frame(height: 44) // 避开顶部信号灯区域
                    
                    SettingsHeader()
                        .padding(.bottom, 6)
                    
                    switch selectedTab {
                    case .appearance:
                        generalSettingsSection
                        iconStyleSection
                        statusBarIconStyleSection
                        statusBarTextModeSection
                        fontSection
                        statusBarThemeColorSection
                        mainWindowThemeColorSection
                        widgetStyleSection
                    case .godMode:
                        godModeSection
                        layoutSection
                    case .ai:
                        pokeIntegrationSection
                        modelManagementSection
                        backgroundLearningSection
                        psychologySettingsSection
                        proHumanSettingsSection
                    case .proactive:
                        proactiveSettingsSection
                    case .system:
                        preventSleepSection
                        timeSyncSection
                        skillManagementSection
                        PluginManagementSectionView()
                        dataManagementSection
                        aboutSection
                        footerText
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settingsBackground)
        .preferredColorScheme(viewModel.mainWindowThemeColor.isDarkTheme ? .dark : .light)
        
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
                
                // 步骤指示器
                HStack(spacing: 8) {
                    ForEach(1...4, id: \.self) { step in
                        VStack(spacing: 4) {
                            Text("\(step)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(viewModel.currentEditorStep == step ? .white : .secondary)
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle()
                                        .fill(viewModel.currentEditorStep == step ? Color(hex: "FF9500") : Color.primary.opacity(0.06))
                                )
                            
                            Text(stepTitle(for: step))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(viewModel.currentEditorStep == step ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        if step < 4 {
                            Rectangle()
                                .fill(viewModel.currentEditorStep > step ? Color(hex: "FF9500") : Color.primary.opacity(0.08))
                                .frame(height: 2)
                                .frame(maxWidth: 30)
                                .padding(.bottom, 14)
                        }
                    }
                }
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(8)
                
                // 步骤主内容
                VStack {
                    if viewModel.currentEditorStep == 1 {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("技能标识名称 (大模型调用名，必须为英文下划线格式)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                TextField("例如: open_safari_url", text: $viewModel.editingSkillName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12, design: .monospaced))
                                    .disabled(viewModel.selectedSkillToEdit != nil)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("技能用途描述 (大模型根据此描述判断何时调用该技能)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                TextField("例如: 用于打开指定网页链接", text: $viewModel.editingSkillDescription)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
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
                            
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                    else if viewModel.currentEditorStep == 2 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("可视化参数定义")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(action: {
                                    viewModel.editingSkillParameters.append(
                                        SettingsViewModel.SkillParameter(name: "new_param", type: "string", description: "描述", isRequired: true)
                                    )
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("添加参数")
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                }
                            }
                            
                            ScrollView {
                                VStack(spacing: 10) {
                                    if viewModel.editingSkillParameters.isEmpty {
                                        Text("暂无自定义参数，点击右上方添加。")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.tertiary)
                                            .padding(.vertical, 20)
                                    } else {
                                        ForEach($viewModel.editingSkillParameters) { $param in
                                            HStack(spacing: 8) {
                                                TextField("参数名", text: $param.name)
                                                    .textFieldStyle(.roundedBorder)
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .frame(width: 100)
                                                
                                                Picker("", selection: $param.type) {
                                                    Text("文本").tag("string")
                                                    Text("数字").tag("number")
                                                    Text("布尔").tag("boolean")
                                                }
                                                .pickerStyle(.menu)
                                                .frame(width: 70)
                                                
                                                TextField("描述", text: $param.description)
                                                    .textFieldStyle(.roundedBorder)
                                                    .font(.system(size: 11))
                                                
                                                Toggle("必填", isOn: $param.isRequired)
                                                    .toggleStyle(.checkbox)
                                                    .font(.system(size: 11))
                                                
                                                Button(action: {
                                                    viewModel.editingSkillParameters.removeAll(where: { $0.id == param.id })
                                                }) {
                                                    Image(systemName: "trash")
                                                        .foregroundStyle(.red)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(6)
                                            .background(Color.primary.opacity(0.02))
                                            .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // 自动生成的 JSON Schema 预览
                            VStack(alignment: .leading, spacing: 4) {
                                Text("自动生成的 JSON Schema")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                ScrollView {
                                    Text(viewModel.generateJSONSchema())
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(height: 60)
                                .padding(4)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.top, 8)
                    }
                    else if viewModel.currentEditorStep == 3 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("编写执行脚本 (使用双大括号 {{参数名}} 引用参数值)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Text("可用参数:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(viewModel.editingSkillParameters) { param in
                                            Text("{{\(param.name)}}")
                                                .font(.system(size: 10, design: .monospaced))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.primary.opacity(0.08))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                            
                            TextEditor(text: $viewModel.editingSkillScriptContent)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(minHeight: 200, maxHeight: .infinity)
                                .scrollContentBackground(.hidden)
                                .padding(6)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                            
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                    else if viewModel.currentEditorStep == 4 {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("沙盒运行测试验证")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            Text("系统将使用模拟 Mock 参数值来实际调用该脚本以校验正确性。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            
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
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("运行反馈输出:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                
                                ScrollView {
                                    Text(viewModel.testOutput.isEmpty ? "点击上方按钮运行测试，控制台输出将在此实时显示" : viewModel.testOutput)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(viewModel.testOutput.contains("error") || viewModel.testOutput.contains("错误") ? .red : .primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                }
                                .frame(minHeight: 120, maxHeight: .infinity)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(6)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(maxHeight: .infinity)
                
                Divider()
                
                // 导航控制按钮
                HStack {
                    if viewModel.currentEditorStep > 1 {
                        Button("上一步") {
                            withAnimation {
                                viewModel.currentEditorStep -= 1
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button("取消") {
                        viewModel.showSkillEditor = false
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    if viewModel.currentEditorStep < 4 {
                        Button("下一步") {
                            withAnimation {
                                viewModel.currentEditorStep += 1
                            }
                        }
                        .disabled(viewModel.editingSkillName.isEmpty)
                    } else {
                        Button("保存并发布技能") {
                            viewModel.saveSkill()
                        }
                        .keyboardShortcut(.return, modifiers: [])
                        .disabled(viewModel.editingSkillName.isEmpty)
                    }
                }
            }
            .padding()
            .frame(width: 500, height: 600)
        }
        .onAppear {
            viewModel.reloadSettings()
            viewModel.checkFullDiskAccess()
            viewModel.checkCLIInstalled()
            customHexInput = "#" + viewModel.customThemeColorHex
            customMainHexInput = "#" + viewModel.customMainWindowThemeColorHex
        }
        .onChange(of: viewModel.customThemeColorHex) { newValue in
            if customHexInput != "#" + newValue {
                customHexInput = "#" + newValue
            }
        }
        .onChange(of: viewModel.customMainWindowThemeColorHex) { newValue in
            if customMainHexInput != "#" + newValue {
                customMainHexInput = "#" + newValue
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
                isOn: $viewModel.showStatusBarIcon,
                onToggle: { value in viewModel.updateShowStatusBarIcon(value) }
            )

            SettingsToggleRow(
                icon: "sparkles.rectangle.stack",
                iconColor: "007AFF",
                title: "开机自启显示主界面",
                subtitle: "在系统开机/登录自动启动时，是否打开主窗口",
                isOn: $viewModel.showMainWindowOnAutoLaunch,
                onToggle: { value in viewModel.updateShowMainWindowOnAutoLaunch(value) }
            )

            SettingsToggleRow(
                icon: "hand.tap.fill",
                iconColor: "007AFF",
                title: "手动启动显示主界面",
                subtitle: "在手动运行应用时，是否自动打开主窗口",
                isOn: $viewModel.showMainWindowOnManualLaunch,
                onToggle: { value in viewModel.updateShowMainWindowOnManualLaunch(value) }
            )
            
            Divider()
                .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 10) {
                SettingsToggleRow(
                    icon: "sidebar.right",
                    iconColor: "007AFF",
                    title: "隐藏底部布局编辑栏",
                    subtitle: "隐藏上帝模式下的底部浮动控制栏，使用侧边栏笔形图标编辑",
                    isOn: $viewModel.hideFloatingLayoutToolbar,
                    onToggle: { viewModel.updateHideFloatingLayoutToolbar($0) }
                )
                
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "007AFF"))
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("状态栏特效雨选项")
                            .font(.system(size: 12, weight: .medium))
                        Text("选择在状态栏展示的华丽粒子特效雨")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("", selection: Binding(
                        get: { viewModel.activeSpecialEffect },
                        set: { viewModel.selectSpecialEffect($0) }
                    )) {
                        ForEach(SpecialEffectType.allCases) { effect in
                            Text(effect.displayName).tag(effect)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow.click")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "007AFF"))
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("鼠标点击特效")
                            .font(.system(size: 12, weight: .medium))
                        Text("点击应用界面时触发的华丽点击特效")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("", selection: Binding(
                        get: { viewModel.activeClickEffect },
                        set: { viewModel.selectClickEffect($0) }
                    )) {
                        ForEach(ClickEffectType.allCases) { effect in
                            Text(effect.displayName).tag(effect)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "007AFF"))
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("截图快捷键预设")
                            .font(.system(size: 12, weight: .medium))
                        Text("使用全局快捷键唤起快速区域截图")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("", selection: Binding(
                        get: { viewModel.screenshotHotkeyPreset },
                        set: { viewModel.selectScreenshotHotkeyPreset($0) }
                    )) {
                        ForEach(ScreenshotHotkeyPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
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
    
    private var statusBarThemeColorSection: some View {
        SettingsSection(title: "状态栏主题色", icon: "paintpalette.fill", iconColor: "FF6B9D") {
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
                                if let hex = color.toHex(), !Color.isHexClose(hex, viewModel.customThemeColorHex) {
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

    private var mainWindowThemeColorSection: some View {
        SettingsSection(title: "主界面主题色", icon: "paintpalette", iconColor: "007AFF") {
            VStack(alignment: .leading, spacing: 12) {
                // 主题选择
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                    ForEach(ThemeColor.allCases) { theme in
                        Button(action: {
                            viewModel.selectMainWindowThemeColor(theme)
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: theme.themeIcon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(viewModel.mainWindowThemeColor == theme ? .white : theme.accentColor)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(viewModel.mainWindowThemeColor == theme ? theme.accentColor : Color.primary.opacity(0.06))
                                    )
                                
                                Text(theme.displayName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(viewModel.mainWindowThemeColor == theme ? .primary : .secondary)
                            }
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.mainWindowThemeColor == theme ? Color.primary.opacity(0.04) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // 如果是自定义主题，显示 ColorPicker & HEX 输入框
                if viewModel.mainWindowThemeColor == .custom {
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
                        
                        TextField("#HEX", text: $customMainHexInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 90)
                            .onSubmit {
                                applyCustomMainHex()
                            }
                            .onChange(of: customMainHexInput) { newValue in
                                applyCustomMainHex(newValue)
                            }
                        
                        ColorPicker("", selection: Binding(
                            get: {
                                Color(hex: viewModel.customMainWindowThemeColorHex)
                            },
                            set: { color in
                                if let hex = color.toHex(), !Color.isHexClose(hex, viewModel.customMainWindowThemeColorHex) {
                                    viewModel.updateCustomMainWindowThemeColorHex(hex)
                                }
                            }
                        ))
                    }
                    .padding(.horizontal, 4)
                }
                
                // Color schemes management UI inside mainWindowThemeColorSection
                Divider()
                    .background(Color.primary.opacity(0.08))
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("配色方案备份与加载")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    if !viewModel.savedColorSchemes.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(viewModel.savedColorSchemes) { scheme in
                                HStack(spacing: 8) {
                                    HStack(spacing: 4) {
                                        Circle().fill(Color(hex: scheme.statusBarHex)).frame(width: 8, height: 8)
                                        Circle().fill(Color(hex: scheme.mainWindowHex)).frame(width: 8, height: 8)
                                        Circle().fill(Color(hex: scheme.accentHex)).frame(width: 8, height: 8)
                                    }
                                    
                                    Text(scheme.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(viewModel.activeColorSchemeName == scheme.name ? Color(hex: "007AFF") : .primary)
                                    
                                    Spacer()
                                    
                                    Button("加载") {
                                        viewModel.loadColorScheme(name: scheme.name)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Color(hex: "007AFF"))
                                    .font(.system(size: 11, weight: .semibold))
                                    
                                    Button(action: {
                                        viewModel.deleteColorScheme(name: scheme.name)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(8)
                                .background(Color.primary.opacity(0.03))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                    
                    HStack(spacing: 8) {
                        TextField("方案名称 (如: 极光绿)", text: $viewModel.newSchemeName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        
                        Button(action: {
                            viewModel.saveCurrentAsColorScheme(name: viewModel.newSchemeName)
                            viewModel.newSchemeName = ""
                        }) {
                            Text("保存当前配色为方案")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(viewModel.newSchemeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color(hex: "007AFF"))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.newSchemeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private var widgetStyleSection: some View {
        SettingsSection(title: "Widget 样式", icon: "widget.small", iconColor: "007AFF") {
            VStack(alignment: .leading, spacing: 12) {
                Text("选择通知中心小组件的显示样式")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                // 三列卡片并排预览
                HStack(alignment: .top, spacing: 10) {
                    ForEach(WidgetDisplayStyle.allCases) { style in
                        Button(action: { viewModel.selectWidgetDisplayStyle(style) }) {
                            VStack(alignment: .center, spacing: 6) {
                                WidgetMediumPreviewCard(style: style,
                                                        themeHex: viewModel.customThemeColorHex)
                                    .frame(maxWidth: .infinity)
                                Text(style.displayName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(style.description)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(height: 22)
                                if viewModel.widgetDisplayStyle == style {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(hex: "007AFF"))
                                } else {
                                    Image(systemName: "circle")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.secondary.opacity(0.4))
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(viewModel.widgetDisplayStyle == style
                                          ? Color(hex: "007AFF").opacity(0.08)
                                          : Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(viewModel.widgetDisplayStyle == style
                                            ? Color(hex: "007AFF").opacity(0.55)
                                            : Color.primary.opacity(0.1),
                                            lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("修改后请等待几秒或重新打开通知中心查看效果")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)

                // --- 控制中心 widget 使用说明（macOS 26+）---
                Divider().padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "switch.2")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "AF52DE"))
                        Text("控制中心 widget")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("macOS 26+")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color(hex: "AF52DE").opacity(0.15))
                            )
                            .foregroundStyle(Color(hex: "AF52DE"))
                    }

                    Text("YumikoToys 提供了控制中心小组件，可以在菜单栏下拉的控制中心里一键点按启动主 App。")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // 三步走
                    VStack(alignment: .leading, spacing: 4) {
                        stepRow(num: "1", text: "打开控制中心（点按菜单栏右上角  或三指右滑）")
                        stepRow(num: "2", text: "点底部的「编辑控制中心」")
                        stepRow(num: "3", text: "在「快捷指令 / App 控制」里把「YumikoToys」加进去")
                    }
                    .padding(.leading, 4)

                    // 一键直达控制中心设置
                    HStack(spacing: 8) {
                        Button(action: {
                            openSystemControlCenter()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "gear")
                                    .font(.system(size: 10))
                                Text("打开系统控制中心设置")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: "AF52DE").opacity(0.15))
                            )
                            .foregroundStyle(Color(hex: "AF52DE"))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            WidgetKitGuide.openNotificationCenter()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 10))
                                Text("通知中心 / 桌面组件")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(0.08))
                            )
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)

                    Text("小提示：桌面 / 通知中心组件的样式由上面「Widget 样式」决定；控制中心 widget 启动主 App。")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "AF52DE").opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "AF52DE").opacity(0.25), lineWidth: 1)
                )
            }
        }
    }

    @ViewBuilder
    private func stepRow(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(num)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 14, height: 14)
                .background(Circle().fill(Color(hex: "AF52DE")))
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 打开 macOS 系统控制中心 / 控制中心配置
    private func openSystemControlCenter() {
        // 控制中心没有专门的 URL scheme；用 System Settings 的"控制中心"面板
        // macOS 14+ 的通用面板 deep link：
        //   x-apple.systempreferences:com.apple.preference?ControlCenter
        // 兼容写法：x-apple.systempreferences:com.apple.systempreferences?ControlCenter
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference?ControlCenter") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
    }

    private func stepTitle(for step: Int) -> String {
        switch step {
        case 1: return "基础信息"
        case 2: return "参数定义"
        case 3: return "脚本内容"
        case 4: return "测试验证"
        default: return ""
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

    private func applyCustomMainHex(_ val: String? = nil) {
        let input = val ?? customMainHexInput
        var hex = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }
        let pattern = "^[0-9a-fA-F]{6}$"
        if hex.range(of: pattern, options: .regularExpression) != nil {
            viewModel.updateCustomMainWindowThemeColorHex(hex)
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
                
                SettingsToggleRow(
                    icon: "slider.horizontal.3",
                    iconColor: "AF52DE",
                    title: "上帝模式布局控制",
                    subtitle: "启用拖动与调整小组件大小（已锁定 / 正在编辑）",
                    isOn: Binding(
                        get: { viewModel.isLayoutEditingEnabled },
                        set: { viewModel.updateLayoutEditing($0) }
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
                                    if let hex = color.toHex(), !Color.isHexClose(hex, viewModel.customBackgroundColorHex) {
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
                                    if let hex = color.toHex(), !Color.isHexClose(hex, viewModel.customCardBackgroundColorHex) {
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
                                    if let hex = color.toHex(), !Color.isHexClose(hex, viewModel.customTextColorHex) {
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
                                    if let hex = color.toHex(), !Color.isHexClose(hex, viewModel.customAccentColorHex) {
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
                                    if let hex = color.toHex(), !Color.isHexClose(hex, viewModel.customBorderColorHex) {
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
                                    if let hex = color.toHex(), hex.lowercased() != viewModel.customDividerColorHex.lowercased() {
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
                            ComponentCustomizationPanel(layout: layout, viewModel: viewModel)
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
    
    private var statusBarTextModeSection: some View {
        SettingsSection(title: "状态栏文字", icon: "textformat.abc", iconColor: "FF6B9D") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(StatusBarTextMode.allCases) { mode in
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.selectStatusBarTextMode(mode)
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.statusBarTextMode == mode ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.statusBarTextMode == mode ? Color(hex: "FF6B9D") : .secondary)
                                    .font(.system(size: 14))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Text(mode.description)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(viewModel.statusBarTextMode == mode ? Color(hex: "FF6B9D").opacity(0.1) : Color.primary.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.statusBarTextMode == mode ? Color(hex: "FF6B9D").opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                
                // 自定义标题输入框（customTitle 模式）
                if viewModel.statusBarTextMode == .customTitle {
                    Divider().background(Color.primary.opacity(0.08))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("自定义宠物名称")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("输入自定义名称...", text: Binding(
                            get: { viewModel.customStatusBarText },
                            set: { viewModel.updateCustomStatusBarText($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        
                        Text("输入的名称将替换状态栏中的原始宠物名")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                // 上帝模式自定义文本输入框
                if viewModel.statusBarTextMode == .godMode {
                    Divider().background(Color.primary.opacity(0.08))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("自定义状态栏文本")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("输入自定义文本...", text: Binding(
                            get: { viewModel.customStatusBarText },
                            set: { viewModel.updateCustomStatusBarText($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        
                        Text("点击变量可插入到文本框:")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 6) {
                            VariableTag(name: "{name}", description: "宠物名")
                            VariableTag(name: "{days}", description: "天数")
                            VariableTag(name: "{emoji}", description: "头像")
                            VariableTag(name: "{species}", description: "品种")
                        }
                    }
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
                
                if viewModel.selectedFont == .systemCustom {
                    HStack {
                        Image(systemName: "textformat.size")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        
                        Text("选择内置系统字体")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { viewModel.selectedSystemFontFamily ?? "" },
                            set: { viewModel.selectSystemFontFamily($0) }
                        )) {
                            Text("请选择系统字体").tag("")
                            ForEach(NSFontManager.shared.availableFontFamilies.sorted(), id: \.self) { family in
                                Text(family).tag(family)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
    
    private var proactiveSettingsSection: some View {
        VStack(spacing: 20) {
            SettingsSection(title: "主动心跳助理 (Heartbeat Mode)", icon: "sparkles", iconColor: "9C27B0") {
                SettingsToggleRow(
                    icon: "sparkles",
                    iconColor: viewModel.enableProactiveAssistant ? "34C759" : "9C27B0",
                    title: "启用主动智能助理",
                    subtitle: "允许助手在后台定时自我唤醒，检测环境并主动向你发起关怀或自动执行任务",
                    isOn: Binding(
                        get: { viewModel.enableProactiveAssistant },
                        set: { _ in viewModel.toggleProactiveAssistant() }
                    )
                )
                
                if viewModel.enableProactiveAssistant {
                    // 心跳检测间隔滑块
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("心跳分析检查频率: \(Int(viewModel.proactiveHeartbeatInterval)) 分钟")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                        }
                        Slider(value: Binding(
                            get: { viewModel.proactiveHeartbeatInterval },
                            set: { val in viewModel.updateProactiveHeartbeatInterval(val) }
                        ), in: 5.0...60.0, step: 5.0)
                        .tint(Color(hex: "9C27B0"))
                        
                        Text("每隔 \(Int(viewModel.proactiveHeartbeatInterval)) 分钟，智能助理将默默收集一次系统运行状态、情绪趋势与日程安排，进行主动意图决策。")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                    
                    Divider().padding(.vertical, 4)
                    
                    // 主动触发器细分选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("后台心跳监测范围")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(.bottom, 2)
                        
                        let triggers = [
                            ("health", "📅 健康作息关怀 (连续工作、熬夜、午休提醒)"),
                            ("performance", "🖥️ 系统性能监控 (CPU 满载、物理内存溢出警示)"),
                            ("emotion", "🧠 情绪与心境净化 (根据聊天日志进行 CBT 心理安慰气泡推送)"),
                            ("workspace", "📁 工作区文件整理 (检测到临时文件堆积时提示自动整理)")
                        ]
                        
                        ForEach(triggers, id: \.0) { triggerId, displayName in
                            Button(action: { viewModel.toggleProactiveTrigger(triggerId) }) {
                                HStack {
                                    Image(systemName: viewModel.proactiveEnabledTriggers.contains(triggerId) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(viewModel.proactiveEnabledTriggers.contains(triggerId) ? .purple : .secondary)
                                    Text(displayName)
                                        .font(.system(size: 11))
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Divider().padding(.vertical, 4)
                    
                    // 自动执行模式
                    SettingsToggleRow(
                        icon: "bolt.fill",
                        iconColor: viewModel.proactiveAutoExecuteTasks ? "FFCC00" : "8E8E93",
                        title: "静默执行任务",
                        subtitle: "开启后，心跳整理工作区时无需向你弹窗确认，直接执行静默归档与清理任务",
                        isOn: Binding(
                            get: { viewModel.proactiveAutoExecuteTasks },
                            set: { _ in viewModel.toggleProactiveAutoExecuteTasks() }
                        )
                    )
                }
            }
            
            if viewModel.enableProactiveAssistant {
                // 当前运行状态面板
                SettingsSection(title: "运行状态面板", icon: "gauge.with.dots.needle.67percent", iconColor: "00BCD4") {
                    VStack(alignment: .leading, spacing: 12) {
                        // 运行状态指示器
                        HStack(spacing: 8) {
                            Circle()
                                .fill(viewModel.proactiveIsRunning ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(viewModel.proactiveIsRunning ? "监测运行中" : "已暂停")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            if viewModel.proactiveIsRunning {
                                Text("心跳间隔: \(Int(viewModel.proactiveHeartbeatInterval))分钟")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Divider().background(Color.primary.opacity(0.08))
                        
                        // 当前模型信息
                        VStack(alignment: .leading, spacing: 6) {
                            Text("当前调用模型")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                            
                            if let modelInfo = viewModel.proactiveCurrentModel {
                                HStack(spacing: 8) {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.purple)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(modelInfo.modelName)
                                            .font(.system(size: 11, weight: .medium))
                                        Text("\(modelInfo.provider) · \(modelInfo.status)")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(viewModel.formatProactiveDuration(modelInfo.startedAt))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.purple.opacity(0.08)))
                            } else {
                                HStack {
                                    Image(systemName: "moon.zzz")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    Text("空闲中，等待下一次心跳触发")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.06)))
                            }
                        }
                        
                        Divider().background(Color.primary.opacity(0.08))
                        
                        // 系统资源快照
                        if let snapshot = viewModel.proactiveSystemSnapshot {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("系统资源快照")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                                
                                let memMB = snapshot.memoryUsed / (1024 * 1024)
                                let totalMB = snapshot.memoryTotal / (1024 * 1024)
                                let availMB = snapshot.memoryAvailable / (1024 * 1024)
                                let compressedMB = snapshot.memoryCompressed / (1024 * 1024)
                                
                                VStack(spacing: 4) {
                                    ProactiveInfoRow(label: "已用内存", value: "\(memMB) MB / \(totalMB) MB", icon: "memorychip")
                                    ProactiveInfoRow(label: "可用内存", value: "\(availMB) MB", icon: "checkmark.circle")
                                    ProactiveInfoRow(label: "压缩内存", value: "\(compressedMB) MB", icon: "archivebox")
                                    ProactiveInfoRow(label: "桌面文件", value: "\(snapshot.desktopFilesCount) 个", icon: "folder")
                                    ProactiveInfoRow(label: "情绪状态", value: snapshot.dominantEmotion, icon: "heart")
                                    ProactiveInfoRow(label: "压力指数", value: String(format: "%.2f", snapshot.stressLevel), icon: "brain.head.profile")
                                }
                            }
                        }
                        
                        Divider().background(Color.primary.opacity(0.08))
                        
                        // 最近 API 调用记录
                        VStack(alignment: .leading, spacing: 6) {
                            Text("最近 API 调用")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                            
                            if viewModel.proactiveRecentCalls.isEmpty {
                                Text("暂无调用记录")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .padding(8)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(viewModel.proactiveRecentCalls.prefix(5)) { call in
                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack(spacing: 4) {
                                                    Circle()
                                                        .fill(call.success ? Color.green : Color.red)
                                                        .frame(width: 5, height: 5)
                                                    Text(call.model)
                                                        .font(.system(size: 9, weight: .medium))
                                                        .lineLimit(1)
                                                }
                                                Text(call.provider)
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.secondary)
                                                if let duration = call.duration {
                                                    Text(String(format: "%.1fs", duration))
                                                        .font(.system(size: 8, design: .monospaced))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .padding(6)
                                            .frame(minWidth: 80)
                                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.06)))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
    // 主动助理运行日志卡片
                SettingsSection(title: "助理心跳活动日志", icon: "doc.text.fill", iconColor: "607D8B") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("后台监测与自动化流水记录")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            
                            Button("清除日志") {
                                viewModel.clearProactiveLogs()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("刷新") {
                                viewModel.refreshProactiveLogs()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        if viewModel.proactiveLogs.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.tertiary)
                                Text("尚无活动日志。启用并等待心跳唤醒或生成主动提醒。")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.12)))
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 6) {
                                    ForEach(viewModel.proactiveLogs.reversed(), id: \.self) { log in
                                        Text(log)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.04)))
                                    }
                                }
                            }
                            .frame(height: 180)
                            .padding(4)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.12)))
                        }
                    }
                }
            }
        }
    }

    private var pokeIntegrationSection: some View {
        SettingsSection(title: "Poke 集成", icon: "link", iconColor: "00C7BE") {
            VStack(alignment: .leading, spacing: 12) {
                SettingsToggleRow(
                    icon: viewModel.enablePoke ? "link.circle.fill" : "link.circle",
                    iconColor: "00C7BE",
                    title: "启用 Poke 集成",
                    subtitle: viewModel.enablePoke ? "AI 对话内容将实时同步至 Poke" : "开启后同步 AI 对话消息到 Poke",
                    isOn: Binding(
                        get: { viewModel.enablePoke },
                        set: { _ in viewModel.toggleEnablePoke() }
                    )
                )
                
                if viewModel.enablePoke {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Poke API Key")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            
                            SecureField("输入您的 Poke API Key", text: Binding(
                                get: { viewModel.pokeApiKey },
                                set: { viewModel.updatePokeApiKey($0) }
                            ))
                            .font(.system(size: 12, design: .monospaced))
                            .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("💡 如何获取 API Key？")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text("1. 访问 https://poke.com/settings/advanced 并创建 API Key。\n2. 在上方填入 API Key 即可自动实时同步。")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(.top, 4)
                }
            }
        }
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

                        // Empathy Level Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("情感共鸣同理度 (Empathy): \(String(format: "%.2f", viewModel.psychologyEmpathyLevel))")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                            }
                            Slider(value: Binding(
                                get: { viewModel.psychologyEmpathyLevel },
                                set: { val in
                                    viewModel.psychologyEmpathyLevel = val
                                    viewModel.updatePsychologySettings()
                                }
                            ), in: 0.0...1.0, step: 0.05)
                            .tint(Color(hex: "AF52DE"))
                        }

                        // Clinical Depth Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("临床分析重构深度 (Clinical Depth): \(String(format: "%.2f", viewModel.psychologyClinicalDepth))")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                            }
                            Slider(value: Binding(
                                get: { viewModel.psychologyClinicalDepth },
                                set: { val in
                                    viewModel.psychologyClinicalDepth = val
                                    viewModel.updatePsychologySettings()
                                }
                            ), in: 0.0...1.0, step: 0.05)
                            .tint(Color(hex: "AF52DE"))
                        }

                        // Reframing Intensity Slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("认知重塑干预强度 (Reframing): \(String(format: "%.2f", viewModel.psychologyReframingIntensity))")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                            }
                            Slider(value: Binding(
                                get: { viewModel.psychologyReframingIntensity },
                                set: { val in
                                    viewModel.psychologyReframingIntensity = val
                                    viewModel.updatePsychologySettings()
                                }
                            ), in: 0.0...1.0, step: 0.05)
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
        SettingsSection(title: "Yumiko Claw 自定义设置", icon: "🌱", iconColor: "34C759") {
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
                        Text("Yumiko Claw 交互风格")
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

                Divider().background(Color.primary.opacity(0.08))

                // Anti-Algorithm Intensity Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("反算法驯化与推荐挑战度 (Anti-Algorithm): \(String(format: "%.2f", viewModel.proHumanAntiAlgorithmIntensity))")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    Slider(value: Binding(
                        get: { viewModel.proHumanAntiAlgorithmIntensity },
                        set: { val in
                            viewModel.proHumanAntiAlgorithmIntensity = val
                            viewModel.updateProHumanSettings()
                        }
                    ), in: 0.0...1.0, step: 0.05)
                    .tint(Color(hex: "34C759"))
                }

                // Self-Reflection Interval Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("自我内省与冥想日志引导频率 (Self-Reflection): \(String(format: "%.2f", viewModel.proHumanSelfReflectionInterval))")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    Slider(value: Binding(
                        get: { viewModel.proHumanSelfReflectionInterval },
                        set: { val in
                            viewModel.proHumanSelfReflectionInterval = val
                            viewModel.updateProHumanSettings()
                        }
                    ), in: 0.0...1.0, step: 0.05)
                    .tint(Color(hex: "34C759"))
                }

                // Screen Time Therapy Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("身心断联与排毒干预强度 (Digital Detox): \(String(format: "%.2f", viewModel.proHumanScreenTimeTherapy))")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    Slider(value: Binding(
                        get: { viewModel.proHumanScreenTimeTherapy },
                        set: { val in
                            viewModel.proHumanScreenTimeTherapy = val
                            viewModel.updateProHumanSettings()
                        }
                    ), in: 0.0...1.0, step: 0.05)
                    .tint(Color(hex: "34C759"))
                }

                // Cognitive Resistance Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("高阻力深度阅读与思考强化 (Cognitive Resistance): \(String(format: "%.2f", viewModel.proHumanCognitiveResistance))")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    Slider(value: Binding(
                        get: { viewModel.proHumanCognitiveResistance },
                        set: { val in
                            viewModel.proHumanCognitiveResistance = val
                            viewModel.updateProHumanSettings()
                        }
                    ), in: 0.0...1.0, step: 0.05)
                    .tint(Color(hex: "34C759"))
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
                                .buttonStyle(.premium)
                                .premiumHover()
                                
                                Button(action: {
                                    viewModel.deleteSkill(name: skill.name)
                                }) {
                                    Text("删除")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.premium)
                                .premiumHover()
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
                .buttonStyle(.premium)
                .premiumHover()
                .padding(.top, 4)
                
                Divider()
                    .background(Color.primary.opacity(0.08))
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("CLI 命令行工具")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("安装 ytskill 命令行工具后，您可以在终端中运行技能脚本或控制大模型。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Button(action: {
                            viewModel.installCLITool()
                        }) {
                            HStack {
                                if viewModel.isInstallingCLI {
                                    ProgressView().scaleEffect(0.5)
                                        .frame(height: 10)
                                } else {
                                    Image(systemName: viewModel.isCLIInstalled ? "arrow.clockwise.circle.fill" : "terminal.fill")
                                }
                                Text(viewModel.isCLIInstalled ? "重新安装 CLI 工具" : "安装 CLI 命令行工具")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.isCLIInstalled ? Color(hex: "5856D6") : Color(hex: "007AFF"))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.premium)
                        .premiumHover()
                        .disabled(viewModel.isInstallingCLI)
                        
                        if !viewModel.cliInstallStatus.isEmpty {
                            Text(viewModel.cliInstallStatus)
                                .font(.system(size: 11))
                                .foregroundStyle(viewModel.cliInstallStatus.contains("失败") ? .red : .green)
                        }
                    }
                    
                    CommandLineInstructionView()
                }
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

// MARK: - YumiScript 插件管理 Section
struct PluginManagementSectionView: View {
    @ObservedObject var pluginService = PluginService.shared
    @State private var showingEditor = false
    @State private var selectedPlugin: YumiPlugin? = nil
    @State private var newAppName = ""
    @State private var showingAppPicker = false
    
    var body: some View {
        SettingsSection(title: "YumiScript 插件与快速启动管理", icon: "powerplug", iconColor: "34C759") {
            VStack(alignment: .leading, spacing: 12) {
                Text("🧩 YumiScript 插件配置")
                    .font(.system(size: 12, weight: .bold))
                
                Text("配置状态栏中可快速执行的 YumiScript 插件，支持模块化和自定义编写。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                
                // 插件列表
                VStack(spacing: 8) {
                    ForEach(pluginService.customPlugins) { plugin in
                        HStack {
                            Image(systemName: plugin.icon.isEmpty ? "powerplug" : plugin.icon)
                                .font(.system(size: 12))
                                .frame(width: 20, height: 20)
                                .foregroundStyle(plugin.isEnabled ? .green : .secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(plugin.name)
                                        .font(.system(size: 12, weight: .bold))
                                    Text("(\(plugin.id))")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                                Text(plugin.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Toggle("", isOn: Binding(
                                    get: { plugin.isEnabled },
                                    set: { newValue in
                                        var updated = plugin
                                        updated.isEnabled = newValue
                                        pluginService.addOrUpdatePlugin(updated)
                                    }
                                ))
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                .labelsHidden()
                                
                                Button(action: {
                                    selectedPlugin = plugin
                                    showingEditor = true
                                }) {
                                    Text("编辑")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color(hex: "007AFF"))
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    pluginService.deletePlugin(id: plugin.id)
                                }) {
                                    Text("删除")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.02))
                        .cornerRadius(10)
                    }
                }
                
                Button(action: {
                    selectedPlugin = YumiPlugin(
                        id: "plugin_\(UUID().uuidString.prefix(6).lowercased())",
                        name: "自定义新插件",
                        icon: "powerplug",
                        description: "执行自定义 YumiScript 脚本指令",
                        isEnabled: true,
                        scriptContent: """
                        # YumiScript 自定义脚本
                        notify "自定义通知" "Hello YumiScript!"
                        """
                    )
                    showingEditor = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("新增自定义插件")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "34C759"))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
                
                Divider()
                    .padding(.vertical, 4)
                
                Text("🚀 状态栏快速启动应用配置")
                    .font(.system(size: 12, weight: .bold))
                
                Text("添加或移除展示在状态栏弹出菜单中的快速启动应用。点击对应应用时将自动通过 `launch` 指令激活。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    TextField("输入应用英文/拼音名称（如 Safari, Xcode）", text: $newAppName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                    
                    Button(action: {
                        let name = newAppName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            pluginService.addQuickLaunchApp(name: name)
                            newAppName = ""
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("添加")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "007AFF"))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(newAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                Button(action: {
                    showingAppPicker = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.portrait")
                        Text("从已安装应用批量选择")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(hex: "007AFF"))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
                
                if !pluginService.quickLaunchApps.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(pluginService.quickLaunchApps) { app in
                                HStack(spacing: 4) {
                                    Text(app.name)
                                        .font(.system(size: 10, weight: .semibold))
                                    
                                    Button(action: {
                                        pluginService.deleteQuickLaunchApp(id: app.id)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("暂无快速启动应用，请在上方输入框添加应用。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.vertical, 4)
                }
            }
        }
        .sheet(item: $selectedPlugin) { plugin in
            PluginEditorView(plugin: plugin, selectedPlugin: $selectedPlugin)
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(isPresented: $showingAppPicker)
        }
    }
}

struct PluginEditorView: View {
    @State var plugin: YumiPlugin
    @Binding var selectedPlugin: YumiPlugin?
    @ObservedObject var pluginService = PluginService.shared
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("编辑 YumiScript 插件")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("关闭") {
                    selectedPlugin = nil
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("插件标识 (ID，唯一)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("例如: quick_launch", text: $plugin.id)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("插件名称")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("例如: 快速启动应用", text: $plugin.name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("图标名称 (SFSymbol)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("例如: rocket / camera / video / powerplug", text: $plugin.icon)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("插件用途描述")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("简要描述插件的功能", text: $plugin.description)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YumiScript 脚本内容")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $plugin.scriptContent)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 180)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    }
                    
                    Button(action: {
                        pluginService.addOrUpdatePlugin(plugin)
                        selectedPlugin = nil
                    }) {
                        Text("保存插件")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color(hex: "34C759"))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(.horizontal)
            }
        }
        .frame(width: 450, height: 500)
        .onAppear {
            if let sel = selectedPlugin {
                self.plugin = sel
            }
        }
        .onChange(of: selectedPlugin) { newPlugin in
            if let newPlugin = newPlugin {
                self.plugin = newPlugin
            }
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
                if icon.unicodeScalars.first?.value ?? 0 > 0x2000 {
                    Text(icon)
                        .font(.system(size: 13))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: iconColor))
                }

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

// MARK: - 主动助理信息行

private struct ProactiveInfoRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
        }
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

// MARK: - Widget 预览卡片（模拟 Medium widget）

/// 按 WidgetDisplayStyle 的语义渲染一个小型预览卡片，使用当前主题色
struct WidgetMediumPreviewCard: View {
    let style: WidgetDisplayStyle
    let themeHex: String

    private var themeColor: Color { Color(hex: themeHex) }

    // 生成用于预览的静态数据
    private struct PreviewInfo {
        let petName: String
        let avatar: String
        let totalDays: Double
        let hours: Int
        let minutes: Int
        let seconds: Int
        let milestones: [(icon: String, label: String, date: String, count: String)]
    }

    private var info: PreviewInfo {
        PreviewInfo(
            petName: "兔可可",
            avatar: "🐰",
            totalDays: 827.085,
            hours: 19850,
            minutes: 2,
            seconds: 29,
            milestones: [
                (icon: "🌱", label: "下一个100天", date: "2026-08-29", count: "(第9个)"),
                (icon: "🌿", label: "下一个180天", date: "2026-08-29", count: "(第5个)"),
                (icon: "☘️", label: "下一个300天", date: "2026-08-29", count: "(第3个)"),
                (icon: "🎉", label: "下一周年",   date: "2027-03-12", count: "(第3周年)")
            ]
        )
    }

    var body: some View {
        switch style {
        case .classic: classicCard
        case .compact: compactCard
        case .detailed: detailedCard
        }
    }

    // MARK: - Classic: 信息均衡的两列布局
    private var classicCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(colors: [themeColor.opacity(0.85),
                                             themeColor.opacity(0.45)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        Text(info.avatar).font(.system(size: 8))
                        Text(info.petName)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(String(format: "%.1f", info.totalDays))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("天")
                            .font(.system(size: 6, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Text(String(format: "%dh %dm %ds", info.hours, info.minutes, info.seconds))
                        .font(.system(size: 5, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 1) {
                    ForEach(info.milestones.prefix(2), id: \.label) { m in
                        HStack(spacing: 2) {
                            Text(m.icon).font(.system(size: 5))
                            Text(m.label).font(.system(size: 5, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer(minLength: 2)
                            Text(m.date).font(.system(size: 4, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1.5)
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
        }
        .frame(height: 72)
    }

    // MARK: - Compact: 极简，突出天数
    private var compactCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(colors: [themeColor.opacity(0.95),
                                             themeColor.opacity(0.6)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

            VStack(alignment: .center, spacing: 2) {
                Text(info.avatar).font(.system(size: 12))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(String(format: "%.0f", info.totalDays))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    Text("天")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                Text(info.petName)
                    .font(.system(size: 6, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(height: 72)
    }

    // MARK: - Detailed: 多里程碑信息丰富
    private var detailedCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(colors: [themeColor.opacity(0.9),
                                             themeColor.opacity(0.4)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(info.avatar).font(.system(size: 7))
                    Text(info.petName)
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%dh %dm %ds", info.hours, info.minutes, info.seconds))
                        .font(.system(size: 4.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(String(format: "%.2f", info.totalDays))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("天")
                        .font(.system(size: 6, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(info.milestones, id: \.label) { m in
                        HStack(spacing: 2) {
                            Text(m.icon).font(.system(size: 4.5))
                            Text(m.label).font(.system(size: 4.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer(minLength: 2)
                            Text(m.date).font(.system(size: 4, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                            Text(m.count).font(.system(size: 4, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.22))
                        .cornerRadius(2)
                    }
                }
            }
            .padding(6)
        }
        .frame(height: 120)
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
    @Published var statusBarTextMode: StatusBarTextMode = .customTitle
    @Published var customStatusBarText: String = ""
    @Published var customFontPath: String?
    @Published var selectedSystemFontFamily: String?
    @Published var enablePoke = false
    @Published var pokeApiKey = ""
    @Published var enableBackgroundLearning: Bool = true
    @Published var selectedThemeColor: ThemeColor = .dark
    @Published var customThemeColorHex: String = "FF6B9D"
    @Published var mainWindowThemeColor: ThemeColor = .dark
    @Published var customMainWindowThemeColorHex: String = "FF6B9D"
    @Published var showMainWindowOnAutoLaunch: Bool = false
    @Published var showMainWindowOnManualLaunch: Bool = true
    
    // v4.5.0 settings
    @Published var hideFloatingLayoutToolbar: Bool = false
    @Published var activeSpecialEffect: SpecialEffectType = .emoji
    @Published var screenshotHotkeyPreset: ScreenshotHotkeyPreset = .none
    @Published var activeClickEffect: ClickEffectType = .sparkle
    @Published var widgetDisplayStyle: WidgetDisplayStyle = .classic

    // 👈【核心新增】：上帝模式 (God Mode) 配色及圆角发布参数
    @Published var godModeEnabled = false
    @Published var isLayoutEditingEnabled = false
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
    @Published var psychologyEmpathyLevel: Double = 0.8
    @Published var psychologyClinicalDepth: Double = 0.6
    @Published var psychologyReframingIntensity: Double = 0.5

    // Pro Human 自定义调整项
    @Published var proHumanMissionFocus: ProHumanMissionFocus = .balanced
    @Published var proHumanInteractionStyle: ProHumanInteractionStyle = .warm
    @Published var proHumanCustomTriangleText: String = ""
    @Published var proHumanAntiAlgorithmIntensity: Double = 0.7
    @Published var proHumanSelfReflectionInterval: Double = 0.5
    @Published var proHumanScreenTimeTherapy: Double = 0.6
    @Published var proHumanCognitiveResistance: Double = 0.5

    // 主动助理设置
    @Published var enableProactiveAssistant = false
    @Published var proactiveHeartbeatInterval: Double = 15.0
    @Published var proactiveAutoExecuteTasks = false
    @Published var proactiveEnabledTriggers: [String] = ["health", "performance", "emotion", "workspace"]
    
    // 主动助理运行状态
    @Published var proactiveIsRunning = false
    @Published var proactiveCurrentModel: ProactiveAgentService.ModelCallInfo?
    @Published var proactiveRecentCalls: [ProactiveAgentService.APICallRecord] = []
    @Published var proactiveSystemSnapshot: ProactiveAgentService.SystemSnapshot?
    @Published var proactiveLogs: [String] = []

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

    // CLI 工具安装状态
    @Published var isInstallingCLI = false
    @Published var cliInstallStatus = ""
    @Published var isCLIInstalled = false

    // 自定义颜色方案相关属性
    @Published var savedColorSchemes: [ColorScheme] = []
    @Published var activeColorSchemeName: String? = nil
    @Published var showSaveSchemeDialog = false
    @Published var newSchemeName = ""

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
        selectedSystemFontFamily = settings.selectedSystemFontFamily
        enablePoke = settings.enablePoke
        pokeApiKey = settings.pokeApiKey ?? ""
        selectedThemeColor = settings.selectedThemeColor
        customThemeColorHex = settings.customThemeColorHex
        mainWindowThemeColor = settings.mainWindowThemeColor
        customMainWindowThemeColorHex = settings.customMainWindowThemeColorHex
        showMainWindowOnAutoLaunch = settings.showMainWindowOnAutoLaunch
        showMainWindowOnManualLaunch = settings.showMainWindowOnManualLaunch
        
        // 读取 v4.5.0 配置
        hideFloatingLayoutToolbar = settings.hideFloatingLayoutToolbar
        activeSpecialEffect = settings.activeSpecialEffect
        screenshotHotkeyPreset = settings.screenshotHotkeyPreset
        activeClickEffect = settings.activeClickEffect
        
        // 读取状态栏文字配置
        statusBarTextMode = settings.statusBarTextMode
        customStatusBarText = settings.customStatusBarText
        
        // 读取上帝模式配置
        godModeEnabled = settings.godModeEnabled
        isLayoutEditingEnabled = settings.isLayoutEditingEnabled
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
        psychologyEmpathyLevel = settings.psychologyEmpathyLevel
        psychologyClinicalDepth = settings.psychologyClinicalDepth
        psychologyReframingIntensity = settings.psychologyReframingIntensity

        proHumanMissionFocus = settings.proHumanMissionFocus
        proHumanInteractionStyle = settings.proHumanInteractionStyle
        proHumanCustomTriangleText = settings.proHumanCustomTriangleText
        proHumanAntiAlgorithmIntensity = settings.proHumanAntiAlgorithmIntensity
        proHumanSelfReflectionInterval = settings.proHumanSelfReflectionInterval
        proHumanScreenTimeTherapy = settings.proHumanScreenTimeTherapy
        proHumanCognitiveResistance = settings.proHumanCognitiveResistance

        // 读取主动助理设置
        enableProactiveAssistant = settings.enableProactiveAssistant
        proactiveHeartbeatInterval = settings.proactiveHeartbeatInterval
        proactiveAutoExecuteTasks = settings.proactiveAutoExecuteTasks
        proactiveEnabledTriggers = settings.proactiveEnabledTriggers
        if let proactiveAgent = container.proactiveAgentService {
            proactiveLogs = proactiveAgent.activityLogs
            proactiveIsRunning = proactiveAgent.isHeartbeatRunning
            proactiveCurrentModel = proactiveAgent.currentModelInfo
            proactiveRecentCalls = proactiveAgent.recentAPICalls
            proactiveSystemSnapshot = proactiveAgent.lastSystemSnapshot
            
            // 订阅主动助理状态更新
            proactiveAgent.$isHeartbeatRunning
                .receive(on: DispatchQueue.main)
                .assign(to: &$proactiveIsRunning)
            proactiveAgent.$currentModelInfo
                .receive(on: DispatchQueue.main)
                .assign(to: &$proactiveCurrentModel)
            proactiveAgent.$recentAPICalls
                .receive(on: DispatchQueue.main)
                .assign(to: &$proactiveRecentCalls)
            proactiveAgent.$lastSystemSnapshot
                .receive(on: DispatchQueue.main)
                .assign(to: &$proactiveSystemSnapshot)
        }

        // 初始化技能列表
        refreshSkillsList()

        // 【新增】检测钥匙串中是否存在已存的管理员密码，初始化授权状态指示灯
        checkKeychainStatus()
        
        // 检测命令行工具安装状态
        checkCLIInstalled()
        
        // 自定义配色方案初始化
        savedColorSchemes = settings.savedColorSchemes
        activeColorSchemeName = settings.activeColorSchemeName

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
                self.mainWindowThemeColor = updatedSettings.mainWindowThemeColor
                self.customMainWindowThemeColorHex = updatedSettings.customMainWindowThemeColorHex
                self.showMainWindowOnAutoLaunch = updatedSettings.showMainWindowOnAutoLaunch
                self.showMainWindowOnManualLaunch = updatedSettings.showMainWindowOnManualLaunch
                
                self.hideFloatingLayoutToolbar = updatedSettings.hideFloatingLayoutToolbar
                self.activeSpecialEffect = updatedSettings.activeSpecialEffect
                self.screenshotHotkeyPreset = updatedSettings.screenshotHotkeyPreset
                self.activeClickEffect = updatedSettings.activeClickEffect
                self.selectedFont = updatedSettings.selectedFont
                self.selectedIconStyle = updatedSettings.selectedIconStyle
                self.statusBarIconStyle = updatedSettings.statusBarIconStyle
                self.customFontPath = updatedSettings.customFontPath
                self.selectedSystemFontFamily = updatedSettings.selectedSystemFontFamily
                self.enablePoke = updatedSettings.enablePoke
                self.pokeApiKey = updatedSettings.pokeApiKey ?? ""
                
                self.godModeEnabled = updatedSettings.godModeEnabled
                self.isLayoutEditingEnabled = updatedSettings.isLayoutEditingEnabled
                self.customBackgroundColorHex = updatedSettings.customBackgroundColorHex
                self.customCardBackgroundColorHex = updatedSettings.customCardBackgroundColorHex
                self.customTextColorHex = updatedSettings.customTextColorHex
                self.customAccentColorHex = updatedSettings.customAccentColorHex
                self.customBorderColorHex = updatedSettings.customBorderColorHex
                self.customDividerColorHex = updatedSettings.customDividerColorHex
                self.customCornerRadius = updatedSettings.customCornerRadius
                self.savedColorSchemes = updatedSettings.savedColorSchemes
                self.activeColorSchemeName = updatedSettings.activeColorSchemeName
                
                self.enableProactiveAssistant = updatedSettings.enableProactiveAssistant
                self.proactiveHeartbeatInterval = updatedSettings.proactiveHeartbeatInterval
                self.proactiveAutoExecuteTasks = updatedSettings.proactiveAutoExecuteTasks
                self.proactiveEnabledTriggers = updatedSettings.proactiveEnabledTriggers
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 【新增】钥匙串授权状态核心逻辑
    
    /// 检查钥匙串是否已安全保存本地登录密码
    func checkKeychainStatus() {
        isKeychainAuthorized = YumikoToysKeychain.getSavedPassword() != nil
    }
    
    /// 检查命令行工具是否已安装
    func checkCLIInstalled() {
        isCLIInstalled = FileManager.default.fileExists(atPath: "/usr/local/bin/ytskill")
        if isCLIInstalled && cliInstallStatus.isEmpty {
            cliInstallStatus = "已安装 (位于 /usr/local/bin/ytskill)"
        }
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
    
    func selectSystemFontFamily(_ family: String) {
        let trimmed = family.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedSystemFontFamily = trimmed
        var settings = container.settingsService.settings
        settings.selectedSystemFontFamily = trimmed
        settings.selectedFont = .systemCustom
        container.settingsService.updateSettings(settings)
        selectedFont = .systemCustom
        LoggerService.shared.info("System custom font family changed to: \(trimmed)")
    }
    
    // MARK: - 主动式助理设置 (Proactive Assistant)
    
    func toggleProactiveAssistant() {
        enableProactiveAssistant.toggle()
        var settings = container.settingsService.settings
        settings.enableProactiveAssistant = enableProactiveAssistant
        container.settingsService.updateSettings(settings)
        
        // 唤起或暂停心跳服务
        if enableProactiveAssistant {
            container.proactiveAgentService?.startService()
        } else {
            container.proactiveAgentService?.stopService()
        }
        
        LoggerService.shared.info("Proactive assistant toggled to: \(enableProactiveAssistant)")
    }
    
    func updateProactiveHeartbeatInterval(_ val: Double) {
        proactiveHeartbeatInterval = val
        var settings = container.settingsService.settings
        settings.proactiveHeartbeatInterval = val
        container.settingsService.updateSettings(settings)
        
        // 重置心跳计时器
        container.proactiveAgentService?.restartTimer()
        
        LoggerService.shared.info("Proactive heartbeat interval updated to: \(val) minutes")
    }
    
    func toggleProactiveAutoExecuteTasks() {
        proactiveAutoExecuteTasks.toggle()
        var settings = container.settingsService.settings
        settings.proactiveAutoExecuteTasks = proactiveAutoExecuteTasks
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Proactive auto execute tasks toggled to: \(proactiveAutoExecuteTasks)")
    }
    
    func toggleProactiveTrigger(_ trigger: String) {
        if proactiveEnabledTriggers.contains(trigger) {
            proactiveEnabledTriggers.removeAll(where: { $0 == trigger })
        } else {
            proactiveEnabledTriggers.append(trigger)
        }
        var settings = container.settingsService.settings
        settings.proactiveEnabledTriggers = proactiveEnabledTriggers
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Proactive trigger \(trigger) toggled")
    }
    
    func refreshProactiveLogs() {
        if let proactiveAgent = container.proactiveAgentService {
            proactiveLogs = proactiveAgent.activityLogs
            proactiveIsRunning = proactiveAgent.isHeartbeatRunning
            proactiveCurrentModel = proactiveAgent.currentModelInfo
            proactiveRecentCalls = proactiveAgent.recentAPICalls
            proactiveSystemSnapshot = proactiveAgent.lastSystemSnapshot
        }
    }
    
    func clearProactiveLogs() {
        container.proactiveAgentService?.clearLogs()
        proactiveLogs = []
    }
    
    func formatProactiveDuration(_ startDate: Date) -> String {
        let elapsed = Date().timeIntervalSince(startDate)
        if elapsed < 1 {
            return "<1s"
        } else if elapsed < 60 {
            return String(format: "%.0fs", elapsed)
        } else {
            return String(format: "%.0fm%.0fs", elapsed / 60, elapsed.truncatingRemainder(dividingBy: 60))
        }
    }
    
    func toggleEnablePoke() {
        enablePoke.toggle()
        var settings = container.settingsService.settings
        settings.enablePoke = enablePoke
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Poke integration toggled to: \(enablePoke)")
    }
    
    func updatePokeApiKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        pokeApiKey = trimmed
        var settings = container.settingsService.settings
        settings.pokeApiKey = trimmed.isEmpty ? nil : trimmed
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Poke API Key updated")
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
    
    func selectStatusBarTextMode(_ mode: StatusBarTextMode) {
        statusBarTextMode = mode
        var settings = container.settingsService.settings
        settings.statusBarTextMode = mode
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Status bar text mode changed to: \(mode.displayName)")
    }
    
    func updateCustomStatusBarText(_ text: String) {
        customStatusBarText = text
        var settings = container.settingsService.settings
        settings.customStatusBarText = text
        container.settingsService.updateSettings(settings)
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

    func updateHideFloatingLayoutToolbar(_ hide: Bool) {
        hideFloatingLayoutToolbar = hide
        var settings = container.settingsService.settings
        settings.hideFloatingLayoutToolbar = hide
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Hide floating layout toolbar toggled to: \(hide)")
    }
    
    func selectSpecialEffect(_ effect: SpecialEffectType) {
        activeSpecialEffect = effect
        var settings = container.settingsService.settings
        settings.activeSpecialEffect = effect
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Special effect changed to: \(effect.displayName)")
    }
    
    func selectClickEffect(_ effect: ClickEffectType) {
        activeClickEffect = effect
        var settings = container.settingsService.settings
        settings.activeClickEffect = effect
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Click effect changed to: \(effect.displayName)")
    }
    
    func selectScreenshotHotkeyPreset(_ preset: ScreenshotHotkeyPreset) {
        screenshotHotkeyPreset = preset
        var settings = container.settingsService.settings
        settings.screenshotHotkeyPreset = preset
        container.settingsService.updateSettings(settings)
        GlobalHotkeyManager.shared.setupHotkey(preset: preset)
        LoggerService.shared.info("Screenshot hotkey preset changed to: \(preset.displayName)")
    }

    func selectWidgetDisplayStyle(_ style: WidgetDisplayStyle) {
        widgetDisplayStyle = style
        var settings = container.settingsService.settings
        settings.widgetDisplayStyle = style
        container.settingsService.updateSettings(settings)
        // 同步写入共享 UserDefaults 供 Widget 直接读取
        let groupID = "group.com.Lite.YumikoToys"
        if let shared = UserDefaults(suiteName: groupID) {
            shared.set(style.rawValue, forKey: "widget_display_style")
            shared.synchronize()
        }
        DependencyContainer.shared.anniversaryService.forceSyncAndReloadWidget()
        LoggerService.shared.info("Widget display style changed to: \(style.displayName)")
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
        psychologyEmpathyLevel = settings.psychologyEmpathyLevel
        psychologyClinicalDepth = settings.psychologyClinicalDepth
        psychologyReframingIntensity = settings.psychologyReframingIntensity

        proHumanMissionFocus = settings.proHumanMissionFocus
        proHumanInteractionStyle = settings.proHumanInteractionStyle
        proHumanCustomTriangleText = settings.proHumanCustomTriangleText
        proHumanAntiAlgorithmIntensity = settings.proHumanAntiAlgorithmIntensity
        proHumanSelfReflectionInterval = settings.proHumanSelfReflectionInterval
        proHumanScreenTimeTherapy = settings.proHumanScreenTimeTherapy
        proHumanCognitiveResistance = settings.proHumanCognitiveResistance

        refreshSkillsList()

        // 加载上帝模式配置
        godModeEnabled = settings.godModeEnabled
        isLayoutEditingEnabled = settings.isLayoutEditingEnabled
        customBackgroundColorHex = settings.customBackgroundColorHex
        customCardBackgroundColorHex = settings.customCardBackgroundColorHex
        customTextColorHex = settings.customTextColorHex
        customAccentColorHex = settings.customAccentColorHex
        customBorderColorHex = settings.customBorderColorHex
        customDividerColorHex = settings.customDividerColorHex
        customCornerRadius = settings.customCornerRadius
        
        mainWindowThemeColor = settings.mainWindowThemeColor
        customMainWindowThemeColorHex = settings.customMainWindowThemeColorHex
        showMainWindowOnAutoLaunch = settings.showMainWindowOnAutoLaunch
        showMainWindowOnManualLaunch = settings.showMainWindowOnManualLaunch
        
        hideFloatingLayoutToolbar = settings.hideFloatingLayoutToolbar
        activeSpecialEffect = settings.activeSpecialEffect
        screenshotHotkeyPreset = settings.screenshotHotkeyPreset
        activeClickEffect = settings.activeClickEffect
        widgetDisplayStyle = settings.widgetDisplayStyle
        savedColorSchemes = settings.savedColorSchemes
        activeColorSchemeName = settings.activeColorSchemeName
        
        checkCLIInstalled()

        LoggerService.shared.debug("SettingsView: 重新加载设置，NTP服务器: \(ntpConfig.selectedPreset.displayName)")
    }

    func saveCurrentAsColorScheme(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let newScheme = ColorScheme(
            name: trimmedName,
            statusBarHex: customThemeColorHex,
            mainWindowHex: customMainWindowThemeColorHex,
            bgHex: customBackgroundColorHex,
            accentHex: customAccentColorHex,
            cardHex: customCardBackgroundColorHex,
            textHex: customTextColorHex,
            borderHex: customBorderColorHex,
            dividerHex: customDividerColorHex,
            cornerRadius: customCornerRadius
        )
        
        var settings = container.settingsService.settings
        settings.savedColorSchemes.removeAll(where: { $0.name == trimmedName })
        settings.savedColorSchemes.append(newScheme)
        settings.activeColorSchemeName = trimmedName
        container.settingsService.updateSettings(settings)
        
        savedColorSchemes = settings.savedColorSchemes
        activeColorSchemeName = trimmedName
        LoggerService.shared.info("Color scheme '\(trimmedName)' saved successfully.")
    }
    
    func loadColorScheme(name: String) {
        let settings = container.settingsService.settings
        guard let scheme = settings.savedColorSchemes.first(where: { $0.name == name }) else { return }
        
        var updatedSettings = settings
        updatedSettings.selectedThemeColor = .custom
        updatedSettings.mainWindowThemeColor = .custom
        updatedSettings.customThemeColorHex = scheme.statusBarHex
        updatedSettings.customMainWindowThemeColorHex = scheme.mainWindowHex
        updatedSettings.customBackgroundColorHex = scheme.bgHex
        updatedSettings.customAccentColorHex = scheme.accentHex
        updatedSettings.customCardBackgroundColorHex = scheme.cardHex
        updatedSettings.customTextColorHex = scheme.textHex
        updatedSettings.customBorderColorHex = scheme.borderHex
        updatedSettings.customDividerColorHex = scheme.dividerHex
        updatedSettings.customCornerRadius = scheme.cornerRadius
        updatedSettings.activeColorSchemeName = name
        
        container.settingsService.updateSettings(updatedSettings)
        reloadSettings() // reload properties in view model
        LoggerService.shared.info("Color scheme '\(name)' loaded successfully.")
    }
    
    func deleteColorScheme(name: String) {
        var settings = container.settingsService.settings
        settings.savedColorSchemes.removeAll(where: { $0.name == name })
        if settings.activeColorSchemeName == name {
            settings.activeColorSchemeName = nil
        }
        container.settingsService.updateSettings(settings)
        savedColorSchemes = settings.savedColorSchemes
        activeColorSchemeName = settings.activeColorSchemeName
        LoggerService.shared.info("Color scheme '\(name)' deleted.")
    }

    func updateGodMode(_ enabled: Bool) {
        godModeEnabled = enabled
        var settings = container.settingsService.settings
        settings.godModeEnabled = enabled
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("God Mode status toggled to: \(enabled)")
    }

    func updateLayoutEditing(_ enabled: Bool) {
        isLayoutEditingEnabled = enabled
        var settings = container.settingsService.settings
        settings.isLayoutEditingEnabled = enabled
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Layout editing status toggled to: \(enabled)")
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
        settings.psychologyEmpathyLevel = psychologyEmpathyLevel
        settings.psychologyClinicalDepth = psychologyClinicalDepth
        settings.psychologyReframingIntensity = psychologyReframingIntensity
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Psychology settings updated in SettingsViewModel")
    }

    func updateProHumanSettings() {
        var settings = container.settingsService.settings
        settings.proHumanMissionFocus = proHumanMissionFocus
        settings.proHumanInteractionStyle = proHumanInteractionStyle
        settings.proHumanCustomTriangleText = proHumanCustomTriangleText
        settings.proHumanAntiAlgorithmIntensity = proHumanAntiAlgorithmIntensity
        settings.proHumanSelfReflectionInterval = proHumanSelfReflectionInterval
        settings.proHumanScreenTimeTherapy = proHumanScreenTimeTherapy
        settings.proHumanCognitiveResistance = proHumanCognitiveResistance
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Pro Human settings updated in SettingsViewModel")
    }

    func updateShowMainWindowOnAutoLaunch(_ enabled: Bool) {
        showMainWindowOnAutoLaunch = enabled
        var settings = container.settingsService.settings
        settings.showMainWindowOnAutoLaunch = enabled
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Show main window on auto launch changed to: \(enabled)")
    }
    
    func updateShowMainWindowOnManualLaunch(_ enabled: Bool) {
        showMainWindowOnManualLaunch = enabled
        var settings = container.settingsService.settings
        settings.showMainWindowOnManualLaunch = enabled
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Show main window on manual launch changed to: \(enabled)")
    }

    struct SkillParameter: Identifiable, Codable, Equatable {
        var id = UUID()
        var name: String
        var type: String // "string", "number", "boolean"
        var description: String
        var isRequired: Bool
    }

    @Published var editingSkillParameters: [SkillParameter] = []
    @Published var currentEditorStep: Int = 1

    func parseParametersJSON(_ jsonStr: String) -> [SkillParameter] {
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        
        var list: [SkillParameter] = []
        let properties = json["properties"] as? [String: Any] ?? [:]
        let requiredList = json["required"] as? [String] ?? []
        
        for (key, val) in properties {
            if let dict = val as? [String: Any] {
                let type = dict["type"] as? String ?? "string"
                let desc = dict["description"] as? String ?? ""
                let isRequired = requiredList.contains(key)
                list.append(SkillParameter(id: UUID(), name: key, type: type, description: desc, isRequired: isRequired))
            }
        }
        return list
    }
    
    func generateJSONSchema() -> String {
        var properties: [String: Any] = [:]
        var required: [String] = []
        
        for param in editingSkillParameters {
            let name = param.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            
            var prop: [String: Any] = [:]
            prop["type"] = param.type
            prop["description"] = param.description
            properties[name] = prop
            
            if param.isRequired {
                required.append(name)
            }
        }
        
        let schema: [String: Any] = [
            "type": "object",
            "properties": properties,
            "required": required
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted]),
           let jsonStr = String(data: data, encoding: .utf8) {
            return jsonStr
        }
        return "{}"
    }

    func refreshSkillsList() {
        customSkills = SkillService.shared.customSkills
    }

    func startAddSkill() {
        selectedSkillToEdit = nil
        editingSkillName = ""
        editingSkillDescription = ""
        editingSkillScriptType = "shell"
        editingSkillParameters = [
            SkillParameter(name: "paramName", type: "string", description: "参数描述", isRequired: true)
        ]
        editingSkillParametersJSON = generateJSONSchema()
        editingSkillScriptContent = "echo \"{{paramName}}\""
        testOutput = ""
        currentEditorStep = 1
        showSkillEditor = true
    }

    func startEditSkill(_ skill: LLMSkill) {
        selectedSkillToEdit = skill
        editingSkillName = skill.name
        editingSkillDescription = skill.description
        editingSkillScriptType = skill.scriptType
        editingSkillParameters = parseParametersJSON(skill.parametersJSON)
        editingSkillParametersJSON = skill.parametersJSON
        editingSkillScriptContent = skill.scriptContent
        testOutput = ""
        currentEditorStep = 1
        showSkillEditor = true
    }

    func saveSkill() {
        guard !editingSkillName.isEmpty else { return }
        
        editingSkillParametersJSON = generateJSONSchema()
        
        let newSkill = LLMSkill(
            name: editingSkillName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: editingSkillDescription,
            parametersJSON: editingSkillParametersJSON,
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
        
        editingSkillParametersJSON = generateJSONSchema()
        
        Task {
            var mockArgs: [String: Any] = [:]
            for param in editingSkillParameters {
                let name = param.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                if param.type == "string" {
                    mockArgs[name] = "测试文本"
                } else if param.type == "number" {
                    mockArgs[name] = 42.0
                } else if param.type == "boolean" {
                    mockArgs[name] = true
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

    func installCLITool() {
        isInstallingCLI = true
        cliInstallStatus = "正在安装中..."
        
        Task {
            do {
                try await CLIInstaller.install()
                await MainActor.run {
                    self.isCLIInstalled = true
                    self.cliInstallStatus = "安装成功 (已写入 /usr/local/bin/ytskill)"
                    self.isInstallingCLI = false
                }
            } catch {
                await MainActor.run {
                    self.cliInstallStatus = "安装失败: \(error.localizedDescription)"
                    self.isInstallingCLI = false
                }
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
        DependencyContainer.shared.anniversaryService.forceSyncAndReloadWidget()
        LoggerService.shared.info("Theme color changed to: \(theme.rawValue)")
    }
    
    func updateCustomThemeColorHex(_ hex: String) {
        customThemeColorHex = hex
        selectedThemeColor = .custom
        var settings = container.settingsService.settings
        settings.customThemeColorHex = hex
        settings.selectedThemeColor = .custom
        container.settingsService.updateSettings(settings)
        DependencyContainer.shared.anniversaryService.forceSyncAndReloadWidget()
        LoggerService.shared.info("Custom theme color hex changed to: \(hex)")
    }

    func updateShowStatusBarIcon(_ show: Bool) {
        showStatusBarIcon = show
        var settings = container.settingsService.settings
        settings.showStatusBarIcon = show
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Show status bar icon changed to: \(show)")
    }

    func selectMainWindowThemeColor(_ theme: ThemeColor) {
        mainWindowThemeColor = theme
        var settings = container.settingsService.settings
        settings.mainWindowThemeColor = theme
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Main window theme color changed to: \(theme.rawValue)")
    }
    
    func updateCustomMainWindowThemeColorHex(_ hex: String) {
        customMainWindowThemeColorHex = hex
        mainWindowThemeColor = .custom
        var settings = container.settingsService.settings
        settings.customMainWindowThemeColorHex = hex
        settings.mainWindowThemeColor = .custom
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Custom main window theme color hex changed to: \(hex)")
    }
    
    func toggleShowMainWindowOnAutoLaunch() {
        showMainWindowOnAutoLaunch.toggle()
        var settings = container.settingsService.settings
        settings.showMainWindowOnAutoLaunch = showMainWindowOnAutoLaunch
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Show main window on auto launch changed to: \(showMainWindowOnAutoLaunch)")
    }
    
    func toggleShowMainWindowOnManualLaunch() {
        showMainWindowOnManualLaunch.toggle()
        var settings = container.settingsService.settings
        settings.showMainWindowOnManualLaunch = showMainWindowOnManualLaunch
        container.settingsService.updateSettings(settings)
        LoggerService.shared.info("Show main window on manual launch changed to: \(showMainWindowOnManualLaunch)")
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

// MARK: - CommandLineInstructionView

struct CommandLineInstructionRow: View {
    let cmd: String
    let desc: String
    @State private var isCopied = false
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("// \(desc)")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
            
            HStack {
                Text(cmd)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(hex: "30D158")) // Terminal green
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cmd, forType: .string)
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        isCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            isCopied = false
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .imageScale(.small)
                            .foregroundColor(isCopied ? .green : .white.opacity(0.8))
                        Text(isCopied ? "已复制" : "复制")
                            .font(.system(size: 9))
                            .foregroundColor(isCopied ? .green : .white.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(isHovered ? 0.15 : 0.06))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.03))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
    }
}

struct CommandLineInstructionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(Color.primary.opacity(0.08))
                .padding(.vertical, 4)
                
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "AF52DE"))
                Text("终端命令用法示例")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }
            
            Text("安装后，您可以在终端中使用 `ytskill` 命令行工具来调试或运行大模型技能：")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
            
            // Terminal block simulating macOS terminal window
            VStack(alignment: .leading, spacing: 0) {
                // Title Bar
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "FF5F56")).frame(width: 8, height: 8)
                    Circle().fill(Color(hex: "FFBD2E")).frame(width: 8, height: 8)
                    Circle().fill(Color(hex: "27C93F")).frame(width: 8, height: 8)
                    Spacer()
                    Text("ytskill - terminal")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Spacer()
                    Spacer().frame(width: 36)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                
                // Content area
                VStack(spacing: 12) {
                    CommandLineInstructionRow(
                        cmd: "ytskill list",
                        desc: "列出当前所有已注册的技能脚本 (预设与自定义)"
                    )
                    CommandLineInstructionRow(
                        cmd: "ytskill run system_garbage_cleanup",
                        desc: "运行系统预设技能：垃圾清理 (清除无用缓存)"
                    )
                    CommandLineInstructionRow(
                        cmd: "ytskill run reminders_manager --args '{\"title\":\"买牛奶\"}'",
                        desc: "运行系统预设技能：提醒事项，支持传入参数"
                    )
                    CommandLineInstructionRow(
                        cmd: "ytskill run search_web --args '{\"query\":\"Tahoe\"}'",
                        desc: "运行系统预设技能：网页搜索，并传递搜索参数"
                    )
                }
                .padding(12)
                .background(Color.black.opacity(0.75))
            }
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
        }
        .padding(.vertical, 4)
    }
}


// MARK: - 上帝模式组件定制面板
private struct ComponentCustomizationPanel: View {
    let layout: ComponentLayout
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
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
            
            // 自定义字号大小
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
            
            // 自定义主题色
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
                            if let hex = color.toHex(), !Color.isHexClose(hex, layout.customColorHex ?? "") {
                                var newLayout = layout
                                newLayout.customColorHex = hex
                                viewModel.updateComponentLayout(newLayout)
                            }
                        }
                    ))
                    .labelsHidden()
                }
            }
            
            // 上帝模式拉伸与位置调整
            if viewModel.godModeEnabled {
                Divider()
                    .background(Color.primary.opacity(0.08))
                    .padding(.vertical, 4)
                
                Text("拉伸与位置调整 (上帝模式)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "007AFF"))
                
                // 宽度比例
                HStack(spacing: 8) {
                    Text("宽度比例")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Slider(value: Binding(
                        get: { layout.customWidthScale ?? 1.0 },
                        set: { val in
                            var newLayout = layout
                            newLayout.customWidthScale = val
                            viewModel.updateComponentLayout(newLayout)
                        }
                    ), in: 0.4...1.0, step: 0.05)
                    
                    Text("\(Int((layout.customWidthScale ?? 1.0) * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                
                // 自定义高度
                HStack(spacing: 8) {
                    Text("自定义高度")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Toggle("开启", isOn: Binding(
                        get: { layout.customHeight != nil },
                        set: { hasHeight in
                            var newLayout = layout
                            newLayout.customHeight = hasHeight ? 180 : nil
                            viewModel.updateComponentLayout(newLayout)
                        }
                    ))
                    .font(.system(size: 11))
                    .toggleStyle(.checkbox)
                    
                    if let height = layout.customHeight {
                        Slider(value: Binding(
                            get: { height },
                            set: { val in
                                var newLayout = layout
                                newLayout.customHeight = val
                                viewModel.updateComponentLayout(newLayout)
                            }
                        ), in: 50...500, step: 5)
                        
                        Text("\(Int(height))px")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 45, alignment: .trailing)
                    } else {
                        Spacer()
                        Text("自动适应")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                // 水平偏移 X
                HStack(spacing: 8) {
                    Text("水平偏移 X")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Slider(value: Binding(
                        get: { layout.customOffsetX ?? 0 },
                        set: { val in
                            var newLayout = layout
                            newLayout.customOffsetX = val == 0 ? nil : val
                            viewModel.updateComponentLayout(newLayout)
                        }
                    ), in: -150...150, step: 2)
                    
                    Text("\(Int(layout.customOffsetX ?? 0))px")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 45, alignment: .trailing)
                }
                
                // 垂直偏移 Y
                HStack(spacing: 8) {
                    Text("垂直偏移 Y")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Slider(value: Binding(
                        get: { layout.customOffsetY ?? 0 },
                        set: { val in
                            var newLayout = layout
                            newLayout.customOffsetY = val == 0 ? nil : val
                            viewModel.updateComponentLayout(newLayout)
                        }
                    ), in: -150...150, step: 2)
                    
                    Text("\(Int(layout.customOffsetY ?? 0))px")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 45, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - 可点击变量标签

struct VariableTag: View {
    let name: String
    let description: String
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(name, forType: .string)
        }) {
            HStack(spacing: 3) {
                Text(name)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "FF6B9D"))
                Text(description)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color(hex: "FF6B9D").opacity(0.15) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(hex: "FF6B9D").opacity(isHovered ? 0.4 : 0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("点击复制 \(name) 到剪贴板")
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
