//
//  EnhancedWebSearchService.swift
//  YumikoToys
//
//  增强版联网搜索服务 - 支持多频道搜索（通用、学术、代码、社交）
//  集成 SearXNG、arXiv API、GitHub API、Stack Overflow API
//

import Foundation
import OSLog

// MARK: - 错误类型

/// 增强搜索错误枚举
enum EnhancedSearchError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidQuery
    case requestFailed(statusCode: Int)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)
    case parsingError(message: String)
    case rateLimited
    case serviceUnavailable
    case noResults
    case invalidConfiguration
    case timeout
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidQuery:
            return "无效的搜索查询"
        case .requestFailed(let statusCode):
            return "请求失败，状态码: \(statusCode)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .parsingError(let message):
            return "解析错误: \(message)"
        case .rateLimited:
            return "请求过于频繁，请稍后重试"
        case .serviceUnavailable:
            return "服务暂时不可用"
        case .noResults:
            return "未找到相关结果"
        case .invalidConfiguration:
            return "配置无效"
        case .timeout:
            return "请求超时"
        case .unknown:
            return "未知错误"
        }
    }
}

// MARK: - 响应模型

/// SearXNG 搜索响应
private struct SearXNGResponse: Codable, Sendable {
    let query: String?
    let numberOfResults: Int?
    let results: [SearXNGResult]
    let answers: [String]?
    let corrections: [String]?
    let infoboxes: [SearXNGInfobox]?
    let suggestions: [String]?
    let unresponsiveEngines: [String]?

    enum CodingKeys: String, CodingKey {
        case query
        case numberOfResults = "number_of_results"
        case results
        case answers
        case corrections
        case infoboxes
        case suggestions
        case unresponsiveEngines = "unresponsive_engines"
    }
}

/// SearXNG 搜索结果项
private struct SearXNGResult: Codable, Sendable {
    let title: String
    let url: String
    let content: String
    let engine: String?
    let parsedUrl: [String]?
    let template: String?
    let engines: [String]?
    let positions: [Int]?
    let score: Double?
    let category: String?
    let publishedDate: String?

    enum CodingKeys: String, CodingKey {
        case title
        case url
        case content
        case engine
        case parsedUrl = "parsed_url"
        case template
        case engines
        case positions
        case score
        case category
        case publishedDate = "publishedDate"
    }
}

/// SearXNG 信息框
private struct SearXNGInfobox: Codable, Sendable {
    let infobox: String?
    let id: String?
    let content: String?
    let engine: String?
    let urls: [SearXNGInfoboxURL]?
}

/// SearXNG 信息框 URL
private struct SearXNGInfoboxURL: Codable, Sendable {
    let title: String
    let url: String
}

/// GitHub 代码搜索响应
private struct GitHubCodeSearchResponse: Codable, Sendable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [GitHubCodeItem]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

/// GitHub 代码项
private struct GitHubCodeItem: Codable, Sendable {
    let name: String
    let path: String
    let sha: String
    let url: String
    let gitUrl: String?
    let htmlUrl: String
    let repository: GitHubRepository
    let score: Double

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case sha
        case url
        case gitUrl = "git_url"
        case htmlUrl = "html_url"
        case repository
        case score
    }
}

/// GitHub 仓库信息
private struct GitHubRepository: Codable, Sendable {
    let id: Int
    let name: String
    let fullName: String
    let htmlUrl: String
    let description: String?
    let stargazersCount: Int
    let language: String?
    let owner: GitHubOwner

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case description
        case stargazersCount = "stargazers_count"
        case language
        case owner
    }
}

/// GitHub 仓库所有者
private struct GitHubOwner: Codable, Sendable {
    let login: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

/// Stack Overflow 搜索响应
private struct StackOverflowResponse: Codable, Sendable {
    let items: [StackOverflowQuestion]
    let hasMore: Bool
    let quotaMax: Int
    let quotaRemaining: Int

    enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
        case quotaMax = "quota_max"
        case quotaRemaining = "quota_remaining"
    }
}

/// Stack Overflow 问题
private struct StackOverflowQuestion: Codable, Sendable {
    let questionId: Int
    let title: String
    let link: String
    let score: Int
    let answerCount: Int
    let viewCount: Int
    let creationDate: Date
    let lastActivityDate: Date
    let tags: [String]
    let owner: StackOverflowOwner
    let isAnswered: Bool
    let acceptedAnswerId: Int?

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case title
        case link
        case score
        case answerCount = "answer_count"
        case viewCount = "view_count"
        case creationDate = "creation_date"
        case lastActivityDate = "last_activity_date"
        case tags
        case owner
        case isAnswered = "is_answered"
        case acceptedAnswerId = "accepted_answer_id"
    }
}

/// Stack Overflow 问题所有者
private struct StackOverflowOwner: Codable, Sendable {
    let reputation: Int?
    let userId: Int?
    let displayName: String?
    let link: String?

    enum CodingKeys: String, CodingKey {
        case reputation
        case userId = "user_id"
        case displayName = "display_name"
        case link
    }
}

/// arXiv 论文条目
private struct ArXivEntry: Sendable {
    let id: String
    let title: String
    let summary: String
    let authors: [String]
    let published: Date
    let updated: Date?
    let categories: [String]
    let primaryCategory: String
    let pdfUrl: String?
    let doi: String?
    let comment: String?
    let journalRef: String?
}

// MARK: - arXiv XML 解析器

/// arXiv XML 解析器
private final class ArxivXMLParser: NSObject {
    private var entries: [ArXivEntry] = []
    private var currentElement = ""
    private var currentEntry: ArXivEntryBuilder?
    private var currentText = ""
    private var parsingTask: Task<[ArXivEntry], Error>?

    private class ArXivEntryBuilder: Sendable {
        var id: String = ""
        var title: String = ""
        var summary: String = ""
        var authors: [String] = []
        var published: Date?
        var updated: Date?
        var categories: [String] = []
        var primaryCategory: String = ""
        var pdfUrl: String?
        var doi: String?
        var comment: String?
        var journalRef: String?
        var currentAuthorName: String = ""

        func build() -> ArXivEntry? {
            guard !id.isEmpty,
                  !title.isEmpty,
                  let published = published else {
                return nil
            }

            return ArXivEntry(
                id: id,
                title: title,
                summary: summary,
                authors: authors,
                published: published,
                updated: updated,
                categories: categories,
                primaryCategory: primaryCategory,
                pdfUrl: pdfUrl,
                doi: doi,
                comment: comment,
                journalRef: journalRef
            )
        }
    }

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func parse(data: Data) async throws -> [ArXivEntry] {
        // 取消之前的解析任务
        parsingTask?.cancel()

        parsingTask = Task { [weak self] in
            guard let self = self else { return [] }

            let parser = XMLParser(data: data)
            parser.delegate = self

            guard parser.parse() else {
                if let error = parser.parserError {
                    throw EnhancedSearchError.parsingError(message: error.localizedDescription)
                }
                throw EnhancedSearchError.parsingError(message: "XML 解析失败")
            }

            // 检查是否被取消
            try Task.checkCancellation()

            return self.entries
        }

        return try await parsingTask!.value
    }
}

