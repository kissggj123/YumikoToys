//
//  WidgetSyncData.swift
//  YumikoToys
//
//  主 App 与 Widget 之间的共享数据结构（JSON 文件交换）
//  同时用作主 App 内 WidgetStylePreviewCard 的数据源
//
//  变更记录：
//  - schemaVersion 1: 基础天数 + 里程碑 + 自定义头像
//  - schemaVersion 2: 新增 totalHours / hoursPart / minutesPart / secondsPart / themePrimaryHex
//

import Foundation

/// Widget 样式（与 AppSettings.WidgetDisplayStyle 语义保持一致，但此处
/// 使用原始字符串值，方便与 WidgetExtension 之间解耦）
enum WidgetDisplayStyleRaw: String, Codable, Sendable {
    case classic = "classic"
    case compact = "compact"
    case detailed = "detailed"
}

/// 里程碑单元
struct WidgetMilestone: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let icon: String
    let label: String
    let date: String
    let countDisplay: String

    init(id: String = UUID().uuidString,
         icon: String,
         label: String,
         date: String,
         countDisplay: String) {
        self.id = id
        self.icon = icon
        self.label = label
        self.date = date
        self.countDisplay = countDisplay
    }
}

/// Widget 同步数据模型
struct WidgetSyncData: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let petName: String
    let avatar: String
    let startDate: Date
    let totalDays: Double
    let milestones: [WidgetMilestone]
    let proactiveBubbleText: String?
    let appVersion: String
    let displayStyle: String

    // v2: 时间扩展字段
    let totalHours: Double
    let hoursPart: Int
    let minutesPart: Int
    let secondsPart: Int

    // v2: 主题与显示
    let themePrimaryHex: String

    init(schemaVersion: Int = 2,
         petName: String,
         avatar: String,
         startDate: Date,
         totalDays: Double,
         milestones: [WidgetMilestone],
         proactiveBubbleText: String?,
         appVersion: String,
         displayStyle: String,
         totalHours: Double,
         hoursPart: Int,
         minutesPart: Int,
         secondsPart: Int,
         themePrimaryHex: String) {
        self.schemaVersion = schemaVersion
        self.petName = petName
        self.avatar = avatar
        self.startDate = startDate
        self.totalDays = totalDays
        self.milestones = milestones
        self.proactiveBubbleText = proactiveBubbleText
        self.appVersion = appVersion
        self.displayStyle = displayStyle
        self.totalHours = totalHours
        self.hoursPart = hoursPart
        self.minutesPart = minutesPart
        self.secondsPart = secondsPart
        self.themePrimaryHex = themePrimaryHex
    }

    /// 从 totalDays 反推出 hour / minute / second 分量
    /// 这样主 App 可以简洁构造 WidgetSyncData，无需手写拆分
    static func deriveTimeParts(from totalDays: Double)
        -> (totalHours: Double, hoursPart: Int, minutesPart: Int, secondsPart: Int) {
        let totalSeconds = totalDays * 86_400
        let totalHours = totalSeconds / 3_600
        let hours = Int(totalHours)
        let remainingAfterHours = totalSeconds - Double(hours) * 3_600
        let minutes = Int(remainingAfterHours / 60)
        let seconds = Int(remainingAfterHours - Double(minutes) * 60)
        return (totalHours, hours, minutes, seconds)
    }

    /// 示例数据（用于 Widget preview card / placeholder）
    static func sample(style: String = "classic",
                       themeHex: String = "FF6B9D") -> WidgetSyncData {
        let totalDays: Double = 827.085
        let parts = deriveTimeParts(from: totalDays)
        return WidgetSyncData(
            petName: "兔可可",
            avatar: "🐰",
            startDate: Date.distantPast,
            totalDays: totalDays,
            milestones: [
                WidgetMilestone(icon: "🌱", label: "下一个100天",
                                date: "2026-08-29", countDisplay: "(第9个)"),
                WidgetMilestone(icon: "🌿", label: "下一个180天",
                                date: "2026-08-29", countDisplay: "(第5个)"),
                WidgetMilestone(icon: "☘️", label: "下一个300天",
                                date: "2026-08-29", countDisplay: "(第3个)"),
                WidgetMilestone(icon: "🎉", label: "下一周年",
                                date: "2027-03-12", countDisplay: "(第3周年)")
            ],
            proactiveBubbleText: nil,
            appVersion: AppConfig.version,
            displayStyle: style,
            totalHours: parts.totalHours,
            hoursPart: parts.hoursPart,
            minutesPart: parts.minutesPart,
            secondsPart: parts.secondsPart,
            themePrimaryHex: themeHex
        )
    }
}

// MARK: - 便捷解码器：兼容 schemaVersion 1（缺字段自动回退）

extension WidgetSyncData {
    /// 容错 decoder：若旧版 JSON 缺少 hours / theme 字段，用默认值填充
    static func decode(from data: Data) throws -> WidgetSyncData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(Self.self, from: data)
        } catch {
            // 回退：尝试解码为 Legacy v1，再补齐新字段
            struct LegacyV1: Codable {
                let petName: String
                let avatar: String
                let startDate: Date
                let totalDays: Double
                let milestones: [WidgetMilestone]
                let proactiveBubbleText: String?
                let appVersion: String
                let displayStyle: String?
            }
            let v1 = try decoder.decode(LegacyV1.self, from: data)
            let parts = Self.deriveTimeParts(from: v1.totalDays)
            return WidgetSyncData(
                petName: v1.petName,
                avatar: v1.avatar,
                startDate: v1.startDate,
                totalDays: v1.totalDays,
                milestones: v1.milestones,
                proactiveBubbleText: v1.proactiveBubbleText,
                appVersion: v1.appVersion,
                displayStyle: v1.displayStyle ?? "classic",
                totalHours: parts.totalHours,
                hoursPart: parts.hoursPart,
                minutesPart: parts.minutesPart,
                secondsPart: parts.secondsPart,
                themePrimaryHex: "FF6B9D"
            )
        }
    }
}
