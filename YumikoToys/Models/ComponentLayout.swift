//
//  ComponentLayout.swift
//  YumikoToys
//
//  主界面组件布局配置
//

import Foundation

/// 主界面组件类型
enum ComponentType: String, CaseIterable, Identifiable, Codable, Sendable {
    case header = "header"           // 应用头部
    case daysDisplay = "daysDisplay" // 天数展示卡片
    case milestones = "milestones"   // 里程碑列表
    case modeButton = "modeButton"   // 模式切换按钮
    case quickActions = "quickActions" // 快捷操作网格
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .header: return "应用标题"
        case .daysDisplay: return "天数展示"
        case .milestones: return "里程碑"
        case .modeButton: return "模式切换"
        case .quickActions: return "快捷操作"
        }
    }
    
    var icon: String {
        switch self {
        case .header: return "🐰"
        case .daysDisplay: return "📅"
        case .milestones: return "🎯"
        case .modeButton: return "🔄"
        case .quickActions: return "⚡"
        }
    }
    
    var description: String {
        switch self {
        case .header: return "显示应用标题和图标"
        case .daysDisplay: return "显示已到来天数"
        case .milestones: return "显示下一个里程碑"
        case .modeButton: return "切换应用运行模式"
        case .quickActions: return "快捷功能入口"
        }
    }
    
    /// 是否可隐藏
    var isOptional: Bool {
        switch self {
        case .header, .daysDisplay:
            return false  // 核心组件不可隐藏
        case .milestones, .modeButton, .quickActions:
            return true
        }
    }
}

/// 组件布局配置
struct ComponentLayout: Codable, Identifiable, Sendable, Equatable {
    let type: ComponentType
    var isVisible: Bool
    var sortOrder: Int
    
    var id: String { type.rawValue }
    
    init(type: ComponentType, isVisible: Bool = true, sortOrder: Int = 0) {
        self.type = type
        self.isVisible = isVisible
        self.sortOrder = sortOrder
    }
    
    /// 默认布局配置
    static let defaultLayout: [ComponentLayout] = [
        ComponentLayout(type: .header, isVisible: true, sortOrder: 0),
        ComponentLayout(type: .daysDisplay, isVisible: true, sortOrder: 1),
        ComponentLayout(type: .milestones, isVisible: true, sortOrder: 2),
        ComponentLayout(type: .modeButton, isVisible: true, sortOrder: 3),
        ComponentLayout(type: .quickActions, isVisible: true, sortOrder: 4)
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
            // 从存储中读取，如果没有则返回默认布局
            // 实际实现需要在 StorageService 中添加支持
            ComponentLayout.defaultLayout
        }
    }
}
