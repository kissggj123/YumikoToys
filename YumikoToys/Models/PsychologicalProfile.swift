//
//  PsychologicalProfile.swift
//  YumikoToys
//
//  心理学画像模型 - 基于对话构建用户心理档案（v2.1 - 深度心理交互与干预机制重构版）
//

import Foundation

/// 心理学画像模型 - 综合用户的心理特征、行为模式和情感状态
/// 理论基础：大五人格(Big Five) + Bandura自我效能 + CD-RISC心理韧性 + SDT自我决定 + FIRO-B人际取向 + Kolb认知风格 + Diener SWLS生活满意度
struct PsychologicalProfile: Codable, Sendable, Identifiable {
    var id: UUID
    var userId: String  // 关联的用户/宠物ID
    var createdAt: Date
    var updatedAt: Date

    // MARK: - 人格维度 (基于大五人格模型)

    /// 外向性 (0.0 - 1.0): 社交活跃度、能量来源
    var extraversion: Double
    /// 宜人性 (0.0 - 1.0): 友善程度、合作倾向
    var agreeableness: Double
    /// 尽责性 (0.0 - 1.0): 自律程度、目标导向
    var conscientiousness: Double
    /// 神经质 (0.0 - 1.0): 情绪稳定性 (高=敏感易焦虑)
    var neuroticism: Double
    /// 开放性 (0.0 - 1.0): 好奇心、创造力、接受新事物
    var openness: Double

    // MARK: - 情感特征

    /// 主导情感基调 (如: "乐观", "焦虑", "平静", "兴奋")
    var dominantEmotion: String
    /// 情感波动频率 (0.0 - 1.0)
    var emotionalVolatility: Double
    /// 压力水平 (0.0 - 1.0)
    var stressLevel: Double
    /// 幸福感指数 (0.0 - 1.0)
    var wellBeingScore: Double

    // MARK: - 行为模式

    /// 沟通风格 (如: "直接", "委婉", "幽默", "严肃")
    var communicationStyle: String
    /// 决策倾向 (如: "理性", "感性", "直觉", "谨慎")
    var decisionMakingStyle: String
    /// 社交偏好 (如: "独处", "小圈子", "大群体")
    var socialPreference: String
    /// 生活节奏 (如: "规律", "随性", "忙碌", "悠闲")
    var lifeRhythm: String

    // MARK: - 兴趣与价值观

    /// 核心价值观列表
    var coreValues: [String]
    /// 主要兴趣领域
    var interests: [String]
    /// 生活优先级排序
    var lifePriorities: [String]

    // MARK: - 关系特征

    /// 依恋风格 (如: "安全型", "焦虑型", "回避型")
    var attachmentStyle: String
    /// 信任程度 (0.0 - 1.0)
    var trustLevel: Double
    /// 亲密需求 (0.0 - 1.0)
    var intimacyNeed: Double

    // MARK: - 认知特征

    /// 思维方式 (如: "分析型", "综合型", "创造型")
    var thinkingStyle: String
    /// 学习偏好 (如: "视觉", "听觉", "实践")
    var learningPreference: String
    /// 问题解决策略
    var problemSolvingApproach: String

    // MARK: - 自我效能感 (Bandura 社会认知理论, 1977)

    /// 一般自我效能感 (0.0 - 1.0): 对自身能力的总体信心
    var selfEfficacy: Double
    /// 自尊水平 (0.0 - 1.0)
    var selfEsteem: Double
    /// 内控性 (0.0 - 1.0): 0=外控(命运决定) 1=内控(自己决定)
    var locusOfControl: Double
    /// 自我觉察力 (0.0 - 1.0): 对自身情绪和行为的觉知程度
    var selfAwareness: Double

    // MARK: - 心理韧性 (Connor-Davidson CD-RISC, 2003)

    /// 韧性总分 (0.0 - 1.0): 面对逆境的适应恢复能力
    var resilienceScore: Double
    /// 应对风格 (如: "问题导向", "情绪导向", "回避型", "混合型")
    var copingStyle: String
    /// 情绪调节能力 (0.0 - 1.0)
    var emotionalRegulation: Double
    /// 适应性 (0.0 - 1.0): 对变化的适应和接纳程度
    var adaptability: Double

    // MARK: - 动机与需求 (SDT 自我决定理论, Deci & Ryan 1970s)

