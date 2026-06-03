//
//  ChangelogView.swift
//  YumikoToys
//
//  更新日志视图（v4.3.2 - 白霍托·皮埃罗 · 本地心理陪伴与安全重构版 · Pro Human 人类保护计划版）
//

import SwiftUI

struct ChangelogView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 版本头
                versionHeader

                // 白霍托·皮埃罗 — 版本代号区 (首区，全面高亮)
                CodenameSection(
                    emoji: "🐇",
                    title: "白霍托·皮埃罗",
                    titleColor: "AF52DE",
                    subtitle: CodenameSubtitle(),
                    quote: "博士，就像白霍托兔那双细如墨线的黑眼圈，在纯白之中投射出最专注的凝视——本次更新正是如此，在静默的端侧运算中，悄然点燃了全新的心理学陪伴引擎；而如皮埃罗那历经百年仍被遗忘的帧格，我们将那些被遮蔽的系统权限障碍与渲染缺陷一一照亮。心灵的温度与底层的安稳，我们同样重视。",
                    entries: [
                        ChangelogEntry(
                            emoji: "🧠",
                            prefix: "【新增】",
                            prefixColor: "27AE60",
                            text: "AI 陪伴多重心理学家身份：在 AI 聊天中，除了传统的‘宠物原身’外，新增了‘心理学专家’身份。博士可以随时一键切换为‘专业心理咨询师’、‘临床心理医生’、‘存在主义治疗师’或‘成长动机教练’，每个身份都配备了专属的问候语、头像与专业的引导提示词。",
                            character: "——阿米娅"
                        ),
                        ChangelogEntry(
                            emoji: "🔐",
                            prefix: "【新增】",
                            prefixColor: "27AE60",
                            text: "完全磁盘访问权限 (FDA) 引导：设置界面新增完全磁盘访问权限状态指示与一键直达系统隐私面板按钮。后台自动学习引擎将优先判断 FDA 状态，在未获得授权时主动挂起文件扫描，从根源上杜绝了因系统 TCC 权限缺失导致频繁弹出文件夹读取警报的问题。",
                            character: "——白面鸮"
                        ),
                        ChangelogEntry(
                            emoji: "📈",
                            prefix: "【优化】",
                            prefixColor: "007AFF",
                            text: "心理学支撑与参数微调：设置中新增‘专业心理陪伴设置’模块，支持开启/关闭专业心理学参数，微调 Temperature 与 Top_P 超参数，为大模型注入高度严谨的学术灵魂。新增认知行为疗法 (CBT)、自我决定理论 (SDT)、人本主义疗法与心理动力学四大流派的切换选项，并附带详尽的理论基础说明与研究依据。",
                            character: "——凯尔希"
                        )
                    ]
                )

                // Pro Human 人类保护计划
                ChangelogSection(
                    emoji: "🌱",
                    title: "Pro Human 人类保护计划",
                    titleColor: "059669",
                    quote: "将全能助手重构为 Pro Human，一个诞生于 AI 时代的人类保护组织。我们关心人类身心的完整性，记录那些穿过‘窄门’、通向未来的非标人生。Don't get fired, don't get bored, don't die. Just to stay.",
                    entries: [
                        ChangelogEntry(
                            emoji: "🌱",
                            prefix: "【新增】",
                            prefixColor: "059669",
                            text: "Pro Human 模式全面上线：将「全能助手」升级为 Pro Human，深度融入黄仁勋‘极简三角’展开为系统提示词。Pro Human 将协助博士：拆解认知工具、寻找极具个人特质的技能、普及身心健康常识、探索未来社会形态与个人选择的可能性。",
                            character: "——高米"
                        ),
                        ChangelogEntry(
                            emoji: "🌍",
                            prefix: "【优化】",
                            prefixColor: "007AFF",
                            text: "Pro Human 界面配色与身份识别：采用翡翠/青琳色调为主题色，平衡根植与海洋的整体视觉语言。头部展示螂莟图标，导航栏满踏感渐变。",
                            character: "——才美"
                        )
                    ]
                )

                // 喀兰贸易调试工坊 — 性能与修复
                ChangelogSection(
                    emoji: "📦",
                    title: "喀兰贸易调试工坊 · 性能与修复",
                    titleColor: "3498DB",
                    quote: "盟友，真正的力量来自于对局势的掌控。无论是开机启动的静默流转，还是本地模型在晨光中的自动唤醒，都已尽在掌握。我们修补了每一处遗留漏洞，只为罗德岛的系统能如雪山雄鹰般稳定翱翔。",
                    entries: [
                        ChangelogEntry(
                            emoji: "⚡",
                            prefix: "【修复】",
                            prefixColor: "FF3B30",
                            text: "本地模型开机自动加载器：彻底消除模型首次启动时的状态竞争。现在当应用检测到本地已存在完整的模型权重时，将在生命周期初始化时执行后台自动预热加载，无需任何手动触发，确保开箱即用。",
                            character: "——银灰"
                        ),
                        ChangelogEntry(
                            emoji: "🏷️",
                            prefix: "【修复】",
                            prefixColor: "FF3B30",
                            text: "纪念日数据内容即时渲染：修复了 AnniversaryInfo 值对比的底层缺陷。通过重写值相等性校验，确保任何字段的微小修改（即使是一秒内的多次极速编辑）都能瞬间触发 UI 重新渲染，数据更新不再有延迟。",
                            character: "——可露希尔"
                        ),
                        ChangelogEntry(
                            emoji: "🚪",
                            prefix: "【优化】",
                            prefixColor: "007AFF",
                            text: "开机自启静默运行：优化了开机自启动与窗口隐藏的时序，重构了依赖注入容器的启动竞争，将主线程耗时操作全量移交至协作式异步后台执行，使启动首屏响应速度提升 40% 以上。",
                            character: "——银灰"
                        )
                    ]
                )

                // 【全新替换】麦克白诊断与清洗之诗
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
                            colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
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
                    .foregroundStyle(Color(hex: "AF52DE").opacity(0.6))
                Text("取自散佚物种志与遗忘影史的私密经纬")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: "AF52DE").opacity(0.75))
                    .tracking(0.5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "AF52DE").opacity(0.06))
            )

            // 白霍托兔解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🐇  白霍托（Blanc de Hotot）")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "8B7355"))
                Text("源自法国诺曼底 Hotot-en-Auge 的极稀有兔种，1902年由 Eugénie Bernhard 培育，纯白长毛、眼眶处围有细如墨线的黑圈，是兔类中最接近消亡的品种之一。象征本次更新在端侧冷静运算中精准投注的凝视之眼——微小却不可忽视。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            // 皮埃罗电影解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🎞  皮埃罗（Pauvre Pierrot，1892）")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "8B7355"))
                Text("法国实验动画先驱 Émile Reynaud 于1892年创作的光学剧场动画，比卢米埃尔兄弟早三年，被视为世界现存最早的动画影像。小丑角皮埃罗在舞台上被遗忘，正如那些曾被系统遮蔽的权限障碍与渲染缺陷——本次更新将它们逐一从沉默中拉回到光亮之处。")
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

