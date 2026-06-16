//
//  ChangelogView.swift
//  YumikoToys
//
//  更新日志视图（v4.5.1 - 安哥拉兔·月球旅行记 · 特效雨升级 · 点击特效版）
//

import SwiftUI

struct ChangelogView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 版本头
                versionHeader

                // 安哥拉兔·月球旅行记 — 版本代号区
                CodenameSection(
                    emoji: "🐇",
                    title: "安哥拉兔·月球旅行记 (Angora · Le Voyage dans la Lune)",
                    titleColor: "E9C46A",
                    subtitle: CodenameSubtitle(),
                    quote: "博士，命运正如那轮悬挂在夜空中的苍白银盘，而我们只是在银幕上游荡的追梦旅人。每一次编译，都像是把那一千一分的心绪织成安哥拉兔般松软的梦境。在 4.5.1『安哥拉兔·月球旅行记』中，我们修正了那出可能让伶人猝然退场的智能引擎休克剧目，更为那墨黑的状态栏倾注了数字雨、天使光环与重力水滴的三幕华丽新剧，并在您指尖触及之处，绽开霓虹与繁星的交响。飞向月球的轨道已经铺就，请您一同登舱。",
                    entries: [
                        ChangelogEntry(
                            emoji: "🤖",
                            prefix: "【修复】",
                            prefixColor: "E9C46A",
                            text: "后台助理冷启动异常阻断防护：深度修复了当 AI 激活模型为空或提供商配置不全时，智能助理在后台心跳引擎冷启动期间造成的崩溃及闪退现象。加入了健壮的异常监控防御壁垒，遇到未知异常将优雅回执并暂停服务，保护主进程稳态。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "🌧️",
                            prefix: "【新增】",
                            prefixColor: "A8D8A8",
                            text: "状态栏特效雨物理动效升级：在原有特效雨底座之上，引入并精雕细琢了三款全新的视觉奇观：深绿矩阵坠落的『数字雨（赛博克系Monospace风格）』、金色华光缓缓升腾的『天使光环（灵敏飘移风格）』以及遵从重力加速度抛物下坠的『重力水滴（物理弹跳风格）』。",
                            character: "——W"
                        ),
                        ChangelogEntry(
                            emoji: "✨",
                            prefix: "【新增】",
                            prefixColor: "A8C8D8",
                            text: "应用内全局交互点击特效：为应用主视窗及状态栏面板加持了全新的物理微粒子点击特效系统。目前提供『繁星四射』、『霓虹涟漪』、『爱心飘散』及『重力烟花』四套华丽的动态物理回馈，点击瞬间在光影画布上绽放指尖跃动的绚丽光华。",
                            character: "——陈"
                        )
                    ]
                )

                // 版本诗引
                VersionEpigraph()
            }
            .padding(24)
        }
        .frame(minWidth: 420, idealWidth: 460, maxWidth: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 版本头

    private var versionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("v\(AppConfig.version)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "E9C46A"), Color(hex: "F4A261")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("(\(AppConfig.buildNumber))")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Spacer()
            }

            Text(AppConfig.buildDate)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - 代号副标题

private struct CodenameSubtitle: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // 代号坐标系标签
            HStack(spacing: 6) {
                Text("◈")
                    .font(.system(size: 9, weight: .thin))
                    .foregroundStyle(Color(hex: "E9C46A").opacity(0.6))
                Text("微光折射与近在咫尺的魔术跃迁")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: "E9C46A").opacity(0.75))
                    .tracking(0.5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "E9C46A").opacity(0.06))
            )

            // 安哥拉兔解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🐇  Angora 安哥拉兔 (Angora Rabbit)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "E9C46A"))
                Text("Angora（安哥拉）兔是世界上最著名的长毛兔品种之一，其兔毛丰盈蓬松，如云朵般细腻轻盈。这种「丰盈稳态」特质，正如我们在 4.5.1 中精心加固的智能助理冷启动安全屏障，为应用筑起了一层轻柔而无比坚韧的防护外壳，杜绝了后台因空模型而引起的进程闪退。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            // 月球旅行记解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🌙  月球旅行记 (Le Voyage dans la Lune, 1902)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "E9C46A"))
                Text("《月球旅行记》是乔治·梅里爱于 1902 年创作 of 影史首部科幻杰作，以炮弹飞船击中月球眼睛的经典画面开创了人类电影特效与科幻幻想的新纪元。本次版本以此隐喻：我们以天马行空的想象力，在方寸屏幕之间编织出『状态栏数字雨』与『指尖霓虹粒子』等魔幻特效，带您在日常的敲击与点击中，展开一场跨越界限的月球奇幻之旅。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

// MARK: - 条目结构

private struct ChangelogEntry: Identifiable {
    let id = UUID()
    let emoji: String
    let prefix: String
    let prefixColor: String
    let text: String
    let character: String
}

// MARK: - 代号分区

private struct CodenameSection: View {
    let emoji: String
    let title: String
    let titleColor: String
    let subtitle: CodenameSubtitle
    let quote: String
    let entries: [ChangelogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 大标题
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: titleColor))
                Spacer()
            }

            subtitle

            // 专属名言/引言
            Text(quote)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "E9C46A").opacity(0.9))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "E9C46A").opacity(0.06))
                )
                .lineSpacing(4)

            // 条目列表
            VStack(spacing: 12) {
                ForEach(entries) { entry in
                    ChangelogRow(entry: entry)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: titleColor).opacity(0.15), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - 单条更新行

private struct ChangelogRow: View {
    let entry: ChangelogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.emoji)
                .font(.system(size: 13))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(entry.prefix)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: entry.prefixColor))

                    Spacer()

                    Text(entry.character)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Text(entry.text)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 版本诗引