extension ArxivXMLParser: XMLParserDelegate {
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "entry":
            currentEntry = ArXivEntryBuilder()
        case "author":
            currentEntry?.currentAuthorName = ""
        case "link":
            if let title = attributeDict["title"], title == "pdf" {
                currentEntry?.pdfUrl = attributeDict["href"]
            }
        case "arxiv:primary_category":
            currentEntry?.primaryCategory = attributeDict["term"] ?? ""
        case "category":
            if let term = attributeDict["term"] {
                currentEntry?.categories.append(term)
            }
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "entry":
            if let entry = currentEntry?.build() {
                entries.append(entry)
            }
            currentEntry = nil
        case "id":
            currentEntry?.id = trimmedText
        case "title":
            currentEntry?.title = trimmedText
        case "summary":
            currentEntry?.summary = trimmedText
        case "name":
            if !trimmedText.isEmpty {
                currentEntry?.authors.append(trimmedText)
            }
        case "published":
            currentEntry?.published = dateFormatter.date(from: trimmedText)
        case "updated":
            currentEntry?.updated = dateFormatter.date(from: trimmedText)
        case "arxiv:doi":
            currentEntry?.doi = trimmedText
        case "arxiv:comment":
            currentEntry?.comment = trimmedText
        case "arxiv:journal_ref":
            currentEntry?.journalRef = trimmedText
        default:
            break
        }

        currentText = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        Logger.enhancedSearch.error("XML 解析错误: \(parseError.localizedDescription)")
    }
}

// MARK: - 增强版搜索服务

