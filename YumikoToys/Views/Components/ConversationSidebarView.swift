//
//  ConversationSidebarView.swift
//  YumikoToys
//
//  对话列表侧边栏（可爱像素风格 - 支持右键重命名与删除版 - 深度主题化适配）
//

import SwiftUI

struct ConversationSidebarView: View {
    @ObservedObject var conversationService: ConversationService
    let chatMode: ChatMode
    let themeColor: ResolvedTheme
    let onSelectConversation: (UUID) -> Void
    let onNewConversation: () -> Void
    let onDeleteConversation: (UUID) -> Void
    let onRenameConversation: (UUID, String) -> Void

    @State private var hoveredConversationId: UUID?
    @State private var showDeleteConfirmation: UUID?
    
    // MARK: - 重命名交互状态
    @State private var showingRenameAlert = false
    @State private var conversationToRename: UUID?
    @State private var newConversationTitle = ""

    private var filteredConversations: [Conversation] {
        conversationService.conversations.filter { ($0.chatMode ?? .petCompanion) == chatMode }
    }

    // MARK: - 主题颜色计算属性
    
    private var sidebarBackgroundColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.backgroundColor
        case .aiAssistant:
            return Color(hex: "0A0F0D")
        }
    }
    
    private var dividerColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.dividerColor
        case .aiAssistant:
            return Color(hex: "059669").opacity(0.15)
        }
    }
    
    private var headerTextColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.textColor
        case .aiAssistant:
            return Color(hex: "E6F4EA")
        }
    }
    
    private var badgeTextColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.secondaryTextColor
        case .aiAssistant:
            return Color(hex: "81C784").opacity(0.8)
        }
    }
    
    private var badgeBackgroundColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.textColor.opacity(0.06)
        case .aiAssistant:
            return Color.white.opacity(0.05)
        }
    }
    
    private var newBtnColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.accentColor
        case .aiAssistant:
            return Color(hex: "059669")
        }
    }
    
    private var footerIconColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.accentColor.opacity(0.6)
        case .aiAssistant:
            return Color(hex: "059669").opacity(0.6)
        }
    }
    
    private var footerTextColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.secondaryTextColor
        case .aiAssistant:
            return Color.gray.opacity(0.8)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            headerView

            Divider()
                .background(dividerColor)

            // 对话列表
            conversationList

            Divider()
                .background(dividerColor)

            // 底部信息
            footerView
        }
        .background(sidebarBackgroundColor)
        // 重命名对话的原生输入弹窗
        .alert("重命名对话", isPresented: $showingRenameAlert) {
            TextField("对话新标题", text: $newConversationTitle)
            
            Button("取消", role: .cancel) {
                conversationToRename = nil
                newConversationTitle = ""
            }
            
            Button("确定") {
                if let id = conversationToRename {
                    let trimmed = newConversationTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onRenameConversation(id, trimmed)
                    }
                }
                conversationToRename = nil
                newConversationTitle = ""
            }
        } message: {
            Text("请为此对话输入一个新的标题。")
        }
    }

    // MARK: - 头部

    private var headerView: some View {
        HStack(spacing: 8) {
            Text("💬 对话")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(headerTextColor)

            Spacer()

            Text("\(filteredConversations.count)")
                .font(.system(size: 11))
                .foregroundStyle(badgeTextColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(badgeBackgroundColor)
                )

            Button(action: onNewConversation) {
                Image(systemName: "plus.message")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(newBtnColor)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(newBtnColor.opacity(0.1))
                    )
            }
            .buttonStyle(.plain)
            .help("新建对话")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - 对话列表

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredConversations) { conversation in
                    let isConfirming = showDeleteConfirmation == conversation.id
                    
                    ConversationRow(
                        conversation: conversation,
                        isSelected: conversation.id == conversationService.currentConversationId,
                        isHovered: hoveredConversationId == conversation.id,
                        isConfirmingDelete: isConfirming,
                        themeColor: themeColor,
                        chatMode: chatMode,
                        onTap: { onSelectConversation(conversation.id) },
                        onDelete: {
                            if showDeleteConfirmation == conversation.id {
                                onDeleteConversation(conversation.id)
                                showDeleteConfirmation = nil
                            } else {
                                showDeleteConfirmation = conversation.id
                                // 2秒后自动取消确认状态
                                Task {
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    await MainActor.run {
                                        if showDeleteConfirmation == conversation.id {
                                            showDeleteConfirmation = nil
                                        }
                                    }
                                }
                            }
                        },
                        onRightClickDelete: {
                            onDeleteConversation(conversation.id)
                        },
                        onRename: { // 👈 激活重命名弹窗
                            conversationToRename = conversation.id
                            newConversationTitle = conversation.title
                            showingRenameAlert = true
                        }
                    )
                    .onHover { isHovered in
                        hoveredConversationId = isHovered ? conversation.id : nil
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 底部

    private var footerView: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 9))
                .foregroundStyle(footerIconColor)

            Text("AI 驱动 · 本地记忆")
                .font(.system(size: 10))
                .foregroundStyle(footerTextColor)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 对话行

private struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let isHovered: Bool
    let isConfirmingDelete: Bool
    let themeColor: ResolvedTheme
    let chatMode: ChatMode
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRightClickDelete: () -> Void
    let onRename: () -> Void

    private var titleColor: Color {
        if isSelected {
            switch chatMode {
            case .petCompanion:
                return themeColor.textColor
            case .aiAssistant:
                return .white
            }
        } else {
            switch chatMode {
            case .petCompanion:
                return themeColor.secondaryTextColor
            case .aiAssistant:
                return .gray
            }
        }
    }
    
    private var metaColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.secondaryTextColor.opacity(0.8)
        case .aiAssistant:
            return .gray.opacity(0.8)
        }
    }
    
    private var selectedCircleColor: Color {
        switch chatMode {
        case .petCompanion:
            return themeColor.accentColor.opacity(0.15)
        case .aiAssistant:
            return Color(hex: "059669").opacity(0.15)
        }
    }
    
    private var rowBgColor: Color {
        if isSelected {
            switch chatMode {
            case .petCompanion:
                return themeColor.accentColor.opacity(0.08)
            case .aiAssistant:
                return Color(hex: "059669").opacity(0.08)
            }
        } else if isHovered {
            switch chatMode {
            case .petCompanion:
                return themeColor.textColor.opacity(0.04)
            case .aiAssistant:
                return Color.white.opacity(0.03)
            }
        } else {
            return .clear
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // 图标
                ZStack {
                    Circle()
                        .fill(isSelected
                            ? AnyShapeStyle(selectedCircleColor)
                            : AnyShapeStyle(Color.clear))
                        .frame(width: 32, height: 32)

                    Text(conversation.isPinned ? "📌" : "💬")
                        .font(.system(size: 14))
                }

                // 标题和预览
                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.title)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(conversation.formattedUpdateTime)
                            .font(.system(size: 10))
                            .foregroundStyle(metaColor)

                        if conversation.messageCount > 0 {
                            Text("· \(conversation.messageCount)条")
                                .font(.system(size: 10))
                                .foregroundStyle(metaColor)
                        }
                    }
                }

                Spacer()

                // 删除按钮
                if (isHovered || isConfirmingDelete) && !isSelected {
                    Button(action: onDelete) {
                        Image(systemName: isConfirmingDelete ? "trash.fill" : "minus.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(isConfirmingDelete ? Color.red : Color.red.opacity(0.6))
                            .scaleEffect(isConfirmingDelete ? 1.15 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isConfirmingDelete)
                    }
                    .buttonStyle(.plain)
                    .help(isConfirmingDelete ? "再次点击确认删除" : "移除对话")
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AnyShapeStyle(rowBgColor))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            // 右键菜单中增加重命名按钮
            Button(action: onRename) {
                Label("重命名", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive, action: onRightClickDelete) {
                Label("删除对话", systemImage: "trash")
            }
        }
    }
}