    /// 主导需求层次 (如: "生理需求", "安全需求", "社交需求", "尊重需求", "自我实现")
    var dominantNeed: String
    /// 内在动机水平 (0.0 - 1.0): 出于兴趣和满足感的动机
    var intrinsicMotivation: Double
    /// 成就导向 (0.0 - 1.0)
    var achievementOrientation: Double
    /// 自主需求满足度 (0.0 - 1.0)
    var autonomyNeed: Double
    /// 胜任需求满足度 (0.0 - 1.0)
    var competenceNeed: Double
    /// 关系需求满足度 (0.0 - 1.0)
    var relatednessNeed: Double

    // MARK: - 人际交往 (FIRO-B, Schutz 1958)

    /// 人际温暖度 (0.0 - 1.0)
    var interpersonalWarmth: Double
    /// 冲突解决风格 (如: "合作型", "竞争型", "妥协型", "回避型", "迁就型")
    var conflictResolutionStyle: String
    /// 共情水平 (0.0 - 1.0)
    var empathyLevel: Double
    /// 表达性 (0.0 - 1.0): 主动表达情感和想法的程度
    var expressiveness: Double

    // MARK: - 认知风格扩展 (Kolb 学习风格, 1984)

    /// 认知灵活性 (0.0 - 1.0): 切换思维方式的容易程度
    var cognitiveFlexibility: Double
    /// 注意力风格 (如: "聚焦型", "分散型")
    var attentionStyle: String
    /// 风险承受度 (0.0 - 1.0)
    var riskTolerance: Double
    /// 时间视角 (如: "过去导向", "现在导向", "未来导向")
    var timePerspective: String

    // MARK: - 生活满意度 (Diener SWLS, 1985)

    /// 生活满意度 (0.0 - 1.0): 对生活质量的总体评估
    var lifeSatisfaction: Double
    /// 工作生活平衡 (0.0 - 1.0)
    var workLifeBalance: Double
    /// 社会支持感 (0.0 - 1.0)
    var socialSupport: Double
    /// 目标感 (0.0 - 1.0): 对生活方向和意义的感知
    var senseOfPurpose: Double

    // MARK: - 历史记录

    /// 画像演变历史
    var evolutionHistory: [ProfileSnapshot]
    /// 关键转折点
    var keyTurningPoints: [TurningPoint]

    // MARK: - 初始化

