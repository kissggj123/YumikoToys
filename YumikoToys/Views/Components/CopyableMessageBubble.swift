//
//  CopyableMessageBubble.swift
//  YumikoToys
//
//  可爱像素风格消息气泡（v3.6.0 - 用户像素头像物理联动版）
//

import SwiftUI
import MarkdownUI

struct CopyableMessageBubble: View {
    let message: ChatMessage
    let aiAvatarEmoji: String
    
    // 👈【核心新增】：支持从主视图传入当前激活的用户像素头像属性，解决头像不同步问题
    let userAvatarEmoji: String?
    let userAvatarPath: String?

    @State private var isHovered = false
    @State private var showCopied = false

    private var isUser: Bool {
        message.role == "user"
    }

    // UI 隔离过滤器。剔除 System Note，只在气泡里渲染最干净的提问文本。
    private var displayedContent: String {
        let raw = message.content
        if raw.contains("[System Note: Web Search Grounding Integration Enabled]") {
            let parts = raw.components(separatedBy: "User Query: ")
            if parts.count > 1 {
                return parts.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? raw
            }
        }
        return raw
    }

    var body: some View {
        let isStructured = isStructuredContent
        let formattedContent = isStructured ? formattedMarkdownContent : ""

        HStack(alignment: .top, spacing: 12) {
            // AI 头像（仅 AI 消息显示）
            if !isUser {
                BubblePixelAvatarView(emoji: aiAvatarEmoji, size: 36)
                    .padding(.top, 4)
            }

            // 消息内容区
            VStack(alignment: .leading, spacing: 8) {
                // 结构化思考链
                if let thinking = message.thinkingContent, !thinking.isEmpty {
                    BubbleThinkingProcessView(
                        thinkingContent: thinking,
                        duration: nil,
                        hasSearchSources: message.searchSources != nil && !(message.searchSources?.isEmpty ?? true)
                    )
                }

                // 搜索来源
                if let sources = message.searchSources, !sources.isEmpty {
                    SearchSourcesView(sources: sources)
                }

                // 分流渲染普通内容与 Agent 步骤，消灭空白气泡
                if message.isAgentStep {
                    BubbleAgentStepView(content: message.content)
                } else {
                    if !displayedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        messageContentView(isStructured: isStructured, formattedContent: formattedContent)
                    }
                }
            }

            // 👈【重构】：用户头像同步（与陪伴端样式 100% 同步对齐）
            if isUser {
                Group {
                    if let emoji = userAvatarEmoji {
                        // 使用带粉色渐变和像素描边的圆形头像框渲染用户 Emoji
                        BubblePixelAvatarView(emoji: emoji, size: 36)
                    } else if let path = userAvatarPath, let image = NSImage(contentsOfFile: path) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(hex: "FF6B9D").opacity(0.3), lineWidth: 2))
                    } else {
                        BubblePixelAvatarView(emoji: "👤", size: 36)
                    }
                }
                .padding(.top, 4)
            }
        }
        .onHover { isHovered = $0 }
        .overlay(alignment: .topTrailing) {
            if isHovered && !displayedContent.isEmpty && !message.isAgentStep {
                copyButton
                    .offset(x: 8, y: -4)
            }
        }
    }

    // MARK: - 消息内容

    @ViewBuilder
    private func messageContentView(isStructured: Bool, formattedContent: String) -> some View {
        if isUser {
            VStack(alignment: .trailing, spacing: 4) {
                if isStructured {
                    Markdown(formattedContent)
                        .markdownTheme(.gitHub)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                } else {
                    Text(displayedContent)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "FF6B9D").opacity(0.25), radius: 8, x: 0, y: 4)
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if isStructured {
                    Markdown(formattedContent)
                        .markdownTheme(.gitHub)
                        .font(.system(size: 14))
                } else {
                    Text(displayedContent)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: 680, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "FF6B9D").opacity(0.2), Color(hex: "22D3EE").opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
    }

    // MARK: - 内容检测

    private var isStructuredContent: Bool {
        let content = displayedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return false }

        if (content.hasPrefix("{") && content.hasSuffix("}")) ||
           (content.hasPrefix("[") && content.hasSuffix("]")) {
            if let data = content.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return true
            }
        }

        let markdownPatterns = ["```", "### ", "## ", "# ", "- ", "* ", "1. ", "| ", "**", "__"]
        return markdownPatterns.contains { content.contains($0) }
    }

    private var formattedMarkdownContent: String {
        let content = displayedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return "" }

        if (content.hasPrefix("{") && content.hasSuffix("}")) ||
           (content.hasPrefix("[") && content.hasSuffix("]")) {
            if let data = content.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                return "```json\n\(prettyString)\n```"
            }
        }

        return content
    }

    // MARK: - 复制按钮

    private var copyButton: some View {
        Button(action: copyToClipboard) {
            HStack(spacing: 4) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                Text(showCopied ? "已复制" : "复制")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(showCopied ? Color(hex: "34C759") : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayedContent, forType: .string)

        withAnimation(.easeInOut(duration: 0.2)) {
            showCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopied = false
            }
        }
    }
}

