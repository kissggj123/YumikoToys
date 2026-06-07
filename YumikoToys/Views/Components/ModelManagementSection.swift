//
//  ModelManagementSection.swift
//  YumikoToys
//
//  设置页面 - 本地模型管理区域
//

import SwiftUI

// MARK: - ModelManagementSection

struct ModelManagementSection: View {
    @ObservedObject var modelService: ModelManagementService
    @StateObject private var authService = HuggingFaceAuthService.shared
    @State private var showingDeleteConfirmation = false
    @State private var modelToDelete: String?
    @State private var showingAuthenticationAlert = false
    @State private var showingCookieInput = false
    @State private var showingTokenInput = false
    @State private var cookieInput = ""
    @State private var tokenInput = ""
    @State private var authHost = "huggingface.co"

    private var totalMemoryFormatted: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(modelService.totalMemoryUsage),
            countStyle: .memory
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 分组标题行
            sectionHeader

            // 认证按钮（在需要登录时显示）
            authenticationBanner

            // 模型列表
            VStack(spacing: 12) {
                ForEach(modelService.models) { model in
                    ModelManagementCard(
                        model: model,
                        modelService: modelService,
                        onDelete: { modelId in
                            modelToDelete = modelId
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }

            // 高级设置
            AdvancedModelSettings()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .alert("确认删除模型", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) {
                modelToDelete = nil
            }
            Button("删除", role: .destructive) {
                guard let modelId = modelToDelete else { return }
                Task {
                    try? await modelService.deleteModel(modelId)
                }
                modelToDelete = nil
            }
        } message: {
            if let modelId = modelToDelete,
               let model = modelService.models.first(where: { $0.id == modelId }) {
                Text("确定要删除「\(model.name)」吗？此操作将移除已下载的模型文件，不可撤销。")
            } else {
                Text("确定要删除此模型吗？")
            }
        }
        .alert("需要登录认证", isPresented: $showingAuthenticationAlert) {
            Button("打开登录页面") {
                modelService.openLoginPage()
            }
            Button("我已登录", role: .cancel) { }
        } message: {
            if let host = modelService.authenticationRequired {
                Text("下载模型需要登录 \(host)。\n\n点击「打开登录页面」在浏览器中登录，然后返回重试下载。")
            } else {
                Text("下载模型需要登录认证。")
            }
        }
        .alert("输入 Cookie", isPresented: $showingCookieInput) {
            TextField("粘贴 Cookie 字符串", text: $cookieInput)
                .textFieldStyle(.roundedBorder)
            Button("取消", role: .cancel) {
                cookieInput = ""
            }
            Button("保存") {
                if !cookieInput.isEmpty {
                    modelService.saveAuthenticationCookie(cookieInput)
                    cookieInput = ""
                }
            }
        } message: {
            Text("在浏览器中登录后，打开开发者工具 -> Application/Storage -> Cookies，复制 hf_token 或其他认证 cookie 的值。")
        }
        .sheet(isPresented: $showingTokenInput) {
            HuggingFaceAuthSheet(authService: authService)
        }
        .onChange(of: modelService.authenticationRequired) { oldValue, newValue in
            if newValue != nil {
                showingAuthenticationAlert = true
            }
        }
    }

    // MARK: - Authentication Banner

    private var authenticationBanner: some View {
        VStack(spacing: 8) {
            if authService.isAuthenticated {
                // 已认证状态
                authenticatedBanner
            } else {
                // 未认证状态
                unauthenticatedBanner
            }
        }
    }

    /// 已认证状态横幅
    private var authenticatedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "34C759"))

            VStack(alignment: .leading, spacing: 2) {
                Text("HuggingFace 已认证")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                if let username = authService.username {
                    Text("用户: \(username)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                authService.signOut()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 10))
                    Text("退出")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "34C759").opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "34C759").opacity(0.2), lineWidth: 1)
                )
        )
    }

    /// 未认证状态横幅
    private var unauthenticatedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "FF9500"))

            VStack(alignment: .leading, spacing: 2) {
                Text("HuggingFace 登录认证")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("部分模型需要登录才能下载")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingTokenInput = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 10))
                    Text("登录")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "FF9500"))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "FF9500").opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "FF9500").opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "5856D6"))

            Text("本地模型")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            // 一键卸载按钮（当有模型加载时显示）
            if modelService.models.contains(where: { $0.isLoaded }) {
                Button {
                    withAnimation {
                        for model in modelService.models where model.isLoaded {
                            modelService.unloadModel(model.id)
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                        Text("一键卸载")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color(hex: "FF9500"))
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
                .help("一键卸载所有已加载的模型以释放物理内存")
            }

            // 一键禁用/启用所有模型
            let anyEnabled = modelService.models.contains { !modelService.isModelDisabled($0.id) }
            Button {
                withAnimation {
                    if anyEnabled {
                        modelService.disableAllModels()
                    } else {
                        modelService.enableAllModels()
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: anyEnabled ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 10))
                    Text(anyEnabled ? "一键禁用" : "一键启用")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color(hex: anyEnabled ? "FF3B30" : "34C759"))
                )
            }
            .buttonStyle(.plain)
            .help(anyEnabled ? "禁用所有模型，启动时将不会加载任何模型" : "启用所有已禁用的模型")

            // 内存使用统计
            HStack(spacing: 4) {
                Image(systemName: "memorychip")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                Text(totalMemoryFormatted)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - ModelManagementCard

struct ModelManagementCard: View {
    let model: ModelInfo
    @ObservedObject var modelService: ModelManagementService
    let onDelete: (String) -> Void

    @State private var isHovered = false

    private var progressValue: Double? {
        switch model.status {
        case .downloading(let progress):
            return progress
        case .loading(let progress):
            return progress
        default:
            return nil
        }
    }

    private var isModelDisabled: Bool {
        modelService.isModelDisabled(model.id)
    }

    private var statusColor: Color {
        if isModelDisabled {
            return Color(hex: "8E8E93")
        }
        switch model.status {
        case .ready, .inference:
            return Color(hex: "34C759")
        case .downloaded:
            return Color(hex: "007AFF")
        case .downloading, .loading:
            return Color(hex: "5856D6")
        case .notDownloaded:
            return Color(hex: "8E8E93")
        case .error:
            return Color(hex: "FF3B30")
        }
    }

    private var statusText: String {
        if isModelDisabled {
            return "已禁用"
        }
        return model.status.displayText
    }

    private var statusDotPulse: Bool {
        if isModelDisabled {
            return false
        }
        switch model.status {
        case .downloading, .loading, .inference(true):
            return true
        default:
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 标题行
            titleRow

            // 描述文本
            Text(model.description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 进度条
            if let progress = progressValue {
                progressBar(progress)
            }

            // 操作按钮
            actionButtons

            // 性能统计（已加载时显示）
            if model.isLoaded {
                performanceStats
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(isHovered ? 0.04 : 0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            Color.primary.opacity(isHovered ? 0.08 : 0.04),
                            lineWidth: 1
                        )
                )
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    // MARK: - Title Row

    private var titleRow: some View {
        HStack(spacing: 8) {
            // 类型图标
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "5856D6").opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: model.type.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "5856D6"))
            }

            // 名称
            Text(model.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            // "必需"标签
            if model.isRequired {
                Text("必需")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color(hex: "FF6B9D"))
                    )
            }

            Spacer()

            // 状态指示器
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: statusColor.opacity(0.5), radius: statusDotPulse ? 3 : 0)
                    .modifier(PulseDotModifier(isPulsing: statusDotPulse))

                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusColor)
            }
        }
    }

    // MARK: - Progress Bar

    private func progressBar(_ progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "5856D6"), Color(hex: "AF52DE")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                switch model.status {
                case .notDownloaded:
                    downloadButton
 
                case .downloaded:
                    loadButton
                    deleteButton
 
                case .ready:
                    unloadButton
                    deleteButton
 
                case .downloading, .loading:
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
 
                case .inference:
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
 
                case .error:
                    retryButton
                }
                
                Spacer()
                
                // 禁用开关
                Toggle("禁用模型", isOn: Binding(
                    get: { isModelDisabled },
                    set: { modelService.setModelDisabled(model.id, disabled: $0) }
                ))
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
 
            // 错误状态下显示详细错误信息
            if case .error(let message) = model.status {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "FF3B30"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
 
    private var downloadButton: some View {
        Button {
            Task { await modelService.downloadModel(model.id) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 11))
                Text("下载")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "5856D6"))
            )
        }
        .buttonStyle(.plain)
    }
 
    private var loadButton: some View {
        Button {
            Task {
                try? await modelService.loadModel(model.id)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "play.circle")
                    .font(.system(size: 11))
                Text("加载")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "34C759").opacity(isModelDisabled ? 0.4 : 1.0))
            )
        }
        .buttonStyle(.plain)
        .disabled(isModelDisabled)
    }

    private var unloadButton: some View {
        Button {
            modelService.unloadModel(model.id)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "stop.circle")
                    .font(.system(size: 11))
                Text("卸载")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "FF9500"))
            )
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button {
            onDelete(model.id)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                Text("删除")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color(hex: "FF3B30"))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "FF3B30").opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    private var retryButton: some View {
        Button {
            Task { await modelService.downloadModel(model.id) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                Text("重试")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "FF3B30"))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Performance Stats

    private var performanceStats: some View {
        HStack(spacing: 16) {
            StatItem(
                icon: "bolt.fill",
                value: "\(model.inferenceCount)",
                label: "推理次数"
            )

            StatItem(
                icon: "clock",
                value: String(format: "%.0fms", model.averageInferenceTime * 1000),
                label: "平均耗时"
            )

            if let lastUsed = model.lastUsed {
                StatItem(
                    icon: "calendar",
                    value: {
                        let formatter = RelativeDateTimeFormatter()
                        return formatter.localizedString(for: lastUsed, relativeTo: Date())
                    }(),
                    label: "上次使用"
                )
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - StatItem

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "5856D6").opacity(0.7))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - AdvancedModelSettings

struct AdvancedModelSettings: View {
    @AppStorage("autoLoadModels") private var autoLoadModels = false
    @AppStorage("memoryBudgetGB") private var memoryBudgetGB: Double = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(Color.primary.opacity(0.08))

            Text("高级设置")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            // 启动时自动加载模型
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("启动时自动加载模型")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Text("应用启动后自动加载已下载的必需模型")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Toggle("", isOn: $autoLoadModels)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            // 内存预算
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("内存预算")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(String(format: "%.0f GB", memoryBudgetGB))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(hex: "5856D6"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: "5856D6").opacity(0.1))
                        )
                }

                HSlider(
                    value: $memoryBudgetGB,
                    range: 1...8,
                    step: 1
                )
                .tint(Color(hex: "5856D6"))

                HStack {
                    Text("1 GB")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("8 GB")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .onChange(of: memoryBudgetGB) { oldValue, newValue in
            ModelMemoryManager.shared.memoryBudget = UInt64(newValue * 1024 * 1024 * 1024)
            LoggerService.shared.info("[AdvancedModelSettings] 内存预算更新为 \(newValue) GB")
        }
        .onAppear {
            ModelMemoryManager.shared.memoryBudget = UInt64(memoryBudgetGB * 1024 * 1024 * 1024)
            LoggerService.shared.info("[AdvancedModelSettings] 内存预算初始化为 \(memoryBudgetGB) GB")
        }
    }
}

// MARK: - Pulse Dot Modifier

private struct PulseDotModifier: ViewModifier {
    let isPulsing: Bool
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing && isAnimating ? 1.4 : 1.0)
            .opacity(isPulsing && isAnimating ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onChange(of: isPulsing) { _, newValue in
                isAnimating = newValue
            }
            .onAppear {
                if isPulsing {
                    isAnimating = true
                }
            }
    }
}

// MARK: - HSlider (macOS Slider wrapper)

/// macOS 14+ 使用新的 Slider API，低版本回退
private struct HSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        Slider(value: $value, in: range, step: step)
            .controlSize(.small)
    }
}
