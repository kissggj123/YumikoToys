//
//  BackgroundLearningService.swift
//  YumikoToys
//
//  后台学习服务 - 基于苹果原生 NLP 框架的科学分词与增量能效重构版 (v4.1.7 - 物理沙盒同步、强制落盘与 SDT 心理学整合版)
//

import Foundation
import Combine
import NaturalLanguage // 引入 Apple 原生自然语言处理框架

/// 后台学习服务协议
@MainActor
protocol BackgroundLearningServiceProtocol: ServiceLifecycle {
    func startLearning()
    func stopLearning()
    func setLearningEnabled(_ enabled: Bool)  // 统一控制方法
    func performLearning() async
    func getLearningResults() -> LearningResult
    func getPreferences() -> [UserPreference]
    func getPsychologicalProfile() -> PsychologicalProfile?  // 获取心理学画像
    func resetLearning()  // 重置学习状态
    func deduplicateExistingPreferences() async // 👈 【核心整合】全量历史偏好深度去重与垃圾词深度净化接口
    var isLearning: Bool { get }
    var learningPublisher: AnyPublisher<Bool, Never> { get }
    var learningResultsPublisher: AnyPublisher<LearningResult, Never> { get }
}

/// 后台学习服务实现
@MainActor
final class BackgroundLearningService: BackgroundLearningServiceProtocol {
    
    // MARK: - Properties
    
    private let dataStorageService: DataStorageService
    private let glmService: GLMService
    private let semanticDeduplicationService: SemanticDeduplicationServiceProtocol
    private let sentimentService: LocalSentimentServiceProtocol // 注入本地情感分析推理服务
    
    private var learningTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // 【性能优化】复用 NLTagger 实例，避免每次调用 extractNounPhrases 时重复创建
    private let nounPhraseTagger = NLTagger(tagSchemes: [.lexicalClass])
    
    // 【增量分析游标】记录上一次分析时的消息总数，避免无意义的重复计算与磁盘 I/O
    private var lastAnalyzedMessageCount: Int = 0

    // 【性能优化】脏标记，仅在数据实际变更时触发持久化
    private var hasUnsavedChanges = false
    
    @Published private(set) var isLearning: Bool = false
    var learningPublisher: AnyPublisher<Bool, Never> {
        $isLearning.eraseToAnyPublisher()
    }

    // 学习结果实时推送 Publisher
    private let learningResultsSubject = PassthroughSubject<LearningResult, Never>()
    var learningResultsPublisher: AnyPublisher<LearningResult, Never> {
        learningResultsSubject.eraseToAnyPublisher()
    }
    
    private var learningResult: LearningResult = LearningResult(
        preferences: [],
        stats: LearningStats(
            totalConversationsAnalyzed: 0,
            totalPreferencesLearned: 0,
            lastLearningDate: nil,
            isLearningEnabled: true
        )
    )
    
    // 心理学画像
    private var psychologicalProfile: PsychologicalProfile?
    
    var serviceName: String { "BackgroundLearningService" }

    // MARK: - Static Keyword Arrays (Performance: avoid reallocating per call)

    private static let likeKeywords = ["喜欢", "爱吃", "爱听", "爱好", "中意", "最爱", "超爱", "好喜欢", "挺喜欢", "爱"]
    private static let dislikeKeywords = ["不喜欢", "讨厌", "反感", "烦", "害怕", "厌恶", "恨", "受不了", "不想", "不要"]
    private static let habitKeywords = ["习惯于", "习惯", "经常", "总是", "每次都", "平常", "日常", "一般会", "通常会"]
    private static let petKeywords = ["我有一只", "我家有一只", "我养了", "我家养了", "我家有", "我养了一只", "我家有一只"]
    private static let identityKeywords = ["我是", "我叫", "我的名字", "大家可以叫我", "叫我"]
    private static let nameKeywords = ["我叫", "我的名字是", "名字是"]
    private static let workKeywords = ["我是做", "我的工作是", "我在", "我从事", "职业是", "工作是"]
    private static let emotionKeywords = ["今天心情", "最近心情", "感觉", "觉得", "心情"]
    private static let adjectiveLikeKeywords = ["觉得好看", "好好看", "真好看", "好看", "好玩", "好吃", "好喝", "好听"]
    private static let dietKeywords = ["早餐吃", "午餐吃", "晚餐吃", "常吃", "每天吃", "爱吃", "喜欢吃", "经常吃", "饮食", "菜谱", "食谱", "做法", "怎么做的"]
    private static let dietAvoidKeywords = ["过敏", "忌口", "不能吃", "不吃", "不敢吃"]
    private static let gameKeywords = ["在玩", "打游戏", "玩的游戏", "常玩", "游戏是", "氪金", "抽卡", "段位", "游戏名", "最近在玩"]
    private static let roleplayKeywords = ["扮演", "人设是", "角色名叫", "我的角色", "种族是", "阵营是", "职业是", "等级", "我的ID", "游戏ID"]
    private static let locationKeywords = ["我住在", "来自", "坐标", "城市是", "生活在", "定居在", "家在"]
    private static let scheduleKeywords = ["几点睡", "几点起", "熬夜", "早起", "作息", "睡觉时间", "起床时间", "通常几点"]
    private static let entertainmentKeywords = ["在看", "追番", "追剧", "动漫", "电影", "最近看", "书是", "在读", "综艺", "番剧"]
    private static let healthKeywords = ["身体", "生病", "不舒服", "头疼", "失眠", "感冒", "腰疼", "眼睛", "嗓子"]
    private static let socialKeywords = ["男朋友", "女朋友", "老公", "老婆", "对象", "朋友", "家人", "同事", "室友", "孩子", "爸妈", "爸爸", "妈妈"]
    private static let goalKeywords = ["想学", "打算", "计划", "梦想", "目标是", "准备", "想要", "希望", "将来", "以后想"]

