//
//  ToastView.swift
//  YumikoToys
//
//  Toast 提示组件
//

import SwiftUI

struct ToastView: View {
    let message: String
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.75))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .onAppear {
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isPresented = false
                            }
                        }
                    }
                }
        }
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    ToastView(message: message, isPresented: $isPresented)
                        .padding(.bottom, 60)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
                }
            }
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message))
    }
}

// MARK: - 复制工具

import AppKit

func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State var showToast = true

        var body: some View {
            VStack {
                Button("显示 Toast") {
                    withAnimation {
                        showToast = true
                    }
                }
            }
            .frame(width: 300, height: 300)
            .toast(isPresented: $showToast, message: "已复制到剪贴板")
        }
    }

    return PreviewWrapper()
}
