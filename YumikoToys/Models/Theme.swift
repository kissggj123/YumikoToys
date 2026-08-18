//
//  Theme.swift
//  YumikoToys
//
//  ResolvedTheme 结构体，用于解决主界面和状态栏主题色独立配置后的色彩解析
//

import SwiftUI

@MainActor struct ResolvedTheme: Equatable, Sendable {
    let color: ThemeColor
    let customHex: String
    
    var backgroundColor: Color { color.backgroundColor(customHex: customHex) }
    var nsBackgroundColor: NSColor { color.nsBackgroundColor(customHex: customHex) }
    var accentColor: Color { color.accentColor(customHex: customHex) }
    var iconGradient: [Color] { color.iconGradient(customHex: customHex) }
    var textColor: Color { color.textColor(customHex: customHex) }
    var secondaryTextColor: Color { color.secondaryTextColor(customHex: customHex) }
    var cardBackgroundColor: Color { color.cardBackgroundColor(customHex: customHex) }
    var buttonBackgroundColor: Color { color.buttonBackgroundColor(customHex: customHex) }
    var isDarkTheme: Bool { color.isDarkTheme(customHex: customHex) }
    var isCustomLight: Bool { color.isCustomLight(customHex: customHex) }
    var isCustomDarkBackground: Bool { color.isCustomDarkBackground(customHex: customHex) }
    var isAccentLight: Bool { color.isAccentLight(customHex: customHex) }
    var borderColor: Color { color.borderColor(customHex: customHex) }
    var dividerColor: Color { color.dividerColor(customHex: customHex) }
    var toggleOnColor: Color { color.toggleOnColor(customHex: customHex) }
    var toggleBackgroundColor: Color { color.toggleBackgroundColor(customHex: customHex) }
    var primaryButtonBackground: Color { color.primaryButtonBackground(customHex: customHex) }
    var primaryButtonTextColor: Color { color.primaryButtonTextColor(customHex: customHex) }
    var secondaryButtonBackground: Color { color.secondaryButtonBackground(customHex: customHex) }
    var destructiveButtonColor: Color { color.destructiveButtonColor(customHex: customHex) }
    var iconColor: Color { color.iconColor(customHex: customHex) }
    var hoverBackgroundColor: Color { color.hoverBackgroundColor(customHex: customHex) }
}

// MARK: - 全主题自适应配置 (AboutThemeConfig / AppThemeConfig - 支持 20 款主题专属双模式长图与全局控件调色盘)

typealias AppThemeConfig = AboutThemeConfig

@MainActor
struct AboutThemeConfig {
    let themeName: String
    let themeIcon: String
    let primaryColor: Color
    let secondaryColor: Color
    let cuteBannerBadge: String
    let cuteBannerSub: String
    let watermarkTitle: String
    let watermarkSubtitle: String
    let cardDecorationEmoji: String
    let backgroundGradientStops: [Gradient.Stop]

    // 主题专属日间/夜间长图画布 base palette
    let exportDayCanvasBg: Color
    let exportNightCanvasBg: Color
    let exportCardBorderGlow: Color

