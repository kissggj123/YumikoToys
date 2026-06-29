//
//  ChangelogView.swift
//  YumikoToys
//
//  更新日志视图（v4.5.2 - 荷兰垂耳兔·星尘修复记 · 稳定性修复版）
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
                    title: "荷兰垂耳兔·星尘修复记 (Holland Lop · Stardust Repair)",
                    titleColor: "E9C46A",
                    subtitle: CodenameSubtitle(),
                    quote: "博士，正如荷兰垂耳兔那对柔软下垂的耳朵，总能捕捉到最细微的声响，我们也倾听着每一处代码的低语。在 4.5.2『荷兰垂耳兔·星尘修复记』中，我们修复了 Widget 无法在通知中心显示的构建问题，修正了截图插件保存到桌面的路径错误，合并了设置中重复的 Widget 说明，并为截图标记工具带来了画笔式马赛克与可拖拽文字框。每一颗星尘的修补，都是为了让您的体验更加完美。",
                    entries: [
                        ChangelogEntry(
                            emoji: "🔧",
                            prefix: "【修复】",
                            prefixColor: "E9C46A",
                            text: "Widget 通知中心显示修复：修复了构建脚本中签名配置导致 Widget Extension 未正确嵌入主 App 的问题，确保 Widget 能够在 macOS 通知中心正常显示。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "🎨",
                            prefix: "【改进】",
                            prefixColor: "A8D8A8",
                            text: "截图标记工具升级：新增画笔式马赛克工具（涂抹打码），文字标注改为可拖拽文字框（支持自由移动与双击编辑），操作体验更接近原生截图工具。",
                            character: "——W"
                        ),
                        ChangelogEntry(
                            emoji: "⚡",
                            prefix: "【修复】",
                            prefixColor: "E76F51",
                            text: "截图保存路径修复：修正了截图插件「保存到桌面」选项失效的问题，截图文件现在正确保存到桌面而非临时目录。",
                            character: "——陈"
                        ),
                        ChangelogEntry(
                            emoji: "🧹",
                            prefix: "【优化】",
                            prefixColor: "A8C8D8",
                            text: "设置界面优化：合并了设置中重复的 Widget 说明部分（通知中心 + 控制中心），精简为统一的「添加 Widget 到系统」引导面板。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "🛡️",
                            prefix: "【修复】",
                            prefixColor: "E9C46A",
                            text: "稳定性全面提升：为所有外部进程调用添加了超时保护机制，将同步阻塞操作改为异步执行，防止系统命令挂起导致应用卡死。",
                            character: "——W"
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
                Text("星尘织补与垂耳倾听的修复之旅")
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

            // 荷兰垂耳兔解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🐰  Holland Lop 荷兰垂耳兔")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "E9C46A"))
                Text("荷兰垂耳兔以其标志性的下垂耳朵闻名，圆润可爱的体型与温顺性格使其成为全球最受欢迎的宠物兔品种之一。那对柔软下垂的耳朵，象征着对每一处细节的敏锐倾听——正如我们在 4.5.2 中逐一捕捉并修复的每一个细微缺陷。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            // 星尘修复记解释
            VStack(alignment: .leading, spacing: 3) {
                Text("✨  星尘修复记 (Stardust Repair)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "E9C46A"))
                Text("星尘是宇宙中最细微却不可或缺的物质，每一颗尘埃的归位都维系着星辰的运转。本次版本以此隐喻：我们逐一拾取散落在代码宇宙中的微小缺陷——构建脚本的签名遗漏、截图路径的逻辑偏差、设置面板的冗余文字——将它们一一修补归位，让整个应用如星轨般稳定运行。")
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