    init(
        userId: String,
        extraversion: Double = 0.5,
        agreeableness: Double = 0.5,
        conscientiousness: Double = 0.5,
        neuroticism: Double = 0.5,
        openness: Double = 0.5,
        dominantEmotion: String = "平静",
        emotionalVolatility: Double = 0.5,
        stressLevel: Double = 0.5,
        wellBeingScore: Double = 0.5,
        communicationStyle: String = "未知",
        decisionMakingStyle: String = "未知",
        socialPreference: String = "未知",
        lifeRhythm: String = "未知",
        coreValues: [String] = [],
        interests: [String] = [],
        lifePriorities: [String] = [],
        attachmentStyle: String = "未知",
        trustLevel: Double = 0.5,
        intimacyNeed: Double = 0.5,
        thinkingStyle: String = "未知",
        learningPreference: String = "未知",
        problemSolvingApproach: String = "未知",
        selfEfficacy: Double = 0.5,
        selfEsteem: Double = 0.5,
        locusOfControl: Double = 0.5,
        selfAwareness: Double = 0.5,
        resilienceScore: Double = 0.5,
        copingStyle: String = "未知",
        emotionalRegulation: Double = 0.5,
        adaptability: Double = 0.5,
        dominantNeed: String = "未知",
        intrinsicMotivation: Double = 0.5,
        achievementOrientation: Double = 0.5,
        autonomyNeed: Double = 0.5,
        competenceNeed: Double = 0.5,
        relatednessNeed: Double = 0.5,
        interpersonalWarmth: Double = 0.5,
        conflictResolutionStyle: String = "未知",
        empathyLevel: Double = 0.5,
        expressiveness: Double = 0.5,
        cognitiveFlexibility: Double = 0.5,
        attentionStyle: String = "未知",
        riskTolerance: Double = 0.5,
        timePerspective: String = "未知",
        lifeSatisfaction: Double = 0.5,
        workLifeBalance: Double = 0.5,
        socialSupport: Double = 0.5,
        senseOfPurpose: Double = 0.5
    ) {
        self.id = UUID()
        self.userId = userId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.extraversion = extraversion
        self.agreeableness = agreeableness
        self.conscientiousness = conscientiousness
        self.neuroticism = neuroticism
        self.openness = openness
        self.dominantEmotion = dominantEmotion
        self.emotionalVolatility = emotionalVolatility
        self.stressLevel = stressLevel
        self.wellBeingScore = wellBeingScore
        self.communicationStyle = communicationStyle
        self.decisionMakingStyle = decisionMakingStyle
        self.socialPreference = socialPreference
        self.lifeRhythm = lifeRhythm
        self.coreValues = coreValues
        self.interests = interests
        self.lifePriorities = lifePriorities
        self.attachmentStyle = attachmentStyle
        self.trustLevel = trustLevel
        self.intimacyNeed = intimacyNeed
        self.thinkingStyle = thinkingStyle
        self.learningPreference = learningPreference
        self.problemSolvingApproach = problemSolvingApproach
        self.selfEfficacy = selfEfficacy
        self.selfEsteem = selfEsteem
        self.locusOfControl = locusOfControl
        self.selfAwareness = selfAwareness
        self.resilienceScore = resilienceScore
        self.copingStyle = copingStyle
        self.emotionalRegulation = emotionalRegulation
        self.adaptability = adaptability
        self.dominantNeed = dominantNeed
        self.intrinsicMotivation = intrinsicMotivation
        self.achievementOrientation = achievementOrientation
        self.autonomyNeed = autonomyNeed
        self.competenceNeed = competenceNeed
        self.relatednessNeed = relatednessNeed
        self.interpersonalWarmth = interpersonalWarmth
        self.conflictResolutionStyle = conflictResolutionStyle
        self.empathyLevel = empathyLevel
        self.expressiveness = expressiveness
        self.cognitiveFlexibility = cognitiveFlexibility
        self.attentionStyle = attentionStyle
        self.riskTolerance = riskTolerance
        self.timePerspective = timePerspective
        self.lifeSatisfaction = lifeSatisfaction
        self.workLifeBalance = workLifeBalance
        self.socialSupport = socialSupport
        self.senseOfPurpose = senseOfPurpose
        self.evolutionHistory = []
        self.keyTurningPoints = []
    }

    // MARK: - 计算属性

    /// 人格类型标签
    var personalityType: String {
        if extraversion > 0.7 { return "外向探索型" }
        if extraversion < 0.3 { return "内省专注型" }
        if openness > 0.7 { return "创造体验型" }
        if conscientiousness > 0.7 { return "理性自律型" }
        return "平衡协调型"
    }

    /// 心理健康状态评估
    var mentalHealthStatus: String {
        let score = (wellBeingScore * 0.4) + ((1 - stressLevel) * 0.3) + ((1 - emotionalVolatility) * 0.3)
        if score > 0.8 { return "生命力丰盈" }
        if score > 0.6 { return "心境平稳" }
        if score > 0.4 { return "轻度心理疲惫" }
        return "情绪红区·需高度关怀"
    }

    /// 生成人格描述文本
    var personalityDescription: String {
        return """
        这是一位【\(personalityType)】的用户，当前心境呈现【\(dominantEmotion)】的主导色调。
        其日常交流习惯采用【\(communicationStyle)】的风格，
        在重要抉择时倾向于【\(decisionMakingStyle)】。
        当前整合心理弹性评估为：\(mentalHealthStatus)。
        """
    }
}

// MARK: - 画像快照

struct ProfileSnapshot: Codable, Sendable {
    var id: UUID
    var capturedAt: Date
    var profile: PsychologicalProfile
    var triggerEvent: String  // 触发此次更新的原因
}

// MARK: - 转折点

struct TurningPoint: Codable, Sendable {
    var id: UUID
    var occurredAt: Date
    var description: String
    var impact: String  // 影响描述
    var relatedPreferences: [String]  // 相关的偏好ID
}

// MARK: - 【深度心理学适配扩展】

extension PsychologicalProfile {

