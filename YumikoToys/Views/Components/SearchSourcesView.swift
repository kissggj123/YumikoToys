//
//  SearchSourcesView.swift
//  YumikoToys
//
//  搜索来源展示视图
//

import SwiftUI

struct SearchSourcesView: View {
    let sources: [SearchSource]

    @State private var isExpanded = true

    var body: some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: "3B82F6"))

                        Text("🌐 搜索了 \(sources.count) 个来源")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "3B82F6"))
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(sources) { source in
                            SourceRow(source: source)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "3B82F6").opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "3B82F6").opacity(0.15), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

private struct SourceRow: View {
    let source: SearchSource

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Text(source.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Text(source.snippet)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
