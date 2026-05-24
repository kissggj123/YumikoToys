//
//  AppHeader.swift
//  YumikoToys
//
//  应用头部组件（v4.0.0 - 全新设计）
//

import SwiftUI

struct AppHeader: View, Equatable {
    static func == (lhs: AppHeader, rhs: AppHeader) -> Bool { true }
    
    var body: some View {
        HStack(spacing: 16) {
            // 应用图标 - 使用自定义图片或渐变背景
            ZStack {
                // 渐变背景
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "FF6B9D"),
                                Color(hex: "C44FE2")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: Color(hex: "FF6B9D").opacity(0.4),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                
                // 尝试使用自定义图标，否则使用系统图标
                if let customImage = NSImage(named: "YumikoToys") {
                    Image(nsImage: customImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "rabbit.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            
            // 应用信息
            VStack(alignment: .leading, spacing: 3) {
                Text(AppConfig.appName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    Text(AppConfig.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // 版本标签
                    Text("v\(AppConfig.version)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.3))
                        )
                }
            }
            
            Spacer()
        }
        .padding(.bottom, 4)
    }
}

#Preview {
    AppHeader()
        .padding()
        .frame(width: 400)
}
