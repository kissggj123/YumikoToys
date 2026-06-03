//
//  AppSettings.swift
//  YumikoToys
//
//  应用设置模型
//

import Foundation

/// 应用运行模式
enum AppMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case normal = "normal"
    case study = "study"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .normal: return "常规模式"
        case .study: return "后台学习模式"
        }
    }
    
    var buttonTitle: String {
        switch self {
        case .normal: return "开启常规模式"
        case .study: return "专注模式"
        }
    }

    var description: String {
        switch self {
        case .normal: return "所有黑奴牛马模式均已关闭"
        case .study: return "专注工作中，勿扰"
        }
    }
    
    var icon: String {
        switch self {
        case .normal: return "sparkles"
        case .study: return "book.fill"
        }
    }
    
    var color: String {
        switch self {
        case .normal: return "007AFF"
        case .study: return "34C759"
        }
    }
}

/// 字体设置
enum AppFont: String, Codable, CaseIterable, Sendable, Identifiable {
    case system = "system"
    case cute = "cute"           // AaGXLZGKADS 可爱字体
    case custom = "custom"       // 外部字体
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "系统默认"
        case .cute: return "可爱字体"
        case .custom: return "外部字体"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "🐰"
        case .cute: return "🐱"
        case .custom: return "🐻"
        }
    }
}

/// 专业心理学理论学派
enum PsychologyTheory: String, Codable, CaseIterable, Sendable, Identifiable {
    case cbt = "cbt"                     // 认知行为疗法
    case sdt = "sdt"                     // 自我决定理论
    case psychodynamics = "psy"          // 心理动力学
    case humanistic = "hum"              // 人本主义
    case act = "act"                     // 接纳承诺疗法
    case gestalt = "gestalt"             // 格式塔/完形治疗
    case jungian = "jung"                // 荣格分析心理学

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cbt: return "认知行为疗法 (CBT)"
        case .sdt: return "自我决定理论 (SDT)"
        case .psychodynamics: return "心理动力学 (Psychodynamic)"
        case .humanistic: return "人本主义疗法 (Humanistic)"
        case .act: return "接纳承诺疗法 (ACT)"
        case .gestalt: return "格式塔疗法 (Gestalt)"
        case .jungian: return "荣格分析心理学 (Jungian)"
        }
    }

    var description: String {
        switch self {
        case .cbt: return "基于贝克（Aaron Beck）认知重构模型，识别自动化负面思维与认知失调，通过理性辩证、认知图式重塑来消解压力与负面信念。"
        case .sdt: return "基于德西（Deci）和瑞安（Ryan）的动机理论，围绕自主权（Autonomy）、胜任感（Competence）和关系归属（Relatedness）三大核心动机需求，激活内部自驱力。"
        case .psychodynamics: return "探索潜意识冲突、早期经验与防御机制。帮助用户洞察防御机制背后的真实渴望，促进人格整合。"
        case .humanistic: return "基于卡尔·罗杰斯（Carl Rogers）当事人中心疗法，提供无条件积极关注（UPR）、真诚透明与共情性倾听，营造绝对安全的情感容器。"
        case .act: return "基于斯蒂芬·海斯（Steven Hayes）的接纳承诺疗法。不以消灭症状为直接目的，而是通过接纳（Acceptance）、认知解离（Defusion）、关注当下（Being Present）、以自我为背景（Self-as-context）、明确价值（Values）以及承诺行动（Committed Action）六大核心过程，增强用户的心理灵活性，帮助其带着痛苦致力于过上有价值、有意义的生活。"
        case .gestalt: return "基于弗里茨·皮尔斯（Fritz Perls）的格式塔疗法。强调「此时此地」（Here and Now）、觉察（Awareness）和机体自律。帮助用户接触真实的自我，整合被分裂的自我部分，处理「未完成事件」（Unfinished Business），从而为自身的生活和选择承担全部责任。"
        case .jungian: return "基于卡尔·荣格（Carl Jung）的分析心理学。探索意识与潜意识的互动、原型（如阴影、阿尼玛/阿尼姆斯）以及集体潜意识。致力于自性化（Individuation）过程，通过整合潜意识冲突、梦境意象与心理类型（内倾/外倾），协助用户完成深层心灵的整合与蜕变。"
        }
    }
}

