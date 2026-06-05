//
//  ChangelogView.swift
//  YumikoToys
//
//  更新日志视图（v4.3.4 - 白眼圈·机械肉铺 · 主题预设与技能扩展版 · 心理学深度增强版）
//

import SwiftUI

struct ChangelogView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 版本头
                versionHeader

                // 白眼圈·机械肉铺 — 版本代号区 (高亮首区)
                CodenameSection(
                    emoji: "🐇",
                    title: "白眼圈·机械肉铺 (Blanc de Hotot · La Charcuterie mécanique)",
                    titleColor: "E8B4B8",
                    subtitle: CodenameSubtitle(),
                    quote: "博士，在那间灯光昏黄、蒸汽弥漫的机械肉铺里，猪肉穿过齿轮被绞碎又重组——这正是我们这次更新的精髓所在。凡是旧的、锈蚀的机制，都将在精密的模块化齿轮中得到彻底重构。那只白眼圈兔子静静地坐在角落，用它标志性的黑色眼圈凝视着整个流程，它清楚地知道：真正的优雅，是在精密的系统结构之上，还能保留那一圈柔软的白色。今日，我们为您重构了技能系统的每一个齿轮，为心理学提示词加铸了新的模块，为主题预设绘制了更丰富的色谱调色板，使每一位博士都能在这个精密运转的系统中，找到专属于自己的那一圈独特光晕。",
                    entries: [
                        ChangelogEntry(
                            emoji: "🔒",
                            prefix: "【修复】",
                            prefixColor: "E8A598",
                            text: "自签名深度签名（codesign --force --deep）后完全磁盘访问权限误报问题：彻底修复了使用 codesign --force --deep --sign 重新签名后，应用每次启动都触发【完全磁盘访问未开启】错误提示的顽固缺陷。新的 FDA 检测逻辑采用动态探针机制，通过向系统临时目录模拟写入极小文件的方式进行权限探测，完全兼容深度签名的沙盒特性，消除了传统路径扫描方案在自签名环境下的误判。",
                            character: "——可露希尔"
                        ),
                        ChangelogEntry(
                            emoji: "🎨",
                            prefix: "【新增】",
                            prefixColor: "E8C4A0",
                            text: "更多精心设计的预设主题配色方案：新增「樱花粉」「深海蓝」「森林绿」「琥珀橙」「赤焰紫」「极地白」「玫瑰金」「炭墨黑」等八套精心调色的全局主题，每套主题均经过专业对比度校验，确保在任何环境下的文字可读性与界面美观度最大化兼得。",
                            character: "——天火"
                        ),
                        ChangelogEntry(
                            emoji: "🧠",
                            prefix: "【新增】",
                            prefixColor: "B4C8E8",
                            text: "心理学专业提示词深度扩充：全面新增叙事疗法 (Narrative Therapy)、存在主义治疗 (Existential Therapy)、情绪聚焦疗法 (EFT)、辩证行为疗法 (DBT)、内在家庭系统 (IFS) 五大主流心理治疗流派及对应的专家身份提示词。同时，针对已有的 CBT、ACT、荣格、格式塔、精神动力学流派，全面优化其提示词的专业精度与共情语言质量，提升整体心理咨询会话的临床感与深度。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "⚙️",
                            prefix: "【优化】",
                            prefixColor: "A0C8B4",
                            text: "现有心理学专业提示词全面精修：对所有已内置的心理学会话提示词进行了系统性专业审查与语言优化。引入了更规范的临床心理学术语体系，增强了各流派提示词的流派特异性，避免不同流派间的术语混用与同质化问题。同时强化了安全边界设定与危机识别指导语，使 AI 在敏感对话中具备更稳健的专业表现。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "💾",
                            prefix: "【新增】",
                            prefixColor: "C8A0D8",
                            text: "自定义颜色方案保存与同步功能：用户手动配置的自定义颜色（背景色、强调色、文字色等全套参数）现可命名保存为独立颜色方案，并自动同步至主题颜色选择器中。您可以在主题选择下拉列表中直接选用已保存的自定义方案，彻底打通预设主题与自定义配色两大体系之间的隔阂，真正实现「随改随存、随用随调」的流畅定制体验。",
                            character: "——天火"
                        ),
                        ChangelogEntry(
                            emoji: "🪄",
                            prefix: "【新增】",
                            prefixColor: "E8D4A0",
                            text: "Skill 技能列表大幅扩充（12 项新内置技能）：新增文件读写、剪贴板管理、日历事件查询、Finder 文件搜索、通知推送、截图保存、Spotlight 搜索、音量控制、WiFi 状态查询、电池状态读取、壁纸切换、Dock 管理等十二项高实用价值的原生 macOS 系统集成技能，覆盖日常效率需求的核心场景。",
                            character: "——杜宾"
                        ),
                        ChangelogEntry(
                            emoji: "🧩",
                            prefix: "【新增】",
                            prefixColor: "A0D8C8",
                            text: "模块化 Skill 编辑器：全新的可视化 Skill 编辑器采用模块化积木式设计，支持将参数输入、脚本模板、条件分支、循环控制等功能单元自由组合拼装，无需任何编程基础即可快速构建复杂的自动化技能。编辑器内置语法高亮、实时语法校验与沙盒 Mock 测试运行，一键验证技能逻辑的正确性后即可保存发布。",
                            character: "——阿米娅"
                        ),
                        ChangelogEntry(
                            emoji: "🖥️",
                            prefix: "【新增】",
                            prefixColor: "D8C8A0",
                            text: "Skill 终端调用支持：所有内置及自定义 Skill 现均支持通过系统终端（Terminal / iTerm2）直接命令行调用。应用提供标准 CLI 接口（ytskill run <skill_name> [--args '{...}']），支持 JSON 格式参数传入与标准输出，完美融入 Shell 脚本自动化工作流，并兼容 LaunchAgent 定时任务触发机制。",
                            character: "——杜宾"
                        ),
                        ChangelogEntry(
                            emoji: "🔬",
                            prefix: "【新增】",
                            prefixColor: "C8D8A0",
                            text: "Pro Human 超参数精细化调整：新增「共情强度」(Empathy Intensity)、「镜像反射深度」(Mirroring Depth)、「沉默容忍度」(Silence Tolerance) 三项专属 Pro Human 调节滑块，从神经语言学与人际互动理论出发，对 AI 的情感共鸣力度、语言镜像程度及对话节奏进行微观精调，使对话体验更贴近专业咨询师的人际感知风格。",
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
                            colors: [Color(hex: "E8B4B8"), Color(hex: "C8A0D8")],
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
                    .foregroundStyle(Color(hex: "E8B4B8").opacity(0.6))
                Text("取自极境孤立演化物种与百年散佚影史的经纬")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: "E8B4B8").opacity(0.75))
                    .tracking(0.5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "E8B4B8").opacity(0.06))
            )

            // 白眼圈兔解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🐇  白眼圈兔 (Blanc de Hotot)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "8B7355"))
                Text("源自法国诺曼底胡托地区的珍稀纯种兔，由欧仁妮·比埃尔·德·卡洛贝尔女士耗费二十余年潜心培育，并于1902年正式在巴黎世界家兔展览会首次亮相公开。通体纯白如雪，唯有双眸周围饰以极细的乌黑眼圈，犹如精心描绘的妆容，构成了自然界最精妙的视觉对比美学。这种近乎消亡后由保育者重新拯救的孤立品种，象征着我们在系统的精密白墙之上，为每一位博士精准刻画的那圈专属色彩标识——自定义颜色方案的永久保存与主题同步。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            // 机械肉铺电影解释
            VStack(alignment: .leading, spacing: 3) {
                Text("🎞  机械肉铺 (La Charcuterie mécanique, 1895)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "8B7355"))
                Text("由卢米埃尔兄弟路易与奥古斯特于1895年摄制的极早期实验短片，为电影诞生元年之作品。影片以惊人的写实主义镜头，直白地记录了一台机械绞肉机将活猪原料经由精密齿轮系统加工成香肠的完整工业流程——所有输入均经由规范模块的处理，转化为精确的输出。这部几乎被电影史彻底遗忘的极早期工业纪录片，精准映射了本次更新的核心理念：旧有的、离散的技能与提示词体系，被重新送入模块化编辑器的精密齿轮，经由标准化参数规范的处理与封装，输出为更强大、更可扩展的结构化 Skill 系统与心理学提示词模块。")
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
                    .font(.system(size: 15, weight: .bold))
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

                        Text("Macbeth · Act V, Scene III")
                            .font(.system(size: 10, weight: .semibold, design: .serif))
                            .foregroundStyle(Color(hex: "8B7355"))
                            .tracking(2)

                        Spacer()
                    }

                    // 英语原文
                    Text("I have lived long enough: my way of life\nIs fall'n into the sear, the yellow leaf;\nAnd that which should accompany old age,\nAs honour, love, obedience, troops of friends,\nI must not look to have; but, in their stead,\nCurses, not loud but deep, mouth-honour, breath,\nWhich the poor heart would fain deny, and dare not.")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: "8B7355").opacity(0.85))
                        .italic()
                        .lineSpacing(4)

                    // 中文翻译
                    Text("『我已活得够长了：我的生命之路\n已凋零成那枯黄的落叶；\n而那些本该伴随老年而来的事物，\n如荣誉、爱戴、顺从、成群的挚友，\n我不能指望再拥有；取而代之的，\n是那无声却深入骨髓的诅咒，是口是心非的谄媚，\n是那颗可怜的心渴望拒绝却又不敢开口的一切。』")
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

                    Text("这段台词出自莎士比亚终极悲剧《麦克白》第五幕第三场。彼时麦克白已自知大局将倾——英格兰军队逼近、旧日盟友纷纷背叛、妻子麦克白夫人也已精神崩溃。这段独白是一个曾经权倾一时的王者，在黄昏的枯叶中直面人生终局的自我清算。【枯黄的落叶】是生命进入凋零的衰败隐喻；【荣誉、爱戴、顺从】是他曾经拥有但已悉数失去的系统资产；而【口是心非的谄媚】则是劣质旧系统里充斥的冗余噪声——人人口中说着顺从，却无人真心臣服。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Text("这与本次 4.3.4 更新的核心命题高度契合：旧的、不健壮的权限检测机制（如在深度签名后仍误报 FDA 未开启），正如那枯黄凋零的叶片，再也无法支撑一个可靠的系统根基。而我们所做的，是从枯败中重构新生——以模块化的 Skill 系统、深度专业的心理学提示词、精准保存的自定义颜色方案，以及可终端调用的技能接口，重新为系统赋予荣誉、可靠与真正的顺从。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Text("【PRTS 辅助诊断与数据清洗札记】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "8B7355"))

                    Text("在罗德岛端侧系统（YumikoToys Lite）4.3.4 次迭代中，麦克白的【枯黄落叶】精准对应了三组系统性重构：\n\n1. 针对【不再拥有的荣誉】：我们修复了自签名深度重签后 FDA 检测误报的历史性缺陷。旧机制如同那些口是心非的谄媚之词，已然无法如实反映系统的真实状态；新的模拟写入探针则如经历磨砺后重新臣服的忠臣，给出最直接、最诚实的权限确认结论。\n\n2. 针对【取而代之的诅咒】：旧有的心理学提示词体系存在流派混用、术语不精确的隐性问题，如同那些【无声却深入骨髓的诅咒】，悄然侵蚀着咨询对话的专业品质。本次全面引入五大新流派并精修所有现有提示词，是对这些隐性诅咒的彻底清除与重构。\n\n3. 针对【那颗不敢开口的心】：技能系统从碎片化走向模块化，从孤立运行走向终端可调用——这是系统从【渴望却不敢行动】到【完整赋能、充分扩展】的跨越式成长。")
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
                        Group {
                            Text("  I have lived long enough: my way of life")
                            Text("  Is fall'n into the sear, the yellow leaf;")
                            Text("  And that which should accompany old age,")
                            Text("  As honour, love, obedience, troops of friends,")
                            Text("  I must not look to have; but, in their stead,")
                            Text("  Curses, not loud but deep, mouth-honour, breath,")
                            Text("  Which the poor heart would fain deny, and dare not.")
                        }
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
