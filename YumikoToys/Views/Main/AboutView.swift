//
//  AboutView.swift
//  YumikoToys
//
//  关于页面视图（v4.5.6 - 1:1 Status Bar Popover Mockups & Shakespearean Credits）
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

                // MARK: - 主描述
                AboutTextCard {
                    VStack(spacing: 10) {
                        Text("🐷 让你合盖状态下也可以为资👦本👧家输出劳动力")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("此工具基于 YumikoToys 🐰可可皇后AI 的粉色钻石魔力实现，支持多环境跨平台巡逻防护。")
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

                // MARK: - Dramatis Personae 功勋名录
                AboutSectionCard(title: "Dramatis Personae", subtitle: "或曰：铸就此杰作之功勋名录") {
                    VStack(alignment: .leading, spacing: 12) {
                        CreditsRow(
                            title: "The Grand Artificer",
                            subtitle: "伟大之工匠",
                            name: "@泡菜老司机",
                            tagline: "缔造万物基石与逻辑之枢纽"
                        )
                        CreditsRow(
                            title: "The Limner of the Sigil",
                            subtitle: "徽记描绘者",
                            name: "@会拧头的ruarua怪",
                            tagline: "赐予界面极彩光芒与视觉灵魂"
                        )
                        CreditsRow(
                            title: "The Muse of Whimsy",
                            subtitle: "奇思之缪斯",
                            name: "@cici 的胡扯",
                            tagline: "注入灵感妙想与无限生机"
                        )
                        CreditsRow(
                            title: "The Patron of New Marvels",
                            subtitle: "新奇赞助人",
                            name: "@🐰可可",
                            tagline: "粉色魔法之源，永恒陪伴庇佑"
                        )
                        
                        Divider().padding(.vertical, 4)
                        
                        // 莎士比亚文学致谢代号
                        CreditsRow(
                            title: "The Enchantress of Mist & Song",
                            subtitle: "雾霭与歌咏之灵 (Puck / Ophelia)",
                            name: "@烟烟",
                            tagline: "“如《仲夏夜之梦》薄雾凝霜之灵，赋万物以飘逸诗意。”"
                        )
                        CreditsRow(
                            title: "The Sovereign of Eternal Starlight",
                            subtitle: "永恒星芒之女王 (Titania / Portia)",
                            name: "@ching_1222",
                            tagline: "“如《第十二夜》璀璨星辰，以优雅与睿智光照剧场。”"
                        )
                        CreditsRow(
                            title: "The Guardian of Enchanted Realm",
                            subtitle: "幻境奇迹之守护者 (Miranda / Beatrice)",
                            name: "@邱",
                            tagline: "“如《暴风雨》奇迹女神 Miranda，赐予作品纯真神圣之守护。”"
                        )
                    }
                }

                // MARK: - 致谢深情群星
                AboutSectionCard(title: "A Note of Gratitude Most Profound", subtitle: "致以最深沉的谢意") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("吾辈亦向此众友献上敬意：")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                        Text("@saya.ka,   @sayu,   @さおり")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("“汝等之光，亦使此剧增辉。”")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }

                // MARK: - 命运的信使
                AboutSectionCard(title: "A Wyrd Messenger", subtitle: "命运的信使") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("如荒野上之回响，自迷雾中而来，其低语之建言，足以扭转吾辈大业之航向者，乃")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)

                        Text("@小汐shio")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "C44FE2"))

                        Text("也。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
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

// MARK: - 致敬行

private struct CreditsRow: View {
    let title: String
    let subtitle: String
    let name: String
    var tagline: String? = nil

    @State private var isHovered = false

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

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

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
