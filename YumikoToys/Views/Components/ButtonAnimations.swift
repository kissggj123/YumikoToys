//
//  ButtonAnimations.swift
//  YumikoToys
//
//  统一按钮动画效果组件库
//

import SwiftUI

// MARK: - 弹性缩放按钮样式

struct BounceScaleButtonStyle: ButtonStyle {
    let scaleFactor: CGFloat
    let duration: Double

    init(scaleFactor: CGFloat = 0.92, duration: Double = 0.1) {
        self.scaleFactor = scaleFactor
        self.duration = duration
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleFactor : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - 发光脉冲按钮样式

struct GlowPulseButtonStyle: ButtonStyle {
    let glowColor: Color
    let glowRadius: CGFloat

    init(glowColor: Color = .pink, glowRadius: CGFloat = 8) {
        self.glowColor = glowColor
        self.glowRadius = glowRadius
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .shadow(color: glowColor.opacity(configuration.isPressed ? 0.8 : 0.3), radius: configuration.isPressed ? glowRadius * 1.5 : glowRadius)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.12, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - 涟漪扩散按钮样式

struct RippleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0))
                    .scaleEffect(configuration.isPressed ? 1.5 : 0)
                    .animation(.easeOut(duration: 0.3), value: configuration.isPressed)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - 颜色渐变按钮样式

struct GradientButtonStyle: ButtonStyle {
    let fromColor: Color
    let toColor: Color
    let isActive: Bool

    init(fromColor: Color = Color(hex: "FF6B9D"), toColor: Color = Color(hex: "C44FE2"), isActive: Bool = true) {
        self.fromColor = fromColor
        self.toColor = toColor
        self.isActive = isActive
    }

    func makeBody(configuration: Configuration) -> some View {
        // Precompute gradient and target opacity to avoid type-checking complexity
        let baseGradient = LinearGradient(
            colors: [fromColor.opacity(0.8), toColor.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        let overlayOpacity: Double = configuration.isPressed ? 0.7 : (isActive ? 1.0 : 0.3)

        return configuration.label
            // Use background with explicit opacity to avoid ambiguous overloads on LinearGradient
            .background(
                baseGradient
                    .opacity(overlayOpacity)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(
                .spring(response: 0.12, dampingFraction: 0.75),
                value: configuration.isPressed
            )
    }
}

// MARK: - 震动反馈效果

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 5
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

// MARK: - 点击涟漪效果视图

struct ClickRipple: View {
    let color: Color
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.3))
            .frame(width: 20, height: 20)
            .scaleEffect(isAnimating ? 3 : 0)
            .opacity(isAnimating ? 0 : 1)
            .animation(.easeOut(duration: 0.5), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - 动画化图标视图

struct AnimatedIcon: View {
    let systemName: String
    let size: CGFloat
    @State private var isBouncing = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .scaleEffect(isBouncing ? 1.2 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isBouncing)
    }

    func triggerBounce() {
        isBouncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isBouncing = false
        }
    }
}

// MARK: - 渐变文字效果

struct GradientText: View {
    let text: String
    let font: Font
    let colors: [Color]

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

// MARK: - 脉冲动画视图

struct PulseAnimation: View {
    @State private var isAnimating = false

    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.5 : 1.0)
            .animation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - 弹性进入视图

struct BounceIn: ViewModifier {
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1 : 0.5)
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

extension View {
    func bounceIn() -> some View {
        modifier(BounceIn())
    }
}
