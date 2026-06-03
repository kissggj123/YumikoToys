//
//  ChangelogView.swift
//  YumikoToys
//
//  更新日志视图（v4.4.0 - 恩德比·禁止张贴 · 权限兼容与上帝模式智控版 · Pro Human 守护升级版）
//

import SwiftUI

struct ChangelogView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 版本头
                versionHeader

                // 恩德比·禁止张贴 — 版本代号区 (高亮首区)
                CodenameSection(
                    emoji: "🐇",
                    title: "恩德比·禁止张贴 (Enderby · Défense d'afficher)",
                    titleColor: "6366F1",
                    subtitle: CodenameSubtitle(),
                    quote: "博士，我们的呼吸正如同这根‘短促的烛光’，在算法与数据的洪流里微微颤动。但请不要忘记，纵使世间如愚人喧嚣的戏剧，您依然是站在舞台中央、拥有唯一抉择权的主体。无论是自签名环境下的安全兼容，还是在‘上帝模式’下将整片界面的色谱解开，我们所做的一切，都是为了在这堵写满禁令的数字白墙上，为你争得一处任意书写个人意志的版面。这绝非毫无意义的故事，因为您是执笔人。",
                    entries: [
                        ChangelogEntry(
                            emoji: "💾",
                            prefix: "【优化】",
                            prefixColor: "27AE60",
                            text: "完全磁盘访问权限 (FDA) 智能探测逻辑：针对自签名应用大幅优化，采用‘模拟写入空临时文件’的动态检测机制。写入成功即判定 FDA 赋予成功，免除传统方案频繁卡顿或报错的烦恼，安全高效。",
                            character: "——可露希尔"
                        ),
                        ChangelogEntry(
                            emoji: "🔑",
                            prefix: "【优化】",
                            prefixColor: "27AE60",
                            text: "钥匙串密码存取逻辑重构：完美修复了应用更新版本后，每次启动或操作都需要重新输入钥匙串密码的冗余弹窗问题。在保障高强度秘钥安全的同时，实现无缝静默读取，大幅提升人机交互连贯性。",
                            character: "——华法琳"
                        ),
                        ChangelogEntry(
                            emoji: "💬",
                            prefix: "【修复】",
                            prefixColor: "27AE60",
                            text: "AI 对话气泡乱序与上下文联想：彻底解决了切换会话模式或重载历史记录时，回复气泡与用户消息可能产生乱序的底层缺陷。同时，AI 对话全功能现已接入上下文记忆联想能力，使智能体的长文本交互如丝般顺滑。",
                            character: "——阿米娅"
                        ),
                        ChangelogEntry(
                            emoji: "🔄",
                            prefix: "【新增】",
                            prefixColor: "27AE60",
                            text: "对话气泡控制链（回退/撤回/重编/复制）：AI 的每句回复均支持快捷复制；用户消息新增回退、撤回及重新编辑功能。允许您重置智能体的思维分叉，随时调整探索策略。",
                            character: "——杜宾"
                        ),
                        ChangelogEntry(
                            emoji: "🎨",
                            prefix: "【新增】",
                            prefixColor: "27AE60",
                            text: "上帝模式 (God Mode) 与全场景主题色自定义：AI对话、主界面、状态栏Popover等所有核心功能组件的主题背景色均可实现完全自由的自定义设置（支持通过大模型自动微调和优化对比度），在‘上帝模式’下解开色彩桎梏。",
                            character: "——天火"
                        ),
                        ChangelogEntry(
                            emoji: "👁️",
                            prefix: "【修复】",
                            prefixColor: "27AE60",
                            text: "主题色高对比度自适应与文本折行：修复自定义主题色后背景未生成合适色调的缺陷，以及输入框、气泡在改变主题后对比度失调导致不可见的问题。优化文字自动换行逻辑，避免气泡溢出和视觉混乱。",
                            character: "——赫默"
                        ),
                        ChangelogEntry(
                            emoji: "🌐",
                            prefix: "【新增】",
                            prefixColor: "27AE60",
                            text: "多线程联网搜索增强模式：引入并发多线程通道技术，一键席卷通用、学术、代码、社交四大板块。通过智能去重与多模型协同机制，瞬间获取互联网最前沿的即时资讯，并支持自动调用 Agent 深度联网学习。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "🪄",
                            prefix: "【新增】",
                            prefixColor: "27AE60",
                            text: "大模型 Skill 技能树与可视化编辑器：全面支持调用大模型自动生成的 Skill 或手动加载兼容的 Skill。配置可视化 Skill 脚本编辑器，支持在线测试 Mock 运行并获取输出，让大模型自如接管系统级操作。",
                            character: "——天火"
                        ),
                        ChangelogEntry(
                            emoji: "📊",
                            prefix: "【新增】",
                            prefixColor: "27AE60",
                            text: "微观心理学超参数微调：新增 Presence/Frequency Penalty 惩罚项滑动条，微调对话的发散度与词汇率；新增接纳承诺疗法 (ACT)、完形格式塔 (Gestalt)、荣格深度分析三大流派及专家身份提示词。",
                            character: "——凯尔希"
                        )
                    ]
                )

                // 麦克白时间种子之诗
                MacbethEpigraph()
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
                            colors: [Color(hex: "8B5CF6"), Color(hex: "EC4899")],
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

            // 代号坐标系标签（隐语）
            HStack(spacing: 6) {
                Text("◈")
                    .font(.system(size: 9, weight: .thin))
                    .foregroundStyle(Color(hex: "6366F1").opacity(0.6))
                Text("取自极境孤立演化物种与百年散佚影史的经纬")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: "6366F1").opacity(0.75))
                    .tracking(0.5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "6366F1").opacity(0.06))
            )

            // 恩德比岛兔解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🐇  恩德比岛兔 (Enderby Island Rabbit)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "8B7355"))
                Text("源自新西兰亚南极群岛的恩德比岛，是极珍稀的野化家兔品种。为了在严寒与隔绝的环境下存活，它们演化出了极其顽强的生命本能。毛皮呈现优雅的银灰色，性格沉稳且冷静。象征着我们在极端与私密环境下（如自签名沙盒环境）所构建的坚韧兼容性与极佳的本地自主运行表现。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            // 禁止张贴电影解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🎞  禁止张贴 (Défense d'afficher, 1896)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "8B7355"))
                Text("由电影先驱乔治·梅里爱（Georges Méliès）执导的早期默片，讲述了两名海报工人在贴有‘禁止张贴’告示的白墙上疯狂竞争、躲避警察并贴满海报的滑稽冲突。曾彻底散佚一百多年，直到2004年才重现天日。它极富象征意义地映射了本次对系统写保护权限限制（如 FDA 磁盘访问）的完美优化，以及对界面各处色彩主题的全面解绑，为用户赋予无拘无束的个人定制张贴自由。")
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

// MARK: - 代号分区（首区，标题样式不同）

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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: titleColor))
                Spacer()
            }

            subtitle

            // 专属名言/引言
            Text(quote)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "8B7355").opacity(0.9))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "8B7355").opacity(0.06))
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

