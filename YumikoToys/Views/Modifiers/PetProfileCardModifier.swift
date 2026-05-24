//
//  PetProfileCardModifier.swift
//  YumikoToys
//
//  宠物名片弹窗修饰符 - 居中卡片弹窗 + 高精度毛玻璃背景
//

import SwiftUI

struct PetProfileCardModifier: ViewModifier {
    @Binding var isPresented: Bool
    let anniversary: Anniversary
    let calculation: AnniversaryCalculation

    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    if isPresented {
                        // 背景遮罩 - 点击关闭
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                dismiss()
                            }
                            .transition(.opacity)

                        // 弹窗卡片 (此时它会自动调用在 PetProfileCardView.swift 中定义的最新版视图)
                        PetProfileCardView(
                            anniversary: anniversary,
                            calculation: calculation,
                            onClose: {
                                dismiss()
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPresented)
            )
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }
}

// MARK: - View 扩展

extension View {
    /// 附加宠物名片精美弹窗
    func petProfileCard(
        isPresented: Binding<Bool>,
        anniversary: Anniversary,
        calculation: AnniversaryCalculation
    ) -> some View {
        modifier(PetProfileCardModifier(
            isPresented: isPresented,
            anniversary: anniversary,
            calculation: calculation
        ))
    }
}