// MARK: - 像素头像视图

struct BubblePixelAvatarView: View {
    let emoji: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFE4EC"), Color(hex: "E8D6FF")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color(hex: "FF6B9D").opacity(0.15), radius: 4, x: 0, y: 2)

            Circle()
                .stroke(Color(hex: "FF6B9D").opacity(0.3), lineWidth: 2)
                .frame(width: size, height: size)

            Text(emoji)
                .font(.system(size: size * 0.5))
        }
    }
}

// MARK: - 深度思考过程视图

struct BubbleThinkingProcessView: View {
    let thinkingContent: String
    let duration: TimeInterval?
    let hasSearchSources: Bool

    @State private var isExpanded = false
    @State private var isPulsing = false
    @State private var cooldownWorkItem: DispatchWorkItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Text(hasSearchSources ? "🌐" : "🧠")
                        .font(.system(size: 14))
                        .rotationEffect(.degrees(isPulsing ? 8 : 0))
                        .animation(isPulsing ? Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true) : .default, value: isPulsing)

                    Text(isPulsing ? (hasSearchSources ? "正在检索并消化网络数据..." : "深度思考中...") : (hasSearchSources ? "全网检索剖面" : "深度思考过程"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "8B5CF6"))

                    if isPulsing {
                        Circle()
                            .fill(Color(hex: "8B5CF6"))
                            .frame(width: 5, height: 5)
                            .scaleEffect(isPulsing ? 1.4 : 1.0)
                            .opacity(isPulsing ? 0.8 : 0.4)
                            .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
                    }

                    if let duration = duration {
                        Text("· \(String(format: "%.1f", duration))s")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "8B5CF6"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "8B5CF6").opacity(0.08))
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollViewReader { scrollView in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            Markdown(thinkingContent)
                                .markdownTheme(.gitHub)
                                .font(.system(size: 12, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Spacer()
                                .frame(height: 1)
                                .id("bottom_anchor")
                        }
                    }
                    .frame(maxHeight: 250)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.02))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onChange(of: thinkingContent) { newValue in
                        if isPulsing {
                            withAnimation(.easeOut(duration: 0.15)) {
                                scrollView.scrollTo("bottom_anchor", anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "8B5CF6").opacity(0.15), lineWidth: 1)
        )
        .onChange(of: thinkingContent) { newValue in
            if !newValue.isEmpty {
                if !isExpanded {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                }
                isPulsing = true
                triggerPulseCooldown()
            }
        }
        .onAppear {
            if !thinkingContent.isEmpty {
                isExpanded = false
                isPulsing = false
            }
        }
    }

    private func triggerPulseCooldown() {
        cooldownWorkItem?.cancel()
        let item = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.4)) {
                isPulsing = false
            }
        }
        cooldownWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
    }
}

// MARK: - Agent 步骤自适应可折叠面板

struct BubbleAgentStepView: View {
    let content: String
    @State private var isExpanded = false

    private var extractedContent: (prefix: String, json: String) {
        if let jsonStart = content.firstIndex(of: "{") {
            let prefix = String(content[..<jsonStart]).trimmingCharacters(in: .whitespacesAndNewlines)
            let json = String(content[jsonStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (prefix, json)
        } else if let jsonStart = content.firstIndex(of: "[") {
            let prefix = String(content[..<jsonStart]).trimmingCharacters(in: .whitespacesAndNewlines)
            let json = String(content[jsonStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (prefix, json)
        }
        return (content, "")
    }

    private var parsedHeader: (icon: String, title: String, subtitle: String) {
        let parsed = extractedContent
        var title = "Agent 步骤执行中"
        var icon = "🔧"

        let lowercasedPrefix = parsed.prefix.lowercased()
        if lowercasedPrefix.contains("web_search") || lowercasedPrefix.contains("search") {
            title = "联网搜索完成"
            icon = "🌐"
        } else if lowercasedPrefix.contains("file") || lowercasedPrefix.contains("parse") || lowercasedPrefix.contains("read") {
            title = "文档解析完成"
            icon = "📄"
        }

        var subtitle = parsed.prefix
        subtitle = subtitle.replacingOccurrences(of: "🔧", with: "")
        subtitle = subtitle.replacingOccurrences(of: "调用工具:", with: "")
        subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        return (icon, title, subtitle)
    }

    private var formattedContent: String {
        let parsed = extractedContent
        if !parsed.json.isEmpty {
            if let data = parsed.json.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                return "```json\n\(prettyString)\n```"
            }
            return "```json\n\(parsed.json)\n```"
        }
        return content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Text(parsedHeader.icon)
                        .font(.system(size: 13))

                    Text(parsedHeader.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "8B5CF6"))

                    if !parsedHeader.subtitle.isEmpty {
                        Text("· \(parsedHeader.subtitle)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "8B5CF6"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "8B5CF6").opacity(0.08))
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    MarkdownContentView(markdown: formattedContent)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.02))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "8B5CF6").opacity(0.15), lineWidth: 1)
        )
        .frame(maxWidth: 680, alignment: .leading)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}
