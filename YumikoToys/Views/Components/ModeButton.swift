//
//  ModeButton.swift
//  YumikoToys
//
//  模式切换按钮组件（v4.0.0 - 全新设计）
//

import SwiftUI

struct ModeButtonStyle: ButtonStyle {
    let mode: AppMode
    let isHovered: Bool

    private var modeColor: Color {
        Color(hex: mode.color)
    }

    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: [modeColor, modeColor.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconGradient)
                    .frame(width: 44, height: 44)
                    .shadow(
                        color: modeColor.opacity(0.3),
                        radius: configuration.isPressed ? 4 : 8,
                        x: 0,
                        y: configuration.isPressed ? 2 : 4
                    )
                    // 【增强】点击时发光脉冲效果
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(modeColor.opacity(configuration.isPressed ? 0.8 : 0), lineWidth: 2)
                            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
                            .opacity(configuration.isPressed ? 1 : 0)
                            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
                    )

                Image(systemName: mode.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: mode)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(mode.buttonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if mode == .study {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: .green.opacity(0.5), radius: 4)

                    // 【新增】脉冲光环动画
                    Circle()
                        .stroke(Color.green, lineWidth: 1)
                        .frame(width: 8, height: 8)
                        .scaleEffect(configuration.isPressed ? 2.5 : 1.0)
                        .opacity(configuration.isPressed ? 0 : 0.5)
                        .animation(.easeOut(duration: 0.4).repeatForever(autoreverses: false), value: configuration.isPressed)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        // 【增强】使用更弹性的缩放效果
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.12, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ModeButton: View {
    @Binding var mode: AppMode
    let onModeChange: (AppMode) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: toggleMode) {
            EmptyView()
        }
        .buttonStyle(ModeButtonStyle(mode: mode, isHovered: isHovered))
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.25), value: isHovered)
    }
    
    // MARK: - Actions
    
    private func toggleMode() {
        let newMode: AppMode = mode == .normal ? .study : .normal
        withAnimation(.easeInOut(duration: 0.25)) {
            mode = newMode
        }
        onModeChange(newMode)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    VStack {
        ModeButton(mode: .constant(.normal)) { _ in }
        ModeButton(mode: .constant(.study)) { _ in }
    }
    .padding()
    .frame(width: 400)
}
