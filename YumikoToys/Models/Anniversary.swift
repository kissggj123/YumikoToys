//
//  Anniversary.swift
//  YumikoToys
//
//  纪念日数据模型（科学提示与体型指标扩展版）
//

import Foundation
import SwiftUI

// MARK: - 应用配置常量

enum AppConfig {
    /// 应用版本号（从 Info.plist 动态获取）
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// 构建版本号
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// 完整版本信息（版本号 + 构建号）
    static var fullVersion: String {
        "\(version) (\(buildNumber))"
    }
    
    /// 应用显示名称
    static var displayName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "可可皇后"
    }
    
    /// 应用名称
    static var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "YumikoToys"
    }

    /// 构建日期（优先从 Info.plist 读取，否则返回编译日期）
    static var buildDate: String {
        if let date = Bundle.main.infoDictionary?["CFBuildDate"] as? String {
            return date
        }
        return "2026-05-22"
    }
}

// MARK: - 犬类体型划分（源自美国动物医院协会 AAHA 临床标准）

enum CanineSize: String, Codable, CaseIterable, Sendable, Identifiable {
    case small   = "small"   // 小型犬
    case medium  = "medium"  // 中型犬
    case large   = "large"   // 大型犬
    case giant   = "giant"   // 巨型犬
    
    var id: String { rawValue }
    
    /// 体型显示名称
    var displayName: String {
        switch self {
        case .small: return "小型犬"
        case .medium: return "中型犬"
        case .large: return "大型犬"
        case .giant: return "巨型犬"
        }
    }
    
    /// 【新增】临床体重划分界限描述
    var weightRange: String {
        switch self {
        case .small: return "体重 < 9 kg (20 lbs)"
        case .medium: return "体重 9 - 23 kg (20 - 50 lbs)"
        case .large: return "体重 23 - 41 kg (50 - 90 lbs)"
        case .giant: return "体重 > 41 kg (90 lbs)"
        }
    }
    
    /// 【新增】典型代表品种提示
    var representativeBreeds: String {
        switch self {
        case .small: return "泰迪、博美、吉娃娃、比熊、雪纳瑞、八哥、西施"
        case .medium: return "柴犬、柯基、边牧、法斗、喜乐蒂、可卡"
        case .large: return "金毛、拉布拉多、哈士奇、德牧、萨摩耶、秋田"
        case .giant: return "巨型阿拉斯加、大白熊、圣伯纳、大丹、藏獒"
        }
    }
    
    /// 【新增】科学选型辅助向导文本（可直接显示在 UI 提示行中）
    var selectionHint: String {
        return "\(displayName)（\(weightRange)）：适合\(representativeBreeds)等。"
    }
}

// MARK: - 纪念日类型

enum AnniversaryType: String, Codable, CaseIterable, Sendable, Identifiable {
    case countUp = "countUp"
    case countDown = "countDown"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .countUp: return "正计时"
        case .countDown: return "倒计时"
        }
    }
    
    var icon: String {
        switch self {
        case .countUp: return "heart.fill"
        case .countDown: return "hourglass"
        }
    }
    
    var gradientColors: [String] {
        switch self {
        case .countUp: return ["FF6B6B", "EE5A5A"]
        case .countDown: return ["4ECDC4", "44A08D"]
        }
    }
}

// MARK: - 宠物性别

enum PetGender: String, Codable, CaseIterable, Sendable, Identifiable {
    case male = "male"
    case female = "female"
    case neutral = "neutral"
    case unknown = "unknown"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .male: return "公"
        case .female: return "母"
        case .neutral: return "中性"
        case .unknown: return "未知"
        }
    }
    
    var emoji: String {
        switch self {
        case .male: return "♂"
        case .female: return "♀"
        case .neutral: return "⚧"
        case .unknown: return "?"
        }
    }
    
    var icon: String {
        switch self {
        case .male: return "circle.circle.fill"
        case .female: return "circle.circle"
        case .neutral: return "circle.lefthalf.filled"
        case .unknown: return "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .male: return Color(hex: "007AFF") // 蓝色
        case .female: return Color(hex: "FF6B9D") // 粉色
        case .neutral: return Color.clear // 使用彩虹渐变
        case .unknown: return .secondary
        }
    }
    
    var isRainbow: Bool {
        return self == .neutral
    }
    
    static let rainbowGradient: LinearGradient = LinearGradient(
        colors: [
            Color(hex: "FF0000"), // 红
            Color(hex: "FF8E00"), // 橙
            Color(hex: "FFFF00"), // 黄
            Color(hex: "00FF00"), // 绿
            Color(hex: "00B4D8"), // 蓝
            Color(hex: "8B00FF")  // 紫
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - 纪念日模型

struct Anniversary: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var startDate: Date
    var type: AnniversaryType
    var emoji: String?
    var color: String?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // 宠物名片字段
    var petName: String?
    var petGender: PetGender?
    var species: String?
    var avatarEmoji: String?
    var customStatusBarLine1: String?
    
    // 狗狗体型配置
    var dogSize: CanineSize?

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        type: AnniversaryType = .countUp,
        emoji: String? = nil,
        color: String? = nil,
        isActive: Bool = true,
        petName: String? = nil,
        petGender: PetGender? = nil,
        species: String? = nil,
        avatarEmoji: String? = nil,
        customStatusBarLine1: String? = nil,
        dogSize: CanineSize? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.type = type
        self.emoji = emoji
        self.color = color
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.petName = petName
        self.petGender = petGender
        self.species = species
        self.avatarEmoji = avatarEmoji
        self.customStatusBarLine1 = customStatusBarLine1
        self.dogSize = dogSize
    }
}