/// 增强版联网搜索服务
actor EnhancedWebSearchService: Sendable {

    // MARK: - 配置

    private let searxngBaseURL: String
    private let githubToken: String?
    private let stackOverflowKey: String?
    private let timeoutInterval: TimeInterval

    private let logger = Logger.enhancedSearch

    // MARK: - 初始化

    init(
        searxngBaseURL: String = "https://searx.be",
        githubToken: String? = nil,
        stackOverflowKey: String? = nil,
        timeoutInterval: TimeInterval = 30
    ) {
        self.searxngBaseURL = searxngBaseURL
        self.githubToken = githubToken
        self.stackOverflowKey = stackOverflowKey
        self.timeoutInterval = timeoutInterval
    }

    // MARK: - 主搜索方法

    /// 执行多频道搜索
    /// - Parameters:
    ///   - query: 搜索查询
    ///   - channels: 要搜索的频道类型数组
    ///   - maxResultsPerChannel: 每个频道的最大结果数
    /// - Returns: 按频道分组的结果字典
    func search(
        query: String,
        channels: [SearchChannelType],
        maxResultsPerChannel: Int = 5
    ) async -> [SearchChannelType: Result<[EnhancedSearchResult], EnhancedSearchError>] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            var emptyResults: [SearchChannelType: Result<[EnhancedSearchResult], EnhancedSearchError>] = [:]
            for channel in channels {
                emptyResults[channel] = .failure(.invalidQuery)
            }
            return emptyResults
        }

        // 并行执行多个频道的搜索
        var results: [SearchChannelType: Result<[EnhancedSearchResult], EnhancedSearchError>] = [:]

        await withTaskGroup(of: (SearchChannelType, Result<[EnhancedSearchResult], EnhancedSearchError>).self) { group in
            for channel in channels {
                group.addTask {
                    let result = await self.searchChannel(
                        query: query,
                        channel: channel,
                        maxResults: maxResultsPerChannel
                    )
                    return (channel, result)
                }
            }

            for await (channel, result) in group {
                results[channel] = result
            }
        }

        return results
    }

    /// 根据频道类型执行搜索
    private func searchChannel(
        query: String,
        channel: SearchChannelType,
        maxResults: Int
    ) async -> Result<[EnhancedSearchResult], EnhancedSearchError> {
        do {
            let results: [EnhancedSearchResult]

            switch channel {
            case .general:
                results = try await searchGeneral(query: query, maxResults: maxResults)
            case .academic:
                results = try await searchAcademic(query: query, maxResults: maxResults)
            case .code:
                results = try await searchCode(query: query, maxResults: maxResults)
            case .social:
                results = try await searchSocial(query: query, maxResults: maxResults)
            }

            return .success(results)
        } catch let error as EnhancedSearchError {
            return .failure(error)
        } catch {
            return .failure(.networkError(underlying: error))
        }
    }

    // MARK: - 通用搜索 (SearXNG)

    /// 通用搜索 - 使用 SearXNG
    func searchGeneral(query: String, maxResults: Int = 5) async throws -> [EnhancedSearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw EnhancedSearchError.invalidQuery
        }

        let searchURL = "\(searxngBaseURL)/search"
        var components = URLComponents(string: searchURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: encodedQuery),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "categories", value: "general"),
            URLQueryItem(name: "language", value: "zh-CN")
        ]

        guard let url = components?.url else {
            throw EnhancedSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeoutInterval

        let (data, response) = try await performRequest(request)

        let searxResponse = try JSONDecoder().decode(SearXNGResponse.self, from: data)

        return searxResponse.results.prefix(maxResults).enumerated().map { index, result in
            EnhancedSearchResult(
                title: result.title,
                url: result.url,
                snippet: result.content,
                channelType: .general,
                source: result.engine ?? "SearXNG",
                sourceIcon: nil,
                publishedDate: parseDate(result.publishedDate),
                author: nil,
                relevanceScore: result.score ?? Double(maxResults - index),
                metadata: nil
            )
        }
    }

    // MARK: - 学术搜索 (arXiv)

    /// 学术搜索 - 使用 arXiv API
    func searchAcademic(query: String, maxResults: Int = 5) async throws -> [EnhancedSearchResult] {
        let arxivURL = "http://export.arxiv.org/api/query"

        // 构建 arXiv 查询
        let searchQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        var components = URLComponents(string: arxivURL)
        components?.queryItems = [
            URLQueryItem(name: "search_query", value: "all:\(searchQuery)"),
            URLQueryItem(name: "start", value: "0"),
            URLQueryItem(name: "max_results", value: String(maxResults)),
            URLQueryItem(name: "sortBy", value: "relevance"),
            URLQueryItem(name: "sortOrder", value: "descending")
        ]

        guard let url = components?.url else {
            throw EnhancedSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/atom+xml", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeoutInterval

        let (data, response) = try await performRequest(request)

        // 使用自定义 XML 解析器
        let parser = ArxivXMLParser()
        let entries = try await parser.parse(data: data)

        guard !entries.isEmpty else {
            throw EnhancedSearchError.noResults
        }

        return entries.map { entry in
            let metadata = SearchResultMetadata(
                citationCount: nil,
                downloadCount: nil,
                upvoteCount: nil,
                commentCount: nil,
                tags: entry.categories,
                language: nil,
                fileType: "PDF",
                fileSize: nil,
                doi: entry.doi,
                isOpenAccess: true,
                license: nil
            )

            return EnhancedSearchResult(
                title: entry.title,
                url: entry.pdfUrl ?? "https://arxiv.org/abs/\(entry.id)",
                snippet: entry.summary.prefix(500) + (entry.summary.count > 500 ? "..." : ""),
                channelType: .academic,
                source: "arXiv",
                sourceIcon: "doc.text.magnifyingglass",
                publishedDate: entry.published,
                author: entry.authors.first,
                relevanceScore: nil,
                metadata: metadata
            )
        }
    }

    // MARK: - 代码搜索 (GitHub)

    /// 代码搜索 - 使用 GitHub API
    func searchCode(query: String, maxResults: Int = 5) async throws -> [EnhancedSearchResult] {
        let githubAPIURL = "https://api.github.com/search/code"

        guard var components = URLComponents(string: githubAPIURL) else {
            throw EnhancedSearchError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "per_page", value: String(maxResults)),
            URLQueryItem(name: "sort", value: "indexed"),
            URLQueryItem(name: "order", value: "desc")
        ]

        guard let url = components.url else {
            throw EnhancedSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        // 添加 GitHub Token（如果可用）
        if let token = githubToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.timeoutInterval = timeoutInterval

        let (data, response) = try await performRequest(request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let searchResponse = try decoder.decode(GitHubCodeSearchResponse.self, from: data)

        guard !searchResponse.items.isEmpty else {
            throw EnhancedSearchError.noResults
        }

        return searchResponse.items.map { item in
            let metadata = SearchResultMetadata(
                citationCount: nil,
                downloadCount: nil,
                upvoteCount: nil,
                commentCount: nil,
                tags: item.repository.language.map { [$0] },
                language: item.repository.language,
                fileType: (item.name as NSString).pathExtension,
                fileSize: nil,
                doi: nil,
                isOpenAccess: true,
                license: nil
            )

            let snippet = "文件: \(item.path)\n仓库: \(item.repository.fullName)\n\(item.repository.description ?? "")"

            return EnhancedSearchResult(
                title: item.name,
                url: item.htmlUrl,
                snippet: snippet,
                channelType: .code,
                source: "GitHub",
                sourceIcon: "chevron.left.forwardslash.chevron.right",
                publishedDate: nil,
                author: item.repository.owner.login,
                relevanceScore: item.score,
                metadata: metadata
            )
        }
    }

    // MARK: - 社交搜索 (Stack Overflow)

    /// 社交搜索 - 使用 Stack Overflow API
    func searchSocial(query: String, maxResults: Int = 5) async throws -> [EnhancedSearchResult] {
        let stackOverflowAPIURL = "https://api.stackexchange.com/2.3/search/advanced"

        guard var components = URLComponents(string: stackOverflowAPIURL) else {
            throw EnhancedSearchError.invalidURL
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "pagesize", value: String(maxResults)),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "sort", value: "relevance"),
            URLQueryItem(name: "site", value: "stackoverflow"),
            URLQueryItem(name: "filter", value: "withbody")
        ]

        // 添加 API Key（如果可用）
        if let key = stackOverflowKey {
            queryItems.append(URLQueryItem(name: "key", value: key))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw EnhancedSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = timeoutInterval

        let (data, response) = try await performRequest(request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let searchResponse = try decoder.decode(StackOverflowResponse.self, from: data)

        guard !searchResponse.items.isEmpty else {
            throw EnhancedSearchError.noResults
        }

        return searchResponse.items.map { question in
            let metadata = SearchResultMetadata(
                citationCount: nil,
                downloadCount: nil,
                upvoteCount: question.score,
                commentCount: question.answerCount,
                tags: question.tags,
                language: nil,
                fileType: nil,
                fileSize: nil,
                doi: nil,
                isOpenAccess: true,
                license: nil
            )

            let status = question.isAnswered ? "✓ 已解决" : "待回答"
            let snippet = "\(status) · \(question.answerCount) 回答 · \(question.viewCount) 浏览\n标签: \(question.tags.joined(separator: ", "))"

            return EnhancedSearchResult(
                title: question.title,
                url: question.link,
                snippet: snippet,
                channelType: .social,
                source: "Stack Overflow",
                sourceIcon: "arrowtriangle.up.fill",
                publishedDate: question.creationDate,
                author: question.owner.displayName,
                relevanceScore: Double(question.score),
                metadata: metadata
            )
        }
    }

    // MARK: - 辅助方法

    /// 执行网络请求
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnhancedSearchError.unknown
            }

            switch httpResponse.statusCode {
            case 200...299:
                return (data, response)
            case 429:
                throw EnhancedSearchError.rateLimited
            case 503, 504:
                throw EnhancedSearchError.serviceUnavailable
            default:
                throw EnhancedSearchError.requestFailed(statusCode: httpResponse.statusCode)
            }
        } catch let error as EnhancedSearchError {
            throw error
        } catch {
            throw EnhancedSearchError.networkError(underlying: error)
        }
    }

    /// 解析日期字符串
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateStyle = .medium
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
}

// MARK: - Logger 扩展

private extension Logger {
    static let enhancedSearch = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yumikotoys",
        category: "EnhancedWebSearch"
    )
}
