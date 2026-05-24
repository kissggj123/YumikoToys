//
//  CodeHighlightView.swift
//  YumikoToys
//
//  代码语法高亮视图 - 包装 Highlightr 库，支持条件编译回退
//

import SwiftUI
import AppKit

// MARK: - 支持的编程语言

/// 代码高亮支持的语言列表
enum CodeLanguage: String, CaseIterable, Identifiable {
    case swift
    case python
    case javascript
    case typescript
    case go
    case rust
    case java
    case c
    case cpp
    case json
    case xml
    case yaml
    case markdown
    case sql
    case bash
    case html
    case css

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .go: return "Go"
        case .rust: return "Rust"
        case .java: return "Java"
        case .c: return "C"
        case .cpp: return "C++"
        case .json: return "JSON"
        case .xml: return "XML"
        case .yaml: return "YAML"
        case .markdown: return "Markdown"
        case .sql: return "SQL"
        case .bash: return "Bash"
        case .html: return "HTML"
        case .css: return "CSS"
        }
    }

    /// Highlightr 使用的语言标识符
    var highlightrIdentifier: String {
        switch self {
        case .cpp: return "cpp"
        case .javascript: return "javascript"
        case .typescript: return "typescript"
        default: return rawValue
        }
    }

    /// 根据字符串自动检测语言
    static func detect(from languageString: String?) -> CodeLanguage? {
        guard let string = languageString?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return nil
        }
        return allCases.first { $0.rawValue == string }
    }
}

// MARK: - 代码高亮视图

/// 代码语法高亮视图
/// 包装 Highlightr 库提供语法高亮，若未安装则回退到等宽文本渲染
@MainActor
struct CodeHighlightView: View {
    /// 代码内容
    let code: String
    /// 编程语言（可选，用于语法高亮）
    let language: String?
    /// 高亮主题名称（默认使用 atom-one-dark）
    let theme: String

    /// 复制成功提示状态
    @State private var showCopied = false
    /// 鼠标悬停状态
    @State private var isHovered = false

    /// 默认深色主题
    private static let defaultTheme = "atom-one-dark"

    /// 代码背景色（卡片色）
    private var codeBackgroundColor: Color {
        Color(hex: "1A1A1E")
    }

    /// 代码内嵌背景色（更深一层）
    private var codeInnerBackgroundColor: Color {
        Color(hex: "141418")
    }

    init(code: String, language: String? = nil, theme: String = defaultTheme) {
        self.code = code
        self.language = language
        self.theme = theme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部工具栏：语言标签 + 复制按钮
            headerBar

            // 代码内容区域
            codeContent
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(codeBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - 顶部工具栏

    /// 顶部栏：语言标签 + 复制按钮
    private var headerBar: some View {
        HStack {
            // 语言标签
            if let language = language, !language.isEmpty {
                languageBadge(language)
            } else {
                // 未指定语言时显示 "Code"
                languageBadge("Code")
            }

            Spacer()

            // 复制按钮
            copyButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color(hex: "252530")
        )
    }

    /// 语言标签徽章
    private func languageBadge(_ name: String) -> some View {
        Text(name.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color(hex: "8B949E"))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color(hex: "2D2D3A"))
            )
    }

    /// 复制按钮
    private var copyButton: some View {
        Button(action: copyCode) {
            HStack(spacing: 4) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .medium))

                if showCopied {
                    Text("已复制")
                        .font(.system(size: 10, weight: .medium))
                }
            }
            .foregroundStyle(showCopied ? Color(hex: "10B981") : Color(hex: "8B949E"))
            .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .opacity(isHovered || showCopied ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: showCopied)
    }

    // MARK: - 代码内容

    /// 代码内容区域（条件编译选择渲染方式）
    @ViewBuilder
    private var codeContent: some View {
        #if canImport(Highlightr)
        highlightrCodeView
        #else
        fallbackCodeView
        #endif
    }

    // MARK: - Highlightr 渲染

    #if canImport(Highlightr)
    /// 使用 Highlightr 进行语法高亮渲染
    private var highlightrCodeView: some View {
        ScrollView([.vertical, .horizontal]) {
            ScrollViewReader { proxy in
                HighlightrCodeRepresentable(
                    code: code,
                    language: language,
                    theme: theme
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(codeInnerBackgroundColor)
    }
    #endif

    // MARK: - 回退渲染

    /// 回退方案：使用等宽文本 + 简单代码样式
    private var fallbackCodeView: some View {
        ScrollView([.vertical, .horizontal]) {
            Text(code)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(Color(hex: "E6EDF3"))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .background(codeInnerBackgroundColor)
    }

    // MARK: - 操作

    /// 复制代码到剪贴板
    private func copyCode() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)

        withAnimation(.easeInOut(duration: 0.2)) {
            showCopied = true
        }

        // 2 秒后重置复制状态
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopied = false
            }
        }
    }
}

// MARK: - Highlightr NSViewRepresentable

#if canImport(Highlightr)
import Highlightr

/// Highlightr 的 NSViewRepresentable 包装器
/// 将 Highlightr 的代码高亮渲染结果嵌入 SwiftUI 视图层级
@MainActor
struct HighlightrCodeRepresentable: NSViewRepresentable {
    let code: String
    let language: String?
    let theme: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.backgroundColor = .clear
        textView.textColor = NSColor(hex: "E6EDF3")

        // 配置 Highlightr
        if let highlightr = Highlightr() {
            // 设置主题
            highlightr.setTheme(to: theme)

            // 高亮代码
            let lang = language.flatMap { CodeLanguage.detect(from: $0) }?.highlightrIdentifier ?? language
            if let highlighted = highlightr.highlight(code, as: lang) {
                textView.textStorage?.setAttributedString(highlighted)
            } else {
                // 高亮失败时使用纯文本
                textView.string = code
            }
        } else {
            // Highlightr 初始化失败时使用纯文本
            textView.string = code
        }

        // 设置字体
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // 代码内容不频繁变化，无需额外更新逻辑
    }
}
#endif

// MARK: - NSColor Hex 扩展（Highlightr 回退使用）

#if canImport(Highlightr)
extension NSColor {
    /// 从十六进制字符串创建 NSColor
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif

// MARK: - Preview

struct CodeHighlightView_Previews: SwiftUI.PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Swift 代码示例
            CodeHighlightView(
                code: """
                import SwiftUI

                struct ContentView: View {
                    @State private var count = 0

                    var body: some View {
                        VStack {
                            Text("Count: \\(count)")
                                .font(.title)
                            Button("Increment") {
                                count += 1
                            }
                        }
                    }
                }
                """,
                language: "swift"
            )
            .frame(width: 500)

            // Python 代码示例
            CodeHighlightView(
                code: """
                def fibonacci(n: int) -> list[int]:
                    \"\"\"Generate Fibonacci sequence.\"\"\"
                    if n <= 0:
                        return []
                    fib = [0, 1]
                    for i in range(2, n):
                        fib.append(fib[i-1] + fib[i-2])
                    return fib[:n]
                """,
                language: "python"
            )
            .frame(width: 500)

            // 无语言指定
            CodeHighlightView(
                code: "echo 'Hello, World!'",
                language: nil
            )
            .frame(width: 500)
        }
        .padding(24)
        .frame(width: 560, height: 700)
        .background(Color(hex: "0F0F12"))
    }
}
