//
//  TavilySearchService.swift
//  YumikoToys
//
//  Tavily & Google 官方 API 及 Python 原生极简正则搜索引擎（v5.0.0 - 100% 对齐 Python 无干扰防拦截版）
//

import Foundation
import OSLog
import CFNetwork
import NaturalLanguage

// MARK: - Logger 扩展

private extension Logger {
    static let tavily = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yumikotoys",
        category: "TavilySearch"
    )
}

// MARK: - Tavily 错误类型

enum TavilyError: Error, LocalizedError, Sendable {
    case missingAPIKey
    case invalidQuery
    case invalidRequest(reason: String)
    case httpError(statusCode: Int, message: String?)
    case decodingError(underlying: Error)
    case networkError(underlying: Error)
    case rateLimited(retryAfter: TimeInterval?)
    case creditsExhausted
    case timeout
    case noResults
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "API Key 未配置"
        case .invalidQuery: return "搜索查询内容无效"
        case .invalidRequest(let reason): return "请求构建失败: \(reason)"
        case .httpError(let statusCode, let message): return message != nil ? "API 请求失败 (\(statusCode)): \(message!)" : "API 请求失败，状态码: \(statusCode)"
        case .decodingError(let error): return "数据解析失败: \(error.localizedDescription)"
        case .networkError(let error): return "网络错误: \(error.localizedDescription)"
        case .rateLimited(let retryAfter): return retryAfter != nil ? "频率超限，请在 \(Int(retryAfter!)) 秒后重试" : "请求频率超限"
        case .creditsExhausted: return "API 额度已耗尽"
        case .timeout: return "请求超时"
        case .noResults: return "未找到相关搜索结果"
        case .unknown(let message): return "未知错误: \(message)"
        }
    }
}

// MARK: - API 模型及配置

struct TavilySearchConfig: Sendable {
    let apiKey: String
    let defaultSearchDepth: TavilySearchDepth
    let defaultMaxResults: Int
    let defaultTopic: TavilyTopic
    let timeoutInterval: TimeInterval
    let baseURL: String

    init(apiKey: String, defaultSearchDepth: TavilySearchDepth = .basic, defaultMaxResults: Int = 5, defaultTopic: TavilyTopic = .general, timeoutInterval: TimeInterval = 30, baseURL: String = "https://api.tavily.com") {
        self.apiKey = apiKey
        self.defaultSearchDepth = defaultSearchDepth
        self.defaultMaxResults = min(max(defaultMaxResults, 0), 20)
        self.defaultTopic = defaultTopic
        self.timeoutInterval = timeoutInterval
        self.baseURL = baseURL
    }
}

enum TavilySearchDepth: String, Codable, Sendable, CaseIterable { case basic, advanced, fast, ultraFast = "ultra-fast" }
enum TavilyTopic: String, Codable, Sendable, CaseIterable { case general, news }
enum TavilyTimeRange: String, Codable, Sendable, CaseIterable { case day, week, month, year }

private struct TavilySearchRequestBody: Codable, Sendable {
    let query: String
    let searchDepth: String
    let maxResults: Int
    let topic: String
    let includeAnswer: Bool
    let includeRawContent: Bool
    let timeRange: String?
    let country: String?
    let includeDomains: [String]?
    let excludeDomains: [String]?
    enum CodingKeys: String, CodingKey { case query, searchDepth = "search_depth", maxResults = "max_results", topic, includeAnswer = "include_answer", includeRawContent = "include_raw_content", timeRange = "time_range", country, includeDomains = "include_domains", excludeDomains = "exclude_domains" }
}

private struct TavilyExtractRequestBody: Codable, Sendable { let urls: [String] }

struct TavilySearchResponse: Codable, Sendable {
    let query: String
    let answer: String?
    let results: [TavilySearchResult]
    let responseTime: Double
    let usage: TavilyUsage
    enum CodingKeys: String, CodingKey { case query, answer, results, responseTime = "response_time", usage }
}

struct TavilySearchResult: Codable, Sendable, Identifiable {
    var id: String { url }
    let title: String
    let url: String
    let content: String
    let score: Double?
    let rawContent: String?
    let favicon: String?
    let images: [String]?
    enum CodingKeys: String, CodingKey { case title, url, content, score, rawContent = "raw_content", favicon, images }
}

