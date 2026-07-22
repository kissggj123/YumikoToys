//
//  EmotionalStateTracker.swift
//  YumikoToys
//
//  情绪状态追踪器 - 基于对话历史的情绪趋势分析
//

import Foundation

/// 细粒度情绪类型
enum GranularEmotion: String, Codable, Sendable, CaseIterable, Identifiable {
    case anxiety      // 焦虑
    case depression   // 抑郁
    case anger        // 愤怒
    case sadness      // 悲伤
    case fear         // 恐惧
    case shame        // 羞耻
    case guilt        // 内疚
    case loneliness   // 孤独
    case frustration  // 挫败
    case joy          // 喜悦
    case calm         // 平静
    case gratitude    // 感恩
    case hope         // 希望
    case neutral      // 中性

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anxiety: return "焦虑"
        case .depression: return "抑郁"
        case .anger: return "愤怒"
        case .sadness: return "悲伤"
        case .fear: return "恐惧"
        case .shame: return "羞耻"
        case .guilt: return "内疚"
        case .loneliness: return "孤独"
        case .frustration: return "挫败"
        case .joy: return "喜悦"
        case .calm: return "平静"
        case .gratitude: return "感恩"
        case .hope: return "希望"
        case .neutral: return "中性"
        }
    }

    var isNegative: Bool {
        switch self {
        case .anxiety, .depression, .anger, .sadness, .fear, .shame, .guilt, .loneliness, .frustration:
            return true
        default:
            return false
        }
    }

    /// 情绪强度（0.0~1.0）
    var defaultIntensity: Double {
        isNegative ? 0.6 : 0.5
    }
}

/// 单次情绪快照
struct EmotionSnapshot: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let conversationId: String?
    let dominantEmotion: GranularEmotion
    let intensity: Double  // 0.0 ~ 1.0
    var valence: Double  // -1.0 (negative) ~ 1.0 (positive)
    let arousal: Double  // 0.0 (calm) ~ 1.0 (high arousal)
    let context: String?  // 触发情境的简要描述

    init(
        timestamp: Date = Date(),
        conversationId: String? = nil,
        dominantEmotion: GranularEmotion,
        intensity: Double = 0.5,
        valence: Double = 0.0,
        arousal: Double = 0.5,
        context: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.conversationId = conversationId
        self.dominantEmotion = dominantEmotion
        self.intensity = intensity
        self.valence = valence
        self.arousal = arousal
        self.context = context
    }
}

/// 情绪趋势摘要
struct EmotionTrendSummary: Codable, Sendable {
    let periodDays: Int
    let snapshotCount: Int
    let averageValence: Double
    let averageArousal: Double
    let dominantEmotion: GranularEmotion
    let emotionDistribution: [String: Double]  // emotion -> percentage
    let trendDirection: TrendDirection

    enum TrendDirection: String, Codable, Sendable {
        case improving    // 改善中
        case stable       // 稳定
        case declining    // 下降中
        case volatile     // 波动大
    }
}

/// CBT 思维记录
struct ThoughtRecord: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let conversationId: String?

    // CBT 思维记录五列
    let situation: String          // 情境
    let automaticThought: String   // 自动思维
    let emotion: GranularEmotion   // 情绪
    let emotionIntensity: Double   // 情绪强度 0-100
    let cognitiveDistortion: String? // 认知扭曲类型
    let alternativeThought: String? // 替代思维
    let reRatedIntensity: Double?  // 重新评估后的情绪强度

    init(
        timestamp: Date = Date(),
        conversationId: String? = nil,
        situation: String,
        automaticThought: String,
        emotion: GranularEmotion,
        emotionIntensity: Double,
        cognitiveDistortion: String? = nil,
        alternativeThought: String? = nil,
        reRatedIntensity: Double? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.conversationId = conversationId
        self.situation = situation
        self.automaticThought = automaticThought
        self.emotion = emotion
        self.emotionIntensity = emotionIntensity
        self.cognitiveDistortion = cognitiveDistortion
        self.alternativeThought = alternativeThought
        self.reRatedIntensity = reRatedIntensity
    }
}

