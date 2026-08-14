//
//  AboutView.swift
//  YumikoToys
//
//  关于页面视图（v4.5.6 - Shakespearean Macbeth Allusion Popovers & Info Buttons）
//

import SwiftUI

struct AboutView: View {
    @State private var isIconHovered = false
    @State private var isBreathingDotPulse = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // MARK: - App Hero Icon Header
                appHeroHeader

                // MARK: - 主描述 (Shakespearean Macbeth Style)
                AboutTextCard {
                    VStack(spacing: 12) {
                        Text("⚔️ “睡眠已死，麦克白杀死了睡眠！”")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
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
                AboutSectionCard(title: "Dramatis Personae", subtitle: "“幕起幕落，铸就此悲剧史诗之功勋名录（点击 ⓘ 按钮查阅原著典故）”") {
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
                            name: "@cici 的胡扯",
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
                        
                        Divider().padding(.vertical, 4)
                        
                        // 莎士比亚文学致谢代号
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

                // MARK: - 致谢深情群星 (Shakespearean Chorus Edition)
                AboutSectionCard(title: "A Note of Gratitude Most Profound", subtitle: "“汝等之光，亦使此剧增辉（点击 ⓘ 查阅原著典故）”") {
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
                AboutSectionCard(title: "A Wyrd Messenger", subtitle: "“荒野神谕，低语建言扭转浩瀚航程（点击 ⓘ 查阅原著典故）”") {
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
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .frame(minWidth: 580, idealWidth: 620, maxWidth: 720)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                EllipticalGradient(
                    stops: [
                        .init(color: Color(hex: "FF6B9D").opacity(0.08), location: 0.0),
                        .init(color: Color(hex: "C44FE2").opacity(0.04), location: 0.5),
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

    // MARK: - Hero Icon Header
    private var appHeroHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "FF6B9D").opacity(0.2),
                                Color(hex: "C44FE2").opacity(0.1)
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
                            colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(
                        color: Color(hex: "FF6B9D").opacity(isIconHovered ? 0.5 : 0.3),
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
                                        colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
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
    }
}

// MARK: - 高精 1:1 状态栏菜单面板矢量 UI 模拟器 (YumikoPopoverMockupView)

private struct YumikoPopoverMockupView: View {
    let isActive: Bool
    let isPulsing: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                // 1. 顶部 Header (Icon + App Title + Version + Pill + Breathing Dot)
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
                            Text("v4.5.6").font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    // 右侧功能 Pill (✨ 🔵 ▾) + 防休眠呼吸指示点 (•)
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Text("✨").font(.system(size: 7))
                            Circle().fill(Color.blue).frame(width: 5, height: 5)
                            Text("▾").font(.system(size: 7)).foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.blue.opacity(0.12)))

                        // 防休眠呼吸指示点（开启时在 Header 右侧精准亮起）
                        if isActive {
                            ZStack {
                                Circle()
                                    .stroke(Color(hex: "2563EB").opacity(0.6), lineWidth: 1.2)
                                    .scaleEffect(isPulsing ? 1.6 : 1.0)
                                    .opacity(isPulsing ? 0.0 : 0.8)

                                Circle()
                                    .fill(Color(hex: "2563EB"))
                                    .frame(width: 6.5, height: 6.5)
                                    .shadow(color: Color(hex: "2563EB"), radius: isPulsing ? 3 : 1)
                            }
                            .frame(width: 14, height: 14)
                        }
                    }
                }

                Divider().opacity(0.4)

                // 2. 导航 Tab 按钮组 (纪念日 / 插件 / 截图)
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar").font(.system(size: 8))
                        Text("纪念日").font(.system(size: 8.5, weight: .bold))
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: "2563EB")))
                    .foregroundStyle(.white)

                    HStack(spacing: 3) {
                        Image(systemName: "puzzlepiece.fill").font(.system(size: 8))
                        Text("插件").font(.system(size: 8.5, weight: .semibold))
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))

                    HStack(spacing: 3) {
                        Image(systemName: "camera.viewfinder").font(.system(size: 8))
                        Text("截图").font(.system(size: 8.5, weight: .semibold))
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                }

                // 3. 兔可可 886.035天 计时卡片
                VStack(spacing: 4) {
                    HStack {
                        HStack(spacing: 3) {
                            Circle().fill(Color.pink.opacity(0.2)).frame(width: 12, height: 12)
                                .overlay(Image(systemName: "rabbit.fill").font(.system(size: 7)).foregroundStyle(Color(hex: "FF6B9D")))
                            Text("兔可可").font(.system(size: 9.5, weight: .bold))
                        }
                        Spacer()
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("886.035")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: "2563EB"))
                        Text("天")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Text("下一个100天").font(.system(size: 7.5)).foregroundStyle(.secondary)
                        Spacer()
                        Text("2026-08-29").font(.system(size: 7.5)).foregroundStyle(.tertiary)
                        Text("(第9个)").font(.system(size: 7.5, weight: .bold)).foregroundStyle(Color(hex: "2563EB"))
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.pink.opacity(0.02))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.pink.opacity(0.25), lineWidth: 0.8)
                        )
                )

                // 4. 不休眠模式 Toggle 交互卡片
                HStack {
                    HStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5).fill(isActive ? Color.blue.opacity(0.15) : Color.primary.opacity(0.05)).frame(width: 18, height: 18)
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(isActive ? Color(hex: "2563EB") : .gray)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("不休眠模式").font(.system(size: 9.5, weight: .bold))
                            Text(isActive ? "已开启" : "已关闭")
                                .font(.system(size: 8))
                                .foregroundStyle(isActive ? Color(hex: "2563EB") : .secondary)
                        }
                    }

                    Spacer()

                    // iOS 风格 Switch
                    Capsule()
                        .fill(isActive ? Color(hex: "2563EB") : Color.gray.opacity(0.3))
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
                        .fill(isActive ? Color.blue.opacity(0.08) : Color.primary.opacity(0.03))
                )
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            )
        }
        .clipped()
    }
}

