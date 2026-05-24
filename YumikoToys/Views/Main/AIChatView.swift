//
//  AIChatView.swift
//  YumikoToys
//
//  AI 对话界面（v5.2.1 - 纯净主界面：自适应视窗高度解耦、用户像素头像多轨同步版）
//

import SwiftUI

struct AIChatView: View {
    @StateObject private var viewModel = AIChatViewModel()
    @StateObject private var conversationService: ConversationService
    
    @State private var showSettings = false
    @State private var sidebarVisible = true
    @FocusState private var isInputFocused: Bool
    @State private var isUserScrolling = false
    @State private var lastUserScrollTime = Date()

    private let userScrollTimeout: TimeInterval = 3.0

    init() {
        let container = DependencyContainer.shared
        _conversationService = StateObject(wrappedValue: ConversationService(
            dataStorageService: container.dataStorageService
        ))
    }

    var body: some View {
        NavigationSplitView {
            ConversationSidebarView(
                conversationService: conversationService,
                onSelectConversation: { id in
                    conversationService.switchToConversation(id)
                    viewModel.switchConversation(to: id)
                },
                onNewConversation: {
                    let newConv = conversationService.createConversation(title: "新对话")
                    viewModel.startNewConversation(id: newConv.id)
                },
                onDeleteConversation: { id in
                    conversationService.deleteConversation(id)
                    viewModel.deleteConversation(id)
                },
                onRenameConversation: { id, newTitle in
                    conversationService.updateTitle(for: id, title: newTitle)
                }
            )
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)
        } detail: {
            chatDetailView
        }
        .navigationSplitViewStyle(.prominentDetail)
        .frame(minWidth: 580, minHeight: 500)
        .background(Color(hex: "0F0F12"))
        .sheet(isPresented: $showSettings, onDismiss: {
            viewModel.loadAPIConfiguration()
        }) {
            ChatSettingsView()
        }
        .sheet(isPresented: $viewModel.showTemplatePicker) {
            PromptTemplatePicker(
                selectedTemplate: $viewModel.selectedTemplate
            )
        }
        .modelSwitchNotification(manager: viewModel.modelCompatibilityManager)
        .onAppear {
            Task {
                await conversationService.loadConversations()
                if let currentId = conversationService.currentConversationId {
                    viewModel.switchConversation(to: currentId)
                }
            }
        }
    }

    // MARK: - 聊天详情

    private var chatDetailView: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            // 聊天区域
            chatArea

            // 输入区域
            inputArea
        }
        .background(Color(hex: "0F0F12"))
    }

    // MARK: - 标题栏

    private var headerView: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack(spacing: 12) {
                // AI 像素头像
                PixelAvatarView(
                    emoji: viewModel.chatMode == .aiAssistant ? "🤖" : viewModel.aiAvatarEmoji,
                    size: 36
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.chatMode == .aiAssistant ? "全能助手" : viewModel.characterName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.chatMode == .aiAssistant ? Color(hex: "06B6D4") : Color.green)
                            .frame(width: 6, height: 6)

                        Text("在线")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 用户头像预览
                userAvatarPreview

                // 设置按钮
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .help("设置")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "1A1A1E"))

            // 模式切换和提供商选择
            HStack(spacing: 12) {
                ChatModeSelector(
                    selectedMode: $viewModel.chatMode,
                    onModeChange: { mode in
                        viewModel.switchChatMode(to: mode)
                    }
                )

                Spacer()

                ProviderPicker(
                    selectedProvider: $viewModel.currentProvider,
                    onProviderChange: { provider in
                        viewModel.switchProvider(to: provider)
                    }
                )

                ModelPickerMenu(
                    selectedModel: $viewModel.currentModel,
                    availableModels: viewModel.availableModels,
                    onModelChange: { model in
                        viewModel.selectModel(model)
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "1A1A1E"))
        }
    }

    private var userAvatarPreview: some View {
        Group {
            if let emoji = viewModel.userAvatarEmoji {
                PixelAvatarView(emoji: emoji, size: 28)
            } else if let path = viewModel.userAvatarPath {
                Image(nsImage: NSImage(contentsOfFile: path) ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }

    // MARK: - 聊天区域

    private var chatArea: some View {
        Group {
            if viewModel.messages.isEmpty && !viewModel.isGeneratingPersona {
                // 将空状态视图直接剥离出 ScrollView 外部，释放高度弹性
                emptyStateView
            } else if viewModel.isGeneratingPersona {
                personaGeneratingView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // 新人设确认卡片
                            if viewModel.hasPendingPersona, let persona = viewModel.pendingPersona {
                                PersonaConfirmationCard(persona: persona) {
                                    viewModel.confirmPendingPersona()
                                } onReject: {
                                    viewModel.rejectPendingPersona()
                                }
                            }

                            ForEach(viewModel.messages) { message in
                                messageBubble(for: message)
                            }
                            
                            if viewModel.isLoading {
                                TypingIndicator(aiAvatarEmoji: viewModel.aiAvatarEmoji)
                                    .id("typing")
                            }
                        }
                        .padding(16)
                    }
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(key: ScrollOffsetKey.self, value: geometry.frame(in: .named("chatScroll")).origin.y)
                        }
                    )
                    .coordinateSpace(name: "chatScroll")
                    .onPreferenceChange(ScrollOffsetKey.self) { offset in
                        let now = Date()
                        if abs(offset) > 10 {
                            isUserScrolling = true
                            lastUserScrollTime = now
                        }
                        if isUserScrolling && now.timeIntervalSince(lastUserScrollTime) > userScrollTimeout {
                            isUserScrolling = false
                        }
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if !isUserScrolling { scrollToBottom(proxy: proxy) }
                    }
                    .onChange(of: viewModel.isLoading) { _ in
                        if !isUserScrolling { scrollToBottom(proxy: proxy) }
                    }
                    .onChange(of: viewModel.initialHistoryLoaded) { _ in
                        Task {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onChange(of: viewModel.messages.last?.content.count ?? 0) { _ in
                        if viewModel.isLoading && !isUserScrolling {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 消息气泡

    private func messageBubble(for message: ChatMessage) -> some View {
        CopyableMessageBubble(
            message: message,
            aiAvatarEmoji: viewModel.aiAvatarEmoji,
            userAvatarEmoji: viewModel.userAvatarEmoji,
            userAvatarPath: viewModel.userAvatarPath
        )
        .id(message.id)
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.content, forType: .string)
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }

            Divider()

            if message.role == "user" {
                Button {
                    viewModel.editAndResend(messageId: message.id, newContent: message.content)
                } label: {
                    Label("编辑并重新发送", systemImage: "pencil")
                }

                Button {
                    viewModel.rollbackTo(messageId: message.id)
                } label: {
                    Label("回滚到此处", systemImage: "arrow.uturn.backward")
                }
            }

            if message.role == "assistant" {
                Button {
                    viewModel.regenerateResponse(for: message.id)
                } label: {
                    Label("重新生成", systemImage: "arrow.clockwise")
                }
            }

            Divider()

            Button(role: .destructive) {
                viewModel.deleteMessage(messageId: message.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [themeColor.opacity(0.15), themeColor.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                PixelAvatarView(emoji: viewModel.aiAvatarEmoji, size: 60)
            }

            VStack(spacing: 8) {
                Text("开始对话")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text(viewModel.greeting)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                QuickPromptButton(text: "介绍一下自己") {
                    viewModel.inputText = "介绍一下自己"
                    sendMessage()
                }
                QuickPromptButton(text: "今天心情如何") {
                    viewModel.inputText = "今天心情如何"
                    sendMessage()
                }
            }

            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    private var personaGeneratingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("正在生成人设...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - 输入区域

    private var inputArea: some View {
        VStack(spacing: 0) {
            // 助手模式工具栏
            if viewModel.chatMode == .aiAssistant {
                AssistantToolbar(
                    enableDeepThinking: $viewModel.enableDeepThinking,
                    enableWebSearch: $viewModel.enableWebSearch,
                    enableAgentMode: $viewModel.enableAgentMode
                )

                // 已上传文件预览
                if !viewModel.uploadedFiles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(viewModel.uploadedFiles) { file in
                                FilePreviewChip(file: file) {
                                    viewModel.removeFile(file)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack(spacing: 12) {
                // 文件上传按钮（助手模式）- 仅小型回形针按钮，不再渲染占位拖拽区
                if viewModel.chatMode == .aiAssistant {
                    CompactFileUploadButton(onFilesAdded: { urls in
                        viewModel.addFiles(urls: urls)
                    })
                }

                TextField("输入消息...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendMessage()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.05))
                    )

                if !viewModel.messages.isEmpty && !viewModel.isGenerating && !viewModel.isLoading {
                    Button(action: { viewModel.rollbackLastTurn() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("撤销发送/回退上一次对话")
                }

                if viewModel.isGenerating || viewModel.isLoading {
                    // 中止按钮 (Stop State)
                    Button(action: { viewModel.stopStreaming() }) {
                        Image(systemName: "square.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.8))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("中止流式输出")
                } else {
                    // 发送按钮 (Send State)
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(viewModel.inputText.isEmpty
                                        ? AnyShapeStyle(Color.gray.opacity(0.3))
                                        : AnyShapeStyle(themeGradient)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.inputText.isEmpty || viewModel.isGeneratingPersona)
                }
            }
            .padding(16)
            .background(Color(hex: "1A1A1E"))
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        guard !viewModel.inputText.isEmpty else { return }
        let message = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        viewModel.sendMessage(message)

        if let convId = conversationService.currentConversationId {
            conversationService.updateMessageCount(for: convId, count: viewModel.messages.count)
            conversationService.updateTitle(for: convId, title: message)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if viewModel.isLoading {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let lastMessage = viewModel.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    // MARK: - 主题配色

    private var themeGradient: LinearGradient {
        switch viewModel.chatMode {
        case .petCompanion:
            return LinearGradient(
                colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .aiAssistant:
            return LinearGradient(
                colors: [Color(hex: "3B82F6"), Color(hex: "06B6D4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var themeColor: Color {
        switch viewModel.chatMode {
        case .petCompanion:
            return Color(hex: "FF6B9D")
        case .aiAssistant:
            return Color(hex: "3B82F6")
        }
    }
}

// MARK: - 滚动偏移量检测

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 打字指示器

private struct TypingIndicator: View {
    var aiAvatarEmoji: String = "🐰"
    @State private var offset: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            PixelAvatarView(emoji: aiAvatarEmoji, size: 28)

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .offset(y: offset)
                        .animation(
                            .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.12),
                            value: offset
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "1A1A1E"))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            offset = -4
        }
    }
}

// MARK: - 快捷提示按钮

private struct QuickPromptButton: View {
    let text: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isHovered
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            : AnyShapeStyle(Color.white.opacity(0.05))
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - 新人设确认卡片

private struct PersonaConfirmationCard: View {
    let persona: PetPersona
    let onConfirm: () -> Void
    let onReject: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 12) {
            PixelAvatarView(emoji: persona.avatar, size: 48)

            Text("✨ 新人设已生成")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text("\(persona.characterName)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "FF6B9D"))

            if !persona.personality.isEmpty {
                Text(persona.personality.prefix(60))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            if !persona.speakingStyle.isEmpty {
                Text("说话风格：\(persona.speakingStyle.prefix(40))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                Button("保持旧人设", action: onReject)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.secondary)
                Button("采用新人设", action: onConfirm)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color(hex: "FF6B9D"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "1A1A1E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "FF6B9D").opacity(isHovered ? 0.6 : 0.3), Color(hex: "C44FE2").opacity(isHovered ? 0.4 : 0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
