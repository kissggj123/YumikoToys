//
//  ProactiveToolCardView.swift
//  YumikoToys
//
//  主动工具建议卡片视图
//

import SwiftUI

struct ProactiveToolCardView: View {
    let toolName: String
    let displayName: String
    let reason: String
    let arguments: String
    let confidence: Double
    let onExecute: () -> Void
    let onDismiss: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("💡 主动建议: \(displayName)")
                        .font(.system(size: 13, weight: .semibold))
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Button(action: onDismiss) {
                        Text("忽略")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onExecute) {
                        Text("执行")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentColor)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                    Text(isExpanded ? "收起详情" : "查看详情")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("工具: \(toolName)")
                        .font(.system(.caption, design: .monospaced))
                    Text("参数: \(arguments)")
                        .font(.system(.caption, design: .monospaced))
                    HStack(spacing: 4) {
                        Text("置信度:")
                            .font(.system(size: 10))
                        ProgressView(value: confidence)
                            .frame(width: 60)
                        Text(String(format: "%.0f%%", confidence * 100))
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.05))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}
