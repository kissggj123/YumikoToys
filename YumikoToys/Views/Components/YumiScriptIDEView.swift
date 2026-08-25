//
//  YumiScriptIDEView.swift
//  YumikoToys
//
//  VS Code + 捷径 (Apple Shortcuts) 风格的专业级 YumiScript Studio 可视化 IDE 套件
//  支持：新建 100% 空白画布、捷径原子能力积木库、一键场景工作流、文件读写/系统通知/YumikoToys自身控制、AI Copilot、自制插件扩展开发
//

import SwiftUI
import AppKit
import Combine

// MARK: - 自制 IDE 插件扩展模型 (Custom Extension Block)

struct CustomIDEBlock: Codable, Identifiable, Sendable, Equatable {
    var id: String
    var title: String
    var icon: String
    var category: String
    var description: String
    var snippetCode: String
}

// MARK: - IDE 独立窗口与工程文档管理器

@MainActor
final class YumiScriptIDEManager: ObservableObject {
    static let shared = YumiScriptIDEManager()
    
    @Published var isPresented: Bool = false
    @Published var editingPlugin: YumiPlugin = YumiPlugin(
        id: "plugin_blank",
        name: "新建空白脚本",
        icon: "sparkles",
        description: "",
        isEnabled: true,
        scriptContent: "" // 100% 保证绝对纯净空白
    )
    @Published var isCreating: Bool = false
    
    /// 当前已打开的文件标签列表 (VS Code Tabs)
    @Published var openPlugins: [YumiPlugin] = []
    @Published var activePluginId: String = ""
    
    /// 用户自制 IDE 插件扩展积木表
    @Published var customUserBlocks: [CustomIDEBlock] = []
    
    private let customBlocksKey = "YumikoToys_UserCustomIDEBlocks_v1"
    private var idePanel: NSWindow?
    
