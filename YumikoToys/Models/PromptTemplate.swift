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
final class PromptTemplate: Identifiable, Hashable {
    @Attribute(.unique) let id: UUID
    let name: String
    let template: String
    let templateDescription: String
    let isBuiltIn: Bool
    let createdAt: Date
    let updatedAt: Date

    // 使用原始值存储枚举和复杂类型
    private var categoryRawValue: String
    private var variablesData: Data

    /// 分类（计算属性）
    var category: PromptCategory {
        get { PromptCategory(rawValue: categoryRawValue) ?? .custom }
        set { categoryRawValue = newValue.rawValue }
    }

    /// 变量列表（计算属性）
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

    // MARK: - 核心方法

    /// 应用变量到模板
    func apply(variables: [String: String]) -> String {
        var result = template
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    /// 验证变量是否完整
    func validate(variables: [String: String]) -> Bool {
        for variable in self.variables where variable.isRequired {
            if variables[variable.name]?.isEmpty ?? true {
                return false
            }
        }
        return true
    }

    /// 从模板中提取变量名
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

    // MARK: - Hashable

    static func == (lhs: PromptTemplate, rhs: PromptTemplate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - 内置模板

    static var builtInTemplates: [PromptTemplate] {
        [
            // 写作类
            PromptTemplate(
                name: "文章润色",
                category: .writing,
                template: """
请对以下文章进行润色和优化：

{{content}}

要求：
1. 改善语言表达，使其更加流畅自然
2. 修正语法和拼写错误
3. 保持原文的核心意思和风格
4. 适当优化段落结构
""",
                variables: [
                    PromptVariable(name: "content", placeholder: "粘贴需要润色的文章内容", isRequired: true)
                ],
                description: "对文章进行润色、优化和纠错",
                isBuiltIn: true
            ),

            // 编程类
            PromptTemplate(
                name: "代码审查",
                category: .coding,
                template: """
请对以下{{language}}代码进行审查：

```{{language}}
{{code}}
```

请从以下方面进行分析：
1. 代码质量和可读性
2. 潜在的错误或漏洞
3. 性能优化建议
4. 最佳实践建议
""",
                variables: [
                    PromptVariable(name: "language", placeholder: "编程语言，如 Swift、Python", isRequired: true),
                    PromptVariable(name: "code", placeholder: "粘贴需要审查的代码", isRequired: true)
                ],
                description: "审查代码质量并提供改进建议",
                isBuiltIn: true
            ),

            // 分析类
            PromptTemplate(
                name: "数据分析",
                category: .analysis,
                template: """
请对以下数据进行分析和解读：

{{data}}

分析维度：
1. 数据概况和关键指标
2. 趋势和模式识别
3. 异常值检测
4. Actionable insights
""",
                variables: [
                    PromptVariable(name: "data", placeholder: "粘贴需要分析的数据", isRequired: true)
                ],
                description: "分析数据并提供洞察",
                isBuiltIn: true
            ),

            // 翻译类
            PromptTemplate(
                name: "专业翻译",
                category: .translation,
                template: """
请将以下文本从{{sourceLanguage}}翻译为{{targetLanguage}}：

{{text}}

要求：
1. 保持原文的语气和风格
2. 使用地道自然的表达
3. 专业术语准确
4. 如有歧义，提供备选翻译
""",
                variables: [
                    PromptVariable(name: "sourceLanguage", placeholder: "源语言", isRequired: true),
                    PromptVariable(name: "targetLanguage", placeholder: "目标语言", isRequired: true),
                    PromptVariable(name: "text", placeholder: "需要翻译的文本", isRequired: true)
                ],
                description: "提供专业准确的翻译服务",
                isBuiltIn: true
            ),

            // 创意类
            PromptTemplate(
                name: "头脑风暴",
                category: .creative,
                template: """
请围绕以下主题进行头脑风暴：

主题：{{topic}}

背景信息：{{context}}

请提供：
1. 10个创意点子
2. 每个点子的简要说明
3. 可行性评估
4. 潜在风险和应对策略
""",
                variables: [
                    PromptVariable(name: "topic", placeholder: "头脑风暴主题", isRequired: true),
                    PromptVariable(name: "context", placeholder: "相关背景信息（可选）", isRequired: false)
                ],
                description: "围绕主题进行创意头脑风暴",
                isBuiltIn: true
            )
        ]
    }
}

// MARK: - 数据传输对象

/// 用于 Codable 持久化的数据结构
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