// MARK: - 图标说明展示卡片 (IconLegendCard)

private struct IconLegendCard: View {
    let title: String
    let description: String
    let isActive: Bool
    let isPulsing: Bool

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 高精 1:1 状态栏菜单面板模拟器 (Simulated Popover Window Mockup)
            YumikoPopoverMockupView(isActive: isActive, isPulsing: isPulsing)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(isActive ? Color(hex: "FF6B9D") : .primary)
                        .lineLimit(1)

                    if isActive {
                        Circle()
                            .fill(Color(hex: "00F5D4"))
                            .frame(width: 6, height: 6)
                            .scaleEffect(isPulsing ? 1.3 : 1.0)
                    }
                }

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isActive ? Color(hex: "FF6B9D").opacity(0.08) : Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isActive
                                ? LinearGradient(colors: [Color(hex: "FF6B9D").opacity(0.4), Color(hex: "00F5D4").opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.primary.opacity(0.1), Color.primary.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1
                        )
                )
        )
        .clipped()
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 文本卡片

private struct AboutTextCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.18), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

// MARK: - 分区卡片

private struct AboutSectionCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }

            Divider()
                .background(Color.primary.opacity(0.08))

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
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

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "5856D6"), Color(hex: "FF6B9D")],
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

                // ⓘ 按钮：展现原著典故与文学深层解读
                if originalAllusion != nil || literaryDecoding != nil {
                    Button(action: {
                        showInfoPopover.toggle()
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(
                                isInfoBtnHovered || showInfoPopover
                                    ? Color(hex: "FF6B9D")
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
                                    .foregroundStyle(Color(hex: "FF6B9D"))

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
                                        .foregroundStyle(Color(hex: "C44FE2"))

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
                                        .foregroundStyle(Color(hex: "FF6B9D"))

                                    Text(decoding)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineSpacing(3)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.pink.opacity(0.04)))
                            }
                        }
                        .padding(14)
                        .frame(width: 290)
                    }
                }

                if let tagline = tagline {
                    Text(tagline)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

#Preview {
    AboutView()
        .frame(height: 850)
}
