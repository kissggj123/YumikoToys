//
//  SearchChannel.swift
//  YumikoToys
//
//  搜索频道模型 - 支持多频道搜索（通用、学术、代码、社交）
//

import Foundation
import SwiftUI

// MARK: - 搜索频道类型

/// 搜索频道类型枚举
enum SearchChannelType: String, Codable, CaseIterable, Identifiable, Sendable {
    case general = "general"
    case academic = "academic"
    case code = "code"
    case social = "social"

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .general:
            return "通用搜索"
        case .academic:
            return "学术搜索"
        case .code:
            return "代码搜索"
        case .social:
            return "社交搜索"
        }
    }

    /// 图标（SF Symbols）
    var icon: String {
        switch self {
        case .general:
            return "globe"
        case .academic:
            return "graduationcap"
        case .code:
            return "curlybraces"
        case .social:
            return "bubble.left.and.bubble.right"
        }
    }

    /// 表情图标
    var emojiIcon: String {
        switch self {
        case .general:
            return "🌐"
        case .academic:
            return "🎓"
        case .code:
            return "💻"
        case .social:
            return "💬"
        }
    }

    /// 描述
    var description: String {
        switch self {
        case .general:
            return "综合全网信息，获取最广泛的搜索结果"
        case .academic:
            return "搜索学术论文、期刊和研究资料"
        case .code:
            return "搜索代码仓库、技术文档和开发者资源"
        case .social:
            return "搜索社交媒体、论坛和社区讨论"
        }
    }

    /// 提示文本
    var placeholder: String {
        switch self {
        case .general:
            return "输入关键词搜索..."
        case .academic:
            return "输入论文标题、作者或关键词..."
        case .code:
            return "输入代码片段、函数名或技术问题..."
        case .social:
            return "输入话题、用户名或讨论内容..."
        }
    }

    /// 主题色
    var themeColor: Color {
        switch self {
        case .general:
            return Color(hex: "3B82F6") // 蓝色
        case .academic:
            return Color(hex: "8B5CF6") // 紫色
        case .code:
            return Color(hex: "10B981") // 绿色
        case .social:
            return Color(hex: "F59E0B") // 橙色
        }
    }
}

// MARK: - 学术来源

/// 学术来源枚举
enum AcademicSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case googleScholar = "google_scholar"
    case arXiv = "arxiv"
    case pubMed = "pubmed"
    case ieee = "ieee"
    case acm = "acm"
    case semanticScholar = "semantic_scholar"
    case dblp = "dblp"
    case crossRef = "crossref"

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .googleScholar:
            return "Google Scholar"
        case .arXiv:
            return "arXiv"
        case .pubMed:
            return "PubMed"
        case .ieee:
            return "IEEE Xplore"
        case .acm:
            return "ACM Digital Library"
        case .semanticScholar:
            return "Semantic Scholar"
        case .dblp:
            return "DBLP"
        case .crossRef:
            return "CrossRef"
        }
    }

    /// 图标
    var icon: String {
        switch self {
        case .googleScholar:
            return "magnifyingglass.circle"
        case .arXiv:
            return "doc.text.magnifyingglass"
        case .pubMed:
            return "cross.case"
        case .ieee:
            return "cpu"
        case .acm:
            return "book.closed"
        case .semanticScholar:
            return "brain.head.profile"
        case .dblp:
            return "list.bullet.rectangle"
        case .crossRef:
            return "link"
        }
    }

    /// 描述
    var description: String {
        switch self {
        case .googleScholar:
            return "Google 学术搜索，涵盖广泛的学术文献"
        case .arXiv:
            return "预印本论文库，主要涵盖物理、数学、计算机科学"
        case .pubMed:
            return "生物医学文献数据库"
        case .ieee:
            return "电气电子工程师协会数字图书馆"
        case .acm:
            return "计算机协会数字图书馆"
        case .semanticScholar:
            return "AI 驱动的学术搜索引擎"
        case .dblp:
            return "计算机科学文献书目"
        case .crossRef:
            return "学术出版物的 DOI 注册机构"
        }
    }

    /// 基础 URL
    var baseURL: String {
        switch self {
        case .googleScholar:
            return "https://scholar.google.com"
        case .arXiv:
            return "https://arxiv.org"
        case .pubMed:
            return "https://pubmed.ncbi.nlm.nih.gov"
        case .ieee:
            return "https://ieeexplore.ieee.org"
        case .acm:
            return "https://dl.acm.org"
        case .semanticScholar:
            return "https://www.semanticscholar.org"
        case .dblp:
            return "https://dblp.org"
        case .crossRef:
            return "https://www.crossref.org"
        }
    }
}

// MARK: - 社交平台

/// 社交平台枚举
enum SocialPlatform: String, Codable, CaseIterable, Identifiable, Sendable {
    case reddit = "reddit"
    case twitter = "twitter"
    case zhihu = "zhihu"
    case stackOverflow = "stackoverflow"
    case githubDiscussions = "github_discussions"
    case devTo = "dev_to"
    case medium = "medium"
    case hackernews = "hackernews"