/// 正念引导练习类型
enum MindfulnessExerciseType: String, Codable, Sendable, CaseIterable, Identifiable {
    case breathing      // 呼吸练习
    case bodyScan       // 身体扫描
    case grounding      // 五感接地
    case lovingKindness // 慈心冥想
    case visualization  // 引导想象

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breathing: return "呼吸练习"
        case .bodyScan: return "身体扫描"
        case .grounding: return "五感接地"
        case .lovingKindness: return "慈心冥想"
        case .visualization: return "引导想象"
        }
    }

    /// 生成练习引导文本
    var guideText: String {
        switch self {
        case .breathing:
            return """
            **4-7-8 呼吸练习**

            请找一个舒适的姿势坐好，轻轻闭上眼睛。

            1. **吸气**（4秒）：通过鼻子缓缓吸气，感受腹部像气球一样慢慢膨胀... 2... 3... 4...
            2. **屏息**（7秒）：温柔地屏住呼吸，让氧气充分流入血液... 感受这份宁静... 2... 3... 4... 5... 6... 7...
            3. **呼气**（8秒）：通过嘴巴缓缓呼出，发出轻柔的"呼"声... 让所有的紧张随着呼气离开身体... 2... 3... 4... 5... 6... 7... 8...

            重复 3-4 个循环。每一次呼气，你都可以感受到身体更加放松。
            """
        case .bodyScan:
            return """
            **渐进式身体扫描**

            请闭上眼睛，将注意力带到身体上。

            从**头顶**开始... 感受头皮的温度... 慢慢向下移动到**额头**... 注意是否有紧绷感，如果有，想象它在慢慢融化...

            继续向下到**眼睛**... **脸颊**... **下巴**... 放松咬紧的牙关...

            感受**脖子**和**肩膀**... 这里常常承载着很多压力... 允许它们慢慢下沉、放松...

            注意力流向**双臂**... **手指**... 感受指尖的温度和微微的脉动...

            来到**胸部**... 感受呼吸的起伏... **腹部**... 随呼吸温柔地起伏...

            向下到**双腿**... **膝盖**... **脚踝**... **脚底**...

            现在，感受整个身体作为一个完整的存在。你是安全的，你是被支持的。
            """
        case .grounding:
            return """
            **5-4-3-2-1 五感接地练习**

            当你感到焦虑或被情绪淹没时，这个练习可以帮你回到当下。

            **看到 5 样东西**：环顾四周，说出你看到的 5 样东西... （例如：蓝色的杯子、窗外的树、桌上的书...）

            **触摸 4 样东西**：感受你身体正在接触的 4 种触感... （例如：椅子支撑着你的背、脚踩在地板上、衣服的质感、空气的温度...）

            **听到 3 种声音**：闭上眼睛，聆听你能听到的 3 种声音... （例如：空调的嗡鸣、远处的车声、自己的呼吸...）

            **闻到 2 种气味**：注意你能闻到的 2 种气味... （例如：咖啡、空气清新剂、自己的衣服...）

            **品尝 1 种味道**：注意嘴里的一种味道... （例如：刚喝的水、残留的茶味...）

            你现在在这里，此时此地，你是安全的。
            """
        case .lovingKindness:
            return """
            **慈心冥想**

            请闭上眼睛，想象一个让你感到温暖和安全的人（可以是亲人、朋友、甚至宠物）。

            在心中对他们说：
            - 愿你平安健康
            - 愿你快乐自在
            - 愿你远离痛苦
            - 愿你以轻松与善意对待自己

            现在，将这份慈心转向**自己**：
            - 愿我平安健康
            - 愿我快乐自在
            - 愿我远离痛苦
            - 愿我以轻松与善意对待自己

            最后，将慈心扩展到**所有众生**：
            - 愿所有生命平安、快乐、自由

            感受这份温暖在你心中扩展，像阳光一样照亮每一个角落。
            """
        case .visualization:
            return """
            **安全之地引导想象**

            请闭上眼睛，做几次深呼吸...

            想象你来到了一个让你感到绝对安全和平静的地方... 它可以是真实存在过的地方，也可以是想象中的空间...

            也许是温暖的海滩... 柔软的白沙在脚下... 海浪轻柔地拍打着岸边... 阳光温暖地洒在你身上...

            也许是森林中的小木屋... 壁炉的火光在跳动... 窗外是纷纷扬扬的雪花... 你裹着柔软的毯子，手捧一杯热可可...

            也许是童年时那个最安全的角落... 那里有最温柔的光线... 和最安心的气息...

            在这个空间里，没有评判，没有期待，没有压力。你只需要在这里，存在就好。

            记住这个地方的感觉。任何时候你需要它，只需闭上眼睛，它就会在这里等你。
            """
        }
    }
}