    private init() {
        loadCustomBlocks()
    }
    
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
            // 新建完全空白的纯净脚本 (100% Blank Canvas)
            let newId = "plugin_\(UUID().uuidString.prefix(6).lowercased())"
            let newPlugin = YumiPlugin(
                id: newId,
                name: "新建空白脚本",
                icon: "doc.badge.plus",
                description: "",
                isEnabled: true,
                scriptContent: "" // 100% 绝对纯净空白
            )
            self.editingPlugin = newPlugin
            self.openPlugins = [newPlugin]
            self.activePluginId = newId
        }
        
        self.isPresented = true
        showIDEPanel()
    }
    
    /// 新建一个纯净空白文件标签
    func createNewBlankTab() {
        syncCurrentEditingToOpenList()
        
        let newId = "plugin_\(UUID().uuidString.prefix(6).lowercased())"
        let count = openPlugins.count + 1
        let newPlugin = YumiPlugin(
            id: newId,
            name: "未命名脚本-\(count)",
            icon: "doc.text",
            description: "",
            isEnabled: true,
            scriptContent: "" // 100% 空白
        )
        self.editingPlugin = newPlugin
        self.openPlugins.append(newPlugin)
        self.activePluginId = newId
    }
    
    /// 切换当前激活的文件
    func switchToFile(_ plugin: YumiPlugin) {
        syncCurrentEditingToOpenList()
        self.editingPlugin = plugin
        self.activePluginId = plugin.id
    }
    
    /// 关闭指定文件标签
    func closeTab(id: String) {
        syncCurrentEditingToOpenList()
        guard let idx = openPlugins.firstIndex(where: { $0.id == id }) else { return }
        openPlugins.remove(at: idx)
        
        if activePluginId == id {
            if let next = openPlugins.last {
                self.editingPlugin = next
                self.activePluginId = next.id
            } else {
                createNewBlankTab()
            }
        }
    }
    
    /// 同步当前编辑内容到标签列表
    func syncCurrentEditingToOpenList() {
        if let idx = openPlugins.firstIndex(where: { $0.id == editingPlugin.id }) {
            openPlugins[idx] = editingPlugin
        }
    }
    
    // MARK: - 自制 IDE 插件扩展持久化
    
    func addCustomBlock(_ block: CustomIDEBlock) {
        if let idx = customUserBlocks.firstIndex(where: { $0.id == block.id }) {
            customUserBlocks[idx] = block
        } else {
            customUserBlocks.append(block)
        }
        saveCustomBlocks()
    }
    
    func deleteCustomBlock(id: String) {
        customUserBlocks.removeAll { $0.id == id }
        saveCustomBlocks()
    }
    
    private func loadCustomBlocks() {
        if let data = UserDefaults.standard.data(forKey: customBlocksKey),
           let blocks = try? JSONDecoder().decode([CustomIDEBlock].self, from: data) {
            self.customUserBlocks = blocks
        } else {
            self.customUserBlocks = [
                CustomIDEBlock(
                    id: "ext_clean_mac",
                    title: "一键深度优化 Mac",
                    icon: "wand.and.stars",
                    category: "自制系统扩展",
                    description: "清空废纸篓、释放内存缓存并朗读语音汇报",
                    snippetCode: """
                    # 自制扩展：一键深度优化 Mac
                    sys emptytrash
                    sys purge
                    tts "Mac 内存缓存与废纸篓已全面优化完毕！"
                    notify "优化完成" "已清理垃圾并释放系统缓存"
                    """
                )
            ]
        }
    }
    
    private func saveCustomBlocks() {
        if let data = try? JSONEncoder().encode(customUserBlocks) {
            UserDefaults.standard.set(data, forKey: customBlocksKey)
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
                contentRect: NSRect(x: 0, y: 0, width: 1080, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = "YumiScript Studio IDE"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.level = .normal
            panel.minSize = NSSize(width: 860, height: 580)
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
            "file", "app", "yumiko", "input", "prompt", "askinput",
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
            if textView.string != text {
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

// MARK: - IDE 主界面 (VS Code + 捷径风格架构)

struct YumiScriptIDEView: View {
    @ObservedObject var manager: YumiScriptIDEManager
    @ObservedObject var pluginService = PluginService.shared
    @ObservedObject private var animeThemeService = AnimeThemeService.shared
    
    /// VS Code 风格活动栏视图切换
    enum ActivitySection: String, CaseIterable {
        case toolbox = "捷径动作库"
        case presets = "一键场景模板"
        case explorer = "资源管理器"
        case copilot = "AI Copilot"
        case extensions = "自制插件扩展"
        case settings = "偏好设置"
        
        var icon: String {
            switch self {
            case .toolbox: return "puzzlepiece.extension.fill"
            case .presets: return "wand.and.stars"
            case .explorer: return "folder.fill"
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
    
    // 自制扩展插件创建弹窗
    @State private var showNewExtSheet: Bool = false
    @State private var newExtTitle: String = ""
    @State private var newExtDesc: String = ""
    @State private var newExtIcon: String = "bolt.circle.fill"
    @State private var newExtCategory: String = "我的自制扩展"
    @State private var newExtCode: String = ""
    
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
                    .frame(width: 320)
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
        .frame(minWidth: 860, minHeight: 580)
        .overlay(alignment: .bottom) {
            if showSaveToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("脚本已成功保存！已实时同步至状态栏与系统扩展")
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
        .sheet(isPresented: $showNewExtSheet) {
            newExtensionSheet
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
                } else if activeSection == .extensions {
                    Button(action: {
                        newExtTitle = ""
                        newExtDesc = ""
                        newExtCode = "# 编写您的扩展插件代码\nnotify \"自制插件\" \"运行成功\""
                        showNewExtSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.primaryColor)
                    }
                    .buttonStyle(.plain)
                    .help("新建自定义扩展积木")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            Divider()
            
            // 侧边栏内容路由
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    switch activeSection {
                    case .toolbox:
                        shortcutsToolboxView
                    case .presets:
                        presetWorkflowsView
                    case .explorer:
                        explorerView
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
    
    // MARK: - 1. 捷径原子动作积木库 (Shortcuts Toolbox)
    
    private var shortcutsToolboxView: some View {
        VStack(spacing: 12) {
            // 📁 文件与系统磁盘操作
            toolboxGroup(title: "📁 文件与磁盘管理", color: .yellow) {
                toolboxItem("创建/覆盖写入文件", code: "file write \"~/Desktop/demo.txt\" \"你好，这是由 YumiScript 自动创建的文件！\\n创建时间: $DATETIME\"\nnotify \"文件已保存\" \"已写入 ~/Desktop/demo.txt\"", icon: "doc.badge.plus")
                toolboxItem("追加文本到文件", code: "file append \"~/Desktop/demo.txt\" \"[$DATETIME] 追加记录一条自动化日志\"\nnotify \"日志已记录\" \"已追加内容\"", icon: "doc.append")
                toolboxItem("读取文件内容到变量", code: "file read \"~/Desktop/demo.txt\"\nnotify \"文件内容预览\" \"$OUTPUT\"", icon: "doc.text.magnifyingglass")
                toolboxItem("安全移入废纸篓", code: "file trash \"~/Desktop/demo.txt\"\nnotify \"已删除\" \"文件已移入废纸篓\"", icon: "trash")
                toolboxItem("列出目录内文件", code: "file list \"~/Desktop\"\nnotify \"桌面文件清单\" \"$OUTPUT\"", icon: "folder.badge.gearshape")
                toolboxItem("创建文件夹目录", code: "file mkdir \"~/Desktop/YumiBackup\"\nnotify \"目录创建成功\" \"~/Desktop/YumiBackup\"", icon: "folder.badge.plus")
            }
            
            // 💬 通知、弹窗与交互输入
            toolboxGroup(title: "💬 通知与交互输入", color: .green) {
                toolboxItem("系统通知横幅 + HUD", code: "notify \"任务完成\" \"自动化流程已成功执行完毕！\"", icon: "bell.badge.fill")
                toolboxItem("弹出文本输入框", code: "input \"请输入您要记录的内容:\" \"默认备忘\"\nfile append \"~/Desktop/notes.txt\" \"[$DATETIME] $OUTPUT\"\nnotify \"记录成功\" \"内容已追加到备忘录\"", icon: "character.cursor.ibeam")
                toolboxItem("模态确认对话框", code: "alert \"确认执行\" \"是否立即开始自动化任务？\"\nnotify \"用户决策\" \"用户选择了: $OUTPUT\"", icon: "bubble.left.and.bubble.right.fill")
                toolboxItem("列表单选菜单", code: "choose \"启动 Safari,清空废纸篓,切换主题\"\nnotify \"选中的操作\" \"$OUTPUT\"", icon: "list.bullet.rectangle")
                toolboxItem("语音合成播报 TTS", code: "tts \"主人您好，今日系统任务已全部自动化就绪。\"", icon: "speaker.wave.3.fill")
            }
            
            // 🐰 操控 YumikoToys 本身
            toolboxGroup(title: "🐰 操控 YumikoToys 自身", color: .pink) {
                toolboxItem("召唤 / 隐藏桌面桌宠", code: "app pet toggle\nnotify \"桌宠状态\" \"$OUTPUT\"", icon: "pawprint.fill")
                toolboxItem("切换二次元主题风格", code: "app theme toggle\nnotify \"主题切换\" \"$OUTPUT\"", icon: "paintpalette.fill")
                toolboxItem("查询置顶纪念日倒数", code: "app anniversary\ntts \"$OUTPUT\"\nnotify \"纪念日提醒\" \"$OUTPUT\"", icon: "calendar.badge.clock")
                toolboxItem("触发区域 / 全屏截图", code: "app screenshot area\nnotify \"截图已触发\" \"请框选屏幕区域\"", icon: "viewfinder")
                toolboxItem("启动截图标注工具", code: "app screenshot annotate", icon: "pencil.tip.crop.circle")
            }
            
            // ⚡ 硬件与系统控制
            toolboxGroup(title: "⚡ 硬件与系统深度控制", color: .blue) {
                toolboxItem("调节系统音量 (50%)", code: "sys volume 50\nnotify \"音量调节\" \"音量已调至 50%\"", icon: "speaker.wave.2.fill")
                toolboxItem("查询电池状态", code: "sys battery\nnotify \"电池健康\" \"$OUTPUT\"", icon: "battery.100")
                toolboxItem("一键清空废纸篓", code: "sys emptytrash\nnotify \"系统清理\" \"废纸篓已安全清空\"", icon: "trash.fill")
                toolboxItem("释放内存缓存", code: "sys purge\nnotify \"内存加速\" \"缓存已极速释放\"", icon: "bolt.fill")
                toolboxItem("一键锁定 Mac 屏幕", code: "sys lock", icon: "lock.fill")
                toolboxItem("切换深浅色外观", code: "sys toggletheme", icon: "circle.righthalf.filled")
            }
            
            // 🤖 AI 大模型与 OCR 视觉
            toolboxGroup(title: "🤖 AI 大模型 & OCR 视觉", color: .purple) {
                toolboxItem("AI 智能文本生成", code: "ai \"请帮我写一段关于今日工作的温馨激励语\"\nnotify \"AI 寄语\" \"$OUTPUT\"", icon: "sparkles")
                toolboxItem("屏幕原生 OCR 识别提取", code: "ocr\ncopy \"$OUTPUT\"\nnotify \"OCR 识别完成\" \"识别到的文字已写入剪贴板\"", icon: "text.viewfinder")
                toolboxItem("HTTP 网络 GET 请求", code: "http get \"https://api.github.com/zen\"\nnotify \"GitHub 格言\" \"$OUTPUT\"", icon: "network")
            }
            
            // 🔌 用户自制扩展积木
            if !manager.customUserBlocks.isEmpty {
                toolboxGroup(title: "🔌 我的自制扩展积木", color: .orange) {
                    ForEach(manager.customUserBlocks) { block in
                        toolboxItem(block.title, code: block.snippetCode, icon: block.icon)
                    }
                }
            }
        }
    }
    
    // MARK: - 2. 一键场景工作流 (Preset Workflows)
    
    private var presetWorkflowsView: some View {
        VStack(spacing: 10) {
            Text("精选开箱即用的一键自动化工作流，点击即可装载到编辑器：")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            presetCard(
                title: "📝 每日工作日志快速记录",
                desc: "弹出输入框让您输入今日日志，自动带时间戳追加到桌面工作日志文件，并横幅通知确认",
                icon: "square.and.pencil",
                code: """
                # 每日工作日志记录器
                input "请输入今日已完成的重要工作内容:" "完成功能模块开发与自测"
                file append "~/Desktop/每日工作日志.txt" "[$DATETIME] $OUTPUT"
                notify "日志记录成功" "已保存至 ~/Desktop/每日工作日志.txt"
                """
            )
            
            presetCard(
                title: "🐰 桌宠早安问候与状态体检",
                desc: "唤醒桌面桌宠，查询 Mac 电池与磁盘剩余空间，组织早安汇报并通过原生语音播报",
                icon: "sun.max.fill",
                code: """
                # 桌宠早安互动与体检
                app pet on
                sys battery
                var batt = $OUTPUT
                sys disk
                var disk = $OUTPUT
                tts "主人早安！桌宠已就绪，当前$batt，$disk"
                notify "桌宠早安" "电量与磁盘状态正常，随时听候调遣！"
                """
            )
            
            presetCard(
                title: "🧹 Mac 极速大扫除与体检",
                desc: "一键清空废纸篓、极速释放内存缓存、查询系统负载，居中弹出 HUD 报告",
                icon: "sparkle",
                code: """
                # Mac 一键极速体检与清理
                sys emptytrash
                sys purge
                sys cpu
                var cpu_load = $OUTPUT
                notify "系统清理与体检完毕" "废纸篓已清空，内存缓存已释放\\n$cpu_load"
                """
            )
            
            presetCard(
                title: "👁️ 屏幕 OCR 识字并写入文件",
                desc: "调用 Apple 神经引擎识别屏幕所有文字，自动写入桌面 ocr_result.txt 并复制到剪贴板",
                icon: "text.badge.plus",
                code: """
                # 屏幕 OCR 识字并存盘
                ocr
                file write "~/Desktop/ocr_result.txt" "$OUTPUT"
                copy "$OUTPUT"
                notify "OCR 提取完成" "已保存至桌面 ocr_result.txt 并同步复制到剪贴板"
                """
            )
            
            presetCard(
                title: "🌙 下班专注与息屏休眠",
                desc: "切换赛博二次元主题，将音量调至 20% 并静音，最后锁定 Mac 屏幕",
                icon: "moon.stars.fill",
                code: """
                # 下班休息自动化
                app theme cyber
                sys volume 20
                sys volume mute
                tts "主人辛苦了，正在为您锁定屏幕"
                wait 1.0
                sys lock
                """
            )
        }
    }
    
    private func presetCard(title: String, desc: String, icon: String, code: String) -> some View {
        Button(action: {
            manager.editingPlugin.scriptContent = code
            showSaveToast = true
        }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(theme.primaryColor)
                        .font(.system(size: 13, weight: .bold))
                    Text(title)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.primaryColor)
                }
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.primaryColor.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 3. 资源管理器 (Explorer)
    
    private var explorerView: some View {
        VStack(alignment: .leading, spacing: 8) {
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
    
    // MARK: - 4. Yumi AI 智能助手 (AI Copilot)
    
    private var copilotView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("输入您的自然语言需求，AI 将自动生成完整的 YumiScript 原子脚本：")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            TextEditor(text: $copilotPrompt)
                .font(.system(size: 12))
                .frame(height: 75)
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
    
    // MARK: - 5. 自制扩展插件 (Extensions & Custom Blocks)
    
    private var extensionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("您可以在此开发属于自己的 YumiScript 插件扩展，注册后的扩展积木会直接出现在左侧 API 积木库中：")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            Button(action: {
                newExtTitle = ""
                newExtDesc = ""
                newExtCode = "# 自定义扩展过程\ndef my_tool\n    sys emptytrash\n    notify \"工具运行\" \"已完成\"\nend\n\ncall my_tool"
                showNewExtSheet = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("➕ 开发新扩展积木")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 6).fill(theme.primaryColor))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            
            Divider()
            
            Text("已安装的自制扩展 (\(manager.customUserBlocks.count))")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            
            ForEach(manager.customUserBlocks) { block in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: block.icon)
                            .foregroundStyle(theme.primaryColor)
                        Text(block.title)
                            .font(.system(size: 11, weight: .bold))
                        Spacer()
                        Button(action: {
                            manager.deleteCustomBlock(id: block.id)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(block.description.isEmpty ? "无描述" : block.description)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                    
                    Button("插入此积木") {
                        smartInsert(block.snippetCode)
                    }
                    .font(.system(size: 10))
                    .padding(.top, 2)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
            }
        }
    }
    
    // MARK: - 6. IDE 偏好设置 (Settings)
    
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
    
    // MARK: - 自定义扩展创建表单弹窗
    
    private var newExtensionSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("开发自制 IDE 插件扩展")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(theme.primaryColor)
                Spacer()
                Button("关闭") { showNewExtSheet = false }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("扩展积木标题:")
                    .font(.system(size: 11, weight: .semibold))
                TextField("例如: 自动归档日志", text: $newExtTitle)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("扩展积木描述:")
                    .font(.system(size: 11, weight: .semibold))
                TextField("简要说明功能", text: $newExtDesc)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("底层 YumiScript 脚本代码:")
                    .font(.system(size: 11, weight: .semibold))
                TextEditor(text: $newExtCode)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 120)
                    .background(Color(nsColor: .textBackgroundColor))
                    .border(Color.secondary.opacity(0.3))
            }
            
            HStack {
                Spacer()
                Button("保存并注册到积木库") {
                    guard !newExtTitle.isEmpty else { return }
                    let block = CustomIDEBlock(
                        id: "ext_\(UUID().uuidString.prefix(6).lowercased())",
                        title: newExtTitle,
                        icon: newExtIcon,
                        category: newExtCategory,
                        description: newExtDesc,
                        snippetCode: newExtCode
                    )
                    manager.addCustomBlock(block)
                    showNewExtSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 440, height: 380)
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
                    .frame(width: 120)
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
                Text("YumiScript v6.0 (捷径原子版)")
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
            - 文件操作：
              * file write "路径" "内容" (创建并覆盖写入文件)
              * file append "路径" "内容" (追加内容到文件)
              * file read "路径" (读取文件内容到 $OUTPUT)
              * file delete "路径" (移入废纸篓)
              * file list "目录路径" (列出文件列表)
            - YumikoToys 自身控制：
              * app pet on / off / toggle (召唤/收回桌宠)
              * app theme toggle / cyber / healing / kawaii (切换二次元主题)
              * app anniversary (查询置顶纪念日)
              * app screenshot area / annotate (截图/标注)
            - 交互与通知：
              * notify "标题" "内容" (发送横幅通知 + HUD)
              * input "提示文字" "默认值" (弹出输入框获取用户输入)
              * alert "标题" "内容" (弹出确认对话框)
              * choose "选项1,选项2" (弹出单选框)
              * tts "要播报的语音文本" (语音朗读)
            - AI 与视觉：
              * ai "提示词" (大模型问答)
              * ocr (全屏文字提取)
              * http get "url" (网络请求)
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
