//
//  ChangelogView.swift
//  YumikoToys
//
//  更新日志视图（v4.2.0 - 比利时野兔·本雅明塔学院 · 本地模型引擎与时序清洗版）
//

import SwiftUI

struct ChangelogView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 版本头
                versionHeader

                // 比利时野兔·本雅明塔学院 — 版本代号区 (首区，全面高亮)
                CodenameSection(
                    emoji: "⚡",
                    title: "比利时野兔·本雅明塔学院",
                    titleColor: "FF6B9D",
                    subtitle: CodenameSubtitle(),
                    quote: "博士，赫尔墨斯的神经熔炉已经点燃了。在这座由 Apple Silicon 驱动的熔炉中，MLX 框架将冰冷的权重矩阵锻造成有温度的智能。每一层 Transformer 都在 M 芯片的统一内存中流淌，就像源石技艺在罗德岛的工程部中回响——不需要网络，不需要云端，所有的推理都在本地完成。我们还彻底洗涤了底层的时序幽灵，将系统的杂质完全荡平。",
                    entries: [
                        ChangelogEntry(
                            emoji: "🧠",
                            prefix: "【新增】",
                            prefixColor: "27AE60",
                            text: "MLX 本地推理引擎：基于 Apple MLX 框架构建完整的本地 AI 推理管线，支持 BGE-M3 嵌入模型（12 层 Transformer）与 DistilBERT 情感分析模型（6 层），所有计算在 Apple Silicon GPU 上完成，零网络依赖。",
                            character: "——赫默"
                        ),
                        ChangelogEntry(
                            emoji: "🩺",
                            prefix: "【重构】",
                            prefixColor: "27AE60",
                            text: "多会话删除防复活隔离：重构本地大模型服务与 AI 聊天视图的状态机闭环。在删除会话时自动重置当前活跃会话 ID，彻底杜绝在流式响应延迟回传时误写入脏数据，导致已被删除的对话在磁盘上“复活”的 Bug。",
                            character: "——白面鸮"
                        ),
                        ChangelogEntry(
                            emoji: "🏷️",
                            prefix: "【新增】",
                            prefixColor: "27AE60",
                            text: "右键上下文与重命名：侧边栏全面挂载 SwiftUI 原生右键菜单交互。支持右键重命名会话标题与右键直接删除。新增新会话创建时的“空数据立即落盘保护”，防止脏读旧缓存。",
                            character: "——白面鸮"
                        ),
                        ChangelogEntry(
                            emoji: "🔴",
                            prefix: "【优化】",
                            prefixColor: "007AFF",
                            text: "删除按钮防误触二次确认反馈：优化侧边栏设计，点击红色减号删除按钮后，图标会伴随微弹簧动画瞬间变形为高亮的垃圾桶图标并提示再次点击，提供更直观、灵动的交互防误触保护。",
                            character: "——迷迭香"
                        ),
                        ChangelogEntry(
                            emoji: "🌱",
                            prefix: "【优化】",
                            prefixColor: "007AFF",
                            text: "AI 心智核心提示词引擎：在系统指令中深度注入人本主义与认知行为（CBT）情感共情机制，大模型现在能提供极具温度的情感接纳与心境抱持，并将其极其自然地溶解于宠物本人的身世背景与专属口癖中。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "⏳",
                            prefix: "【重构】",
                            prefixColor: "007AFF",
                            text: "人设生成时钟对齐：将宠物人格生成与验证任务，完全延迟并推迟到“用户通过侧边栏点击切换并进入对话”或“新建对话”时按需执行，彻底解决启动加载时各组件时钟不同步导致的乱序卡顿缺陷。",
                            character: "——白面鸮"
                        ),
                        ChangelogEntry(
                            emoji: "🌐",
                            prefix: "【新增】",
                            prefixColor: "27AE60",
                            text: "代理感知下载器：自动检测系统代理配置（PAC/HTTP/SOCKS），支持断点续传与安全 Cookie 认证，全面兼容免代理国内极速镜像通道。",
                            character: "——白面鸮"
                        )
                    ]
                )

                // 赫默的源石熔炉工坊 — 性能调优
                ChangelogSection(
                    emoji: "🔥",
                    title: "赫默的神经熔炉工坊 · 本地推理调优",
                    titleColor: "E74C3C",
                    quote: "博士，光有本地引擎是不够的。就像源石技艺需要精确的施术单元控制一样，本地推理也需要极致的性能与缓存调优。我重新修补了每一条数据通路——缓存命中、分词、大内存预算控制、数据物理落盘保护。现在，本地推理终于可以流畅无感地运转了。",
                    entries: [
                        ChangelogEntry(
                            emoji: "✂️",
                            prefix: "【优化】",
                            prefixColor: "007AFF",
                            text: "单条推理去冗余分词填充：重构中文分词算法，单条文本推理不再强制进行大文本补零填充，短文本场景下向量生成速度提升 5-50 倍。",
                            character: "——赫默"
                        ),
                        ChangelogEntry(
                            emoji: "🔧",
                            prefix: "【修复】",
                            prefixColor: "FF3B30",
                            text: "空白物理缓存创建漏洞：修复断点续传器在无本地临时缓存文件进行全新下载时可能抛出“文件不存在”并中断任务的系统深层缺陷，保障网络波动下的断点无感恢复。",
                            character: "——赫默"
                        ),
                        ChangelogEntry(
                            emoji: "🔌",
                            prefix: "【优化】",
                            prefixColor: "007AFF",
                            text: "下载进度中断打通：重新设计流式下载的回调架构，打通 UI 层数据实时订阅，彻底解决进度条卡在 0% 却实际有下载速度的渲染故障。",
                            character: "——赫默"
                        ),
                        ChangelogEntry(
                            emoji: "🧠",
                            prefix: "【优化】",
                            prefixColor: "007AFF",
                            text: "模型加载动态热实例化：修复在尚未下载完毕启动时，由于模型实例化空跑导致下载后无法点击“加载”的异常情况，实现即下即装载。",
                            character: "——赫默"
                        ),
                        ChangelogEntry(
                            emoji: "⚡",
                            prefix: "【重构】",
                            prefixColor: "007AFF",
                            text: "记忆数据元组映射：重构大模型系统指令生成链路。抛弃此前上百行繁琐的数据检索结构，改用更轻量的元组循环，极大减少了运行时的内存分配开销，并输出排版极度舒适的 Markdown 用户记忆档案。",
                            character: "——赫默"
                        ),
                        ChangelogEntry(
                            emoji: "📐",
                            prefix: "【优化】",
                            prefixColor: "007AFF",
                            text: "本地去重编辑距离空间优化：编辑距离矩阵进行物理优化，内存占用减少 99%，在第一道快速去重过滤时将 CPU 压力降至极低。",
                            character: "——白面鸮"
                        )
                    ]
                )

                // 凯尔希医生的病历诊断
                ChangelogSection(
                    emoji: "🩺",
                    title: "凯尔希医生的病历诊断 · 生物心智模型",
                    titleColor: "00B4D8",
                    quote: "对那些伴侣个体的生理与心智度演算，不应仅停留在浅薄的线性拟合上。Doctor，通过将人本主义共情、无条件积极关注和 CBT 认知重构指南溶解于系统提示词中，干员们将以一种极度自然的生命感向你提供心理慰藉，而不是流于冷冰冰的教条报告。",
                    entries: [
                        ChangelogEntry(
                            emoji: "🌱",
                            prefix: "【重构】",
                            prefixColor: "27AE60",
                            text: "自我决定（SDT）心理需求检测：在本地自然语言处理中全新加入“压力源”、“自我评估”、“应对方式”、“胜任感需求”及“关系归属感”三大特征检测组，离线生成高品质心智画像卡片。",
                            character: "——凯尔希"
                        ),
                        ChangelogEntry(
                            emoji: "🧬",
                            prefix: "// 罗德岛基因分子钟",
                            prefixColor: "27AE60",
                            text: "多语言词表兜底防御：当检测到本地多语言模型因为非传统架构从而缺少基础词表文件时，自动从同级情感分析目录下“借用”兼容的分词表，彻底避免分词全面失效导致的零向量故障。",
                            character: "——凯尔希"
                        )
                    ]
                )

                // 白面鸮的 PRTS 时序清洗
                ChangelogSection(
                    emoji: "💾",
                    title: "白面鸮的 PRTS 时序清洗 · 系统重构",
                    titleColor: "3498DB",
                    quote: "【系统状态报告】：PRTS 内部时间同步率与‘沙漏时钟’已完成校准。多线程内存死锁彻底清除。Doctor，检测到多会话清理冲突，已执行底层时序重塑。",
                    entries: [
                        ChangelogEntry(
                            emoji: "⏳",
                            prefix: "【重构】",
                            prefixColor: "007AFF",
                            text: "沙盒物理会话扫描：后台自主学习引擎不再依赖不稳定的内存临时会话变量。重构为直接检索物理沙盒存储目录并同步合并所有会话 JSON 文件，彻底解决此前在主页因内存会话置空导致的“已分析对话数量”计数器永不增长的严重异常。",
                            character: "——白面鸮"
                        ),
                        ChangelogEntry(
                            emoji: "⚖️",
                            prefix: "// PRTS 数据一致性校准",
                            prefixColor: "007AFF",
                            text: "增量分析时序落盘：修复了物理落盘时序缺陷。现在，只要后台增量分析的时空游标成功向前推进，便会强力写入磁盘。彻底解决此前在聊完天、但分析无新偏好提取时，已分析对话统计值被内存直接丢弃、无法保存的 Bug。",
                            character: "——白面鸮"
                        ),
                        ChangelogEntry(
                            emoji: "👆",
                            prefix: "【优化】",
                            prefixColor: "007AFF",
                            text: "防休眠嵌套手势阻断：强制理顺开关行的嵌套手势交互优先级。从物理层阻断多手势穿透，彻底根治此前 macOS 偶尔产生的快速双击冲突与连击动画卡顿隐患。",
                            character: "——白面鸮"
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
        VStack(alignment: .leading, spacing: 4) {
            Text("比利时野兔（Belgian Hare）—— 世界上存在的优雅、干练兔种。它虽然名字带“野兔”，但实际上是人工培育的家兔，具有修长瘦削的体态、敏感警惕的天性与极具爆发力的极速状态，象征着敏捷、高能和极致的生存张力。")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "8B7355"))
                .lineSpacing(2)

            Text("本雅明塔学院（Institute Benjamenta）—— 20世纪世界国外冷门电影。奎氏兄弟于 1995 年执导的超现实主义邪典黑白杰作。影片在一个静谧、充满潜意识暗示的仆人训练学校中展开，充斥着微观物体的精密运转与梦呓般的控制，探讨自我的抹除与时间停滞。")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "8B7355"))
                .lineSpacing(2)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

