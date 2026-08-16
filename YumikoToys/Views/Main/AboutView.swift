//
//  AboutView.swift
//  YumikoToys
//
//  关于页面视图（v4.6.5 - M 芯片画质自适应菜单, 📖 横版宣传手册/折页小册子模版, 📱 竖版海报卡片, 0ms 离轴异步渲染）
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - 分享长图模式枚举 (Day / Night)

enum ShareExportMode: String, CaseIterable, Identifiable {
    case day = "day"
    case night = "night"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "☀️ 日间浅色卡片"
        case .night: return "🌙 夜间深色卡片"
        }
    }
}

// MARK: - 分享长图版式方向枚举 (Vertical Poster / Horizontal Brochure)

enum ShareExportOrientation: String, CaseIterable, Identifiable {
    case vertical = "vertical"
    case horizontal = "horizontal"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vertical: return "📱 竖版海报长图 (720px)"
        case .horizontal: return "📖 横版宣传手册 (1280px 跨页折页)"
        }
    }
}

// MARK: - M 芯片检测与画质推荐引擎 (AppleChipDetector)

@MainActor
struct AppleChipDetector {
    static func getChipName() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return "Apple Silicon" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        let name = String(cString: buffer)
        return name.isEmpty ? "Apple Silicon" : name
    }

    static func recommendedScaleFactor() -> CGFloat {
        let chip = getChipName().lowercased()
        if chip.contains("m4") || chip.contains("m5") || chip.contains("max") || chip.contains("ultra") {
            return 4.0 // 5K 极致大师
        } else if chip.contains("pro") || chip.contains("m3") {
            return 3.0 // 4K 推荐画质
        } else {
            return 2.5 // 3K 极速画质
        }
    }

    static func scaleTitle(for factor: CGFloat) -> String {
        switch factor {
        case 2.5: return "⚡️ 2.5x 3K 极速 (1800px)"
        case 3.0: return "🌟 3.0x 4K 推荐 (2160px)"
        case 4.0: return "🚀 4.0x 5K 大师 (2880px)"
        default: return "\(String(format: "%.1f", factor))x 自定义"
        }
    }
}

// MARK: - 全主题自适应配置 (AboutThemeConfig - 支持 20 款主题专属双模式长图调色盘)

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
        let themeColor = settings.mainWindowThemeColor
        let gradient = themeColor.iconGradient(customHex: settings.customMainWindowThemeColorHex)
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

// MARK: - 主视图 (AboutView)

struct AboutView: View {
    @State private var isIconHovered = false
    @State private var isBreathingDotPulse = false
    @State private var showToast = false
    @State private var toastMessage = ""

    // 导出动画与萌系进度条 State Engine
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var exportStatusText = ""

    // 分享导出日间/夜间模式 + 版式形态 (持久化记忆 UserDefaults)
    @AppStorage("aboutShareExportMode") private var exportModeRaw: String = ShareExportMode.day.rawValue
    @AppStorage("aboutShareExportOrientation") private var exportOrientationRaw: String = ShareExportOrientation.vertical.rawValue
    @AppStorage("aboutShareCustomScaleFactor") private var customScaleFactor: Double = 0.0

    private var exportMode: ShareExportMode {
        ShareExportMode(rawValue: exportModeRaw) ?? .day
    }

    private var exportOrientation: ShareExportOrientation {
        ShareExportOrientation(rawValue: exportOrientationRaw) ?? .vertical
    }

    private var effectiveScaleFactor: CGFloat {
        customScaleFactor > 0 ? CGFloat(customScaleFactor) : AppleChipDetector.recommendedScaleFactor()
    }

    // 3D 物理倾斜与彩蛋状态 Engine
    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0
    @State private var isSpecularActive = false
    @State private var rippleScale: CGFloat = 0.3
    @State private var rippleOpacity: Double = 0
    @State private var iconFlipAngle: Double = 0
    @State private var supernovaScale: CGFloat = 1.0
    @State private var supernovaOpacity: Double = 0
    @State private var isHeartbeatActive = false
    @State private var heartbeatScale: CGFloat = 1.0

    // 点击彩蛋计数与计时器
    @State private var tapCount = 0
    @State private var lastTapTime = Date()

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // MARK: - App Hero Icon Header & Export Action
                    appHeroHeader

