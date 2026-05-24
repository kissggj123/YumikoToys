//
//  GenderSelectorView.swift
//  YumikoToys
//
//  三层性别选择器组件（大圆预览 + 分段选择器 + 图标按钮组）
//

import SwiftUI

struct GenderSelectorView: View {
    @Binding var gender: PetGender
    
    @State private var isAnimating = false
    @State private var hoveredGender: PetGender?
    
    var body: some View {
        VStack(spacing: 20) {
            // 第一层：大圆预览
            largeCirclePreview
            
            // 第二层：分段选择器
            segmentedPicker
            
            // 第三层：图标按钮组
            iconButtonGroup
        }
    }
    
    // MARK: - 第一层：大圆预览
    
    private var largeCirclePreview: some View {
        ZStack {
            // 外圈发光
            Circle()
                .stroke(
                    gender.isRainbow
                        ? AnyShapeStyle(PetGender.rainbowGradient)
                        : AnyShapeStyle(gender.color),
                    lineWidth: 3
                )
                .frame(width: 88, height: 88)
                .blur(radius: gender == .unknown ? 0 : 8)
                .opacity(gender == .unknown ? 0.3 : 0.6)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // 主圆
            Circle()
                .fill(
                    gender.isRainbow
                        ? AnyShapeStyle(PetGender.rainbowGradient)
                        : AnyShapeStyle(gender.color.opacity(0.15))
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .stroke(
                            gender.isRainbow
                                ? AnyShapeStyle(PetGender.rainbowGradient)
                                : AnyShapeStyle(gender.color),
                            lineWidth: 2
                        )
                )
            
            // 性别符号
            Text(gender.emoji)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(
                    gender.isRainbow
                        ? AnyShapeStyle(PetGender.rainbowGradient)
                        : AnyShapeStyle(gender.color)
                )
        }
        .onAppear { isAnimating = true }
        .onChange(of: gender) { _ in
            // 切换时触发脉冲动画
            isAnimating = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - 第二层：分段选择器
    
    private var segmentedPicker: some View {
        HStack(spacing: 0) {
            ForEach([PetGender.male, .female, .neutral], id: \.self) { g in
                Button(action: { withAnimation { gender = g } }) {
                    HStack(spacing: 4) {
                        Text(g.emoji)
                            .font(.system(size: 14, weight: .bold))
                        Text(g.displayName)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        gender == g
                            ? (g.isRainbow
                                ? AnyShapeStyle(PetGender.rainbowGradient)
                                : AnyShapeStyle(g.color.opacity(0.2)))
                            : AnyShapeStyle(Color.clear)
                    )
                    .foregroundStyle(
                        gender == g
                            ? (g.isRainbow ? .white : g.color)
                            : .secondary
                    )
                }
                .buttonStyle(.plain)
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
        .cornerRadius(10)
    }
    
    // MARK: - 第三层：图标按钮组
    
    private var iconButtonGroup: some View {
        HStack(spacing: 12) {
            ForEach(PetGender.allCases, id: \.self) { g in
                GenderIconButton(
                    gender: g,
                    isSelected: gender == g,
                    isHovered: hoveredGender == g
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        gender = g
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hoveredGender = hovering ? g : nil
                    }
                }
            }
        }
    }
}

// MARK: - 性别图标按钮

private struct GenderIconButton: View {
    let gender: PetGender
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    
    @State private var bounce = false
    
    var body: some View {
        Button(action: {
            // 点击弹跳动画
            bounce = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                bounce = false
            }
            action()
        }) {
            VStack(spacing: 4) {
                Text(gender.emoji)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        gender.isRainbow
                            ? AnyShapeStyle(PetGender.rainbowGradient)
                            : AnyShapeStyle(gender.color)
                    )
                
                Text(gender.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? (gender.isRainbow ? .primary : gender.color) : .secondary)
            }
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                        ? (gender.isRainbow
                            ? AnyShapeStyle(PetGender.rainbowGradient.opacity(0.2))
                            : AnyShapeStyle(gender.color.opacity(0.15)))
                        : AnyShapeStyle(Color.primary.opacity(isHovered ? 0.08 : 0.03)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                            ? (gender.isRainbow
                                ? AnyShapeStyle(PetGender.rainbowGradient)
                                : AnyShapeStyle(gender.color))
                            : AnyShapeStyle(Color.clear),
                        lineWidth: isSelected ? 2 : 0
                    )
            )
            .shadow(
                color: isSelected && !gender.isRainbow
                    ? gender.color.opacity(0.3)
                    : .clear,
                radius: isHovered ? 8 : 4
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(bounce ? 1.1 : (isHovered ? 1.05 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: bounce)
        .animation(.spring(response: 0.2), value: isHovered)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var gender: PetGender = .neutral
        
        var body: some View {
            GenderSelectorView(gender: $gender)
                .padding()
                .frame(width: 400, height: 350)
        }
    }
    
    return PreviewWrapper()
}
