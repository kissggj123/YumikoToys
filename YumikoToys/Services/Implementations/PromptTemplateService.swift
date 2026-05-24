import Foundation
import SwiftUI
import Combine
import OSLog

/// 提示词模板服务
/// 管理内置模板、自定义模板和收藏功能
@MainActor
final class PromptTemplateService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 内置模板列表
    @Published private(set) var builtInTemplates: [PromptTemplate] = []
    
    /// 自定义模板列表
    @Published private(set) var customTemplates: [PromptTemplate] = []
    
    /// 收藏的模板ID集合
    @Published private(set) var favorites: Set<UUID> = []
    
    /// 搜索文本
    @Published var searchText: String = ""
    
    /// 选中的分类筛选
    @Published var selectedCategory: PromptCategory?
    
    // MARK: - Computed Properties
    
    /// 所有模板（内置 + 自定义）
    var allTemplates: [PromptTemplate] {
        builtInTemplates + customTemplates
    }
    
    /// 根据搜索文本和分类筛选后的模板
    var filteredTemplates: [PromptTemplate] {
        var templates = allTemplates
        
        // 按分类筛选
        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }
        
        // 按搜索文本筛选
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            templates = templates.filter { template in
                template.name.lowercased().contains(lowercasedSearch) ||
                template.templateDescription.lowercased().contains(lowercasedSearch) ||
                template.template.lowercased().contains(lowercasedSearch)
            }
        }
        
        // 排序：收藏的在前，然后按名称排序
        return templates.sorted { first, second in
            let firstIsFavorite = favorites.contains(first.id)
            let secondIsFavorite = favorites.contains(second.id)
            
            if firstIsFavorite != secondIsFavorite {
                return firstIsFavorite
            }
            return first.name < second.name
        }
    }
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.yumikotoys", category: "PromptTemplateService")
    private let userDefaults = UserDefaults.standard
    
    private enum UserDefaultsKeys {
        static let customTemplates = "promptTemplateService.customTemplates"
        static let favorites = "promptTemplateService.favorites"
    }
    
    // MARK: - Initialization
    
    init() {
        loadBuiltInTemplates()
        loadFromUserDefaults()
    }
    
    // MARK: - Public Methods
    
    /// 根据分类获取模板
    /// - Parameter category: 模板分类
    /// - Returns: 该分类下的所有模板
    func getTemplates(by category: PromptCategory) -> [PromptTemplate] {
        allTemplates.filter { $0.category == category }
    }
    
    /// 应用模板变量，生成最终提示词
    /// - Parameters:
    ///   - template: 要应用的模板
    ///   - variables: 变量名到变量值的映射
    /// - Returns: 替换变量后的最终提示词
    func apply(template: PromptTemplate, variables: [String: String]) -> String {
        template.apply(variables: variables)
    }
    
    /// 保存自定义模板
    /// - Parameter template: 要保存的模板
    func saveCustomTemplate(_ template: PromptTemplate) {
        // 确保不是内置模板
        guard !template.isBuiltIn else {
            logger.warning("Cannot save built-in template as custom: \(template.name)")
            return
        }
        
        // 检查是否已存在
        if let index = customTemplates.firstIndex(where: { $0.id == template.id }) {
            customTemplates[index] = template
            logger.info("Updated custom template: \(template.name)")
        } else {
            customTemplates.append(template)
            logger.info("Added new custom template: \(template.name)")
        }
        
        saveToUserDefaults()
    }
    
    /// 删除自定义模板
    /// - Parameter template: 要删除的模板
    func deleteCustomTemplate(_ template: PromptTemplate) {
        // 确保不是内置模板
        guard !template.isBuiltIn else {
            logger.warning("Cannot delete built-in template: \(template.name)")
            return
        }
        
        customTemplates.removeAll { $0.id == template.id }
        
        // 同时从收藏中移除
        favorites.remove(template.id)
        
        logger.info("Deleted custom template: \(template.name)")
        saveToUserDefaults()
    }
    
    /// 切换模板的收藏状态
    /// - Parameter template: 要切换收藏的模板
    func toggleFavorite(_ template: PromptTemplate) {
        if favorites.contains(template.id) {
            favorites.remove(template.id)
            logger.info("Removed template from favorites: \(template.name)")
        } else {
            favorites.insert(template.id)
            logger.info("Added template to favorites: \(template.name)")
        }
        saveToUserDefaults()
    }
    
    /// 检查模板是否已收藏
    /// - Parameter template: 要检查的模板
    /// - Returns: 是否已收藏
    func isFavorite(_ template: PromptTemplate) -> Bool {
        favorites.contains(template.id)
    }
    
    /// 获取收藏的模板列表
    /// - Returns: 所有收藏的模板
    func getFavoriteTemplates() -> [PromptTemplate] {
        allTemplates.filter { favorites.contains($0.id) }
    }
    
    /// 根据ID查找模板
    /// - Parameter id: 模板ID
    /// - Returns: 找到的模板，如果不存在则返回nil
    func findTemplate(by id: UUID) -> PromptTemplate? {
        allTemplates.first { $0.id == id }
    }
    
    /// 重置为默认状态（删除所有自定义模板和收藏）
    func resetToDefaults() {
        customTemplates.removeAll()
        favorites.removeAll()
        searchText = ""
        selectedCategory = nil
        
        logger.info("Reset prompt templates to defaults")
        saveToUserDefaults()
    }
    
    // MARK: - Private Methods
    
    /// 加载内置模板
    private func loadBuiltInTemplates() {
        self.builtInTemplates = Self.createDefaultTemplates()
        logger.info("Loaded \(self.builtInTemplates.count) built-in templates")
    }
    
    /// 从 UserDefaults 加载数据
    private func loadFromUserDefaults() {
        // 加载自定义模板
        if let data = userDefaults.data(forKey: UserDefaultsKeys.customTemplates) {
            do {
                let decoder = JSONDecoder()
                let templates = try decoder.decode([PromptTemplateData].self, from: data)
                self.customTemplates = templates.map { $0.toPromptTemplate() }
                logger.info("Loaded \(self.customTemplates.count) custom templates from UserDefaults")
            } catch {
                logger.error("Failed to load custom templates: \(error.localizedDescription)")
            }
        }
        
        // 加载收藏
        if let data = userDefaults.data(forKey: UserDefaultsKeys.favorites) {
            do {
                let decoder = JSONDecoder()
                let favoriteIDs = try decoder.decode([UUID].self, from: data)
                self.favorites = Set(favoriteIDs)
                logger.info("Loaded \(self.favorites.count) favorites from UserDefaults")
            } catch {
                logger.error("Failed to load favorites: \(error.localizedDescription)")
            }
        }
    }
    
    /// 保存到 UserDefaults
    private func saveToUserDefaults() {
        do {
            let encoder = JSONEncoder()
            
            // 保存自定义模板
            let templateData = customTemplates.map { PromptTemplateData(from: $0) }
            let templatesEncoded = try encoder.encode(templateData)
            userDefaults.set(templatesEncoded, forKey: UserDefaultsKeys.customTemplates)
            
            // 保存收藏
            let favoritesEncoded = try encoder.encode(Array(favorites))
            userDefaults.set(favoritesEncoded, forKey: UserDefaultsKeys.favorites)
            
            logger.debug("Saved prompt template data to UserDefaults")
        } catch {
            logger.error("Failed to save prompt template data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Default Templates
    
    /// 创建默认模板集合
    private static func createDefaultTemplates() -> [PromptTemplate] {
        [
            // MARK: 写作类
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
            
            PromptTemplate(
                name: "文章摘要",
                category: .writing,
                template: """
请为以下文章生成摘要：

{{content}}

要求：
1. 摘要长度控制在 {{length}} 字以内
2. 涵盖文章的核心观点和关键信息
3. 语言简洁明了
4. 保持客观中立
""",
                variables: [
                    PromptVariable(name: "content", placeholder: "粘贴需要摘要的文章内容", isRequired: true),
                    PromptVariable(name: "length", placeholder: "200", isRequired: false)
                ],
                description: "为长文章生成简洁的摘要",
                isBuiltIn: true
            ),
            
            // MARK: 编程类
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
            
            PromptTemplate(
                name: "代码解释",
                category: .coding,
                template: """
请解释以下{{language}}代码的工作原理：

```{{language}}
{{code}}
```

请包含：
1. 代码的整体功能概述
2. 关键部分的详细解释
3. 使用的算法或设计模式
4. 执行流程分析
""",
                variables: [
                    PromptVariable(name: "language", placeholder: "编程语言", isRequired: true),
                    PromptVariable(name: "code", placeholder: "粘贴需要解释的代码", isRequired: true)
                ],
                description: "详细解释代码的工作原理",
                isBuiltIn: true
            ),
            
            PromptTemplate(
                name: "代码重构",
                category: .coding,
                template: """
请对以下{{language}}代码进行重构优化：

```{{language}}
{{code}}
```

重构目标：
1. 提高代码可读性和可维护性
2. 消除重复代码
3. 优化性能瓶颈
4. 遵循{{language}}最佳实践
5. 添加适当的注释和文档

请提供重构后的完整代码，并说明主要改进点。
""",
                variables: [
                    PromptVariable(name: "language", placeholder: "编程语言", isRequired: true),
                    PromptVariable(name: "code", placeholder: "粘贴需要重构的代码", isRequired: true)
                ],
                description: "重构代码以提高质量和性能",
                isBuiltIn: true
            ),
            
            // MARK: 分析类
            PromptTemplate(
                name: "SWOT 分析",
                category: .analysis,
                template: """
请对以下主题进行 SWOT 分析：

主题：{{subject}}

背景信息：
{{context}}

请从以下四个维度进行分析：

**优势 (Strengths)**
- 内部积极因素

**劣势 (Weaknesses)**
- 内部消极因素

**机会 (Opportunities)**
- 外部积极因素

**威胁 (Threats)**
- 外部消极因素

最后请提供基于分析的战略建议。
""",
                variables: [
                    PromptVariable(name: "subject", placeholder: "分析主题", isRequired: true),
                    PromptVariable(name: "context", placeholder: "相关背景信息", isRequired: false)
                ],
                description: "对主题进行全面的 SWOT 分析",
                isBuiltIn: true
            ),
            
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
4. 数据间的关联性分析
5. 可执行的洞察和建议

请使用清晰的数据可视化描述来呈现分析结果。
""",
                variables: [
                    PromptVariable(name: "data", placeholder: "粘贴需要分析的数据", isRequired: true)
                ],
                description: "分析数据并提供深度洞察",
                isBuiltIn: true
            ),
            
            // MARK: 翻译类
            PromptTemplate(
                name: "中英互译",
                category: .translation,
                template: """
请将以下文本翻译为{{targetLanguage}}：

{{text}}

要求：
1. 保持原文的语气和风格
2. 使用地道自然的表达
3. 专业术语准确
4. 如有歧义，提供备选翻译
5. 对文化特定内容提供注释
""",
                variables: [
                    PromptVariable(name: "targetLanguage", placeholder: "目标语言（中文/英文）", isRequired: true),
                    PromptVariable(name: "text", placeholder: "需要翻译的文本", isRequired: true)
                ],
                description: "提供专业的中英互译服务",
                isBuiltIn: true
            ),
            
            PromptTemplate(
                name: "英中翻译",
                category: .translation,
                template: """
请将以下英文文本翻译为中文：

{{text}}

翻译要求：
1. 准确传达原文意思
2. 符合中文表达习惯
3. 专业术语使用行业标准译法
4. 保持原文的语气和风格
5. 长句适当拆分，提高可读性
""",
                variables: [
                    PromptVariable(name: "text", placeholder: "需要翻译的英文文本", isRequired: true)
                ],
                description: "将英文内容翻译为流畅的中文",
                isBuiltIn: true
            ),
            
            // MARK: 创意类
            PromptTemplate(
                name: "头脑风暴",
                category: .creative,
                template: """
请围绕以下主题进行头脑风暴：

主题：{{topic}}

背景信息：{{context}}

目标：{{goal}}

请提供：
1. 10个创意点子
2. 每个点子的简要说明
3. 可行性评估（高/中/低）
4. 实施难度预估
5. 潜在风险和应对策略
""",
                variables: [
                    PromptVariable(name: "topic", placeholder: "头脑风暴主题", isRequired: true),
                    PromptVariable(name: "context", placeholder: "相关背景信息", isRequired: false),
                    PromptVariable(name: "goal", placeholder: "期望达成的目标", isRequired: false)
                ],
                description: "围绕主题进行创意头脑风暴",
                isBuiltIn: true
            ),
            
            PromptTemplate(
                name: "故事创作",
                category: .creative,
                template: """
请根据以下要素创作一个故事：

主题：{{theme}}
类型：{{genre}}
主角：{{protagonist}}
背景设定：{{setting}}

要求：
1. 故事结构完整（开端、发展、高潮、结局）
2. 人物形象鲜明
3. 情节引人入胜
4. 字数控制在{{wordCount}}字左右
5. 语言风格符合{{genre}}类型特点
""",
                variables: [
                    PromptVariable(name: "theme", placeholder: "故事主题", isRequired: true),
                    PromptVariable(name: "genre", placeholder: "故事类型（如科幻、悬疑、爱情）", isRequired: true),
                    PromptVariable(name: "protagonist", placeholder: "主角描述", isRequired: true),
                    PromptVariable(name: "setting", placeholder: "故事背景", isRequired: true),
                    PromptVariable(name: "wordCount", placeholder: "1000", isRequired: false)
                ],
                description: "根据要素创作原创故事",
                isBuiltIn: true
            )
        ]
    }
}