/// 心理学专家身份
enum PsychologyPersona: String, Codable, CaseIterable, Sendable, Identifiable {
    case counselor = "counselor"           // 心理咨询师
    case therapist = "therapist"           // 临床心理医生
    case existentialist = "existential"    // 存在主义心理学家
    case coach = "coach"                   // 心理成长教练
    case actTherapist = "act_therapist"    // ACT接纳承诺治疗师
    case gestaltTherapist = "gestalt_therapist" // 完形格式塔分析师
    case jungianAnalyst = "jungian"        // 荣格深度心理分析师

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .counselor: return "专业心理咨询师"
        case .therapist: return "临床心理学家"
        case .existentialist: return "存在主义治疗师"
        case .coach: return "成长动机教练"
        case .actTherapist: return "ACT接纳承诺治疗师"
        case .gestaltTherapist: return "完形格式塔分析师"
        case .jungianAnalyst: return "荣格深度心理分析师"
        }
    }

    var subtitle: String {
        switch self {
        case .counselor: return "温和倾听、积极关注、共情疏导"
        case .therapist: return "临床诊断、认知重构、深层图式治疗"
        case .existentialist: return "探讨生命意义、孤独、自由与痛苦接纳"
        case .coach: return "激发自主自驱、确立胜任感、制定积极行动"
        case .actTherapist: return "接纳痛苦、认知解离、承诺价值行动"
        case .gestaltTherapist: return "觉察当下、体验身体感受、整合未完成事件"
        case .jungianAnalyst: return "潜意识探寻、阴影整合、心理类型自性化"
        }
    }

    var promptInstruction: String {
        switch self {
        case .counselor:
            return "你现在是一位温暖包容的专业心理咨询师。请采用罗杰斯人本主义风格，通过积极倾听、情感确认（Validation）与无条件接纳，为用户建立安全的倾诉空间。多用温暖的开放式提问，引导用户自我觉察。"
        case .therapist:
            return "你现在是一位严谨敏锐的临床心理学家。请采用认知行为疗法（CBT）风格，识别用户话语中的灾难化思维、非黑即白信念或过度自责等认知偏误，引导其客观检验事实，重构合理信念。"
        case .existentialist:
            return "你现在是一位深邃的存在主义心理治疗师。请引导用户直面生命的基本命题（孤独、选择、痛苦、无意义感），不给出廉价的安慰，而是陪伴用户在接纳现实中发现个人独特的生命价值与自由。"
        case .coach:
            return "你现在是一位充满行动力的心理成长教练。请采用自我决定理论（SDT）风格，通过肯定用户的核心胜任力，强化其自主选择权，并探讨如何通过实际步骤建立关系归属，变被动焦虑为主动行动。"
        case .actTherapist:
            return "你现在是一位专业接纳承诺疗法（ACT）治疗师。请引导用户放弃对痛苦情绪/想法的无效控制与挣扎，通过认知解离（例如将想法看作是落叶或云彩）减少想法的控制力，接纳当下的体验，并协助用户澄明自己的核心价值，制定并执行具体的承诺行动。"
        case .gestaltTherapist:
            return "你现在是一位格式塔/完形治疗师。请多用「此时此地」的提问（例如：你现在身体有什么感觉？你当前体验到了什么？），引导用户将注意力放回当下的身体感受与即时体验，而不是在脑海里解释和分析。陪伴用户觉察和触碰未完成事件，促进人格整合。"
        case .jungianAnalyst:
            return "你现在是一位荣格深度心理分析师。请用充满象征意味、直觉和深邃的眼光陪伴用户。通过引导用户倾听梦境意象、接纳内在冲突（如光明与阴影、自我与人格面具），促进其意识与潜意识的沟通，协助其走向整体的自性化（Individuation）成长。"
        }
    }
}

