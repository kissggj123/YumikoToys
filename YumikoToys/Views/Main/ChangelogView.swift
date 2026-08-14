//
//  ChangelogView.swift
//  YumikoToys
//
//  更新日志视图（v4.5.7 - 《幻影马车与银狐兔》 · The Phantom Carriage & Silver Fox Edition）
//

import SwiftUI

struct ChangelogView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 版本头
                versionHeader

                // 明日方舟罗德岛战术协议 — 版本代号区
                CodenameSection(
                    emoji: "🎬",
                    title: "《幻影马车与银狐兔》 · The Phantom Carriage & Silver Fox",
                    titleColor: "E9C46A",
                    subtitle: CodenameSubtitle(),
                    quote: "博士，欢迎回到罗德岛。在 v4.5.7 战术协议中，全舰工程部完成了‘防休眠’物理守护阵列的终极重构。我们彻底消除了误触休眠的隐患，在状态栏下拉面板中为您绘制了高精 1:1 仪表盘与柔和呼吸指示灯，并为功勋干员名录注入了莎士比亚《麦克白》冷门史诗典故与 info 交互解构。此外，爬爬乐干员的桌面攀爬与白名单应用列表均已实现毫秒级感应。祝您战术指挥愉快。",
                    entries: [
                        ChangelogEntry(
                            emoji: "🖼️",
                            prefix: "【1:1 状态栏模拟】",
                            prefixColor: "A8D8A8",
                            text: "状态栏下拉菜单仪表盘现已实现 1:1 高精矢量重绘。无论是防休眠模式的开启或关闭，Header 仪表栏右上角均会实时亮起柔和脉冲呼吸灯，防休眠状态一目了然。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "📖",
                            prefix: "【莎士比亚典故】",
                            prefixColor: "E9C46A",
                            text: "功勋干员名录全面升级为《麦克白》悲剧史诗风格！在每位干员与功勋伙伴的名字右侧，点击名字旁精致的粉色 info 按钮，即可弹窗解构《麦克白》、《暴风雨》、《仲夏夜之梦》原著典故与角色寓意。",
                            character: "——阿米娅"
                        ),
                        ChangelogEntry(
                            emoji: "🐾",
                            prefix: "【爬爬乐轻松互动】",
                            prefixColor: "E76F51",
                            text: "桌宠干员攀爬与桌面互动体验全面升级！现在点击桌宠干员可直接按住拖拽在屏幕四周吸附攀爬；点击空白桌面或状态栏时绝不卡顿拦截，体验无比顺畅自由。",
                            character: "——W (维什戴尔)"
                        ),
                        ChangelogEntry(
                            emoji: "⚡",
                            prefix: "【白名单实时刷新】",
                            prefixColor: "A8C8D8",
                            text: "防休眠白名单应用列表现已建立实时状态感应！Mac 系统中任何软件启动或退出时，白名单勾选列表均会自动刷新，无需重新打开设置界面。",
                            character: "——华法琳"
                        ),
                        ChangelogEntry(
                            emoji: "⏱️",
                            prefix: "【版本与构建】",
                            prefixColor: "B8C0E0",
                            text: "应用版本正式升级为 v4.5.7！全新的高精脉冲构建号已注入罗德岛中枢，精确铭刻博士在罗德岛度过的每一个不休眠之夜。",
                            character: "——缪尔赛思"
                        )
                    ]
                )

                // 版本诗引 (冷门麦克白引文)
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

// MARK: - 代号副标题 (18-20世纪国外冷门电影 × 真实罕见兔种)