struct TavilyUsage: Codable, Sendable { let credits: Int }
private struct TavilyExtractResponse: Codable, Sendable { let results: [TavilyExtractResult] }
private struct TavilyExtractResult: Codable, Sendable { let url: String; let rawContent: String?; enum CodingKeys: String, CodingKey { case url, rawContent = "raw_content" } }

// MARK: - 官方 Tavily 服务
@MainActor
final class TavilySearchService: Sendable {
    private let config: TavilySearchConfig
    private let session: URLSession
    private let logger = Logger.tavily
    private let encoder: JSONEncoder = { let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase; return e }()
    private let decoder: JSONDecoder = { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }()

    static func makeProxyConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        var systemProxies: [String: Any] = [:]
        if let fetchedProxies = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] { systemProxies = fetchedProxies }
        if systemProxies.isEmpty {
            systemProxies[kCFNetworkProxiesHTTPEnable as String] = 1; systemProxies[kCFNetworkProxiesHTTPProxy as String] = "127.0.0.1"; systemProxies[kCFNetworkProxiesHTTPPort as String] = 7897
            systemProxies[kCFNetworkProxiesHTTPSEnable as String] = 1; systemProxies[kCFNetworkProxiesHTTPSProxy as String] = "127.0.0.1"; systemProxies[kCFNetworkProxiesHTTPSPort as String] = 7897
        }
        systemProxies[kCFNetworkProxiesExceptionsList as String] = ["localhost", "127.0.0.1", "*.local", "cn.bing.com", "*.baidu.com", "baidu.com", "*.cn", "*.xiaopeng.com"]
        configuration.connectionProxyDictionary = systemProxies
        return configuration
    }

    init(config: TavilySearchConfig) {
        self.config = config
        let configuration = Self.makeProxyConfiguration()
        configuration.timeoutIntervalForRequest = config.timeoutInterval
        configuration.timeoutIntervalForResource = config.timeoutInterval + 15
        configuration.httpAdditionalHeaders = ["Content-Type": "application/json", "Accept": "application/json"]
        self.session = URLSession(configuration: configuration)
    }
    convenience init(apiKey: String) { self.init(config: TavilySearchConfig(apiKey: apiKey)) }

    func search(query: String, depth: TavilySearchDepth? = nil, maxResults: Int? = nil, topic: TavilyTopic? = nil, includeAnswer: Bool = false) async throws -> TavilySearchResponse {
        guard !config.apiKey.isEmpty else { throw TavilyError.missingAPIKey }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { throw TavilyError.invalidQuery }
        
        let body = TavilySearchRequestBody(query: trimmedQuery, searchDepth: (depth ?? config.defaultSearchDepth).rawValue, maxResults: min(max(maxResults ?? config.defaultMaxResults, 0), 20), topic: (topic ?? config.defaultTopic).rawValue, includeAnswer: includeAnswer, includeRawContent: false, timeRange: nil, country: nil, includeDomains: nil, excludeDomains: nil)
        guard let url = URL(string: "\(config.baseURL)/search") else { throw TavilyError.invalidRequest(reason: "URL 构建失败") }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        var dataAndResponse: (Data, URLResponse)? = nil
        do {
            dataAndResponse = try await session.data(for: request)
        } catch {
            Logger.tavily.warning("Tavily proxy search failed: \(error). Retrying with URLSession.shared...")
            dataAndResponse = try await URLSession.shared.data(for: request)
        }
        
        guard let (data, response) = dataAndResponse else {
            throw TavilyError.networkError(underlying: NSError(domain: "Tavily", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load data"]))
        }
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw TavilyError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: nil)
        }
        return try decoder.decode(TavilySearchResponse.self, from: data)
    }

    func extract(url: String) async throws -> String {
        let body = TavilyExtractRequestBody(urls: [url])
        guard let requestURL = URL(string: "\(config.baseURL)/extract") else { throw TavilyError.invalidRequest(reason: "URL 构建失败") }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        var dataAndResponse: (Data, URLResponse)? = nil
        do {
            dataAndResponse = try await session.data(for: request)
        } catch {
            dataAndResponse = try await URLSession.shared.data(for: request)
        }
        
        guard let (data, _) = dataAndResponse else {
            throw TavilyError.networkError(underlying: NSError(domain: "Tavily", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load extract data"]))
        }
        
        let extractResponse = try decoder.decode(TavilyExtractResponse.self, from: data)
        guard let rawContent = extractResponse.results.first?.rawContent, !rawContent.isEmpty else { throw TavilyError.noResults }
        return rawContent
    }

    func toEnhancedResults(_ response: TavilySearchResponse) -> [EnhancedSearchResult] {
        response.results.map { EnhancedSearchResult(title: $0.title, url: $0.url, snippet: $0.content, channelType: .general, source: "Tavily", sourceIcon: "sparkles", publishedDate: nil, author: nil, relevanceScore: $0.score.map { $0 * 100 }) }
    }
    func toSearchSources(_ response: TavilySearchResponse) -> [SearchSource] {
        response.results.map { SearchSource(title: $0.title, url: $0.url, snippet: $0.content) }
    }
}

// MARK: - 搜索后端枚举
enum SearchBackend: String, Codable, CaseIterable, Sendable, Identifiable {
    case tavily, searxng, brave, google
    var id: String { rawValue }
    var displayName: String {
        switch self { case .tavily: return "Tavily"; case .searxng: return "SearXNG / 免费默认"; case .brave: return "Brave"; case .google: return "Google API" }
    }
}

// MARK: - 【谷歌官方自定义搜索 API 封装服务】
@MainActor
final class GoogleSearchService: Sendable {
    private let apiKey: String; private let cx: String; private let session: URLSession
    init(apiKey: String, cx: String) {
        self.apiKey = apiKey; self.cx = cx
        let config = TavilySearchService.makeProxyConfiguration(); config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }
    func search(query: String, maxResults: Int) async throws -> [EnhancedSearchResult] {
        guard !apiKey.isEmpty && !cx.isEmpty else { throw TavilyError.missingAPIKey }
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.googleapis.com/customsearch/v1?key=\(apiKey)&cx=\(cx)&q=\(encodedQuery)&num=\(maxResults)") else { throw TavilyError.invalidRequest(reason: "URL 构建失败") }
        var request = URLRequest(url: url); request.httpMethod = "GET"
        
        var dataAndResponse: (Data, URLResponse)? = nil
        do {
            dataAndResponse = try await session.data(for: request)
        } catch {
            dataAndResponse = try await URLSession.shared.data(for: request)
        }
        
        guard let (data, response) = dataAndResponse else {
            throw TavilyError.unknown(message: "Google API 失败")
        }
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else { throw TavilyError.unknown(message: "Google API 失败") }
        let apiResponse = try JSONDecoder().decode(GoogleSearchAPIResponse.self, from: data)
        guard let items = apiResponse.items, !items.isEmpty else { throw TavilyError.noResults }
        return items.map { EnhancedSearchResult(title: $0.title, url: $0.link, snippet: $0.snippet, channelType: .general, source: "Google API", sourceIcon: "sparkles", publishedDate: nil, author: nil, relevanceScore: 98.0) }
    }
}
struct GoogleSearchAPIResponse: Codable, Sendable { let items: [GoogleSearchAPIItem]? }
struct GoogleSearchAPIItem: Codable, Sendable { let title: String; let link: String; let snippet: String }

// MARK: - 统一搜索服务 (核心重构：彻底对齐 Python 极简哲学)

@MainActor
final class UnifiedSearchService: ObservableObject, Sendable {

    @Published private(set) var activeBackend: SearchBackend
    private var tavilyService: TavilySearchService?
    private var googleSearchService: GoogleSearchService?

    init(assistantConfig: AssistantConfig) {
        let isGoogleConfig = !assistantConfig.searchAPIURL.contains("http") && !assistantConfig.searchAPIURL.isEmpty
        if isGoogleConfig {
            self.googleSearchService = GoogleSearchService(apiKey: assistantConfig.searchAPIKey, cx: assistantConfig.searchAPIURL)
            self.activeBackend = .google
        } else {
            self.activeBackend = .searxng
        }
        
        if !assistantConfig.tavilyAPIKey.isEmpty {
            self.tavilyService = TavilySearchService(config: TavilySearchConfig(apiKey: assistantConfig.tavilyAPIKey))
            self.activeBackend = .tavily
        }
    }

    /// 核心检索执行 (100% 对齐 Python 的逻辑链路)
    func search(query: String, maxResults: Int = 5) async throws -> UnifiedSearchResult {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { throw TavilyError.invalidQuery }

        // 1. 极简智能提取，保护原词 (比如 "柯遥 42")
        let optimizedQuery = Self.extractSemanticKeywords(from: trimmedQuery)

        // 2. 如果配置了高权重的付费 API (Tavily/Google)，优先走这里
        if let tavily = tavilyService {
            do {
                let response = try await tavily.search(query: optimizedQuery, maxResults: maxResults)
                return UnifiedSearchResult(query: response.query, answer: response.answer, results: tavily.toEnhancedResults(response), sources: tavily.toSearchSources(response), backend: .tavily, responseTime: response.responseTime)
            } catch {
                LoggerService.shared.warning("Tavily search failed: \(error). Falling back to next backend.")
            }
        }
        
        if let google = googleSearchService {
            do {
                let results = try await google.search(query: optimizedQuery, maxResults: maxResults)
                let sources = results.map { SearchSource(title: $0.title, url: $0.url, snippet: $0.snippet) }
                return UnifiedSearchResult(query: optimizedQuery, answer: nil, results: results, sources: sources, backend: .google, responseTime: 0.1)
            } catch {
                LoggerService.shared.warning("Google search failed: \(error). Falling back to DDG.")
            }
        }

        // 3. DDG HTML 抓取（Python 版本原汁原味移植）
        LoggerService.shared.info("All premium search backends failed. Using DDG HTML scraping for query: \(optimizedQuery)")
        return try await executePythonStyleDDGSearch(query: optimizedQuery, maxResults: maxResults)
    }
    
    // MARK: - 👈 原汁原味的 Python 正则提取算法
    
    nonisolated private func executePythonStyleDDGSearch(query: String, maxResults: Int) async throws -> UnifiedSearchResult {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)") else {
            throw TavilyError.invalidRequest(reason: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // 👈 绝对还原！伪装成高权重的 Windows Chrome 浏览器，规避 Cloudflare 拦截
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        
        // 👈 Fallback support for DuckDuckGo search connection issues
        var dataAndResponse: (Data, URLResponse)? = nil
        do {
            let session = SmartProxyManager.makeSession(for: "https://html.duckduckgo.com")
            dataAndResponse = try await session.data(for: request)
        } catch {
            LoggerService.shared.warning("Proxy DDG search failed: \(error). Retrying with URLSession.shared...")
            dataAndResponse = try await URLSession.shared.data(for: request)
        }
        
        guard let (data, response) = dataAndResponse,
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            throw TavilyError.unknown(message: "DDG HTML Request Failed")
        }

        var urlMap: [String: (title: String, snippet: String)] = [:]
        var urlOrderedKeys: [String] = []

        func addResult(targetURL: String, title: String?, snippet: String?) {
            let cleanURL = targetURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanURL.isEmpty else { return }
            
            var current = urlMap[cleanURL] ?? (title: "", snippet: "")
            if let t = title, !t.isEmpty {
                current.title = t
            }
            if let s = snippet, !s.isEmpty {
                current.snippet = s
            }
            urlMap[cleanURL] = current
            if !urlOrderedKeys.contains(cleanURL) {
                urlOrderedKeys.append(cleanURL)
            }
        }

        // Helper to extract uddg target URL
        func extractDDGTargetURL(from href: String) -> String? {
            if let urlComponents = URLComponents(string: href.hasPrefix("//") ? "https:" + href : href),
               let uddg = urlComponents.queryItems?.first(where: { $0.name == "uddg" })?.value {
                return uddg
            }
            if let range = href.range(of: "uddg=") {
                let sub = href[range.upperBound...]
                let end = sub.firstIndex(of: "&") ?? sub.endIndex
                let encoded = String(sub[..<end])
                return encoded.removingPercentEncoding
            }
            // If it's a direct URL
            if href.hasPrefix("http") {
                return href
            }
            return nil
        }

        // 1. Match <a class="result__url" ...>
        let urlRegex = try? NSRegularExpression(pattern: "<a[^>]+class=\"[^\"]*result__url[^\"]*\"[^>]+href=\"([^\"]+)\"[^>]*>(.*?)</a>", options: [.dotMatchesLineSeparators, .caseInsensitive])
        if let matches = urlRegex?.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            for match in matches {
                guard let hrefRange = Range(match.range(at: 1), in: html),
                      let titleRange = Range(match.range(at: 2), in: html) else { continue }
                let href = String(html[hrefRange])
                let title = stripSearchHTML(String(html[titleRange]))
                if let targetURL = extractDDGTargetURL(from: href) {
                    addResult(targetURL: targetURL, title: title, snippet: nil)
                }
            }
        }

        // 2. Match <a class="result__snippet" ...>
        let snippetRegex = try? NSRegularExpression(pattern: "<a[^>]+class=\"[^\"]*result__snippet[^\"]*\"[^>]+href=\"([^\"]+)\"[^>]*>(.*?)</a>", options: [.dotMatchesLineSeparators, .caseInsensitive])
        if let matches = snippetRegex?.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            for match in matches {
                guard let hrefRange = Range(match.range(at: 1), in: html),
                      let snippetRange = Range(match.range(at: 2), in: html) else { continue }
                let href = String(html[hrefRange])
                let snippet = stripSearchHTML(String(html[snippetRange]))
                if let targetURL = extractDDGTargetURL(from: href) {
                    addResult(targetURL: targetURL, title: nil, snippet: snippet)
                }
            }
        }

        // 3. Match <td class="result__snippet"> (for the table layout)
        let tdRegex = try? NSRegularExpression(pattern: "<td[^>]+class=\"[^\"]*result__snippet[^\"]*\"[^>]*>(.*?)</td>", options: [.dotMatchesLineSeparators, .caseInsensitive])
        if let matches = tdRegex?.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            for match in matches {
                guard let tdRange = Range(match.range(at: 1), in: html) else { continue }
                let tdContent = String(html[tdRange])
                // Find any link in it to associate the snippet with a URL
                let aRegex = try? NSRegularExpression(pattern: "<a[^>]+href=\"([^\"]+)\"[^>]*>(.*?)</a>", options: [.dotMatchesLineSeparators, .caseInsensitive])
                if let aMatch = aRegex?.firstMatch(in: tdContent, range: NSRange(tdContent.startIndex..., in: tdContent)),
                   let hrefRange = Range(aMatch.range(at: 1), in: tdContent) {
                    let href = String(tdContent[hrefRange])
                    let snippet = stripSearchHTML(tdContent)
                    if let targetURL = extractDDGTargetURL(from: href) {
                        addResult(targetURL: targetURL, title: nil, snippet: snippet)
                    }
                }
            }
        }

        var sources: [SearchSource] = []
        var results: [EnhancedSearchResult] = []

        for url in urlOrderedKeys {
            guard let item = urlMap[url] else { continue }
            let title = item.title.isEmpty ? "网页检索参考" : item.title
            let snippet = item.snippet
            if !snippet.isEmpty {
                sources.append(SearchSource(title: title, url: url, snippet: snippet))
                results.append(EnhancedSearchResult(title: title, url: url, snippet: snippet, channelType: .general, source: "DuckDuckGo", sourceIcon: "globe", publishedDate: nil, author: nil, relevanceScore: 99.0))
            }
        }

        let finalSources = Array(sources.prefix(maxResults))
        let finalResults = Array(results.prefix(maxResults))

        guard !finalSources.isEmpty else {
            throw TavilyError.noResults
        }

        return UnifiedSearchResult(
            query: query,
            answer: nil,
            results: finalResults,
            sources: finalSources,
            backend: .searxng,
            responseTime: 0.1
        )
    }

    nonisolated private func stripSearchHTML(_ html: String) -> String {
        var result = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "&[^;]+;", with: "", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 智能文本提取器

    static func extractSemanticKeywords(from query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 15 { return trimmed }

        let conversationalStopWords = ["请问", "帮我查一下", "帮我搜索", "搜一下", "我想知道", "介绍一下", "关于", "的事情", "是谁", "是什么", "怎么回事", "怎么样", "如何", "怎么", "哪个", "什么", "有没有", "知道吗", "了解吗", "吗", "呢", "啊", "吧", "的", "了", "和", "与", "或", "在", "里"]
        var processed = trimmed
        for word in conversationalStopWords { processed = processed.replacingOccurrences(of: word, with: " ") }

        let words = processed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let finalResult = words.joined(separator: " ")
        return finalResult.isEmpty ? trimmed : finalResult
    }
}

// MARK: - 统一搜索结果

struct UnifiedSearchResult: Sendable {
    let query: String
    let answer: String?
    let results: [EnhancedSearchResult]
    let sources: [SearchSource]
    let backend: SearchBackend
    let responseTime: Double
    var hasAnswer: Bool { answer != nil && !(answer?.isEmpty ?? true) }
}