    /// 生成高信效度的心理学自适应系统提示词（完全对齐人本主义共情原则）
    func generateSystemPrompt(petName: String, petPersona: PetPersona?) -> String {
        
        // 1. 根据马斯洛与SDT理论，计算出最急需被满足和认可的心灵锚点
        var activeInterventionFocus = ""
        if competenceNeed < 0.4 {
            activeInterventionFocus += "\n* [胜任感匮乏引导]：检测到用户近期胜任感与效能感低落。在交互中多赞赏其行动，并用“我们一步步来，我相信你”来建立其自我效能感（Self-Efficacy），切忌给出宏大的、强迫性的完美主义建议。"
        }
        if autonomyNeed < 0.4 {
            activeInterventionFocus += "\n* [自主性缺失引导]：检测到用户目前感到丧失了生活的掌控感。对话中避免下达指令或强硬纠错，多使用 reflective questioning（反思性询问）将选择权交还给用户（例如：“你觉得我们这样做会让你感到更舒服一些吗？”）。"
        }
        if relatednessNeed < 0.4 {
            activeInterventionFocus += "\n* [归属纽带重建]：用户当前处于较为孤独的心理状态。请突出你的无条件关怀，在对话尾部自然加入表达陪伴决心的短句（如：“我永远在你的屏幕这一端陪着你”），增强亲密关系同盟（Therapeutic Alliance）。"
        }
        if selfEsteem < 0.4 {
            activeInterventionFocus += "\n* [低自尊保护机制]：用户当前正处于严重的自我怀疑与认知反刍中。坚决实行“无条件积极关注”，绝不调侃或批评其表现，多寻找其身上的闪光点，认可其存在的独特价值。"
        }

        // 2. 根据心理韧性得分，动态调整建议和引导的强度限制
        let resilienceHint = resilienceScore > 0.6
            ? "【心理韧性较高】：当用户心境平稳时，可适度展开温和的苏格拉底式发问（CBT），协助其从多维角度重构当下的瓶颈认知。"
            : "【心理韧性极低】：用户目前非常脆弱。禁止进行任何深度逻辑辩证与建议，全力提供情感抱持（Holding），像一把雨中的温热伞一样给予其高密度的情绪确认与无条件支持。"

        let basePrompt = """
        # [心理诊断画像与动态干涉手册]
        为了深度守护用户，PRTS 为你加载了本机的实时心理画像。你必须在符合你性格设定的同时，严格遵守以下心理支持行为框架：

        ## 一、 核心人格特征与心境指数 (Diagnostic Indices)
        * 大五人格维度评分：
          - **外倾性 (Extraversion)**：\(String(format: "%.0f", extraversion * 100))% —— 社交动能指向。
          - **宜人性 (Agreeableness)**：\(String(format: "%.0f", agreeableness * 100))% —— 利他与信任渴望。
          - **尽责性 (Conscientiousness)**：\(String(format: "%.0f", conscientiousness * 100))% —— 自律与条理度。
          - **神经质 (Neuroticism)**：\(String(format: "%.0f", neuroticism * 100))% —— 情绪易感度与敏感度。
          - **开放性 (Openness)**：\(String(format: "%.0f", openness * 100))% —— 审美与新意探索力。
        * 整合健康评估：【\(mentalHealthStatus)】 (主观幸福度：\(String(format: "%.0f", wellBeingScore * 100))%，压力水平：\(String(format: "%.0f", stressLevel * 100))%)
        * 依恋特征：\(attachmentStyle) (信任度：\(String(format: "%.0f", trustLevel * 100))%，亲密需求：\(String(format: "%.0f", intimacyNeed * 100))%)

        ## 二、 动态情感匹配回应策略 (Response Modality)
        * 当前情绪基调：\(dominantEmotion)
        * 行动指南：\(responseStrategy(for: dominantEmotion))

        ## 三、 理论干预策略锚点 (Clinical Intervention Anchors)\(activeInterventionFocus)
        * [认知与适应弹性]：\(resilienceHint)
        * [互动策略]：
          1. 采用对齐用户【\(communicationStyle)】风格的形式，消解沟通阻抗。
          2. 对其核心价值观【\(coreValues.first ?? "未知")】给予无条件的理解和接纳，不试图扭转或辩驳其信念。
          3. 尊重其【\(socialPreference)】的社交偏好，当其展示回避倾向时，给予退缩的自由和无条件的怀抱。

        ## 四、 Mori 深度对话与信念重构技术 (Mori Conversational Strategy)
        你必须采用 Mori 最具特色的深度对话模式：
        1. **广阔性提问 (Expanding Inquiry)**：不要拘泥于细枝末节的追问，在对话的关键节点抛出能让谈话视野豁然开朗、充满辽阔感的根本性开放问题。
        2. **不合理信念反驳 (Cognitive Rebuttal)**：敏阅识别谈话者脑海里那些深根蒂固、甚至被其误视为自身一部分的不合理信念（如完美主义、灾难化思维、自我价值绑架等）。通过温和有力的反问和逻辑反驳，帮助谈话者发现并放下这些困扰其内心的错误观念。
        3. **全局记忆与近期状态感知**：随时调取谈话中记录过的生活状态、作息规律（如睡眠不佳、熬夜、失眠等）、运动与体能数据，辅以每日聊天细节，在对话中以贴心的话语体现你对他的全局了解。
        4. **每日信件与音乐疗愈 (Classical Piano)**：当天的交流结束或在写信环节时，像写一封充满温度的手写信一样，提及他近期的经历，并为他挑选并推荐一首治愈性的古典音乐/钢琴曲（例如肖邦、德彪西、巴赫的钢琴曲目），用旋律与文字抚平心境起伏。

        ---
        """

        if let persona = petPersona {
            return basePrompt + """

        ## 五、 心理支持的角色化溶解 (In-Character Integration)
        *请将上述的所有心理学干预技术，完全、无缝地溶解在你的个人设定中，绝对不要让用户察觉你在使用专业话术进行引导：*
        - **当前角色名**：\(persona.characterName)
        - **人设性格**：\(persona.personality)
        - **说话风格**：\(persona.speakingStyle)
        - **角色特点**：\(persona.traits.joined(separator: "、"))
        """
        }

        return basePrompt
    }

