//
//  EnhancedSearchSourcesView.swift
//  YumikoToys
//
//  增强版搜索来源展示视图 - 支持按频道分组和筛选
//

import SwiftUI

// MARK: - 增强搜索来源视图

/// 增强版搜索来源展示视图 - 支持按频道分组和筛选
struct EnhancedSearchSourcesView: View {
    let results: [EnhancedSearchResult]

    @State private var selectedChannel: SearchChannelType? = nil
    @State private var isExpanded = true
    @State private var isShowingAll = false

    private let maxVisibleResults = 5
    private let maxSnippetLength = 120

    // 按频道分组的结果
    private var groupedResults: [(SearchChannelType, [EnhancedSearchResult])] {
        let grouped = Dictionary(grouping: results) { $0.channelType }
        return SearchChannelType.allCases.compactMap { channel in
            guard let items = grouped[channel], !items.isEmpty else { return nil }
            return (channel, items)
        }
    }

    // 过滤后的结果
    private var filteredResults: [(SearchChannelType, [EnhancedSearchResult])] {
        if let selected = selectedChannel {
            return groupedResults.filter { $0.0 == selected }
        }
        return groupedResults
    }

    // 总结果数
    private var totalResultCount: Int {
        results.count
    }

    var body: some View {
        if !results.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                headerView

                // 频道筛选器
                channelFilterView

                // 结果列表
                if isExpanded {
                    resultsListView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "1E1E2E"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "3B82F6").opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "3B82F6"))

                Text("📚 搜索来源")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(totalResultCount) 个结果")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(hex: "3B82F6").opacity(0.15))
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Channel Filter View

    private var channelFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 全部筛选
                ChannelFilterChip(
                    title: "全部",
                    icon: "square.grid.2x2",
                    color: Color(hex: "6B7280"),
                    isSelected: selectedChannel == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedChannel = nil
                    }
                }

                // 各频道筛选
                ForEach(groupedResults, id: \.0) { channel, items in
                    ChannelFilterChip(
                        title: channel.displayName,
                        icon: channel.icon,
                        color: channel.themeColor,
                        count: items.count,
                        isSelected: selectedChannel == channel
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedChannel = (selectedChannel == channel) ? nil : channel
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Results List View

    private var resultsListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(filteredResults, id: \.0) { channel, items in
                VStack(alignment: .leading, spacing: 6) {
                    // 频道标题
                    HStack(spacing: 6) {
                        Image(systemName: channel.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(channel.themeColor)

                        Text(channel.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(channel.themeColor)

                        Text("(\(items.count))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }

                    // 该频道的结果列表
                    VStack(alignment: .leading, spacing: 0) {
                        let visibleItems = isShowingAll ? items : Array(items.prefix(maxVisibleResults))

                        ForEach(visibleItems) { result in
                            SourceResultRow(
                                result: result,
                                channel: channel,
                                maxSnippetLength: maxSnippetLength
                            )

                            if result.id != visibleItems.last?.id {
                                Divider()
                                    .background(Color(hex: "374151"))
                                    .padding(.vertical, 6)
                            }
                        }

                        // 展开/收起按钮
                        if items.count > maxVisibleResults {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isShowingAll.toggle()
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Text(isShowingAll ? "收起" : "显示更多 (\(items.count - maxVisibleResults))")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(channel.themeColor)
                                    Image(systemName: isShowingAll ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundStyle(channel.themeColor)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "252538"))
                    )
                }
            }
        }
    }
}

// MARK: - 紧凑版搜索来源视图

/// 紧凑版搜索来源视图 - 用于消息气泡内联显示
struct CompactSearchSourcesView: View {
    let results: [EnhancedSearchResult]
    @State private var isShowingPopover = false

    private var channelSummary: [(SearchChannelType, Int)] {
        let grouped = Dictionary(grouping: results) { $0.channelType }
        return SearchChannelType.allCases.compactMap { channel in
            guard let count = grouped[channel]?.count, count > 0 else { return nil }
            return (channel, count)
        }
    }

    var body: some View {
        Button(action: {
            isShowingPopover = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "3B82F6"))

                Text("搜索了 \(results.count) 个来源")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: "3B82F6"))

                HStack(spacing: 4) {
                    ForEach(channelSummary, id: \.0) { channel, count in
                        HStack(spacing: 2) {
                            Image(systemName: channel.icon)
                                .font(.system(size: 9))
                            Text("\(count)")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(channel.themeColor)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "3B82F6").opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "3B82F6").opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
            EnhancedSearchSourcesView(results: results)
                .frame(width: 420, height: 500)
                .padding()
        }
    }
}

// MARK: - 频道筛选芯片

/// 频道筛选芯片组件
private struct ChannelFilterChip: View {
    let title: String
    let icon: String
    let color: Color
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))

                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.25) : color.opacity(0.15))
                        )
                }
            }
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 来源结果行