    var id: String { rawValue }

    /// 显示名称
    var displayName: String {
        switch self {
        case .reddit:
            return "Reddit"
        case .twitter:
            return "X (Twitter)"
        case .zhihu:
            return "知乎"
        case .stackOverflow:
            return "Stack Overflow"
        case .githubDiscussions:
            return "GitHub Discussions"
        case .devTo:
            return "Dev.to"
        case .medium:
            return "Medium"
        case .hackernews:
            return "Hacker News"
        }
    }

    /// 图标
    var icon: String {
        switch self {
        case .reddit:
            return "bubble.left.and.bubble.right"
        case .twitter:
            return "bird"
        case .zhihu:
            return "text.book.closed"
        case .stackOverflow:
            return "arrowtriangle.up.fill"
        case .githubDiscussions:
            return "message"
        case .devTo:
            return "laptopcomputer"
        case .medium:
            return "text.alignleft"
        case .hackernews:
            return "y.circle"
        }
    }

    /// 描述
    var description: String {
        switch self {
        case .reddit:
            return "全球最大的社区讨论平台"
        case .twitter:
            return "实时新闻和观点分享平台"
        case .zhihu:
            return "中文问答社区"
        case .stackOverflow:
            return "程序员问答社区"
        case .githubDiscussions:
            return "GitHub 项目讨论区"
        case .devTo:
            return "开发者社区和博客平台"
        case .medium:
            return "长文阅读和写作平台"
        case .hackernews:
            return "科技新闻和讨论社区"
        }
    }

    /// 基础 URL
    var baseURL: String {
        switch self {
        case .reddit:
            return "https://www.reddit.com"
        case .twitter:
            return "https://twitter.com"
        case .zhihu:
            return "https://www.zhihu.com"
        case .stackOverflow:
            return "https://stackoverflow.com"
        case .githubDiscussions:
            return "https://github.com"
        case .devTo:
            return "https://dev.to"
        case .medium:
            return "https://medium.com"
        case .hackernews:
            return "https://news.ycombinator.com"
        }
    }
}

// MARK: - 搜索频道

/// 搜索频道配置
struct SearchChannel: Codable, Identifiable, Equatable, Sendable, Hashable {
    let id: UUID
    var type: SearchChannelType
    var name: String
    var isEnabled: Bool
    var priority: Int
    var maxResults: Int
    var academicSources: [AcademicSource]?
    var socialPlatforms: [SocialPlatform]?
    var customQueryParams: [String: String]?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        type: SearchChannelType,
        name: String? = nil,
        isEnabled: Bool = true,
        priority: Int = 0,
        maxResults: Int = 5,
        academicSources: [AcademicSource]? = nil,
        socialPlatforms: [SocialPlatform]? = nil,
        customQueryParams: [String: String]? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name ?? type.displayName
        self.isEnabled = isEnabled
        self.priority = priority
        self.maxResults = maxResults
        self.academicSources = academicSources
        self.socialPlatforms = socialPlatforms
        self.customQueryParams = customQueryParams
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 更新修改时间
    mutating func touch() {
        self.updatedAt = Date()
    }

    /// 图标
    var icon: String {
        type.icon
    }

    /// 表情图标
    var emojiIcon: String {
        type.emojiIcon
    }

    /// 描述
    var description: String {
        type.description
    }

    /// 主题色
    var themeColor: Color {
        type.themeColor
    }

    /// 是否为学术频道
    var isAcademic: Bool {
        type == .academic
    }

    /// 是否为代码频道
    var isCode: Bool {
        type == .code
    }

    /// 是否为社交频道
    var isSocial: Bool {
        type == .social
    }

    /// 是否为通用频道
    var isGeneral: Bool {
        type == .general
    }
}

// MARK: - 增强搜索结果

/// 增强搜索结果 - 支持多频道聚合
struct EnhancedSearchResult: Codable, Identifiable, Sendable, Equatable, Hashable {
    let id: String
    let title: String
    let url: String
    let snippet: String
    let channelType: SearchChannelType
    let source: String
    let sourceIcon: String?
    let publishedDate: Date?
    let author: String?
    let relevanceScore: Double?
    let metadata: SearchResultMetadata?
    let fetchedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        url: String,
        snippet: String,
        channelType: SearchChannelType,
        source: String,
        sourceIcon: String? = nil,
        publishedDate: Date? = nil,
        author: String? = nil,
        relevanceScore: Double? = nil,
        metadata: SearchResultMetadata? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
        self.channelType = channelType
        self.source = source
        self.sourceIcon = sourceIcon
        self.publishedDate = publishedDate
        self.author = author
        self.relevanceScore = relevanceScore
        self.metadata = metadata
        self.fetchedAt = Date()
    }

    /// 转换为基础 SearchSource
    func toSearchSource() -> SearchSource {
        SearchSource(
            id: id,
            title: title,
            url: url,
            snippet: snippet
        )
    }

    /// 格式化发布日期
    var formattedDate: String? {
        guard let date = publishedDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// 显示的来源信息
    var displaySource: String {
        if let author = author, !author.isEmpty {
            return "\(source) · \(author)"
        }
        return source
    }
}

