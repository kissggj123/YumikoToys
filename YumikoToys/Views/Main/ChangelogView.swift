//
//  ChangelogView.swift
//  YumikoToys
//
//  更新日志视图（v4.6.5 - 《夜巡双翼与极光兔》 · The Night Watch & Aurora Fox Edition）
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
                    emoji: "🌌",
                    title: "《夜巡双翼与极光兔》 · The Night Watch & Aurora Fox",
                    titleColor: "E9C46A",
                    subtitle: CodenameSubtitle(),
                    quote: "博士，欢迎回到罗德岛中枢。在 v4.6.5 战术协议中，全舰工程部完成了 M 芯片硬件级画质自适应引擎与 1280pt 跨页双栏宣发手册（Brochure）折页系统的全面升级！全舰现已支持 2.5x 3K、3.0x 4K 与 4.0x 5K 高分辨率离轴渲染，并在底部注入了多阶段动态平滑进度条。即使在极端后台计算与跨设备 Handoff 接力下，亦能保持物理级清晰无损。祝您战术指挥愉快。",
                    entries: [
                        ChangelogEntry(
                            emoji: "🧠",
                            prefix: "【M 芯片画质自适应】",
                            prefixColor: "A8D8A8",
                            text: "自动识别当前 Mac 的 Apple M1~M5 / Pro / Max / Ultra 芯片架构，智能匹配 2.5x (3K)、3.0x (4K) 与 4.0x (5K 大师) 分辨率，同时支持在下拉菜单中随时手动切换！",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "📖",
                            prefix: "【1280pt 跨页双栏手册】",
                            prefixColor: "E9C46A",
                            text: "重磅打造 1280pt 跨页双栏宣发手册小册子模版！左栏整合品牌封面、麦克白剧作引言与 2x2 绝品特质图鉴，右栏对称排布功勋干员名录，呈现视觉期刊级的精装优雅质感。",
                            character: "——阿米娅",
                            hasInfoIcon: false
                        ),
                        ChangelogEntry(
                            emoji: "⏳",
                            prefix: "【多阶段平滑进度条】",
                            prefixColor: "E76F51",
                            text: "底部导出进度条现已升级为多阶段动态状态引擎！实时反馈‘芯片检测’、‘矢量矩阵排版’、‘GCD 离轴点阵压包’与‘打包注入’全过程，告别僵硬等待。",
                            character: "——W & 视觉小组"
                        ),
                        ChangelogEntry(
                            emoji: "⚡",
                            prefix: "【0ms 离轴异步编码】",
                            prefixColor: "A8C8D8",
                            text: "将高分辨率 PNG / TIFF 字节点阵压缩与磁盘写入推入 GCD 后台工作线程，主线程矢量渲染只需 5ms，彻底消除 macOS 彩色棒棒糖卡死隐患！",
                            character: "——华法琳"
                        ),
                        ChangelogEntry(
                            emoji: "⏱️",
                            prefix: "【版本与构建重构】",
                            prefixColor: "B8C0E0",
                            text: "应用版本正式升级为 v4.6.5 (Build 76880010)！全新的极光双翼战术协议已注入中枢，守护博士与罗德岛的每一个不休眠夜巡。",
                            character: "——缪尔赛思"
                        )
                    ]
                )

                // 版本诗引 (冷门哈姆雷特夜巡名句)
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
    @State private var showInfoPopover = false
    @State private var isInfoBtnHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // 代号坐标系标签
            HStack(spacing: 6) {
                Text("◈")
                    .font(.system(size: 9, weight: .thin))
                    .foregroundStyle(Color(hex: "E9C46A").opacity(0.6))
                Text("罗德岛战术协议 · 夜巡守护与极光秘语")
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
                HStack(spacing: 6) {
                    Text("🌌  The Night Watch & Aurora Fox 战术代号")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "E9C46A"))

                    // (i) 按钮用于解释 1928 默片与罕见兔种的起源故事
                    Button(action: {
                        showInfoPopover.toggle()
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                isInfoBtnHovered || showInfoPopover
                                    ? Color(hex: "E9C46A")
                                    : Color(hex: "E9C46A").opacity(0.4)
                            )
                            .scaleEffect(isInfoBtnHovered ? 1.15 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .help("点击解构 1928 默片名作与罕见兔种起源故事")
                    .onHover { isInfoBtnHovered = $0 }
                    .popover(isPresented: $showInfoPopover, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            // Header
                            HStack(spacing: 6) {
                                Image(systemName: "film.stack.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: "E9C46A"))

                                Text("战术代号起源与文化故事考据")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(.primary)
                            }

                            Divider()

                            // 1. 1928 默片《夜巡》
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "film")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(hex: "E9C46A"))
                                    Text("🎬 1928 默片《夜巡》(The Night Watch)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color(hex: "E9C46A"))
                                }

                                Text("由著名导演亚历山大·科达执导，讲述海战夜巡舰长在黑暗海域中誓死守护全舰灯火与战略枢纽的传奇悲壮史诗。影片以精湛的光影调度与夜巡职责著称，展现了极夜阴影中坚守岗位的无畏魄力。")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

                            // 2. 1928 极光白珍珠兔
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "pawprint.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(hex: "F4A261"))
                                    Text("🐰 1928 极光白珍珠兔(Aurora Pearl Fox)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color(hex: "F4A261"))
                                }

                                Text("于 20 世纪 20 年代后期在北欧高纬度地区培育的极稀有变异兔种。拥有宛如夜空极光般流光溢彩之纯白锦缎绒毛与极稀有珍珠光泽，在黑暗中散发柔和微光，极为罕见。")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.04)))
                        }
                        .padding(14)
                        .frame(width: 295)
                    }
                }

                Text("“天寒彻骨，四下肃静。在极夜与寒风交织的沉寂阴影中，夜巡双翼与极光守护终将捍卫代码城邦。”")
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
    var hasInfoIcon: Bool = false
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

