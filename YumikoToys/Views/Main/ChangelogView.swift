//
//  ChangelogView.swift
//  YumikoToys
//
//  更新日志视图（v4.5.3 - 苏门答腊短耳兔·贝壳与牧师 · 麦克白版）
//

import SwiftUI

struct ChangelogView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 版本头
                versionHeader

                // 荷兰垂耳兔·星尘修复记 — 版本代号区
                CodenameSection(
                    emoji: "🐰",
                    title: "苏门答腊短耳兔·贝壳与牧师 (Sumatran Striped Rabbit · The Seashell and the Clergyman)",
                    titleColor: "E9C46A",
                    subtitle: CodenameSubtitle(),
                    quote: "博士，正如那只有着短促双耳、隐匿在热带雨林深处的苏门答腊短耳兔，在《贝壳与牧师》那超现实的幻象中穿梭，我们在 4.5.3 中为您带来了一次从感官到交互的全方位进化。我们重构了截图的底层架构以支持多屏捕获的自由选择，以 macOS 原生的姿态接管了 YumiScript 的应用启动，同时为宠物名片注入了档案专属的上帝模式文本与状态栏长文本智能换行。并在顶部状态栏增加了档案快速切换通道。当喧哗与骚动平息，剩下的，唯有纯粹而优雅的体验。",
                    entries: [
                        ChangelogEntry(
                            emoji: "🖥️",
                            prefix: "【重构】",
                            prefixColor: "A8D8A8",
                            text: "多屏截图捕获：重构截屏底层架构，原生支持遍历多屏幕的无缝捕获，现在您可以在全局预览窗体中自由选择并管理每一个屏幕的截图了。",
                            character: "——W"
                        ),
                        ChangelogEntry(
                            emoji: "🚀",
                            prefix: "【修复】",
                            prefixColor: "E9C46A",
                            text: "快速启动插件：弃用易阻塞的 Shell 调用，采用 macOS 原生 NSWorkspace 引擎接管应用启动，彻底解决了启动终端等应用时的卡死问题。",
                            character: "——陈"
                        ),
                        ChangelogEntry(
                            emoji: "✨",
                            prefix: "【特性】",
                            prefixColor: "E76F51",
                            text: "状态栏长文本与上帝模式：为您带来了更为自由的定制体验。现在，您可以为每一张宠物名片单独设置『上帝模式』专属长文本，并且引入了状态栏智能换行支持，让长文本亦能优雅展示。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "⚡",
                            prefix: "【新增】",
                            prefixColor: "A8C8D8",
                            text: "全局快速切换：状态栏新增名片快速切换入口。无需打开管理面板，轻点状态栏中的小箭头，即可在所有宠物档案间无缝穿梭。",
                            character: "——凯尔希"
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
                Text("超现实交织与隐秘穿梭的进化之旅")
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

            // 苏门答腊短耳兔解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🐰  Sumatran Striped Rabbit 苏门答腊短耳兔")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "E9C46A"))
                Text("苏门答腊短耳兔（Nesolagus netscheri）是世界上最稀有、最鲜为人知的兔形目动物之一。它隐匿于苏门答腊岛深处，极具神秘感。以其为名，象征着我们在 4.5.3 中对最底层、最隐秘的代码逻辑（如多屏截图与底层启动机制）进行了深度挖掘与重构，捕捉那些平时难以察觉的系统级细节。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            // 贝壳与牧师解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🎬  贝壳与牧师 (The Seashell and the Clergyman, 1928)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "E9C46A"))
                Text("《贝壳与牧师》是法国导演热尔曼·杜拉克执导的早期超现实主义实验电影先驱。影片通过非理性的视觉幻象和梦境逻辑，打破了传统的叙事结构。此次版本以此为名，寓意着我们在多屏交互与上帝模式中，打破了原有的单向度限制，赋予用户如超现实主义般自由、无缝的档案切换与界面重构体验。")
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
                    Text("Tomorrow, and tomorrow, and tomorrow / Creeps in this petty pace from day to day / To the last syllable of recorded time... / Life's but a walking shadow, a poor player / That struts and frets his hour upon the stage / And then is heard no more. / It is a tale told by an idiot, full of sound and fury, / Signifying nothing.")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: "E9C46A").opacity(0.85))
                        .italic()
                        .lineSpacing(4)

                    // 中文翻译
                    Text("『明天，明天，再一个明天，一天接着一天地蹑步前进，直到最后一秒钟的时间……人生不过是一个行走的影子，一个在舞台上指手划脚的拙劣伶人，登场片刻，便在无声无息中悄然退下；它是一个愚人所讲的故事，充满着喧哗和骚动，却找不到一点意义。』")
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

                    Text("【文学与哲学背景档案】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "E9C46A"))

                    Text("这段著名的独白出自莎士比亚的四大悲剧之一《麦克白》（第五幕第五场）。当麦克白在重重围困中听闻妻子死讯，面对终将覆灭的命运与双手沾满的鲜血，他陷入了极度的虚无主义，对时间的无情流逝与人生的荒诞本质发出了这声绝望的感叹。将如此深沉的悲剧独白置于本次更新的注脚，并非出于悲观，而是一种对数字生命与技术演进的反思：当我们在系统中不断修补、堆砌复杂的逻辑与功能，试图对抗程序的无序时，那些喧哗与骚动最终是为了回归一种“意义”。我们重构底层启动机制，优化多屏交互与档案展示，正是为了在这如同“行走的影子”般瞬息万变的比特世界中，为您剥离毫无意义的喧嚣，留下真正优雅、纯粹且触手可及的秩序。")
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
