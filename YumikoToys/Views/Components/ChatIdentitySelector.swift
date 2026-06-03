//
//  ChatIdentitySelector.swift
//  YumikoToys
//
//  AI 陪伴身份切换组件
//

import SwiftUI

struct ChatIdentitySelector: View {
    @Binding var selectedIdentity: ChatIdentity
    let onIdentityChange: (ChatIdentity) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ChatIdentity.allCases) { identity in
                ChatIdentityButton(
                    identity: identity,
                    isSelected: selectedIdentity == identity,
                    action: {
                        if selectedIdentity != identity {
                            selectedIdentity = identity
                            onIdentityChange(identity)
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

private struct ChatIdentityButton: View {
    let identity: ChatIdentity
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(identityEmoji)
                    .font(.system(size: 14))
                Text(identity.displayName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AnyShapeStyle(identityGradient) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(.plain)
    }

    private var identityEmoji: String {
        switch identity {
        case .pet: return "🐾"
        case .psychologyExpert: return "🧠"
        }
    }

    private var identityGradient: LinearGradient {
        switch identity {
        case .pet:
            return LinearGradient(
                colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .psychologyExpert:
            return LinearGradient(
                colors: [Color(hex: "5856D6"), Color(hex: "AF52DE")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