// MARK: - 版本诗引 (冷门哈姆雷特夜巡名句)

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

                        Text("William Shakespeare · Hamlet, Act I, Scene I")
                            .font(.system(size: 10, weight: .semibold, design: .serif))
                            .foregroundStyle(Color(hex: "E9C46A"))
                            .tracking(1.5)

                        Spacer()
                    }

                    // 英文冷门引文原文
                    Text("“For this relief much thanks: 'tis bitter cold,\nAnd I am sick at heart. Not a mouse stirring...\nIf you do meet Horatio and Marcellus, bid them make haste.”")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: "E9C46A").opacity(0.9))
                        .italic()
                        .lineSpacing(5)

                    // 中文冷门引文翻译
                    Text("『承蒙解换，深表谢意；天寒彻骨，我心惨凄。四下肃静，无一小鼠动弹……倘若遇见赫拉修与马西路斯，我那同班夜巡之同僚，烦请催促他们快来。』")
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
                        Text("• 戏剧情境（第一幕第一场 · 极寒夜巡）：在艾尔西诺城堡栈桥上，深夜极寒彻骨。夜巡卫兵弗朗西斯科向过来换岗的巴纳多说出了这句凄冷而忠诚的回答。天地肃静，连老鼠都不曾动弹。在黑夜中与同僚守护着城邦安全。")

                        Text("• 后续发展：随后赫拉修与马西路斯赶到栈桥，同班夜巡卫兵在茫茫夜雾中目睹了老国王先魂的重现，引出了全剧震惊世界的复仇史诗序幕。")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3.5)

                    Text("【冷门历史考据与系统架构隐喻】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "E9C46A"))

                    Text("莎士比亚借‘同班夜巡之同僚’（The rivals of my watch）展现了黑暗深处交接岗哨的默契与忠诚。在现代 Mac 操作系统与 YumikoToys 系统架构中，这展现了极佳的防休眠隐喻：当 MacBook 屏幕熄灭、四下寂静委顿之际，YumikoToys 防休眠守卫如同班夜巡的同僚，在寂静深夜中默默伫立与交接，持续守护后台 AI 炼金阵与渲染进程。")
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