// MARK: - 搜索结果元数据

/// 搜索结果扩展元数据
struct SearchResultMetadata: Codable, Sendable, Equatable, Hashable {
    var citationCount: Int?
    var downloadCount: Int?
    var upvoteCount: Int?
    var commentCount: Int?
    var tags: [String]?
    var language: String?
    var fileType: String?
    var fileSize: Int?
    var doi: String?
    var isOpenAccess: Bool?
    var license: String?

    init(
        citationCount: Int? = nil,
        downloadCount: Int? = nil,
        upvoteCount: Int? = nil,
        commentCount: Int? = nil,
        tags: [String]? = nil,
        language: String? = nil,
        fileType: String? = nil,
        fileSize: Int? = nil,
        doi: String? = nil,
        isOpenAccess: Bool? = nil,
        license: String? = nil
    ) {
        self.citationCount = citationCount
        self.downloadCount = downloadCount
        self.upvoteCount = upvoteCount
        self.commentCount = commentCount
        self.tags = tags
        self.language = language
        self.fileType = fileType
        self.fileSize = fileSize
        self.doi = doi
        self.isOpenAccess = isOpenAccess
        self.license = license
    }

    /// 是否有学术指标
    var hasAcademicMetrics: Bool {
        citationCount != nil || doi != nil || isOpenAccess != nil
    }

    /// 是否有社交指标
    var hasSocialMetrics: Bool {
        upvoteCount != nil || commentCount != nil
    }

    /// 是否有文件信息
    var hasFileInfo: Bool {
        fileType != nil || fileSize != nil
    }
}

// MARK: - 搜索频道管理

/// 搜索频道管理服务
@MainActor
final class SearchChannelService: ObservableObject {
    @Published var channels: [SearchChannel] = []
    @Published var activeChannel: SearchChannel?

    private let storageKey = "search_channels"

    /// 默认频道配置
    static let defaultChannels: [SearchChannel] = [
        SearchChannel(type: .general, priority: 0, maxResults: 5),
        SearchChannel(
            type: .academic,
            priority: 1,
            maxResults: 5,
            academicSources: [.googleScholar, .arXiv, .semanticScholar]
        ),
        SearchChannel(type: .code, priority: 2, maxResults: 5),
        SearchChannel(
            type: .social,
            priority: 3,
            maxResults: 5,
            socialPlatforms: [.reddit, .stackOverflow, .zhihu]
        )
    ]

    init() {
        loadChannels()
    }

    /// 加载频道配置
    func loadChannels() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([SearchChannel].self, from: data) {
            channels = saved.sorted { $0.priority < $1.priority }
        } else {
            channels = Self.defaultChannels
            saveChannels()
        }
        activeChannel = channels.first { $0.isEnabled }
    }

    /// 保存频道配置
    func saveChannels() {
        if let data = try? JSONEncoder().encode(channels) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// 添加频道
    func addChannel(_ channel: SearchChannel) {
        channels.append(channel)
        channels.sort { $0.priority < $1.priority }
        saveChannels()
    }

    /// 更新频道
    func updateChannel(_ channel: SearchChannel) {
        if let index = channels.firstIndex(where: { $0.id == channel.id }) {
            var updated = channel
            updated.touch()
            channels[index] = updated
            saveChannels()
        }
    }

    /// 删除频道
    func deleteChannel(_ id: UUID) {
        channels.removeAll { $0.id == id }
        saveChannels()
    }

    /// 切换频道启用状态
    func toggleChannel(_ id: UUID) {
        if let index = channels.firstIndex(where: { $0.id == id }) {
            channels[index].isEnabled.toggle()
            channels[index].touch()
            saveChannels()
        }
    }

    /// 设置活动频道
    func setActiveChannel(_ id: UUID?) {
        if let id = id,
           let channel = channels.first(where: { $0.id == id && $0.isEnabled }) {
            activeChannel = channel
        } else {
            activeChannel = channels.first { $0.isEnabled }
        }
    }

    /// 获取启用的频道
    var enabledChannels: [SearchChannel] {
        channels.filter { $0.isEnabled }.sorted { $0.priority < $1.priority }
    }

    /// 按类型获取频道
    func channel(for type: SearchChannelType) -> SearchChannel? {
        channels.first { $0.type == type }
    }

    /// 重置为默认配置
    func resetToDefaults() {
        channels = Self.defaultChannels
        saveChannels()
        activeChannel = channels.first
    }
}

// MARK: - 辅助扩展
// Color(hex:) 扩展定义在 ModeButton.swift 中，避免重复定义
