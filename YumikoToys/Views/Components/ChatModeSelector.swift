//
//  ChatModeSelector.swift
//  YumikoToys
//
//  对话模式切换组件
//

import SwiftUI

struct ChatModeSelector: View {
    @Binding var selectedMode: ChatMode
    let onModeChange: (ChatMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ChatMode.allCases) { mode in
                ChatModeButton(
                    mode: mode,
                    isSelected: selectedMode == mode,
                    action: {
                        if selectedMode != mode {
                            selectedMode = mode
                            onModeChange(mode)
                        }
                    }
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct ChatModeButton: View {
    let mode: ChatMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(mode.icon)
                    .font(.system(size: 14))
                Text(mode.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AnyShapeStyle(modeGradient) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(.plain)
    }

    private var modeGradient: LinearGradient {
        let hexColors = mode.themeGradient
        return LinearGradient(
            colors: hexColors.map { Color(hex: $0) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