private struct VersionEpigraph: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(Color(hex: "E9C46A").opacity(0.5))
                            .frame(width: 20, height: 1.5)

                        Text("William Shakespeare · Macbeth, Act V, Scene V")
                            .font(.system(size: 10, weight: .semibold, design: .serif))
                            .foregroundStyle(Color(hex: "E9C46A"))
                            .tracking(1.5)

                        Spacer()
                    }

                    // 英文原文
                    Text("Life's but a walking shadow, a poor player / That struts and frets his hour upon the stage / And then is heard no more.")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: "E9C46A").opacity(0.85))
                        .italic()
                        .lineSpacing(4)

                    // 中文翻译
                    Text("『人生不过是一个行走的影子，一个在舞台上指手画脚、心神不宁的拙劣伶人，登场片刻，便无声无息地悄然退去。』")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineSpacing(3.5)

                    HStack(spacing: 4) {
                        Text("—— William Shakespeare")
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(.quaternary)

                        Spacer()

                        Text(isExpanded ? "收起档案" : "阅读档案")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(hex: "E9C46A"))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(hex: "E9C46A"))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "E9C46A").opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().background(Color(hex: "E9C46A").opacity(0.1))

                    Text("【技术历史背景档案】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "E9C46A"))

                    Text("这段经典的叙事融合了乔治·梅里爱早期电影工业的特技魔术与现代软件交互设计的深层映射。在 4.5.1『安哥拉兔·月球旅行记』的宏大叙事中，我们借由《麦克白》中关于『行走影子』的探讨，审视了智能体在后台静默生存的状态。智能助理的心跳（Heartbeat）不再是一个毫无防备、随时可能因为找不到激活模型而折翼退场的拙劣伶人。我们为其织就了如安哥拉兔毛般松软而坚韧的异常防护网，更在人机交互的物理边界——状态栏与鼠标指针 of 触碰点，通过 Canvas 硬件加速渲染出数字雨与繁星微粒子，让那些原本冰冷的计算逻辑，在微光与阴影的交织中，焕发出影史默片般纯粹、惊艳的永恒光彩。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
