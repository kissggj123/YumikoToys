//
//  YumiScriptIDEView.swift
//  YumikoToys
//
//  独立可拖动、可调大小的 YumiScript 专业可视化 IDE 编辑器面板
//

import SwiftUI
import AppKit
import Combine

// MARK: - IDE 独立窗口管理器

@MainActor
final class YumiScriptIDEManager: ObservableObject {
    static let shared = YumiScriptIDEManager()
    
    @Published var isPresented: Bool = false
    @Published var editingPlugin: YumiPlugin = YumiPlugin(
        id: "",
        name: "",
        icon: "bolt.fill",
        description: "",
        isEnabled: true,
        scriptContent: ""
    )
    @Published var isCreating: Bool = false
    
    private var windowController: NSWindowController?
    private var idePanel: NSPanel?
    
    private init() {}
    
    /// 打开独立 IDE 窗口
    func open(plugin: YumiPlugin?, isCreating: Bool = false) {
        self.isCreating = isCreating
        if let p = plugin {
            self.editingPlugin = p
        } else {
            self.editingPlugin = YumiPlugin(
                id: "plugin_\(UUID().uuidString.prefix(6).lowercased())",
                name: "新自动化插件",
                icon: "bolt.fill",
                description: "自定义自动化功能",
                isEnabled: true,
                scriptContent: """
                # YumiScript 自动化脚本
                sys ip
                notify "网络状态诊断" "$OUTPUT"
                """
            )
        }
        
        self.isPresented = true
        showIDEPanel()
    }
    
    /// 关闭独立 IDE 窗口
    func close() {
        self.isPresented = false
        idePanel?.orderOut(nil)
    }
    
    private func showIDEPanel() {
        if idePanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 880, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "YumiScript Studio"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = false
            panel.level = .normal
            panel.minSize = NSSize(width: 750, height: 500)
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = NSColor.windowBackgroundColor
            panel.hasShadow = true
            
            let hosting = NSHostingView(rootView: YumiScriptIDEView(manager: self))
            panel.contentView = hosting
            panel.center()
            panel.setFrameAutosaveName("YumiScriptIDEPanelFrame")
            self.idePanel = panel
        }
        
        idePanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - IDE 主界面

struct YumiScriptIDEView: View {
    @ObservedObject var manager: YumiScriptIDEManager
    @ObservedObject var pluginService = PluginService.shared
    
    enum IDETab: String, CaseIterable {
        case split = "分栏视图"
        case visual = "积木工具箱"
        case codeOnly = "纯代码模式"
    }
    
    @State private var selectedTab: IDETab = .split
    @State private var testLogs: String = ""
    @State private var isRunningTest = false
    @State private var showSaveToast = false
    @State private var isConsoleExpanded = true
    
    // 积木临时配置参数
    @State private var blockAppName: String = "Safari"
    @State private var blockNotifyTitle: String = "执行结果"
    @State private var blockNotifyMsg: String = "$OUTPUT"
    @State private var blockOpenTarget: String = "https://github.com"
    @State private var blockCopyText: String = "$OUTPUT"
    @State private var blockShellCmd: String = "echo \"Hello YumiScript\""
    @State private var blockWaitSec: Double = 1.0
    @State private var blockVarName: String = "my_var"
    @State private var blockVarExpr: String = "\"CustomValue\""
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - IDE 顶部导航与工具栏
            ideHeaderBar
            
            Divider()
            
            // MARK: - IDE 工作区主体
            HStack(spacing: 0) {
                // 左侧：动作积木工具箱（在 split 或 visual 模式下显示）
                if selectedTab == .split || selectedTab == .visual {
                    ideToolboxSidebar
                        .frame(width: selectedTab == .visual ? nil : 290)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                    
                    if selectedTab == .split {
                        Divider()
                    }
                }
                
                // 右侧：代码编辑器与控制台（在 split 或 codeOnly 模式下显示）
                if selectedTab == .split || selectedTab == .codeOnly {
                    VStack(spacing: 0) {
                        ideCodeEditorArea
                        
                        if isConsoleExpanded && !testLogs.isEmpty {
                            Divider()
                            ideConsolePanel
                                .frame(height: 160)
                        }
                    }
                }
            }
            
            Divider()
            
