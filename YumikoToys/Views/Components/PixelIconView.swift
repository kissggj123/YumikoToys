//
//  PixelIconView.swift
//  YumikoToys
//
//  像素风格图标组件
//

import SwiftUI

/// 像素图标类型
enum PixelIcon: CaseIterable {
    case rabbit      // 🐰 兔子 - 纪念日
    case fox         // 🦊 狐狸 - AI对话
    case cat         // 🐱 猫咪 - 更新日志
    case bear        // 🐻 小熊 - 设置
    case panda       // 🐼 熊猫 - 关于
    case unicorn     // 🦄 独角兽 - 退出
    
    /// 16x16 像素数据（true = 填充）
    var pixelData: [[Bool]] {
        switch self {
        case .rabbit:
            return [
                [false, false, false, false, true, true, false, false, false, true, true, false, false, false, false, false],
                [false, false, false, true, true, true, true, false, true, true, true, true, false, false, false, false],
                [false, false, false, true, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false],
                [false, false, false, false, false, true, true, true, true, true, false, false, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, false, false, false, false, false],
                [false, false, false, true, true, false, true, true, true, false, true, true, false, false, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, false, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, false, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, false, false, false],
                [false, false, false, true, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, false, true, true, false, false, false, true, true, false, false, false, false, false],
                [false, false, false, true, true, false, false, false, false, false, true, true, false, false, false, false],
                [false, false, true, true, false, false, false, false, false, false, false, true, true, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
            ]
        case .fox:
            return [
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, true, true, false, false, true, true, false, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, false, false, true, true, true, true, true, true, false, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, true, true, false, true, true, true, true, false, true, true, false, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, false, true, true, true, true, true, true, true, true, true, true, false, false, false],
                [false, false, false, false, true, true, false, false, false, false, true, true, false, false, false, false],
                [false, false, false, true, true, false, false, false, false, false, false, true, true, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
            ]
        case .cat:
            return [
                [false, false, false, false, false, true, true, false, false, true, true, false, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, false, false, true, true, true, true, true, true, false, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, true, true, false, true, true, true, true, false, true, true, false, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, false, true, true, true, true, true, true, true, true, true, true, false, false, false],
                [false, false, false, false, true, true, false, false, false, false, true, true, false, false, false, false],
                [false, false, false, true, true, false, false, false, false, false, false, true, true, false, false, false],
                [false, false, true, true, false, false, false, false, false, false, false, false, true, true, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
            ]
        case .bear:
            return [
                [false, false, false, false, true, true, false, false, false, false, true, true, false, false, false, false],
                [false, false, false, true, true, true, true, false, false, true, true, true, true, false, false, false],
                [false, false, false, true, true, true, true, true, true, true, true, true, true, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, false, false, true, true, true, true, true, true, false, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, true, true, false, true, true, true, true, false, true, true, false, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, false, true, true, true, true, true, true, true, true, true, true, false, false, false],
                [false, false, false, false, true, true, false, false, false, false, true, true, false, false, false, false],
                [false, false, false, true, true, false, false, false, false, false, false, true, true, false, false, false],
                [false, false, true, true, false, false, false, false, false, false, false, false, true, true, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
            ]
        case .panda:
            return [
                [false, false, false, false, true, true, false, false, false, false, true, true, false, false, false, false],
                [false, false, false, true, true, true, true, false, false, true, true, true, true, false, false, false],
                [false, false, false, true, true, true, true, true, true, true, true, true, true, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, false, false, true, true, true, true, true, true, false, false, false, false, false],
                [false, false, false, false, true, true, true, true, true, true, true, true, false, false, false, false],
                [false, false, false, true, true, false, true, true, true, true, false, true, true, false, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, true, true, true, true, true, true, true, true, true, true, true, true, false, false],
                [false, false, false, true, true, true, true, true, true, true, true, true, true, false, false, false],
                [false, false, false, false, true, true, false, false, false, false, true, true, false, false, false, false],
                [false, false, false, true, true, false, false, false, false, false, false, true, true, false, false, false],
                [false, false, true, true, false, false, false, false, false, false, false, false, true, true, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
            ]
        case .unicorn:
            return [
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
                [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
            ]
        }
    }
    
    /// 图标颜色
    var color: Color {
        switch self {
        case .rabbit: return Color(hex: "FF6B9D")  // 粉色
        case .fox: return Color(hex: "F4A261")     // 橙色
        case .cat: return Color(hex: "5856D6")     // 紫色
        case .bear: return Color(hex: "8E8E93")    // 灰色
        case .panda: return Color(hex: "34C759")   // 绿色
        case .unicorn: return Color(hex: "FF3B30") // 红色
        }
    }
}

/// 像素图标视图
struct PixelIconView: View {
    let icon: PixelIcon
    let size: CGFloat
    
    @State private var isHovered = false
    
    var body: some View {
        Canvas { context, canvasSize in
            let pixelSize = canvasSize.width / 16  // 16x16 像素网格
            let pixelData = icon.pixelData
            
            for (row, pixels) in pixelData.enumerated() {
                for (col, isFilled) in pixels.enumerated() where isFilled {
                    let rect = CGRect(
                        x: CGFloat(col) * pixelSize,
                        y: CGFloat(row) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    context.fill(Path(rect), with: .color(icon.color))
                }
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    HStack(spacing: 20) {
        ForEach(PixelIcon.allCases, id: \.self) { icon in
            PixelIconView(icon: icon, size: 48)
        }
    }
    .padding()
}
