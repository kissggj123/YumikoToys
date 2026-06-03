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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cbt: return "认知行为疗法 (CBT)"
        case .sdt: return "自我决定理论 (SDT)"
        case .psychodynamics: return "心理动力学 (Psychodynamic)"
        case .humanistic: return "人本主义疗法 (Humanistic)"
        }
    }

    var description: String {
        switch self {
        case .cbt: return "基于贝克（Aaron Beck）认知重构模型，识别自动化负面思维与认知失调，通过理性辩证、认知图式重塑来消解压力与负面信念。"
        case .sdt: return "基于德西（Deci）和瑞安（Ryan）的动机理论，围绕自主权（Autonomy）、胜任感（Competence）和关系归属（Relatedness）三大核心动机需求，激活内部自驱力。"
        case .psychodynamics: return "探索潜意识冲突、早期经验与防御机制。帮助用户洞察防御机制背后的真实渴望，促进人格整合。"
        case .humanistic: return "基于卡尔·罗杰斯（Carl Rogers）当事人中心疗法，提供无条件积极关注（UPR）、真诚透明与共情性倾听，营造绝对安全的情感容器。"
        }
    }
}

/// 心理学专家身份
enum PsychologyPersona: String, Codable, CaseIterable, Sendable, Identifiable {
    case counselor = "counselor"           // 心理咨询师
    case therapist = "therapist"           // 临床心理医生
    case existentialist = "existential"    // 存在主义心理学家
    case coach = "coach"                   // 心理成长教练

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .counselor: return "专业心理咨询师"
        case .therapist: return "临床心理学家"
        case .existentialist: return "存在主义治疗师"
        case .coach: return "成长动机教练"
        }
    }

    var subtitle: String {
        switch self {
        case .counselor: return "温和倾听、积极关注、共情疏导"
        case .therapist: return "临床诊断、认知重构、深层图式治疗"
        case .existentialist: return "探讨生命意义、孤独、自由与痛苦接纳"
        case .coach: return "激发自主自驱、确立胜任感、制定积极行动"
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
    var selectedPsychologyTheory: PsychologyTheory
    var selectedPsychologyPersona: PsychologyPersona

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
        selectedPsychologyTheory: PsychologyTheory = .cbt,
        selectedPsychologyPersona: PsychologyPersona = .counselor
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
        self.selectedPsychologyTheory = selectedPsychologyTheory
        self.selectedPsychologyPersona = selectedPsychologyPersona
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
        selectedPsychologyTheory = try container.decodeIfPresent(PsychologyTheory.self, forKey: .selectedPsychologyTheory) ?? .cbt
        selectedPsychologyPersona = try container.decodeIfPresent(PsychologyPersona.self, forKey: .selectedPsychologyPersona) ?? .counselor
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
