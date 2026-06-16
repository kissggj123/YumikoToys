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
    
    let chatMode: ChatMode
    let themeColor: ResolvedTheme

    // 👈【核心新增】：添加回调以支持快捷操作
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onRegenerate: (() -> Void)? = nil
    var onExecuteProactiveTool: ((AIChatViewModel.ProactiveToolSuggestion) -> Void)? = nil

    @State private var isHovered = false
    @State private var showCopied = false

    // MARK: - 主题相关的色彩属性
    
    private var userBubbleColors: [Color] {
        switch chatMode {
        case .petCompanion:
            return themeColor.iconGradient
        case .aiAssistant:
            return [Color(hex: "059669"), Color(hex: "0891B2")]
        }
    }
    
    private var userBubbleTextColor: Color {
        if chatMode == .petCompanion && themeColor.isAccentLight {
            return Color(red: 0.06, green: 0.09, blue: 0.16)
        }
        return .white
    }
    
    private var userBubbleShadowColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.accentColor.opacity(0.25)
        case .aiAssistant:
            return Color(hex: "059669").opacity(0.25)
        }
    }
    
    private var assistantBorderColors: [Color] {
        switch chatMode {
        case .petCompanion:
            return [themeColor.accentColor.opacity(0.2), Color(hex: "22D3EE").opacity(0.15)]
        case .aiAssistant:
            return [Color(hex: "059669").opacity(0.2), Color(hex: "0891B2").opacity(0.15)]
        }
    }
    
    private var userAvatarBgColors: [Color] {
        switch chatMode {
        case .petCompanion:
            return [Color(hex: "FFE4EC"), Color(hex: "E8D6FF")]
        case .aiAssistant:
            return [Color(hex: "0E1A16"), Color(hex: "0A0F0D")]
        }
    }
    
    private var userAvatarBorderColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.accentColor.opacity(0.3)
        case .aiAssistant:
            return Color(hex: "059669").opacity(0.3)
        }
    }
    
    private var userAvatarShadowColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.accentColor.opacity(0.15)
        case .aiAssistant:
            return Color(hex: "059669").opacity(0.15)
        }
    }
    
    private var aiAvatarBgColors: [Color] {
        switch chatMode {
        case .petCompanion:
            return [Color(hex: "FFE4EC"), Color(hex: "E8D6FF")]
        case .aiAssistant:
            return [Color(hex: "0E1A16"), Color(hex: "0A0F0D")]
        }
    }
    
    private var aiAvatarBorderColor: Color {
        switch chatMode {
        case .petCompanion:
            return Color(hex: "FF6B9D").opacity(0.3)
        case .aiAssistant:
            return Color(hex: "059669").opacity(0.3)
        }
    }
    
    private var aiAvatarShadowColor: Color {
        switch chatMode {
        case .petCompanion:
            return Color(hex: "FF6B9D").opacity(0.15)
        case .aiAssistant:
            return Color(hex: "059669").opacity(0.15)
        }
    }

    private var isUser: Bool {
        message.role == "user"
    }

    private var cornerRadius: CGFloat {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            return CGFloat(DependencyContainer.shared.settingsService.settings.customCornerRadius)
        }
        return 18
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
            if isUser {
                Spacer(minLength: 40)
            }

            // AI 头像（仅 AI 消息显示）
            if !isUser {
                BubblePixelAvatarView(
                    emoji: aiAvatarEmoji,
                    size: 36,
                    bgColors: aiAvatarBgColors,
                    borderColor: aiAvatarBorderColor,
                    shadowColor: aiAvatarShadowColor
                )
                .padding(.top, 4)
            }

            // 消息内容区
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                // 结构化思考链
                if let thinking = message.thinkingContent, !thinking.isEmpty {
                    BubbleThinkingProcessView(
                        thinkingContent: thinking,
                        duration: nil,
                        hasSearchSources: message.searchSources != nil && !(message.searchSources?.isEmpty ?? true),
                        chatMode: chatMode
                    )
                }

                // 搜索来源
                if let sources = message.searchSources, !sources.isEmpty {
                    SearchSourcesView(sources: sources, chatMode: chatMode)
                }

                // 主动工具建议卡片
                if message.isProactiveSuggestion,
                   let toolName = message.proactiveToolName,
                   let toolArgs = message.proactiveToolArgs {
                    ProactiveToolCardView(
                        toolName: toolName,
                        displayName: extractDisplayName(from: toolName),
                        reason: message.content.replacingOccurrences(of: "💡 我可以帮你", with: "").replacingOccurrences(of: "：", with: ""),
                        arguments: toolArgs,
                        confidence: 0.7,
                        onExecute: {
                            let suggestion = AIChatViewModel.ProactiveToolSuggestion(
                                toolName: toolName,
                                arguments: toolArgs,
                                displayName: extractDisplayName(from: toolName),
                                reason: message.content,
                                confidence: 0.7
                            )
                            onExecuteProactiveTool?(suggestion)
                        },
                        onDismiss: {
                            // Remove the suggestion message
                        }
                    )
                } else if message.isAgentStep {
                    // Agent 步骤或工具结果
                    if let toolResult = message.toolResultJSON {
                        VStack(alignment: .leading, spacing: 4) {
                            BubbleAgentStepView(content: message.content, chatMode: chatMode)
                            Button(action: {}) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 9))
                                    Text("查看结果")
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        BubbleAgentStepView(content: message.content, chatMode: chatMode)
                    }
                } else {
                    if !displayedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        messageContentView(isStructured: isStructured, formattedContent: formattedContent)
                    }
                }

                // 👈【核心新增】：鼠标悬浮时在气泡下方显示快捷交互按钮，提升自签名应用下的操作体验
                if isHovered && !message.isAgentStep {
                    HStack(spacing: 8) {
                        if isUser {
                            if let onEdit = onEdit {
                                Button(action: onEdit) {
                                    Label("编辑", systemImage: "pencil")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                                }
                                .buttonStyle(.plain)
                                .help("编辑并重新发送")
                            }
                            if let onDelete = onDelete {
                                Button(action: onDelete) {
                                    Label("撤回", systemImage: "arrow.uturn.backward")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                                }
                                .buttonStyle(.plain)
                                .help("撤回提问")
                            }
                        } else {
                            copyButton
                            
                            if let onRegenerate = onRegenerate {
                                Button(action: onRegenerate) {
                                    Label("重新生成", systemImage: "arrow.clockwise")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                                }
                                .buttonStyle(.plain)
                                .help("重新生成AI回复")
                            }
                            
                            if let onDelete = onDelete {
                                Button(action: onDelete) {
                                    Label("删除", systemImage: "trash")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                                }
                                .buttonStyle(.plain)
                                .help("删除此消息")
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }

            // 👈【重构】：用户头像同步（与陪伴端样式 100% 同步对齐）
            if isUser {
                Group {
                    if let emoji = userAvatarEmoji {
                        // 使用带主题色渐变和像素描边的圆形头像框渲染用户 Emoji
                        BubblePixelAvatarView(
                            emoji: emoji,
                            size: 36,
                            bgColors: userAvatarBgColors,
                            borderColor: userAvatarBorderColor,
                            shadowColor: userAvatarShadowColor
                        )
                    } else if let path = userAvatarPath, let image = NSImage(contentsOfFile: path) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(userAvatarBorderColor, lineWidth: 2))
                    } else {
                        BubblePixelAvatarView(
                            emoji: "👤",
                            size: 36,
                            bgColors: userAvatarBgColors,
                            borderColor: userAvatarBorderColor,
                            shadowColor: userAvatarShadowColor
                        )
                    }
                }
                .padding(.top, 4)
            }

            if !isUser {
                Spacer(minLength: 40)
            }
        }
        .onHover { isHovered = $0 }
    }

    // MARK: - 消息内容

    @ViewBuilder
    private func messageContentView(isStructured: Bool, formattedContent: String) -> some View {
        if isUser {
            VStack(alignment: .leading, spacing: 4) {
                if isStructured {
                    Markdown(formattedContent)
                        .markdownTheme(.gitHub)
                        .font(.system(size: 14))
                        .foregroundStyle(userBubbleTextColor)
                } else {
                    Text(displayedContent)
                        .font(.system(size: 14))
                        .foregroundStyle(userBubbleTextColor)
                        .lineLimit(nil)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: userBubbleColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: userBubbleShadowColor, radius: 8, x: 0, y: 4)
            )
            .frame(maxWidth: 680, alignment: .trailing)
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
                        .lineLimit(nil)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: assistantBorderColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .frame(maxWidth: 680, alignment: .leading)
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

    private func extractDisplayName(from toolName: String) -> String {
        switch toolName {
        case "web_search": return "联网搜索"
        case "file_read": return "读取文件"
        case "file_write": return "写入文件"
        case "file_list": return "列出文件"
        case "get_system_info": return "获取系统信息"
        case "get_clipboard": return "获取剪贴板"
        case "set_clipboard": return "设置剪贴板"
        case "send_notification": return "发送通知"
        case "open_macos_application": return "打开应用"
        default: return toolName
        }
    }
}

// MARK: - 像素头像视图

struct BubblePixelAvatarView: View {
    let emoji: String
    let size: CGFloat
    let bgColors: [Color]
    let borderColor: Color
    let shadowColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: bgColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: shadowColor, radius: 4, x: 0, y: 2)

            Circle()
                .stroke(borderColor, lineWidth: 2)
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
    let chatMode: ChatMode

    @State private var isExpanded = false
    @State private var isPulsing = false
    @State private var cooldownWorkItem: DispatchWorkItem? = nil

    private var accentColor: Color {
        switch chatMode {
        case .petCompanion:
            return Color(hex: "8B5CF6")
        case .aiAssistant:
            return Color(hex: "059669")
        }
    }

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
                        .foregroundStyle(accentColor)

                    if isPulsing {
                        Circle()
                            .fill(accentColor)
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
                        .foregroundStyle(accentColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.08))
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
                    .onChange(of: thinkingContent) { _, newValue in
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
                .stroke(accentColor.opacity(0.15), lineWidth: 1)
        )
        .onChange(of: thinkingContent) { _, newValue in
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
    let chatMode: ChatMode
    @State private var isExpanded = false

    private var accentColor: Color {
        switch chatMode {
        case .petCompanion:
            return Color(hex: "8B5CF6")
        case .aiAssistant:
            return Color(hex: "059669")
        }
    }

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

    private var parsedHeader: (icon: String, title: String, subtitle: String, isSuccess: Bool) {
        let parsed = extractedContent
        var title = "调用工具"
        var icon = "🔧"
        var isSuccess = true

        let lowercasedPrefix = parsed.prefix.lowercased()
        if lowercasedPrefix.contains("error") || lowercasedPrefix.contains("failed") || content.lowercased().contains("error") {
            isSuccess = false
            title = "工具异常"
            icon = "⚠️"
        } else if lowercasedPrefix.contains("web_search") || lowercasedPrefix.contains("search") {
            title = "联网搜索"
            icon = "🌐"
        } else if lowercasedPrefix.contains("file") || lowercasedPrefix.contains("parse") || lowercasedPrefix.contains("read") {
            title = "解析文件"
            icon = "📄"
        }

        var subtitle = parsed.prefix
        subtitle = subtitle.replacingOccurrences(of: "🔧", with: "")
        subtitle = subtitle.replacingOccurrences(of: "调用工具:", with: "")
        subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

        return (icon, title, subtitle, isSuccess)
    }

    private var formattedContent: String {
        let parsed = extractedContent
        if !parsed.json.isEmpty {
            if let data = parsed.json.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                return prettyString
            }
            return parsed.json
        }
        return content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(parsedHeader.isSuccess ? Color(hex: "10B981") : Color(hex: "EF4444"))
                        .frame(width: 4, height: 20)
                        .cornerRadius(2)
                    
                    Text(parsedHeader.icon)
                        .font(.system(size: 13))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(parsedHeader.title)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            
                            Text(parsedHeader.isSuccess ? "SUCCESS" : "ERROR")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(parsedHeader.isSuccess ? Color(hex: "10B981").opacity(0.15) : Color(hex: "EF4444").opacity(0.15))
                                .foregroundColor(parsedHeader.isSuccess ? Color(hex: "10B981") : Color(hex: "EF4444"))
                                .cornerRadius(3)
                        }

                        if !parsedHeader.subtitle.isEmpty {
                            Text(parsedHeader.subtitle)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(hex: "1E1E2E"))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.08))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(formattedContent)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "A6ACCD"))
                            .padding(12)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "151521"))
            }
        }
        .background(Color(hex: "1E1E2E"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .frame(maxWidth: 680, alignment: .leading)
        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
    }
}