// MARK: - Anniversary 宠物名片计算属性

extension Anniversary {
    /// 显示用的头像 emoji（优先 avatarEmoji，回退 emoji，最终回退默认）
    var displayAvatar: String {
        avatarEmoji ?? emoji ?? "🐾"
    }
    
    /// 显示用的宠物名称（优先 petName，回退 title）
    var displayPetName: String {
        petName ?? title
    }
    
    /// 状态栏第一行文字（优先使用自定义值）
    var statusBarLine1: String {
        customStatusBarLine1 ?? {
            switch type {
            case .countUp:
                return "\(displayPetName)已到来"
            case .countDown:
                return "距\(displayPetName)还有"
            }
        }()
    }
    
    /// 解析状态栏模板变量
    /// 支持: {name} 宠物名, {days} 天数, {emoji} 头像, {species} 品种
    func parsedStatusBarLine1(days: Double) -> String {
        var result = statusBarLine1
        if result.isEmpty {
            result = "{name}已到来"
        }
        
        result = result.replacingOccurrences(of: "{name}", with: displayPetName)
        result = result.replacingOccurrences(of: "{days}", with: String(format: "%.0f", days))
        result = result.replacingOccurrences(of: "{emoji}", with: displayAvatar)
        result = result.replacingOccurrences(of: "{species}", with: species ?? "宠物")
        
        return result
    }
    
    /// 是否已填写宠物信息
    var isPetProfile: Bool {
        petName != nil
    }
}

// MARK: - 纪念日计算结果（添加 Equatable）

struct AnniversaryCalculation: Sendable, Equatable {
    let totalDays: Double
    let totalSeconds: TimeInterval
    let totalHours: Double  // 总小时数
    let days: Int
    let hours: Int
    let minutes: Int
    let seconds: Int
    
    /// 格式化字符串：已到来 XXXXX小时 XX分钟 XX秒
    var formattedString: String {
        String(format: "已到来 %.0f小时 %d分钟 %d秒", totalHours, minutes, seconds)
    }
    
    /// 详细格式化：X天 XX小时 XX分钟 XX秒
    var detailedString: String {
        String(format: "%d天 %02d小时 %02d分钟 %02d秒", days, hours, minutes, seconds)
    }
    
    var shortString: String {
        if days > 0 {
            return String(format: "%d天%02d时", days, hours)
        } else {
            return String(format: "%d时%02d分", hours, minutes)
        }
    }
}

// MARK: - 纪念日里程碑（语义化 ID + 缓存 DateFormatter + Equatable）

struct AnniversaryMilestone: Identifiable, Sendable, Equatable {
    let id: String  // 语义化 ID，避免每次创建新 UUID
    let icon: String
    let label: String
    let targetDate: Date
    let count: Int
    let unit: String
    
    // 缓存 DateFormatter（避免每次访问创建新实例）
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    var formattedDate: String {
        Self.dateFormatter.string(from: targetDate)
    }
    
    /// 显示第几个（如"第8个"、"第3周年"）
    var countDisplay: String {
        if unit == "周年" {
            return "第\(count)周年"
        } else {
            return "第\(count)个"
        }
    }
    
    static func == (lhs: AnniversaryMilestone, rhs: AnniversaryMilestone) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 纪念日完整信息（添加 Equatable，支持 SwiftUI 跳过重绘）

struct AnniversaryInfo: Sendable, Equatable {
    let anniversary: Anniversary
    let calculation: AnniversaryCalculation
    let milestones: [AnniversaryMilestone]
    
