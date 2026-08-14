//
//  ChangelogView.swift
//  YumikoToys
//
//  更新日志视图（v4.5.6 - 罗德岛战术协议 · 凯尔希的特别复查 · 麦克白版）
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
                    emoji: "⚔️",
                    title: "罗德岛战术协议 · 麦克白不休眠史诗 (Rhodes Island Tactical Protocol · Macbeth Unsleeping Epic)",
                    titleColor: "E9C46A",
                    subtitle: CodenameSubtitle(),
                    quote: "博士，正如《麦克白》原著中所吟唱的：‘睡眠已死，麦克白杀死了睡眠！’ 在 v4.5.7 协议中，我们完成了睡眠守护重置与硬解冻方案，绘制了 1:1 状态栏下拉面板与呼吸指示点，并为全员名录注入了莎士比亚《麦克白》原著典故与 ⓘ 交互解构。此外，我们彻底消除了爬爬乐全屏点击拦截，实现了白名单应用动态实时刷新。请您审阅。",
                    entries: [
                        ChangelogEntry(
                            emoji: "🖼️",
                            prefix: "【1:1 状态栏模拟】",
                            prefixColor: "A8D8A8",
                            text: "1:1 矢量绘制 YumikoToys 状态栏下拉菜单面板，精准还原防休眠关闭/开启状态，并在 Header 栏右侧精准亮起蓝绿脉冲呼吸点特效。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "📖",
                            prefix: "【莎士比亚典故】",
                            prefixColor: "E9C46A",
                            text: "功勋名录重构为《麦克白》悲剧史诗风格，为全员名字加入精致 ⓘ 交互按钮，点击弹窗即可查阅《麦克白》、《暴风雨》、《仲夏夜之梦》原著典故出处与角色解构。",
                            character: "——阿米娅"
                        ),
                        ChangelogEntry(
                            emoji: "🐾",
                            prefix: "【爬爬乐穿透修复】",
                            prefixColor: "E76F51",
                            text: "彻底消除开启爬爬乐后全屏遮罩对鼠标点击的意外拦截。hitTest 节点级精准判定：点击桌宠人物触发现场拖拽，点击空白桌面或状态栏 100% 物理穿透，随时自由开关。",
                            character: "——W (维什戴尔)"
                        ),
                        ChangelogEntry(
                            emoji: "⚡",
                            prefix: "【白名单实时刷新】",
                            prefixColor: "A8C8D8",
                            text: "白名单勾选列表接入 NSWorkspace 应用生命周期通知流，Mac 系统中任何应用启动或退出时，勾选菜单毫秒级自动实时刷新，无需重新打开设置界面。",
                            character: "——华法琳"
                        ),
                        ChangelogEntry(
                            emoji: "⏱️",
                            prefix: "【秒级构建戳记】",
                            prefixColor: "B8C0E0",
                            text: "应用版本号升级为 v4.5.7，修订构建号采用自 2024-03-12 00:00:00 起精确计算的秒级时间戳 (76555427)，精确记录每一个不休眠之夜。",
                            character: "——缪尔赛思"
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
                Text("罗德岛战术协议 · 大地源石与系统逻辑净化")
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

            // 凯尔希特别复查解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🔷  Kal'tsit's Special Audit 凯尔希的特别复查")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "E9C46A"))
                Text("凯尔希对罗德岛全舰战术设备与底层逻辑进行了全面复查。在 4.5.6 协议中，我们排除了原先滥用特权指令造成的系统电源紊乱，建立了优雅规范的用户级 LaunchAgent 开机防护，全面提升了系统的运算流畅度与干员交互体验。")
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

                        Text("William Shakespeare · Macbeth, Act I, Scene VII")
                            .font(.system(size: 10, weight: .semibold, design: .serif))
                            .foregroundStyle(Color(hex: "E9C46A"))
                            .tracking(1.5)

                        Spacer()
                    }

                    // 英文原文
                    Text("If it were done when 'tis done, then 'twere well / It were done quickly: if the assassination / Could trammel up the consequence, and catch / With his surcease success; that but this blow / Might be the be-all and the end-all here... But in these cases / We still have judgment here; that we but teach / Bloody instructions, which, being taught, return / To plague the inventor...")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: "E9C46A").opacity(0.85))
                        .italic()
                        .lineSpacing(4)

                    // 中文翻译
                    Text("『如果干了之后就算干完了，那么最好快点干；如果这次刺杀能把后果全给拴住，伴随着他的死带来成功；如果这一击就能成为一切的终结……然而在这类事情上，我们在此世便要受到审判；我们所教授的流血指令，一旦被学去，终将返回来折磨发明者自己。』")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineSpacing(3.5)

                    HStack(spacing: 4) {
                        Text("—— William Shakespeare")
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(.quaternary)

                        Spacer()

                        Text(isExpanded ? "收起戏剧背景与考据" : "阅读戏剧背景与考据")
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
                        Text("• 前因（女巫预言与弑君诱惑）：在第一幕第 1~3 场中，战功赫赫的麦克白在荒野遭遇三位女巫预言他将成为考特爵士并终将登基为王。预言应验后，苏格兰国王邓肯亲自下榻麦克白的城堡。麦克白将预言写信告知妻子，果敢狠辣的麦克白夫人极力劝诱他趁国王过夜时将其刺杀。")
                        
                        Text("• 本场现场（宴会独白与内心交战）：在第一幕第 7 场中，大厅正举办欢庆晚宴。麦克白中途离席躲入偏厅阴影中，陷入剧烈的道德煎熬。他深知邓肯不仅是君主更是客人，且爱民如子，弑君不仅违背天理，更告诫自己『流血的指令终将折磨发明者』。他一度动摇，对赶来的妻子说：『我们不要干这件事了！』")

                        Text("• 后果（夫人逼迫与崩溃毁灭）：麦克白夫人用极其冷酷的言语质问其男子气概，并提出灌醉侍卫、嫁祸于人的周密计划。麦克白最终被说服，深夜刺杀了邓肯。但刺杀完成后，麦克白即刻陷入永无止境的惊恐幻听（『麦克白杀死了睡眠！』）与狂躁疑虑，自此踏上狂暴专制与身死国灭的悲剧毁灭之路。")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3.5)

                    Text("【冷门历史考据与系统架构隐喻】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "E9C46A"))

                    Text("1606 年《麦克白》首演前夕，英国爆发了震撼朝野的『火药阴谋』（Gunpowder Plot）。莎士比亚借麦克白独白探讨弑君因果，实则暗指耶稣会教士亨利·加奈特在审判中使用的『模棱两可论』（Equivocation）。『流血的指令终将折磨发明者』在现代软件架构中有着绝妙的隐喻：试图通过特权命令（如 sudo pmset）绕过操作系统底层规范的『快捷手段』，就像弑君篡位一样，最终都会像回旋镖一样生成难以根除的系统副作用与开机电源紊乱。只有回归优雅与原生规范，才能彻底摆脱这层因果反噬。")
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
