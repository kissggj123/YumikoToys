//
//  AnimeThemeSystem.swift
//  YumikoToys
//
//  二次元主题系统 —— 提供四套精心设计的动漫风格配色方案，
//  可与现有 ThemeColor 体系无缝共存。
//

import SwiftUI

// MARK: - Anime Particle Style

/// 粒子特效风格
enum AnimeParticleStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    case sakura     // 樱花飘落
    case dataStream // 数据流
    case stars      // 星尘
    case clouds     // 流云

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sakura:     return "樱花飘落"
        case .dataStream: return "数据流"
        case .stars:      return "星尘"
        case .clouds:     return "流云"
        }
    }
}

// MARK: - Anime Animation Style

/// 动画过渡风格
enum AnimeAnimationStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    case float  // 漂浮
    case pulse  // 脉冲
    case bounce // 弹跳
    case gentle // 柔和

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .float:  return "漂浮"
        case .pulse:  return "脉冲"
        case .bounce: return "弹跳"
        case .gentle: return "柔和"
        }
    }
}

// MARK: - Anime Theme Style

/// 二次元主题风格枚举
enum AnimeThemeStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case healing  // 日系治愈风
    case cyber    // 赛博二次元
    case kawaii   // 软萌可爱风
    case makoto   // 新海诚精致写实

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .healing: return "日系治愈风"
        case .cyber:   return "赛博二次元"
        case .kawaii:  return "软萌可爱风"
        case .makoto:  return "新海诚精致写实"
        }
    }

    var themeIcon: String {
        switch self {
        case .healing: return "leaf.fill"
        case .cyber:   return "cpu.fill"
        case .kawaii:  return "heart.fill"
        case .makoto:  return "cloud.sun.fill"
        }
    }

    var description: String {
        switch self {
        case .healing: return "抹茶绿与晨光金，自然温暖的清爽森林调"
        case .cyber:   return "深空霓虹电光蓝，极具未来感的高科技二次元"
        case .kawaii:  return "草莓奶油草莓粉，甜美柔和的高级软萌氛围"
        case .makoto:  return "新海诚暮光晴空，蔚蓝与落日玫瑰红的电影光影"
        }
    }
}

// MARK: - Anime Theme Token

/// 二次元主题的完整设计令牌（Design Token），所有颜色以十六进制字符串存储以保证 Codable 兼容。
struct AnimeThemeToken: Codable, Sendable, Equatable {
    // 颜色（hex 字符串）
    var backgroundPrimary: String
    var backgroundSecondary: String
    var accentColor: String
    var glowColor: String
    var gradientStart: String
    var gradientEnd: String
    var cardBackground: String
    var cardBorder: String
    var textPrimary: String
    var textSecondary: String
    var hoverColor: String
    var buttonColor: String

    // 布局与效果参数
    var isDark: Bool
    var cardBlurRadius: Double
    var borderWidth: Double
    var cornerRadius: Double

    // 粒子与动画
    var particleStyle: AnimeParticleStyle
    var animationStyle: AnimeAnimationStyle

    // MARK: - Static Presets

    /// 日系治愈风 —— 抹茶温感与自然淡雅，清爽森林美学
    static let healing = AnimeThemeToken(
        backgroundPrimary:   "F7FAF6",
        backgroundSecondary: "EFF5ED",
        accentColor:         "3B7A57",
        glowColor:           "D99B26",
        gradientStart:       "81C784",
        gradientEnd:         "FBC02D",
        cardBackground:      "FFFFFF",
        cardBorder:          "D5E6D8",
        textPrimary:         "1B3022",
        textSecondary:       "4E6B56",
        hoverColor:          "E4F0E6",
        buttonColor:         "3B7A57",
        isDark:              false,
        cardBlurRadius:      12.0,
        borderWidth:         0.5,
        cornerRadius:        14.0,
        particleStyle:       .sakura,
        animationStyle:      .float
    )

    /// 赛博二次元 —— 霓虹电光与深空黑，顶级高科技质感
    static let cyber = AnimeThemeToken(
        backgroundPrimary:   "0B0E17",
        backgroundSecondary: "121726",
        accentColor:         "00E5FF",
        glowColor:           "D946EF",
        gradientStart:       "00E5FF",
        gradientEnd:         "8B5CF6",
        cardBackground:      "161C2E",
        cardBorder:          "293552",
        textPrimary:         "F8FAFC",
        textSecondary:       "94A3B8",
        hoverColor:          "1E263D",
        buttonColor:         "00E5FF",
        isDark:              true,
        cardBlurRadius:      20.0,
        borderWidth:         1.0,
        cornerRadius:        12.0,
        particleStyle:       .dataStream,
        animationStyle:      .pulse
    )