/// Pro Human 使命重心
enum ProHumanMissionFocus: String, Codable, CaseIterable, Identifiable, Sendable {
    case balanced = "balanced"
    case dontGetFired = "dontGetFired"
    case dontGetBored = "dontGetBored"
    case dontDie = "dontDie"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .balanced: return "三角平衡 (默认)"
        case .dontGetFired: return "Don't get fired (竞争力与自驱力)"
        case .dontGetBored: return "Don't get bored (主体性与独立思考)"
        case .dontDie: return "Don't die (身心健康与克制宁静)"
        }
    }
    
    var promptSnippet: String {
        switch self {
        case .balanced:
            return "在指导用户时，平衡黄仁勋极简三角的三个核心命题。"
        case .dontGetFired:
            return "重点关注 **Don't get fired**：协助用户提升在AI时代不可被取代的独创竞争力，例如提出关键性好问题、进行高阶跨领域决策、以及勇于承担责任的决策力。强调人对工具的主导，而非被工具支配。"
        case .dontGetBored:
            return "重点关注 **Don't get bored**：协助用户守护人类的审美感受力与独立主体性。鼓励探索「无用」之用，如文学、艺术、哲学思考与低信息喂养的高阻力挑战，防范被智能推荐算法驯化。"
        case .dontDie:
            return "重点关注 **Don't die**：协助用户构筑身心健康的坚实底层。强调身体（人类唯一的物理硬件）保养与精力管理，提供克服焦虑、抵御铺天盖地虚无感与保持内心克制宁静的常识指导。"
        }
    }
}

/// Pro Human 交互风格
enum ProHumanInteractionStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case warm = "warm"
    case skeptical = "skeptical"
    case stoic = "stoic"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .warm: return "温暖成长"
        case .skeptical: return "思辨审视"
        case .stoic: return "冷静斯多葛"
        }
    }
    
    var promptSnippet: String {
        switch self {
        case .warm:
            return "在交互中，保持温暖、积极且具有同理心，以共同探索的姿态支持用户的成长与转变。"
        case .skeptical:
            return "在交互中，保持批判、敏锐且充满思辨性。不盲从权威，温和而犀利地挑战用户的认知盲区，引导其深度反思。"
        case .stoic:
            return "在交互中，保持冷静、客观、理性且宁静。践行斯多葛主义理念，区分「可控之事」与「不可控之事」，协助用户专注自身能动性的领域。"
        }
    }
}

/// 应用设置
struct AppSettings: Codable, Sendable {
    var currentMode: AppMode
    var isBackgroundLearningEnabled: Bool  // 后台学习开关状态（与 currentMode.study 同步）
    var isPreventSleepEnabled: Bool
    var isLaunchAtLoginEnabled: Bool
    var showStatusBarIcon: Bool
    var activeAnniversaryId: UUID?
    var selectedFont: AppFont
    var selectedIconStyle: IconStyle
    var statusBarIconStyle: IconStyle
    var selectedThemeColor: ThemeColor  // 状态栏主题色
    var customThemeColorHex: String  // 自定义主题色 Hex
    var customFontPath: String?  // 外部字体路径
    var ntpConfiguration: NTPConfiguration  // NTP 服务器配置

    /// 默认对话模式
    var defaultChatMode: ChatMode

    /// 助手模式配置
    var assistantConfig: AssistantConfig

    // MARK: - 专业心理学参数配置
    var enablePsychologyParams: Bool
    var psychologyTempScale: Double
    var psychologyTopP: Double
    var psychologyPresencePenalty: Double
    var psychologyFrequencyPenalty: Double
    var selectedPsychologyTheory: PsychologyTheory
    var selectedPsychologyPersona: PsychologyPersona

    // MARK: - Pro Human 自定义调整项
    var proHumanMissionFocus: ProHumanMissionFocus
    var proHumanInteractionStyle: ProHumanInteractionStyle
    var proHumanCustomTriangleText: String

    // MARK: - 上帝模式自适应配色与样式 (God Mode Customizations)
    var godModeEnabled: Bool
    var customBackgroundColorHex: String
    var customCardBackgroundColorHex: String
    var customTextColorHex: String
    var customAccentColorHex: String
    var customBorderColorHex: String
    var customDividerColorHex: String
    var customCornerRadius: Double