            // MARK: - IDE 底部状态栏
            ideStatusBar
        }
        .frame(minWidth: 750, minHeight: 500)
        .overlay(alignment: .bottom) {
            if showSaveToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("插件保存成功！")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.85)))
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: showSaveToast)
    }
    
    // MARK: - 顶部标题与工具栏
    
    private var ideHeaderBar: some View {
        HStack(spacing: 12) {
            // 左侧应用标识与插件名称
            HStack(spacing: 8) {
                SafeSFSymbolView(manager.editingPlugin.icon, fallback: "bolt.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AboutThemeConfig.current().primaryColor)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(AboutThemeConfig.current().primaryColor.opacity(0.15)))
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        TextField("插件名称", text: $manager.editingPlugin.name)
                            .font(.system(size: 13, weight: .bold))
                            .textFieldStyle(.plain)
                            .frame(minWidth: 100, maxWidth: 180)
                        
                        Text("(\(manager.editingPlugin.id))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    
                    TextField("简要描述功能...", text: $manager.editingPlugin.description)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .textFieldStyle(.plain)
                        .frame(minWidth: 150, maxWidth: 260)
                }
            }
            .padding(.leading, 70) // 给系统红绿灯留出空间
            
            Spacer()
            
            // 视图切换
            Picker("", selection: $selectedTab) {
                ForEach(IDETab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            
            Spacer()
            
            // 右侧操作按钮
            HStack(spacing: 8) {
                // 图标选择
                HStack(spacing: 3) {
                    Text("图标:")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    TextField("图标", text: $manager.editingPlugin.icon)
                        .font(.system(size: 10.5, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
                
                // 运行测试按钮
                Button {
                    runScriptTest()
                } label: {
                    HStack(spacing: 4) {
                        if isRunningTest {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                        }
                        Text("运行 (⌘R)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AboutThemeConfig.current().linearGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: AboutThemeConfig.current().primaryColor.opacity(0.35), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(isRunningTest)
                .keyboardShortcut("r", modifiers: .command)
                
                // 保存插件按钮
                Button {
                    savePlugin()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 9))
                        Text("保存 (⌘S)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(AboutThemeConfig.current().primaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(AboutThemeConfig.current().primaryColor.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - 动作积木工具箱侧边栏
    
    private var ideToolboxSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("动作积木库", systemImage: "square.grid.2x2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AboutThemeConfig.current().primaryColor)
                    Spacer()
                    Text("点选参数插入")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 2)
                
                // 1. 系统控制动作
                VStack(alignment: .leading, spacing: 6) {
                    Text("⚙️ 系统控制 (System Control)")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        blockCard("📶 网络诊断", icon: "wifi") {
                            insertLine("sys ip\nnotify \"网络状态诊断\" \"$OUTPUT\"")
                        }
                        blockCard("📊 CPU 负载", icon: "cpu") {
                            insertLine("sys cpu\nnotify \"系统负载速查\" \"$OUTPUT\"")
                        }
                        blockCard("💾 磁盘空间", icon: "internaldrive") {
                            insertLine("sys disk\nnotify \"主磁盘空间概览\" \"$OUTPUT\"")
                        }
                        blockCard("🔒 锁定屏幕", icon: "lock.fill") {
                            insertLine("sys lock")
                        }
                        blockCard("🗑️ 清废纸篓", icon: "trash.fill") {
                            insertLine("sys emptytrash\nnotify \"废纸篓\" \"已清空\"")
                        }
                        blockCard("🌓 外观切换", icon: "circle.righthalf.filled") {
                            insertLine("sys toggletheme\nnotify \"系统外观\" \"$OUTPUT\"")
                        }
                        blockCard("⚡ 释放内存", icon: "bolt.fill") {
                            insertLine("sys purge\nnotify \"内存释放\" \"$OUTPUT\"")
                        }
                        blockCard("🔇 静音切换", icon: "speaker.slash.fill") {
                            insertLine("sys togglemute")
                        }
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
                
                // 2. 弹窗与通知积木
                VStack(alignment: .leading, spacing: 6) {
                    Text("🔔 弹窗与结果通知 (Dialog / HUD)")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        TextField("标题", text: $blockNotifyTitle)
                            .font(.system(size: 10.5))
                            .textFieldStyle(.roundedBorder)
                        TextField("内容", text: $blockNotifyMsg)
                            .font(.system(size: 10.5))
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button("+ 插入弹窗通知") {
                        insertLine("notify \"\(blockNotifyTitle)\" \"\(blockNotifyMsg)\"")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
                
                // 3. 启动应用积木
                VStack(alignment: .leading, spacing: 6) {
                    Text("🚀 启动应用程序 (Launch App)")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        TextField("应用名", text: $blockAppName)
                            .font(.system(size: 10.5))
                            .textFieldStyle(.roundedBorder)
                        
                        Button("+ 插入") {
                            insertLine("launch \"\(blockAppName)\"")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    HStack(spacing: 3) {
                        ForEach(["Safari", "Terminal", "Xcode", "Finder", "Music"], id: \.self) { name in
                            Button(name) {
                                blockAppName = name
                                insertLine("launch \"\(name)\"")
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.primary.opacity(0.06)))
                        }
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
                
                // 4. 自定义变量定义
                VStack(alignment: .leading, spacing: 6) {
                    Text("📝 自定义变量 (Variables)")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        TextField("变量名", text: $blockVarName)
                            .font(.system(size: 10.5))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                        Text("=")
                            .font(.system(size: 11, weight: .bold))
                        TextField("表达式", text: $blockVarExpr)
                            .font(.system(size: 10.5))
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button("+ 插入变量赋值") {
                        insertLine("var \(blockVarName) = \(blockVarExpr)")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
                
                // 5. 更多操作 (打开网址、延时)
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🌐 打开网址/路径")
                            .font(.system(size: 10, weight: .bold))
                        HStack(spacing: 2) {
                            TextField("网址", text: $blockOpenTarget)
                                .font(.system(size: 10))
                                .textFieldStyle(.roundedBorder)
                            Button("+") {
                                insertLine("open \"\(blockOpenTarget)\"")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.03)))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("⏱️ 等待延时")
                            .font(.system(size: 10, weight: .bold))
                        HStack(spacing: 2) {
                            Stepper("\(String(format: "%.1f", blockWaitSec))s", value: $blockWaitSec, in: 0.5...10.0, step: 0.5)
                                .font(.system(size: 10))
                            Button("+") {
                                insertLine("wait \(String(format: "%.1f", blockWaitSec))")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.03)))
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - 代码编辑主区
    
    private var ideCodeEditorArea: some View {
        VStack(spacing: 0) {
            // 变量快速插入条
            HStack(spacing: 6) {
                Text("快速插入变量:")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                
                quickVariableChip("+ $OUTPUT") { insertSnippet(" $OUTPUT") }
                quickVariableChip("+ $CLIPBOARD") { insertSnippet(" $CLIPBOARD") }
                quickVariableChip("+ $DATE") { insertSnippet(" $DATE") }
                quickVariableChip("+ $TIME") { insertSnippet(" $TIME") }
                quickVariableChip("+ $USER") { insertSnippet(" $USER") }
                quickVariableChip("+ $HOME") { insertSnippet(" $HOME") }
                
                Spacer()
                
                Text("\(manager.editingPlugin.scriptContent.components(separatedBy: .newlines).count) 行")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            // 代码编辑器
            TextEditor(text: $manager.editingPlugin.scriptContent)
                .font(.system(size: 12.5, design: .monospaced))
                .lineSpacing(3)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor))
        }
    }
    
    // MARK: - 控制台输出面板
    
    private var ideConsolePanel: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AboutThemeConfig.current().primaryColor)
                    Text("运行控制台 (Console Output)")
                        .font(.system(size: 11, weight: .bold))
                }
                
                Spacer()
                
                Button {
                    copyToClipboard(testLogs)
                } label: {
                    Label("复制日志", systemImage: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AboutThemeConfig.current().primaryColor)
                
                Button {
                    testLogs = ""
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            
            Divider()
            
            ScrollView {
                Text(testLogs)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .textSelection(.enabled)
            }
            .background(Color.black.opacity(0.05))
        }
    }
    
    // MARK: - 底部状态栏
    
    private var ideStatusBar: some View {
        HStack(spacing: 12) {
            Toggle("在状态栏展示此插件", isOn: $manager.editingPlugin.isEnabled)
                .toggleStyle(CheckboxToggleStyle())
                .font(.system(size: 11))
            
            Spacer()
            
            Button(action: {
                isConsoleExpanded.toggle()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: isConsoleExpanded ? "chevron.down" : "chevron.up")
                    Text(isConsoleExpanded ? "收起控制台" : "展开控制台")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Text("YumiScript IDE v4.0")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AboutThemeConfig.current().primaryColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(AboutThemeConfig.current().primaryColor.opacity(0.1)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - 辅助操作
    
    private func blockCard(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(AboutThemeConfig.current().primaryColor)
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.08), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }
    
    private func quickVariableChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9.5, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(AboutThemeConfig.current().primaryColor.opacity(0.1)))
                .foregroundStyle(AboutThemeConfig.current().primaryColor)
        }
        .buttonStyle(.plain)
    }
    
    private func insertLine(_ line: String) {
        if manager.editingPlugin.scriptContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            manager.editingPlugin.scriptContent = line
        } else {
            manager.editingPlugin.scriptContent += "\n" + line
        }
    }
    
    private func insertSnippet(_ snippet: String) {
        manager.editingPlugin.scriptContent += snippet
    }
    
    private func runScriptTest() {
        isRunningTest = true
        isConsoleExpanded = true
        Task {
            let logs = await YumiScriptEngine.execute(manager.editingPlugin.scriptContent)
            testLogs = logs
            isRunningTest = false
        }
    }
    
    private func savePlugin() {
        pluginService.addOrUpdatePlugin(manager.editingPlugin)
        showSaveToast = true
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            showSaveToast = false
        }
    }
}
