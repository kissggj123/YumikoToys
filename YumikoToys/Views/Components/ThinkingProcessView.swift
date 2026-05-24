//
//  ThinkingProcessView.swift
//  YumikoToys
//
//  深度思考过程折叠展示视图
//

import SwiftUI

struct ThinkingProcessView: View {
    let thinkingContent: String
    let duration: TimeInterval?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "06B6D4"))

                    Text("🧠 思考过程")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "06B6D4"))

                    if let duration = duration {
                        Text("(\(String(format: "%.1f", duration))s)")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(thinkingContent)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "06B6D4").opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "06B6D4").opacity(0.15), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
