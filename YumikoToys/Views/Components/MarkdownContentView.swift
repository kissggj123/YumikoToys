//
//  MarkdownContentView.swift
//  YumikoToys
//
//  Markdown 内容渲染视图 - 包装 swift-markdown-ui 库，支持条件编译回退
//

import SwiftUI

// MARK: - Markdown 内容视图

/// Markdown 内容渲染视图
/// 包装 swift-markdown-ui 库提供丰富的 Markdown 渲染，若未安装则回退到纯文本
@MainActor
struct MarkdownContentView: View {
    /// Markdown 原始内容
    let markdown: String

    /// 最大内容宽度（nil 表示自适应）
    var maxWidth: CGFloat? = nil

    init(markdown: String, maxWidth: CGFloat? = nil) {
        self.markdown = markdown
        self.maxWidth = maxWidth
    }

    var body: some View {
        #if canImport(MarkdownUI)
        markdownUIView
        #else
        fallbackView
        #endif
    }

    // MARK: - MarkdownUI 渲染

    #if canImport(MarkdownUI)
    /// 使用 MarkdownUI 库渲染 Markdown 内容
    private var markdownUIView: some View {
        Markdown(markdown)
            .markdownTheme(.yumikoDark)
            .textSelection(.enabled)
            .frame(maxWidth: maxWidth, alignment: .leading)
    }
    #endif

    // MARK: - 回退渲染

    /// 回退方案：渲染为纯文本
    private var fallbackView: some View {
        // 移除 Markdown 语法标记，显示纯文本
        Text(strippedMarkdown)
            .font(.system(size: 14))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: maxWidth, alignment: .leading)
    }

    /// 移除常见 Markdown 语法标记
    private var strippedMarkdown: String {
        var result = markdown
        // 移除代码块标记
        result = result.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)
        // 移除行内代码标记
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)
        // 移除标题标记
        result = result.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
        // 移除粗体标记
        result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
        // 移除斜体标记
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        // 移除链接标记，保留文本
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        return result
    }
}

// MARK: - MarkdownUI 主题扩展

#if canImport(MarkdownUI)
import MarkdownUI

extension Theme {
    /// YumikoToys 深色主题
    /// 匹配应用整体深色设计风格（背景 #0F0F12，卡片 #1A1A1E）
    static var yumikoDark: Theme {
        var theme = Theme()
        // 文本样式
        theme = theme.text {
            ForegroundColor(.white)
            FontSize(14)
        }
        // 强调色（链接）
        theme = theme.link {
            ForegroundColor(Color(hex: "3B82F6"))
            FontWeight(.medium)
        }
        // 段落
        theme = theme.paragraph { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: 0, bottom: 8)
        }
        // 标题
        theme = theme.heading1 { configuration in
            configuration.label
                .foregroundColor(.white)
                .font(.system(size: 24, weight: .bold))
                .markdownMargin(top: 0, bottom: 12)
        }
        theme = theme.heading2 { configuration in
            configuration.label
                .foregroundColor(.white)
                .font(.system(size: 20, weight: .bold))
                .markdownMargin(top: 0, bottom: 10)
        }
        theme = theme.heading3 { configuration in
            configuration.label
                .foregroundColor(Color(hex: "E6EDF3"))
                .font(.system(size: 17, weight: .semibold))
                .markdownMargin(top: 0, bottom: 8)
        }
        theme = theme.heading4 { configuration in
            configuration.label
                .foregroundColor(Color(hex: "E6EDF3"))
                .font(.system(size: 15, weight: .semibold))
                .markdownMargin(top: 0, bottom: 6)
        }
        theme = theme.heading5 { configuration in
            configuration.label
                .foregroundColor(Color(hex: "D1D5DB"))
                .font(.system(size: 14, weight: .semibold))
                .markdownMargin(top: 0, bottom: 4)
        }
        theme = theme.heading6 { configuration in
            configuration.label
                .foregroundColor(Color(hex: "9CA3AF"))
                .font(.system(size: 13, weight: .semibold))
                .markdownMargin(top: 0, bottom: 4)
        }
        // 强调文本（粗体）
        theme = theme.strong {
            ForegroundColor(.white)
            FontWeight(.bold)
        }
        // 强调文本（斜体）
        theme = theme.emphasis {
            ForegroundColor(Color(hex: "D1D5DB"))
            FontStyle(.italic)
        }
        // 行内代码
        theme = theme.code {
            FontFamilyVariant(.monospaced)
            FontSize(13)
            ForegroundColor(Color(hex: "E6EDF3"))
            BackgroundColor(Color(hex: "2D2D3A"))
        }
        // 代码块
        theme = theme.codeBlock { configuration in
            configuration.label
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color(hex: "E6EDF3"))
                .padding(12)
                .background(Color(hex: "1A1A1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .markdownMargin(top: 8, bottom: 8)
        }
        // 引用块
        theme = theme.blockquote { configuration in
            configuration.label
                .foregroundColor(Color(hex: "9CA3AF"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "1A1A1E"))
                .overlay(
                    Rectangle()
                        .fill(Color(hex: "3B82F6"))
                        .frame(width: 3),
                    alignment: .leading
                )
                .markdownMargin(top: 8, bottom: 8)
        }
        // 列表项
        theme = theme.listItem { configuration in
            configuration.label
                .markdownMargin(top: 4, bottom: 4)
        }
        // 表格
        theme = theme.table { configuration in
            configuration.label
                .markdownMargin(top: 8, bottom: 8)
        }
        theme = theme.tableCell { configuration in
            configuration.label
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        // 图片
        theme = theme.image { configuration in
            configuration.label
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .markdownMargin(top: 8, bottom: 8)
        }
        return theme
    }
}
#endif
