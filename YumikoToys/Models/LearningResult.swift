//
//  LearningResult.swift
//  YumikoToys
//
//  后台学习结果数据模型（v2.1 - 深度心理学自适应与 UI 渲染优化版）
//

import Foundation

/// 学习到的用户偏好模型
struct UserPreference: Codable, Sendable, Identifiable, Hashable, Equatable {
    let id: UUID
    let key: String      // 偏好类型，如 "喜欢"、"不喜欢"、"习惯"
    let value: String    // 偏好内容实体
    let confidence: Double // 0.0 - 1.0 学习置信度
    let learnedAt: Date  // 学习记录时间
    let source: String   // 来源对话
    
    // MARK: - UI 展示辅助计算属性
    
    /// 置信度百分比表达形式（如：85%）
    var confidencePercent: String {
        String(format: "%.0f%%", confidence * 100)
    }
    
    /// 缓存日期格式化器（避免重复创建带来的开销）
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
    
    /// 格式化后的学习时间
    var formattedDate: String {
        Self.dateFormatter.string(from: learnedAt)
    }
    
    /// 高雅的人类语言摘要说明（已融入临床心理学表达规范）
    var summaryText: String {
        switch key {
        case "喜欢":
            return "对 [\(value)] 表现出偏爱"
        case "不喜欢":
            return "表现出避免接触 [\(value)] 的倾向"
        case "习惯":
            return "形成了频繁 [\(value)] 的生活规律"
        case "宠物":
            return "拥有一只 [\(value)]"
        case "自我介绍":
            return "自我描述为 [\(value)]"
        case "情感":
            return "当前情感状态：\(value)"
        case "性格":
            return "性格特点：\(value)"
        case "名字":
            return "用户名字：\(value)"
        case "工作":
            return "从事工作：\(value)"
        case "饮食偏好":
            return "饮食偏好：\(value)"
        case "饮食禁忌":
            return "饮食禁忌：\(value)"
        case "游戏":
            return "正在玩：\(value)"
        case "角色扮演":
            return "角色扮演数据：\(value)"
        case "居住地":
            return "居住在：\(value)"
        case "作息":
            return "作息规律：\(value)"
        case "娱乐":
            return "娱乐偏好：\(value)"
        case "健康":
            return "健康状况：\(value)"
        case "社交关系":
            return "社交关系：\(value)"
        case "目标":
            return "目标计划：\(value)"
            
        // MARK: - 【新增：专业心理学本地特征摘要化映射】
        case "压力源":
            return "检测到潜在心理应激源：[\(value)]"
        case "自我评估":
            return "表现出深度自我认知与觉察：[\(value)]"
        case "应对方式":
            return "习惯采用 [\(value)] 的心理应对策略"
            
        default:
            return "被记录为：对 [\(value)] 拥有 [\(key)] 偏好"
        }
    }
}

/// 学习统计模型
struct LearningStats: Codable, Sendable, Hashable, Equatable {
    var totalConversationsAnalyzed: Int
    var totalPreferencesLearned: Int
    var lastLearningDate: Date?
    var isLearningEnabled: Bool
}

/// 学习结果模型
struct LearningResult: Codable, Sendable, Hashable, Equatable {
    var preferences: [UserPreference]
    var stats: LearningStats
    
    // MARK: - 面向 SwiftUI 列表的开箱即用语义分组属性（已补充心理学分组）
    
    /// 过滤出所有“喜欢”的偏好列表
    var likes: [UserPreference] {
        preferences.filter { $0.key == "喜欢" }
    }
    
    /// 过滤出所有“不喜欢”的偏好列表
    var dislikes: [UserPreference] {
        preferences.filter { $0.key == "不喜欢" }
    }
    
    /// 过滤出所有“习惯”的偏好列表
    var habits: [UserPreference] {
        preferences.filter { $0.key == "习惯" }
    }
    
    // MARK: - 【核心新增：面向 UI 的离线心理档案过滤属性】
    
    /// 过滤出所有检测到的“压力源”
    var stressors: [UserPreference] {
        preferences.filter { $0.key == "压力源" }
    }
    
    /// 过滤出所有提取到的“自我评估”
    var selfEvaluations: [UserPreference] {
        preferences.filter { $0.key == "自我评估" }
    }
    
    /// 过滤出所有表现出的“应对方式”
    var copingStyles: [UserPreference] {
        preferences.filter { $0.key == "应对方式" }
    }
}
