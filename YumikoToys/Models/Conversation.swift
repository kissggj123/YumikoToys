//
//  Conversation.swift
//  YumikoToys
//
//  对话会话模型 - 支持多对话多任务
//

import Foundation

/// 搜索来源
struct SearchSource: Codable, Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let title: String
    let url: String
    let snippet: String

    init(id: String = UUID().uuidString, title: String, url: String, snippet: String) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
    }
}

/// 对话会话
struct Conversation: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messageCount: Int
    var petAnniversaryId: String?  // 关联的宠物纪念日ID
    var isPinned: Bool  // 是否置顶
    var chatMode: ChatMode?  // 对话所属模式

    var mode: ChatMode {
        get { chatMode ?? .petCompanion }
        set { chatMode = newValue }
    }

    init(
        id: UUID = UUID(),
        title: String = "新对话",
        petAnniversaryId: String? = nil,
        isPinned: Bool = false,
        chatMode: ChatMode = .petCompanion
    ) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messageCount = 0
        self.petAnniversaryId = petAnniversaryId
        self.isPinned = isPinned
        self.chatMode = chatMode
    }

    /// 生成显示标题（基于最新消息）
    mutating func updateTitle(from lastMessage: String) {
        let cleaned = lastMessage
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > 20 {
            title = String(cleaned.prefix(20)) + "..."
        } else if !cleaned.isEmpty {
            title = cleaned
        }
        updatedAt = Date()
    }

    /// 格式化的更新时间
    var formattedUpdateTime: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(updatedAt) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(updatedAt) {
            return "昨天"
        } else {
            formatter.dateFormat = "MM/dd"
        }
        return formatter.string(from: updatedAt)
    }
}

/// 对话管理服务
@MainActor
final class ConversationService: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversationId: UUID?

    private let dataStorageService: DataStorageService
    private let saveKey = "conversations/conversations.json"

    init(dataStorageService: DataStorageService) {
        self.dataStorageService = dataStorageService
    }

    /// 加载所有对话
    func loadConversations() async {
        if let saved: [Conversation] = await dataStorageService.load([Conversation].self, from: saveKey) {
            conversations = saved.sorted { $0.isPinned && !$1.isPinned || $0.updatedAt > $1.updatedAt }
        }
        // 如果没有对话，创建默认对话
        if conversations.isEmpty {
            let defaultConversation = Conversation(title: "可可的对话", chatMode: .petCompanion)
            conversations.append(defaultConversation)
            currentConversationId = defaultConversation.id
            await saveConversations()
        } else if currentConversationId == nil {
            currentConversationId = conversations.first?.id
        }
    }

    /// 创建新对话
    @discardableResult
    func createConversation(title: String = "新对话", petAnniversaryId: String? = nil, chatMode: ChatMode = .petCompanion) -> Conversation {
        let conversation = Conversation(title: title, petAnniversaryId: petAnniversaryId, chatMode: chatMode)
        conversations.insert(conversation, at: 0)
        currentConversationId = conversation.id
        Task { await saveConversations() }
        return conversation
    }

    /// 删除对话
    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        if currentConversationId == id {
            currentConversationId = conversations.first?.id
        }
        Task { await saveConversations() }
    }

    /// 切换当前对话
    func switchToConversation(_ id: UUID) {
        currentConversationId = id
    }

    /// 更新对话标题
    func updateTitle(for id: UUID, title: String) {
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations[index].title = title
            conversations[index].updatedAt = Date()
            Task { await saveConversations() }
        }
    }

    /// 更新对话消息数
    func updateMessageCount(for id: UUID, count: Int) {
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations[index].messageCount = count
            conversations[index].updatedAt = Date()
        }
    }

    /// 获取当前对话
    var currentConversation: Conversation? {
        conversations.first { $0.id == currentConversationId }
    }

    /// 保存对话列表
    func saveConversations() async {
        await dataStorageService.save(conversations, to: saveKey)
    }
}