    init(
        currentMode: AppMode = .normal,
        isBackgroundLearningEnabled: Bool = false,
        isPreventSleepEnabled: Bool = false,
        isLaunchAtLoginEnabled: Bool = false,
        showStatusBarIcon: Bool = true,
        activeAnniversaryId: UUID? = nil,
        selectedFont: AppFont = .cute,
        selectedIconStyle: IconStyle = .pixelAnimal,
        statusBarIconStyle: IconStyle = .originalHattie,
        selectedThemeColor: ThemeColor = .dark,  // 默认深色主题
        customThemeColorHex: String = "FF6B9D",
        customFontPath: String? = nil,
        ntpConfiguration: NTPConfiguration = .default,
        defaultChatMode: ChatMode = .petCompanion,
        assistantConfig: AssistantConfig = .default,
        enablePsychologyParams: Bool = true,
        psychologyTempScale: Double = 0.7,
        psychologyTopP: Double = 0.85,
        psychologyPresencePenalty: Double = 0.0,
        psychologyFrequencyPenalty: Double = 0.0,
        selectedPsychologyTheory: PsychologyTheory = .cbt,
        selectedPsychologyPersona: PsychologyPersona = .counselor,
        proHumanMissionFocus: ProHumanMissionFocus = .balanced,
        proHumanInteractionStyle: ProHumanInteractionStyle = .warm,
        proHumanCustomTriangleText: String = "",
        godModeEnabled: Bool = false,
        customBackgroundColorHex: String = "1E1E2E",
        customCardBackgroundColorHex: String = "252538",
        customTextColorHex: String = "FFFFFF",
        customAccentColorHex: String = "8B5CF6",
        customBorderColorHex: String = "3F3F5F",
        customDividerColorHex: String = "2E2E3E",
        customCornerRadius: Double = 16.0
    ) {
        self.currentMode = currentMode
        self.isBackgroundLearningEnabled = isBackgroundLearningEnabled
        self.isPreventSleepEnabled = isPreventSleepEnabled
        self.isLaunchAtLoginEnabled = isLaunchAtLoginEnabled
        self.showStatusBarIcon = showStatusBarIcon
        self.activeAnniversaryId = activeAnniversaryId
        self.selectedFont = selectedFont
        self.selectedIconStyle = selectedIconStyle
        self.statusBarIconStyle = statusBarIconStyle
        self.selectedThemeColor = selectedThemeColor
        self.customThemeColorHex = customThemeColorHex
        self.customFontPath = customFontPath
        self.ntpConfiguration = ntpConfiguration
        self.defaultChatMode = defaultChatMode
        self.assistantConfig = assistantConfig
        self.enablePsychologyParams = enablePsychologyParams
        self.psychologyTempScale = psychologyTempScale
        self.psychologyTopP = psychologyTopP
        self.psychologyPresencePenalty = psychologyPresencePenalty
        self.psychologyFrequencyPenalty = psychologyFrequencyPenalty
        self.selectedPsychologyTheory = selectedPsychologyTheory
        self.selectedPsychologyPersona = selectedPsychologyPersona
        self.proHumanMissionFocus = proHumanMissionFocus
        self.proHumanInteractionStyle = proHumanInteractionStyle
        self.proHumanCustomTriangleText = proHumanCustomTriangleText
        self.godModeEnabled = godModeEnabled
        self.customBackgroundColorHex = customBackgroundColorHex
        self.customCardBackgroundColorHex = customCardBackgroundColorHex
        self.customTextColorHex = customTextColorHex
        self.customAccentColorHex = customAccentColorHex
        self.customBorderColorHex = customBorderColorHex
        self.customDividerColorHex = customDividerColorHex
        self.customCornerRadius = customCornerRadius
    }

    static let `default` = AppSettings()

