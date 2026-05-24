//
//  WebSearchService.swift
//  YumikoToys
//
//  联网搜索服务 - 通过 SearXNG 聚合搜索引擎
//

import Foundation

/// 搜索结果
struct WebSearchResult: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let url: String
    let snippet: String
    let engine: String

    init(title: String, url: String, snippet: String, engine: String = "") {
        self.id = UUID().uuidString
        self.title = title
        self.url = url
        self.snippet = snippet
        self.engine = engine
    }
}

/// 联网搜索服务
final class WebSearchService: Sendable {
    /// 默认 SearXNG 实例
    private let defaultSearchURL = "https://searx.be/search"

    /// 搜索引擎选择
    enum SearchEngine: String, Codable, Sendable {
        case auto = "auto"
        case google = "google"
        case baidu = "baidu"
        case bing = "bing"
    }

    /// 执行搜索
    func search(query: String, engine: SearchEngine = .auto, maxResults: Int = 5) async throws -> [WebSearchResult] {
        var components = URLComponents(string: defaultSearchURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "categories", value: "general"),
        ]

        switch engine {
        case .auto:
            break
        case .google:
            components?.queryItems?.append(URLQueryItem(name: "engines", value: "google"))
        case .baidu:
            components?.queryItems?.append(URLQueryItem(name: "engines", value: "baidu"))
        case .bing:
            components?.queryItems?.append(URLQueryItem(name: "engines", value: "bing"))
        }

        guard let url = components?.url else {
            throw WebSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WebSearchError.requestFailed
        }

        let searchResponse = try JSONDecoder().decode(SearXNGResponse.self, from: data)

        return searchResponse.results.prefix(maxResults).map { result in
            WebSearchResult(
                title: result.title,
                url: result.url,
                snippet: result.content,
                engine: result.engine ?? ""
            )
        }
    }

    /// 转换为 SearchSource（用于 ChatMessage）
    static func toSearchSources(_ results: [WebSearchResult]) -> [SearchSource] {
        results.map { result in
            SearchSource(
                title: result.title,
                url: result.url,
                snippet: result.snippet
            )
        }
    }
}

// MARK: - SearXNG 响应模型

private struct SearXNGResponse: Codable {
    let results: [SearXNGResult]
}

private struct SearXNGResult: Codable {
    let title: String
    let url: String
    let content: String
    let engine: String?
}

// MARK: - 错误

enum WebSearchError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的搜索 URL"
        case .requestFailed: return "搜索请求失败"
        case .decodingError: return "搜索结果解析失败"
        }
    }
}
