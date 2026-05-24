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
    var customFontPath: String?  // 外部字体路径
    var ntpConfiguration: NTPConfiguration  // NTP 服务器配置

    /// 默认对话模式
    var defaultChatMode: ChatMode

    /// 助手模式配置
    var assistantConfig: AssistantConfig

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
        customFontPath: String? = nil,
        ntpConfiguration: NTPConfiguration = .default,
        defaultChatMode: ChatMode = .petCompanion,
        assistantConfig: AssistantConfig = .default
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
        self.customFontPath = customFontPath
        self.ntpConfiguration = ntpConfiguration
        self.defaultChatMode = defaultChatMode
        self.assistantConfig = assistantConfig
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
        customFontPath = try container.decodeIfPresent(String.self, forKey: .customFontPath)
        ntpConfiguration = try container.decodeIfPresent(NTPConfiguration.self, forKey: .ntpConfiguration) ?? .default
        defaultChatMode = try container.decodeIfPresent(ChatMode.self, forKey: .defaultChatMode) ?? .petCompanion
        assistantConfig = try container.decodeIfPresent(AssistantConfig.self, forKey: .assistantConfig) ?? .default
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
