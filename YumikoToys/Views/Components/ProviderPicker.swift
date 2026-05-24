//
//  ProviderPicker.swift
//  YumikoToys
//
//  API 提供商选择器
//

import SwiftUI

struct ProviderPicker: View {
    @Binding var selectedProvider: AIProviderType
    let onProviderChange: (AIProviderType) -> Void

    var body: some View {
        Menu {
            ForEach(AIProviderType.allCases) { provider in
                Button(action: {
                    if selectedProvider != provider {
                        selectedProvider = provider
                        onProviderChange(provider)
                    }
                }) {
                    HStack {
                        Text(provider.icon)
                        Text(provider.displayName)
                        if selectedProvider == provider {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedProvider.icon)
                    .font(.system(size: 14))
                Text(selectedProvider.displayName)
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
    }
}