    /// 软萌可爱风 —— 草莓莓果与奶霜柔粉，甜美高级不俗套
    static let kawaii = AnimeThemeToken(
        backgroundPrimary:   "FFF6F8",
        backgroundSecondary: "FFECF1",
        accentColor:         "FF5376",
        glowColor:           "FFB703",
        gradientStart:       "FF7597",
        gradientEnd:         "FFB3C6",
        cardBackground:      "FFFFFF",
        cardBorder:          "FFD5E1",
        textPrimary:         "3D1424",
        textSecondary:       "7D425A",
        hoverColor:          "FFE4EC",
        buttonColor:         "FF5376",
        isDark:              false,
        cardBlurRadius:      10.0,
        borderWidth:         0.5,
        cornerRadius:        18.0,
        particleStyle:       .stars,
        animationStyle:      .bounce
    )

    /// 新海诚精致写实 —— 暮光晴空与落日渐变，电影级漫彩光影
    static let makoto = AnimeThemeToken(
        backgroundPrimary:   "F2F7FD",
        backgroundSecondary: "E4EEFB",
        accentColor:         "2563EB",
        glowColor:           "F59E0B",
        gradientStart:       "3B82F6",
        gradientEnd:         "F43F5E",
        cardBackground:      "FFFFFF",
        cardBorder:          "D1E2F8",
        textPrimary:         "0F172A",
        textSecondary:       "475569",
        hoverColor:          "E2EDFC",
        buttonColor:         "2563EB",
        isDark:              false,
        cardBlurRadius:      14.0,
        borderWidth:         0.5,
        cornerRadius:        14.0,
        particleStyle:       .clouds,
        animationStyle:      .gentle
    )

    /// 根据主题风格获取对应的预设令牌
    static func preset(for style: AnimeThemeStyle) -> AnimeThemeToken {
        switch style {
        case .healing: return .healing
        case .cyber:   return .cyber
        case .kawaii:  return .kawaii
        case .makoto:  return .makoto
        }
    }
}

// MARK: - Anime Theme Service

/// 二次元主题服务，作为轻量级状态持有者管理当前激活的动漫风格。
@MainActor
final class AnimeThemeService: ObservableObject, @unchecked Sendable {

    static let shared = AnimeThemeService()

    /// 当前选中的动漫主题风格
    @Published var currentStyle: AnimeThemeStyle = .healing

    /// 是否启用二次元主题（关闭时回退到标准 ThemeColor 体系）
    @Published var isEnabled: Bool = false

    private init() {}

    // MARK: - Token Access

    /// 当前风格对应的完整设计令牌
    var currentToken: AnimeThemeToken {
        AnimeThemeToken.preset(for: currentStyle)
    }

    /// 根据应用设置解析出最终生效的设计令牌
    ///
    /// 当 `isEnabled` 为 `false` 时仍返回当前选中风格的令牌，
    /// 但调用方应结合 `isEnabled` 判断是否实际使用。
    func resolve(for settings: AppSettings) -> AnimeThemeToken {
        AnimeThemeToken.preset(for: currentStyle)
    }

    // MARK: - SwiftUI Color Helpers

    /// 将令牌中的 hex 字符串转换为 SwiftUI Color

    func background(from token: AnimeThemeToken? = nil) -> Color {
        Color(hex: (token ?? currentToken).backgroundPrimary)
    }

    func backgroundSecondary(from token: AnimeThemeToken? = nil) -> Color {
        Color(hex: (token ?? currentToken).backgroundSecondary)
    }

    func accent(from token: AnimeThemeToken? = nil) -> Color {
        Color(hex: (token ?? currentToken).accentColor)
    }

    func glow(from token: AnimeThemeToken? = nil) -> Color {
        Color(hex: (token ?? currentToken).glowColor)
    }

    /// 返回渐变色数组（起始色 → 结束色），可直接用于 `LinearGradient`
    func gradient(from token: AnimeThemeToken? = nil) -> [Color] {
        let t = token ?? currentToken
        return [Color(hex: t.gradientStart), Color(hex: t.gradientEnd)]
    }

    func cardBackground(from token: AnimeThemeToken? = nil) -> Color {
        Color(hex: (token ?? currentToken).cardBackground)
    }

    func cardBorder(from token: AnimeThemeToken? = nil) -> Color {
        Color(hex: (token ?? currentToken).cardBorder)
    }

    func textPrimary(from token: AnimeThemeToken? = nil) -> Color {
        Color(hex: (token ?? currentToken).textPrimary)
    }

    func textSecondary(from token: AnimeThemeToken? = nil) -> Color {
        Color(hex: (token ?? currentToken).textSecondary)
    }

    func hoverColor(from token: AnimeThemeToken? = nil) -> Color {
        Color(hex: (token ?? currentToken).hoverColor)
    }

