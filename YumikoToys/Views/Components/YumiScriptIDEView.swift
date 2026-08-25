//
//  YumiScriptIDEView.swift
//  YumikoToys
//
//  VS Code 风格的专业级 YumiScript Studio 可视化 IDE 开发套件
//  支持：新建空白脚本、多标签文件管理、AI Copilot 智能编写与诊断、丰富系统 API 与 OCR/TTS 积木库、自制扩展插件
//

import SwiftUI
import AppKit
import Combine

// MARK: - IDE 独立窗口与工程文档管理器

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
    
    /// 当前已打开的文件标签列表 (VS Code Tabs)
    @Published var openPlugins: [YumiPlugin] = []
    @Published var activePluginId: String = ""
    
    private var idePanel: NSWindow?
    
    private init() {}
    
    func clearPanel() {
        self.idePanel = nil
    }
    
    /// 打开独立 IDE 窗口
    func open(plugin: YumiPlugin?, isCreating: Bool = false) {
        self.isCreating = isCreating
        
        if let p = plugin {
            self.editingPlugin = p
            if !openPlugins.contains(where: { $0.id == p.id }) {
                openPlugins.append(p)
            }
            activePluginId = p.id
        } else {
            // 新建完全空白的纯净脚本
            let newId = "plugin_\(UUID().uuidString.prefix(6).lowercased())"
            let newPlugin = YumiPlugin(
                id: newId,
                name: isCreating ? "新建空白脚本" : "新自动化插件",
                icon: "sparkles",
                description: "自制 YumiScript 自动化脚本",
                isEnabled: true,
                scriptContent: "" // 100% 空白，不预设杂乱代码
            )
            self.editingPlugin = newPlugin
            openPlugins.append(newPlugin)
            activePluginId = newId
        }
        
        self.isPresented = true
        showIDEPanel()
    }
    
    /// 新建一个空白文件标签
    func createNewBlankTab() {
        let newId = "plugin_\(UUID().uuidString.prefix(6).lowercased())"
        let newPlugin = YumiPlugin(
            id: newId,
            name: "未命名脚本-\(openPlugins.count + 1)",
            icon: "doc.badge.plus",
            description: "",
            isEnabled: true,
            scriptContent: ""
        )
        self.editingPlugin = newPlugin
        self.openPlugins.append(newPlugin)
        self.activePluginId = newId
    }
    
    /// 切换当前激活的文件
    func switchToFile(_ plugin: YumiPlugin) {
        // 先同步当前正在编辑的内容
        if let idx = openPlugins.firstIndex(where: { $0.id == editingPlugin.id }) {
            openPlugins[idx] = editingPlugin
        }
        self.editingPlugin = plugin
        self.activePluginId = plugin.id
    }
    
    /// 关闭指定文件标签
    func closeTab(id: String) {
        guard let idx = openPlugins.firstIndex(where: { $0.id == id }) else { return }
        openPlugins.remove(at: idx)
        
        if activePluginId == id {
            if let next = openPlugins.last {
                self.editingPlugin = next
                self.activePluginId = next.id
            } else {
                // 如果标签全关了，自动创建一个空白文档
                createNewBlankTab()
            }
        }
    }
    
    /// 关闭独立 IDE 窗口
    func close() {
        self.isPresented = false
        idePanel?.orderOut(nil)
        self.idePanel = nil
    }
    
    private func showIDEPanel() {
        if idePanel == nil {
            let panel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1040, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "YumiScript Studio IDE"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.level = .normal
            panel.minSize = NSSize(width: 820, height: 560)
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = NSColor.windowBackgroundColor
            panel.hasShadow = true
            panel.isExcludedFromWindowsMenu = false
            panel.collectionBehavior = [.managed, .participatesInCycle, .fullScreenPrimary]
            panel.identifier = NSUserInterfaceItemIdentifier("YumiScriptIDEWindow")
            panel.isReleasedWhenClosed = false
            panel.delegate = YumiScriptIDEWindowDelegate.shared
            
            let hosting = FirstMouseHostingView(rootView: YumiScriptIDEView(manager: self))
            panel.contentView = hosting
            panel.center()
            panel.setFrameAutosaveName("YumiScriptIDEPanelFrame")
            self.idePanel = panel
        }
        
        idePanel?.deminiaturize(nil)
        idePanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - IDE 窗口生命周期委托

@MainActor
final class YumiScriptIDEWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = YumiScriptIDEWindowDelegate()
    
    func windowWillClose(_ notification: Notification) {
        YumiScriptIDEManager.shared.isPresented = false
        YumiScriptIDEManager.shared.clearPanel()
    }
}

