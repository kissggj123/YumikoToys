//
//  AboutView.swift
//  YumikoToys
//
//  关于页面视图（v4.5.7 - Shakespearean Macbeth Allusion Popovers, Vector Info Buttons & Classic Pink Icon Legend）
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AboutView: View {
    @State private var isIconHovered = false
    @State private var isBreathingDotPulse = false
    @State private var showExportMenu = false
    @State private var showToast = false
    @State private var toastMessage = ""

    private var themeGradientColors: [Color] {
        if AnimeThemeService.shared.isEnabled {
            return AnimeThemeService.shared.gradient()
        }
        let settings = DependencyContainer.shared.settingsService.settings
        let themeColor = settings.mainWindowThemeColor
        return themeColor.iconGradient(customHex: settings.customMainWindowThemeColorHex)
    }

    private var primaryColor: Color {
        themeGradientColors.first ?? Color(hex: "FF6B9D")
    }

    private var secondaryColor: Color {
        themeGradientColors.count > 1 ? themeGradientColors[1] : Color(hex: "C44FE2")
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
                                        colors: [primaryColor, secondaryColor],
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

                    // MARK: - 图标说明 (Icon Legend)
                    AboutSectionCard(title: "图标说明", subtitle: "状态栏菜单面板与防休眠呼吸指示点对照") {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                // 关闭状态预览
                                IconLegendCard(
                                    title: "常规模式 (防休眠关闭)",
                                    description: "未开启防休眠，状态栏菜单面板右上角无指示点",
                                    isActive: false,
                                    isPulsing: false
                                )

                                // 开启状态预览
                                IconLegendCard(
                                    title: "不休眠模式 (防休眠开启)",
                                    description: "开启不休眠后，状态栏菜单面板右上角亮起柔和呼吸点",
                                    isActive: true,
                                    isPulsing: isBreathingDotPulse
                                )
                            }
                        }
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
                                literaryDecoding: "麦克白身披重铠，执掌铁血宝剑。作为代码高塔的伟大工匠，日夜披荆斩棘斩尽千百 Bug，以无畏魄力捍卫程序城邦！"
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
                    AboutSectionCard(title: "The Sacred Fellowship of Soulmates", subtitle: "“如《皆大欢喜》与《第十二夜》，心魂相契、同行无间之至亲挚友”", showInfoHint: true) {
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
                    AboutSectionCard(title: "Architects of Pet Playground", subtitle: "“于桌面绝壁与重力极地间筑奇幻桌宠乐园”", showInfoHint: true) {
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
                    AboutSectionCard(title: "A Note of Gratitude Most Profound", subtitle: "“汝等之光，亦使此剧增辉”", showInfoHint: true) {
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
                    AboutSectionCard(title: "A Wyrd Messenger", subtitle: "“荒野神谕，低语建言扭转浩瀚航程”", showInfoHint: true) {
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

            // MARK: - Floating Toast Notification
            if showToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(primaryColor)
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
                                .stroke(primaryColor.opacity(0.35), lineWidth: 1)
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
                    stops: [
                        .init(color: primaryColor.opacity(0.08), location: 0.0),
                        .init(color: secondaryColor.opacity(0.04), location: 0.5),
                        .init(color: .clear, location: 0.85)
                    ],
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

    // MARK: - Hero Icon Header & Export Action Bar
    private var appHeroHeader: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        primaryColor.opacity(0.25),
                                        secondaryColor.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 112, height: 112)
                            .scaleEffect(isIconHovered ? 1.06 : 1.0)
                            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isIconHovered)

                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [primaryColor, secondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                            .shadow(
                                color: primaryColor.opacity(isIconHovered ? 0.5 : 0.3),
                                radius: isIconHovered ? 20 : 10,
                                x: 0,
                                y: isIconHovered ? 8 : 4
                            )

                        if let customImage = NSImage(named: "YumikoToys") {
                            Image(nsImage: customImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                        } else {
                            Image(systemName: "rabbit.fill")
                                .font(.system(size: 42, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    .onHover { isIconHovered = $0 }

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
                                                colors: [primaryColor, secondaryColor],
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

                // 导出/分享长图按钮
                Menu {
                    Button(action: copyLongScreenshot) {
                        Label("复制关于界面梦幻长图 (剪贴板)", systemImage: "doc.on.doc.fill")
                    }

                    Button(action: saveLongScreenshot) {
                        Label("保存长图为文件 (.png)", systemImage: "square.and.arrow.down.fill")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "photo.badge.plus.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("分享长图")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [primaryColor, secondaryColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: primaryColor.opacity(0.35), radius: 6, x: 0, y: 2)
                    )
                }
                .menuStyle(.borderlessButton)
                .help("生成并分享关于界面的萌系梦幻超长截图")
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Screenshot Export Actions
    private func copyLongScreenshot() {
        if AboutImageExporter.copyLongScreenshotToClipboard() {
            triggerToast("✨ 已成功复制《关于》界面 1:1 萌系梦幻超长截图到剪贴板，可直接粘贴分享！")
        } else {
            triggerToast("导出长图失败，请稍后重试。")
        }
    }

    private func saveLongScreenshot() {
        AboutImageExporter.saveLongScreenshotToFile { success in
            if success {
                triggerToast("💾 已成功将《关于》萌系梦幻长图保存为 PNG 文件！")
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

// MARK: - 离线高清长图导出渲染器 (AboutImageExporter)

@MainActor
struct AboutImageExporter {
    static func generateLongScreenshot(width: CGFloat = 720) -> NSImage? {
        let exportContentView = AboutExportableContentView()
            .frame(width: width)

        let hostingView = NSHostingView(rootView: exportContentView)
        let fittingSize = hostingView.fittingSize
        hostingView.frame = CGRect(origin: .zero, size: fittingSize)
        hostingView.layoutSubtreeIfNeeded()

        guard fittingSize.width > 0 && fittingSize.height > 0 else { return nil }

        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else { return nil }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        let image = NSImage(size: fittingSize)
        image.addRepresentation(bitmapRep)
        return image
    }

    static func copyLongScreenshotToClipboard() -> Bool {
        guard let image = generateLongScreenshot() else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }

    static func saveLongScreenshotToFile(completion: @escaping (Bool) -> Void) {
        guard let image = generateLongScreenshot(),
              let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            completion(false)
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "YumikoToys_About_\(AppConfig.version).png"
        savePanel.title = "保存关于界面萌系梦幻超长图片"
        savePanel.message = "选择保存 YumikoToys 关于界面萌系长图的路径"

        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                do {
                    try pngData.write(to: url)
                    completion(true)
                } catch {
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
    }
}

// MARK: - 萌系主题自适应长截图模版容器 (AboutExportableContentView)

private struct AboutExportableContentView: View {
    private var themeGradientColors: [Color] {
        if AnimeThemeService.shared.isEnabled {
            return AnimeThemeService.shared.gradient()
        }
        let settings = DependencyContainer.shared.settingsService.settings
        let themeColor = settings.mainWindowThemeColor
        return themeColor.iconGradient(customHex: settings.customMainWindowThemeColorHex)
    }

    private var primaryColor: Color {
        themeGradientColors.first ?? Color(hex: "FF6B9D")
    }

    private var secondaryColor: Color {
        themeGradientColors.count > 1 ? themeGradientColors[1] : Color(hex: "C44FE2")
    }

    var body: some View {
        VStack(spacing: 26) {
            // 顶栏萌系装饰卡片 (Cute Banner)
            HStack(spacing: 6) {
                Text("🐰")
                    .font(.system(size: 14))
                Text("YumikoToys · 专属梦幻纪念长图卡片")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(primaryColor)
                Text("✨")
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(primaryColor.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(primaryColor.opacity(0.35), lineWidth: 1)
                    )
            )
            .padding(.top, 8)

            // App Hero Icon Header (萌系静态无按钮版)
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [
                                    primaryColor.opacity(0.25),
                                    secondaryColor.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 116, height: 116)

                    RoundedRectangle(cornerRadius: 26)
                        .fill(
                            LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 98, height: 98)
                        .shadow(color: primaryColor.opacity(0.4), radius: 14, x: 0, y: 6)

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

                VStack(spacing: 6) {
                    Text(AppConfig.appName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))

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
                                            colors: [primaryColor, secondaryColor],
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

            // 主描述
            AboutTextCard {
                VStack(spacing: 12) {
                    Text("⚔️ “睡眠已死，麦克白杀死了睡眠！”")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [primaryColor, secondaryColor],
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

            // 图标说明 (使用经典粉色 UI 模拟器)
            AboutSectionCard(title: "✨ 图标对照与防休眠说明", subtitle: "状态栏菜单面板与防休眠呼吸指示点对照", showInfoHint: false) {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        IconLegendCard(
                            title: "常规模式 (防休眠关闭)",
                            description: "未开启防休眠，状态栏菜单面板右上角无指示点",
                            isActive: false,
                            isPulsing: false
                        )

                        IconLegendCard(
                            title: "不休眠模式 (防休眠开启)",
                            description: "开启不休眠后，状态栏菜单面板右上角亮起柔和呼吸点",
                            isActive: true,
                            isPulsing: true
                        )
                    }
                }
            }

            // Dramatis Personae
            AboutSectionCard(title: "🎭 Dramatis Personae 功勋名录", subtitle: "“幕起幕落，铸就此悲剧史诗之功勋名录”", showInfoHint: false) {
                VStack(alignment: .leading, spacing: 12) {
                    StaticCreditsRow(title: "The Grand Artificer", subtitle: "伟大之工匠 (Macbeth / Lord of the Anvil)", name: "@🍊蜜柑工具人", tagline: "“以铁血铸就逻辑城邦，夜以继日斩尽千百 Bug，使代码高塔永不倒塌。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                    StaticCreditsRow(title: "The Limner of the Sigil", subtitle: "徽记描绘者 (Lady Macbeth / Sovereign of Sorcery)", name: "@会拧头的ruarua怪", tagline: "“洗不净手中极彩墨迹，以神笔抹去世间平庸，赐予界面华美绝伦之霓裳。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                    StaticCreditsRow(title: "The Muse of Whimsy", subtitle: "奇思之缪斯 (The Wyrd Sister / Prophet of Chaos)", name: "@cici", tagline: "“在三魔女沸腾的大锅中倒进奇妙遐想，炼化出颠覆凡世之灵感。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                    StaticCreditsRow(title: "The Patron of New Marvels", subtitle: "新奇赞助人 (High Queen / Sovereign of Realms)", name: "@🐰兔可可", tagline: "“戴上粉色魔晶之王冠，端坐于永恒王座，庇佑万物免受休眠迷雾侵蚀。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                }
            }

            // The Sacred Fellowship of Soulmates
            AboutSectionCard(title: "💖 The Sacred Fellowship of Soulmates 挚友同心", subtitle: "“如《皆大欢喜》与《第十二夜》，心魂相契、同行无间之至亲挚友”", showInfoHint: false) {
                VStack(alignment: .leading, spacing: 12) {
                    StaticCreditsRow(title: "The Enchantress of Mist & Song", subtitle: "雾霭与歌咏之灵 (Puck / Ophelia)", name: "@烟烟", tagline: "“如《仲夏夜之梦》薄雾凝霜之灵，赋万物以飘逸诗意。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                    StaticCreditsRow(title: "The Sovereign of Eternal Starlight", subtitle: "永恒星芒之女王 (Titania / Portia)", name: "@ching_1222", tagline: "“如《第十二夜》璀璨星辰，以优雅与睿智光照剧场。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                    StaticCreditsRow(title: "The Guardian of Enchanted Realm", subtitle: "幻境奇迹之守护者 (Miranda / Beatrice)", name: "@邱", tagline: "“如《暴风雨》奇迹女神 Miranda，赐予作品纯真神圣之守护。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                }
            }

            // Architects of Pet Playground
            AboutSectionCard(title: "🐾 Architects of Pet Playground 爬爬乐创作者", subtitle: "“于桌面绝壁与重力极地间筑奇幻桌宠乐园”", showInfoHint: false) {
                VStack(alignment: .leading, spacing: 12) {
                    StaticCreditsRow(title: "The Agile Enchantress of Walls", subtitle: "绝壁与灵动之仙子 (Puck / Peaseblossom)", name: "@氢氧化猫猫", tagline: "“如《仲夏夜之梦》绝壁上翩跹之仙子，以轻灵极彩之姿赋桌宠以生机。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                    StaticCreditsRow(title: "The Lord Warden of Gravity", subtitle: "极地与重力之勋爵 (Prospero / Gonzalo)", name: "@北冥有地瓜", tagline: "“如《暴风雨》掌控重力与天法之勋爵，筑坚实锚点庇佑桌宠安然攀行。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                }
            }

            // A Note of Gratitude Most Profound
            AboutSectionCard(title: "🌸 A Note of Gratitude Most Profound 深情致谢", subtitle: "“汝等之光，亦使此剧增辉”", showInfoHint: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("吾辈亦向此众友献上敬意：")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    StaticCreditsRow(title: "The Muse of Celestial Grace", subtitle: "晨星与真情之缪斯 (Cordelia / Rosalind)", name: "@saya.ka", tagline: "“如天际璀璨之晨星，以温润真情与无声之光照拂众生。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                    StaticCreditsRow(title: "The Spirit of Woodland Harmony", subtitle: "绿林与颂歌之精灵 (Celia / Ophelia)", name: "@sayu", tagline: "“林间和煦之微风，赋予剧场欢快和谐之韵律与治愈之力。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                    StaticCreditsRow(title: "The Guardian of Serene Moonlight", subtitle: "宁静月光之守护者 (Juliet / Viola)", name: "@さおり", tagline: "“宁静月光之守护者，以纯真与柔情照亮凡间，使全剧平添温情。”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                }
            }

            // A Wyrd Messenger
            AboutSectionCard(title: "🔮 A Wyrd Messenger 命运信使", subtitle: "“荒野神谕，低语建言扭转浩瀚航程”", showInfoHint: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("如荒野上之回响，自迷雾中而来，其低语之建言，足以扭转吾辈大业之航向者，乃")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    StaticCreditsRow(title: "The Prophet of Wyrd Echoes", subtitle: "荒野神谕与命运信使 (Ariel / Hecate)", name: "@小汐shio", tagline: "“自迷雾破空而来，其金石低语建言扭转全剧浩瀚航程！”", primaryColor: primaryColor, secondaryColor: secondaryColor)
                }
            }

            // 萌系水滴封印与专属底部水印
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(primaryColor)
                    Text("Made with 🐰 兔可可皇后魔法守护")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .foregroundStyle(secondaryColor)
                }

                Text("© 2026 YumikoToys Lite · 罗德岛不休眠协议 · 莎士比亚悲剧史诗纪念卡片")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(primaryColor.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [primaryColor.opacity(0.3), secondaryColor.opacity(0.18)],
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
                Color(nsColor: .windowBackgroundColor)
                EllipticalGradient(
                    stops: [
                        .init(color: primaryColor.opacity(0.1), location: 0.0),
                        .init(color: secondaryColor.opacity(0.05), location: 0.5),
                        .init(color: .clear, location: 0.85)
                    ],
                    center: .top,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.95
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [primaryColor.opacity(0.4), secondaryColor.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
}

// MARK: - 长截图萌系静态行 (StaticCreditsRow)

private struct StaticCreditsRow: View {
    let title: String
    let subtitle: String
    let name: String
    var tagline: String? = nil
    var primaryColor: Color = Color(hex: "FF6B9D")
    var secondaryColor: Color = Color(hex: "C44FE2")

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

// MARK: - 高精 1:1 状态栏菜单面板矢量 UI 模拟器 (YumikoPopoverMockupView)

private struct YumikoPopoverMockupView: View {
    let isActive: Bool
    let isPulsing: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                // 1. 顶部 Header
                HStack {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 22, height: 22)
                            Image(systemName: "rabbit.fill").font(.system(size: 11)).foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 3) {
                                Text("YumikoToys").font(.system(size: 11, weight: .bold))
                                Image(systemName: "carrot.fill").font(.system(size: 8)).foregroundStyle(.orange)
                                Text("▾").font(.system(size: 8)).foregroundStyle(.tertiary)
                            }
                            Text("v4.5.7").font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Text("✨").font(.system(size: 7))
                            Circle().fill(Color.blue).frame(width: 5, height: 5)
                            Text("▾").font(.system(size: 7)).foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.12)))

                        ZStack {
                            Circle().fill(Color.primary.opacity(0.06)).frame(width: 20, height: 20)
                            Image(systemName: "sparkles").font(.system(size: 9)).foregroundStyle(Color(hex: "FF6B9D"))
                        }

                        ZStack {
                            Circle().fill(Color.primary.opacity(0.06)).frame(width: 20, height: 20)
                            Image(systemName: "gearshape").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)

                // 2. 模式说明
                HStack {
                    Text(isActive ? "防休眠保护进行中" : "常规运行模式")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isActive ? Color(hex: "FF6B9D") : .secondary)

                    Spacer()

                    Text(isActive ? "物理阻止关屏与唤醒" : "遵循系统默认休眠设定")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )

            // 3. 脉冲呼吸点 (在 Header 右上角)
            if isActive {
                Circle()
                    .fill(Color(hex: "FF6B9D"))
                    .frame(width: 7, height: 7)
                    .scaleEffect(isPulsing ? 1.3 : 0.85)
                    .opacity(isPulsing ? 1.0 : 0.45)
                    .offset(x: -6, y: 6)
                    .shadow(color: Color(hex: "FF6B9D").opacity(0.6), radius: isPulsing ? 4 : 1, x: 0, y: 0)
            }
        }
    }
}

// MARK: - 图标对照说明卡片

private struct IconLegendCard: View {
    let title: String
    let description: String
    let isActive: Bool
    let isPulsing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            YumikoPopoverMockupView(isActive: isActive, isPulsing: isPulsing)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isActive ? Color(hex: "FF6B9D") : Color.gray.opacity(0.4))
                        .frame(width: 6, height: 6)

                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isActive ? Color(hex: "FF6B9D") : .primary)
                }

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isActive ? Color(hex: "FF6B9D").opacity(0.3) : Color.primary.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 通用卡片容器

private struct AboutTextCard<Content: View>: View {
    let content: Content

    private var themeGradientColors: [Color] {
        if AnimeThemeService.shared.isEnabled {
            return AnimeThemeService.shared.gradient()
        }
        let settings = DependencyContainer.shared.settingsService.settings
        let themeColor = settings.mainWindowThemeColor
        return themeColor.iconGradient(customHex: settings.customMainWindowThemeColorHex)
    }

    private var primaryColor: Color {
        themeGradientColors.first ?? Color(hex: "FF6B9D")
    }

    private var secondaryColor: Color {
        themeGradientColors.count > 1 ? themeGradientColors[1] : Color(hex: "C44FE2")
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
                                primaryColor.opacity(0.06),
                                secondaryColor.opacity(0.03)
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
                                        primaryColor.opacity(0.3),
                                        secondaryColor.opacity(0.15)
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
    var showInfoHint: Bool = false
    let content: Content

    private var themeGradientColors: [Color] {
        if AnimeThemeService.shared.isEnabled {
            return AnimeThemeService.shared.gradient()
        }
        let settings = DependencyContainer.shared.settingsService.settings
        let themeColor = settings.mainWindowThemeColor
        return themeColor.iconGradient(customHex: settings.customMainWindowThemeColorHex)
    }

    private var primaryColor: Color {
        themeGradientColors.first ?? Color(hex: "FF6B9D")
    }

    init(title: String, subtitle: String, showInfoHint: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.showInfoHint = showInfoHint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)

                Spacer()

                if showInfoHint {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(primaryColor)

                        Text("点击 ⓘ 查阅典故")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(primaryColor)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(primaryColor.opacity(0.1))
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
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
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

    private var themeGradientColors: [Color] {
        if AnimeThemeService.shared.isEnabled {
            return AnimeThemeService.shared.gradient()
        }
        let settings = DependencyContainer.shared.settingsService.settings
        let themeColor = settings.mainWindowThemeColor
        return themeColor.iconGradient(customHex: settings.customMainWindowThemeColorHex)
    }

    private var primaryColor: Color {
        themeGradientColors.first ?? Color(hex: "FF6B9D")
    }

    private var secondaryColor: Color {
        themeGradientColors.count > 1 ? themeGradientColors[1] : Color(hex: "C44FE2")
    }

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

                // ⓘ 按钮：移动至称号 (title) 正右侧
                if originalAllusion != nil || literaryDecoding != nil {
                    Button(action: {
                        showInfoPopover.toggle()
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(
                                isInfoBtnHovered || showInfoPopover
                                    ? primaryColor
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
                                    .foregroundStyle(primaryColor)

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
                                        .foregroundStyle(secondaryColor)

                                    Text(allusion)
                                        .font(.system(size: 11, design: .serif))
                                        .foregroundStyle(.primary)
                                        .italic()
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
                            }

                            // 文学深层解读
                            if let decoding = literaryDecoding {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("🗡️ 角色象征与深层解构")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundStyle(primaryColor)

                                    Text(decoding)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(3)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(primaryColor.opacity(0.06)))
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