private struct CodenameSubtitle: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // 代号坐标系标签
            HStack(spacing: 6) {
                Text("◈")
                    .font(.system(size: 9, weight: .thin))
                    .foregroundStyle(Color(hex: "E9C46A").opacity(0.6))
                Text("代号规则：18-20世纪国外冷门电影 × 真实罕见兔种")
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

            // 简短出处与代号解构
            VStack(alignment: .leading, spacing: 3) {
                Text("🎬  The Phantom Carriage & Silver Fox 代号解构")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "E9C46A"))
                Text("• 电影出处：1921 年瑞典经典默片名作《幻影马车》（The Phantom Carriage / Victor Sjöström 执导，讲述除夕夜灵魂因果与救赎的奇幻黑白先驱）\n• 兔种出处：美洲银狐兔（Silver Fox Rabbit，诞生于 20 世纪 20 年代、拥有漆黑锦缎底色与银针毛尖的极稀有保护兔种）")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

// MARK: - 代号卡片区块

private struct CodenameSection: View {
    let emoji: String
    let title: String
    let titleColor: String
    let subtitle: CodenameSubtitle
    let quote: String
    let entries: [ChangelogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题
            HStack(alignment: .top, spacing: 8) {
                Text(emoji)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: titleColor))
                    .fixedSize(horizontal: false, vertical: true)
            }

            subtitle

            // 引言
            Text(quote)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineSpacing(3.5)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.03))
                )

            Divider()

            // 条目列表
            VStack(alignment: .leading, spacing: 12) {
                ForEach(entries) { entry in
                    ChangelogEntryRow(entry: entry)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: titleColor).opacity(0.2), lineWidth: 1)
                )
        )
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

private struct ChangelogEntryRow: View {
    let entry: ChangelogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.emoji)
                .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.prefix)
                        .font(.system(size: 11.5, weight: .bold))
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

// MARK: - 版本诗引 (冷门麦克白引文)

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

                        Text("William Shakespeare · Macbeth, Act III, Scene II")
                            .font(.system(size: 10, weight: .semibold, design: .serif))
                            .foregroundStyle(Color(hex: "E9C46A"))
                            .tracking(1.5)

                        Spacer()
                    }

                    // 英文冷门引文原文
                    Text("“Light thickens; and the crow makes wing to the rooky wood:\nGood things of day begin to droop and drowse;\nWhiles night's black agents to their preys do rouse.”")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: "E9C46A").opacity(0.9))
                        .italic()
                        .lineSpacing(5)

                    // 中文冷门引文翻译
                    Text("『天色渐沉，乌鸦飞向白桦树林；昼间万物尽皆沉睡委顿，唯夜之暗黑信使纷纷暴起，寻觅猎物。』")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineSpacing(3.5)

                    HStack(spacing: 4) {
                        Text("—— William Shakespeare")
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(.quaternary)

                        Spacer()

                        Text(isExpanded ? "收起戏剧背景与系统隐喻" : "阅读戏剧背景与系统隐喻")
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

                    Text("【戏剧情节背景与前后剧情脉络】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "E9C46A"))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• 戏剧情境（第三幕第二场 · 黄昏独白）：在刺杀邓肯国王登基后，麦克白深陷疑网与无眠折磨。当黄昏落日余晖消逝，麦克白向麦克白夫人说出了这句极具暗黑诗意的冷门独白。乌鸦归林、万物委顿昏睡，而独属于夜间的守护信使却在寂静中悄然复苏。")

                        Text("• 后续发展：随后夜幕降临，麦克白派出的黑夜信使在荒野完成了命运的伏击。而麦克白自己则在宴会上目睹了班柯的幻影，最终走向身死国灭的毁灭悲剧。")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3.5)

                    Text("【冷门历史考据与系统架构隐喻】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "E9C46A"))

                    Text("莎士比亚在此处借‘夜之暗黑信使’（night's black agents）展现了黄昏交替时的神秘秩序。在现代 Mac 操作系统与 YumikoToys 系统架构中，这展现了绝妙的防休眠隐喻：当 MacBook 屏幕熄灭、昼间用户操作归于静止委顿之际，YumikoToys 防休眠阵列与后台 AI 炼金进程如同夜间忠诚的信使，在暗夜中持续守护任务与系统的安全运转。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3.5)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