// MARK: - YumiScript 语法高亮引擎 (预编译缓存)

enum YumiScriptSyntaxHighlighter {
    private static let ipRegex = try? NSRegularExpression(pattern: #"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b|\b\d+(\.\d+)?\b"#)
    private static let keywordRegex: NSRegularExpression? = {
        let keywords = [
            "ai", "ask", "glm", "tts", "say", "speak", "ocr", "http", "fetch",
            "alert", "choose", "select", "def", "call", "run", "var", "let", "set",
            "sys", "system", "notify", "dialog", "toast", "hud", "launch", "open",
            "wait", "sleep", "shell", "copy", "paste", "ping", "applescript", "osascript"
        ]
        let pattern = #"\b("# + keywords.joined(separator: "|") + #")\b"#
        return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }()
    private static let varRegex = try? NSRegularExpression(pattern: #"\$[A-Za-z0-9_]+"#)
    private static let stringRegex = try? NSRegularExpression(pattern: #""[^"\\]*(?:\\.[^"\\]*)*""#)
    private static let commentRegex = try? NSRegularExpression(pattern: #"(#|//).*$"#, options: .anchorsMatchLines)

    static func highlight(text: String, themePrimary: NSColor, fontSize: CGFloat = 13.5) -> NSAttributedString {
        let attr = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        guard fullRange.length > 0 else { return attr }
        
        let defaultFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let baseColor = NSColor(white: 0.92, alpha: 1.0)
        
        attr.addAttribute(.font, value: defaultFont, range: fullRange)
        attr.addAttribute(.foregroundColor, value: baseColor, range: fullRange)
        
        // 1. IP 地址、纯数字与浮点数 (明亮青蓝 / 霓虹青)
        if let regex = ipRegex {
            regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                if let r = match?.range {
                    attr.addAttribute(.foregroundColor, value: NSColor(red: 0.35, green: 0.85, blue: 0.95, alpha: 1.0), range: r)
                    attr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium), range: r)
                }
            }
        }
        
        // 2. 核心关键字 (主题色高亮 / 活力加粗)
        if let regex = keywordRegex {
            regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                if let r = match?.range {
                    attr.addAttribute(.foregroundColor, value: themePrimary, range: r)
                    attr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold), range: r)
                }
            }
        }
        
        // 3. 环境变量与系统变量 ($OUTPUT, $CLIPBOARD, $DATE, $TIME, $USER, $HOME 等)
        if let regex = varRegex {
            regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                if let r = match?.range {
                    attr.addAttribute(.foregroundColor, value: NSColor(red: 1.0, green: 0.72, blue: 0.28, alpha: 1.0), range: r)
                    attr.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold), range: r)
                }
            }
        }
        
        // 4. 字符串常量 ("...") (温暖杏黄 / 蜜桃橙)
        if let regex = stringRegex {
            regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                if let r = match?.range {
                    attr.addAttribute(.foregroundColor, value: NSColor(red: 0.96, green: 0.65, blue: 0.42, alpha: 1.0), range: r)
                }
            }
        }
        
        // 5. 注释行 (# ... 或 // ...) (清新绿意 / 覆盖全行最高优先级)
        if let regex = commentRegex {
            regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                if let r = match?.range {
                    attr.addAttribute(.foregroundColor, value: NSColor(red: 0.45, green: 0.82, blue: 0.52, alpha: 1.0), range: r)
                }
            }
        }
        
        return attr
    }
}

