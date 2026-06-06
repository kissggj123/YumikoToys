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
    let onShowMainWindow: () -> Void
    let onQuit: () -> Void

    // 主题色选择
    @State private var themeColor: ThemeColor = .dark
    @State private var showThemePicker: Bool = false

    // 悬浮动效状态
    @State private var isDaysCardHovered = false
    @State private var isPreventSleepHovered = false
    @State private var isMainBtnHovered = false
    @State private var isQuitBtnHovered = false
    @State private var isThemeBtnHovered = false
    @State private var isAvatarHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            headerView
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            // 天数展示
            if let info = viewModel.anniversaryInfo {
                daysPreview(info: info, countdown: viewModel.shortCountdown)
                    .padding(16)

                Divider()
                    .padding(.horizontal, 16)
            }

            // 防休眠开关
            preventSleepSection
                .padding(16)

            Divider()
                .padding(.horizontal, 16)

            // 底部按钮
            bottomButtons
                .padding(16)

            // 主题色选择器（底部）
            if showThemePicker {
                themeColorPicker
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
        .frame(width: 340)
        // 关键：允许垂直方向完全自适应内容高度，防止 popover 被裁剪或留下空白
        .fixedSize(horizontal: false, vertical: true)
        // 【修复】根据主题色设置背景
        .background(themeColor.backgroundColor)
        .preferredColorScheme(themeColor.isDarkTheme ? .dark : .light)
        .onAppear {
            viewModel.onAppear()
            // 【修复】在 onAppear 中读取保存的主题色
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
                    .fill(themeColor.accentColor)
                    .frame(width: 8, height: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .medium))
                    .rotationEffect(.degrees(showThemePicker ? 180 : 0))
            }
            .foregroundStyle(themeColor.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(themeColor.buttonBackgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(themeColor.borderColor, lineWidth: 1)
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
            Text("选择主题")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(themeColor.secondaryTextColor)

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
            
            // 如果是自定义主题，显示 HEX 输入框和 ColorPicker
            if themeColor == .custom {
                VStack(spacing: 8) {
                    Divider()
                        .background(themeColor.dividerColor)
                        .padding(.vertical, 2)
                    
                    HStack(spacing: 8) {
                        Text("自定义 HEX")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(themeColor.textColor)
                        
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
                                .fill(themeColor.textColor.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(themeColor.borderColor, lineWidth: 1)
                        )
                        .frame(width: 80)
                        .foregroundStyle(themeColor.textColor)
                        
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
                .fill(themeColor.cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeColor.borderColor, lineWidth: 1)
        )
    }

    /// 保存主题色到 AppSettings
    private func saveThemeColor(_ theme: ThemeColor) {
        var settings = DependencyContainer.shared.settingsService.settings
        settings.selectedThemeColor = theme
        DependencyContainer.shared.settingsService.updateSettings(settings)
    }
    
    /// 保存自定义主题色 Hex
    private func saveCustomThemeColorHex(_ hex: String) {
        var settings = DependencyContainer.shared.settingsService.settings
        settings.customThemeColorHex = hex
        settings.selectedThemeColor = .custom
        DependencyContainer.shared.settingsService.updateSettings(settings)
    }
    
    // MARK: - 头部
    
    private var headerView: some View {
        HStack(spacing: 10) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: themeColor.iconGradient,
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
                Text(AppConfig.appName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeColor.textColor)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("🥕")
                        .font(.system(size: 10))
                    Text("可可皇后")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(themeColor.accentColor)
                        .lineLimit(1)
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(themeColor.secondaryTextColor)
                    Text("v\(AppConfig.version)")
                        .font(.system(size: 10))
                        .foregroundStyle(themeColor.secondaryTextColor)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 主题切换按钮
            themeToggleButton
            
            // 状态指示器
            if viewModel.isPreventSleepEnabled {
                Circle()
                    .fill(themeColor.accentColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: themeColor.accentColor.opacity(0.5), radius: 4)
            }
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
                
                Text(info.anniversary.displayPetName)
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
                            colors: themeColor.iconGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("天")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(themeColor.secondaryTextColor)
                
                Spacer()
            }
            
            // 倒计时
            Text(countdown)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(themeColor.secondaryTextColor.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            // 纪念日里程碑列表 (100, 180, 300天及周年里程碑展示)
            if !info.milestones.isEmpty {
                Divider()
                    .background(themeColor.dividerColor)
                    .padding(.vertical, 4)
                
                VStack(spacing: 6) {
                    ForEach(info.milestones) { milestone in
                        HStack(spacing: 6) {
                            Text(milestone.icon)
                                .font(.system(size: 11))
                            
                            Text(milestone.label)
                                .font(.system(size: 10))
                                .foregroundStyle(themeColor.secondaryTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Spacer()
                            
                            Text(milestone.formattedDate)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(themeColor.textColor.opacity(0.8))
                                .frame(width: 75, alignment: .leading)
                            
                            Text("(\(milestone.countDisplay))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(themeColor.accentColor)
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeColor.cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: themeColor.iconGradient.map { $0.opacity(0.8) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isDaysCardHovered ? 1.015 : 1.0)
        .shadow(color: themeColor.accentColor.opacity(isDaysCardHovered ? 0.12 : 0.0), radius: 8)
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
                        .fill(viewModel.isPreventSleepEnabled ? themeColor.accentColor.opacity(0.15) : themeColor.secondaryButtonBackground)
                        .frame(width: 36, height: 36)
                    
                    PixelArtIconView(
                        function: .settings,
                        style: viewModel.uiIconStyle,
                        size: 18
                    )
                    .foregroundStyle(viewModel.isPreventSleepEnabled ? themeColor.accentColor : themeColor.iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("不休眠模式")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(themeColor.textColor)
                        .lineLimit(1)
                    
                    Text(viewModel.isPreventSleepEnabled ? "已开启" : "已关闭")
                        .font(.caption2)
                        .foregroundStyle(viewModel.isPreventSleepEnabled ? themeColor.accentColor : themeColor.secondaryTextColor)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { viewModel.isPreventSleepEnabled },
                    set: { _ in viewModel.togglePreventSleep() }
                ))
                .toggleStyle(.switch)
                .tint(themeColor.toggleOnColor)
                .labelsHidden()
                .allowsHitTesting(false) // 【核心修复】阻断 Toggle 本身对鼠标的响应，统一由外层整行手势接管，消除冲突 [1]
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPreventSleepHovered ? themeColor.hoverBackgroundColor : Color.clear)
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
                .foregroundStyle(themeColor.textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColor.secondaryButtonBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeColor.borderColor, lineWidth: 1)
                )
                .scaleEffect(isMainBtnHovered ? 1.03 : 1.0)
                .shadow(color: themeColor.accentColor.opacity(isMainBtnHovered ? 0.35 : 0.0), radius: 6)
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
}

// MARK: - 视图模型

@MainActor
final class StatusBarViewModel: ObservableObject {
    @Published var anniversaryInfo: AnniversaryInfo?
    @Published var shortCountdown: String = ""
    @Published var isPreventSleepEnabled: Bool = false
    @Published var selectedIconStyle: IconStyle = .pixelAnimal
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
        
        container.anniversaryService.countdownTextPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                self.shortCountdown = text
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
            }
            .store(in: &cancellables)
        
        self.anniversaryInfo = container.anniversaryService.activeAnniversaryInfo
        self.isPreventSleepEnabled = container.preventSleepService.isPreventSleepEnabled
        self.selectedIconStyle = container.settingsService.settings.selectedIconStyle
        self.themeColor = container.settingsService.settings.selectedThemeColor
        self.customThemeColorHex = container.settingsService.settings.customThemeColorHex
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
