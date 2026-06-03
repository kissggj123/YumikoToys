//
//  ComponentLayout.swift
//  YumikoToys
//
//  主界面组件布局配置
//

import Foundation

/// 主界面组件类型
enum ComponentType: String, CaseIterable, Identifiable, Codable, Sendable {
    case header = "header"                       // 应用头部
    case daysDisplay = "daysDisplay"             // 天数展示卡片
    case backgroundLearning = "backgroundLearning" // 后台学习日志卡片
    case modelStatus = "modelStatus"             // 本地模型状态卡片
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .header: return "应用标题"
        case .daysDisplay: return "天数展示"
        case .backgroundLearning: return "心智建模与评估日志"
        case .modelStatus: return "本地模型状态"
        }
    }
    
    var icon: String {
        switch self {
        case .header: return "🐰"
        case .daysDisplay: return "📅"
        case .backgroundLearning: return "🧠"
        case .modelStatus: return "🤖"
        }
    }
    
    var description: String {
        switch self {
        case .header: return "显示应用标题和图标"
        case .daysDisplay: return "显示已到来天数"
        case .backgroundLearning: return "显示心智建模特征及后台分进度"
        case .modelStatus: return "显示端侧SLM本地大模型运行状态"
        }
    }
    
    /// 是否可隐藏
    var isOptional: Bool {
        switch self {
        case .header, .daysDisplay:
            return false  // 核心组件不可隐藏
        case .backgroundLearning, .modelStatus:
            return true
        }
    }
}

/// 组件布局配置
struct ComponentLayout: Codable, Identifiable, Sendable, Equatable {
    let type: ComponentType
    var isVisible: Bool
    var sortOrder: Int
    
    // 自定义修饰属性
    var customTitle: String?
    var customFontSizeScale: Double?  // 字体大小缩放 (0.8 - 1.5)
    var customColorHex: String?      // 自定义卡片背景/主题色 Hex
    
    var id: String { type.rawValue }
    
    init(
        type: ComponentType,
        isVisible: Bool = true,
        sortOrder: Int = 0,
        customTitle: String? = nil,
        customFontSizeScale: Double? = nil,
        customColorHex: String? = nil
    ) {
        self.type = type
        self.isVisible = isVisible
        self.sortOrder = sortOrder
        self.customTitle = customTitle
        self.customFontSizeScale = customFontSizeScale
        self.customColorHex = customColorHex
    }
    
    /// 默认布局配置
    static let defaultLayout: [ComponentLayout] = [
        ComponentLayout(type: .header, isVisible: true, sortOrder: 0),
        ComponentLayout(type: .daysDisplay, isVisible: true, sortOrder: 1),
        ComponentLayout(type: .backgroundLearning, isVisible: true, sortOrder: 2),
        ComponentLayout(type: .modelStatus, isVisible: true, sortOrder: 3)
    ]
    
    /// 按排序顺序排列
    static func sorted(_ layouts: [ComponentLayout]) -> [ComponentLayout] {
        layouts.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    /// 获取可见组件
    static func visible(_ layouts: [ComponentLayout]) -> [ComponentLayout] {
        layouts.filter { $0.isVisible }.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - AppSettings 扩展

extension AppSettings {
    /// 组件布局（存储在 UserDefaults 中）
    var componentLayouts: [ComponentLayout] {
        get {
            ComponentLayout.defaultLayout
        }
    }
}
