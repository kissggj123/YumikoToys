//
//  ModelCompatibilityManager.swift
//  YumikoToys
//
//  模型兼容管理器 - 自动检测并切换到兼容模型
//

import Foundation
import SwiftUI

/// 模型切换事件
enum ModelSwitchEvent: Equatable {
    case switched(from: String, to: String, reason: String)
    case noCompatibleModel(requirement: String)
    case alreadyCompatible

    var description: String {
        switch self {
        case .switched(let from, let to, let reason):
            return "已从 \(from) 切换至 \(to) 以支持\(reason)"
        case .noCompatibleModel(let requirement):
            return "无可用模型支持\(requirement)"
        case .alreadyCompatible:
            return "当前模型已兼容"
        }
    }
}

/// 模型兼容管理器
@MainActor
final class ModelCompatibilityManager: ObservableObject {
    /// 当前模型
    @Published var currentModel: AIModelInfo?

    /// 可用模型列表
    @Published var availableModels: [AIModelInfo] = []

    /// 最近一次自动切换记录
    @Published var lastSwitchEvent: ModelSwitchEvent?

    /// 是否显示切换提示
    @Published var showSwitchNotification: Bool = false

    /// 切换冷却时间（避免频繁切换）
    private var lastSwitchTime: Date?
    private let switchCooldown: TimeInterval = 3.0

    /// 兼容性缓存
    private var compatibilityCache: [String: ModelCapabilityRequirement] = [:]

    // MARK: - 初始化

    init(availableModels: [AIModelInfo] = [], currentModel: AIModelInfo? = nil) {
        self.availableModels = availableModels
        self.currentModel = currentModel
    }

    // MARK: - 公开方法

    /// 检查当前模型是否满足需求
    func checkCompatibility(requirements: ModelCapabilityRequirement) -> Bool {
        guard let model = currentModel else { return false }
        return modelSupports(model, requirements: requirements)
    }

    /// 检查特定功能是否兼容
    func checkCompatibility(for feature: FeatureRequirement) -> Bool {
        checkCompatibility(requirements: feature.requirements)
    }

    /// 确保兼容性（自动切换到兼容模型）
    func ensureCompatibility(requirements: ModelCapabilityRequirement) async -> ModelSwitchEvent {
        // 检查当前模型
        if let model = currentModel, modelSupports(model, requirements: requirements) {
            lastSwitchEvent = .alreadyCompatible
            return .alreadyCompatible
        }

        // 检查冷却时间
        if let lastSwitch = lastSwitchTime,
           Date().timeIntervalSince(lastSwitch) < switchCooldown {
            return lastSwitchEvent ?? .alreadyCompatible
        }

        // 查找兼容模型
        guard let compatibleModel = findBestModel(for: requirements) else {
            let event = ModelSwitchEvent.noCompatibleModel(
                requirement: requirements.descriptions.joined(separator: ", ")
            )
            lastSwitchEvent = event
            return event
        }

        // 执行切换
        let fromModel = currentModel?.name ?? "未知模型"
        currentModel = compatibleModel
        lastSwitchTime = Date()

        let event = ModelSwitchEvent.switched(
            from: fromModel,
            to: compatibleModel.name,
            reason: requirements.descriptions.joined(separator: ", ")
        )
        lastSwitchEvent = event
        showSwitchNotification = true

        return event
    }

    /// 为特定功能确保兼容性
    func ensureCompatibility(for feature: FeatureRequirement) async -> ModelSwitchEvent {
        await ensureCompatibility(requirements: feature.requirements)
    }

    /// 获取最佳兼容模型
    func findBestModel(for requirements: ModelCapabilityRequirement) -> AIModelInfo? {
        // 筛选满足所有需求的模型
        let compatibleModels = availableModels.filter { model in
            modelSupports(model, requirements: requirements)
        }

        // 按优先级排序：能力越多越好，同 provider 优先
        return compatibleModels.sorted { a, b in
            let aScore = capabilityScore(a)
            let bScore = capabilityScore(b)
            if aScore != bScore { return aScore > bScore }
            // 相同分数时，优先选择当前 provider 的模型
            if let current = currentModel {
                if a.provider == current.provider && b.provider != current.provider {
                    return true
                }
            }
            return a.name < b.name
        }.first
    }

    /// 获取所有支持某功能的模型
    func getCompatibleModels(for feature: FeatureRequirement) -> [AIModelInfo] {
        availableModels.filter { modelSupports($0, requirements: feature.requirements) }
    }

    /// 静默切换模型（无提示）
    func silentSwitch(to model: AIModelInfo) {
        currentModel = model
    }

    /// 更新可用模型列表
    func updateAvailableModels(_ models: [AIModelInfo]) {
        availableModels = models
        // 更新缓存
        for model in models {
            compatibilityCache[model.id] = ModelCompatibilityInfo.detectCapabilities(for: model)
        }
    }

    /// 获取模型能力
    func getCapabilities(for model: AIModelInfo) -> ModelCapabilityRequirement {
        if let cached = compatibilityCache[model.id] {
            return cached
        }
        let caps = ModelCompatibilityInfo.detectCapabilities(for: model)
        compatibilityCache[model.id] = caps
        return caps
    }

    /// 清除切换通知
    func clearNotification() {
        showSwitchNotification = false
    }

    // MARK: - 私有方法

    private func modelSupports(_ model: AIModelInfo, requirements: ModelCapabilityRequirement) -> Bool {
        let modelCapabilities = getCapabilities(for: model)
        return modelCapabilities.contains(requirements)
    }

    private func capabilityScore(_ model: AIModelInfo) -> Int {
        let caps = getCapabilities(for: model)
        var score = 0
        if caps.contains(.thinking) { score += 10 }
        if caps.contains(.tools) { score += 8 }
        if caps.contains(.vision) { score += 5 }
        if caps.contains(.longContext) { score += 3 }
        if caps.contains(.codeExecution) { score += 2 }
        return score
    }
}

// MARK: - View Modifier

extension View {
    /// 模型切换通知覆盖层
    func modelSwitchNotification(manager: ModelCompatibilityManager) -> some View {
        self.overlay(
            Group {
                if manager.showSwitchNotification,
                   let event = manager.lastSwitchEvent {
                    ModelSwitchNotificationView(event: event) {
                        manager.clearNotification()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            },
            alignment: .top
        )
    }
}

/// 模型切换通知视图
struct ModelSwitchNotificationView: View {
    let event: ModelSwitchEvent
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)

            Text(event.description)
                .font(.system(size: 12))
                .foregroundStyle(.white)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = true
            }
            // 3秒后自动消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                onDismiss()
            }
        }
    }

    private var iconName: String {
        switch event {
        case .switched: return "arrow.right.arrow.left.circle.fill"
        case .noCompatibleModel: return "exclamationmark.triangle.fill"
        case .alreadyCompatible: return "checkmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch event {
        case .switched: return .blue
        case .noCompatibleModel: return .orange
        case .alreadyCompatible: return .green
        }
    }

    private var backgroundColor: Color {
        switch event {
        case .switched: return Color.blue.opacity(0.2)
        case .noCompatibleModel: return Color.orange.opacity(0.2)
        case .alreadyCompatible: return Color.green.opacity(0.2)
        }
    }
}