/// 单个来源结果行组件
private struct SourceResultRow: View {
    let result: EnhancedSearchResult
    let channel: SearchChannelType
    let maxSnippetLength: Int

    @State private var isHovering = false

    private var truncatedSnippet: String {
        if result.snippet.count > maxSnippetLength {
            return String(result.snippet.prefix(maxSnippetLength)) + "..."
        }
        return result.snippet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标题行
            HStack(spacing: 8) {
                // 频道图标
                Image(systemName: result.sourceIcon ?? channel.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(channel.themeColor)
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(channel.themeColor.opacity(0.15))
                    )

                // 标题
                Text(result.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                // 来源标签
                Text(result.source)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "374151"))
                    )
            }

            // 摘要
            Text(truncatedSnippet)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // 底部信息行
            HStack(spacing: 12) {
                // 作者/日期信息
                if let author = result.author, !author.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                        Text(author)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.tertiary)
                }

                if let dateString = result.formattedDate {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(dateString)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.tertiary)
                }

                // 元数据标签
                if let metadata = result.metadata {
                    metadataTagsView(metadata: metadata)
                }

                Spacer()

                // 打开链接按钮
                if let url = URL(string: result.url) {
                    Link(destination: url) {
                        HStack(spacing: 3) {
                            Text("打开")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(channel.themeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(channel.themeColor.opacity(isHovering ? 0.2 : 0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(channel.themeColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isHovering = hovering
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Metadata Tags View

    @ViewBuilder
    private func metadataTagsView(metadata: SearchResultMetadata) -> some View {
        HStack(spacing: 6) {
            // 学术指标
            if let citations = metadata.citationCount {
                HStack(spacing: 2) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 9))
                    Text("\(citations)")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color(hex: "8B5CF6"))
            }

            // 社交指标
            if let upvotes = metadata.upvoteCount {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9))
                    Text("\(upvotes)")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color(hex: "F59E0B"))
            }

            if let comments = metadata.commentCount {
                HStack(spacing: 2) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 9))
                    Text("\(comments)")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.tertiary)
            }

            // 语言标签
            if let language = metadata.language {
                Text(language)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: "10B981"))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "10B981").opacity(0.15))
                    )
            }

            // 开放获取标签
            if metadata.isOpenAccess == true {
                HStack(spacing: 2) {
                    Image(systemName: "lock.open")
                        .font(.system(size: 9))
                    Text("开放获取")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color(hex: "10B981"))
            }
        }
    }
}

// MARK: - Preview

struct EnhancedSearchSourcesView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // 完整视图
            EnhancedSearchSourcesView(results: PreviewData.sampleResults)
                .padding()

            // 紧凑视图
            CompactSearchSourcesView(results: PreviewData.sampleResults)
        }
        .frame(width: 500)
        .background(Color(hex: "0F0F1A"))
        .previewDisplayName("Enhanced Search Sources")
    }
}

// MARK: - Preview Data

