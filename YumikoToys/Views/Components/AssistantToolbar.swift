//
//  AssistantToolbar.swift
//  YumikoToys
//
//  助手模式功能工具栏
//

import SwiftUI

struct AssistantToolbar: View {
    @Binding var enableDeepThinking: Bool
    @Binding var enableWebSearch: Bool
    @Binding var enableAgentMode: Bool

    var body: some View {
        HStack(spacing: 8) {
            ToolbarToggleButton(
                icon: "🧠",
                title: "深度思考",
                isOn: enableDeepThinking,
                action: { enableDeepThinking.toggle() }
            )

            ToolbarToggleButton(
                icon: "🌐",
                title: "联网搜索",
                isOn: enableWebSearch,
                action: { enableWebSearch.toggle() }
            )

            ToolbarToggleButton(
                icon: "🤖",
                title: "Agent",
                isOn: enableAgentMode,
                action: { enableAgentMode.toggle() }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct ToolbarToggleButton: View {
    let icon: String
    let title: String
    let isOn: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isOn ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isOn
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "3B82F6"), Color(hex: "06B6D4")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        : AnyShapeStyle(Color.primary.opacity(isHovered ? 0.08 : 0.04))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn
                        ? Color(hex: "3B82F6").opacity(0.3)
                        : Color.primary.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isOn)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
