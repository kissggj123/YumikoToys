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

// MARK: - 点击粒子特效系统 (Interactive Click Particle System)

struct ClickParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let vx: CGFloat
    let vy: CGFloat
    let color: Color
    let emoji: String
    let scale: CGFloat
    let rotation: Double
    let rotationSpeed: Double
    let spawnTime: Date
    let lifetime: Double
}

struct ClickEffectModifier: ViewModifier {
    @State private var particles: [ClickParticle] = []
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        spawnParticles(at: value.location)
                    }
            )
            .overlay(
                TimelineView(.animation(minimumInterval: 0.016)) { timelineContext in
                    Canvas { context, size in
                        let now = timelineContext.date
                        for p in particles {
                            let elapsed = now.timeIntervalSince(p.spawnTime)
                            guard elapsed >= 0 && elapsed < p.lifetime else { continue }
                            
                            let progress = elapsed / p.lifetime
                            let opacity = 1.0 - progress
                            
                            if p.emoji.isEmpty {
                                // Ripple or shape-based effects
                                let radius = 80.0 * progress
                                var path = Path()
                                path.addEllipse(in: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2))
                                context.stroke(path, with: .color(p.color.opacity(opacity)), style: StrokeStyle(lineWidth: CGFloat(3.5 - 2.0 * progress)))
                            } else if p.emoji == "COLOR_DOT" {
                                let gravity: CGFloat = 280.0
                                let dx = p.vx * CGFloat(elapsed)
                                let dy = p.vy * CGFloat(elapsed) + 0.5 * gravity * CGFloat(elapsed * elapsed)
                                let radius = 6.0 * CGFloat(1.0 - progress)
                                var path = Path()
                                path.addEllipse(in: CGRect(x: p.x + dx - radius, y: p.y + dy - radius, width: radius * 2, height: radius * 2))
                                context.fill(path, with: .color(p.color.opacity(opacity)))
                            } else {
                                // Emoji-based effects (sparkle, heart)
                                let dx: CGFloat
                                let dy: CGFloat
                                let effect = DependencyContainer.shared.settingsService.settings.activeClickEffect
                                if effect == .heart {
                                    let sway = 15.0 * sin(elapsed * 8.0 + Double(p.id.uuidString.hashValue % 5))
                                    dx = p.vx * CGFloat(elapsed) + CGFloat(sway)
                                    dy = p.vy * CGFloat(elapsed)
                                } else {
                                    dx = p.vx * CGFloat(elapsed)
                                    dy = p.vy * CGFloat(elapsed)
                                }
                                
                                let currentRotation = p.rotation + p.rotationSpeed * elapsed
                                let currentScale = p.scale * CGFloat(1.0 - progress)
                                
                                var particleContext = context
                                particleContext.opacity = opacity
                                let resolved = context.resolve(
                                    Text(p.emoji)
                                        .font(.system(size: 24 * currentScale))
                                )
                                particleContext.translateBy(x: p.x + dx, y: p.y + dy)
                                particleContext.rotate(by: Angle(degrees: currentRotation))
                                particleContext.draw(resolved, at: .zero)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            )
    }
    
    private func spawnParticles(at location: CGPoint) {
        let effect = DependencyContainer.shared.settingsService.settings.activeClickEffect
        guard effect != .none else { return }
        
        let count: Int
        let lifetime: Double
        switch effect {
        case .sparkle:
            count = 12
            lifetime = 0.55
        case .ripple:
            count = 3
            lifetime = 0.45
        case .heart:
            count = 10
            lifetime = 0.75
        case .firework:
            count = 18
            lifetime = 0.7
        case .none:
            return
        }
        
        let now = Date()
        var newParticles: [ClickParticle] = []
        
        for i in 0..<count {
            let p: ClickParticle
            switch effect {
            case .sparkle:
                let angle = Double.random(in: 0...(2 * .pi))
                let speed = CGFloat.random(in: 50...140)
                let scale = CGFloat.random(in: 0.6...1.2)
                p = ClickParticle(
                    x: location.x,
                    y: location.y,
                    vx: speed * cos(angle),
                    vy: speed * sin(angle),
                    color: .yellow,
                    emoji: ["⭐", "✨", "🌟"].randomElement()!,
                    scale: scale,
                    rotation: Double.random(in: 0...360),
                    rotationSpeed: Double.random(in: -120...120),
                    spawnTime: now,
                    lifetime: lifetime
                )
            case .ripple:
                p = ClickParticle(
                    x: location.x,
                    y: location.y,
                    vx: 0,
                    vy: 0,
                    color: [Color.pink, Color.purple, Color.cyan][i % 3],
                    emoji: "",
                    scale: 1.0,
                    rotation: 0,
                    rotationSpeed: 0,
                    spawnTime: now + Double(i) * 0.08,
                    lifetime: lifetime
                )
            case .heart:
                let angle = Double.random(in: (1.2 * .pi)...(1.8 * .pi)) // upward cone
                let speed = CGFloat.random(in: 40...110)
                let scale = CGFloat.random(in: 0.6...1.2)
                p = ClickParticle(
                    x: location.x,
                    y: location.y,
                    vx: speed * cos(angle),
                    vy: speed * sin(angle),
                    color: .pink,
                    emoji: ["❤️", "💖", "💝", "💕"].randomElement()!,
                    scale: scale,
                    rotation: Double.random(in: -20...20),
                    rotationSpeed: Double.random(in: -45...45),
                    spawnTime: now,
                    lifetime: lifetime
                )
            case .firework:
                let angle = Double.random(in: 0...(2 * .pi))
                let speed = CGFloat.random(in: 70...190)
                let scale = CGFloat.random(in: 0.5...1.0)
                p = ClickParticle(
                    x: location.x,
                    y: location.y,
                    vx: speed * cos(angle),
                    vy: speed * sin(angle),
                    color: Color(hue: Double.random(in: 0...1), saturation: 0.85, brightness: 1.0),
                    emoji: "COLOR_DOT",
                    scale: scale,
                    rotation: 0,
                    rotationSpeed: 0,
                    spawnTime: now,
                    lifetime: lifetime
                )
            case .none:
                continue
            }
            newParticles.append(p)
        }
        
        particles.append(contentsOf: newParticles)
        if particles.count > 150 {
            particles.removeFirst(particles.count - 150)
        }
    }
}

extension View {
    func interactiveClickEffect() -> some View {
        self.modifier(ClickEffectModifier())
    }
}
