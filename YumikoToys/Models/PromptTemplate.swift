import Foundation
import SwiftData

/// 提示词模板分类
enum PromptCategory: String, Codable, CaseIterable, Identifiable {
    case writing = "写作"
    case coding = "编程"
    case analysis = "分析"
    case translation = "翻译"
    case creative = "创意"
    case custom = "自定义"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .writing: return "pencil"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .analysis: return "chart.bar"
        case .translation: return "globe"
        case .creative: return "lightbulb"
        case .custom: return "star"
        }
    }

    var displayName: String { rawValue }
}

/// 提示词变量
struct PromptVariable: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let placeholder: String
    let isRequired: Bool

    init(id: UUID = UUID(), name: String, placeholder: String, isRequired: Bool = false) {
        self.id = id
        self.name = name
        self.placeholder = placeholder
        self.isRequired = isRequired
    }
}

/// 提示词模板模型
@Model
final class PromptTemplate {
    @Attribute(.unique) let id: UUID
    let name: String
    let template: String
    let templateDescription: String
    let isBuiltIn: Bool
    let createdAt: Date
    let updatedAt: Date

    private var categoryRawValue: String
    private var variablesData: Data

    var category: PromptCategory {
        get { PromptCategory(rawValue: categoryRawValue) ?? .custom }
        set { categoryRawValue = newValue.rawValue }
    }

    var variables: [PromptVariable] {
        get {
            (try? JSONDecoder().decode([PromptVariable].self, from: variablesData)) ?? []
        }
        set {
            variablesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: PromptCategory,
        template: String,
        variables: [PromptVariable] = [],
        description: String = "",
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.categoryRawValue = category.rawValue
        self.template = template
        self.variablesData = (try? JSONEncoder().encode(variables)) ?? Data()
        self.templateDescription = description
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    func apply(variables: [String: String]) -> String {
        var result = template
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    func validate(variables: [String: String]) -> Bool {
        for variable in self.variables where variable.isRequired {
            if variables[variable.name]?.isEmpty ?? true {
                return false
            }
        }
        return true
    }

    func extractVariableNames() -> [String] {
        let pattern = #"\{\{(\w+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: template) {
                return String(template[range])
            }
            return nil
        }
    }
}

// MARK: - 内置模板

func builtInPromptTemplates() -> [PromptTemplate] {
    [
        PromptTemplate(
            name: "文章润色",
            category: .writing,
            template: "请对以下文章进行润色和优化：\n\n{{content}}\n\n要求：\n1. 改善语言表达，使其更加流畅自然\n2. 修正语法和拼写错误\n3. 保持原文的核心意思和风格\n4. 适当优化段落结构\n",
            variables: [
                PromptVariable(name: "content", placeholder: "粘贴需要润色的文章内容", isRequired: true)
            ],
            description: "对文章进行润色、优化和纠错",
            isBuiltIn: true
        ),
        PromptTemplate(
            name: "代码审查",
            category: .coding,
            template: "请对以下{{language}}代码进行审查：\n\n```{{language}}\n{{code}}\n```\n\n请从以下方面进行分析：\n1. 代码质量和可读性\n2. 潜在的错误或漏洞\n3. 性能优化建议\n4. 最佳实践建议\n",
            variables: [
                PromptVariable(name: "language", placeholder: "编程语言，如 Swift、Python", isRequired: true),
                PromptVariable(name: "code", placeholder: "粘贴需要审查的代码", isRequired: true)
            ],
            description: "审查代码质量并提供改进建议",
            isBuiltIn: true
        ),
        PromptTemplate(
            name: "数据分析",
            category: .analysis,
            template: "请对以下数据进行分析和解读：\n\n{{data}}\n\n分析维度：\n1. 数据概况和关键指标\n2. 趋势和模式识别\n3. 异常值检测\n4. Actionable insights\n",
            variables: [
                PromptVariable(name: "data", placeholder: "粘贴需要分析的数据", isRequired: true)
            ],
            description: "分析数据并提供洞察",
            isBuiltIn: true
        ),
        PromptTemplate(
            name: "专业翻译",
            category: .translation,
            template: "请将以下文本从{{sourceLanguage}}翻译为{{targetLanguage}}：\n\n{{text}}\n\n要求：\n1. 保持原文的语气和风格\n2. 使用地道自然的表达\n3. 专业术语准确\n4. 如有歧义，提供备选翻译\n",
            variables: [
                PromptVariable(name: "sourceLanguage", placeholder: "源语言", isRequired: true),
                PromptVariable(name: "targetLanguage", placeholder: "目标语言", isRequired: true),
                PromptVariable(name: "text", placeholder: "需要翻译的文本", isRequired: true)
            ],
            description: "提供专业准确的翻译服务",
            isBuiltIn: true
        ),
        PromptTemplate(
            name: "头脑风暴",
            category: .creative,
            template: "请围绕以下主题进行头脑风暴：\n\n主题：{{topic}}\n\n背景信息：{{context}}\n\n请提供：\n1. 10个创意点子\n2. 每个点子的简要说明\n3. 可行性评估\n4. 潜在风险和应对策略\n",
            variables: [
                PromptVariable(name: "topic", placeholder: "头脑风暴主题", isRequired: true),
                PromptVariable(name: "context", placeholder: "相关背景信息（可选）", isRequired: false)
            ],
            description: "围绕主题进行创意头脑风暴",
            isBuiltIn: true
        )
    ]
}

// MARK: - 数据传输对象

struct PromptTemplateData: Codable {
    let id: UUID
    let name: String
    let categoryRawValue: String
    let template: String
    let variables: [PromptVariable]
    let description: String
    let isBuiltIn: Bool
    let createdAt: Date
    let updatedAt: Date

    init(from template: PromptTemplate) {
        self.id = template.id
        self.name = template.name
        self.categoryRawValue = template.category.rawValue
        self.template = template.template
        self.variables = template.variables
        self.description = template.templateDescription
        self.isBuiltIn = template.isBuiltIn
        self.createdAt = template.createdAt
        self.updatedAt = template.updatedAt
    }

    func toPromptTemplate() -> PromptTemplate {
        PromptTemplate(
            id: id,
            name: name,
            category: PromptCategory(rawValue: categoryRawValue) ?? .custom,
            template: template,
            variables: variables,
            description: description,
            isBuiltIn: isBuiltIn
        )
    }
}

// MARK: - Prompt Template Service

@MainActor
final class PromptTemplateService: ObservableObject {
    @Published var selectedCategory: PromptCategory?
    @Published var searchText: String = ""

    private var modelContext: ModelContext?

    init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var filteredTemplates: [PromptTemplate] {
        var results: [PromptTemplate]

        if let modelContext = modelContext {
            let descriptor = FetchDescriptor<PromptTemplate>()
            if let all = try? modelContext.fetch(descriptor) {
                results = all
            } else {
                results = []
            }
        } else {
            results = []
        }

        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.name.lowercased().contains(query) ||
                $0.templateDescription.lowercased().contains(query)
            }
        }

        return results.sorted { $0.name < $1.name }
    }

    func isFavorite(_ template: PromptTemplate) -> Bool {
        return false
    }

    func toggleFavorite(_ template: PromptTemplate) {}

    func apply(template: PromptTemplate, variables: [String: String]) -> String {
        var result = template.template
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }
}