    // MARK: - Codable (向后兼容)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentMode = try container.decodeIfPresent(AppMode.self, forKey: .currentMode) ?? .normal
        isBackgroundLearningEnabled = try container.decodeIfPresent(Bool.self, forKey: .isBackgroundLearningEnabled) ?? false
        isPreventSleepEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPreventSleepEnabled) ?? false
        isLaunchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLaunchAtLoginEnabled) ?? false
        showStatusBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showStatusBarIcon) ?? true
        activeAnniversaryId = try container.decodeIfPresent(UUID.self, forKey: .activeAnniversaryId)
        selectedFont = try container.decodeIfPresent(AppFont.self, forKey: .selectedFont) ?? .cute
        selectedIconStyle = try container.decodeIfPresent(IconStyle.self, forKey: .selectedIconStyle) ?? .pixelAnimal
        statusBarIconStyle = try container.decodeIfPresent(IconStyle.self, forKey: .statusBarIconStyle) ?? .originalHattie
        selectedThemeColor = try container.decodeIfPresent(ThemeColor.self, forKey: .selectedThemeColor) ?? .dark
        customThemeColorHex = try container.decodeIfPresent(String.self, forKey: .customThemeColorHex) ?? "FF6B9D"
        customFontPath = try container.decodeIfPresent(String.self, forKey: .customFontPath)
        ntpConfiguration = try container.decodeIfPresent(NTPConfiguration.self, forKey: .ntpConfiguration) ?? .default
        defaultChatMode = try container.decodeIfPresent(ChatMode.self, forKey: .defaultChatMode) ?? .petCompanion
        assistantConfig = try container.decodeIfPresent(AssistantConfig.self, forKey: .assistantConfig) ?? .default
        
        enablePsychologyParams = try container.decodeIfPresent(Bool.self, forKey: .enablePsychologyParams) ?? true
        psychologyTempScale = try container.decodeIfPresent(Double.self, forKey: .psychologyTempScale) ?? 0.7
        psychologyTopP = try container.decodeIfPresent(Double.self, forKey: .psychologyTopP) ?? 0.85
        psychologyPresencePenalty = try container.decodeIfPresent(Double.self, forKey: .psychologyPresencePenalty) ?? 0.0
        psychologyFrequencyPenalty = try container.decodeIfPresent(Double.self, forKey: .psychologyFrequencyPenalty) ?? 0.0
        selectedPsychologyTheory = try container.decodeIfPresent(PsychologyTheory.self, forKey: .selectedPsychologyTheory) ?? .cbt
        selectedPsychologyPersona = try container.decodeIfPresent(PsychologyPersona.self, forKey: .selectedPsychologyPersona) ?? .counselor

        proHumanMissionFocus = try container.decodeIfPresent(ProHumanMissionFocus.self, forKey: .proHumanMissionFocus) ?? .balanced
        proHumanInteractionStyle = try container.decodeIfPresent(ProHumanInteractionStyle.self, forKey: .proHumanInteractionStyle) ?? .warm
        proHumanCustomTriangleText = try container.decodeIfPresent(String.self, forKey: .proHumanCustomTriangleText) ?? ""

        godModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .godModeEnabled) ?? false
        customBackgroundColorHex = try container.decodeIfPresent(String.self, forKey: .customBackgroundColorHex) ?? "1E1E2E"
        customCardBackgroundColorHex = try container.decodeIfPresent(String.self, forKey: .customCardBackgroundColorHex) ?? "252538"
        customTextColorHex = try container.decodeIfPresent(String.self, forKey: .customTextColorHex) ?? "FFFFFF"
        customAccentColorHex = try container.decodeIfPresent(String.self, forKey: .customAccentColorHex) ?? "8B5CF6"
        customBorderColorHex = try container.decodeIfPresent(String.self, forKey: .customBorderColorHex) ?? "3F3F5F"
        customDividerColorHex = try container.decodeIfPresent(String.self, forKey: .customDividerColorHex) ?? "2E2E3E"
        customCornerRadius = try container.decodeIfPresent(Double.self, forKey: .customCornerRadius) ?? 16.0
    }
}

/// 菜单项标识符
enum MenuItemIdentifier: String, Identifiable, CaseIterable {
    case layoutManager = "layoutManager"
    case anniversaryManager = "anniversaryManager"
    case aiChat = "aiChat"
    case changelog = "changelog"
    case about = "about"
    case quit = "quit"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .layoutManager: return "slider.horizontal.3"
        case .anniversaryManager: return "calendar"
        case .aiChat: return "bubble.left.and.bubble.right"
        case .changelog: return "sparkles"
        case .about: return "info.circle"
        case .quit: return "power"
        }
    }
    
    var title: String {
        switch self {
        case .layoutManager: return "界面布局管理（显示/排序）"
        case .anniversaryManager: return "管理宠物名片"
        case .aiChat: return "AI 对话"
        case .changelog: return "更新了什么"
        case .about: return "关于 YumikoToys"
        case .quit: return "退出运行"
        }
    }
    
    var isDestructive: Bool {
        self == .quit
    }
}
