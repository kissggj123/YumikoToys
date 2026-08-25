//
//  StatusBarView.swift
//  YumikoToys
//
//  状态栏弹出视图（v4.0.1 - 稳定版与手势适配重构）
//

import SwiftUI
import Combine

// MARK: - 主题色枚举

@MainActor enum ThemeColor: String, CaseIterable, Codable, Sendable, Identifiable {
    case dark       // 深色经典
    case pink       // 淡粉色
    case lavender   // 薰衣草紫
    case mint       // 薄荷绿
    case ocean      // 海洋蓝
    case sunset     // 日落橙
    case pixel      // 像素复古
    case sakura     // 櫻花粉
    case deepSea    // 深海蓝
    case forest     // 森林绿
    case amber      // 琥珀橙
    case crimson    // 赤焰紫
    case arctic     // 极地白
    case roseGold   // 玫瑞金
    case charcoal   // 炭墨黑
    case custom     // 自定义主题
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dark: return "深色"
        case .pink: return "粉色"
        case .lavender: return "紫色"
        case .mint: return "薄荷"
        case .ocean: return "海洋"
        case .sunset: return "日落"
        case .pixel: return "像素"
        case .sakura: return "櫻花"
        case .deepSea: return "深海"
        case .forest: return "森林"
        case .amber: return "琥珀"
        case .crimson: return "赤焰"
        case .arctic: return "极地"
        case .roseGold: return "玫金"
        case .charcoal: return "炭墨"
        case .custom:
            if let activeName = DependencyContainer.shared.settingsService.settings.activeColorSchemeName {
                return activeName
            }
            return "自定义"
        }
    }
    
    var themeIcon: String {
        switch self {
        case .dark: return "moon.fill"
        case .pink: return "heart.fill"
        case .lavender: return "sparkles"
        case .mint: return "leaf.fill"
        case .ocean: return "water.waves"
        case .sunset: return "sun.max.fill"
        case .pixel: return "gamecontroller.fill"
        case .sakura: return "tree.fill"
        case .deepSea: return "fish.fill"
        case .forest: return "tent.fill"
        case .amber: return "flame.fill"
        case .crimson: return "bolt.fill"
        case .arctic: return "snowflake"
        case .roseGold: return "crown.fill"
        case .charcoal: return "circle.fill"
        case .custom: return "paintpalette.fill"
        }
    }
    
    // MARK: - 自定义颜色解析
    
    private static func getRGB(from hex: String) -> (r: Double, g: Double, b: Double) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        return (r, g, b)
    }
    
    private static func isCustomLight(for hex: String) -> Bool {
        let (r, g, b) = getRGB(from: hex)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.65
    }
    
    var customColor: Color { customColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var isCustomLight: Bool { isCustomLight(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var isCustomDarkBackground: Bool { isCustomDarkBackground(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var isAccentLight: Bool { isAccentLight(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var customBlendedBackground: (r: Double, g: Double, b: Double) { customBlendedBackground(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    
    var backgroundColor: Color { backgroundColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var nsBackgroundColor: NSColor { nsBackgroundColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var accentColor: Color { accentColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var iconGradient: [Color] { iconGradient(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var textColor: Color { textColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var secondaryTextColor: Color { secondaryTextColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var cardBackgroundColor: Color { cardBackgroundColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var buttonBackgroundColor: Color { buttonBackgroundColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var isDarkTheme: Bool { isDarkTheme(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var borderColor: Color { borderColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var dividerColor: Color { dividerColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var toggleOnColor: Color { toggleOnColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var toggleBackgroundColor: Color { toggleBackgroundColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var primaryButtonBackground: Color { primaryButtonBackground(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var primaryButtonTextColor: Color { primaryButtonTextColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var secondaryButtonBackground: Color { secondaryButtonBackground(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var destructiveButtonColor: Color { destructiveButtonColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var iconColor: Color { iconColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }
    var hoverBackgroundColor: Color { hoverBackgroundColor(customHex: DependencyContainer.shared.settingsService.settings.customThemeColorHex) }

    // MARK: - Anime Bridge Properties
    // 当二次元主题启用时，返回 AnimeThemeService 的颜色令牌；否则回退到标准 ThemeColor。

    var animeOrBackground: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.background() : backgroundColor
    }
    var animeOrAccent: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.accent() : accentColor
    }
    var animeOrGlow: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.glow() : accentColor
    }
    var animeOrGradient: [Color] {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.gradient() : iconGradient
    }
    var animeOrCardBackground: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.cardBackground() : cardBackgroundColor
    }
    var animeOrTextPrimary: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.textPrimary() : textColor
    }
    var animeOrTextSecondary: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.textSecondary() : secondaryTextColor
    }
    var animeOrBorder: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.cardBorder() : borderColor
    }
    var animeOrDivider: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.cardBorder() : dividerColor
    }
    var animeOrHover: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.hoverColor() : hoverBackgroundColor
    }
    var animeOrButton: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.buttonColor() : buttonBackgroundColor
    }
    var animeOrToggleOn: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.accent() : toggleOnColor
    }
    var animeOrToggleBackground: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.hoverColor() : toggleBackgroundColor
    }
    var animeOrIcon: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.textSecondary() : iconColor
    }
    var animeOrSecondaryButton: Color {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.hoverColor() : secondaryButtonBackground
    }
    var animeOrIsDark: Bool {
        AnimeThemeService.shared.isEnabled ? AnimeThemeService.shared.currentToken.isDark : isDarkTheme
    }

    var originalIconGradient: [Color] {
        switch self {
        case .dark:
            return [Color(hex: "FF6B9D"), Color(hex: "C44FE2")]
        case .pink:
            return [Color(hex: "FFB6C1"), Color(hex: "E85D75")]
        case .lavender:
            return [Color(hex: "C4B5FD"), Color(hex: "8B5CF6")]
        case .mint:
            return [Color(hex: "6EE7B7"), Color(hex: "10B981")]
        case .ocean:
            return [Color(hex: "93C5FD"), Color(hex: "3B82F6")]
        case .sunset:
            return [Color(hex: "FCD34D"), Color(hex: "F59E0B")]
        case .pixel:
            return [Color(hex: "22D3EE"), Color(hex: "A78BFA")]
        case .sakura:
            return [Color(hex: "FFB7C5"), Color(hex: "FF91A8")]
        case .deepSea:
            return [Color(hex: "48CAE4"), Color(hex: "00B4D8")]
        case .forest:
            return [Color(hex: "95D5B2"), Color(hex: "52B788")]
        case .amber:
            return [Color(hex: "FFD166"), Color(hex: "F4A261")]
        case .crimson:
            return [Color(hex: "E2B0FF"), Color(hex: "C77DFF")]
        case .arctic:
            return [Color(hex: "74B0E8"), Color(hex: "4A90D9")]
        case .roseGold:
            return [Color(hex: "F2C4A8"), Color(hex: "E8956D")]
        case .charcoal:
            return [Color(hex: "D0D0D0"), Color(hex: "A0A0A0")]
        case .custom:
            let c = Color(hex: DependencyContainer.shared.settingsService.settings.customThemeColorHex)
            return [c, c.opacity(0.7)]
        }
    }
    
    var originalAccentColor: Color {
        switch self {
        case .dark:
            return Color(hex: "FF6B9D")
        case .pink:
            return Color(hex: "E85D75")
        case .lavender:
            return Color(hex: "8B5CF6")
        case .mint:
            return Color(hex: "10B981")
        case .ocean:
            return Color(hex: "3B82F6")
        case .sunset:
            return Color(hex: "F59E0B")
        case .pixel:
            return Color(hex: "22D3EE")
        case .sakura:
            return Color(hex: "FFB7C5")
        case .deepSea:
            return Color(hex: "00B4D8")
        case .forest:
            return Color(hex: "52B788")
        case .amber:
            return Color(hex: "F4A261")
        case .crimson:
            return Color(hex: "C77DFF")
        case .arctic:
            return Color(hex: "4A90D9")
        case .roseGold:
            return Color(hex: "E8956D")
        case .charcoal:
            return Color(hex: "A0A0A0")
        case .custom:
            return Color(hex: DependencyContainer.shared.settingsService.settings.customThemeColorHex)
        }
    }
}

// MARK: - ThemeColor Parameterized Extensions

extension ThemeColor {
    func customColor(customHex: String) -> Color {
        return Color(hex: customHex)
    }
    
    func isCustomLight(customHex: String) -> Bool {
        return Self.isCustomLight(for: customHex)
    }
    
    func isCustomDarkBackground(customHex: String) -> Bool {
        let (r, g, b) = Self.getRGB(from: customHex)
        let MathLuminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return MathLuminance > 0.45
    }
    
    func isAccentLight(customHex: String) -> Bool {
        let (r, g, b) = Self.getRGB(from: customHex)
        let MathLuminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return MathLuminance > 0.7
    }
    
    func customBlendedBackground(customHex: String) -> (r: Double, g: Double, b: Double) {
        let (r, g, b) = Self.getRGB(from: customHex)
        if isCustomDarkBackground(customHex: customHex) {
            let bgR = r * 0.08 + 0.055 * 0.92
            let bgG = g * 0.08 + 0.055 * 0.92
            let bgB = b * 0.08 + 0.063 * 0.92
            return (bgR, bgG, bgB)
        } else {
            let bgR = r * 0.04 + 1.0 * 0.96
            let bgG = g * 0.04 + 1.0 * 0.96
            let bgB = b * 0.04 + 1.0 * 0.96
            return (bgR, bgG, bgB)
        }
    }
    
    func backgroundColor(customHex: String) -> Color {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            return Color(hex: DependencyContainer.shared.settingsService.settings.customBackgroundColorHex)
        }
        switch self {
        case .dark:
            return Color(red: 0.07, green: 0.07, blue: 0.08)
        case .pink:
            return Color(red: 1.0, green: 0.94, blue: 0.95)
        case .lavender:
            return Color(red: 0.95, green: 0.94, blue: 0.99)
        case .mint:
            return Color(red: 0.94, green: 0.99, blue: 0.96)
        case .ocean:
            return Color(red: 0.94, green: 0.98, blue: 1.0)
        case .sunset:
            return Color(red: 1.0, green: 0.97, blue: 0.93)
        case .pixel:
            return Color(red: 0.10, green: 0.10, blue: 0.12)
        case .sakura:
            return Color(red: 1.0, green: 0.96, blue: 0.97)
        case .deepSea:
            return Color(red: 0.106, green: 0.31, blue: 0.447)
        case .forest:
            return Color(red: 0.106, green: 0.227, blue: 0.176)
        case .amber:
            return Color(red: 0.176, green: 0.106, blue: 0.0)
        case .crimson:
            return Color(red: 0.176, green: 0.039, blue: 0.118)
        case .arctic:
            return Color(red: 0.941, green: 0.957, blue: 0.973)
        case .roseGold:
            return Color(red: 0.173, green: 0.094, blue: 0.063)
        case .charcoal:
            return Color(red: 0.051, green: 0.051, blue: 0.051)
        case .custom:
            let (r, g, b) = customBlendedBackground(customHex: customHex)
            return Color(red: r, green: g, blue: b)
        }
    }
    
    func nsBackgroundColor(customHex: String) -> NSColor {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            let hex = DependencyContainer.shared.settingsService.settings.customBackgroundColorHex
            let (r, g, b) = Self.getRGB(from: hex)
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)
        }
        switch self {
        case .dark:
            return NSColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1.0)
        case .pink:
            return NSColor(red: 1.0, green: 0.94, blue: 0.95, alpha: 1.0)
        case .lavender:
            return NSColor(red: 0.95, green: 0.94, blue: 0.99, alpha: 1.0)
        case .mint:
            return NSColor(red: 0.94, green: 0.99, blue: 0.96, alpha: 1.0)
        case .ocean:
            return NSColor(red: 0.94, green: 0.98, blue: 1.0, alpha: 1.0)
        case .sunset:
            return NSColor(red: 1.0, green: 0.97, blue: 0.93, alpha: 1.0)
        case .pixel:
            return NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        case .sakura:
            return NSColor(red: 1.0, green: 0.96, blue: 0.97, alpha: 1.0)
        case .deepSea:
            return NSColor(red: 0.106, green: 0.31, blue: 0.447, alpha: 1.0)
        case .forest:
            return NSColor(red: 0.106, green: 0.227, blue: 0.176, alpha: 1.0)
        case .amber:
            return NSColor(red: 0.176, green: 0.106, blue: 0.0, alpha: 1.0)
        case .crimson:
            return NSColor(red: 0.176, green: 0.039, blue: 0.118, alpha: 1.0)
        case .arctic:
            return NSColor(red: 0.941, green: 0.957, blue: 0.973, alpha: 1.0)
        case .roseGold:
            return NSColor(red: 0.173, green: 0.094, blue: 0.063, alpha: 1.0)
        case .charcoal:
            return NSColor(red: 0.051, green: 0.051, blue: 0.051, alpha: 1.0)
        case .custom:
            let (r, g, b) = customBlendedBackground(customHex: customHex)
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)
        }
    }
    
    func accentColor(customHex: String) -> Color {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            return Color(hex: DependencyContainer.shared.settingsService.settings.customAccentColorHex)
        }
        switch self {
        case .dark:
            return Color(hex: "FF6B9D")
        case .pink:
            return Color(hex: "E85D75")
        case .lavender:
            return Color(hex: "8B5CF6")
        case .mint:
            return Color(hex: "10B981")
        case .ocean:
            return Color(hex: "3B82F6")
        case .sunset:
            return Color(hex: "F59E0B")
        case .pixel:
            return Color(hex: "22D3EE")
        case .sakura:
            return Color(hex: "FFB7C5")
        case .deepSea:
            return Color(hex: "00B4D8")
        case .forest:
            return Color(hex: "52B788")
        case .amber:
            return Color(hex: "F4A261")
        case .crimson:
            return Color(hex: "C77DFF")
        case .arctic:
            return Color(hex: "4A90D9")
        case .roseGold:
            return Color(hex: "E8956D")
        case .charcoal:
            return Color(hex: "A0A0A0")
        case .custom:
            return customColor(customHex: customHex)
        }
    }
    
    func iconGradient(customHex: String) -> [Color] {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            let accent = Color(hex: DependencyContainer.shared.settingsService.settings.customAccentColorHex)
            return [accent, accent.opacity(0.7)]
        }
        switch self {
        case .dark:
            return [Color(hex: "FF6B9D"), Color(hex: "C44FE2")]
        case .pink:
            return [Color(hex: "FFB6C1"), Color(hex: "E85D75")]
        case .lavender:
            return [Color(hex: "C4B5FD"), Color(hex: "8B5CF6")]
        case .mint:
            return [Color(hex: "6EE7B7"), Color(hex: "10B981")]
        case .ocean:
            return [Color(hex: "93C5FD"), Color(hex: "3B82F6")]
        case .sunset:
            return [Color(hex: "FCD34D"), Color(hex: "F59E0B")]
        case .pixel:
            return [Color(hex: "22D3EE"), Color(hex: "A78BFA")]
        case .sakura:
            return [Color(hex: "FFB7C5"), Color(hex: "FF91A8")]
        case .deepSea:
            return [Color(hex: "48CAE4"), Color(hex: "00B4D8")]
        case .forest:
            return [Color(hex: "95D5B2"), Color(hex: "52B788")]
        case .amber:
            return [Color(hex: "FFD166"), Color(hex: "F4A261")]
        case .crimson:
            return [Color(hex: "E2B0FF"), Color(hex: "C77DFF")]
        case .arctic:
            return [Color(hex: "74B0E8"), Color(hex: "4A90D9")]
        case .roseGold:
            return [Color(hex: "F2C4A8"), Color(hex: "E8956D")]
        case .charcoal:
            return [Color(hex: "D0D0D0"), Color(hex: "A0A0A0")]
        case .custom:
            let c = customColor(customHex: customHex)
            return [c, c.opacity(0.7)]
        }
    }
    
    func textColor(customHex: String) -> Color {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            return Color(hex: DependencyContainer.shared.settingsService.settings.customTextColorHex)
        }
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return .white
        case .pink:
            return Color(red: 0.25, green: 0.05, blue: 0.12)
        case .lavender:
            return Color(red: 0.18, green: 0.06, blue: 0.40)
        case .mint:
            return Color(red: 0.02, green: 0.31, blue: 0.23)
        case .ocean:
            return Color(red: 0.05, green: 0.29, blue: 0.43)
        case .sunset:
            return Color(red: 0.49, green: 0.18, blue: 0.07)
        case .sakura:
            return Color(red: 0.35, green: 0.08, blue: 0.15)
        case .arctic:
            return Color(red: 0.08, green: 0.18, blue: 0.32)
        case .custom:
            return isCustomDarkBackground(customHex: customHex)
                ? Color.white
                : Color(red: 0.06, green: 0.09, blue: 0.16)
        }
    }
    
    func secondaryTextColor(customHex: String) -> Color {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            return Color(hex: DependencyContainer.shared.settingsService.settings.customTextColorHex).opacity(0.7)
        }
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return Color(hex: "9A9AAB")
        case .pink:
            return Color(hex: "A75D74")
        case .lavender:
            return Color(hex: "6D28D9").opacity(0.8)
        case .mint:
            return Color(hex: "047857").opacity(0.8)
        case .ocean:
            return Color(hex: "0369A1").opacity(0.8)
        case .sunset:
            return Color(hex: "C2410C").opacity(0.8)
        case .sakura:
            return Color(hex: "C87890").opacity(0.8)
        case .arctic:
            return Color(hex: "4A6FA5").opacity(0.8)
        case .custom:
            return isCustomDarkBackground(customHex: customHex)
                ? Color(hex: "9CA3AF")
                : Color(hex: "475569")
        }
    }
    
    func cardBackgroundColor(customHex: String) -> Color {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            return Color(hex: DependencyContainer.shared.settingsService.settings.customCardBackgroundColorHex)
        }
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return Color.white.opacity(0.05)
        case .pink, .lavender, .mint, .ocean, .sunset, .sakura, .arctic:
            return Color.white.opacity(0.6)
        case .custom:
            return isCustomDarkBackground(customHex: customHex)
                ? Color.white.opacity(0.05)
                : Color.white.opacity(0.6)
        }
    }
    
    func buttonBackgroundColor(customHex: String) -> Color {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            return Color(hex: DependencyContainer.shared.settingsService.settings.customAccentColorHex).opacity(0.08)
        }
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return Color.white.opacity(0.08)
        case .pink:
            return Color(hex: "E85D75").opacity(0.08)
        case .lavender:
            return Color(hex: "8B5CF6").opacity(0.08)
        case .mint:
            return Color(hex: "10B981").opacity(0.08)
        case .ocean:
            return Color(hex: "3B82F6").opacity(0.08)
        case .sunset:
            return Color(hex: "F59E0B").opacity(0.08)
        case .sakura:
            return Color(hex: "FF91A8").opacity(0.08)
        case .arctic:
            return Color(hex: "4A90D9").opacity(0.08)
        case .custom:
            return accentColor(customHex: customHex).opacity(0.08)
        }
    }
    
    func isDarkTheme(customHex: String) -> Bool {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            let hex = DependencyContainer.shared.settingsService.settings.customBackgroundColorHex
            let (r, g, b) = Self.getRGB(from: hex)
            let MathLuminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            return MathLuminance < 0.55
        }
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return true
        case .custom:
            return isCustomDarkBackground(customHex: customHex)
        default:
            return false
        }
    }
    
    func borderColor(customHex: String) -> Color {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            return Color(hex: DependencyContainer.shared.settingsService.settings.customBorderColorHex)
        }
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return Color.white.opacity(0.12)
        case .pink:
            return Color(hex: "E85D75").opacity(0.15)
        case .lavender:
            return Color(hex: "8B5CF6").opacity(0.15)
        case .mint:
            return Color(hex: "10B981").opacity(0.15)
        case .ocean:
            return Color(hex: "3B82F6").opacity(0.15)
        case .sunset:
            return Color(hex: "F59E0B").opacity(0.15)
        case .sakura:
            return Color(hex: "FF91A8").opacity(0.15)
        case .arctic:
            return Color(hex: "4A90D9").opacity(0.15)
        case .custom:
            return accentColor(customHex: customHex).opacity(0.15)
        }
    }
    
    func dividerColor(customHex: String) -> Color {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            return Color(hex: DependencyContainer.shared.settingsService.settings.customDividerColorHex)
        }
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return Color.white.opacity(0.08)
        case .pink:
            return Color(hex: "E85D75").opacity(0.12)
        case .lavender:
            return Color(hex: "8B5CF6").opacity(0.12)
        case .mint:
            return Color(hex: "10B981").opacity(0.12)
        case .ocean:
            return Color(hex: "3B82F6").opacity(0.12)
        case .sunset:
            return Color(hex: "F59E0B").opacity(0.12)
        case .sakura:
            return Color(hex: "FF91A8").opacity(0.12)
        case .arctic:
            return Color(hex: "4A90D9").opacity(0.12)
        case .custom:
            return accentColor(customHex: customHex).opacity(0.12)
        }
    }
    
    func toggleOnColor(customHex: String) -> Color {
        return accentColor(customHex: customHex)
    }
    
    func toggleBackgroundColor(customHex: String) -> Color {
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return Color.white.opacity(0.15)
        default:
            return Color.gray.opacity(0.2)
        }
    }
    
    func primaryButtonBackground(customHex: String) -> Color {
        return accentColor(customHex: customHex).opacity(0.12)
    }
    
    func primaryButtonTextColor(customHex: String) -> Color {
        return accentColor(customHex: customHex)
    }
    
    func secondaryButtonBackground(customHex: String) -> Color {
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return Color.white.opacity(0.08)
        default:
            return Color.black.opacity(0.05)
        }
    }
    
    func destructiveButtonColor(customHex: String) -> Color {
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return Color(hex: "FF453A")
        default:
            return Color(hex: "DC2626")
        }
    }
    
    func iconColor(customHex: String) -> Color {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            return Color(hex: DependencyContainer.shared.settingsService.settings.customTextColorHex).opacity(0.6)
        }
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return .secondary
        default:
            return textColor(customHex: customHex).opacity(0.6)
        }
    }
    
    func hoverBackgroundColor(customHex: String) -> Color {
        if DependencyContainer.shared.settingsService.settings.godModeEnabled {
            return Color(hex: DependencyContainer.shared.settingsService.settings.customAccentColorHex).opacity(0.08)
        }
        switch self {
        case .dark, .pixel, .deepSea, .forest, .amber, .crimson, .roseGold, .charcoal:
            return Color.white.opacity(0.06)
        default:
            return accentColor(customHex: customHex).opacity(0.08)
        }
    }
}

