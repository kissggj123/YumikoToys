//
//  AdvancedFeaturesService.swift
//  YumikoToys
//
//  高级功能管理服务 - 需要钥匙串/系统密码权限才能执行
//

import Foundation
import Combine
import SwiftUI

/// 高级功能类型
enum AdvancedFeature: String, CaseIterable, Identifiable {
    case preventSleep = "preventSleep"       // 防休眠
    case launchAtLogin = "launchAtLogin"     // 开机自启动
    case ntpSync = "ntpSync"                 // NTP 时间同步
    case dataExport = "dataExport"           // 数据导出
    case dataImport = "dataImport"           // 数据导入
    case dataReset = "dataReset"             // 数据重置
    case keychainAccess = "keychainAccess"   // 钥匙串管理
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .preventSleep: return "防休眠模式"
        case .launchAtLogin: return "开机自启动"
        case .ntpSync: return "NTP 时间同步"
        case .dataExport: return "数据导出"
        case .dataImport: return "数据导入"
        case .dataReset: return "数据重置"
        case .keychainAccess: return "钥匙串管理"
        }
    }
    
    var description: String {
        switch self {
        case .preventSleep: return "阻止系统和显示器进入休眠状态"
        case .launchAtLogin: return "登录时自动启动兔可可"
        case .ntpSync: return "同步网络时间确保纪念日计算准确"
        case .dataExport: return "导出纪念日和设置数据"
        case .dataImport: return "从文件导入纪念日和设置数据"
        case .dataReset: return "清除所有数据并恢复默认设置"
        case .keychainAccess: return "管理钥匙串中的敏感数据"
        }
    }
    
    var icon: String {
        switch self {
        case .preventSleep: return "shield.lefthalf.filled"
        case .launchAtLogin: return "power"
        case .ntpSync: return "clock.arrow.circlepath"
        case .dataExport: return "square.and.arrow.up"
        case .dataImport: return "square.and.arrow.down"
        case .dataReset: return "trash"
        case .keychainAccess: return "key.fill"
        }
    }
    
    var requiredAccessLevel: KeychainAccessLevel {
        switch self {
        case .preventSleep, .launchAtLogin, .ntpSync:
            return .standard
        case .dataExport, .dataImport:
            return .standard
        case .dataReset, .keychainAccess:
            return .advanced
        }
    }
    
    var isDestructive: Bool {
        switch self {
        case .dataReset: return true
        default: return false
        }
    }
}

/// 高级功能权限状态
enum FeatureAccessState: String {
    case granted     // 已授权
    case denied      // 已拒绝
    case pending     // 等待授权
    case notRequired // 不需要授权
}

/// 高级功能管理服务
@MainActor
final class AdvancedFeaturesService: ObservableObject {
    
    // MARK: - Properties
    
    let keychainService: KeychainAccessServiceProtocol
    let preventSleepService: PreventSleepServiceProtocol
    let launchAtLoginService: LaunchAtLoginServiceProtocol
    
    /// 各功能的权限状态
    @Published private(set) var accessStates: [AdvancedFeature: FeatureAccessState] = [:]
    
    /// 是否已通过高级授权
    @Published private(set) var isAdvancedUnlocked: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        keychainService: KeychainAccessServiceProtocol,
        preventSleepService: PreventSleepServiceProtocol,
        launchAtLoginService: LaunchAtLoginServiceProtocol
    ) {
        self.keychainService = keychainService
        self.preventSleepService = preventSleepService
        self.launchAtLoginService = launchAtLoginService
        
        // 初始化所有功能状态
        for feature in AdvancedFeature.allCases {
            accessStates[feature] = .notRequired
        }
    }
    
    // MARK: - Public Methods
    
    /// 请求功能权限
    func requestAccess(for feature: AdvancedFeature) async -> Bool {
        let requiredLevel = feature.requiredAccessLevel
        
        // 检查是否已有足够权限
        if keychainService.hasAccess {
            accessStates[feature] = .granted
            return true
        }
        
        // 请求权限
        accessStates[feature] = .pending
        
        let reason = "兔可可需要\(feature.displayName)权限：\(feature.description)"
        let granted = await keychainService.requestAccess(level: requiredLevel, reason: reason)
        
        accessStates[feature] = granted ? .granted : .denied
        
        if granted {
            isAdvancedUnlocked = true
            LoggerService.shared.info("Advanced feature granted: \(feature.displayName)")
        } else {
            LoggerService.shared.warning("Advanced feature denied: \(feature.displayName)")
        }
        
        return granted
    }
    
    /// 执行高级功能（自动检查权限）
    func executeFeature(_ feature: AdvancedFeature) async -> Bool {
        // 检查权限
        if accessStates[feature] != .granted && accessStates[feature] != .notRequired {
            guard await requestAccess(for: feature) else { return false }
        }
        
        // 执行功能
        switch feature {
        case .preventSleep:
            preventSleepService.togglePreventSleep()
            return true
            
        case .launchAtLogin:
            launchAtLoginService.toggle()
            return true
            
        case .ntpSync:
            // NTP 同步由 TimeSyncService 处理
            return true
            
        case .dataExport, .dataImport, .dataReset, .keychainAccess:
            // 这些功能由各自的服务处理
            return true
        }
    }
    
    /// 批量授权所有功能
    func unlockAllFeatures() async -> Bool {
        let granted = await keychainService.requestAccess(
            level: .advanced,
            reason: "解锁所有高级功能：包括防休眠、开机自启动、数据管理等"
        )
        
        if granted {
            isAdvancedUnlocked = true
            for feature in AdvancedFeature.allCases {
                accessStates[feature] = .granted
            }
            LoggerService.shared.info("All advanced features unlocked")
        }
        
        return granted
    }
    
    /// 锁定所有高级功能
    func lockAllFeatures() {
        isAdvancedUnlocked = false
        for feature in AdvancedFeature.allCases {
            accessStates[feature] = .notRequired
        }
        LoggerService.shared.info("All advanced features locked")
    }
    
    /// 检查功能是否可用
    func isFeatureAvailable(_ feature: AdvancedFeature) -> Bool {
        switch accessStates[feature] {
        case .granted, .notRequired:
            return true
        case .denied, .pending:
            return false
        case .none:
            return true  // 默认可用
        }
    }
}

