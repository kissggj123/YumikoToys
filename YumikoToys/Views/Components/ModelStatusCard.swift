//
//  ModelStatusCard.swift
//  YumikoToys
//
//  主界面模型状态卡片 - 显示模型加载状态摘要
//

import SwiftUI

// MARK: - ModelStatusCard

struct ModelStatusCard: View {
    @ObservedObject var modelService: ModelManagementService
    let onManageTapped: () -> Void
    let layout: ComponentLayout?

    @State private var isHovered = false

    init(modelService: ModelManagementService, onManageTapped: @escaping () -> Void, layout: ComponentLayout? = nil) {
        self.modelService = modelService
        self.onManageTapped = onManageTapped
        self.layout = layout
    }

    private var themeColor: Color {
        if let hex = layout?.customColorHex {
            return Color(hex: hex)
        }
        return Color(hex: "5856D6")
    }
    
    private var fontSizeScale: Double {
        layout?.customFontSizeScale ?? 1.0
    }
    
    private var titleText: String {
        layout?.customTitle ?? "本地模型"
    }

    // MARK: - Computed Properties

    private var loadedCount: Int {
        modelService.models.filter { $0.isLoaded }.count
    }

    private var totalCount: Int {
        modelService.models.count
    }

    private var hasLoadedModels: Bool {
        loadedCount > 0
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 标题行
            headerRow

            // 分隔线
            Divider()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            // 模型状态网格
            modelGrid

            // 内存占用行
            if hasLoadedModels {
                memoryRow
                    .padding(.top, 10)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    Color.primary.opacity(isHovered ? 0.15 : 0.06),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 8) {
            // 紫色渐变图标
            Image(systemName: "cpu.fill")
                .font(.system(size: 14 * fontSizeScale, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeColor, themeColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 标题
            Text(titleText)
                .font(.system(size: 13 * fontSizeScale, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            // 状态指示
            HStack(spacing: 5) {
                Circle()
                    .fill(statusIndicatorColor)
                    .frame(width: 6, height: 6)

                Text("\(loadedCount)/\(totalCount) 已加载")
                    .font(.system(size: 11 * fontSizeScale, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // 管理按钮
            Button(action: onManageTapped) {
                Text("管理")
                    .font(.system(size: 11 * fontSizeScale, weight: .medium))
                    .foregroundStyle(themeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(themeColor.opacity(isHovered ? 0.12 : 0.06))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Status Indicator Color

    private var statusIndicatorColor: Color {
        hasLoadedModels ? .green : .secondary
    }

    // MARK: - Model Grid

    private var modelGrid: some View {
        HStack(spacing: 0) {
            ForEach(modelService.models) { model in
                ModelStatusItem(model: model, themeColor: themeColor)

                if model.id != modelService.models.last?.id {
                    Spacer()
                }
            }
        }
    }

    // MARK: - Memory Row

    private var memoryRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "memorychip")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)

            Text("内存占用")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)

            Spacer()

            Text(formattedMemoryUsage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
    }

    // MARK: - Helpers

    private var formattedMemoryUsage: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(modelService.totalMemoryUsage),
            countStyle: .memory
        )
    }
}

// MARK: - ModelStatusItem

private struct ModelStatusItem: View {
    let model: ModelInfo
    let themeColor: Color

    @State private var isPulsing = false

    // MARK: - Computed Properties

    private var isInference: Bool {
        if case .inference(let active) = model.status, active {
            return true
        }
        return false
    }

    private var statusColor: Color {
        switch model.status {
        case .ready:
            return .green
        case .downloading, .loading:
            return .blue
        case .error:
            return .red
        default:
            return .secondary
        }
    }

    private var statusIcon: String {
        model.type.icon
    }

    private var typeName: String {
        model.type.rawValue
    }

    private var statusText: String {
        model.status.displayText
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            // 圆形背景 + 类型图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: statusIcon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(statusColor)
            }
            .overlay(
                // 推理中脉冲动画
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 32, height: 32)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )

            // 类型名 + 状态
            VStack(alignment: .leading, spacing: 2) {
                Text(typeName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(statusText)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .onAppear {
            isPulsing = isInference
        }
        .onChange(of: isInference) { newValue in
            isPulsing = newValue
        }
    }
}