// MARK: - 原生富文本高亮代码编辑器

struct YumiScriptCodeEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    var themePrimary: Color
    var fontSize: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1.0)
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.delegate = context.coordinator
        
        context.coordinator.textView = textView
        context.coordinator.applyHighlighting(text: text)
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string.trimmingCharacters(in: .newlines) != text.trimmingCharacters(in: .newlines) {
                context.coordinator.applyHighlighting(text: text)
            }
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: YumiScriptCodeEditorRepresentable
        weak var textView: NSTextView?
        private var isUpdating = false
        
        init(_ parent: YumiScriptCodeEditorRepresentable) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let tv = textView, !isUpdating else { return }
            let newText = tv.string
            parent.text = newText
            
            let selectedRanges = tv.selectedRanges
            applyHighlighting(text: newText)
            tv.selectedRanges = selectedRanges
        }
        
        func applyHighlighting(text: String) {
            guard let tv = textView else { return }
            isUpdating = true
            let nsColor = NSColor(parent.themePrimary)
            let highlighted = YumiScriptSyntaxHighlighter.highlight(text: text, themePrimary: nsColor, fontSize: parent.fontSize)
            tv.textStorage?.setAttributedString(highlighted)
            isUpdating = false
        }
    }
}

// MARK: - IDE 主界面 (VS Code 风格架构)

struct YumiScriptIDEView: View {
    @ObservedObject var manager: YumiScriptIDEManager
    @ObservedObject var pluginService = PluginService.shared
    @ObservedObject private var animeThemeService = AnimeThemeService.shared
    
    /// VS Code 风格活动栏视图切换
    enum ActivitySection: String, CaseIterable {
        case explorer = "资源管理器"
        case toolbox = "动作积木"
        case copilot = "AI 助手"
        case extensions = "插件扩展"
        case settings = "偏好设置"
        
        var icon: String {
            switch self {
            case .explorer: return "folder.fill"
            case .toolbox: return "puzzlepiece.extension.fill"
            case .copilot: return "sparkles"
            case .extensions: return "square.grid.2x2.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    @State private var activeSection: ActivitySection = .toolbox
    @State private var isSidebarVisible: Bool = true
    @State private var testLogs: String = ""
    @State private var isRunningTest = false
    @State private var showSaveToast = false
    @State private var isConsoleExpanded = true
    @State private var editorFontSize: CGFloat = 13.5
    @State private var fileSearchQuery: String = ""
    
    // AI Copilot 交互状态
    @State private var copilotPrompt: String = ""
    @State private var copilotResponse: String = ""
    @State private var isCopilotLoading: Bool = false
    
    // 自定义扩展插件状态
    @State private var newMacroName: String = ""
    @State private var newMacroSnippet: String = ""
    
    private var theme: AboutThemeConfig {
        AboutThemeConfig.current()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // MARK: - 1. VS Code 风格最左侧活动栏 (Activity Bar)
            activityBar
                .frame(width: 48)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
            
            Divider()
            
            // MARK: - 2. 侧边功能栏 (Sidebar)
            if isSidebarVisible {
                sidebarPanel
                    .frame(width: 280)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                
                Divider()
            }
            
            // MARK: - 3. 核心编辑工作区 (Editor & Tabs)
            VStack(spacing: 0) {
                // 顶部文件标签栏 (VS Code Editor Tabs)
                editorTabsBar
                
                Divider()
                
                // 代码编辑区
                ideCodeEditorArea
                
                // 底部可折叠控制台
                if isConsoleExpanded && !testLogs.isEmpty {
                    Divider()
                    ideConsolePanel
                        .frame(height: 160)
                }
                
                Divider()
                
                // 底部状态栏
                ideStatusBar
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .overlay(alignment: .bottom) {
            if showSaveToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("插件保存成功！已实时同步至状态栏与系统扩展")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.88)))
                .padding(.bottom, 36)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28), value: showSaveToast)
    }
    