    func buttonColor(from token: AnimeThemeToken? = nil) -> Color {
        let t = token ?? currentToken
        return Color(hex: t.buttonColor).opacity(t.isDark ? 0.15 : 0.08)
    }

    // MARK: - Resolved Theme Bridge

    /// 返回与现有主题系统兼容的解析结果
    var resolvedTheme: AnimeResolvedTheme {
        AnimeResolvedTheme(token: currentToken, service: self)
    }
}

// MARK: - Anime Resolved Theme

/// 桥接结构体，将 `AnimeThemeToken` 包装为与现有 `ResolvedTheme` 对齐的 API。
@MainActor
struct AnimeResolvedTheme: Sendable {
    let token: AnimeThemeToken
    private let service: AnimeThemeService

    init(token: AnimeThemeToken, service: AnimeThemeService) {
        self.token = token
        self.service = service
    }

    var backgroundColor: Color { service.background(from: token) }
    var accentColor: Color { service.accent(from: token) }
    var glowColor: Color { service.glow(from: token) }
    var gradientColors: [Color] { service.gradient(from: token) }
    var cardBackgroundColor: Color { service.cardBackground(from: token) }
    var borderColor: Color { service.cardBorder(from: token) }
    var textColor: Color { service.textPrimary(from: token) }
    var secondaryTextColor: Color { service.textSecondary(from: token) }
    var hoverBackgroundColor: Color { service.hoverColor(from: token) }
    var buttonBackgroundColor: Color { service.buttonColor(from: token) }
    var isDarkTheme: Bool { token.isDark }
}

// MARK: - ResolvedTheme + Anime Bridge

extension ResolvedTheme {

    /// 如果二次元主题已启用，返回动漫背景色；否则返回现有的 `backgroundColor`
    var animeOrBackground: Color {
        guard AnimeThemeService.shared.isEnabled else { return backgroundColor }
        return AnimeThemeService.shared.background()
    }

    /// 如果二次元主题已启用，返回动漫强调色；否则返回现有的 `accentColor`
    var animeOrAccent: Color {
        guard AnimeThemeService.shared.isEnabled else { return accentColor }
        return AnimeThemeService.shared.accent()
    }

    /// 如果二次元主题已启用，返回动漫辉光色；否则回退到强调色
    var animeOrGlow: Color {
        guard AnimeThemeService.shared.isEnabled else { return accentColor }
        return AnimeThemeService.shared.glow()
    }

    /// 如果二次元主题已启用，返回动漫渐变色；否则回退到 iconGradient
    var animeOrGradient: [Color] {
        guard AnimeThemeService.shared.isEnabled else { return iconGradient }
        return AnimeThemeService.shared.gradient()
    }

    /// 如果二次元主题已启用，返回动漫卡片背景色；否则返回现有的 `cardBackgroundColor`
    var animeOrCardBackground: Color {
        guard AnimeThemeService.shared.isEnabled else { return cardBackgroundColor }
        return AnimeThemeService.shared.cardBackground()
    }

    /// 如果二次元主题已启用，返回动漫主文本色；否则返回现有的 `textColor`
    var animeOrTextPrimary: Color {
        guard AnimeThemeService.shared.isEnabled else { return textColor }
        return AnimeThemeService.shared.textPrimary()
    }

    /// 如果二次元主题已启用，返回动漫次要文本色；否则返回现有的 `secondaryTextColor`
    var animeOrTextSecondary: Color {
        guard AnimeThemeService.shared.isEnabled else { return secondaryTextColor }
        return AnimeThemeService.shared.textSecondary()
    }

    /// 如果二次元主题已启用，返回动漫边框色；否则返回现有的 `borderColor`
    var animeOrBorder: Color {
        guard AnimeThemeService.shared.isEnabled else { return borderColor }
        return AnimeThemeService.shared.cardBorder()
    }

    /// 如果二次元主题已启用，返回动漫悬停色；否则返回现有的 `hoverBackgroundColor`
    var animeOrHover: Color {
        guard AnimeThemeService.shared.isEnabled else { return hoverBackgroundColor }
        return AnimeThemeService.shared.hoverColor()
    }

    /// 如果二次元主题已启用，返回动漫按钮色；否则返回现有的 `buttonBackgroundColor`
    var animeOrButton: Color {
        guard AnimeThemeService.shared.isEnabled else { return buttonBackgroundColor }
        return AnimeThemeService.shared.buttonColor()
    }

    /// 如果二次元主题已启用，返回动漫深色标志；否则返回现有的 `isDarkTheme`
    var animeOrIsDark: Bool {
        guard AnimeThemeService.shared.isEnabled else { return isDarkTheme }
        return AnimeThemeService.shared.currentToken.isDark
    }
}
