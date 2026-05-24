//
//  MessageContextMenu.swift
//  YumikoToys
//
//  消息上下文菜单组件
//

import SwiftUI

// MARK: - MessageActions

/// 消息操作回调集合
struct MessageActions {
    var onCopy: (() -> Void)?
    var onEditAndResend: ((String) -> Void)?
    var onRegenerate: (() -> Void)?
    var onRollback: (() -> Void)?
    var onDelete: (() -> Void)?
    
    init(
        onCopy: (() -> Void)? = nil,
        onEditAndResend: ((String) -> Void)? = nil,
        onRegenerate: (() -> Void)? = nil,
        onRollback: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.onCopy = onCopy
        self.onEditAndResend = onEditAndResend
        self.onRegenerate = onRegenerate
        self.onRollback = onRollback
        self.onDelete = onDelete
    }
}

// MARK: - MessageContextMenu

/// 消息右键菜单视图
struct MessageContextMenu: View {
    let message: ChatMessage
    let actions: MessageActions
    
    @State private var isShowingEditSheet = false
    
    /// 判断是否为用户消息
    private var isUserMessage: Bool {
        message.role == "user"
    }
    
    /// 判断是否为 AI 消息
    private var isAssistantMessage: Bool {
        message.role == "assistant"
    }
    
    var body: some View {
        Group {
            // 复制
            Button {
                actions.onCopy?()
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
            .disabled(actions.onCopy == nil)
            
            Divider()
            
            // 用户消息特有操作
            if isUserMessage {
                Group {
                    Button {
                        isShowingEditSheet = true
                    } label: {
                        Label("编辑并重新发送", systemImage: "pencil")
                    }
                    .disabled(actions.onEditAndResend == nil)
                    
                    Button {
                        actions.onRollback?()
                    } label: {
                        Label("回滚到此处", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(actions.onRollback == nil)
                }
            }
            
            // AI 消息特有操作
            if isAssistantMessage {
                Group {
                    Button {
                        actions.onRegenerate?()
                    } label: {
                        Label("重新生成", systemImage: "arrow.clockwise")
                    }
                    .disabled(actions.onRegenerate == nil)
                }
            }
            
            Divider()
            
            // 删除
            Button(role: .destructive) {
                actions.onDelete?()
            } label: {
                Label("删除", systemImage: "trash")
            }
            .disabled(actions.onDelete == nil)
        }
        .sheet(isPresented: $isShowingEditSheet) {
            MessageEditSheet(
                originalContent: message.content,
                onConfirm: { newContent in
                    actions.onEditAndResend?(newContent)
                    isShowingEditSheet = false
                },
                onCancel: {
                    isShowingEditSheet = false
                }
            )
        }
    }
}

// MARK: - MessageEditSheet

/// 消息编辑弹窗视图
struct MessageEditSheet: View {
    let originalContent: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    @State private var editedContent: String
    @Environment(\.dismiss) private var dismiss
    
    init(
        originalContent: String,
        onConfirm: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.originalContent = originalContent
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _editedContent = State(initialValue: originalContent)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("编辑消息")
                    .font(.headline)
                Spacer()
            }
            
            // 编辑区域
            TextEditor(text: $editedContent)
                .font(.body)
                .frame(minWidth: 400, minHeight: 200)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            
            // 按钮区域
            HStack(spacing: 12) {
                Spacer()
                
                Button("取消") {
                    onCancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("重新发送") {
                    let trimmedContent = editedContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedContent.isEmpty else { return }
                    onConfirm(trimmedContent)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(editedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 450, minHeight: 300)
    }
}

// MARK: - Preview

#Preview("用户消息菜单") {
    Text("右键点击查看菜单")
        .contextMenu {
            MessageContextMenu(
                message: ChatMessage(
                    role: "user",
                    content: "这是一条用户消息"
                ),
                actions: MessageActions(
                    onCopy: { print("复制") },
                    onEditAndResend: { newContent in print("编辑并发送: \(newContent)") },
                    onRollback: { print("回滚") },
                    onDelete: { print("删除") }
                )
            )
        }
}

#Preview("AI 消息菜单") {
    Text("右键点击查看菜单")
        .contextMenu {
            MessageContextMenu(
                message: ChatMessage(
                    role: "assistant",
                    content: "这是一条 AI 回复消息"
                ),
                actions: MessageActions(
                    onCopy: { print("复制") },
                    onRegenerate: { print("重新生成") },
                    onDelete: { print("删除") }
                )
            )
        }
}

#Preview("编辑弹窗") {
    MessageEditSheet(
        originalContent: "这是一条需要编辑的消息内容",
        onConfirm: { newContent in print("确认编辑: \(newContent)") },
        onCancel: { print("取消编辑") }
    )
}