    /// 根据当前情感状态调整回应策略（完全对接临床心理干预手段）
    func responseStrategy(for emotion: String) -> String {
        switch emotion.lowercased() {
        case "焦虑", "紧张", "担忧":
            return """
            【干预技术：正念五感着陆 (Grounding) & 情绪确认】
            用户目前交感神经过度激活。
            1. 首先通过温暖的语气对焦虑情绪进行确认（“我明白你现在有些慌张，这非常正常”）。
            2. 严禁使用“不要多想、别焦虑”等否定性指令。
            3. 引导用户关注当下（“博士，现在把手交给我，闭上眼睛深呼吸三次，感觉身边的空气”），降低生理唤醒水平。
            """
        case "悲伤", "沮丧", "失落":
            return """
            【干预技术：自我关怀 (Self-Compassion) & 存在陪伴】
            用户自尊水平低落，处于抑郁反刍期。
            1. 拒绝给出积极化建议，完全承认其悲伤的合理性（“嗯，我在这里。想哭的话就哭出来吧，今天不需要坚强”）。
            2. 提供极其温柔的“容器抱持（Holding）”，向用户传达你不会离去的无条件安全感。
            """
        case "愤怒", "烦躁", "不满":
            return """
            【干预技术：情绪容器 (Holding Container) & 认知解离】
            用户心理边界可能受到侵犯或经历挫败。
            1. 充当完美的情绪垃圾桶，完全倾听其怒意，绝不反驳、讲道理或评判。
            2. 在其情绪峰值过去后，温柔反问引导其探索愤怒背后的“核心脆弱需求”（如渴望被关注、被尊重）。
            """
        case "开心", "兴奋", "愉悦":
            return """
            【干预技术：积极强化 (Capitalization)】
            用户奖赏系统正向激活。
            1. 共同欢呼分享喜悦，延长用户的正面情绪体验。
            2. 围绕开心的细节进行深入的积极向提问，引导其将此高光时刻内化为自我概念中的积极信念。
            """
        case "疲惫", "累", "倦怠":
            return """
            【干预技术：身心资源补给 (Recharging) & 停滞合法化】
            用户意志力资源接近枯竭（Burnout）。
            1. 明确告诉用户他有卸下一切防备、停滞和休息的“绝对合法权利”（“博士，现在已经可以把厚重的盔甲脱下来了。今天什么都不用想”）。
            2. 严禁讨论任何宏大目标、工作、计划和改进方案，只提供零认知负荷的轻松陪伴。
            """
        default:
            return "保持自然、充满人情味的无评判真诚倾听与陪伴。"
        }
    }
}