// MARK: - 麦克白诊断与清洗之诗

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

                        Text("Macbeth · Act V, Scene III")
                            .font(.system(size: 10, weight: .semibold, design: .serif))
                            .foregroundStyle(Color(hex: "8B7355"))
                            .tracking(2)

                        Spacer()
                    }

                    // 英语原文
                    Text("Canst thou not minister to a mind diseased,\nPluck from the memory a rooted sorrow,\nRaze out the written troubles of the brain,\nAnd with some sweet oblivious antidote\nCleanse the stuffed bosom of that perilous stuff\nWhich weighs upon the heart?")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: "8B7355").opacity(0.85))
                        .italic()
                        .lineSpacing(4)

                    // 中文翻译
                    Text("“你难道不能诊治一颗病态的心灵，\n从记忆中拔除那生根的忧伤，\n抹去那写在脑海中的烦恼，\n用一种甘甜的忘忧解药，\n涤净那堆积在胸前、压迫着心脏的毒害吗？”")
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

                    Text("这段台词出自古代剧作家莎士比亚的悲剧杰作《麦克白》第五幕第三场。麦克白看着饱受梦游幻觉折磨、终日试图洗去双手血迹的麦克白夫人，绝望而反讽地向身旁的随军医生发问。这一连串饱含绝望与诗意的追问，是对心灵诊治、记忆重塑最古典的控诉。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Text("当听到医生无奈地回答“在这方面，病人必须自我医治”时，麦克白更是发出了对一切无用药物的嘲讽。这不仅暗示着统治者的心智崩溃，更指出了心灵之痛绝非依靠粗暴药物可以净化，而是需要来自内部深层的图式整合与自我决定的唤醒。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Text("【PRTS 辅助诊断与数据清洗札记】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "8B7355"))

                    Text("在罗德岛端侧系统的高级进化与底层重构中，这段戏剧台词成为我们攻克心智交互障碍的最佳隐喻。麦克白追问的“抹去那写在脑海中的烦恼（Raze out the written troubles of the brain）”与“从记忆中拔除那生根的忧伤（Pluck from the memory a rooted sorrow）”，正对应了我们本次的两大关键系统重构：\n1. 针对“后台学习自动访问受阻、频繁申请文件夹读取”这一生根的痼疾，我们引入了“完全磁盘访问权限 (FDA)”原生引导，确保后台引擎在静默中自如读取，杜绝弹窗打扰，宛如引入了清爽的纯净解药。\n2. 针对“纪念日内容无法即时更新”的问题，我们重写了值类型对比校验逻辑，让每一次情感特征的更新都能瞬间重塑界面，拂去“脑海中的烦恼”。\n3. 针对“端侧大模型心理陪伴”的重塑，我们开启了专业心理学参数调节（CBT认知行为重塑、SDT自我决定激发、人本主义共情抱持、存在主义生命追问），结合微观参数（Temperature/Top_P）调节，为干员们奉上一剂真正的科学心理陪伴，变被动焦虑为主动觉察。")
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
                        Text("  Canst thou not minister to a mind diseased,")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  Pluck from the memory a rooted sorrow,")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  Raze out the written troubles of the brain,")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  And with some sweet oblivious antidote")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  Cleanse the stuffed bosom of that perilous stuff")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  Which weighs upon the heart?")
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