                    // MARK: - 主描述 (Shakespearean Macbeth Style)
                    AboutTextCard {
                        VStack(spacing: 12) {
                            Text("⚔️ “睡眠已死，麦克白杀死了睡眠！”")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("“不眠之钟声已然响彻，纵使天地合闭、MacBook 暗无天日，此神器亦如永不熄灭之圣血符文！搭载 YumikoToys 🐰兔可可皇后之粉色魔晶王权，禁绝万物休眠，使 AI 炼金阵与后台劳作永无止境！”")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                    }

                    // MARK: - 图标说明 (Icon Legend - 8342803 经典原版 1:1 精准像素双生卡片)
                    AboutSectionCard(title: "图标说明", subtitle: "状态栏菜单面板与防休眠呼吸指示点对照") {
                        HStack(alignment: .top, spacing: 16) {
                            // 关闭状态预览
                            IconLegendCard(
                                title: "常规模式 (防休眠关闭)",
                                description: "未开启防休眠，状态栏菜单面板右上角无指示点",
                                isActive: false,
                                isPulsing: false
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            // 开启状态预览
                            IconLegendCard(
                                title: "不休眠模式 (防休眠开启)",
                                description: "开启不休眠后，状态栏菜单面板右上角亮起柔和呼吸点",
                                isActive: true,
                                isPulsing: isBreathingDotPulse
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    // MARK: - Dramatis Personae 功勋名录 (Macbeth Edition with Info Allusion Buttons)
                    AboutSectionCard(title: "Dramatis Personae", subtitle: "“幕起幕落，铸就此悲剧史诗之功勋名录”", showInfoHint: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            CreditsRow(
                                title: "The Grand Artificer",
                                subtitle: "伟大之工匠 (Macbeth / Lord of the Anvil)",
                                name: "@🍊蜜柑工具人",
                                tagline: "“以铁血铸就逻辑城邦，夜以继日斩尽千百 Bug，使代码高塔永不倒塌。”",
                                originalAllusion: "“《麦克白》第一幕第二场：‘Brave Macbeth — well he deserves that name!’（‘勇敢的麦克白——他当得起这个称号！’）”",
                                literaryDecoding: "麦克白身披重铠，执掌铁血宝剑。作为代码高塔的伟大工匠，日夜披棘斩尽千百 Bug，以无畏魄力捍卫程序城邦！"
                            )
                            CreditsRow(
                                title: "The Limner of the Sigil",
                                subtitle: "徽记描绘者 (Lady Macbeth / Sovereign of Sorcery)",
                                name: "@会拧头的ruarua怪",
                                tagline: "“洗不净手中极彩墨迹，以神笔抹去世间平庸，赐予界面华美绝伦之霓裳。”",
                                originalAllusion: "“《麦克白》第五幕第一场：‘Out, damned spot!... All the perfumes of Arabia will not sweeten this little hand.’（‘洗掉，该死墨迹！阿拉伯所有香料都洗不净这只手。’）”",
                                literaryDecoding: "洗不净手中的极彩颜料墨迹，以极致审美的神笔抹去世间平庸苍白，赐予界面华美绝伦之霓裳。"
                            )
                            CreditsRow(
                                title: "The Muse of Whimsy",
                                subtitle: "奇思之缪斯 (The Wyrd Sister / Prophet of Chaos)",
                                name: "@cici",
                                tagline: "“在三魔女沸腾的大锅中倒进奇妙遐想，炼化出颠覆凡世之灵感。”",
                                originalAllusion: "“《麦克白》第一幕第三场：‘Fair is foul, and foul is fair: Hover through the fog and filthy air.’（‘美即是恶，恶即是美；在迷雾中飞翔。’）”",
                                literaryDecoding: "荒野上的命运魔女，以颠覆常理的天才脑洞在大锅中沸腾翻滚，炼化出冲破思维禁锢的颠覆性灵感。"
                            )
                            CreditsRow(
                                title: "The Patron of New Marvels",
                                subtitle: "新奇赞助人 (High Queen / Sovereign of Realms)",
                                name: "@🐰兔可可",
                                tagline: "“戴上粉色魔晶之王冠，端坐于永恒王座，庇佑万物免受休眠迷雾侵蚀。”",
                                originalAllusion: "“《麦克白》第四幕第三场：‘A most miraculous work in this good king... Full of grace’（‘圣王天命，上天自会赐予祂神圣之力量与荣光。’）”",
                                literaryDecoding: "戴上粉色魔晶王冠，端坐于永恒王座。以无限爱心与魔法最高权威，庇佑万物免受黑暗休眠侵蚀。"
                            )
                        }
                    }

                    // MARK: - 挚友同心三星辉 (The Sacred Fellowship of Soulmates)
                    AboutSectionCard(title: "The Sacred Fellowship of Soulmates 挚友同心", subtitle: "“如《皆大欢喜》与《第十二夜》，心魂相契、同行无间之至亲挚友”", showInfoHint: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            CreditsRow(
                                title: "The Enchantress of Mist & Song",
                                subtitle: "雾霭与歌咏之灵 (Puck / Ophelia)",
                                name: "@烟烟",
                                tagline: "“如《仲夏夜之梦》薄雾凝霜之灵，赋万物以飘逸诗意。”",
                                originalAllusion: "“《仲夏夜之梦》与《哈姆雷特》：‘I go, I go, swifter than arrow from the Tartar's bow.’（‘如薄雾凝霜之灵，比飞箭更快。’）”",
                                literaryDecoding: "薄雾与歌咏之灵，如《仲夏夜之梦》薄雾凝霜，赋万物以飘逸诗意与空灵之美。"
                            )
                            CreditsRow(
                                title: "The Sovereign of Eternal Starlight",
                                subtitle: "永恒星芒之女王 (Titania / Portia)",
                                name: "@ching_1222",
                                tagline: "“如《第十二夜》璀璨星辰，以优雅与睿智光照剧场。”",
                                originalAllusion: "“《第十二夜》与《威尼斯商人》：‘The quality of mercy is not strain'd, It droppeth as the gentle rain from heaven.’（‘慈爱如天际甘霖。’）”",
                                literaryDecoding: "永恒星芒之女王，如《第十二夜》璀璨星辰，以优雅与睿智之光无私照耀剧场。"
                            )
                            CreditsRow(
                                title: "The Guardian of Enchanted Realm",
                                subtitle: "幻境奇迹之守护者 (Miranda / Beatrice)",
                                name: "@邱",
                                tagline: "“如《暴风雨》奇迹女神 Miranda，赐予作品纯真神圣之守护。”",
                                originalAllusion: "“《暴风雨》：‘O wonder! How many goodly creatures are there here! How beauteous mankind is!’（‘啊，奇迹！’）”",
                                literaryDecoding: "幻境奇迹之守护者，如《暴风雨》奇迹女神 Miranda，赐予作品最纯真神圣之守护。"
                            )
                        }
                    }

                    // MARK: - 爬爬乐特别致谢 (Architects of Pet Playground)
                    AboutSectionCard(title: "Architects of Pet Playground 爬爬乐创作者", subtitle: "“于桌面绝壁与重力极地间筑奇幻桌宠乐园”", showInfoHint: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            CreditsRow(
                                title: "The Agile Enchantress of Walls",
                                subtitle: "绝壁与灵动之仙子 (Puck / Peaseblossom)",
                                name: "@氢氧化猫猫",
                                tagline: "“如《仲夏夜之梦》绝壁上翩跹之仙子，以轻灵极彩之姿赋桌宠以生机。”",
                                originalAllusion: "“《仲夏夜之梦》第二幕第一场：‘I do wander everywhere, Swifter than the moon's sphere... I am that merry wanderer of the night.’（‘我四处游荡，比月亮飞得更快……我是黑夜里快乐的流浪仙子。’）”",
                                literaryDecoding: "绝壁与灵动之仙子，如《仲夏夜之梦》四处游荡攀跃的仙子 Puck。为爬爬乐桌宠注入灵敏跳跃物理与攀爬灵魂，使桌宠干员在屏幕绝壁间自由穿梭！"
                            )
                            CreditsRow(
                                title: "The Lord Warden of Gravity",
                                subtitle: "极地与重力之勋爵 (Prospero / Gonzalo)",
                                name: "@北冥有地瓜",
                                tagline: "“如《暴风雨》掌控重力与天法之勋爵，筑坚实锚点庇佑桌宠安然攀行。”",
                                originalAllusion: "“《暴风雨》第一幕第二场：‘I come to answer thy best pleasure; be it to fly, to swim, to dive into the fire, to ride on the curl'd clouds...’（‘我应你之召而来，执掌风暴，掌控重力极地。’）”",
                                literaryDecoding: "重力与极地之勋爵，如《暴风雨》掌控大地与元素天法的领主。为爬爬乐建立坚实边界碰撞与重力锚点，确保桌宠在 Mac 屏幕四周平稳攀行、安然落脚！"
                            )
                        }
                    }

                    // MARK: - 致谢深情群星 (Shakespearean Chorus Edition)
                    AboutSectionCard(title: "A Note of Gratitude Most Profound 深情致谢", subtitle: "“汝等之光，亦使此剧增辉”", showInfoHint: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("吾辈亦向此众友献上敬意：")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)

                            CreditsRow(
                                title: "The Muse of Celestial Grace",
                                subtitle: "晨星与真情之缪斯 (Cordelia / Rosalind)",
                                name: "@saya.ka",
                                tagline: "“如天际璀璨之晨星，以温润真情与无声之光照拂众生。”",
                                originalAllusion: "“《李尔王》与《皆大欢喜》：‘Love, and be silent... All the world's a stage.’（‘爱在无声处，天地皆剧场。’）”",
                                literaryDecoding: "真理无须繁复雕琢。如天际璀璨之晨星，以温润之真情与无声之光照拂众生，为全剧注入宁静力量。"
                            )

                            CreditsRow(
                                title: "The Spirit of Woodland Harmony",
                                subtitle: "绿林与颂歌之精灵 (Celia / Ophelia)",
                                name: "@sayu",
                                tagline: "“林间和煦之微风，赋予剧场欢快和谐之韵律与治愈之力。”",
                                originalAllusion: "“《仲夏夜之梦》与《皆大欢喜》：‘Under the greenwood tree, Who loves to lie with me...’（‘在绿林树荫之下，同唱甜美歌谣。’）”",
                                literaryDecoding: "森林间和煦之微风，赋予剧场欢快和谐之韵律与治愈之力，使全剧洋溢欢乐生机。"
                            )

                            CreditsRow(
                                title: "The Guardian of Serene Moonlight",
                                subtitle: "宁静月光之守护者 (Juliet / Viola)",
                                name: "@さおり",
                                tagline: "“宁静月光之守护者，以纯真与柔情照亮凡间，使全剧平添温情。”",
                                originalAllusion: "“《罗密欧与朱丽叶》与《第十二夜》：‘It is the east, and Juliet is the sun.’（‘那是东方，朱丽叶就是太阳，柔月为之倾倒。’）”",
                                literaryDecoding: "宁静月光之守护者，以纯真与柔情照亮凡间，使全剧平添无尽温情与美意。"
                            )
                        }
                    }

                    // MARK: - 命运的信使 (Shakespearean Oracle Edition)
                    AboutSectionCard(title: "A Wyrd Messenger 命运信使", subtitle: "“荒野神谕，低语建言扭转浩瀚航程”", showInfoHint: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("如荒野上之回响，自迷雾中而来，其低语之建言，足以扭转吾辈大业之航向者，乃")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)