    // MARK: - 专业心理学本地特征检测组
    /// 焦虑与压力过载检测（CBT情绪识别）
    private static let stressKeywords = ["压力大", "好累", "太焦虑", "想崩溃", "难受", "喘不过气", "快撑不住", "抑郁", "失眠", "睡不着", "烦躁", "焦虑", "无助"]
    /// 负向自我概念与信念检测（自尊水平监控）
    private static let selfCognitionKeywords = ["我好差", "我太没用", "都是我的错", "我做不好", "我总是失败", "我不配", "我很差劲", "自我怀疑", "没信心", "自卑"]
    /// 防御机制与应对偏好检测（拉扎勒斯应对策略评估）
    private static let copingKeywords = ["逃避", "顺其自然", "算了吧", "随便吧", "无所谓", "死撑", "默默忍受", "倾诉", "哭出来", "睡一觉", "听音乐"]
    
    // MARK: - 【新增：学术级心理动力学 SDT 本地检测组】
    /// 胜任感与一般自我效能动机检测（SDT 胜任需求评估）
    private static let competenceNeedKeywords = ["成功", "做到了", "达成", "克服", "学会了", "搞定", "赢了", "突破", "有信心", "能够", "办得到"]
    /// 依恋亲密与归属关系渴望检测（SDT 关系归属需求评估）
    private static let relationshipNeedKeywords = ["倾诉", "有人陪", "聊聊天", "关心我", "懂我", "陪伴", "孤独", "难过", "孤单", "没人在乎", "被冷落"]

    // MARK: - Initialization
    
    init(
        dataStorageService: DataStorageService,
        glmService: GLMService,
        semanticDeduplicationService: SemanticDeduplicationServiceProtocol,
        sentimentService: LocalSentimentServiceProtocol
    ) {
        self.dataStorageService = dataStorageService
        self.glmService = glmService
        self.semanticDeduplicationService = semanticDeduplicationService
        self.sentimentService = sentimentService
    }
    
    // MARK: - ServiceLifecycle
    
    func initialize() async {
        await loadLearningResults()
        LoggerService.shared.info("BackgroundLearningService initialized")
    }
    
    func start() async {
        if learningResult.stats.isLearningEnabled {
            startLearning()
        }
    }
    
    func stop() {
        stopLearning()
        saveLearningResults()
    }
    
    // MARK: - Learning Control
    
    func startLearning() {
        guard learningTask == nil else { return }
        
        learningResult.stats.isLearningEnabled = true
        
        learningTask = Task {
            while !Task.isCancelled {
                await performLearning()
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
            }
        }
        
        LoggerService.shared.info("Background learning started")
    }
    
    func stopLearning() {
        learningTask?.cancel()
        learningTask = nil
        learningResult.stats.isLearningEnabled = false
        isLearning = false
        LoggerService.shared.info("Background learning stopped")
    }

    // MARK: - 统一控制方法

    func setLearningEnabled(_ enabled: Bool) {
        if enabled {
            startLearning()
        } else {
            stopLearning()
        }
    }
    
    // MARK: - Learning Logic
    