    var primaryNSColor: NSColor { NSColor(primaryColor) }
    var secondaryNSColor: NSColor { NSColor(secondaryColor) }
    var linearGradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    @MainActor
    static func current() -> AboutThemeConfig {
        // 1. 二次元主题模式开启时优先使用 4 款二次元配色
        if AnimeThemeService.shared.isEnabled {
            let style = AnimeThemeService.shared.currentStyle
            let gradient = AnimeThemeService.shared.gradient()
            let primary = gradient.first ?? Color(hex: "FF6B9D")
            let secondary = gradient.count > 1 ? gradient[1] : Color(hex: "C44FE2")

            switch style {
            case .kawaii:
                return AboutThemeConfig(
                    themeName: "草莓软萌风",
                    themeIcon: "heart.fill",
                    primaryColor: primary,
                    secondaryColor: secondary,
                    cuteBannerBadge: "🌸 兔可可草莓奶油 · 二次元梦幻王权卡片 💖",
                    cuteBannerSub: "“草莓奶油蛋糕与萌兔王权魔法守护”",
                    watermarkTitle: "Made with 🐰 兔可可草莓奶油梦幻王权 ✨",
                    watermarkSubtitle: "© 2026 YumikoToys Lite · 软萌草莓王国独家长图卡片",
                    cardDecorationEmoji: "🍓",
                    backgroundGradientStops: [
                        .init(color: primary.opacity(0.12), location: 0.0),
                        .init(color: secondary.opacity(0.06), location: 0.5),
                        .init(color: .clear, location: 0.85)
                    ],
                    exportDayCanvasBg: Color(hex: "FFF0F5"),
                    exportNightCanvasBg: Color(hex: "1B0B16"),
                    exportCardBorderGlow: primary.opacity(0.4)
                )
            case .healing:
                return AboutThemeConfig(
                    themeName: "日系治愈风",
                    themeIcon: "leaf.fill",
                    primaryColor: primary,
                    secondaryColor: secondary,
                    cuteBannerBadge: "🍃 抹茶晨光 · 自然和风治愈卡片 🌸",
                    cuteBannerSub: "“抹茶森林和风与清爽微风漫游”",
                    watermarkTitle: "Made with 🍃 抹茶晨光与和风治愈守护 ✨",
                    watermarkSubtitle: "© 2026 YumikoToys Lite · 自然治愈森林专属长图卡片",
                    cardDecorationEmoji: "🌸",
                    backgroundGradientStops: [
                        .init(color: primary.opacity(0.12), location: 0.0),
                        .init(color: secondary.opacity(0.06), location: 0.5),
                        .init(color: .clear, location: 0.85)
                    ],
                    exportDayCanvasBg: Color(hex: "F1F9F5"),
                    exportNightCanvasBg: Color(hex: "091A13"),
                    exportCardBorderGlow: primary.opacity(0.4)
                )
            case .cyber:
                return AboutThemeConfig(
                    themeName: "赛博二次元",
                    themeIcon: "cpu.fill",
                    primaryColor: primary,
                    secondaryColor: secondary,
                    cuteBannerBadge: "⚡️ 霓虹电光蓝 · 赛博二次元矩阵卡片 🌐",
                    cuteBannerSub: "“量子防休眠力场与深空高科技矩阵”",
                    watermarkTitle: "Made with ⚡️ 赛博量子防护与电光矩阵 ✨",
                    watermarkSubtitle: "© 2026 YumikoToys Lite · 赛博朋克电光专属长图卡片",
                    cardDecorationEmoji: "🔮",
                    backgroundGradientStops: [
                        .init(color: primary.opacity(0.15), location: 0.0),
                        .init(color: secondary.opacity(0.08), location: 0.5),
                        .init(color: .clear, location: 0.85)
                    ],
                    exportDayCanvasBg: Color(hex: "F0F7FF"),
                    exportNightCanvasBg: Color(hex: "070F1E"),
                    exportCardBorderGlow: primary.opacity(0.45)
                )
            case .makoto:
                return AboutThemeConfig(
                    themeName: "新海诚漫彩风",
                    themeIcon: "cloud.sun.fill",
                    primaryColor: primary,
                    secondaryColor: secondary,
                    cuteBannerBadge: "🌇 暮光晴空 · 新海诚漫彩限定卡片 ☁️",
                    cuteBannerSub: "“蔚蓝晴空与落日玫瑰漫彩光影”",
                    watermarkTitle: "Made with 🌇 新海诚暮光霞光与云朵守护 ✨",
                    watermarkSubtitle: "© 2026 YumikoToys Lite · 电影级漫彩电影专属长图卡片",
                    cardDecorationEmoji: "✨",
                    backgroundGradientStops: [
                        .init(color: primary.opacity(0.12), location: 0.0),
                        .init(color: secondary.opacity(0.06), location: 0.5),
                        .init(color: .clear, location: 0.85)
                    ],
                    exportDayCanvasBg: Color(hex: "FFF6EE"),
                    exportNightCanvasBg: Color(hex: "1C0E08"),
                    exportCardBorderGlow: primary.opacity(0.4)
                )
            }
        }

        // 2. 二次元主题未开启时，全面支持 16 款标准主题色专属配置
        let settings = DependencyContainer.shared.settingsService.settings
        let themeColor = settings.selectedThemeColor != .dark ? settings.selectedThemeColor : (settings.mainWindowThemeColor != .dark ? settings.mainWindowThemeColor : settings.selectedThemeColor)
        let customHex = !settings.customThemeColorHex.isEmpty ? settings.customThemeColorHex : settings.customMainWindowThemeColorHex
        let gradient = themeColor.iconGradient(customHex: customHex)
        let primary = gradient.first ?? Color(hex: "FF6B9D")
        let secondary = gradient.count > 1 ? gradient[1] : Color(hex: "C44FE2")

        let defaultStops: [Gradient.Stop] = [
            .init(color: primary.opacity(0.12), location: 0.0),
            .init(color: secondary.opacity(0.06), location: 0.5),
            .init(color: .clear, location: 0.85)
        ]

        switch themeColor {
        case .dark:
            return AboutThemeConfig(
                themeName: "深色经典",
                themeIcon: "moon.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🌙 深色经典 · Yumiko 极夜夜幕限定卡片 ✨",
                cuteBannerSub: "“夜幕降临与永恒月光守护”",
                watermarkTitle: "Made with 🌙 极夜月光与不休眠夜幕 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 极夜深色经典专属长图卡片",
                cardDecorationEmoji: "🌙",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "F4F4F7"),
                exportNightCanvasBg: Color(hex: "0D0D12"),
                exportCardBorderGlow: primary.opacity(0.35)
            )
        case .pink:
            return AboutThemeConfig(
                themeName: "甜心粉色",
                themeIcon: "heart.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "💖 甜心草莓粉 · 兔可可梦幻限定卡片 🌸",
                cuteBannerSub: "“甜心草莓与少女心防休眠守护”",
                watermarkTitle: "Made with 💖 兔可可草莓甜心爱意守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 甜心草莓粉专属长图卡片",
                cardDecorationEmoji: "💖",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "FFF0F5"),
                exportNightCanvasBg: Color(hex: "1B0A15"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        case .lavender:
            return AboutThemeConfig(
                themeName: "梦幻紫色",
                themeIcon: "sparkles",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🔮 薰衣草紫 · 魔法水晶典藏长图卡片 ✨",
                cuteBannerSub: "“薰衣草花海与魔法符文奇迹”",
                watermarkTitle: "Made with 🔮 魔法紫罗兰与星辉秘灵守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 梦幻薰衣草紫专属长图卡片",
                cardDecorationEmoji: "🔮",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "FAF0FE"),
                exportNightCanvasBg: Color(hex: "16091E"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        case .mint:
            return AboutThemeConfig(
                themeName: "清新薄荷",
                themeIcon: "leaf.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🍃 清爽薄荷绿 · 晨露自然特调卡片 🌱",
                cuteBannerSub: "“微风拂过与清爽薄荷冰品”",
                watermarkTitle: "Made with 🍃 薄荷晨露与清爽爽朗守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 清新薄荷绿专属长图卡片",
                cardDecorationEmoji: "🌱",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "F0FAF5"),
                exportNightCanvasBg: Color(hex: "091A13"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        case .ocean:
            return AboutThemeConfig(
                themeName: "蔚蓝海洋",
                themeIcon: "water.waves",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🌊 蔚蓝海洋 · 浪花与鲸歌纪念卡片 🐋",
                cuteBannerSub: "“深蓝海洋浪花与潮汐防休眠”",
                watermarkTitle: "Made with 🌊 深海浪花与大鲸歌唱守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 蔚蓝海洋专属长图卡片",
                cardDecorationEmoji: "🐋",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "F0F8FF"),
                exportNightCanvasBg: Color(hex: "071220"),
                exportCardBorderGlow: primary.opacity(0.45)
            )
        case .sunset:
            return AboutThemeConfig(
                themeName: "金色日落",
                themeIcon: "sun.max.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🌇 金色日落 · 晚霞温暖夕阳卡片 🌅",
                cuteBannerSub: "“黄昏余晖与温暖琥珀霞光”",
                watermarkTitle: "Made with 🌇 温暖晚霞与落日余晖守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 金色日落专属长图卡片",
                cardDecorationEmoji: "🌅",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "FFF7EE"),
                exportNightCanvasBg: Color(hex: "1B0E05"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        case .pixel:
            return AboutThemeConfig(
                themeName: "复古像素",
                themeIcon: "gamecontroller.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🎮 8-Bit 像素复古 · 极客游戏成就卡片 🕹️",
                cuteBannerSub: "“8 位机街机音效与霓虹波普”",
                watermarkTitle: "Made with 🎮 8-Bit 像素关卡防休眠守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 复古像素街机专属长图卡片",
                cardDecorationEmoji: "👾",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "F6F0FF"),
                exportNightCanvasBg: Color(hex: "150820"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        case .sakura:
            return AboutThemeConfig(
                themeName: "浪漫樱花",
                themeIcon: "tree.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🌸 浪漫樱花粉 · 樱花雨落限定卡片 🎎",
                cuteBannerSub: "“樱吹雪与神社祈愿风铃”",
                watermarkTitle: "Made with 🌸 浪漫樱花雨与和风祈愿守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 浪漫樱花粉专属长图卡片",
                cardDecorationEmoji: "🌸",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "FFF2F8"),
                exportNightCanvasBg: Color(hex: "1C0B17"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        case .deepSea:
            return AboutThemeConfig(
                themeName: "深海静谧",
                themeIcon: "fish.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🐚 深海静谧 · 荧光水母与珊瑚卡片 🌊",
                cuteBannerSub: "“深海万米水母荧光与沉静”",
                watermarkTitle: "Made with 🐚 深海水母荧光与宁静守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 深海静谧专属长图卡片",
                cardDecorationEmoji: "🐚",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "EEF7FF"),
                exportNightCanvasBg: Color(hex: "05101A"),
                exportCardBorderGlow: primary.opacity(0.45)
            )
        case .forest:
            return AboutThemeConfig(
                themeName: "翠绿森林",
                themeIcon: "tent.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🌲 翠绿森林 · 露营与木屋呼吸卡片 🏕️",
                cuteBannerSub: "“杉木芬多精与露营篝火”",
                watermarkTitle: "Made with 🌲 森林芬多精与清晨光斑守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 翠绿森林专属长图卡片",
                cardDecorationEmoji: "🌲",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "F1F9F3"),
                exportNightCanvasBg: Color(hex: "0A1910"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        case .amber:
            return AboutThemeConfig(
                themeName: "暖阳琥珀",
                themeIcon: "flame.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🍯 暖阳琥珀 · 蜂蜜与热可可暖心卡片 ☕️",
                cuteBannerSub: "“金黄琥珀光泽与温暖陪伴”",
                watermarkTitle: "Made with 🍯 蜂蜜琥珀与暖阳壁炉守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 暖阳琥珀专属长图卡片",
                cardDecorationEmoji: "🍯",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "FFF8ED"),
                exportNightCanvasBg: Color(hex: "1C1205"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        case .crimson:
            return AboutThemeConfig(
                themeName: "热烈赤焰",
                themeIcon: "bolt.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🔥 激情赤焰 · 燃烧星火限定卡片 ⚡️",
                cuteBannerSub: "“无限激情与不熄灭之圣血”",
                watermarkTitle: "Made with 🔥 激情赤焰与永恒燃烧守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 热烈赤焰专属长图卡片",
                cardDecorationEmoji: "🔥",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "FFF1F1"),
                exportNightCanvasBg: Color(hex: "1C0708"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        case .arctic:
            return AboutThemeConfig(
                themeName: "极地冰雪",
                themeIcon: "snowflake",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "❄️ 极地冰雪 · 冰晶与极光纪念卡片 🐧",
                cuteBannerSub: "“冰川极光与冰晶守护”",
                watermarkTitle: "Made with ❄️ 极地冰晶与绚彩极光守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 极地冰雪专属长图卡片",
                cardDecorationEmoji: "❄️",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "F0FAFF"),
                exportNightCanvasBg: Color(hex: "06151F"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        case .roseGold:
            return AboutThemeConfig(
                themeName: "高贵玫金",
                themeIcon: "crown.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "👑 高贵玫瑞金 · 典雅皇家限定卡片 💍",
                cuteBannerSub: "“玫瑰金冠与奢华光芒”",
                watermarkTitle: "Made with 👑 玫瑞金王冠与皇家荣耀守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 高贵玫金专属长图卡片",
                cardDecorationEmoji: "👑",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "FAF2F5"),
                exportNightCanvasBg: Color(hex: "1B0D13"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        case .charcoal:
            return AboutThemeConfig(
                themeName: "极简炭墨",
                themeIcon: "circle.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🖤 极简炭墨 · 水墨与静谧典藏卡片 🖊️",
                cuteBannerSub: "“水墨晕染与极简工学”",
                watermarkTitle: "Made with 🖤 极简炭墨与水墨静谧守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · 极简炭墨专属长图卡片",
                cardDecorationEmoji: "🖤",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "F5F5F7"),
                exportNightCanvasBg: Color(hex: "0F0F12"),
                exportCardBorderGlow: primary.opacity(0.35)
            )
        case .custom:
            let customName = settings.activeColorSchemeName ?? "独家自定义"
            return AboutThemeConfig(
                themeName: customName,
                themeIcon: "paintpalette.fill",
                primaryColor: primary,
                secondaryColor: secondary,
                cuteBannerBadge: "🎨 \(customName) · 灵感工坊限定卡片 ✨",
                cuteBannerSub: "“个性 Hex 调色盘与专属魔法”",
                watermarkTitle: "Made with 🎨 灵感调色盘与个性专属守护 ✨",
                watermarkSubtitle: "© 2026 YumikoToys Lite · \(customName)专属长图卡片",
                cardDecorationEmoji: "🎨",
                backgroundGradientStops: defaultStops,
                exportDayCanvasBg: Color(hex: "FAFAFD"),
                exportNightCanvasBg: Color(hex: "0D0D13"),
                exportCardBorderGlow: primary.opacity(0.4)
            )
        }
    }
}