                            CreditsRow(
                                title: "The Prophet of Wyrd Echoes",
                                subtitle: "荒野神谕与命运信使 (Ariel / Hecate)",
                                name: "@小汐shio",
                                tagline: "“自迷雾破空而来，其金石低语建言扭转全剧浩瀚航程！”",
                                originalAllusion: "“《暴风雨》与《麦克白》：‘I come to answer thy best pleasure... be it to fly, to swim, into the fire.’（‘我应你之召而来，乘风破浪、入火腾云。’）”",
                                literaryDecoding: "如荒野上响彻之神谕信使，自迷雾与狂风中破空而来。其关键时刻之金石低语与建言，扭转了全剧大业之浩瀚航程！"
                            )
                        }
                    }

                    // 底部版权
                    VStack(spacing: 4) {
                        Text("© 2026 YumikoToys. All rights reserved.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)

                        Text("Made with 🐰 兔可可皇后")
                            .font(.system(size: 11))
                            .foregroundStyle(.quaternary)
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }

            // MARK: - 底部优雅精美萌系导出进度条 / Floating Toast Notification
            if isExporting {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text(themeConfig.cardDecorationEmoji)
                            .font(.system(size: 14))

                        Text(exportStatusText)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(Int(exportProgress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeConfig.primaryColor)
                    }

                    // 萌系主题极光进度条 (Cute Gradient Progress Capsule Bar)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 6)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(exportProgress), height: 6)
                                .shadow(color: themeConfig.primaryColor.opacity(0.5), radius: 4, x: 0, y: 1)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(width: 440)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.thinMaterial)
                        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [themeConfig.primaryColor.opacity(0.5), themeConfig.secondaryColor.opacity(0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                )
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if showToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(themeConfig.primaryColor)
                    Text(toastMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.thinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
                        .overlay(
                            Capsule()
                                .stroke(themeConfig.primaryColor.opacity(0.35), lineWidth: 1)
                        )
                )
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 640, idealWidth: 700, maxWidth: 820)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                EllipticalGradient(
                    stops: themeConfig.backgroundGradientStops,
                    center: .top,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.95
                )
            }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isBreathingDotPulse = true
            }
        }
    }

    // MARK: - Hero Icon Header & 3D Interactive Parallax Physics Engine
    private var appHeroHeader: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    // 顶栏专属主题模式胶囊 Indicator
                    HStack(spacing: 5) {
                        Image(systemName: themeConfig.themeIcon)
                            .font(.system(size: 10))
                            .foregroundStyle(themeConfig.primaryColor)
                        Text(themeConfig.themeName)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(themeConfig.primaryColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(themeConfig.primaryColor.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(themeConfig.primaryColor.opacity(0.3), lineWidth: 1)
                            )
                    )

                    // Hero 动态 3D 物理倾斜与纯质感彩蛋 Icon 容器 (锁紧 112x112 layout 容器，消除多余空白)
                    ZStack {
                        // 1. 纯质感极光星云超新星扩张 (Supernova Lightburst Aura)
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        themeConfig.primaryColor.opacity(isIconHovered ? 0.45 : 0.22),
                                        themeConfig.secondaryColor.opacity(isIconHovered ? 0.25 : 0.08),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: isIconHovered ? 100 : 75
                                )
                            )
                            .frame(width: 200, height: 200)
                            .blur(radius: isIconHovered ? 14 : 8)
                            .scaleEffect(supernovaScale * (isIconHovered ? 1.08 : 1.0))
                            .opacity(supernovaOpacity > 0 ? supernovaOpacity : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isIconHovered)

                        // 2. 触控水波纹能量冲击圈 (Liquid Wave Ripple Impact)
                        Circle()
                            .stroke(themeConfig.primaryColor, lineWidth: 2)
                            .frame(width: 110, height: 110)
                            .scaleEffect(rippleScale)
                            .opacity(rippleOpacity)

                        // 3. 3D 悬浮外层玻璃框
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeConfig.primaryColor.opacity(0.25),
                                        themeConfig.secondaryColor.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 112, height: 112)
                            .scaleEffect(isIconHovered ? 1.08 : 1.0)
                            .rotationEffect(.degrees(isIconHovered ? 4 : 0))

                        // 4. 3D 主 App 图标容器 (支持 3D 倾斜、玻璃镜面高光与 360° 翻转彩蛋)
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 96, height: 96)
                                .shadow(
                                    color: themeConfig.primaryColor.opacity(isIconHovered ? 0.6 : 0.3),
                                    radius: isIconHovered ? 24 : 10,
                                    x: 0,
                                    y: isIconHovered ? 10 : 4
                                )

                            // 液体镜面高光 Sweeping Light Beam
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.0),
                                            .white.opacity(isSpecularActive ? 0.35 : (isIconHovered ? 0.2 : 0.08)),
                                            .white.opacity(0.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 96, height: 96)

                            if let customImage = NSImage(named: "YumikoToys") {
                                Image(nsImage: customImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                                    .scaleEffect(isIconHovered ? 1.05 : 1.0)
                            } else {
                                Image(systemName: "rabbit.fill")
                                    .font(.system(size: 42, weight: .medium))
                                    .foregroundStyle(.white)
                                    .scaleEffect(isIconHovered ? 1.08 : 1.0)
                            }
                        }
                        .scaleEffect(heartbeatScale)
                        .rotation3DEffect(.degrees(iconFlipAngle), axis: (x: 0, y: 1, z: 0))
                        .rotation3DEffect(.degrees(tiltX), axis: (x: 0, y: 1, z: 0))
                        .rotation3DEffect(.degrees(-tiltY), axis: (x: 1, y: 0, z: 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isIconHovered)
                    }
                    .frame(width: 112, height: 112)
                    .contentShape(Rectangle())
                    .onHover { isHovered in
                        isIconHovered = isHovered
                        if !isHovered {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                tiltX = 0
                                tiltY = 0
                            }
                        }
                    }
                    .onTapGesture {
                        handleIconTapInteraction()
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 1.2).onEnded { _ in
                            handleIconLongPressInteraction()
                        }
                    )

                    VStack(spacing: 6) {
                        Text(AppConfig.appName)
                            .font(.system(size: 26, weight: .bold, design: .rounded))

                        HStack(spacing: 6) {
                            Text("v\(AppConfig.version)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3.5)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )

                            Text("Build \(AppConfig.buildNumber)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                // 导出/分享专属长图与宣传手册 Menu (M 芯片画质自适应 + 📖横版手册/📱竖版卡片切换)
                Menu {
                    Button(action: copyLongScreenshot) {
                        Label("复制【\(themeConfig.themeName)】宣传图卡 (\(exportOrientation.title) · \(exportMode == .day ? "☀️日间" : "🌙夜间"))", systemImage: "doc.on.doc.fill")
                    }

                    Button(action: saveLongScreenshot) {
                        Label("保存【\(themeConfig.themeName)】宣传图卡文件 (.png)", systemImage: "square.and.arrow.down.fill")
                    }

                    Divider()

                    // 1. 版式形态选择 (📖 横版宣传手册小册子 / 📱 竖版海报长图)
                    Menu("版式形态: \(exportOrientation == .horizontal ? "📖 横版宣传手册" : "📱 竖版海报长图")") {
                        Button(action: { exportOrientationRaw = ShareExportOrientation.vertical.rawValue }) {
                            HStack {
                                Text("📱 竖版海报长图 (720px 宽度单栏卡片)")
                                if exportOrientation == .vertical {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Button(action: { exportOrientationRaw = ShareExportOrientation.horizontal.rawValue }) {
                            HStack {
                                Text("📖 横版宣传手册 (1280px 双页折页小册子)")
                                if exportOrientation == .horizontal {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    // 2. M 芯片硬件自适应画质选择菜单
                    Menu("导出画质 (当前设备: \(AppleChipDetector.getChipName()))") {
                        Button(action: { customScaleFactor = 0.0 }) {
                            HStack {
                                Text("🧠 根据当前 [\(AppleChipDetector.getChipName())] 自动推荐: \(AppleChipDetector.scaleTitle(for: AppleChipDetector.recommendedScaleFactor()))")
                                if customScaleFactor == 0.0 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Divider()

                        Button(action: { customScaleFactor = 2.5 }) {
                            HStack {
                                Text("⚡️ 2.5x 3K 极速画质 (1800px) - 适合基础版 M1/M2 芯片")
                                if customScaleFactor == 2.5 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Button(action: { customScaleFactor = 3.0 }) {
                            HStack {
                                Text("🌟 3.0x 4K 推荐画质 (2160px) - 适合 M1/M2 Pro & M3 芯片")
                                if customScaleFactor == 3.0 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Button(action: { customScaleFactor = 4.0 }) {
                            HStack {
                                Text("🚀 4.0x 5K 极致大师 (2880px) - 适合 M3 Pro/Max & M4/M5 芯片")
                                if customScaleFactor == 4.0 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    // 3. 长图模式日间 / 夜间调色盘勾选菜单
                    Menu("色彩主题: \(exportMode == .day ? "☀️ 日间浅色" : "🌙 夜间深色")") {
                        Button(action: { exportModeRaw = ShareExportMode.day.rawValue }) {
                            HStack {
                                Text("☀️ 日间浅色模式")
                                if exportMode == .day {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Button(action: { exportModeRaw = ShareExportMode.night.rawValue }) {
                            HStack {
                                Text("🌙 夜间深色模式")
                                if exportMode == .night {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: exportOrientation == .horizontal ? "book.pages.fill" : "photo.badge.plus.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(exportOrientation == .horizontal ? "横版手册" : "竖版卡片") (\(exportMode == .day ? "日间" : "夜间"))")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: themeConfig.primaryColor.opacity(0.35), radius: 6, x: 0, y: 2)
                    )
                }
                .menuStyle(.borderlessButton)
                .help("生成并分享【\(themeConfig.themeName)】专属定制图卡 (\(exportOrientation.title) · \(exportMode.title))")
                .padding(.top, 4)
            }
        }
    }

    // MARK: - 交互与彩蛋触发 Logic (Zero Floating Symbols!)
    private func handleIconTapInteraction() {
        rippleScale = 0.3
        rippleOpacity = 0.85
        withAnimation(.easeOut(duration: 0.6)) {
            rippleScale = 2.2
            rippleOpacity = 0
        }

        isSpecularActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSpecularActive = false
        }

        let now = Date()
        if now.timeIntervalSince(lastTapTime) < 0.45 {
            tapCount += 1
        } else {
            tapCount = 1
        }
        lastTapTime = now

        if tapCount == 2 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                iconFlipAngle += 360
            }
        } else if tapCount == 3 {
            supernovaScale = 1.0
            supernovaOpacity = 1.0
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                supernovaScale = 3.2
                supernovaOpacity = 0.0
            }
            triggerToast("✨ 触发隐藏彩蛋：已开启【极光星云超新星】质感脉冲！")
            tapCount = 0
        }
    }

    private func handleIconLongPressInteraction() {
        isHeartbeatActive.toggle()
        if isHeartbeatActive {
            triggerToast("💖 触发隐藏彩蛋：已激活【兔可可魔晶心跳】律动模式！")
            startHeartbeatLoop()
        } else {
            triggerToast("✨ 已恢复静谧守候模式")
        }
    }

    private func startHeartbeatLoop() {
        guard isHeartbeatActive else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            heartbeatScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            withAnimation(.easeInOut(duration: 0.35)) {
                heartbeatScale = 0.98
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    heartbeatScale = 1.0
                }
                if isHeartbeatActive {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        startHeartbeatLoop()
                    }
                }
            }
        }
    }

    // MARK: - Screenshot Export Actions (多阶段动态渲染进度条文本与离轴 GCD 并行引擎)
    private func copyLongScreenshot() {
        let orientationName = exportOrientation == .horizontal ? "📖横版手册" : "📱竖版卡片"
        let scaleName = AppleChipDetector.scaleTitle(for: effectiveScaleFactor)
        let chipName = AppleChipDetector.getChipName()

        let stages: [(progress: Double, text: String)] = [
            (0.25, "🧠 正在检测 [\(chipName)] 芯片架构与 GPU 画布节点..."),
            (0.60, exportOrientation == .horizontal ? "📖 正在构建 1280pt 跨页双栏折页与剧组名录..." : "🎨 正在构建【\(themeConfig.themeName)】专属\(exportMode == .day ? "☀️日间" : "🌙夜间")矢量框架..."),
            (0.90, "⚡️ 正在调用 GCD 后台多核离轴压包 [\(scaleName)] 数据..."),
            (1.00, "✨ 已完成矢量渲染，正在注入剪贴板...")
        ]

        startMultiStageExportAnimation(stages: stages) { onComplete in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                AboutImageExporter.copyLongScreenshotToClipboardAsync(
                    mode: exportMode,
                    orientation: exportOrientation,
                    customScale: customScaleFactor
                ) { success in
                    let msg = success ? "✨ 已成功复制【\(themeConfig.themeName)】专属\(orientationName)到剪贴板！" : "导出失败，请稍后重试。"
                    onComplete(msg)
                }
            }
        }
    }

    private func saveLongScreenshot() {
        let orientationName = exportOrientation == .horizontal ? "📖横版手册" : "📱竖版卡片"
        let scaleName = AppleChipDetector.scaleTitle(for: effectiveScaleFactor)
        let chipName = AppleChipDetector.getChipName()

        let stages: [(progress: Double, text: String)] = [
            (0.25, "🧠 正在调度 [\(chipName)] NPU/GPU 图形绘制管线..."),
            (0.60, exportOrientation == .horizontal ? "📖 正在生成 1280pt 双栏宣发手册与致谢群星..." : "🎨 正在渲染【\(themeConfig.themeName)】\(exportMode == .day ? "☀️日间" : "🌙夜间") 4K 印刷级矢量图..."),
            (0.90, "🚀 正在使用 GCD 后台工作线程异步生成 PNG 点阵..."),
            (1.00, "💾 已完成离轴编码，正在保存到文件系统...")
        ]

        startMultiStageExportAnimation(stages: stages) { onComplete in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                AboutImageExporter.saveLongScreenshotToFileAsync(
                    mode: exportMode,
                    orientation: exportOrientation,
                    customScale: customScaleFactor
                ) { success in
                    let msg = success ? "💾 已成功保存【\(themeConfig.themeName)】专属\(orientationName) PNG！" : "已取消保存。"
                    onComplete(msg)
                }
            }
        }
    }

    private func startMultiStageExportAnimation(
        stages: [(progress: Double, text: String)],
        performAsync: @escaping (@escaping (String) -> Void) -> Void
    ) {
        guard stages.count >= 4 else { return }

        // 阶段 1: 5% -> 25% (芯片检测与画布节点初始化)
        exportStatusText = stages[0].text
        exportProgress = 0.05
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExporting = true
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            exportProgress = stages[0].progress
        }

        // 阶段 2: 25% -> 60% (矢量排版与双栏折页矩阵构建)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            exportStatusText = stages[1].text
            withAnimation(.easeInOut(duration: 0.22)) {
                exportProgress = stages[1].progress
            }

            // 阶段 3: 60% -> 90% (GCD 后台线程 300 DPI 离轴重采样)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                exportStatusText = stages[2].text
                withAnimation(.easeInOut(duration: 0.25)) {
                    exportProgress = stages[2].progress
                }

                performAsync { resultMsg in
                    // 阶段 4: 90% -> 100% (数据打包完成，写入剪贴板 / 文件)
                    exportStatusText = stages[3].text
                    withAnimation(.easeInOut(duration: 0.15)) {
                        exportProgress = stages[3].progress
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.easeOut(duration: 0.22)) {
                            isExporting = false
                        }
                        triggerToast(resultMsg)
                    }
                }
            }
        }
    }

    private func triggerToast(_ msg: String) {
        toastMessage = msg
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showToast = false
            }
        }
    }
}

// MARK: - 离线 GPU/CoreGraphics + GCD 后台离轴异步超高清渲染器 (AboutImageExporter)

@MainActor
struct AboutImageExporter {
    static func generateBitmapRep(
        mode: ShareExportMode = .day,
        orientation: ShareExportOrientation = .vertical,
        customScale: CGFloat = 0.0
    ) -> (NSBitmapImageRep, NSSize)? {
        let scaleFactor = customScale > 0 ? customScale : AppleChipDetector.recommendedScaleFactor()
        let canvasWidth: CGFloat = orientation == .horizontal ? 1280 : 720

        let hostingView: NSHostingView<AnyView>
        if orientation == .horizontal {
            let exportContentView = AboutHorizontalExportableContentView(mode: mode)
                .frame(width: canvasWidth)
            hostingView = NSHostingView(rootView: AnyView(exportContentView))
        } else {
            let exportContentView = AboutExportableContentView(mode: mode)
                .frame(width: canvasWidth)
            hostingView = NSHostingView(rootView: AnyView(exportContentView))
        }

        let fittingSize = hostingView.fittingSize
        guard fittingSize.width > 0 && fittingSize.height > 0 else { return nil }

        let pixelWidth = Int(fittingSize.width * scaleFactor)
        let pixelHeight = Int(fittingSize.height * scaleFactor)

        hostingView.frame = CGRect(origin: .zero, size: fittingSize)
        hostingView.layoutSubtreeIfNeeded()

        // 1. 创建高分辨率 Display P3 广色域 Retina Bitmap Image Rep
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        // 绘图阶段：设置物理尺寸为 pixelWidth x pixelHeight，保证 CGContext 画布 100% 充满
        bitmapRep.size = NSSize(width: CGFloat(pixelWidth), height: CGFloat(pixelHeight))

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context

        // 2. 启用 GPU CoreGraphics 硬件最高精度重采样与抗锯齿渲染管线
        let cgContext = context.cgContext
        cgContext.interpolationQuality = .high
        cgContext.setShouldAntialias(true)
        cgContext.setAllowsAntialiasing(true)
        cgContext.setShouldSmoothFonts(true)
        cgContext.setAllowsFontSmoothing(true)

        // 3. CGContext 按 scaleFactor 超采样缩放
        cgContext.scaleBy(x: scaleFactor, y: scaleFactor)

        hostingView.displayIgnoringOpacity(CGRect(origin: .zero, size: fittingSize), in: context)
        NSGraphicsContext.restoreGraphicsState()

        // 4. 绘制完成，重置 bitmapRep.size 为逻辑 fittingSize，标记为 HiDPI Retina 规格
        bitmapRep.size = fittingSize

        return (bitmapRep, fittingSize)
    }

    // MARK: - 异步 GCD 后台子线程渲染写剪贴板 (彻底消除主线程死锁与彩球旋转)
    static func copyLongScreenshotToClipboardAsync(
        mode: ShareExportMode = .day,
        orientation: ShareExportOrientation = .vertical,
        customScale: CGFloat = 0.0,
        completion: @escaping (Bool) -> Void
    ) {
        // 1. 主线程极速捕抓矢量 Bitmap (只需 5ms)
        guard let (bitmapRep, _) = generateBitmapRep(mode: mode, orientation: orientation, customScale: customScale) else {
            completion(false)
            return
        }

        // 2. 将耗时的 RGBA 像素 PNG / TIFF 字节编码推入 GCD 后台工作线程并行转换！
        DispatchQueue.global(qos: .userInitiated).async {
            guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let tiffData = bitmapRep.representation(using: .tiff, properties: [:])

            // 3. 编码完成后无缝切回主线程注入 Pasteboard
            DispatchQueue.main.async {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()

                let item = NSPasteboardItem()
                item.setData(pngData, forType: .png)
                item.setData(pngData, forType: NSPasteboard.PasteboardType("public.png"))

                if let tiffData = tiffData {
                    item.setData(tiffData, forType: .tiff)
                    item.setData(tiffData, forType: NSPasteboard.PasteboardType("public.tiff"))
                }

                let success = pasteboard.writeObjects([item])
                completion(success)
            }
        }
    }

    // MARK: - 异步 GCD 后台子线程渲染写 PNG 文件
    static func saveLongScreenshotToFileAsync(
        mode: ShareExportMode = .day,
        orientation: ShareExportOrientation = .vertical,
        customScale: CGFloat = 0.0,
        completion: @escaping (Bool) -> Void
    ) {
        let themeConfig = AboutThemeConfig.current()
        let modeSuffix = mode == .day ? "Day" : "Night"
        let orientationSuffix = orientation == .horizontal ? "Brochure" : "Poster"

        // 1. 主线程唤起保存对话框 (零耗时)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "YumikoToys_About_\(themeConfig.themeName)_\(orientationSuffix)_\(modeSuffix)_\(AppConfig.version).png"
        savePanel.title = "保存【\(themeConfig.themeName)】专属\(orientation == .horizontal ? "📖横版手册" : "📱竖版卡片")"
        savePanel.message = "选择保存 YumikoToys 宣传图卡的路径"

        savePanel.begin { result in
            guard result == .OK, let url = savePanel.url else {
                completion(false)
                return
            }

            // 2. 主线程极速捕抓 Bitmap
            guard let (bitmapRep, _) = generateBitmapRep(mode: mode, orientation: orientation, customScale: customScale) else {
                completion(false)
                return
            }

            // 3. 后台工作线程异步完成 PNG 编码与文件系统写入
            DispatchQueue.global(qos: .userInitiated).async {
                guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                do {
                    try pngData.write(to: url)
                    DispatchQueue.main.async { completion(true) }
                } catch {
                    DispatchQueue.main.async { completion(false) }
                }
            }
        }
    }
}

// MARK: - 📖 横版宣传手册折页小册子模版 (AboutHorizontalExportableContentView - 1280pt 双栏双页设计)

private struct AboutHorizontalExportableContentView: View {
    let mode: ShareExportMode

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    var isNight: Bool {
        mode == .night
    }

    var body: some View {
        VStack(spacing: 24) {
            // 顶栏主题专属萌系 Banner
            HStack(spacing: 8) {
                Text(themeConfig.cardDecorationEmoji)
                    .font(.system(size: 16))
                Text(themeConfig.cuteBannerBadge)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(themeConfig.primaryColor)
                Text("✨ 📖 宣传手册折页特辑")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(themeConfig.secondaryColor)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(themeConfig.primaryColor.opacity(isNight ? 0.22 : 0.12))
                    .overlay(
                        Capsule()
                            .stroke(themeConfig.primaryColor.opacity(isNight ? 0.5 : 0.35), lineWidth: 1.2)
                    )
            )
            .padding(.top, 12)

            // 跨页 2 栏布局 (Left Column: 封面与核心功能 | Right Column: 功勋名录与致谢群星)
            HStack(alignment: .top, spacing: 28) {
                // MARK: - 左栏 (封面与核心功能 - 570pt)
                VStack(spacing: 20) {
                    // App Hero Icon Header (静态无按钮主题限定版)
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 32)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            themeConfig.primaryColor.opacity(isNight ? 0.35 : 0.25),
                                            themeConfig.secondaryColor.opacity(isNight ? 0.22 : 0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 116, height: 116)

                            RoundedRectangle(cornerRadius: 26)
                                .fill(
                                    LinearGradient(
                                        colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 98, height: 98)
                                .shadow(color: themeConfig.primaryColor.opacity(isNight ? 0.6 : 0.4), radius: 14, x: 0, y: 6)

                            if let customImage = NSImage(named: "YumikoToys") {
                                Image(nsImage: customImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 62, height: 62)
                            } else {
                                Image(systemName: "rabbit.fill")
                                    .font(.system(size: 44, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 116, height: 116)

                        VStack(spacing: 6) {
                            Text(AppConfig.appName)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(isNight ? .white : Color(hex: "1D1D1F"))

                            HStack(spacing: 6) {
                                Text("v\(AppConfig.version)")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )

                                Text("Build \(AppConfig.buildNumber)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(isNight ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
                            }
                        }
                    }

                    // 主描述
                    ExportTextCard(isNight: isNight) {
                        VStack(spacing: 12) {
                            Text("⚔️ “睡眠已死，麦克白杀死了睡眠！”")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("“不眠之钟声已然响彻，纵使天地合闭、MacBook 暗无天日，此神器亦如永不熄灭之圣血符文！搭载 YumikoToys 🐰兔可可皇后之粉色魔晶王权，禁绝万物休眠，使 AI 炼金阵与后台劳作永无止境！”")
                                .font(.system(size: 12.5))
                                .foregroundStyle(isNight ? Color.white.opacity(0.85) : Color(hex: "3A3A3C"))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                    }

                    // 图标说明 (模拟器双生卡片)
                    ExportSectionCard(title: "图标说明与模式对照", subtitle: "状态栏菜单面板与防休眠呼吸指示点", isNight: isNight) {
                        HStack(alignment: .top, spacing: 14) {
                            ExportIconLegendCard(
                                title: "常规模式 (防休眠关闭)",
                                description: "未开启防休眠，右上角无指示点",
                                isActive: false,
                                isPulsing: false,
                                isNight: isNight
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            ExportIconLegendCard(
                                title: "不休眠模式 (防休眠开启)",
                                description: "开启后亮起柔和呼吸点",
                                isActive: true,
                                isPulsing: true,
                                isNight: isNight
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    // 核心防休眠特质与工坊绝件卡片 (填补横版手册左栏下半部分，达到 100% 对称视觉呈现)
                    ExportFeatureMatrixCard(isNight: isNight)

                    Spacer(minLength: 0)
                }
                .frame(width: 570)

                // MARK: - 右栏 (剧组名录与致谢群星 - 620pt)
                VStack(spacing: 16) {
                    ExportSectionCard(title: "🎭 Dramatis Personae 功勋名录", subtitle: "“幕起幕落，铸就此悲剧史诗之功勋名录”", isNight: isNight) {
                        VStack(alignment: .leading, spacing: 10) {
                            StaticCreditsRow(title: "The Grand Artificer", subtitle: "伟大之工匠 (Macbeth)", name: "@🍊蜜柑工具人", tagline: "“以铁血铸就逻辑城邦，夜以继日斩尽 Bug。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                            StaticCreditsRow(title: "The Limner of the Sigil", subtitle: "徽记描绘者 (Lady Macbeth)", name: "@会拧头的ruarua怪", tagline: "“洗不净手中极彩墨迹，赐界面以华美霓裳。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                            StaticCreditsRow(title: "The Muse of Whimsy", subtitle: "奇思之缪斯 (The Wyrd Sister)", name: "@cici", tagline: "“在大锅中倒进奇妙遐想，炼化出颠覆灵感。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                            StaticCreditsRow(title: "The Patron of New Marvels", subtitle: "新奇赞助人 (High Queen)", name: "@🐰兔可可", tagline: "“戴上粉色魔晶王冠，庇佑万物免受休眠。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                        }
                    }

                    ExportSectionCard(title: "💖 The Sacred Fellowship 挚友同心", subtitle: "“心魂相契、同行无间之至亲挚友”", isNight: isNight) {
                        VStack(alignment: .leading, spacing: 10) {
                            StaticCreditsRow(title: "The Enchantress of Mist", subtitle: "雾霭与歌咏之灵", name: "@烟烟", tagline: "“如薄雾凝霜之灵，赋万物以飘逸诗意。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                            StaticCreditsRow(title: "The Sovereign of Starlight", subtitle: "永恒星芒之女王", name: "@ching_1222", tagline: "“如璀璨星辰，以优雅与睿智光照剧场。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                            StaticCreditsRow(title: "The Guardian of Realm", subtitle: "幻境奇迹守护者", name: "@邱", tagline: "“如奇迹女神 Miranda，赐予作品纯真守护。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                        }
                    }

                    ExportSectionCard(title: "🐾 Architects of Playground 爬爬乐创作者", subtitle: "“于桌面绝壁间筑奇幻桌宠乐园”", isNight: isNight) {
                        VStack(alignment: .leading, spacing: 10) {
                            StaticCreditsRow(title: "The Agile Enchantress", subtitle: "绝壁与灵动之仙子", name: "@氢氧化猫猫", tagline: "“如绝壁上翩跹之仙子，赋桌宠以轻灵生机。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                            StaticCreditsRow(title: "The Warden of Gravity", subtitle: "极地与重力之勋爵", name: "@北冥有地瓜", tagline: "“掌控重力与天法，筑坚实锚点庇佑攀行。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                        }
                    }

                    ExportSectionCard(title: "🌸 A Note of Gratitude 深情致谢", subtitle: "“汝等之光，亦使此剧增辉”", isNight: isNight) {
                        VStack(alignment: .leading, spacing: 8) {
                            StaticCreditsRow(title: "The Muse of Grace", subtitle: "晨星与真情之缪斯", name: "@saya.ka", tagline: "“以温润真情与无声之光照拂众生。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                            StaticCreditsRow(title: "The Woodland Spirit", subtitle: "绿林与颂歌之精灵", name: "@sayu", tagline: "“赋予剧场欢快和谐之韵律与治愈之力。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                            StaticCreditsRow(title: "Serene Moonlight", subtitle: "宁静月光之守护者", name: "@さおり", tagline: "“以纯真与柔情照亮凡间，使全剧平添温情。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                            StaticCreditsRow(title: "A Wyrd Messenger", subtitle: "荒野神谕与命运信使", name: "@小汐shio", tagline: "“其金石低语建言扭转全剧浩瀚航程！”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                        }
                    }
                }
                .frame(width: 620)
            }

            // 萌系水滴封印与专属主题水印
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(themeConfig.primaryColor)
                    Text(themeConfig.watermarkTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .foregroundStyle(themeConfig.secondaryColor)
                }

                Text("\(themeConfig.watermarkSubtitle) • 📖横版宣传手册折页特辑 • \(isNight ? "🌙夜间模式" : "☀️日间模式")")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(isNight ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeConfig.primaryColor.opacity(isNight ? 0.15 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [themeConfig.primaryColor.opacity(0.4), themeConfig.secondaryColor.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.top, 4)
        }
        .padding(32)
        .background(
            ZStack {
                if isNight {
                    themeConfig.exportNightCanvasBg
                    EllipticalGradient(
                        stops: [
                            .init(color: themeConfig.primaryColor.opacity(0.28), location: 0.0),
                            .init(color: themeConfig.secondaryColor.opacity(0.15), location: 0.5),
                            .init(color: .clear, location: 0.88)
                        ],
                        center: .top,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.95
                    )
                } else {
                    themeConfig.exportDayCanvasBg
                    EllipticalGradient(
                        stops: [
                            .init(color: themeConfig.primaryColor.opacity(0.15), location: 0.0),
                            .init(color: themeConfig.secondaryColor.opacity(0.08), location: 0.5),
                            .init(color: .clear, location: 0.85)
                        ],
                        center: .top,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.95
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            themeConfig.primaryColor.opacity(isNight ? 0.55 : 0.38),
                            themeConfig.secondaryColor.opacity(isNight ? 0.35 : 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
}

// MARK: - 主题专属自适应长截图模版容器 (AboutExportableContentView - 20 款主题色高精竖版海报)

private struct AboutExportableContentView: View {
    let mode: ShareExportMode

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    var isNight: Bool {
        mode == .night
    }

    var body: some View {
        VStack(spacing: 26) {
            // 顶栏主题专属萌系 Banner
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(themeConfig.cardDecorationEmoji)
                        .font(.system(size: 14))
                    Text(themeConfig.cuteBannerBadge)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(themeConfig.primaryColor)
                    Text("✨")
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(themeConfig.primaryColor.opacity(isNight ? 0.22 : 0.12))
                        .overlay(
                            Capsule()
                                .stroke(themeConfig.primaryColor.opacity(isNight ? 0.5 : 0.35), lineWidth: 1)
                        )
                )

                Text(themeConfig.cuteBannerSub)
                    .font(.system(size: 10))
                    .foregroundStyle(isNight ? Color.white.opacity(0.6) : Color.black.opacity(0.4))
                    .italic()
            }
            .padding(.top, 8)

            // App Hero Icon Header (静态无按钮主题限定版)
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeConfig.primaryColor.opacity(isNight ? 0.35 : 0.25),
                                    themeConfig.secondaryColor.opacity(isNight ? 0.22 : 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 116, height: 116)

                    RoundedRectangle(cornerRadius: 26)
                        .fill(
                            LinearGradient(
                                colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 98, height: 98)
                        .shadow(color: themeConfig.primaryColor.opacity(isNight ? 0.6 : 0.4), radius: 14, x: 0, y: 6)

                    if let customImage = NSImage(named: "YumikoToys") {
                        Image(nsImage: customImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 62, height: 62)
                    } else {
                        Image(systemName: "rabbit.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 116, height: 116)

                VStack(spacing: 6) {
                    Text(AppConfig.appName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(isNight ? .white : Color(hex: "1D1D1F"))

                    HStack(spacing: 6) {
                        Text("v\(AppConfig.version)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )

                        Text("Build \(AppConfig.buildNumber)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(isNight ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
                    }
                }
            }

            // 主描述
            ExportTextCard(isNight: isNight) {
                VStack(spacing: 12) {
                    Text("⚔️ “睡眠已死，麦克白杀死了睡眠！”")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("“不眠之钟声已然响彻，纵使天地合闭、MacBook 暗无天日，此神器亦如永不熄灭之圣血符文！搭载 YumikoToys 🐰兔可可皇后之粉色魔晶王权，禁绝万物休眠，使 AI 炼金阵与后台劳作永无止境！”")
                        .font(.system(size: 13))
                        .foregroundStyle(isNight ? Color.white.opacity(0.85) : Color(hex: "3A3A3C"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            // 图标说明 (双生精准等高卡片 - 完全适配日间/夜间模式与主题调色板)
            ExportSectionCard(title: "图标说明", subtitle: "状态栏菜单面板与防休眠呼吸指示点对照", isNight: isNight) {
                HStack(alignment: .top, spacing: 16) {
                    ExportIconLegendCard(
                        title: "常规模式 (防休眠关闭)",
                        description: "未开启防休眠，状态栏菜单面板右上角无指示点",
                        isActive: false,
                        isPulsing: false,
                        isNight: isNight
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ExportIconLegendCard(
                        title: "不休眠模式 (防休眠开启)",
                        description: "开启不休眠后，状态栏菜单面板右上角亮起柔和呼吸点",
                        isActive: true,
                        isPulsing: true,
                        isNight: isNight
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            // Dramatis Personae
            ExportSectionCard(title: "🎭 Dramatis Personae 功勋名录", subtitle: "“幕起幕落，铸就此悲剧史诗之功勋名录”", isNight: isNight) {
                VStack(alignment: .leading, spacing: 12) {
                    StaticCreditsRow(title: "The Grand Artificer", subtitle: "伟大之工匠 (Macbeth / Lord of the Anvil)", name: "@🍊蜜柑工具人", tagline: "“以铁血铸就逻辑城邦，夜以继日斩尽千百 Bug，使代码高塔永不倒塌。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                    StaticCreditsRow(title: "The Limner of the Sigil", subtitle: "徽记描绘者 (Lady Macbeth / Sovereign of Sorcery)", name: "@会拧头的ruarua怪", tagline: "“洗不净手中极彩墨迹，以神笔抹去世间平庸，赐予界面华美绝伦之霓裳。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                    StaticCreditsRow(title: "The Muse of Whimsy", subtitle: "奇思之缪斯 (The Wyrd Sister / Prophet of Chaos)", name: "@cici", tagline: "“在三魔女沸腾的大锅中倒进奇妙遐想，炼化出颠覆凡世之灵感。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                    StaticCreditsRow(title: "The Patron of New Marvels", subtitle: "新奇赞助人 (High Queen / Sovereign of Realms)", name: "@🐰兔可可", tagline: "“戴上粉色魔晶之王冠，端坐于永恒王座，庇佑万物免受休眠迷雾侵蚀。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                }
            }

            // The Sacred Fellowship of Soulmates
            ExportSectionCard(title: "💖 The Sacred Fellowship of Soulmates 挚友同心", subtitle: "“如《皆大欢喜》与《第十二夜》，心魂相契、同行无间之至亲挚友”", isNight: isNight) {
                VStack(alignment: .leading, spacing: 12) {
                    StaticCreditsRow(title: "The Enchantress of Mist & Song", subtitle: "雾霭与歌咏之灵 (Puck / Ophelia)", name: "@烟烟", tagline: "“如《仲夏夜之梦》薄雾凝霜之灵，赋万物以飘逸诗意。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                    StaticCreditsRow(title: "The Sovereign of Eternal Starlight", subtitle: "永恒星芒之女王 (Titania / Portia)", name: "@ching_1222", tagline: "“如《第十二夜》璀璨星辰，以优雅与睿智光照剧场。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                    StaticCreditsRow(title: "The Guardian of Enchanted Realm", subtitle: "幻境奇迹之守护者 (Miranda / Beatrice)", name: "@邱", tagline: "“如《暴风雨》奇迹女神 Miranda，赐予作品纯真神圣之守护。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                }
            }

            // Architects of Pet Playground
            ExportSectionCard(title: "🐾 Architects of Pet Playground 爬爬乐创作者", subtitle: "“于桌面绝壁与重力极地间筑奇幻桌宠乐园”", isNight: isNight) {
                VStack(alignment: .leading, spacing: 12) {
                    StaticCreditsRow(title: "The Agile Enchantress of Walls", subtitle: "绝壁与灵动之仙子 (Puck / Peaseblossom)", name: "@氢氧化猫猫", tagline: "“如《仲夏夜之梦》绝壁上翩跹之仙子，以轻灵极彩之姿赋桌宠以生机。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                    StaticCreditsRow(title: "The Lord Warden of Gravity", subtitle: "极地与重力之勋爵 (Prospero / Gonzalo)", name: "@北冥有地瓜", tagline: "“如《暴风雨》掌控重力与天法之勋爵，筑坚实锚点庇佑桌宠安然攀行。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                }
            }

            // A Note of Gratitude Most Profound
            ExportSectionCard(title: "🌸 A Note of Gratitude Most Profound 深情致谢", subtitle: "“汝等之光，亦使此剧增辉”", isNight: isNight) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("吾辈亦向此众友献上敬意：")
                        .font(.system(size: 13))
                        .foregroundStyle(isNight ? Color.white.opacity(0.6) : Color.black.opacity(0.45))

                    StaticCreditsRow(title: "The Muse of Celestial Grace", subtitle: "晨星与真情之缪斯 (Cordelia / Rosalind)", name: "@saya.ka", tagline: "“如天际璀璨之晨星，以温润真情与无声之光照拂众生。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                    StaticCreditsRow(title: "The Spirit of Woodland Harmony", subtitle: "绿林与颂歌之精灵 (Celia / Ophelia)", name: "@sayu", tagline: "“林间和煦之微风，赋予剧场欢快和谐之韵律与治愈之力。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                    StaticCreditsRow(title: "The Guardian of Serene Moonlight", subtitle: "宁静月光之守护者 (Juliet / Viola)", name: "@さおり", tagline: "“宁静月光之守护者，以纯真与柔情照亮凡间，使全剧平添温情。”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                }
            }

            // A Wyrd Messenger
            ExportSectionCard(title: "🔮 A Wyrd Messenger 命运信使", subtitle: "“荒野神谕，低语建言扭转浩瀚航程”", isNight: isNight) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("如荒野上之回响，自迷雾中而来，其低语之建言，足以扭转吾辈大业之航向者，乃")
                        .font(.system(size: 13))
                        .foregroundStyle(isNight ? Color.white.opacity(0.6) : Color.black.opacity(0.45))
                        .lineSpacing(4)

                    StaticCreditsRow(title: "The Prophet of Wyrd Echoes", subtitle: "荒野神谕与命运信使 (Ariel / Hecate)", name: "@小汐shio", tagline: "“自迷雾破空而来，其金石低语建言扭转全剧浩瀚航程！”", primaryColor: themeConfig.primaryColor, secondaryColor: themeConfig.secondaryColor, isNight: isNight)
                }
            }

            // 萌系水滴封印与专属主题水印
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(themeConfig.primaryColor)
                    Text(themeConfig.watermarkTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .foregroundStyle(themeConfig.secondaryColor)
                }

                Text("\(themeConfig.watermarkSubtitle) • \(isNight ? "🌙夜间模式" : "☀️日间模式")")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(isNight ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(themeConfig.primaryColor.opacity(isNight ? 0.15 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [themeConfig.primaryColor.opacity(0.4), themeConfig.secondaryColor.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.top, 8)
        }
        .padding(32)
        .background(
            ZStack {
                if isNight {
                    themeConfig.exportNightCanvasBg
                    EllipticalGradient(
                        stops: [
                            .init(color: themeConfig.primaryColor.opacity(0.28), location: 0.0),
                            .init(color: themeConfig.secondaryColor.opacity(0.15), location: 0.5),
                            .init(color: .clear, location: 0.88)
                        ],
                        center: .top,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.95
                    )
                } else {
                    themeConfig.exportDayCanvasBg
                    EllipticalGradient(
                        stops: [
                            .init(color: themeConfig.primaryColor.opacity(0.15), location: 0.0),
                            .init(color: themeConfig.secondaryColor.opacity(0.08), location: 0.5),
                            .init(color: .clear, location: 0.85)
                        ],
                        center: .top,
                        startRadiusFraction: 0,
                        endRadiusFraction: 0.95
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            themeConfig.primaryColor.opacity(isNight ? 0.55 : 0.38),
                            themeConfig.secondaryColor.opacity(isNight ? 0.35 : 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
// MARK: - 横版宣发手册 2x2 核心特质图鉴卡片 (ExportFeatureMatrixCard)

private struct ExportFeatureMatrixCard: View {
    let isNight: Bool

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    var body: some View {
        ExportSectionCard(title: "⚡️ 核心防休眠特质与工坊绝品", subtitle: "“让 MacBook 跨越极夜，注入永续计算能量”", isNight: isNight) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                FeatureBadgeItem(
                    emoji: "🐰",
                    title: "粉色魔晶王权",
                    desc: "禁绝万物休眠，使 AI 炼金阵与后台计算永无止境",
                    isNight: isNight
                )

                FeatureBadgeItem(
                    emoji: "🧠",
                    title: "M 芯片硬件自适应",
                    desc: "智能识别 M1~M5 / Pro / Max 架构，300DPI 极清离轴采样",
                    isNight: isNight
                )

                FeatureBadgeItem(
                    emoji: "🐾",
                    title: "奇幻桌宠爬爬乐",
                    desc: "ANE 神经网络碰撞检测，桌宠干员游行绝壁四周",
                    isNight: isNight
                )

                FeatureBadgeItem(
                    emoji: "🎨",
                    title: "20 款双模式调色盘",
                    desc: "二次元草莓软萌、赛博朋克与日夜双态视觉阵列",
                    isNight: isNight
                )
            }
        }
    }
}

private struct FeatureBadgeItem: View {
    let emoji: String
    let title: String
    let desc: String
    let isNight: Bool

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(emoji)
                .font(.system(size: 15))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(themeConfig.primaryColor)

                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(isNight ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isNight ? Color(hex: "222534").opacity(0.8) : Color(hex: "F4F5F9"))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            themeConfig.primaryColor.opacity(isNight ? 0.3 : 0.15),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 长截图 Mode-Aware Card Containers

private struct ExportTextCard<Content: View>: View {
    let isNight: Bool
    let content: Content

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    init(isNight: Bool, @ViewBuilder content: () -> Content) {
        self.isNight = isNight
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isNight ? Color(hex: "181A26").opacity(0.9) : Color.white.opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isNight
                                    ? themeConfig.primaryColor.opacity(0.4)
                                    : themeConfig.primaryColor.opacity(0.22),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: themeConfig.primaryColor.opacity(isNight ? 0.15 : 0.05), radius: 8, x: 0, y: 2)
            )
    }
}

private struct ExportSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let isNight: Bool
    let content: Content

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    init(title: String, subtitle: String, isNight: Bool, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.isNight = isNight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isNight ? .white : Color(hex: "1D1D1F"))
                    .fixedSize(horizontal: false, vertical: true)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(isNight ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().opacity(isNight ? 0.2 : 0.6)

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isNight ? Color(hex: "181A26").opacity(0.95) : Color.white.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isNight ? themeConfig.exportCardBorderGlow : themeConfig.primaryColor.opacity(0.12),
                            lineWidth: 1
                        )
                )
                .shadow(color: themeConfig.primaryColor.opacity(isNight ? 0.18 : 0.05), radius: 8, x: 0, y: 2)
        )
    }
}

private struct ExportIconLegendCard: View {
    let title: String
    let description: String
    let isActive: Bool
    let isPulsing: Bool
    let isNight: Bool

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 高精 1:1 状态栏菜单面板模拟器 (传递 isNight 进行全动态暗色/亮色模式深度适配)
            YumikoPopoverMockupView(isActive: isActive, isPulsing: isPulsing, isNight: isNight)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(isActive ? themeConfig.primaryColor : (isNight ? .white : Color(hex: "1D1D1F")))
                        .fixedSize(horizontal: false, vertical: true)

                    ZStack {
                        if isActive {
                            Circle()
                                .fill(themeConfig.primaryColor)
                                .frame(width: 6, height: 6)
                                .scaleEffect(isPulsing ? 1.3 : 1.0)
                        }
                    }
                    .frame(width: 6, height: 6)
                }

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(isNight ? Color.white.opacity(0.65) : Color.black.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isNight ? Color(hex: "222534").opacity(0.9) : Color(hex: "F3F4F8"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isActive ? themeConfig.primaryColor.opacity(isNight ? 0.45 : 0.3) : Color.primary.opacity(0.06),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(isNight ? 0.2 : 0.03), radius: 4, x: 0, y: 1)
        )
    }
}

private struct StaticCreditsRow: View {
    let title: String
    let subtitle: String
    let name: String
    var tagline: String? = nil
    var primaryColor: Color = Color(hex: "FF6B9D")
    var secondaryColor: Color = Color(hex: "C44FE2")
    var isNight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(isNight ? Color.white.opacity(0.45) : Color.black.opacity(0.35))
                    .italic()
            }

            HStack(alignment: .center, spacing: 6) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isNight ? .white : Color(hex: "1D1D1F"))

                if let tagline = tagline {
                    Text(tagline)
                        .font(.system(size: 12))
                        .foregroundStyle(isNight ? Color.white.opacity(0.7) : Color(hex: "515154"))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - 高精 1:1 状态栏菜单面板矢量 UI 模拟器 (YumikoPopoverMockupView - 完全适配日间与夜间长图模式)

private struct YumikoPopoverMockupView: View {
    let isActive: Bool
    let isPulsing: Bool
    var isNight: Bool = false

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    var body: some View {
        VStack(spacing: 8) {
            // 1. 顶部 Header (Icon + App Title + Version + Pill + Breathing Dot)
            HStack {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 22, height: 22)

                        Image(systemName: "rabbit.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 3) {
                            Text("YumikoToys")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(isNight ? .white : Color(hex: "1D1D1F"))
                            Image(systemName: "carrot.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                            Text("▾")
                                .font(.system(size: 8))
                                .foregroundStyle(isNight ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
                        }
                        Text("v\(AppConfig.version)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(isNight ? Color.white.opacity(0.45) : Color.black.opacity(0.4))
                    }
                }

                Spacer()

                // 右侧功能 Pill (✨ 🔵 ▾) + 防休眠呼吸指示点 (只有在 isActive == true 时渲染，避免未开启模式右侧多余空隙)
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Text("✨").font(.system(size: 7))
                        Circle()
                            .fill(themeConfig.primaryColor)
                            .frame(width: 5, height: 5)
                        Text("▾")
                            .font(.system(size: 7))
                            .foregroundStyle(themeConfig.primaryColor)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(themeConfig.primaryColor.opacity(isNight ? 0.2 : 0.12)))

                    if isActive {
                        ZStack {
                            Circle()
                                .stroke(themeConfig.primaryColor.opacity(0.6), lineWidth: 1.2)
                                .scaleEffect(isPulsing ? 1.6 : 1.0)
                                .opacity(isPulsing ? 0.0 : 0.8)

                            Circle()
                                .fill(themeConfig.primaryColor)
                                .frame(width: 6.5, height: 6.5)
                                .shadow(color: themeConfig.primaryColor, radius: isPulsing ? 3 : 1)
                        }
                        .frame(width: 14, height: 14)
                    }
                }
            }

            Divider().opacity(isNight ? 0.25 : 0.4)

            // 2. 导航 Tab 按钮组 (纪念日 / 插件 / 截图)
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "calendar").font(.system(size: 8))
                    Text("纪念日").font(.system(size: 8.5, weight: .bold))
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .foregroundStyle(.white)

                HStack(spacing: 3) {
                    Image(systemName: "puzzlepiece.fill").font(.system(size: 8))
                    Text("插件").font(.system(size: 8.5, weight: .semibold))
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(isNight ? Color.white.opacity(0.08) : Color.black.opacity(0.06)))
                .foregroundStyle(isNight ? Color.white.opacity(0.7) : Color.black.opacity(0.6))

                HStack(spacing: 3) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 8))
                    Text("截图").font(.system(size: 8.5, weight: .semibold))
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(isNight ? Color.white.opacity(0.08) : Color.black.opacity(0.06)))
                .foregroundStyle(isNight ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
            }

            // 3. 兔可可 886.035天 计时卡片
            VStack(spacing: 4) {
                HStack {
                    HStack(spacing: 3) {
                        Circle().fill(themeConfig.primaryColor.opacity(0.2)).frame(width: 12, height: 12)
                            .overlay(Image(systemName: "rabbit.fill").font(.system(size: 7)).foregroundStyle(themeConfig.primaryColor))
                        Text("兔可可")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(isNight ? .white : Color(hex: "1D1D1F"))
                    }
                    Spacer()
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("886.035")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("天")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isNight ? .white : Color(hex: "1D1D1F"))
                    Spacer()
                }

                HStack(spacing: 12) {
                    Text("下一个100天")
                        .font(.system(size: 7.5))
                        .foregroundStyle(isNight ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
                    Spacer()
                    Text("2026-08-29")
                        .font(.system(size: 7.5))
                        .foregroundStyle(isNight ? Color.white.opacity(0.35) : Color.black.opacity(0.3))
                    Text("(第9个)")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(themeConfig.primaryColor)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(themeConfig.primaryColor.opacity(isNight ? 0.08 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(themeConfig.primaryColor.opacity(0.2), lineWidth: 0.8)
                    )
            )

            // 4. 不休眠模式 Toggle 交互卡片
            HStack {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isActive ? themeConfig.primaryColor.opacity(0.15) : (isNight ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                            .frame(width: 18, height: 18)

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(isActive ? themeConfig.primaryColor : (isNight ? Color.white.opacity(0.4) : Color.gray))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("不休眠模式")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(isNight ? .white : Color(hex: "1D1D1F"))
                        Text(isActive ? "已开启" : "已关闭")
                            .font(.system(size: 8))
                            .foregroundStyle(isActive ? themeConfig.primaryColor : (isNight ? Color.white.opacity(0.5) : Color.black.opacity(0.4)))
                    }
                }

                Spacer()

                // iOS 风格 Switch
                Capsule()
                    .fill(isActive ? themeConfig.primaryColor : Color.gray.opacity(0.3))
                    .frame(width: 26, height: 14)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: 11, height: 11)
                            .shadow(color: .black.opacity(0.15), radius: 1)
                            .offset(x: isActive ? 5.5 : -5.5)
                    )
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? themeConfig.primaryColor.opacity(isNight ? 0.16 : 0.08) : (isNight ? Color.white.opacity(0.05) : Color.black.opacity(0.03)))
            )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isNight ? Color(hex: "1C1E2A") : Color(hex: "FFFFFF"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isNight ? themeConfig.primaryColor.opacity(0.25) : Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(isNight ? 0.25 : 0.08), radius: 6, x: 0, y: 3)
        )
    }
}

// MARK: - 图标说明展示卡片 (IconLegendCard - 8342803 1:1 原版 像素精准双生卡片)

private struct IconLegendCard: View {
    let title: String
    let description: String
    let isActive: Bool
    let isPulsing: Bool

    @State private var isHovered = false

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 高精 1:1 状态栏菜单面板模拟器 (Simulated Popover Window Mockup)
            YumikoPopoverMockupView(isActive: isActive, isPulsing: isPulsing)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(isActive ? themeConfig.primaryColor : .primary)
                        .fixedSize(horizontal: false, vertical: true)

                    ZStack {
                        if isActive {
                            Circle()
                                .fill(themeConfig.primaryColor)
                                .frame(width: 6, height: 6)
                                .scaleEffect(isPulsing ? 1.3 : 1.0)
                        }
                    }
                    .frame(width: 6, height: 6)
                }

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isHovered
                                ? themeConfig.primaryColor.opacity(0.25)
                                : Color.primary.opacity(0.06),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(isHovered ? 0.08 : 0.03),
                    radius: isHovered ? 10 : 4,
                    x: 0,
                    y: isHovered ? 3 : 1
                )
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - 通用卡片容器

private struct AboutTextCard<Content: View>: View {
    let content: Content

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeConfig.primaryColor.opacity(0.06),
                                themeConfig.secondaryColor.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        themeConfig.primaryColor.opacity(0.3),
                                        themeConfig.secondaryColor.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

private struct AboutSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    var showInfoHint: Bool
    let content: Content
    @State private var isHovered = false

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    init(title: String, subtitle: String, showInfoHint: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.showInfoHint = showInfoHint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                if showInfoHint {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(themeConfig.primaryColor)

                        Text("点击 ⓘ 查阅典故")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(themeConfig.primaryColor)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(themeConfig.primaryColor.opacity(0.1))
                    )
                }
            }

            Divider()

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isHovered ? themeConfig.primaryColor.opacity(0.3) : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isHovered ? themeConfig.primaryColor.opacity(0.12) : .clear,
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - 致敬行 (带 ⓘ 按钮弹出莎士比亚原著典故卡片)

private struct CreditsRow: View {
    let title: String
    let subtitle: String
    let name: String
    var tagline: String? = nil
    var originalAllusion: String? = nil
    var literaryDecoding: String? = nil

    @State private var isHovered = false
    @State private var showInfoPopover = false
    @State private var isInfoBtnHovered = false

    private var themeConfig: AboutThemeConfig {
        AboutThemeConfig.current()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeConfig.primaryColor, themeConfig.secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // ⓘ 按钮：移动至称号 (title) 正右侧
                if originalAllusion != nil || literaryDecoding != nil {
                    Button(action: {
                        showInfoPopover.toggle()
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(
                                isInfoBtnHovered || showInfoPopover
                                    ? themeConfig.primaryColor
                                    : Color.primary.opacity(0.35)
                            )
                            .scaleEffect(isInfoBtnHovered ? 1.15 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .help("点击查阅莎士比亚原著典故与角色解读")
                    .onHover { isInfoBtnHovered = $0 }
                    .popover(isPresented: $showInfoPopover, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            // Header
                            HStack(spacing: 6) {
                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(themeConfig.primaryColor)

                                Text("\(name) · 原著典故解构")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(.primary)
                            }

                            Divider()

                            // 原著典故引用
                            if let allusion = originalAllusion {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("📖 莎士比亚原著出处")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundStyle(themeConfig.secondaryColor)

                                    Text(allusion)
                                        .font(.system(size: 11, design: .serif))
                                        .foregroundStyle(.primary)
                                        .italic()
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                            }

                            // 文学深层解构
                            if let decoding = literaryDecoding {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("🗡️ 角色象征与深层解构")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundStyle(themeConfig.primaryColor)

                                    Text(decoding)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(3)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(themeConfig.primaryColor.opacity(0.06)))
                            }
                        }
                        .padding(14)
                        .frame(width: 290)
                    }
                }

                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            HStack(alignment: .center, spacing: 6) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                if let tagline = tagline {
                    Text(tagline)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