struct StatusBarView: View {
    @StateObject private var viewModel = StatusBarViewModel()
    @ObservedObject private var pluginService = PluginService.shared
    @ObservedObject private var screenMedia = ScreenMediaHelper.shared
    let onShowMainWindow: () -> Void
    let onQuit: () -> Void
    var onScreenshotTriggered: (() -> Void)? = nil

    private var customDaysDisplayTitle: String? {
        let settings = DependencyContainer.shared.settingsService.settings
        var titleToUse: String? = nil
        
        // 优先使用上帝模式或自定义名称
        if settings.statusBarTextMode == .godMode || settings.statusBarTextMode == .customTitle {
            if let active = viewModel.anniversaryInfo?.anniversary, let custom = active.godModeCustomText, !custom.isEmpty {
                titleToUse = custom
            } else if !settings.customStatusBarText.isEmpty {
                titleToUse = settings.customStatusBarText
            }
        }
        
        if titleToUse == nil {
            // 回退到布局组件中的 customTitle
            let layouts = DependencyContainer.shared.componentLayoutService.currentLayouts
            if let layout = layouts.first(where: { $0.type == .daysDisplay }),
               let title = layout.customTitle, !title.isEmpty {
                titleToUse = title
            }
        }
        
        return titleToUse?.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "/n", with: "\n")
    }

    // 主题色选择
    @State private var themeColor: ThemeColor = .dark
    @State private var showThemePicker: Bool = false
    
    // 插件系统状态
    @State private var pluginRunningLogs = ""
    @State private var showLogsSheet = false
    @State private var showPluginConfig = false

    // 悬浮动效状态
    @State private var isDaysCardHovered = false
    @State private var isPreventSleepHovered = false
    @State private var isMainBtnHovered = false
    @State private var isQuitBtnHovered = false
    @State private var isThemeBtnHovered = false
    @State private var isAvatarHovered = false

    // Tab 导航
    @State private var selectedTab: StatusBarTab = .anniversary

    enum StatusBarTab: String, CaseIterable {
        case anniversary = "anniversary"
        case plugins = "plugins"
        case screenshot = "screenshot"
        case ide = "ide"

        var title: String {
            switch self {
            case .anniversary: return "纪念日"
            case .plugins: return "插件"
            case .screenshot: return "截图"
            case .ide: return "IDE"
            }
        }

        var icon: String {
            switch self {
            case .anniversary: return "calendar.badge.clock"
            case .plugins: return "puzzlepiece.extension.fill"
            case .screenshot: return "camera.viewfinder"
            case .ide: return "terminal.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header (avatar + days mini display + theme)
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            // Tab navigation
            tabNavigationBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider().padding(.horizontal, 16)

            // Tab content — macOS 不支持 .page TabViewStyle，用 Group+switch 实现
            Group {
                switch selectedTab {
                case .anniversary:
                    anniversaryTabContent
                case .plugins:
                    pluginsTabContent
                case .screenshot:
                    screenshotTabContent
                case .ide:
                    ideTabContent
                }
            }
            .frame(height: 330)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)

            Divider().padding(.horizontal, 16)

            // Fixed bottom buttons
            bottomButtons
                .padding(16)

            // Theme picker
            if showThemePicker {
                themeColorPicker
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
        .frame(width: 340)
        .background(themeColor.animeOrBackground)
        .preferredColorScheme(themeColor.animeOrIsDark ? .dark : .light)
        .tint(themeColor.animeOrAccent)
        .accentColor(themeColor.animeOrAccent)
        .onAppear {
            viewModel.onAppear()
            themeColor = DependencyContainer.shared.settingsService.settings.selectedThemeColor
        }
        .onDisappear { viewModel.onDisappear() }
        .onReceive(viewModel.$themeColor) { newTheme in
            if themeColor != newTheme {
                withAnimation(.easeInOut(duration: 0.25)) {
                    themeColor = newTheme
                }
            }
        }
        .interactiveClickEffect()
    }

    // MARK: - Tab 导航栏

    private var tabNavigationBar: some View {
        HStack(spacing: 4) {
            ForEach(StatusBarTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 10))
                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(selectedTab == tab ? (themeColor.animeOrIsDark ? Color.black : Color.white) : themeColor.animeOrTextPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(selectedTab == tab ? themeColor.animeOrAccent : themeColor.animeOrButton)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - 纪念日 Tab

    private var anniversaryTabContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if let info = viewModel.anniversaryInfo {
                    daysPreview(info: info, countdown: viewModel.shortCountdown)
                        .padding(12)
                    Divider().padding(.horizontal, 12)
                }
                preventSleepSection
                    .padding(12)
            }
        }
    }

    // MARK: - 插件 Tab

    private var pluginsTabContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                // 插件区头部（含日志 + IDE入口 + 配置按钮）
                HStack(spacing: 6) {
                    Text("🔌 YumiScript")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor.animeOrTextPrimary)

                    Spacer()

                    Button(action: {
                        YumiScriptIDEManager.shared.open(plugin: nil)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 8))
                            Text("IDE")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(themeColor.animeOrAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(themeColor.animeOrAccent.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    .help("打开 YumiScript Studio 可视化 IDE 编辑器")

                    if !pluginRunningLogs.isEmpty {
                        Button(action: { showLogsSheet = true }) {
                            HStack(spacing: 2) {
                                Circle().fill(Color.green).frame(width: 5, height: 5)
                                Text("查看日志")
                                    .font(.system(size: 9))
                                    .foregroundStyle(themeColor.animeOrAccent)
                            }
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showLogsSheet) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("YumiScript 运行日志")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.top, 8)
                                ScrollView {
                                    Text(pluginRunningLogs)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .padding(8)
                                }
                                .frame(width: 260, height: 180)
                            }
                        }
                    }

                    Button(action: { showPluginConfig.toggle() }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 10))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showPluginConfig, arrowEdge: .trailing) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("状态栏插件显示控制")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.bottom, 2)

                            Picker("显示模版", selection: Binding(
                                get: { pluginService.activeLayoutPreset },
                                set: { preset in pluginService.applyPreset(preset) }
                            )) {
                                ForEach(PluginLayoutPreset.allCases) { preset in
                                    Text(preset.displayName).tag(preset)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.system(size: 10))

                            Divider()

                            Picker("快速启动显示", selection: Binding(
                                get: { DependencyContainer.shared.settingsService.settings.quickLaunchDisplayMode },
                                set: { mode in
                                    var settings = DependencyContainer.shared.settingsService.settings
                                    settings.quickLaunchDisplayMode = mode
                                    DependencyContainer.shared.settingsService.updateSettings(settings)
                                }
                            )) {
                                ForEach(QuickLaunchDisplayMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.system(size: 10))

                            Picker("图标大小", selection: Binding(
                                get: { DependencyContainer.shared.settingsService.settings.quickLaunchIconSize },
                                set: { size in
                                    var settings = DependencyContainer.shared.settingsService.settings
                                    settings.quickLaunchIconSize = size
                                    DependencyContainer.shared.settingsService.updateSettings(settings)
                                }
                            )) {
                                ForEach(QuickLaunchIconSize.allCases) { size in
                                    Text(size.displayName).tag(size)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.system(size: 10))

                            Toggle(isOn: Binding(
                                get: { viewModel.allowMultipleInstances },
                                set: { _ in viewModel.toggleAllowMultipleInstances() }
                            )) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.stack.3d.up")
                                        .font(.system(size: 10))
                                        .frame(width: 14)
                                    Text("允许多开应用")
                                        .font(.system(size: 11))
                                }
                            }
                            .toggleStyle(ThemedToggleStyle(width: 32, height: 18))

                            Divider()

                            Toggle(isOn: Binding(
                                get: { pluginService.showQuickLaunchSection },
                                set: { _ in pluginService.toggleQuickLaunchSection() }
                            )) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 10))
                                        .frame(width: 14)
                                    Text("快速启动应用")
                                        .font(.system(size: 11))
                                }
                            }
                            .toggleStyle(ThemedToggleStyle(width: 32, height: 18))

                            Toggle(isOn: Binding(
                                get: { pluginService.showCustomPluginsSection },
                                set: { _ in pluginService.toggleCustomPluginsSection() }
                            )) {
                                HStack(spacing: 6) {
                                    Image(systemName: "puzzlepiece.extension")
                                        .font(.system(size: 10))
                                        .frame(width: 14)
                                    Text("扩展插件")
                                        .font(.system(size: 11))
                                }
                            }
                            .toggleStyle(ThemedToggleStyle(width: 32, height: 18))

                            Divider()

                            if !pluginService.customPlugins.isEmpty {
                                Text("单个插件状态栏显示")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(pluginService.customPlugins) { plugin in
                                    Toggle(isOn: Binding(
                                        get: { pluginService.isVisibleInStatusBar(pluginId: plugin.id) },
                                        set: { newVal in pluginService.setVisibility(pluginId: plugin.id, visible: newVal) }
                                    )) {
                                        Text(plugin.name)
                                            .font(.system(size: 10))
                                            .foregroundStyle(plugin.isEnabled ? .primary : .secondary)
                                    }
                                    .toggleStyle(ThemedToggleStyle(width: 32, height: 18))
                                    .disabled(!plugin.isEnabled)
                                }
                            }

                            Divider()

                            HStack(spacing: 8) {
                                Button("全部显示") {
                                    pluginService.showQuickLaunchSection = true
                                    pluginService.showCustomPluginsSection = true
                                    for plugin in pluginService.customPlugins {
                                        pluginService.setVisibility(pluginId: plugin.id, visible: true)
                                    }
                                    pluginService.saveVisibilitySettings()
                                }
                                .font(.system(size: 10))
                                .buttonStyle(.bordered)

                                Button("全部隐藏") {
                                    pluginService.showQuickLaunchSection = false
                                    pluginService.showCustomPluginsSection = false
                                    for plugin in pluginService.customPlugins {
                                        pluginService.setVisibility(pluginId: plugin.id, visible: false)
                                    }
                                    pluginService.saveVisibilitySettings()
                                }
                                .font(.system(size: 10))
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(14)
                        .frame(width: 240)
                    }
                }
                .padding(.horizontal, 4)

                // 快速启动应用列表
                if pluginService.showQuickLaunchSection && !pluginService.quickLaunchApps.isEmpty {
                    let displayMode = DependencyContainer.shared.settingsService.settings.quickLaunchDisplayMode
                    let iconSize = DependencyContainer.shared.settingsService.settings.quickLaunchIconSize
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🚀 快速启动")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(themeColor.animeOrTextSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(pluginService.quickLaunchApps) { app in
                                    Button(action: {
                                        Task {
                                            let logs = await YumiScriptEngine.execute("launch \"\(app.name)\"")
                                            pluginRunningLogs = logs
                                        }
                                    }) {
                                        HStack(spacing: 3) {
                                            if displayMode != .nameOnly {
                                                if let iconName = app.iconName {
                                                    AppIconImageView(appName: app.name, iconName: iconName, size: iconSize.sizeValue, bundlePath: app.bundlePath)
                                                } else {
                                                    Image(systemName: "arrow.up.right.square")
                                                        .font(.system(size: iconSize.sizeValue * 0.75))
                                                }
                                            }
                                            if displayMode != .iconOnly {
                                                Text(app.name)
                                                    .font(.system(size: iconSize.fontValue, weight: .medium))
                                            }
                                        }
                                        .foregroundStyle(themeColor.animeOrTextPrimary)
                                        .padding(.horizontal, iconSize == .large ? 10 : 8)
                                        .padding(.vertical, iconSize == .large ? 6 : 4)
                                        .background(Capsule().fill(themeColor.animeOrButton))
                                        .overlay(Capsule().stroke(themeColor.animeOrBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .modifier(TooltipModifier(text: app.name))
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // 自定义插件列表
                if pluginService.showCustomPluginsSection {
                    let activePlugins = pluginService.customPlugins.filter {
                        $0.isEnabled && pluginService.isVisibleInStatusBar(pluginId: $0.id)
                    }
                    if !activePlugins.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("🧩 扩展插件")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(themeColor.animeOrTextSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(activePlugins) { plugin in
                                        Button(action: {
                                            Task {
                                                let logs = await YumiScriptEngine.execute(plugin.scriptContent)
                                                pluginRunningLogs = logs
                                                // 从日志中提取"成功/失败"关键字，给用户弹一条简短通知
                                                let succeeded = logs.contains("成功")
                                                    || logs.contains("完成")
                                                    || logs.contains("已启动")
                                                let failed = logs.contains("失败")
                                                    || logs.contains("错误")
                                                    || logs.contains("拒绝")
                                                if succeeded && !failed {
                                                    Self.showQuickNotify(
                                                        title: "✅ \(plugin.name)",
                                                        body: "已执行完成"
                                                    )
                                                } else if failed {
                                                    Self.showQuickNotify(
                                                        title: "⚠️ \(plugin.name)",
                                                        body: "执行失败，点击查看日志"
                                                    )
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 3) {
                                                SafeSFSymbolView(plugin.icon, fallback: "bolt.fill")
                                                    .font(.system(size: 9))
                                                Text(plugin.name)
                                                    .font(.system(size: 10, weight: .medium))
                                            }
                                            .foregroundStyle(themeColor.animeOrTextPrimary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(themeColor.animeOrButton))
                                            .overlay(Capsule().stroke(themeColor.animeOrBorder, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .modifier(TooltipModifier(text: plugin.description.isEmpty ? plugin.name : plugin.description))
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(12)
        }
    }

    // MARK: - 截图 Tab

    private var screenshotTabContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // 截图按钮网格
                VStack(alignment: .leading, spacing: 6) {
                    Text("截图")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                        .padding(.horizontal, 4)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        screenshotButton(title: "区域截图", icon: "square.dashed", action: {
                            onScreenshotTriggered?()
                            ScreenMediaHelper.shared.captureArea()
                        })
                        screenshotButton(title: "全屏截图", icon: "rectangle.on.rectangle", action: {
                            onScreenshotTriggered?()
                            ScreenMediaHelper.shared.captureFullscreen()
                        })
                        screenshotButton(title: "多屏截图", icon: "rectangle.split.2x2", action: {
                            onScreenshotTriggered?()
                            ScreenMediaHelper.shared.captureAllScreens()
                        })
                        screenshotButton(title: "标注工具", icon: "pencil.tip.crop.circle", action: {
                            onScreenshotTriggered?()
                            ScreenMediaHelper.shared.openScreenshotAnnotation()
                        })
                        screenshotButton(title: "TouchBar 截图", icon: "rectangle.bottomthird.inset.filled", action: {
                            onScreenshotTriggered?()
                            ScreenMediaHelper.shared.captureTouchBar()
                        })
                        Color.clear
                            .frame(height: 1)
                    }

                    // TouchBar 截图机型提示（2020 以后机型自带 TouchBar 的不多，给个一键确认按钮）
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                        Text("TouchBar 仅 2016–2020 款带 Touch Bar 的 MacBook 支持；其他机型会直接提示无 TouchBar。")
                            .font(.system(size: 9))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 4)
                }

                Divider().padding(.horizontal, 4)

                // 录屏
                VStack(alignment: .leading, spacing: 6) {
                    Text("录屏")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                        .padding(.horizontal, 4)

                    if screenMedia.isRecording {
                        Button(action: { ScreenMediaHelper.shared.stopRecording() }) {
                            HStack {
                                Image(systemName: "stop.circle.fill").foregroundStyle(.red)
                                Text("停止录屏").font(.system(size: 11, weight: .medium))
                                Spacer()
                                Circle().fill(.red).frame(width: 6, height: 6).opacity(0.8)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.red.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: { ScreenMediaHelper.shared.startRecording() }) {
                            HStack {
                                Image(systemName: "record.circle")
                                Text("开始录屏").font(.system(size: 11, weight: .medium))
                                Spacer()
                            }
                            .foregroundStyle(themeColor.animeOrTextPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrButton))
                        }
                        .buttonStyle(.plain)
                    }

                    // 授权诊断（解决"明明开了开关但提示未授权"）
                    Button(action: { Task { await TCCDiagnostic.showScreenCaptureDiagnostic() } }) {
                        HStack {
                            Image(systemName: "stethoscope.circle")
                            Text("诊断授权状态").font(.system(size: 11, weight: .medium))
                            Spacer()
                        }
                        .foregroundStyle(themeColor.animeOrTextPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrButton))
                    }
                    .buttonStyle(.plain)

                    Button(action: { TCCDiagnostic.openScreenCaptureSettings() }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("打开屏幕录制设置").font(.system(size: 11, weight: .medium))
                            Spacer()
                        }
                        .foregroundStyle(themeColor.animeOrTextPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrButton))
                    }
                    .buttonStyle(.plain)
                }

                Divider().padding(.horizontal, 4)

                // 设置
                VStack(alignment: .leading, spacing: 8) {
                    Text("设置")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                        .padding(.horizontal, 4)

                    HStack {
                        Text("全局快捷键")
                            .font(.system(size: 11))
                            .foregroundStyle(themeColor.animeOrTextPrimary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { DependencyContainer.shared.settingsService.settings.screenshotHotkeyPreset },
                            set: { preset in
                                var settings = DependencyContainer.shared.settingsService.settings
                                settings.screenshotHotkeyPreset = preset
                                DependencyContainer.shared.settingsService.updateSettings(settings)
                                GlobalHotkeyManager.shared.setupHotkey(preset: preset)
                            }
                        )) {
                            ForEach(ScreenshotHotkeyPreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 11))
                        .frame(width: 130)
                    }

                    HStack {
                        Text("输出模式")
                            .font(.system(size: 11))
                            .foregroundStyle(themeColor.animeOrTextPrimary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { DependencyContainer.shared.settingsService.settings.screenshotOutputMode },
                            set: { mode in
                                var settings = DependencyContainer.shared.settingsService.settings
                                settings.screenshotOutputMode = mode
                                DependencyContainer.shared.settingsService.updateSettings(settings)
                            }
                        )) {
                            ForEach(ScreenshotOutputMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .font(.system(size: 9))
                    }
                }
            }
            .padding(12)
        }
    }

    // MARK: - IDE Tab

    private var ideTabContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // IDE 快捷大卡片
                Button(action: {
                    YumiScriptIDEManager.shared.open(plugin: nil)
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeColor.animeOrAccent.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(themeColor.animeOrAccent)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("YumiScript Studio")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(themeColor.animeOrTextPrimary)
                                Text("IDE")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(themeColor.animeOrAccent)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(themeColor.animeOrAccent.opacity(0.15)))
                            }
                            Text("多色语法编辑器 · 动作积木库 · Tab 补全")
                                .font(.system(size: 10))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(themeColor.animeOrAccent)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeColor.animeOrCardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeColor.animeOrAccent.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // 快捷操作
                HStack(spacing: 8) {
                    Button(action: {
                        YumiScriptIDEManager.shared.open(plugin: nil, isCreating: true)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(themeColor.animeOrAccent)
                            Text("新建插件脚本")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(themeColor.animeOrTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrButton))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeColor.animeOrBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if let first = pluginService.customPlugins.first {
                            YumiScriptIDEManager.shared.open(plugin: first)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .foregroundStyle(pluginService.customPlugins.isEmpty ? themeColor.animeOrTextSecondary : themeColor.animeOrAccent)
                            Text("管理与编辑")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(pluginService.customPlugins.isEmpty ? themeColor.animeOrTextSecondary : themeColor.animeOrTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrButton))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeColor.animeOrBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(pluginService.customPlugins.isEmpty)
                }
                
                Divider().padding(.horizontal, 4)
                
                // 脚本列表预览
                VStack(alignment: .leading, spacing: 6) {
                    Text("我的插件脚本 (\(pluginService.customPlugins.count))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                        .padding(.horizontal, 4)
                    
                    ForEach(pluginService.customPlugins) { plugin in
                        HStack(spacing: 8) {
                            SafeSFSymbolView(plugin.icon, fallback: "bolt.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(themeColor.animeOrAccent)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(plugin.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(themeColor.animeOrTextPrimary)
                                Text(plugin.description.isEmpty ? "自定义 YumiScript 自动化" : plugin.description)
                                    .font(.system(size: 9))
                                    .foregroundStyle(themeColor.animeOrTextSecondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                YumiScriptIDEManager.shared.open(plugin: plugin)
                            }) {
                                Text("IDE编辑")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(themeColor.animeOrAccent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(themeColor.animeOrAccent.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrButton))
                    }
                }
            }
            .padding(12)
        }
    }

    private func screenshotButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(themeColor.animeOrTextPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrButton))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeColor.animeOrBorder.opacity(0.5), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 主题色切换按钮

    private var themeToggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showThemePicker.toggle()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: themeColor.themeIcon)
                    .font(.system(size: 10))
                Circle()
                    .fill(themeColor.animeOrAccent)
                    .frame(width: 8, height: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .medium))
                    .rotationEffect(.degrees(showThemePicker ? 180 : 0))
            }
            .foregroundStyle(themeColor.animeOrAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(themeColor.animeOrButton)
            )
            .overlay(
                Capsule()
                    .stroke(themeColor.animeOrBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isThemeBtnHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isThemeBtnHovered)
        .onHover { isThemeBtnHovered = $0 }
        .help("切换主题色")
    }

    // MARK: - 底部主题色选择器

    private var themeColorPicker: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("选择主题")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(themeColor.animeOrTextSecondary)

                if AnimeThemeService.shared.isEnabled {
                    Text("(二次元主题已生效，选择已禁用)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Color(hex: "FF6B9D"))
                }
            }

            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ThemeColor.allCases) { theme in
                    ThemeColorButton(
                        theme: theme,
                        isSelected: themeColor == theme,
                        action: {
                            guard !AnimeThemeService.shared.isEnabled else { return }
                            withAnimation(.easeInOut(duration: 0.25)) {
                                themeColor = theme
                                saveThemeColor(theme)
                            }
                            if theme != .custom {
                                // 选择非自定义主题后延迟隐藏
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showThemePicker = false
                                    }
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 2)
            .disabled(AnimeThemeService.shared.isEnabled)
            .opacity(AnimeThemeService.shared.isEnabled ? 0.45 : 1.0)
            
            // 如果是自定义主题，显示 HEX 输入框和 ColorPicker
            if themeColor == .custom {
                VStack(spacing: 8) {
                    Divider()
                        .background(themeColor.animeOrDivider)
                        .padding(.vertical, 2)
                    
                    HStack(spacing: 8) {
                        Text("自定义 HEX")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(themeColor.animeOrTextPrimary)
                        
                        Spacer()
                        
                        TextField("#HEX", text: Binding(
                            get: {
                                DependencyContainer.shared.settingsService.settings.customThemeColorHex
                            },
                            set: { newValue in
                                var hex = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !hex.hasPrefix("#") && hex.count == 6 {
                                    hex = "#" + hex
                                }
                                let pattern = "^#?[0-9a-fA-F]{6}$"
                                if hex.range(of: pattern, options: .regularExpression) != nil {
                                    let cleanHex = hex.replacingOccurrences(of: "#", with: "")
                                    saveCustomThemeColorHex(cleanHex)
                                    themeColor = .custom
                                }
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(themeColor.animeOrTextPrimary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(themeColor.animeOrBorder, lineWidth: 1)
                        )
                        .frame(width: 80)
                        .foregroundStyle(themeColor.animeOrTextPrimary)
                        
                        ColorPicker("", selection: Binding(
                            get: {
                                themeColor.customColor
                            },
                            set: { newColor in
                                if let hex = newColor.toHex(), !Color.isHexClose(hex, DependencyContainer.shared.settingsService.settings.customThemeColorHex) {
                                    saveCustomThemeColorHex(hex)
                                    withAnimation {
                                        themeColor = .custom
                                    }
                                }
                            }
                        ))
                        .labelsHidden()
                        .frame(width: 24, height: 24)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColor.animeOrCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.animeOrBorder, lineWidth: 1)
        )
    }

    /// 保存主题色到 AppSettings
    private func saveThemeColor(_ theme: ThemeColor) {
        var settings = DependencyContainer.shared.settingsService.settings
        settings.selectedThemeColor = theme
        settings.mainWindowThemeColor = theme
        DependencyContainer.shared.settingsService.updateSettings(settings)
        DependencyContainer.shared.anniversaryService.forceSyncAndReloadWidget()
    }
    
    /// 保存自定义主题色 Hex
    private func saveCustomThemeColorHex(_ hex: String) {
        var settings = DependencyContainer.shared.settingsService.settings
        settings.customThemeColorHex = hex
        settings.customMainWindowThemeColorHex = hex
        settings.selectedThemeColor = .custom
        settings.mainWindowThemeColor = .custom
        DependencyContainer.shared.settingsService.updateSettings(settings)
        DependencyContainer.shared.anniversaryService.forceSyncAndReloadWidget()
    }
    
    // MARK: - 头部
    
    private var headerView: some View {
        HStack(spacing: 10) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: themeColor.animeOrGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                if let customImage = NSImage(named: "YumikoToys") {
                    Image(nsImage: customImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: "rabbit.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                // 标题行
                if let customTitle = customDaysDisplayTitle {
                    Text(customTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(themeColor.animeOrTextPrimary)
                        .lineLimit(viewModel.anniversaryInfo?.anniversary.allowMultiline == true ? nil : 1)
                } else {
                    Text(AppConfig.appName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(themeColor.animeOrTextPrimary)
                        .lineLimit(viewModel.anniversaryInfo?.anniversary.allowMultiline == true ? nil : 1)
                }

                // 宠物选择器 + 版本号（共享）
                petSelectorRow
            }
            
            Spacer()
            
            // 主题切换按钮
            themeToggleButton
            
            // 状态指示器
            if viewModel.isPreventSleepEnabled {
                Circle()
                    .fill(themeColor.animeOrAccent)
                    .frame(width: 8, height: 8)
                    .shadow(color: themeColor.animeOrAccent.opacity(0.5), radius: 4)
            }
        }
    }

    /// 宠物选择器 + 版本号行（headerView 共享子视图）
    private var petSelectorRow: some View {
        HStack(spacing: 6) {
            // 宠物选择 — 仅文字 + 极细 chevron，不叠加多余箭头
            Menu {
                ForEach(viewModel.anniversaries) { ann in
                    Button {
                        viewModel.setActiveAnniversary(id: ann.id)
                    } label: {
                        if ann.id == viewModel.anniversaryInfo?.anniversary.id {
                            Label(ann.displayPetName, systemImage: "checkmark")
                        } else {
                            Text(ann.displayPetName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text("🥕")
                        .font(.system(size: 9))
                    Text(viewModel.anniversaryInfo?.anniversary.displayPetName ?? "可可皇后")
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .foregroundStyle(themeColor.animeOrAccent)
                .background(
                    Capsule()
                        .fill(themeColor.animeOrAccent.opacity(0.08))
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Text("v\(AppConfig.version)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(themeColor.animeOrAccent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(themeColor.animeOrAccent.opacity(0.12)))
                .lineLimit(1)
        }
    }

    // MARK: - 天数预览
    
    private func daysPreview(info: AnniversaryInfo, countdown: String) -> some View {
        VStack(spacing: 10) {
            // 标题
            HStack(spacing: 6) {
                PixelAvatarView(emoji: info.anniversary.displayAvatar, size: 20)
                    .scaleEffect(isAvatarHovered ? 1.25 : 1.0)
                    .rotationEffect(.degrees(isAvatarHovered ? 12 : 0))
                    .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isAvatarHovered)
                    .onHover { isAvatarHovered = $0 }
                
                Text(customDaysDisplayTitle ?? info.anniversary.displayPetName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // 天数（支持字号和内容自适应缩放）
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.3f", info.calculation.totalDays))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6) // 避免天数过长时换行或被截断
                    .lineLimit(1)
                    .foregroundStyle(
                        LinearGradient(
                            colors: themeColor.animeOrGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("天")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(themeColor.animeOrTextSecondary)
                
                Spacer()
            }
            
            // 倒计时
            Text(countdown)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(themeColor.animeOrTextSecondary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            // 纪念日里程碑列表 (100, 180, 300天及周年里程碑展示)
            if !info.milestones.isEmpty {
                Divider()
                    .background(themeColor.animeOrDivider)
                    .padding(.vertical, 4)
                
                VStack(spacing: 6) {
                    ForEach(info.milestones) { milestone in
                        HStack(spacing: 6) {
                            Text(milestone.icon)
                                .font(.system(size: 11))
                            
                            Text(milestone.label)
                                .font(.system(size: 10))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Spacer()
                            
                            Text(milestone.formattedDate)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(themeColor.animeOrTextPrimary.opacity(0.8))
                                .frame(width: 75, alignment: .leading)
                            
                            Text("(\(milestone.countDisplay))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(themeColor.animeOrAccent)
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColor.animeOrCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: themeColor.animeOrGradient.map { $0.opacity(0.8) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isDaysCardHovered ? 1.015 : 1.0)
        .shadow(color: themeColor.animeOrAccent.opacity(isDaysCardHovered ? 0.12 : 0.0), radius: 8)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isDaysCardHovered)
        .onHover { isDaysCardHovered = $0 }
    }
    
    // MARK: - 防休眠开关
    
    private var preventSleepSection: some View {
        Button(action: {
            viewModel.togglePreventSleep()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.isPreventSleepEnabled ? themeColor.animeOrAccent.opacity(0.15) : themeColor.animeOrSecondaryButton)
                        .frame(width: 36, height: 36)
                    
                    PixelArtIconView(
                        function: .settings,
                        style: viewModel.uiIconStyle,
                        size: 18
                    )
                    .foregroundStyle(viewModel.isPreventSleepEnabled ? themeColor.animeOrAccent : themeColor.animeOrIcon)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("不休眠模式")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(themeColor.animeOrTextPrimary)
                        .lineLimit(1)
                    
                    Text(viewModel.isPreventSleepEnabled ? "已开启" : "已关闭")
                        .font(.caption2)
                        .foregroundStyle(viewModel.isPreventSleepEnabled ? themeColor.animeOrAccent : themeColor.animeOrTextSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { viewModel.isPreventSleepEnabled },
                    set: { _ in viewModel.togglePreventSleep() }
                ))
                .toggleStyle(ThemedToggleStyle(width: 34, height: 20))
                .labelsHidden()
                .allowsHitTesting(false) // 【核心修复】阻断 Toggle 本身对鼠标的响应，统一由外层整行手势接管，消除冲突 [1]
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPreventSleepHovered ? themeColor.animeOrHover : Color.clear)
            )
            .scaleEffect(isPreventSleepHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPreventSleepHovered)
            .onHover { isPreventSleepHovered = $0 }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 底部按钮
    
    private var bottomButtons: some View {
        HStack(spacing: 12) {
            Button(action: onShowMainWindow) {
                HStack(spacing: 6) {
                    PixelArtIconView(
                        function: .anniversary,
                        style: viewModel.uiIconStyle,
                        size: 14
                    )
                    Text("主界面")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .foregroundStyle(themeColor.animeOrTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColor.animeOrSecondaryButton)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeColor.animeOrBorder, lineWidth: 1)
                )
                .scaleEffect(isMainBtnHovered ? 1.03 : 1.0)
                .shadow(color: themeColor.animeOrAccent.opacity(isMainBtnHovered ? 0.35 : 0.0), radius: 6)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isMainBtnHovered)
                .onHover { isMainBtnHovered = $0 }
            }
            .buttonStyle(.plain)
            
            Button(action: onQuit) {
                HStack(spacing: 6) {
                    PixelArtIconView(
                        function: .quit,
                        style: viewModel.uiIconStyle,
                        size: 14
                    )
                    Text("退出")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                .foregroundStyle(themeColor.destructiveButtonColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColor.destructiveButtonColor.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeColor.destructiveButtonColor.opacity(0.2), lineWidth: 1)
                )
                .scaleEffect(isQuitBtnHovered ? 1.03 : 1.0)
                .shadow(color: themeColor.destructiveButtonColor.opacity(isQuitBtnHovered ? 0.25 : 0.0), radius: 6)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isQuitBtnHovered)
                .onHover { isQuitBtnHovered = $0 }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - 插件系统 UI
    
    private var pluginsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // MARK: 插件区头部（含日志 + 配置按钮）
            HStack(spacing: 6) {
                Text("🔌 YumiScript 插件系统")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor.animeOrTextPrimary)
                
                Spacer()
                
                if !pluginRunningLogs.isEmpty {
                    Button(action: { showLogsSheet = true }) {
                        HStack(spacing: 2) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text("查看日志")
                                .font(.system(size: 9))
                                .foregroundStyle(themeColor.animeOrAccent)
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showLogsSheet) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("YumiScript 运行日志")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.top, 8)
                            ScrollView {
                                Text(pluginRunningLogs)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(8)
                            }
                            .frame(width: 260, height: 180)
                        }
                    }
                }
                
                // ⚙️ 显示配置按钮
                Button(action: { showPluginConfig.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPluginConfig, arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("状态栏插件显示控制")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.bottom, 2)
                        
                        Picker("显示模版", selection: Binding(
                            get: { pluginService.activeLayoutPreset },
                            set: { preset in pluginService.applyPreset(preset) }
                        )) {
                            ForEach(PluginLayoutPreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                             }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 10))
                        
                        Divider()
                        
                        // 快速启动显示模式
                        Picker("快速启动显示", selection: Binding(
                            get: { DependencyContainer.shared.settingsService.settings.quickLaunchDisplayMode },
                            set: { mode in
                                var settings = DependencyContainer.shared.settingsService.settings
                                settings.quickLaunchDisplayMode = mode
                                DependencyContainer.shared.settingsService.updateSettings(settings)
                            }
                        )) {
                            ForEach(QuickLaunchDisplayMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 10))
                        
                        // 截图输出模式
                        Picker("截图输出", selection: Binding(
                            get: { DependencyContainer.shared.settingsService.settings.screenshotOutputMode },
                            set: { mode in
                                var settings = DependencyContainer.shared.settingsService.settings
                                settings.screenshotOutputMode = mode
                                DependencyContainer.shared.settingsService.updateSettings(settings)
                            }
                        )) {
                            ForEach(ScreenshotOutputMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .font(.system(size: 9))
                        
                        // 允许多开
                        Toggle(isOn: Binding(
                            get: { viewModel.allowMultipleInstances },
                            set: { _ in viewModel.toggleAllowMultipleInstances() }
                        )) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.stack.3d.up")
                                    .font(.system(size: 10))
                                    .frame(width: 14)
                                Text("允许多开应用")
                                    .font(.system(size: 11))
                            }
                        }
                        .toggleStyle(ThemedToggleStyle(width: 32, height: 18))
                        
                        Divider()
                        
                        // 内置快捷操作区
                        Toggle(isOn: Binding(
                            get: { pluginService.showBuiltinQuickActions },
                            set: { _ in pluginService.toggleBuiltinQuickActions() }
                        )) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.system(size: 10))
                                    .frame(width: 14)
                                Text("截图工具（区域/全屏/录屏）")
                                    .font(.system(size: 11))
                            }
                        }
                        .toggleStyle(ThemedToggleStyle(width: 32, height: 18))
                        
                        // 快速启动区
                        Toggle(isOn: Binding(
                            get: { pluginService.showQuickLaunchSection },
                            set: { _ in pluginService.toggleQuickLaunchSection() }
                        )) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                    .frame(width: 14)
                                Text("快速启动应用")
                                    .font(.system(size: 11))
                            }
                        }
                        .toggleStyle(ThemedToggleStyle(width: 32, height: 18))
                        
                        // 自定义插件区
                        Toggle(isOn: Binding(
                            get: { pluginService.showCustomPluginsSection },
                            set: { _ in pluginService.toggleCustomPluginsSection() }
                        )) {
                            HStack(spacing: 6) {
                                Image(systemName: "puzzlepiece.extension")
                                    .font(.system(size: 10))
                                    .frame(width: 14)
                                Text("扩展插件")
                                    .font(.system(size: 11))
                            }
                        }
                        .toggleStyle(ThemedToggleStyle(width: 32, height: 18))
                        
                        Divider()
                        
                        // 单个插件的可见性控制
                        if !pluginService.customPlugins.isEmpty {
                            Text("单个插件状态栏显示")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            ForEach(pluginService.customPlugins) { plugin in
                                Toggle(isOn: Binding(
                                    get: { pluginService.isVisibleInStatusBar(pluginId: plugin.id) },
                                    set: { newVal in pluginService.setVisibility(pluginId: plugin.id, visible: newVal) }
                                )) {
                                    Text(plugin.name)
                                        .font(.system(size: 10))
                                        .foregroundStyle(plugin.isEnabled ? .primary : .secondary)
                                }
                                .toggleStyle(ThemedToggleStyle(width: 32, height: 18))
                                .disabled(!plugin.isEnabled)
                            }
                        }
                        
                        Divider()
                        
                        // 全部隐藏/全部显示
                        HStack(spacing: 8) {
                            Button("全部显示") {
                                pluginService.showBuiltinQuickActions = true
                                pluginService.showQuickLaunchSection = true
                                pluginService.showCustomPluginsSection = true
                                for plugin in pluginService.customPlugins {
                                    pluginService.setVisibility(pluginId: plugin.id, visible: true)
                                }
                                pluginService.saveVisibilitySettings()
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.bordered)
                            
                            Button("全部隐藏") {
                                pluginService.showBuiltinQuickActions = false
                                pluginService.showQuickLaunchSection = false
                                pluginService.showCustomPluginsSection = false
                                for plugin in pluginService.customPlugins {
                                    pluginService.setVisibility(pluginId: plugin.id, visible: false)
                                }
                                pluginService.saveVisibilitySettings()
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(14)
                    .frame(width: 240)
                }
            }
            
            // MARK: 内置快捷操作（截图/录屏）
            if pluginService.showBuiltinQuickActions {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("📸 截图工具")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                        
                        Spacer()
                        
                        // 显示当前快捷键
                        let hotkeyPreset = DependencyContainer.shared.settingsService.settings.screenshotHotkeyPreset
                        if hotkeyPreset != .none {
                            Text(hotkeyPreset.displayName)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(themeColor.animeOrBorder.opacity(0.3)))
                        }
                    }
                    
                    // 截图模式按钮行
                    HStack(spacing: 4) {
                        // 区域截图
                        Button(action: {
                            onScreenshotTriggered?()
                            ScreenMediaHelper.shared.captureArea()
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "square.dashed")
                                    .font(.system(size: 11))
                                Text("区域")
                                    .font(.system(size: 8, weight: .medium))
                            }
                            .foregroundStyle(themeColor.animeOrTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton))
                        }
                        .buttonStyle(.plain)
                        .help("区域截图 (快捷键)")
                        
                        // 全屏截图
                        Button(action: {
                            onScreenshotTriggered?()
                            ScreenMediaHelper.shared.captureFullscreen()
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "rectangle.on.rectangle")
                                    .font(.system(size: 11))
                                Text("全屏")
                                    .font(.system(size: 8, weight: .medium))
                            }
                            .foregroundStyle(themeColor.animeOrTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton))
                        }
                        .buttonStyle(.plain)
                        
                        // TouchBar 截图
                        Button(action: {
                            onScreenshotTriggered?()
                            ScreenMediaHelper.shared.captureTouchBar()
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "rectangle.dashed")
                                    .font(.system(size: 11))
                                Text("TouchBar")
                                    .font(.system(size: 8, weight: .medium))
                            }
                            .foregroundStyle(themeColor.animeOrTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton))
                        }
                        .buttonStyle(.plain)
                        
                        // 多屏截图
                        Button(action: {
                            onScreenshotTriggered?()
                            ScreenMediaHelper.shared.captureAllScreens()
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "rectangle.split.2x2")
                                    .font(.system(size: 11))
                                Text("多屏")
                                    .font(.system(size: 8, weight: .medium))
                            }
                            .foregroundStyle(themeColor.animeOrTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 录屏按钮
                    HStack(spacing: 4) {
                        Button(action: {
                            ScreenMediaHelper.shared.startRecording()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "record.circle")
                                    .font(.system(size: 9))
                                Text("开始录屏")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(screenMedia.isRecording ? .red : themeColor.animeOrTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton))
                        }
                        .buttonStyle(.plain)
                        .disabled(screenMedia.isRecording)
                        
                        if screenMedia.isRecording {
                            Button(action: {
                                ScreenMediaHelper.shared.stopRecording()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 9))
                                    Text("停止")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 4).fill(.red))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // 标注工具按钮
                        Button(action: {
                            onScreenshotTriggered?()
                            ScreenMediaHelper.shared.openScreenshotAnnotation()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "pencil.tip.crop.circle")
                                    .font(.system(size: 9))
                                Text("标注")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(themeColor.animeOrTextPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 快捷键设置
                    HStack(spacing: 4) {
                        Text("全局快捷键:")
                            .font(.system(size: 8))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                        
                        Picker("", selection: Binding(
                            get: { DependencyContainer.shared.settingsService.settings.screenshotHotkeyPreset },
                            set: { preset in
                                var settings = DependencyContainer.shared.settingsService.settings
                                settings.screenshotHotkeyPreset = preset
                                DependencyContainer.shared.settingsService.updateSettings(settings)
                                GlobalHotkeyManager.shared.setupHotkey(preset: preset)
                            }
                        )) {
                            ForEach(ScreenshotHotkeyPreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 8))
                        .frame(width: 120)
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(themeColor.animeOrBorder.opacity(0.15)))
            }
            
            // MARK: 快速启动应用列表
            if pluginService.showQuickLaunchSection && !pluginService.quickLaunchApps.isEmpty {
                let displayMode = DependencyContainer.shared.settingsService.settings.quickLaunchDisplayMode
                let iconSize = DependencyContainer.shared.settingsService.settings.quickLaunchIconSize
                VStack(alignment: .leading, spacing: 4) {
                    Text("🚀 快速启动")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(pluginService.quickLaunchApps) { app in
                                Button(action: {
                                    Task {
                                        let logs = await YumiScriptEngine.execute("launch \"\(app.name)\"")
                                        pluginRunningLogs = logs
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        if displayMode != .nameOnly {
                                            if let iconName = app.iconName {
                                                AppIconImageView(appName: app.name, iconName: iconName, size: iconSize.sizeValue, bundlePath: app.bundlePath)
                                            } else {
                                                Image(systemName: "arrow.up.right.square")
                                                    .font(.system(size: iconSize.sizeValue * 0.75))
                                            }
                                        }
                                        if displayMode != .iconOnly {
                                            Text(app.name)
                                                .font(.system(size: iconSize.fontValue, weight: .medium))
                                        }
                                    }
                                    .foregroundStyle(themeColor.animeOrTextPrimary)
                                    .padding(.horizontal, iconSize == .large ? 10 : 8)
                                    .padding(.vertical, iconSize == .large ? 6 : 4)
                                    .background(Capsule().fill(themeColor.animeOrButton))
                                    .overlay(Capsule().stroke(themeColor.animeOrBorder, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .modifier(TooltipModifier(text: app.name))
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            
            // MARK: 自定义插件列表（支持单个可见性控制）
            if pluginService.showCustomPluginsSection {
                let activePlugins = pluginService.customPlugins.filter {
                    $0.isEnabled && pluginService.isVisibleInStatusBar(pluginId: $0.id)
                }
                if !activePlugins.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🧩 扩展插件")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(activePlugins) { plugin in
                                    Button(action: {
                                        Task {
                                            let logs = await YumiScriptEngine.execute(plugin.scriptContent)
                                            pluginRunningLogs = logs
                                            // 通知反馈
                                            let succeeded = logs.contains("成功")
                                                || logs.contains("完成")
                                                || logs.contains("已启动")
                                            let failed = logs.contains("失败")
                                                || logs.contains("错误")
                                                || logs.contains("拒绝")
                                            if succeeded && !failed {
                                                Self.showQuickNotify(title: "✅ \(plugin.name)", body: "已执行完成")
                                            } else if failed {
                                                Self.showQuickNotify(title: "⚠️ \(plugin.name)", body: "执行失败，点击查看日志")
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: plugin.icon)
                                                .font(.system(size: 9))
                                            Text(plugin.name)
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .foregroundStyle(themeColor.animeOrTextPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(themeColor.animeOrButton))
                                        .overlay(Capsule().stroke(themeColor.animeOrBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .modifier(TooltipModifier(text: plugin.description.isEmpty ? plugin.name : plugin.description))
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColor.animeOrCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.animeOrBorder, lineWidth: 1)
        )
    }
}

// MARK: - 视图模型

@MainActor
final class StatusBarViewModel: ObservableObject {
    @Published var anniversaryInfo: AnniversaryInfo?
    @Published var anniversaries: [Anniversary] = []
    @Published var shortCountdown: String = ""
    @Published var isPreventSleepEnabled: Bool = false
    @Published var isPetPlaygroundEnabled: Bool = false
    @Published var selectedIconStyle: IconStyle = .pixelAnimal
    @Published var allowMultipleInstances: Bool = false
    @Published var themeColor: ThemeColor = .dark
    @Published var customThemeColorHex: String = "FF6B9D"
    
    var uiIconStyle: IconStyle {
        selectedIconStyle.isStatusBarOnly ? .pixelAnimal : selectedIconStyle
    }
    
    private let container = DependencyContainer.shared
    private var cancellables = Set<AnyCancellable>()
    
    func onAppear() {
        cancellables.removeAll()
        
        container.anniversaryService.activeAnniversaryInfoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                guard let self = self else { return }
                self.anniversaryInfo = info
            }
            .store(in: &cancellables)
            
        container.anniversaryService.anniversariesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lists in
                guard let self = self else { return }
                self.anniversaries = lists
            }
            .store(in: &cancellables)
        
        container.anniversaryService.countdownTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                self.shortCountdown = text
                // Popover 展开展示期间：同步更新 activeAnniversaryInfo，确保弹窗内天数(如 868.590)与状态栏毫秒级实时同步
                if let active = self.container.anniversaryService.activeAnniversaryInfo {
                    self.anniversaryInfo = active
                }
            }
            .store(in: &cancellables)
        
        container.preventSleepService.isPreventSleepEnabledPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self = self else { return }
                self.isPreventSleepEnabled = enabled
            }
            .store(in: &cancellables)
        
        container.settingsService.settingsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self = self else { return }
                self.selectedIconStyle = settings.selectedIconStyle
                self.themeColor = settings.selectedThemeColor
                self.customThemeColorHex = settings.customThemeColorHex
                self.allowMultipleInstances = settings.allowMultipleInstances
            }
            .store(in: &cancellables)
        
        self.anniversaryInfo = container.anniversaryService.activeAnniversaryInfo
        self.anniversaries = container.anniversaryService.anniversaries
        self.isPreventSleepEnabled = container.preventSleepService.isPreventSleepEnabled
        self.isPetPlaygroundEnabled = container.petPlaygroundService.isEnabled
        self.selectedIconStyle = container.settingsService.settings.selectedIconStyle
        self.themeColor = container.settingsService.settings.selectedThemeColor
        self.customThemeColorHex = container.settingsService.settings.customThemeColorHex
        self.allowMultipleInstances = container.settingsService.settings.allowMultipleInstances
        if let info = self.anniversaryInfo {
            self.shortCountdown = info.calculation.shortString
        }
    }
    
    func onDisappear() {
        cancellables.removeAll()
    }
    
    func togglePreventSleep() {
        container.preventSleepService.togglePreventSleep()
    }

    func togglePetPlayground() {
        container.petPlaygroundService.togglePlayground()
        isPetPlaygroundEnabled = container.petPlaygroundService.isEnabled
    }
    
    func toggleAllowMultipleInstances() {
        var settings = container.settingsService.settings
        settings.allowMultipleInstances.toggle()
        container.settingsService.updateSettings(settings)
        self.allowMultipleInstances = settings.allowMultipleInstances
    }
    
    func setActiveAnniversary(id: UUID) {
        container.anniversaryService.setActiveAnniversary(id: id)
    }
}

// MARK: - 主题色选择按钮

struct ThemeColorButton: View {
    let theme: ThemeColor
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // 颜色方块
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: theme.originalIconGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)

                    // 选中指示
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? .white : Color.clear, lineWidth: 2)
                )
                .shadow(color: theme.originalAccentColor.opacity(isHovered ? 0.5 : 0.3), radius: isHovered ? 6 : 3)

                // 主题名称
                Text(theme.displayName)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? theme.originalAccentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Tooltip Modifier (macOS native NSToolTip)

struct TooltipModifier: ViewModifier {
    let text: String
    
    func body(content: Content) -> some View {
        content
            .background(
                TooltipHostingView(text: text)
            )
    }
}

struct TooltipHostingView: NSViewRepresentable {
    let text: String
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        viewToolTip(view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        viewToolTip(nsView)
    }
    
    private func viewToolTip(_ view: NSView) {
        if view.toolTip != text {
            view.toolTip = text
        }
    }
}

// MARK: - App Icon Image View

struct AppIconImageView: View {
    let appName: String
    let iconName: String
    let size: CGFloat
    var bundlePath: String? = nil
    
    @State private var appIcon: NSImage?
    
    var body: some View {
        Group {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.8))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        .task {
            await loadAppIconAsync()
        }
    }
    
    private func loadAppIconAsync() async {
        let path = bundlePath
        let icon = await Task.detached(priority: .utility) { () -> NSImage? in
            if let path = path, FileManager.default.fileExists(atPath: path) {
                let nsIcon = NSWorkspace.shared.icon(forFile: path)
                if nsIcon.isValid && nsIcon.size.width > 0 {
                    nsIcon.size = NSSize(width: size * 2, height: size * 2)
                    return nsIcon
                }
            }
            let searchDirs = ["/Applications", "/System/Applications", "/System/Library/CoreServices"]
            for dir in searchDirs {
                let appPath = (dir as NSString).appendingPathComponent("\(appName).app")
                if FileManager.default.fileExists(atPath: appPath) {
                    let nsIcon = NSWorkspace.shared.icon(forFile: appPath)
                    if nsIcon.isValid && nsIcon.size.width > 0 {
                        nsIcon.size = NSSize(width: size * 2, height: size * 2)
                        return nsIcon
                    }
                }
            }
            for dir in searchDirs {
                if let items = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                    for item in items where item.hasSuffix(".app") {
                        let nameWithoutExt = (item as NSString).deletingPathExtension
                        if nameWithoutExt.localizedCaseInsensitiveContains(appName) || appName.localizedCaseInsensitiveContains(nameWithoutExt) {
                            let fullPath = (dir as NSString).appendingPathComponent(item)
                            let nsIcon = NSWorkspace.shared.icon(forFile: fullPath)
                            if nsIcon.isValid && nsIcon.size.width > 0 {
                                nsIcon.size = NSSize(width: size * 2, height: size * 2)
                                return nsIcon
                            }
                        }
                    }
                }
            }
            return nil
        }.value
        self.appIcon = icon
    }
}

// MARK: - 快速通知工具（给插件回调 / 状态栏事件用）

import UserNotifications
extension StatusBarView {
    /// 弹一条 macOS 系统通知（UNUserNotificationCenter）。
    /// 给插件执行结果等"需要立刻告知用户"的事件用。
    static func showQuickNotify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in
            // 通知中心可能未注册；忽略错误
        }
    }
}
