//
//  AgentStepView.swift
//  YumikoToys
//
//  Agent 工具调用步骤展示视图
//

import SwiftUI

struct AgentStepView: View {
    let toolName: String
    let arguments: String
    let result: String?
    let isError: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isError ? "exclamationmark.triangle" : "gearshape.2")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isError ? .orange : Color(hex: "8B5CF6"))

                    Text("🤖 调用工具: \(toolName)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isError ? .orange : Color(hex: "8B5CF6"))

                    Spacer()

                    if result != nil {
                        Image(systemName: isError ? "xmark.circle" : "checkmark.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(isError ? .orange : .green)
                    } else {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("参数:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(arguments)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    if let result = result {
                        Divider()
                        Text("结果:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(8)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "8B5CF6").opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "8B5CF6").opacity(0.15), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