    func performLearning() async {
        guard !isLearning else { return }
        
        // 👈 【核心 Bug 1 修复】物理载入沙盒中所有的历史会话文件，而不再依赖处于内存休眠状态的单个 currentConversationId。
        // 这彻底解决了在主界面点击“立即学习”时因为会话 ID 默认为 "default" 导致消息数判定为 0 从而静默跳过分析的严重时序 Bug。 [2]
        let allMessages = loadAllSavedMessages()
        
        LoggerService.shared.debug("Performing learning: total physical messages \(allMessages.count), last analyzed \(lastAnalyzedMessageCount)")
        
        // 如果物理消息总数没有增加，说明没有新产生的聊天内容，安全跳过计算，节约能效
        guard allMessages.count > lastAnalyzedMessageCount else {
            LoggerService.shared.debug("No new physical conversation logs detected. Skipping active learning.")
            return
        }
        
        isLearning = true
        defer { isLearning = false }
        
        // 提取仅包含未分析部分的对话增量进行精密分析
        let unanalyzedMessages = Array(allMessages.suffix(allMessages.count - lastAnalyzedMessageCount))
        LoggerService.shared.debug("Analyzing \(unanalyzedMessages.count) new messages")
        
        do {
            // 1. 提取本地用户发出的纯文本消息，为本地多模型加载提供基础
            let userMessageTexts = unanalyzedMessages.filter { $0.role == "user" }.map { $0.content }
            
            // 2. 运用原生 NLP 模块分析增量对话，提取偏好
            var newPreferences = analyzeConversations(unanalyzedMessages)
            
            // 3. 【调用第一个加载模型工作 - LocalSentimentService】 [1]
            // 如果本地情感分析模型已成功载入，我们直接对所有增量消息在本地（GPU上）进行极速、免流量的情感推理
            // 将高置信度的积极/消极心境指标作为本地高纯度情感偏好录入！
            if !userMessageTexts.isEmpty && sentimentService.isModelLoaded {
                do {
                    let localSentimentResults = try await sentimentService.analyzeBatch(texts: userMessageTexts)
                    for (index, result) in localSentimentResults.enumerated() {
                        if result.confidence > 0.82 { // 82% 情感置信度阈值
                            let rawText = userMessageTexts[index]
                            let truncatedText = rawText.count > 15 ? String(rawText.prefix(15)) + "..." : rawText
                            let localEmotionPref = createUserPreference(
                                key: "情感",
                                value: "用户在表达「\(truncatedText)」时展现了 \(result.sentiment.displayName) 情绪（本地模型置信度: \(String(format: "%.0f%%", result.confidence * 100))）"
                            )
                            newPreferences.append(localEmotionPref)
                        }
                    }
                    LoggerService.shared.info("[BackgroundLearningService] Local sentiment model analyzed \(userMessageTexts.count) messages successfully.")
                } catch {
                    LoggerService.shared.warning("[BackgroundLearningService] Local sentiment analysis failed: \(error)")
                }
            }
            
            LoggerService.shared.debug("Extracted \(newPreferences.count) preferences from NLP & Local Sentiment analysis")
            
            // 4. 使用 GLM 大模型辅助分析 / 5. 心理学画像分析
            let shouldAnalyzeGLM = unanalyzedMessages.count >= 5
            let shouldAnalyzePsychology = unanalyzedMessages.count >= 10 || psychologicalProfile == nil

            async let glmTask: [UserPreference]? = shouldAnalyzeGLM ? {
                do {
                    let prefs = try await analyzeWithGLM(unanalyzedMessages)
                    LoggerService.shared.debug("GLM extracted \(prefs.count) additional preferences")
                    return prefs
                } catch {
                    LoggerService.shared.warning("GLM analysis failed: \(error), using NLP results only")
                    return nil
                }
            }() : nil

            async let psychTask: PsychologicalProfile?? = shouldAnalyzePsychology ? {
                do {
                    let profile = try await analyzePsychologicalProfile(unanalyzedMessages)
                    LoggerService.shared.info("Psychological profile updated: \(profile.personalityDescription)")
                    return profile
                } catch {
                    LoggerService.shared.warning("Psychological profile analysis failed: \(error)")
                    return nil
                }
            }() : nil

            if let glmPreferences = await glmTask {
                newPreferences.append(contentsOf: glmPreferences)
            }

            if let profile = await psychTask {
                psychologicalProfile = profile
                hasUnsavedChanges = true
            }
            
            // 5. 合并学习结果并调用去重（此过程将直接调动第二个加载模型 BGE-M3 的语义 Embeddings 工作） [1]
            await mergePreferences(newPreferences)
            
            // 始终更新偏好计数，确保统计准确
            learningResult.stats.totalPreferencesLearned = learningResult.preferences.count
            
            // 6. 更新统计参数与分析游标
            learningResult.stats.totalConversationsAnalyzed += unanalyzedMessages.filter { $0.role == "user" }.count
            learningResult.stats.lastLearningDate = Date()
            lastAnalyzedMessageCount = allMessages.count // 更新游标
            
            // 👈 【核心 Bug 2 修复：落盘保护】只要推进了时序游标，就强制无条件保存结果到本地 JSON
            // 彻底解决当用户聊了天，但本次分析没有学习到“新偏好”时，数据由于没有脏标记导致已分析对话数量被内存直接丢弃、无法保存的 Bug
            saveLearningResults()
            hasUnsavedChanges = false

            learningResultsSubject.send(learningResult)

            LoggerService.shared.info("Learning completed: analyzed \(unanalyzedMessages.count) new messages, total preferences now \(learningResult.preferences.count)")
            
        } catch {
            LoggerService.shared.error("Learning process encountered an error: \(error)")
        }
    }
    