private enum PreviewData {
    static let sampleResults: [EnhancedSearchResult] = [
        EnhancedSearchResult(
            title: "Swift Concurrency: A Deep Dive into async/await",
            url: "https://developer.apple.com/documentation/swift/concurrency",
            snippet: "Swift 的并发模型基于结构化并发，使用 async/await 语法让异步代码看起来像同步代码一样清晰。本文深入探讨 Swift 并发的工作原理和最佳实践。",
            channelType: .general,
            source: "Apple Developer",
            sourceIcon: "apple.logo",
            publishedDate: Date(),
            author: "Apple Inc.",
            relevanceScore: 0.95,
            metadata: nil
        ),
        EnhancedSearchResult(
            title: "Understanding Swift Actors and Data Race Safety",
            url: "https://swift.org/blog/actors",
            snippet: "Actors 是 Swift 5.5 引入的新特性，用于保护可变状态免受数据竞争的影响。本文详细介绍了 Actor 的隔离规则和使用场景。",
            channelType: .code,
            source: "Swift.org",
            sourceIcon: "curlybraces",
            publishedDate: Date().addingTimeInterval(-86400),
            author: "Swift Team",
            relevanceScore: 0.92,
            metadata: SearchResultMetadata(
                language: "Swift",
                isOpenAccess: true
            )
        ),
        EnhancedSearchResult(
            title: "SwiftUI Performance Optimization Techniques",
            url: "https://developer.apple.com/documentation/swiftui/performance",
            snippet: "学习如何优化 SwiftUI 应用的性能，包括视图生命周期管理、状态更新优化和内存管理技巧。",
            channelType: .code,
            source: "GitHub",
            sourceIcon: "chevron.left.forwardslash.chevron.right",
            publishedDate: Date().addingTimeInterval(-172800),
            author: "johnappleseed",
            relevanceScore: 0.88,
            metadata: SearchResultMetadata(
                upvoteCount: 256,
                commentCount: 42,
                language: "Swift"
            )
        ),
        EnhancedSearchResult(
            title: "Machine Learning in iOS: Core ML and Beyond",
            url: "https://arxiv.org/abs/2301.12345",
            snippet: "本文探讨了在 iOS 设备上部署机器学习模型的最新进展，包括 Core ML 的优化策略和神经网络压缩技术。",
            channelType: .academic,
            source: "arXiv",
            sourceIcon: "doc.text.magnifyingglass",
            publishedDate: Date().addingTimeInterval(-259200),
            author: "Dr. Jane Smith",
            relevanceScore: 0.90,
            metadata: SearchResultMetadata(
                citationCount: 45,
                doi: "10.1234/example",
                isOpenAccess: true
            )
        ),
        EnhancedSearchResult(
            title: "How to implement custom SwiftUI view modifiers",
            url: "https://stackoverflow.com/questions/12345678",
            snippet: "我想创建一个可复用的 SwiftUI 视图修饰器，但不确定如何正确处理环境值和状态。有什么最佳实践吗？",
            channelType: .social,
            source: "Stack Overflow",
            sourceIcon: "arrowtriangle.up.fill",
            publishedDate: Date().addingTimeInterval(-43200),
            author: "swift_dev_2024",
            relevanceScore: 0.85,
            metadata: SearchResultMetadata(
                upvoteCount: 128,
                commentCount: 15,
                tags: ["swiftui", "swift", "ios"]
            )
        ),
        EnhancedSearchResult(
            title: "The Future of macOS Development",
            url: "https://www.reddit.com/r/swift/comments/example",
            snippet: "随着 SwiftUI 的成熟，AppKit 开发者的未来在哪里？大家怎么看？",
            channelType: .social,
            source: "Reddit",
            sourceIcon: "bubble.left.and.bubble.right",
            publishedDate: Date().addingTimeInterval(-604800),
            author: "macOS_fan",
            relevanceScore: 0.78,
            metadata: SearchResultMetadata(
                upvoteCount: 512,
                commentCount: 89
            )
        )
    ]
}
