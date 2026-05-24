//
//  MenuList.swift
//  YumikoToys
//
//  菜单列表组件（Equatable 优化 + hover 状态下沉）
//

import SwiftUI

struct MenuList: View, Equatable {
    let onItemTap: (MenuItemIdentifier) -> Void
    
    static func == (lhs: MenuList, rhs: MenuList) -> Bool { true }
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach(MenuItemIdentifier.allCases) { item in
                Button(action: {
                    onItemTap(item)
                }) {
                    MenuItemView(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

// MARK: - MenuItemView（hover 状态下沉到每个 item）

private struct MenuItemView: View {
    let item: MenuItemIdentifier
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(item.isDestructive ? .red : .secondary)
                .frame(width: 24, height: 24)
            
            Text(item.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(item.isDestructive ? .red : .primary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private var backgroundColor: Color {
        if isHovered {
            return item.isDestructive ? Color.red.opacity(0.1) : Color.accentColor.opacity(0.1)
        }
        return Color.clear
    }
}

#Preview {
    MenuList { item in
        print("Tapped: \(item.title)")
    }
    .padding()
    .frame(width: 300)
}