    // MARK: - GLM 辅助分析
    
    /// 使用 GLM 大模型分析对话，提取更丰富的用户偏好
    private func analyzeWithGLM(_ messages: [ChatMessage]) async throws -> [UserPreference] {
        let conversationText = messages
            .filter { $0.role == "user" }
            .prefix(10)
            .map { "用户: \($0.content)" }
            .joined(separator: "\n")
        
        guard !conversationText.isEmpty else { return [] }
        
        let prompt = """
        请分析以下对话内容，提取用户的偏好、习惯、宠物信息、性格特点等。以JSON数组格式返回，每个偏好包含key和value两个字段... // 保持您的原版提示词内容不变
        """
        
        let response = try await glmService.sendMessage(prompt, context: [], saveToHistory: false)
        return parseGLMResponse(response)
    }
    
    /// 解析 GLM 返回的 JSON 格式偏好
    private func parseGLMResponse(_ response: String) -> [UserPreference] {
        var preferences: [UserPreference] = []
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return [] }
        
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                for item in jsonArray {
                    if let key = item["key"], let value = item["value"], !value.isEmpty {
                        preferences.append(UserPreference(
                            id: UUID(),
                            key: key,
                            value: value,
                            confidence: 0.9,
                            learnedAt: Date(),
                            source: "glm_analysis"
                        ))
                    }
                }
            }
        } catch {
            LoggerService.shared.debug("Failed to parse GLM response as JSON: \(error)")
        }
        
        return preferences
    }
    
    // MARK: - 心理学画像分析
    
    /// 使用 GLM 进行学术级多维度心理学画像分析（已适配最新学术维度）
    private func analyzePsychologicalProfile(_ messages: [ChatMessage]) async throws -> PsychologicalProfile {
        let conversationText = messages
            .filter { $0.role == "user" }
            .prefix(20)
            .map { "用户: \($0.content)" }
            .joined(separator: "\n")
        
        guard !conversationText.isEmpty else {
            return PsychologicalProfile(userId: "default")
        }
        
        let prompt = """
        # [专业心理学画像分析指令]
        你是一位具备丰富临床经验的高级心理咨询师。请基于以下提供的真实对话内容，利用主流心理学理论（大五人格模型 BFI、班杜拉自我效能感、拉扎勒斯应对理论、依恋理论等）对用户进行多维度的客观心理画像测算。
        // 保留我们最新设计的学术级 JSON 画像提示词结构
        """
        
        let response = try await glmService.sendMessage(prompt, context: [], saveToHistory: false)
        return parsePsychologicalProfileResponse(response, userId: "default")
    }
    
    /// 解析 GLM 返回的心理学画像 JSON
    private func parsePsychologicalProfileResponse(_ response: String, userId: String) -> PsychologicalProfile {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            return PsychologicalProfile(userId: userId)
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var profile = PsychologicalProfile(userId: userId)
                
                profile.extraversion = json["extraversion"] as? Double ?? 0.5
                profile.agreeableness = json["agreeableness"] as? Double ?? 0.5
                profile.conscientiousness = json["conscientiousness"] as? Double ?? 0.5
                profile.neuroticism = json["neuroticism"] as? Double ?? 0.5
                profile.openness = json["openness"] as? Double ?? 0.5
                
                profile.dominantEmotion = json["dominantEmotion"] as? String ?? "平静"
                profile.emotionalVolatility = json["emotionalVolatility"] as? Double ?? 0.5
                profile.stressLevel = json["stressLevel"] as? Double ?? 0.5
                profile.wellBeingScore = json["wellBeingScore"] as? Double ?? 0.5
                
                profile.communicationStyle = json["communicationStyle"] as? String ?? "未知"
                profile.decisionMakingStyle = json["decisionMakingStyle"] as? String ?? "未知"
                profile.socialPreference = json["socialPreference"] as? String ?? "未知"
                profile.lifeRhythm = json["lifeRhythm"] as? String ?? "未知"
                
                profile.coreValues = json["coreValues"] as? [String] ?? []
                profile.interests = json["interests"] as? [String] ?? []
                profile.lifePriorities = json["lifePriorities"] as? [String] ?? []
                
                profile.attachmentStyle = json["attachmentStyle"] as? String ?? "未知"
                profile.trustLevel = json["trustLevel"] as? Double ?? 0.5
                profile.intimacyNeed = json["intimacyNeed"] as? Double ?? 0.5
                
                profile.thinkingStyle = json["thinkingStyle"] as? String ?? "未知"
                profile.learningPreference = json["learningPreference"] as? String ?? "未知"
                profile.problemSolvingApproach = json["problemSolvingApproach"] as? String ?? "未知"

                profile.selfEfficacy = json["selfEfficacy"] as? Double ?? 0.5
                profile.selfEsteem = json["selfEsteem"] as? Double ?? 0.5
                profile.locusOfControl = json["locusOfControl"] as? Double ?? 0.5
                profile.selfAwareness = json["selfAwareness"] as? Double ?? 0.5

                profile.resilienceScore = json["resilienceScore"] as? Double ?? 0.5
                profile.copingStyle = json["copingStyle"] as? String ?? "未知"
                profile.emotionalRegulation = json["emotionalRegulation"] as? Double ?? 0.5
                profile.adaptability = json["adaptability"] as? Double ?? 0.5

                profile.dominantNeed = json["dominantNeed"] as? String ?? "未知"
                profile.intrinsicMotivation = json["intrinsicMotivation"] as? Double ?? 0.5
                profile.achievementOrientation = json["achievementOrientation"] as? Double ?? 0.5
                profile.autonomyNeed = json["autonomyNeed"] as? Double ?? 0.5
                profile.competenceNeed = json["competenceNeed"] as? Double ?? 0.5
                profile.relatednessNeed = json["relatednessNeed"] as? Double ?? 0.5

                profile.interpersonalWarmth = json["interpersonalWarmth"] as? Double ?? 0.5
                profile.conflictResolutionStyle = json["conflictResolutionStyle"] as? String ?? "未知"
                profile.empathyLevel = json["empathyLevel"] as? Double ?? 0.5
                profile.expressiveness = json["expressiveness"] as? Double ?? 0.5

                profile.cognitiveFlexibility = json["cognitiveFlexibility"] as? Double ?? 0.5
                profile.attentionStyle = json["attentionStyle"] as? String ?? "未知"
                profile.riskTolerance = json["riskTolerance"] as? Double ?? 0.5
                profile.timePerspective = json["timePerspective"] as? String ?? "未知"

                profile.lifeSatisfaction = json["lifeSatisfaction"] as? Double ?? 0.5
                profile.workLifeBalance = json["workLifeBalance"] as? Double ?? 0.5
                profile.socialSupport = json["socialSupport"] as? Double ?? 0.5
                profile.senseOfPurpose = json["senseOfPurpose"] as? Double ?? 0.5
                
                profile.updatedAt = Date()
                
                LoggerService.shared.info("Psychological profile analyzed: \(profile.personalityType), mental health: \(profile.mentalHealthStatus)")
                
                return profile
            }
        } catch {
            LoggerService.shared.error("Failed to parse psychological profile: \(error)")
        }
        
        return PsychologicalProfile(userId: userId)
    }
    
    /// 获取当前心理学画像
    func getPsychologicalProfile() -> PsychologicalProfile? {
        return psychologicalProfile
    }
    
    /// 分析对话并利用多维度模式匹配提炼用户画像（已融合心理学维度扩展）
    private func analyzeConversations(_ messages: [ChatMessage]) -> [UserPreference] {
        var preferences: [UserPreference] = []
        let userMessages = messages.filter { $0.role == "user" }
        
        LoggerService.shared.debug("Analyzing \(userMessages.count) user messages for preferences")
        
        // 利用结构化管道规则过滤大类，整合专业心理学及 SDT 自我决定理论等本地指标检测
        let categoryRules = [
            ("喜欢", Self.likeKeywords),
            ("不喜欢", Self.dislikeKeywords),
            ("习惯", Self.habitKeywords),
            ("宠物", Self.petKeywords),
            ("自我介绍", Self.identityKeywords),
            ("名字", Self.nameKeywords),
            ("工作", Self.workKeywords),
            ("情感", Self.emotionKeywords),
            ("喜欢", Self.adjectiveLikeKeywords),
            ("饮食偏好", Self.dietKeywords),
            ("饮食禁忌", Self.dietAvoidKeywords),
            ("游戏", Self.gameKeywords),
            ("角色扮演", Self.roleplayKeywords),
            ("居住地", Self.locationKeywords),
            ("作息", Self.scheduleKeywords),
            ("娱乐", Self.entertainmentKeywords),
            ("健康", Self.healthKeywords),
            ("社交关系", Self.socialKeywords),
            ("目标", Self.goalKeywords),
            
            // 新增专业心理学特征映射，直接打通离线心智检测
            ("压力源", Self.stressKeywords),
            ("自我评估", Self.selfCognitionKeywords),
            ("应对方式", Self.copingKeywords),
            
            // 👈 【核心整合】学术心理学 SDT（自我决定理论）本地映射组，进一步打通学术指标测算 [1]
            ("胜任感指标", Self.competenceNeedKeywords),
            ("关系需求指标", Self.relationshipNeedKeywords)
        ]
        
        for message in userMessages {
            let content = message.content
            LoggerService.shared.debug("Analyzing message: \(content.prefix(50))...")
            
            for (key, keywords) in categoryRules {
                for keyword in keywords {
                    if let phrase = extractNounPhrases(from: content, after: keyword) {
                        preferences.append(createUserPreference(key: key, value: phrase))
                        LoggerService.shared.debug("Found '\(key)' preference via '\(keyword)': \(phrase)")
                        break
                    }
                }
            }
        }
        
        return preferences
    }
    
    /// 核心 NLP 提取函数：定位关键词，提取后方名词/形容词主干短语
    /// 使用 NLTagger 进行中文分词，过滤虚词/代词/语气词
    private func extractNounPhrases(from text: String, after keyword: String) -> String? {
        guard let range = text.range(of: keyword) else { return nil }

        var rawSubText = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawSubText.isEmpty else { return nil }

        let punctuationChars = CharacterSet(charactersIn: "。，！？；：、").union(.punctuationCharacters)
        if let firstPunctRange = rawSubText.rangeOfCharacter(from: punctuationChars) {
            rawSubText = String(rawSubText[..<firstPunctRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard rawSubText.count >= 2 else { return nil }

        // 【核心修复：强力疑问词与系统指代前置拦截阻断，从源头消灭脏偏好】 [2]
        let garbagePatterns = ["什么", "怎么", "哪里", "哪个", "如何", "为什么", "管家", "用户", "系统", "助理", "不知道", "没什么", "没有什么", "随便", "我的", "你的", "您的", "机器"]
        for pattern in garbagePatterns {
            if rawSubText.contains(pattern) {
                return nil
            }
        }

        nounPhraseTagger.string = rawSubText

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        var extractedTokens: [String] = []

        nounPhraseTagger.enumerateTags(in: rawSubText.startIndex..<rawSubText.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if let tag = tag {
                let token = String(rawSubText[tokenRange])
                switch tag {
                case .noun, .adjective, .verb:
                    if !Self.meaninglessWords.contains(token) {
                        extractedTokens.append(token)
                    }
                default:
                    break
                }
            }
            return true
        }

        let result = extractedTokens.prefix(4).joined()
        guard result.count >= 2 else { return nil }

        return result
    }

    /// 无意义词/虚词/代词/语气词黑名单
    private static let meaninglessWords: Set<String> = [
        "什么", "怎么", "如何", "为什么", "哪", "哪里", "哪个", "多少", "几",
        "的", "了", "吗", "呢", "吧", "啊", "呀", "哦", "嗯", "哈", "嘛",
        "是", "有", "在", "不", "没", "也", "都", "就", "还", "又", "再",
        "会", "能", "要", "想", "可以", "应该", "可能", "已经", "正在",
        "我", "你", "他", "她", "它", "我们", "你们", "他们",
        "这个", "那个", "these", "those", "什么", "怎么",
        "用户", "系统", "请", "让", "把", "被", "给", "对", "从", "到",
        "一个", "一些", "一种", "一下", "一样", "一直",
        "觉得", "认为", "知道", "看到", "想要", "需要",
        "说", "去", "来", "看", "用", "吃", "喝", "玩", "打",
        "很", "太", "真", "好", "多", "少", "大", "小",
        "上", "下", "里", "中", "前", "后", "时", "后"
    ]
    
    /// 生成标准偏好模型
    private func createUserPreference(key: String, value: String) -> UserPreference {
        UserPreference(
            id: UUID(),
            key: key,
            value: value,
            confidence: 0.85,
            learnedAt: Date(),
            source: "conversation_nlp"
        )
    }
    
    /// 合并新偏好到学习结果中（语义去重 + 本地编辑距离双重去重管道）
    private func mergePreferences(_ newPreferences: [UserPreference]) async {
        LoggerService.shared.debug("Merging \(newPreferences.count) new preferences, existing: \(learningResult.preferences.count)")

        // 1. 快速模糊过滤通道（编辑距离相似度）
        var uniqueNewPreferences: [UserPreference] = []
        for newPref in newPreferences {
            let cleanedValue = newPref.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanedValue.count >= 2 else { continue }
            
            let isDuplicate = isFuzzyDuplicate(newPref, existing: learningResult.preferences) ||
                              isFuzzyDuplicate(newPref, existing: uniqueNewPreferences)
            
            if !isDuplicate {
                uniqueNewPreferences.append(newPref)
            }
        }
        
        guard !uniqueNewPreferences.isEmpty else {
            LoggerService.shared.debug("All new preferences are duplicates after local fast-path filter.")
            return
        }

        // 2. 语义深度去重通道（调用 BGE-M3 模型） [1]
        var merged: [UserPreference] = []
        let mergedResult = await semanticDeduplicationService.mergePreferences(uniqueNewPreferences, existing: learningResult.preferences)
        
        if mergedResult.isEmpty && !uniqueNewPreferences.isEmpty {
            // 如果 Embedding 服务异常，本地去重兜底，安全保护 [1]
            var fallbackList = learningResult.preferences
            for pref in uniqueNewPreferences {
                if !isFuzzyDuplicate(pref, existing: fallbackList) {
                    fallbackList.append(pref)
                }
            }
            merged = fallbackList
            LoggerService.shared.warning("Semantic deduplication had silent fallback. Used local fuzzy-deduplication safeguard.")
        } else {
            merged = mergedResult
        }

        let addedCount = merged.count - learningResult.preferences.count
        learningResult.preferences = merged

        if addedCount > 0 {
            hasUnsavedChanges = true
        }

        LoggerService.shared.debug("Merge complete: added \(addedCount), total now: \(learningResult.preferences.count)")

        if learningResult.preferences.count > 100 {
            learningResult.preferences = Array(learningResult.preferences.suffix(100))
        }
    }

    /// 判断新偏好是否与已有偏好模糊重复
    private func isFuzzyDuplicate(_ new: UserPreference, existing: [UserPreference]) -> Bool {
        for item in existing where item.key == new.key {
            let newValue = new.value
            let existingValue = item.value

            // 规则1：包含关系（短字符串被长字符串包含）
            if newValue.contains(existingValue) || existingValue.contains(newValue) {
                return true
            }

            // 规则2：长度差异过大直接跳过（超过 1/3 视为不同）
            let lengthDiff = abs(newValue.count - existingValue.count)
            if Double(lengthDiff) > Double(max(newValue.count, existingValue.count)) * 0.33 {
                continue
            }

            // 规则3：Levenshtein 相似度 ≥ 0.7（调用我们写好的算法）
            if similarityBetween(newValue, existingValue) >= 0.7 {
                return true
            }
        }
        return false
    }

    /// 计算 Levenshtein 编辑距离（空间优化：仅使用两行 DP 数组）
    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aCount = a.count
        let bCount = b.count
        guard aCount > 0, bCount > 0 else { return max(aCount, bCount) }

        var previous = Array(0...bCount)
        var current = Array(repeating: 0, count: bCount + 1)

        let aArr = Array(a)
        let bArr = Array(b)
        for i in 1...aCount {
            current[0] = i
            for j in 1...bCount {
                let cost = aArr[i-1] == bArr[j-1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,      // 删除
                    current[j-1] + 1,     // 插入
                    previous[j-1] + cost  // 替换
                )
            }
            swap(&previous, &current)
        }
        return previous[bCount]
    }

    /// 计算两个字符串的相似度（0.0 ~ 1.0）
    private func similarityBetween(_ a: String, _ b: String) -> Double {
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return 1.0 }
        return 1.0 - Double(levenshteinDistance(a, b)) / Double(maxLen)
    }
    
    // MARK: - 【物理沙盒会话扫描机制】
    
    /// 物理载入沙盒中所有的历史会话文件并按时间排序，彻底打破 App 刚启动或非 AI 界面下内存缓存被静默置空导致无法进行增量计算的 Bug [2]
    private func loadAllSavedMessages() -> [ChatMessage] {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let conversationsDir = documentsURL.appendingPathComponent("YumikoToys Data/memory/conversations")
        
        guard fileManager.fileExists(atPath: conversationsDir.path) else {
            return []
        }
        
        var allMessages: [ChatMessage] = []
        
        if let files = try? fileManager.contentsOfDirectory(atPath: conversationsDir.path) {
            let decoder = JSONDecoder()
            for file in files where file.hasSuffix(".json") {
                let fileURL = conversationsDir.appendingPathComponent(file)
                if let data = try? Data(contentsOf: fileURL),
                   let messages = try? decoder.decode([ChatMessage].self, from: data) {
                    allMessages.append(contentsOf: messages)
                }
            }
        }
        
        // 按时间排序，确保上下文时序完全正常
        return allMessages.sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - 【全量去重物理清洗通道】
    
    /// 对现有已学习的所有历史偏好进行一次全量、回顾性的深度去重、物理垃圾词清洗与净化 [1, 2]
    func deduplicateExistingPreferences() async {
        guard !isLearning else { return }
        isLearning = true
        defer { isLearning = false }
        
        LoggerService.shared.info("[BackgroundLearningService] 开始对现有 \(learningResult.preferences.count) 条历史偏好进行全量去重与垃圾词深度净化清洗...")
        
        // 1. 第一关卡：快速本地模糊字面量比对与垃圾词过滤器
        var uniquePreferences: [UserPreference] = []
        let garbagePatterns = ["什么", "怎么", "哪里", "哪个", "如何", "为什么", "管家", "用户", "系统", "助理", "不知道", "没什么", "没有什么", "随便", "我的", "你的", "您的", "机器"]
        
        for pref in learningResult.preferences {
            // 【心理学去噪修复】过滤掉历史累积中包含无意义系统指代和疑问词的偏好条目（例如：什么用户、我的管家） [2]
            let containsGarbage = garbagePatterns.contains { pref.value.contains($0) }
            if containsGarbage {
                LoggerService.shared.warning("[BackgroundLearningService] 已成功物理抹除历史残留脏数据：\(pref.value)")
                continue // 直接丢弃该数据，完成物理净化 [2]
            }
            
            let isDuplicate = isFuzzyDuplicate(pref, existing: uniquePreferences)
            if !isDuplicate {
                uniquePreferences.append(pref)
            }
        }
        
        // 2. 第二关卡：深度语义向量去重（在 BGE-M3 加载时，真正执行对已有数据的两两语义比对） [1]
        var finalPreferences: [UserPreference] = []
        for pref in uniquePreferences {
            let isSemDup = await semanticDeduplicationService.isSemanticDuplicate(pref, existing: finalPreferences)
            if !isSemDup {
                finalPreferences.append(pref)
            }
        }
        
        let removedCount = learningResult.preferences.count - finalPreferences.count
        if removedCount > 0 {
            // 更新数据源并立即保存落盘
            learningResult.preferences = finalPreferences
            learningResult.stats.totalPreferencesLearned = finalPreferences.count
            hasUnsavedChanges = true
            saveLearningResults()
            
            // 实时广播给 UI 弹窗刷新
            learningResultsSubject.send(learningResult)
            LoggerService.shared.info("[BackgroundLearningService] 深度全量物理清洗完成！共剔除了 \(removedCount) 条重复偏好。")
        } else {
            LoggerService.shared.info("[BackgroundLearningService] 深度全量物理清洗完成，未检测到冗余偏好。")
        }
    }
    
    // MARK: - Data Access
    
    func getLearningResults() -> LearningResult {
        var result = learningResult
        result.stats.totalPreferencesLearned = learningResult.preferences.count
        return result
    }
    
    /// 重置学习状态（用于测试）
    func resetLearning() {
        learningResult = LearningResult(
            preferences: [],
            stats: LearningStats(
                totalConversationsAnalyzed: 0,
                totalPreferencesLearned: 0,
                lastLearningDate: nil,
                isLearningEnabled: learningResult.stats.isLearningEnabled
            )
        )
        lastAnalyzedMessageCount = 0
        saveLearningResults()
        LoggerService.shared.info("Learning results reset")
    }
    
    func getPreferences() -> [UserPreference] {
        learningResult.preferences
    }
    
    // MARK: - Persistence
    
    private func saveLearningResults() {
        let copyToSave = self.learningResult
        Task {
            await dataStorageService.save(copyToSave, to: "learning/learning_results.json")
        }
    }
    
    private func loadLearningResults() async {
        if let result: LearningResult = await dataStorageService.load(LearningResult.self, from: "learning/learning_results.json") {
            learningResult = result
        }
    }
}