    static func == (lhs: AnniversaryInfo, rhs: AnniversaryInfo) -> Bool {
        lhs.anniversary.id == rhs.anniversary.id
        && lhs.calculation.days == rhs.calculation.days
        && lhs.calculation.hours == rhs.calculation.hours
        && lhs.calculation.minutes == rhs.calculation.minutes
        && lhs.calculation.seconds == rhs.calculation.seconds
    }
    
    /// 仅计算时间（轻量，用于秒级更新）
    /// - Parameters:
    ///   - startDate: 起始日期
    ///   - referenceDate: 参考时间（NTP 修正后的时间），nil 则使用系统时间
    static func calculateTime(from startDate: Date, referenceDate: Date? = nil) -> AnniversaryCalculation {
        let now = referenceDate ?? Date()
        let totalSeconds = now.timeIntervalSince(startDate)
        let totalDays = totalSeconds / 86400.0
        let totalHours = totalSeconds / 3600.0  // 计算总小时数
        
        let components = Calendar.current.dateComponents(
            [.day, .hour, .minute, .second],
            from: startDate,
            to: now
        )
        
        return AnniversaryCalculation(
            totalDays: totalDays,
            totalSeconds: totalSeconds,
            totalHours: totalHours,
            days: components.day ?? 0,
            hours: components.hour ?? 0,
            minutes: components.minute ?? 0,
            seconds: components.second ?? 0
        )
    }
    
    /// 完整计算（包含里程碑，仅在纪念日数据变化时调用）
    /// - Parameters:
    ///   - anniversary: 纪念日
    ///   - referenceDate: 参考时间（NTP 修正后的时间），nil 则使用系统时间
    static func calculate(from anniversary: Anniversary, referenceDate: Date? = nil) -> AnniversaryInfo {
        let calc = calculateTime(from: anniversary.startDate, referenceDate: referenceDate)
        let milestones = calculateMilestones(from: anniversary.startDate, referenceDate: referenceDate)
        
        return AnniversaryInfo(
            anniversary: anniversary,
            calculation: calc,
            milestones: milestones
        )
    }
    
    /// 仅更新时间（不重新计算里程碑）
    /// - Parameter referenceDate: 参考时间（NTP 修正后的时间），nil 则使用系统时间
    func updatedTime(referenceDate: Date? = nil) -> AnniversaryInfo {
        let newCalc = Self.calculateTime(from: anniversary.startDate, referenceDate: referenceDate)
        return AnniversaryInfo(
            anniversary: anniversary,
            calculation: newCalc,
            milestones: milestones
        )
    }
    
    // MARK: - 里程碑计算
    
    static func calculateMilestones(from startDate: Date, referenceDate: Date? = nil) -> [AnniversaryMilestone] {
        let now = referenceDate ?? Date()
        let calendar = Calendar.current
        
        let days100 = nextMilestone(from: startDate, referenceDate: now, interval: 100, icon: "🌱", label: "下一个100天", unit: "个")
        let days180 = nextMilestone(from: startDate, referenceDate: now, interval: 180, icon: "🌿", label: "下一个180天", unit: "个")
        let days300 = nextMilestone(from: startDate, referenceDate: now, interval: 300, icon: "🍀", label: "下一个300天", unit: "个")
        
        let years = calendar.dateComponents([.year], from: startDate, to: now).year ?? 0
        let nextYear = years + 1
        let nextAnniversary = calendar.date(byAdding: .year, value: nextYear, to: startDate) ?? now
        
        let yearMilestone = AnniversaryMilestone(
            id: "anniversary_year",
            icon: "🎉",
            label: "下一个周年",
            targetDate: nextAnniversary,
            count: nextYear,
            unit: "周年"
        )
        
        return [days100, days180, days300, yearMilestone]
    }
    
    static func nextMilestone(from startDate: Date, referenceDate: Date, interval: Int, icon: String, label: String, unit: String) -> AnniversaryMilestone {
        let elapsedDays = Int(referenceDate.timeIntervalSince(startDate) / 86400)
        let passedCount = elapsedDays / interval
        let nextCount = passedCount + 1
        let nextDays = nextCount * interval
        
        let targetDate = Calendar.current.date(byAdding: .day, value: nextDays, to: startDate) ?? referenceDate
        
        return AnniversaryMilestone(
            id: "milestone_\(interval)_\(nextCount)",
            icon: icon,
            label: label,
            targetDate: targetDate,
            count: nextCount,
            unit: unit
        )
    }
}
