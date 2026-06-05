//
//  AppHeader.swift
//  YumikoToys
//
//  应用头部组件（v4.0.0 - 全新设计）
//

import SwiftUI

struct AppHeader: View, Equatable {
    let layout: ComponentLayout?
    
    init(layout: ComponentLayout? = nil) {
        self.layout = layout
    }
    
    static func == (lhs: AppHeader, rhs: AppHeader) -> Bool {
        lhs.layout == rhs.layout
    }
    
    private var titleText: String {
        layout?.customTitle ?? AppConfig.appName
    }
    
    private var fontSizeScale: Double {
        layout?.customFontSizeScale ?? 1.0
    }
    
    private var accentColors: [Color] {
        if let hex = layout?.customColorHex {
            let col = Color(hex: hex)
            return [col, col.opacity(0.7)]
        }
        let settings = DependencyContainer.shared.settingsService.settings
        let themeColor = settings.mainWindowThemeColor
        return themeColor.iconGradient(customHex: settings.customMainWindowThemeColorHex)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 应用图标 - 使用自定义图片或渐变背景
            ZStack {
                // 渐变背景
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: accentColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: (accentColors.first ?? .clear).opacity(0.4),
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
                        .font(.system(size: 28 * fontSizeScale, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            
            // 应用信息
            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.system(size: 22 * fontSizeScale, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 4) {
                    Text(AppConfig.displayName)
                        .font(.system(size: 13 * fontSizeScale))
                        .foregroundStyle(.secondary)
                    
                    // 版本标签
                    Text("v\(AppConfig.version)")
                        .font(.system(size: 10 * fontSizeScale))
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
