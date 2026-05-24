//
//  ConversationSidebarView.swift
//  YumikoToys
//
//  对话列表侧边栏（可爱像素风格 - 支持右键重命名与删除版）
//

import SwiftUI

struct ConversationSidebarView: View {
    @ObservedObject var conversationService: ConversationService
    let onSelectConversation: (UUID) -> Void
    let onNewConversation: () -> Void
    let onDeleteConversation: (UUID) -> Void
    let onRenameConversation: (UUID, String) -> Void // 👈 新增重命名回调接口

    @State private var hoveredConversationId: UUID?
    @State private var showDeleteConfirmation: UUID?
    
    // MARK: - 重命名交互状态 [1]
    @State private var showingRenameAlert = false
    @State private var conversationToRename: UUID?
    @State private var newConversationTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            headerView

            Divider()
                .background(Color.white.opacity(0.05))

            // 对话列表
            conversationList

            Divider()
                .background(Color.white.opacity(0.05))

            // 底部信息
            footerView
        }
        .background(Color(hex: "141418"))
        // 【核心新增】重命名对话的原生输入弹窗 [1]
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
                .foregroundStyle(.white)

            Spacer()

            Text("\(conversationService.conversations.count)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                )

            Button(action: onNewConversation) {
                Image(systemName: "plus.message")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "FF6B9D"))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color(hex: "FF6B9D").opacity(0.1))
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
                ForEach(conversationService.conversations) { conversation in
                    let isConfirming = showDeleteConfirmation == conversation.id
                    
                    ConversationRow(
                        conversation: conversation,
                        isSelected: conversation.id == conversationService.currentConversationId,
                        isHovered: hoveredConversationId == conversation.id,
                        isConfirmingDelete: isConfirming,
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
                .foregroundStyle(Color(hex: "FF6B9D").opacity(0.6))

            Text("AI 驱动 · 本地记忆")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
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
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRightClickDelete: () -> Void
    let onRename: () -> Void // 👈 新增重命名回调

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // 图标
                ZStack {
                    Circle()
                        .fill(isSelected
                            ? AnyShapeStyle(Color(hex: "FF6B9D").opacity(0.15))
                            : AnyShapeStyle(Color.clear))
                        .frame(width: 32, height: 32)

                    Text(conversation.isPinned ? "📌" : "💬")
                        .font(.system(size: 14))
                }

                // 标题和预览
                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.title)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(conversation.formattedUpdateTime)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)

                        if conversation.messageCount > 0 {
                            Text("· \(conversation.messageCount)条")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
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
                    .fill(isSelected
                        ? AnyShapeStyle(Color(hex: "FF6B9D").opacity(0.08))
                        : isHovered
                            ? AnyShapeStyle(Color.white.opacity(0.03))
                            : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            // 【核心新增】右键菜单中增加重命名按钮 [1]
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