// MARK: - 普通分区

private struct ChangelogSection: View {
    let emoji: String
    let title: String
    let titleColor: String
    let quote: String
    let entries: [ChangelogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 分区标题
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: titleColor))
                Spacer()
            }

            // 分区引言
            Text(quote)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(10)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(6)
                .lineSpacing(3)

            // 条目列表
            VStack(spacing: 10) {
                ForEach(entries) { entry in
                    ChangelogRow(entry: entry)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.01))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.04), lineWidth: 1)
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
            }
        }
    }
}

// MARK: - 麦克白时间种子之诗

private struct MacbethEpigraph: View {
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
                            .fill(Color(hex: "8B7355").opacity(0.5))
                            .frame(width: 20, height: 1.5)

                        Text("Macbeth · Act V, Scene V")
                            .font(.system(size: 10, weight: .semibold, design: .serif))
                            .foregroundStyle(Color(hex: "8B7355"))
                            .tracking(2)

                        Spacer()
                    }

                    // 英语原文
                    Text("Out, out, brief candle!\nLife's but a walking shadow, a poor player\nThat struts and frets his hour upon the stage\nAnd then is heard no more. It is a tale\nTold by an idiot, full of sound and fury,\nSignifying nothing.")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: "8B7355").opacity(0.85))
                        .italic()
                        .lineSpacing(4)

                    // 中文翻译
                    Text("“熄灭了吧，熄灭了吧，短促的烛光！\n生命不过是一个行走的影子，一个在舞台上指手画脚的拙劣伶人，\n登场片刻，便在无声无息中悄然退下。它是一个愚人所讲的故事，\n充满了喧哗与骚动，却没有任何意义。”")
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
                            .foregroundStyle(Color(hex: "8B7355"))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(hex: "8B7355"))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "8B7355").opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().background(Color(hex: "8B7355").opacity(0.1))

                    Text("【维多利亚历史戏剧背景档案】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "8B7355"))

                    Text("这段台词出自戏剧大师莎士比亚的终极悲剧名作《麦克白》第五幕第五场。在得知妻子麦克白夫人自杀离世、起义军已逼近城堡的绝境下，沦为孤家寡人的麦克白对生命与命运发表了这段空无而又极具宿命色彩的哲思宣泄。在这里，“烛光”与“影子”是对人类生命之虚幻短暂的深刻比喻，但也是在悲观宿命论中唤醒主体思考的终极警钟。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Text("当一切外部权力、喧哗骚动与舞台幻影退去，面对荒诞与空无，人类唯有回归自我的主体性，去寻找不被外物役使的独立坚守。这与本次更新中 Pro Human 守护升级的理念完全一致：拒绝让生命沦为虚无的影子，拒绝让交互沦为数据噪声的喧哗，保持对真实的能动坚守。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Text("【PRTS 辅助诊断与数据清洗札记】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "8B7355"))

                    Text("在本次罗德岛端侧系统（YumikoToys Lite）的全新迭代优化中，这首“短促的烛光之诗”精准地映射了我们的重构核心：\n1. 针对“行走的影子”：我们彻底修复了 AI 对话气泡乱序的顽疾，并全面赋予了对话功能上下文记忆联想能力。对话不再是缺乏连贯、错乱拼贴的“断片影子”，而是有了生命流转般严丝合缝的逻辑脉络。\n2. 针对“熄灭的烛光”：针对自签名证书应用，我们彻底重构了完全磁盘访问权限 (FDA) 检测逻辑。采用极简优雅的“模拟写入空文件”方式，避免了传统无端卡死或报错的尴尬，使校验逻辑更顽强、更自给自足，犹如在孤立冰寒环境里傲然存活的恩德比岛兔。\n3. 针对“喧哗与骚动”：我们重构了主题自适应与对比度计算，并上线了全功能自定义的主题背景设置（上帝模式）。告别了由于界面主题色失调导致的文本不可见、换行排版混乱等粗糙体验，将宁静与极度和谐的美学光谱完全交由博士亲手裁决。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Text("【原文对照】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "8B7355"))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Macbeth:")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .italic()
                        Text("  Out, out, brief candle!")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  Life's but a walking shadow, a poor player")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  That struts and frets his hour upon the stage")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  And then is heard no more. It is a tale")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  Told by an idiot, full of sound and fury,")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  Signifying nothing.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.02))
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