// MARK: - Advanced Features View

/// 高级功能面板
struct AdvancedFeaturesPanel: View {
    @StateObject private var viewModel: AdvancedFeaturesViewModel
    @State private var showAuthPrompt = false
    @State private var pendingFeature: AdvancedFeature?
    
    init(viewModel: AdvancedFeaturesViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("高级功能")
                        .font(.headline)
                    Text("需要系统密码授权才能使用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 全局解锁/锁定按钮
                Button(viewModel.isAdvancedUnlocked ? "锁定全部" : "解锁全部") {
                    Task { await viewModel.toggleGlobalLock() }
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // 功能列表
            ForEach(AdvancedFeature.allCases) { feature in
                AdvancedFeatureRow(
                    feature: feature,
                    accessState: viewModel.accessStates[feature] ?? .notRequired,
                    isEnabled: viewModel.isFeatureEnabled(feature),
                    onToggle: {
                        Task { await viewModel.toggleFeature(feature) }
                    }
                )
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

/// 单个高级功能行
struct AdvancedFeatureRow: View {
    let feature: AdvancedFeature
    let accessState: FeatureAccessState
    let isEnabled: Bool
    let onToggle: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 14) {
            // 图标
            ZStack {
                Circle()
                    .fill(accessColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: feature.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(accessColor)
            }
            
            // 文字
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(feature.displayName)
                        .font(.system(size: 14, weight: .medium))
                    
                    // 权限状态标签
                    switch accessState {
                    case .granted:
                        Text("✓")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    case .denied:
                        Text("🔒")
                            .font(.system(size: 10))
                    case .pending:
                        Text("⏳")
                            .font(.system(size: 10))
                    case .notRequired:
                        EmptyView()
                    }
                }
                
                Text(feature.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 开关
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .disabled(accessState == .denied)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
    
    private var accessColor: Color {
        switch accessState {
        case .granted: return .green
        case .denied: return .red
        case .pending: return .orange
        case .notRequired: return .secondary
        }
    }
}

// MARK: - ViewModel

@MainActor
final class AdvancedFeaturesViewModel: ObservableObject {
    @Published var accessStates: [AdvancedFeature: FeatureAccessState] = [:]
    @Published var isAdvancedUnlocked: Bool = false
    
    private let service: AdvancedFeaturesService
    
    init(service: AdvancedFeaturesService) {
        self.service = service
    }
    
    func isFeatureEnabled(_ feature: AdvancedFeature) -> Bool {
        switch feature {
        case .preventSleep:
            return service.preventSleepService.isPreventSleepEnabled
        case .launchAtLogin:
            return service.launchAtLoginService.isEnabled
        default:
            return false
        }
    }
    
    func toggleFeature(_ feature: AdvancedFeature) async {
        await service.executeFeature(feature)
        accessStates = service.accessStates
        isAdvancedUnlocked = service.isAdvancedUnlocked
    }
    
    func toggleGlobalLock() async {
        if service.isAdvancedUnlocked {
            service.lockAllFeatures()
        } else {
            await service.unlockAllFeatures()
        }
        accessStates = service.accessStates
        isAdvancedUnlocked = service.isAdvancedUnlocked
    }
}