    // MARK: - 活动栏 (Activity Bar)
    
    private var activityBar: some View {
        VStack(spacing: 12) {
            // 顶层 Logo 徽章
            SafeSFSymbolView(manager.editingPlugin.icon, fallback: "bolt.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.primaryColor)
                .frame(width: 32, height: 32)
                .background(Circle().fill(theme.primaryColor.opacity(0.18)))
                .padding(.top, 14)
            
            Divider().padding(.horizontal, 8)
            
            // 各功能按钮
            ForEach(ActivitySection.allCases, id: \.self) { section in
                Button(action: {
                    if activeSection == section && isSidebarVisible {
                        isSidebarVisible = false
                    } else {
                        activeSection = section
                        isSidebarVisible = true
                    }
                }) {
                    Image(systemName: section.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(activeSection == section && isSidebarVisible ? theme.primaryColor : Color.secondary)
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(activeSection == section && isSidebarVisible ? theme.primaryColor.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(section.rawValue)
            }
            
            Spacer()
            
            // 快速运行测试按钮
            Button(action: {
                runScriptTest()
            }) {
                Image(systemName: isRunningTest ? "arrow.triangle.2.circlepath" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.green)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.green.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .help("运行脚本测试 (Cmd+R)")
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - 侧边面板 (Sidebar Panel)
    
    private var sidebarPanel: some View {
        VStack(spacing: 0) {
            // 侧边栏标题头
            HStack {
                Text(activeSection.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryColor)
                
                Spacer()
                
                if activeSection == .explorer {
                    Button(action: {
                        manager.createNewBlankTab()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.primaryColor)
                    }
                    .buttonStyle(.plain)
                    .help("新建空白脚本")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            Divider()
            
            // 侧边栏内容路由
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    switch activeSection {
                    case .explorer:
                        explorerView
                    case .toolbox:
                        toolboxView
                    case .copilot:
                        copilotView
                    case .extensions:
                        extensionsView
                    case .settings:
                        settingsView
                    }
                }
                .padding(10)
            }
        }
    }
    
    // MARK: - 1. 资源管理器 (Explorer)
    
    private var explorerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 搜索过滤框
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("搜索脚本...", text: $fileSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor).opacity(0.5)))
            
            // 快捷新建大按钮
            Button(action: {
                manager.createNewBlankTab()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(theme.primaryColor)
                    Text("新建空白脚本 (.yumi)")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(theme.primaryColor.opacity(0.1)))
            }
            .buttonStyle(.plain)
            
            Text("工程脚本清单 (\(pluginService.customPlugins.count))")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            
            ForEach(pluginService.customPlugins.filter { fileSearchQuery.isEmpty || $0.name.localizedCaseInsensitiveContains(fileSearchQuery) }) { plugin in
                HStack(spacing: 6) {
                    SafeSFSymbolView(plugin.icon, fallback: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(manager.activePluginId == plugin.id ? theme.primaryColor : .secondary)
                    
                    Text(plugin.name)
                        .font(.system(size: 11, weight: manager.activePluginId == plugin.id ? .semibold : .regular))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if manager.activePluginId == plugin.id {
                        Circle().fill(theme.primaryColor).frame(width: 6, height: 6)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(manager.activePluginId == plugin.id ? theme.primaryColor.opacity(0.15) : Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    manager.switchToFile(plugin)
                }
            }
        }
    }
    
    // MARK: - 2. 动作积木与 API 手册 (Toolbox)
    
    private var toolboxView: some View {
        VStack(spacing: 10) {
            // 🤖 AI 大模型 API
            toolboxGroup(title: "🤖 AI 大模型 Copilot", color: .purple) {
                toolboxItem("AI 智能生成文本", code: "ai \"请帮我写一段关于早安的问候语\"\nnotify \"AI 问候\" \"$OUTPUT\"", icon: "sparkles")
                toolboxItem("AI 总结剪贴板内容", code: "paste\nai \"请帮我简要总结以下内容：\\n$OUTPUT\"\nnotify \"AI 总结报告\" \"$OUTPUT\"", icon: "doc.text.magnifyingglass")
            }
            
            // 👁️ 视觉 OCR 与 🗣️ 语音合成
            toolboxGroup(title: "👁️ 视觉 OCR & 🗣️ 语音", color: .orange) {
                toolboxItem("屏幕原生 OCR 识别", code: "ocr\ncopy \"$OUTPUT\"\nnotify \"OCR 识别完成\" \"已复制识别文字至剪贴板\"", icon: "text.viewfinder")
                toolboxItem("系统语音朗读 TTS", code: "tts \"主人您好，今日任务已全部自动化处理完毕。\"", icon: "speaker.wave.3.fill")
                toolboxItem("蜂鸣提示音", code: "sys beep", icon: "bell.fill")
            }
            
            // 🌐 网络与 HTTP API
            toolboxGroup(title: "🌐 HTTP 网络请求", color: .cyan) {
                toolboxItem("HTTP GET 请求", code: "http get \"https://api.github.com/zen\"\nnotify \"GitHub Zen\" \"$OUTPUT\"", icon: "network")
                toolboxItem("网络连通与延迟诊断", code: "sys ip\nnotify \"网络诊断\" \"$OUTPUT\"", icon: "wifi")
            }
            
            // ⚡ 系统控制与硬件 API
            toolboxGroup(title: "⚡ 硬件与系统控制", color: .blue) {
                toolboxItem("调节音量 (50%)", code: "sys volume 50", icon: "speaker.wave.2.fill")
                toolboxItem("查看电池状态", code: "sys battery\nnotify \"电池健康\" \"$OUTPUT\"", icon: "battery.100")
                toolboxItem("一键清空废纸篓", code: "sys emptytrash\nnotify \"系统清理\" \"废纸篓已清空\"", icon: "trash.fill")
                toolboxItem("释放内存缓存", code: "sys purge\nnotify \"内存加速\" \"内存缓存已极速释放\"", icon: "bolt.fill")
                toolboxItem("一键锁屏", code: "sys lock", icon: "lock.fill")
                toolboxItem("切换深浅色外观", code: "sys toggletheme", icon: "circle.righthalf.filled")
            }
            
            // 💬 交互式弹窗与通知
            toolboxGroup(title: "💬 弹窗与交互", color: .green) {
                toolboxItem("精美 HUD 渲染弹窗", code: "notify \"任务完成\" \"所有流程执行成功！\"", icon: "app.badge")
                toolboxItem("模态确认弹窗", code: "alert \"确认执行\" \"是否立即开始自动化？\"\nnotify \"用户选择\" \"用户点击了：$OUTPUT\"", icon: "bubble.left.and.bubble.right.fill")
                toolboxItem("列表单选菜单", code: "choose \"选项A,选项B,选项C\"\nnotify \"选中项目\" \"$OUTPUT\"", icon: "list.bullet.rectangle")
            }
        }
    }
    
    // MARK: - 3. Yumi AI 智能助手 (AI Copilot)
    
    private var copilotView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("输入您的需求，AI 将自动生成合法的 YumiScript 代码：")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            TextEditor(text: $copilotPrompt)
                .font(.system(size: 12))
                .frame(height: 70)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor).opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.primaryColor.opacity(0.3), lineWidth: 1))
            
            HStack {
                Button(action: {
                    generateCodeWithAI()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopilotLoading ? "arrow.triangle.2.circlepath" : "sparkles")
                        Text(isCopilotLoading ? "AI 生成中..." : "一键生成脚本")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(theme.primaryColor))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isCopilotLoading || copilotPrompt.isEmpty)
            }
            
            if !copilotResponse.isEmpty {
                Divider()
                
                Text("AI 生成结果：")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.primaryColor)
                
                ScrollView {
                    Text(copilotResponse)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.3)))
                }
                .frame(maxHeight: 180)
                
                HStack(spacing: 8) {
                    Button("插入光标位置") {
                        smartInsert(copilotResponse)
                    }
                    .font(.system(size: 11))
                    
                    Button("替换全部代码") {
                        manager.editingPlugin.scriptContent = copilotResponse
                    }
                    .font(.system(size: 11))
                }
            }
        }
    }
    
    // MARK: - 4. 自制扩展插件 (Extensions)
    
    private var extensionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YumiScript 支持使用 `def <宏名>` 自制 IDE 插件扩展函数，并可在任何脚本中通过 `call <宏名>` 极速调用：")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("插件名称:")
                    .font(.system(size: 10, weight: .bold))
                TextField("例如: clean_mac", text: $newMacroName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
            }
            
            Button("插入自定义过程模板") {
                let name = newMacroName.isEmpty ? "my_custom_plugin" : newMacroName
                let template = """
                # 自制扩展过程: \(name)
                def \(name)
                    sys emptytrash
                    sys purge
                    notify "\(name) 执行完成" "内存与垃圾已彻底清理"
                end
                
                # 调用自制过程
                call \(name)
                """
                smartInsert(template)
            }
            .buttonStyle(.borderedProminent)
            .font(.system(size: 11))
        }
    }
    
    // MARK: - 5. IDE 偏好设置 (Settings)
    
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("编辑器外观与排版")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.primaryColor)
            
            HStack {
                Text("字体大小 (\(Int(editorFontSize)) pt):")
                    .font(.system(size: 11))
                Spacer()
                Button("-") { if editorFontSize > 10 { editorFontSize -= 1 } }
                Button("+") { if editorFontSize < 22 { editorFontSize += 1 } }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("当前全局跟随主题:")
                    .font(.system(size: 11))
                HStack(spacing: 6) {
                    Circle().fill(theme.primaryColor).frame(width: 12, height: 12)
                    Text("主色调已与状态栏/主界面全链路同频")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - 辅助积木组件
    
    private func toolboxGroup<Content: View>(title: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            
            content()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.18), lineWidth: 1))
    }
    
    private func toolboxItem(_ title: String, code: String, icon: String) -> some View {
        Button(action: {
            smartInsert(code)
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.primaryColor)
                Text(title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .controlBackgroundColor).opacity(0.8)))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - VS Code 多标签页栏 (Editor Tabs Bar)
    
    private var editorTabsBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(manager.openPlugins) { plugin in
                        HStack(spacing: 6) {
                            SafeSFSymbolView(plugin.icon, fallback: "doc.text.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(manager.activePluginId == plugin.id ? theme.primaryColor : .secondary)
                            
                            Text(plugin.name.isEmpty ? "未命名脚本" : plugin.name)
                                .font(.system(size: 11, weight: manager.activePluginId == plugin.id ? .semibold : .regular))
                                .lineLimit(1)
                            
                            Button(action: {
                                manager.closeTab(id: plugin.id)
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            manager.activePluginId == plugin.id ?
                            Color(nsColor: .textBackgroundColor).opacity(0.6) :
                            Color.clear
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            manager.switchToFile(plugin)
                        }
                    }
                    
                    // 新建空白标签按钮
                    Button(action: {
                        manager.createNewBlankTab()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .help("新建空白脚本标签")
                }
            }
            
            Spacer()
            
            // 插件元数据与保存栏
            HStack(spacing: 8) {
                TextField("插件名称", text: $manager.editingPlugin.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 110)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: .controlBackgroundColor)))
                
                Button(action: {
                    runScriptTest()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isRunningTest ? "arrow.triangle.2.circlepath" : "play.fill")
                        Text("运行")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.green.opacity(0.2)))
                    .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    savePlugin()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("保存")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 5).fill(theme.primaryColor))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
    }
    
    // MARK: - 代码编辑区域
    
    private var ideCodeEditorArea: some View {
        ZStack(alignment: .bottomTrailing) {
            YumiScriptCodeEditorRepresentable(
                text: $manager.editingPlugin.scriptContent,
                themePrimary: theme.primaryColor,
                fontSize: editorFontSize
            )
            .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
        }
    }
    
    // MARK: - 控制台输出面板
    
    private var ideConsolePanel: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isRunningTest ? Color.orange : Color.green)
                        .frame(width: 7, height: 7)
                    Text("执行日志输出 (Console)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.primaryColor)
                }
                
                Spacer()
                
                Button("清空") {
                    testLogs = ""
                }
                .font(.system(size: 10))
                
                Button(action: {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(testLogs, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("复制日志")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
            
            ScrollView(.vertical, showsIndicators: true) {
                Text(testLogs)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(white: 0.88))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color.black.opacity(0.65))
        }
    }
    
    // MARK: - 底部状态栏
    
    private var ideStatusBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("YumiScript v5.0")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            
            Text("行数: \(manager.editingPlugin.scriptContent.components(separatedBy: .newlines).count)")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.secondary)
            
            Text("字符数: \(manager.editingPlugin.scriptContent.count)")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("UTF-8 | LF")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
    }
    
    // MARK: - 辅助操作逻辑
    
    private func smartInsert(_ snippet: String) {
        let trimmed = manager.editingPlugin.scriptContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            manager.editingPlugin.scriptContent = snippet
        } else {
            manager.editingPlugin.scriptContent = trimmed + "\n\n" + snippet
        }
    }
    
    private func runScriptTest() {
        isRunningTest = true
        isConsoleExpanded = true
        Task { @MainActor in
            let logs = await YumiScriptEngine.execute(manager.editingPlugin.scriptContent)
            testLogs = logs
            isRunningTest = false
        }
    }
    
    private func savePlugin() {
        guard !manager.editingPlugin.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        pluginService.addOrUpdatePlugin(manager.editingPlugin)
        showSaveToast = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            showSaveToast = false
        }
    }
    
    private func generateCodeWithAI() {
        guard !copilotPrompt.isEmpty else { return }
        isCopilotLoading = true
        Task { @MainActor in
            let systemInstruction = """
            你是一个专业的 YumiScript 自动化脚本编写专家。
            请根据用户的需求，生成一段纯净、语法正确的 YumiScript 代码。
            YumiScript 语法规范：
            - 注释：# 注释文字
            - 变量：var name = value 或 $OUTPUT
            - AI 大模型：ai "提示词"
            - 语音朗读：tts "要播报的语音文本"
            - 视觉文字识别：ocr 或 ocr "/path/to/img.png"
            - 网络请求：http get "url" 或 http post "url" "json"
            - 系统通知/弹窗：notify "标题" "内容" 或 alert "标题" "内容"
            - 系统硬件控制：sys volume 50, sys battery, sys lock, sys emptytrash, sys purge, sys toggletheme
            - 启动应用：launch "应用名" 或 open "URL或路径"
            - 剪贴板：copy "内容" 或 paste
            - 延时：wait 1.5
            - 自定义过程：def process_name ... end 然后 call process_name
            仅输出可以直接运行的 YumiScript 代码，不要添加 markdown 外部说明。
            """
            
            do {
                let prompt = "\(systemInstruction)\n\n用户需求：\(copilotPrompt)"
                let result = try await DependencyContainer.shared.glmService.sendMessage(prompt, context: [], saveToHistory: false)
                copilotResponse = result.replacingOccurrences(of: "```yumiscript", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                copilotResponse = "# AI 生成失败: \(error.localizedDescription)\nnotify \"AI 异常\" \"请检查网络或 API 设置\""
            }
            isCopilotLoading = false
        }
    }
}