/// 情绪状态追踪服务
@MainActor
final class EmotionalStateTracker: ObservableObject {
    static let shared = EmotionalStateTracker()

    @Published private(set) var snapshots: [EmotionSnapshot] = []
    @Published private(set) var thoughtRecords: [ThoughtRecord] = []

    private let storageKey = "emotional_state_tracker_data"
    private let thoughtRecordKey = "cbt_thought_records"

    private init() {
        loadData()
    }

    // MARK: - 情绪快照管理

    func addSnapshot(_ snapshot: EmotionSnapshot) {
        snapshots.append(snapshot)
        // 保留最近 90 天的数据
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        snapshots.removeAll { $0.timestamp < cutoff }
        saveData()
    }

    /// 生成指定天数的情绪趋势摘要
    func trendSummary(days: Int = 7) -> EmotionTrendSummary {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recent = snapshots.filter { $0.timestamp >= cutoff }

        guard !recent.isEmpty else {
            return EmotionTrendSummary(
                periodDays: days,
                snapshotCount: 0,
                averageValence: 0.0,
                averageArousal: 0.5,
                dominantEmotion: .neutral,
                emotionDistribution: ["neutral": 1.0],
                trendDirection: .stable
            )
        }

        let avgValence = recent.map(\.valence).reduce(0, +) / Double(recent.count)
        let avgArousal = recent.map(\.arousal).reduce(0, +) / Double(recent.count)

        // 计算情绪分布
        var distribution: [String: Int] = [:]
        for snap in recent {
            distribution[snap.dominantEmotion.rawValue, default: 0] += 1
        }
        let total = Double(recent.count)
        let emotionDist = distribution.mapValues { Double($0) / total }

        // 主导情绪
        let dominant = distribution.max(by: { $0.value < $1.value })
            .flatMap { GranularEmotion(rawValue: $0.key) } ?? .neutral

        // 趋势方向
        let direction: EmotionTrendSummary.TrendDirection
        if recent.count < 3 {
            direction = .stable
        } else {
            let sorted = recent.sorted { $0.timestamp < $1.timestamp }
            let firstHalf = sorted.prefix(sorted.count / 2)
            let secondHalf = sorted.suffix(sorted.count / 2)
            let firstAvg = firstHalf.map(\.valence).reduce(0, +) / Double(firstHalf.count)
            let secondAvg = secondHalf.map(\.valence).reduce(0, +) / Double(secondHalf.count)
            let diff = secondAvg - firstAvg

            let variance = recent.map { ($0.valence - avgValence) * ($0.valence - avgValence) }.reduce(0, +) / Double(recent.count)

            if variance > 0.3 {
                direction = .volatile
            } else if diff > 0.1 {
                direction = .improving
            } else if diff < -0.1 {
                direction = .declining
            } else {
                direction = .stable
            }
        }

        return EmotionTrendSummary(
            periodDays: days,
            snapshotCount: recent.count,
            averageValence: avgValence,
            averageArousal: avgArousal,
            dominantEmotion: dominant,
            emotionDistribution: emotionDist,
            trendDirection: direction
        )
    }

    // MARK: - CBT 思维记录管理

    func addThoughtRecord(_ record: ThoughtRecord) {
        thoughtRecords.append(record)
        saveData()
    }

    func recentThoughtRecords(limit: Int = 10) -> [ThoughtRecord] {
        Array(thoughtRecords.sorted(by: { $0.timestamp > $1.timestamp }).prefix(limit))
    }

    // MARK: - 持久化

    private func saveData() {
        if let data = try? JSONEncoder().encode(snapshots) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if let data = try? JSONEncoder().encode(thoughtRecords) {
            UserDefaults.standard.set(data, forKey: thoughtRecordKey)
        }
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([EmotionSnapshot].self, from: data) {
            snapshots = decoded
        }
        if let data = UserDefaults.standard.data(forKey: thoughtRecordKey),
           let decoded = try? JSONDecoder().decode([ThoughtRecord].self, from: data) {
            thoughtRecords = decoded
        }
    }
}
