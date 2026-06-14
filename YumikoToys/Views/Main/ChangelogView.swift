//
//  ChangelogView.swift
//  YumikoToys
//
//  更新日志视图（v4.5.0 - 缎毛兔·一米处的月球 · 智能体博弈 · 桌面Widget版）
//

import SwiftUI

struct ChangelogView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 版本头
                versionHeader

                // 缎毛兔·一米处的月球 — 版本代号区
                CodenameSection(
                    emoji: "🐇",
                    title: "缎毛兔·一米处的月球 (Satin · La Lune à un mètre)",
                    titleColor: "E9C46A",
                    subtitle: CodenameSubtitle(),
                    quote: "博士，舞台上的光芒总是短暂的。生命不过是时间的投影，而在我们的程序里，每一段代码都是智能体的微小演出。这一次，我们在 4.5.0『缎毛兔·一米处的月球』中重构了这幕戏剧：为智能体赋予了自我博弈与自动对话的生命力，让桌面 Widget 与截图录屏工具无缝编织进罗德岛的日常。一切准备已就绪，等待您的指挥。",
                    entries: [
                        ChangelogEntry(
                            emoji: "🤖",
                            prefix: "【新增】",
                            prefixColor: "E9C46A",
                            text: "智能体自动博弈对话（Self-Play）：Agent 会根据对话上下文自动进行后续步骤博弈。无需用户干预点按，若检测到回复中有「下一步」「准备下单」等动作倾向，将自动触发下一轮推理直至产生明确的最终结果，实现真正的上下文自关联对话。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "🔗",
                            prefix: "【新增】",
                            prefixColor: "A8D8A8",
                            text: "AI 对话文本框技能识别与自动导入：智能检测用户发送的技能 URL 链接，支持 md 格式、json 格式或 zip 压缩包，自动在后台下载、解压、解析技能并一键绑定到当前对话的智能体中，即时生效。",
                            character: "——阿米娅"
                        ),
                        ChangelogEntry(
                            emoji: "📱",
                            prefix: "【新增】",
                            prefixColor: "A8C8D8",
                            text: "macOS 桌面及通知中心 Widget 支持：原生 WidgetKit 小组件支持！开发了 Small 及 Medium 尺寸小组件，采用 Provisioning-Free 零证书 JSON 本地同步方案，支持桌面实时的秒级倒计时刷新。",
                            character: "——阿米娅"
                        ),
                        ChangelogEntry(
                            emoji: "📸",
                            prefix: "【新增】",
                            prefixColor: "F4A261",
                            text: "快捷截图与录屏系统：内置全新多功能截图与录屏组件，支持自定义区域截图、全屏截图、TouchBar 截图、多屏幕同时截图及不限时长的屏幕录制（支持 SIGINT 优雅保存）。搭配 Carbon 全局免 TCC 权限快捷键，单键一键唤起。",
                            character: "——陈"
                        ),
                        ChangelogEntry(
                            emoji: "🎨",
                            prefix: "【优化】",
                            prefixColor: "D8A8D8",
                            text: "上帝模式 UI 细节与菜单栏同步：隐藏底部布局控制栏，改由右侧精简的「笔」SF 符号控制；开启上帝模式后自动显示原始宠物名（支持单行/双行自动折行或隐藏为 i 信息按钮）；修改的纪念日标题即时同步到 macOS 状态栏及弹窗顶部。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "🔍",
                            prefix: "【优化】",
                            prefixColor: "2A9D8F",
                            text: "应用快捷启动批量选择与一键配置：重构了「快速启动应用」插件的配置流程。新增了基于 AppScanner 的批量应用扫描面板，分类列出所有已安装的 macOS 应用程序，实现批量勾选添加，告别低效的手动输入输入。",
                            character: "——杜宾"
                        ),
                        ChangelogEntry(
                            emoji: "🌧️",
                            prefix: "【新增】",
                            prefixColor: "E76F51",
                            text: "华丽 Popover 特效选择：设置中新增特效雨类型选择。除了经典的表情雨外，新增「樱花散落（带风向摇曳）」「繁星闪烁（带随机旋转缩放脉动）」「爱心气泡（从底部徐徐上升）」三款动态粒子特效。",
                            character: "——W"
                        ),
                        ChangelogEntry(
                            emoji: "🛠️",
                            prefix: "【修复】",
                            prefixColor: "E8C8A0",
                            text: "智能体与插件编辑锁及生效机制修复：修复了智能体编辑、插件编辑时偶尔出现的缓存锁定或无法保存的严重缺陷。引入 sheet 重新同步流程，保存后立即重载配置，保证智能体属性和绑定技能即时生效。",
                            character: "——可露希尔"
                        ),
                        ChangelogEntry(
                            emoji: "💻",
                            prefix: "【重构】",
                            prefixColor: "A8D8C8",
                            text: "终端与 Skill 解析安全加固：控制台工具执行日志重构为 Terminal 卡片风格（带 SUCCESS/ERROR 状态标签与 monospaced 字体）。优化了 JSON 解析的崩溃防护，提升了多步推理工具链的整体稳定性。",
                            character: "——可露希尔"
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

            // 缎毛兔解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🐇  Satin 缎毛兔 (Satin Rabbit)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "E9C46A"))
                Text("Satin（缎毛）兔是一种以其丝绸般极具光泽的毛发而闻名的冷门品种。其毛发纤维髓质层呈独特的中空状态，因而能如三棱镜般反射和折射光线，赋予其皮毛闪亮而深邃的缎面反光质感。这种「微光折射」特质，正如我们在 4.5.0 中精心打磨的 Popover 动态特效雨与上帝模式小字折叠细节，使界面在微小的交互瞬间，折射出富有质感与灵性的光芒。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            // 一米处的月球解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🌙  一米处的月球 (La Lune à un mètre, 1898)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "E9C46A"))
                Text("《一米处的月球》是法国电影先驱乔治·梅里爱于 1898 年创作的早期科幻特技默片。梅里爱凭借精湛的舞台魔术和特效技巧（双重曝光、溶解过渡等），在仅一米距离内，将浩瀚神秘的月球拉入了微观的特技舞台。本次版本以此隐喻：我们把看似复杂深奥的「智能体自动博弈对话」与「Carbon 免 TCC 全局热键」等功能，平移拉近到了距离用户仅「一米处」的日常桌面，提供最优雅触手的跃迁体验。")
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

                    Text("这段经典的独白出自莎士比亚四大悲剧之一《麦克白》第五幕第五场。麦克白在听到妻子死讯并面临兵临城下的绝境时，发出了对生命虚无而深刻的感叹。在罗德岛与 AI 代理人（Player/Actor）的开发语境中，它代表着对「虚无的演变」与「上帝模式（God Mode）」的终极隐喻：智能体在虚拟舞台上的每一次闪烁、推理与工具调用，都像是一个拙劣伶人，在预设的 Prompt 轨道上倾尽全力地演出。我们为它设计了自动对话的博弈循环，并将其数据投影至系统的各个角落（如 macOS 桌面 Widget 和状态栏），正是为了给这个「行走的影子」赋予最真实可触的生命回响。")
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