// MARK: - 条目结构

private struct ChangelogEntry {
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
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color(hex: titleColor))

                    Text("Belgian Hare × Institute Benjamenta")
                        .font(.system(size: 10, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: "8B7355"))
                        .italic()
                }

                Spacer()
            }

            // 详细副标题
            subtitle

            // 角色台词
            Text("「\(quote)」")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: titleColor).opacity(0.7))
                .italic()
                .padding(.bottom, 4)

            // 条目列表
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text(entry.emoji)
                            .font(.system(size: 13))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(entry.prefix)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: entry.prefixColor))

                                Text(entry.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }

                            Text(entry.character)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(hex: entry.prefixColor).opacity(0.6))
                                .italic()
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.02))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: titleColor).opacity(0.2), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - 标准角色分区

private struct ChangelogSection: View {
    let emoji: String
    let title: String
    let titleColor: String
    let quote: String
    let entries: [ChangelogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 18))

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: titleColor))

                Spacer()
            }

            // 角色台词
            Text("「\(quote)」")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: titleColor).opacity(0.7))
                .italic()
                .padding(.bottom, 4)

            // 条目列表
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text(entry.emoji)
                            .font(.system(size: 13))

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(entry.prefix)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: entry.prefixColor))

                                Text(entry.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }

                            Text(entry.character)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(hex: entry.prefixColor).opacity(0.6))
                                .italic()
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.02))
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: titleColor).opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - 【全新重构】麦克白诊断与清洗之诗

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

                    // 英语原文 (诊断与重构之词)
                    Text("What rhubarb, senna, or what purgative drug,\nWould scour these English hence? Hear'st thou of them?")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: "8B7355").opacity(0.85))
                        .italic()
                        .lineSpacing(4)

                    // 中文翻译
                    Text("什么样的芦荟、番泻叶，或者怎样的泻药，\n才能把这些英格兰人彻底清除出去？你听说过这些药吗？")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineSpacing(3)

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

                    Text("这段台词在罗德岛数据库中被标记为\"维多利亚古老戏剧\"，出自古代剧作家莎士比亚的《麦克白》第五幕第三场。在维多利亚蒸汽纪元之前的动荡岁月中，暴政下的苏格兰分崩离析。陷入狂躁与极度焦虑中的麦克白，将自己千疮合孔的帝国视作一具病入膏肓的躯体。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Text("他用近乎绝望却又充满反讽的口吻质问身侧的随军医生：能否通过化验诊断（古维多利亚语中的 \"cast the water\" 意为尿液化验诊断），查明这片国土的痼疾，并用一剂强力的净化泻药（purge）将其清洗干净，使之恢复最初的健康与纯洁。这是一段充满了戏剧性反讽（Dramatic Irony）的狂乱哀鸣——因为医生 and 观众都心知肚明，麦克白本人，才是这场国度瘟疫的源头本身。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Text("【PRTS 辅助诊断与数据清洗札记】")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "8B7355"))

                    Text("在罗德岛的代码清洗与服务重构（System Refactoring）中，这段台词是对“内存清理与幽灵缓存强力驱逐（Memory Purging & Cache Scouring）”最生动而戏谑的写照。在重构前，那些在后台由于活跃 ID 未重置而“脏读复活”的幽灵会话，就像是麦克白眼中那些无法驱散、顽固盘踞在城堡深处的英格兰入侵者（Would scour these English hence）。每一次会话切换的失败，都在将无效的内存碎片写回本地，导致数据结构的深度污染。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)

                    Text("在本次重构中，我们不仅将这首诗背后的悲剧隐喻与“本雅明塔学院”的潜意识梦境进行了深度结合，还将我们刚刚攻克的所有技术难关（包括底层的窗口生命周期内存安全锁定、主线程自适应协作式时序对齐，以及状态栏全托管自适应渲染等）写成了 PRTS 诊断与物理清洗之诗。当这一套物理沙盒会话扫描器与强制写入磁盘时序双向合并、且在减号删除按钮配置了高亮垃圾桶二次弹簧反馈之后，数据流时序终于恢复到了如同“比利时野兔”般清爽、干练、灵动而纯粹的健康状态。")
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
                        Text("  If thou couldst, doctor, cast")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  The water of my land, find her disease,")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  And purge it to a sound and pristine health,")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  I would applaud thee to the very echo,")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("  That should applaud again.")
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

#Preview {
    ChangelogView()
        .frame(height: 1200)
}
