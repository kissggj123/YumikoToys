//
//  PixelArtIcons.swift
//  YumikoToys
//
//  完整像素艺术图标集 - 基于 YumikoToys-IconStyles-Design.jpg 设计图
//  使用 SwiftUI Canvas 绘制，支持 4 种风格
//

import SwiftUI
import AppKit

// MARK: - 像素图标绘制引擎

/// 像素图标绘制引擎
struct PixelArtRenderer {
    /// 在 Canvas 上绘制像素图标
    static func draw(
        context: GraphicsContext,
        size: CGSize,
        pixels: [[UInt8]],
        palette: [Color]
    ) {
        let rows = pixels.count
        guard rows > 0 else { return }
        let cols = pixels[0].count
        let pixelW = size.width / CGFloat(cols)
        let pixelH = size.height / CGFloat(rows)
        
        for (row, rowData) in pixels.enumerated() {
            for (col, colorIndex) in rowData.enumerated() where colorIndex > 0 {
                let color = palette[Int(colorIndex) - 1]
                let rect = CGRect(
                    x: CGFloat(col) * pixelW,
                    y: CGFloat(row) * pixelH,
                    width: pixelW + 0.5,  // +0.5 消除像素间隙
                    height: pixelH + 0.5
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
    }
}

// MARK: - 调色板定义

enum PixelPalette {
    /// 兔子 - 粉色系
    static let rabbit: [Color] = [
        Color(hex: "FFB5C5"),  // 1: 浅粉（主体）
        Color(hex: "FF8FA3"),  // 2: 中粉（阴影）
        Color(hex: "FF6B9D"),  // 3: 深粉（轮廓/耳朵内部）
        Color(hex: "FFFFFF"),  // 4: 白色（眼睛高光）
        Color(hex: "2D2D2D"),  // 5: 深灰（眼睛/鼻子）
        Color(hex: "FFD4E0"),  // 6: 腮红
    ]
    
    /// 狐狸 - 橙色系
    static let fox: [Color] = [
        Color(hex: "F4A261"),  // 1: 橙色（主体）
        Color(hex: "E76F51"),  // 2: 深橙（阴影）
        Color(hex: "FFFFFF"),  // 3: 白色（脸部/眼睛高光）
        Color(hex: "2D2D2D"),  // 4: 深灰（鼻子/眼睛）
        Color(hex: "264653"),  // 5: 深蓝（耳朵内部）
    ]
    
    /// 猫咪 - 紫色系
    static let cat: [Color] = [
        Color(hex: "B8A9E8"),  // 1: 浅紫（主体）
        Color(hex: "8B7EC8"),  // 2: 中紫（阴影）
        Color(hex: "5856D6"),  // 3: 深紫（轮廓）
        Color(hex: "FFFFFF"),  // 4: 白色（眼睛高光）
        Color(hex: "2D2D2D"),  // 5: 深灰（眼睛）
        Color(hex: "FFB5C5"),  // 6: 粉色（鼻子/耳朵内部）
    ]
    
    /// 小熊 - 棕色系
    static let bear: [Color] = [
        Color(hex: "C4A882"),  // 1: 浅棕（主体）
        Color(hex: "A68B6B"),  // 2: 中棕（阴影）
        Color(hex: "8B6F4E"),  // 3: 深棕（轮廓）
        Color(hex: "D4B896"),  // 4: 米色（嘴巴区域）
        Color(hex: "FFFFFF"),  // 5: 白色（眼睛高光）
        Color(hex: "2D2D2D"),  // 6: 深灰（眼睛/鼻子）
    ]
    
    /// 熊猫 - 黑白系
    static let panda: [Color] = [
        Color(hex: "FFFFFF"),  // 1: 白色（脸部）
        Color(hex: "2D2D2D"),  // 2: 黑色（轮廓/眼圈）
        Color(hex: "4A4A4A"),  // 3: 深灰（阴影）
        Color(hex: "1A1A1A"),  // 4: 纯黑（眼睛）
        Color(hex: "FFB5C5"),  // 5: 粉色（腮红）
    ]
    
    /// 独角兽 - 彩虹系
    static let unicorn: [Color] = [
        Color(hex: "FFFFFF"),  // 1: 白色（主体）
        Color(hex: "E8E0F0"),  // 2: 浅紫（阴影）
        Color(hex: "FFD700"),  // 3: 金色（角）
        Color(hex: "FF6B9D"),  // 4: 粉色（鬃毛）
        Color(hex: "5856D6"),  // 5: 紫色（鬃毛）
        Color(hex: "34C759"),  // 6: 绿色（鬃毛）
        Color(hex: "007AFF"),  // 7: 蓝色（鬃毛）
        Color(hex: "FF9500"),  // 8: 橙色（鬃毛）
        Color(hex: "2D2D2D"),  // 9: 深灰（眼睛）
        Color(hex: "FFB5C5"),  // 10: 粉色（腮红）
    ]

    /// 狗 - 金色/棕色系
    static let dog: [Color] = [
        Color(hex: "D4A574"),  // 1: 金棕（主体）
        Color(hex: "B8864E"),  // 2: 深棕（阴影）
        Color(hex: "8B6914"),  // 3: 暗棕（轮廓）
        Color(hex: "FFFFFF"),  // 4: 白色（眼睛高光）
        Color(hex: "2D2D2D"),  // 5: 深灰（眼睛/鼻子）
        Color(hex: "F5DEB3"),  // 6: 米色（嘴巴区域）
    ]

    /// 仓鼠 - 暖黄/橙色系
    static let hamster: [Color] = [
        Color(hex: "F5D5A0"),  // 1: 暖黄（主体）
        Color(hex: "E8C080"),  // 2: 中黄（阴影）
        Color(hex: "D4A860"),  // 3: 深黄（轮廓/耳朵内部）
        Color(hex: "FFFFFF"),  // 4: 白色（眼睛高光）
        Color(hex: "2D2D2D"),  // 5: 深灰（眼睛）
        Color(hex: "FFB5C5"),  // 6: 粉色（腮红/鼻子）
    ]

    /// 青蛙 - 绿色系
    static let frog: [Color] = [
        Color(hex: "7BC67E"),  // 1: 浅绿（主体）
        Color(hex: "4CAF50"),  // 2: 中绿（阴影）
        Color(hex: "2E7D32"),  // 3: 深绿（轮廓）
        Color(hex: "FFFFFF"),  // 4: 白色（眼睛高光）
        Color(hex: "2D2D2D"),  // 5: 深灰（眼睛）
        Color(hex: "C8E6C9"),  // 6: 浅绿（腹部）
    ]

    /// 企鹅 - 黑白/蓝色系
    static let penguin: [Color] = [
        Color(hex: "2D2D2D"),  // 1: 黑色（背部/头部）
        Color(hex: "4A4A4A"),  // 2: 深灰（阴影）
        Color(hex: "FFFFFF"),  // 3: 白色（腹部/眼睛高光）
        Color(hex: "FFD700"),  // 4: 金色（嘴巴）
        Color(hex: "1A1A1A"),  // 5: 纯黑（眼睛）
        Color(hex: "FFB5C5"),  // 6: 粉色（腮红）
    ]

    /// 鹦鹉 - 红绿/彩色系
    static let parrot: [Color] = [
        Color(hex: "E53935"),  // 1: 红色（头部）
        Color(hex: "43A047"),  // 2: 绿色（身体）
        Color(hex: "2E7D32"),  // 3: 深绿（翅膀阴影）
        Color(hex: "FFFFFF"),  // 4: 白色（眼睛高光）
        Color(hex: "2D2D2D"),  // 5: 深灰（眼睛）
        Color(hex: "FFD700"),  // 6: 金色（嘴巴）
        Color(hex: "FDD835"),  // 7: 黄色（翅膀点缀）
    ]

    /// 乌龟 - 深绿/棕色系
    static let turtle: [Color] = [
        Color(hex: "66BB6A"),  // 1: 绿色（壳/头部）
        Color(hex: "43A047"),  // 2: 深绿（壳纹路）
        Color(hex: "8D6E63"),  // 3: 棕色（壳底色）
        Color(hex: "FFFFFF"),  // 4: 白色（眼睛高光）
        Color(hex: "2D2D2D"),  // 5: 深灰（眼睛）
        Color(hex: "A5D6A7"),  // 6: 浅绿（头部/四肢）
    ]

    /// 鱼 - 蓝色/橙色系
    static let fish: [Color] = [
        Color(hex: "42A5F5"),  // 1: 蓝色（主体）
        Color(hex: "1E88E5"),  // 2: 深蓝（阴影）
        Color(hex: "FF9800"),  // 3: 橙色（尾巴/鳍）
        Color(hex: "FFFFFF"),  // 4: 白色（眼睛高光）
        Color(hex: "2D2D2D"),  // 5: 深灰（眼睛）
        Color(hex: "BBDEFB"),  // 6: 浅蓝（腹部）
    ]

    /// 蜥蜴 - 绿色/黄色系
    static let lizard: [Color] = [
        Color(hex: "81C784"),  // 1: 浅绿（主体）
        Color(hex: "4CAF50"),  // 2: 中绿（阴影）
        Color(hex: "2E7D32"),  // 3: 深绿（轮廓）
        Color(hex: "FFF176"),  // 4: 黄色（腹部/点缀）
        Color(hex: "FFFFFF"),  // 5: 白色（眼睛高光）
        Color(hex: "2D2D2D"),  // 6: 深灰（眼睛）
    ]

    /// 爪印 - 粉色系（回退用）
    static let pawPrint: [Color] = [
        Color(hex: "FFB5C5"),  // 1: 浅粉（肉垫）
        Color(hex: "FF8FA3"),  // 2: 中粉（脚趾）
        Color(hex: "FF6B9D"),  // 3: 深粉（阴影）
    ]

    /// SF 风格 - 蓝色系
    static let sfBlue: [Color] = [
        Color(hex: "007AFF"),  // 1: 蓝色
        Color(hex: "0055CC"),  // 2: 深蓝
        Color(hex: "5AC8FA"),  // 3: 浅蓝
        Color(hex: "FFFFFF"),  // 4: 白色
        Color(hex: "8E8E93"),  // 5: 灰色
        Color(hex: "FF3B30"),  // 6: 红色
    ]
    
    /// SF 风格 - 灰色系
    static let sfGray: [Color] = [
        Color(hex: "8E8E93"),  // 1: 灰色
        Color(hex: "636366"),  // 2: 深灰
        Color(hex: "AEAEB2"),  // 3: 浅灰
        Color(hex: "FFFFFF"),  // 4: 白色
        Color(hex: "2D2D2D"),  // 5: 黑色
        Color(hex: "FF9500"),  // 6: 橙色
    ]
}

// MARK: - 像素动物图标数据 (16x16)

enum PixelAnimalData {
    
    // 🐰 兔子 - 粉色可爱风格
    static let rabbit: [[UInt8]] = [
        [0,0,0,0,0,3,3,0,0,0,3,3,0,0,0,0],
        [0,0,0,0,3,1,1,3,3,1,1,3,0,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,0,3,1,1,1,1,1,1,3,0,0,0,0],
        [0,0,0,0,0,5,4,1,1,5,4,0,0,0,0,0],
        [0,0,0,0,5,5,4,1,4,5,5,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,6,1,1,1,1,1,6,0,0,0,0,0],
        [0,0,0,0,6,6,1,1,1,6,6,0,0,0,0,0],
        [0,0,0,0,0,1,1,5,1,1,0,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]
    
    // 🦊 狐狸 - 橙色机灵风格
    static let fox: [[UInt8]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,5,5,0,0,5,5,0,0,0,0,0],
        [0,0,0,0,5,1,1,5,5,1,1,5,0,0,0,0],
        [0,0,0,5,1,1,1,1,1,1,1,1,5,0,0,0],
        [0,0,0,5,1,1,1,1,1,1,1,1,5,0,0,0],
        [0,0,0,0,5,1,1,1,1,1,1,5,0,0,0,0],
        [0,0,0,5,1,1,3,3,3,3,1,1,5,0,0,0],
        [0,0,5,1,1,3,3,4,4,3,3,1,1,5,0,0],
        [0,0,5,1,1,3,4,5,5,4,3,1,1,5,0,0],
        [0,0,0,5,1,1,3,3,3,3,1,1,5,0,0,0],
        [0,0,0,0,5,1,1,1,1,1,1,5,0,0,0,0],
        [0,0,0,0,0,5,1,1,1,1,5,0,0,0,0,0],
        [0,0,0,0,5,1,1,0,0,1,1,5,0,0,0,0],
        [0,0,0,5,1,0,0,0,0,0,0,1,5,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]
    
    // 🐱 猫咪 - 紫色优雅风格
    static let cat: [[UInt8]] = [
        [0,0,0,0,0,3,0,0,0,0,3,0,0,0,0,0],
        [0,0,0,0,3,1,3,0,0,3,1,3,0,0,0,0],
        [0,0,0,3,1,1,1,3,3,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,0,3,1,1,1,1,1,1,3,0,0,0,0],
        [0,0,0,0,5,4,1,1,1,5,4,0,0,0,0,0],
        [0,0,0,0,5,5,4,1,4,5,5,0,0,0,0,0],
        [0,0,0,0,0,1,1,6,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,1,1,0,0,0,0,0,1,1,0,0,0,0],
        [0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]
    
    // 🐻 小熊 - 棕色温暖风格
    static let bear: [[UInt8]] = [
        [0,0,0,0,0,3,0,0,0,0,3,0,0,0,0,0],
        [0,0,0,0,3,1,3,0,0,3,1,3,0,0,0,0],
        [0,0,0,3,1,1,1,3,3,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,0,3,1,1,1,1,1,1,3,0,0,0,0],
        [0,0,0,0,5,4,1,1,1,5,4,0,0,0,0,0],
        [0,0,0,0,5,5,4,1,4,5,5,0,0,0,0,0],
        [0,0,0,0,0,1,1,6,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,1,1,0,0,0,0,0,1,1,0,0,0,0],
        [0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]
    
    // 🐼 熊猫 - 黑白经典风格
    static let panda: [[UInt8]] = [
        [0,0,0,0,0,2,2,0,0,2,2,0,0,0,0,0],
        [0,0,0,0,2,1,1,2,2,1,1,2,0,0,0,0],
        [0,0,0,2,1,1,1,1,1,1,1,1,2,0,0,0],
        [0,0,0,2,1,2,2,1,1,2,2,1,2,0,0,0],
        [0,0,0,2,1,2,4,1,4,2,1,1,2,0,0,0],
        [0,0,0,2,1,2,2,2,2,2,1,1,2,0,0,0],
        [0,0,0,0,2,1,1,1,1,1,1,2,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,5,1,1,1,1,1,1,5,0,0,0,0],
        [0,0,0,0,5,5,1,1,1,1,5,5,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0],
        [0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]
    
    // 🦄 独角兽 - 彩虹梦幻风格
    static let unicorn: [[UInt8]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,3,3,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,3,3,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,8,7,6,5,4,0,0,0,0,0,0,0],
        [0,0,0,8,7,6,5,4,1,1,0,0,0,0,0,0],
        [0,0,8,7,6,5,4,1,1,1,1,0,0,0,0,0],
        [0,0,0,8,7,6,5,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,8,7,6,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,0,9,4,1,1,9,4,0,0,0,0,0],
        [0,0,0,0,0,9,9,1,1,9,9,0,0,0,0,0],
        [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    // 🐶 狗 - 金色忠诚风格
    static let dog: [[UInt8]] = [
        [0,0,0,0,0,3,0,0,0,0,3,0,0,0,0,0],
        [0,0,0,0,3,1,3,0,0,3,1,3,0,0,0,0],
        [0,0,0,3,1,1,1,3,3,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,0,3,1,1,1,1,1,1,3,0,0,0,0],
        [0,0,0,0,5,4,1,1,1,5,4,0,0,0,0,0],
        [0,0,0,0,5,5,4,1,4,5,5,0,0,0,0,0],
        [0,0,0,0,0,1,1,6,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,1,1,0,0,0,0,0,1,1,0,0,0,0],
        [0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    // 🐹 仓鼠 - 暖黄圆润风格
    static let hamster: [[UInt8]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,3,3,0,0,0,3,3,0,0,0,0,0],
        [0,0,0,3,1,1,3,3,3,1,1,3,0,0,0,0],
        [0,0,3,1,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,3,1,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,3,0,0,0,0],
        [0,0,0,0,5,4,1,1,1,5,4,0,0,0,0,0],
        [0,0,0,0,5,5,4,1,4,5,5,0,0,0,0,0],
        [0,0,0,0,0,6,1,1,1,6,0,0,0,0,0,0],
        [0,0,0,0,6,6,1,1,1,6,6,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    // 🐸 青蛙 - 绿色清爽风格
    static let frog: [[UInt8]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,3,0,0,0,0,0,0,0,3,0,0,0,0],
        [0,0,0,3,1,0,0,0,0,0,1,3,0,0,0,0],
        [0,0,3,1,1,3,0,0,0,3,1,1,3,0,0,0],
        [0,0,3,1,1,1,3,3,3,1,1,1,3,0,0,0],
        [0,0,3,1,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,3,0,0,0,0],
        [0,0,0,0,3,5,4,1,4,5,3,0,0,0,0,0],
        [0,0,0,0,0,5,5,4,5,5,0,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,6,1,1,1,1,1,6,0,0,0,0,0],
        [0,0,0,0,6,6,1,1,1,6,6,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    // 🐧 企鹅 - 黑白经典风格
    static let penguin: [[UInt8]] = [
        [0,0,0,0,0,1,1,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,0,1,1,5,4,1,4,5,1,1,1,0,0,0],
        [0,0,0,1,1,5,5,4,5,5,1,1,1,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
        [0,0,0,0,0,1,3,3,3,3,1,0,0,0,0,0],
        [0,0,0,0,0,3,3,3,3,3,3,0,0,0,0,0],
        [0,0,0,0,0,3,3,3,3,3,3,0,0,0,0,0],
        [0,0,0,0,0,3,3,3,3,3,3,0,0,0,0,0],
        [0,0,0,0,0,3,3,3,3,3,3,0,0,0,0,0],
        [0,0,0,0,0,1,3,3,3,3,1,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0],
        [0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    // 🦜 鹦鹉 - 彩色热带风格
    static let parrot: [[UInt8]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,3,0,0,0,0,3,0,0,0,0,0],
        [0,0,0,0,3,1,3,0,0,3,1,3,0,0,0,0],
        [0,0,0,3,1,1,1,3,3,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,0,5,4,1,1,1,5,4,0,0,0,0,0],
        [0,0,0,0,5,5,4,1,4,5,5,0,0,0,0,0],
        [0,0,0,0,0,6,1,1,1,6,0,0,0,0,0,0],
        [0,0,0,0,2,2,1,1,1,2,2,0,0,0,0,0],
        [0,0,0,2,2,2,1,1,1,2,2,2,0,0,0,0],
        [0,0,0,2,3,2,1,1,1,2,3,2,0,0,0,0],
        [0,0,0,0,2,2,1,1,1,2,2,0,0,0,0,0],
        [0,0,0,0,0,2,2,1,2,2,0,0,0,0,0,0],
        [0,0,0,0,0,0,2,1,2,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    // 🐢 乌龟 - 深绿沉稳风格
    static let turtle: [[UInt8]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,6,0,0,0,0,6,0,0,0,0,0],
        [0,0,0,0,6,1,6,0,0,6,1,6,0,0,0,0],
        [0,0,0,0,5,4,1,0,0,5,4,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
        [0,0,3,3,3,1,1,1,1,1,3,3,3,0,0,0],
        [0,3,2,3,2,1,1,1,1,1,2,3,2,3,0,0],
        [0,3,3,3,3,1,1,1,1,1,3,3,3,3,0,0],
        [0,0,3,3,3,1,1,1,1,1,3,3,3,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,6,1,0,0,0,1,6,0,0,0,0,0],
        [0,0,0,6,1,0,0,0,0,0,1,6,0,0,0,0],
        [0,0,0,6,0,0,0,0,0,0,0,6,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    // 🐟 鱼 - 蓝色灵动风格
    static let fish: [[UInt8]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,3,0,0,1,1,1,1,1,1,0,0,3,0,0],
        [0,3,1,3,0,1,1,1,1,1,1,0,3,1,3,0],
        [0,3,1,1,3,1,1,1,1,1,1,3,1,1,3,0],
        [0,0,3,1,1,1,1,1,1,1,1,1,1,3,0,0],
        [0,0,0,3,1,1,5,4,1,5,4,1,3,0,0,0],
        [0,0,0,0,3,1,5,5,4,5,5,3,0,0,0,0],
        [0,0,0,0,3,1,1,1,1,1,1,3,0,0,0,0],
        [0,0,0,3,1,6,1,1,1,1,6,1,3,0,0,0],
        [0,0,0,3,1,1,6,1,6,1,1,1,3,0,0,0],
        [0,0,0,0,3,1,1,1,1,1,1,3,0,0,0,0],
        [0,0,0,0,0,3,1,1,1,1,3,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    // 🦎 蜥蜴 - 绿色敏捷风格（正面视角）
    static let lizard: [[UInt8]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,3,0,0,0,0,3,0,0,0,0,0],
        [0,0,0,0,3,1,3,0,0,3,1,3,0,0,0,0],
        [0,0,0,3,1,1,1,3,3,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,3,1,1,1,1,1,1,1,1,3,0,0,0],
        [0,0,0,0,3,1,1,1,1,1,1,3,0,0,0,0],
        [0,0,0,0,5,4,1,1,1,5,4,0,0,0,0,0],
        [0,0,0,0,5,5,4,1,4,5,5,0,0,0,0,0],
        [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
        [0,0,0,0,4,1,1,1,1,1,4,0,0,0,0,0],
        [0,0,0,0,4,4,1,1,1,4,4,0,0,0,0,0],
        [0,0,0,0,0,1,1,0,1,1,0,0,0,0,0,0],
        [0,0,0,0,1,1,0,0,0,1,1,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    // 🐾 爪印 - 粉色通用回退
    static let pawPrint: [[UInt8]] = [
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,2,0,0,0,2,0,0,0,0,0,0],
        [0,0,0,0,2,1,2,0,2,1,2,0,0,0,0,0],
        [0,0,0,0,2,1,2,0,2,1,2,0,0,0,0,0],
        [0,0,0,0,0,2,0,0,0,2,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,2,2,2,2,2,2,2,2,2,2,0,0,0],
        [0,0,2,1,1,1,1,1,1,1,1,1,1,2,0,0],
        [0,2,1,1,1,1,1,1,1,1,1,1,1,1,2,0],
        [0,2,1,1,1,1,1,1,1,1,1,1,1,1,2,0],
        [0,2,1,1,1,1,1,1,1,1,1,1,1,1,2,0],
        [0,0,2,1,1,1,1,1,1,1,1,1,1,2,0,0],
        [0,0,0,2,2,2,2,2,2,2,2,2,2,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]
}

// MARK: - 像素 SF 符号图标数据 (12x12)

enum PixelSFData {
    
    // 📅 日历
    static let calendar: [[UInt8]] = [
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,1,1,1,1,1,1,1,1,1,1],
        [0,1,1,1,1,1,1,1,1,1,1,0],
    ]
    
    // 💬 对话气泡
    static let chatBubble: [[UInt8]] = [
        [0,0,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [1,1,4,4,4,4,4,4,4,4,1,1],
        [0,1,1,1,1,1,1,1,1,1,1,0],
        [0,0,1,1,1,1,1,1,0,1,0,0],
        [0,0,0,0,0,0,0,1,1,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0],
    ]
    
    // ⚡ 闪光
    static let sparkles: [[UInt8]] = [
        [0,0,0,0,0,1,0,0,0,0],
        [0,0,0,0,1,1,1,0,0,0],
        [0,0,0,1,1,1,1,1,0,0],
        [0,0,1,1,1,1,1,1,1,0],
        [0,1,1,1,1,0,1,1,1,1],
        [1,1,1,1,0,0,0,1,1,1],
        [0,1,1,1,1,0,1,1,1,1],
        [0,0,1,1,1,1,1,1,1,0],
        [0,0,0,1,1,1,1,1,0,0],
        [0,0,0,0,1,1,1,0,0,0],
    ]
    
    // ⚙️ 齿轮
    static let gear: [[UInt8]] = [
        [0,0,0,1,1,1,0,0,0],
        [0,1,1,1,0,1,1,1,0],
        [0,1,0,0,1,0,0,1,0],
        [1,1,0,1,1,1,0,1,1],
        [1,0,1,1,0,1,1,0,1],
        [1,1,0,1,1,1,0,1,1],
        [0,1,0,0,1,0,0,1,0],
        [0,1,1,1,0,1,1,1,0],
        [0,0,0,1,1,1,0,0,0],
    ]
    
    // ℹ️ 信息
    static let info: [[UInt8]] = [
        [0,0,0,1,1,1,0,0],
        [0,0,1,1,1,1,1,0],
        [0,0,1,1,1,1,1,0],
        [0,0,0,1,1,1,0,0],
        [0,0,0,1,1,1,0,0],
        [0,0,0,1,1,1,0,0],
        [0,0,0,1,1,1,0,0],
        [0,0,0,1,1,1,0,0],
        [0,1,1,1,1,1,1,0],
        [0,1,1,1,1,1,1,0],
    ]
    
    // ⏻ 电源
    static let power: [[UInt8]] = [
        [0,0,0,1,1,1,0,0,0],
        [0,0,1,1,0,1,1,0,0],
        [0,1,1,0,0,0,1,1,0],
        [0,1,1,0,0,0,1,1,0],
        [1,1,0,0,1,0,0,1,1],
        [1,1,0,0,1,0,0,1,1],
        [1,1,0,0,1,0,0,1,1],
        [0,1,1,0,0,0,1,1,0],
        [0,1,1,0,0,0,1,1,0],
        [0,0,1,1,1,1,1,0,0],
        [0,0,0,1,1,1,0,0,0],
    ]
}

// MARK: - 统一图标视图

/// 像素艺术图标视图 - 支持4种风格
struct PixelArtIconView: View {
    let function: FunctionButton
    let style: IconStyle
    let size: CGFloat
    
    @State private var isHovered = false
    
    var body: some View {
        Group {
            switch style {
            case .originalHattie:
                originalHattieView
            case .pixelAnimal:
                pixelAnimalView
            case .pixelSF:
                pixelSFView
            case .nativeSF:
                nativeSFView
            case .nativeEmoji:
                nativeEmojiView
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovered)
        .onHover { isHovered = $0 }
    }
    
    // MARK: - 原始 Hattie 视图
    
    /// Hattie 图标资源名映射
    private var hattieImageName: String {
        switch function {
        case .anniversary: return "hattie off"
        case .aiChat: return "hattie off"
        case .changelog: return "hattie off"
        case .settings: return "hattie off"
        case .about: return "hattie off"
        case .quit: return "hattie off"
        }
    }
    
    @ViewBuilder
    private var originalHattieView: some View {
        if let nsImage = NSImage(named: hattieImageName) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.none)
        } else {
            // 回退到像素动物
            pixelAnimalView
        }
    }
    
    // MARK: - 像素动物视图
    @ViewBuilder
    private var pixelAnimalView: some View {
        let (pixels, palette) = animalData
        Canvas { context, canvasSize in
            PixelArtRenderer.draw(context: context, size: canvasSize, pixels: pixels, palette: palette)
        }
    }
    
    private var animalData: ([[UInt8]], [Color]) {
        switch function {
        case .anniversary: return (PixelAnimalData.rabbit, PixelPalette.rabbit)
        case .aiChat: return (PixelAnimalData.fox, PixelPalette.fox)
        case .changelog: return (PixelAnimalData.cat, PixelPalette.cat)
        case .settings: return (PixelAnimalData.bear, PixelPalette.bear)
        case .about: return (PixelAnimalData.panda, PixelPalette.panda)
        case .quit: return (PixelAnimalData.unicorn, PixelPalette.unicorn)
        }
    }
    
    // MARK: - 像素 SF 视图
    @ViewBuilder
    private var pixelSFView: some View {
        let (pixels, palette) = sfData
        Canvas { context, canvasSize in
            PixelArtRenderer.draw(context: context, size: canvasSize, pixels: pixels, palette: palette)
        }
    }
    
    private var sfData: ([[UInt8]], [Color]) {
        switch function {
        case .anniversary: return (PixelSFData.calendar, PixelPalette.sfBlue)
        case .aiChat: return (PixelSFData.chatBubble, PixelPalette.sfBlue)
        case .changelog: return (PixelSFData.sparkles, PixelPalette.sfBlue)
        case .settings: return (PixelSFData.gear, PixelPalette.sfGray)
        case .about: return (PixelSFData.info, PixelPalette.sfGray)
        case .quit: return (PixelSFData.power, PixelPalette.sfGray)
        }
    }
    
    // MARK: - 原生 SF 视图
    private var nativeSFView: some View {
        let systemName: String
        let color: Color
        switch function {
        case .anniversary:
            systemName = "calendar.badge.plus"; color = .blue
        case .aiChat:
            systemName = "bubble.left.and.bubble.right"; color = .blue
        case .changelog:
            systemName = "sparkles"; color = .purple
        case .settings:
            systemName = "gearshape.fill"; color = .gray
        case .about:
            systemName = "info.circle.fill"; color = .gray
        case .quit:
            systemName = "power"; color = .red
        }
        return Image(systemName: systemName)
            .font(.system(size: size * 0.65))
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
    
    // MARK: - 原生 Emoji 视图
    private var nativeEmojiView: some View {
        let emoji: String
        switch function {
        case .anniversary: emoji = "🐰"
        case .aiChat: emoji = "🦊"
        case .changelog: emoji = "🐱"
        case .settings: emoji = "🐻"
        case .about: emoji = "🐼"
        case .quit: emoji = "🦄"
        }
        return Text(emoji)
            .font(.system(size: size * 0.75))
            .frame(width: size, height: size)
    }
}

// MARK: - 图标风格预览网格

struct IconStylePreviewGrid: View {
    @Binding var selectedStyle: IconStyle
    
    private let iconSize: CGFloat = 48
    
    var body: some View {
        VStack(spacing: 20) {
            ForEach(IconStyle.allCases) { style in
                VStack(alignment: .leading, spacing: 8) {
                    Text(style.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(FunctionButton.allCases) { button in
                            VStack(spacing: 4) {
                                PixelArtIconView(
                                    function: button,
                                    style: style,
                                    size: iconSize
                                )
                                Text(button.title)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if style != IconStyle.allCases.last {
                    Divider()
                }
            }
        }
        .padding(20)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            Text("YumikoToys 图标风格")
                .font(.title2.bold())
            
            IconStylePreviewGrid(selectedStyle: .constant(.pixelAnimal))
        }
        .frame(width: 500)
    }
}

// MARK: - NSImage 生成（用于状态栏图标）

extension IconStyle {
    /// 生成状态栏托盘图标（NSImage）
    /// - Parameter size: 图标尺寸
    /// - Returns: 渲染好的 NSImage
    func renderStatusBarIcon(size: CGFloat = 22) -> NSImage {
        switch self {
        case .originalHattie:
            // 使用原始 Hattie 资源图标
            if let image = NSImage(named: "hattie off") {
                image.size = NSSize(width: size, height: size)
                image.isTemplate = true
                return image
            }
            // 回退到像素兔子
            return PixelArtRenderer.renderNSImage(
                pixels: PixelAnimalData.rabbit,
                palette: PixelPalette.rabbit,
                size: size
            )
        case .pixelAnimal:
            return PixelArtRenderer.renderNSImage(
                pixels: PixelAnimalData.rabbit,
                palette: PixelPalette.rabbit,
                size: size
            )
        case .pixelSF:
            return PixelArtRenderer.renderNSImage(
                pixels: PixelSFData.calendar,
                palette: PixelPalette.sfBlue,
                size: size
            )
        case .nativeSF:
            return renderSystemIcon("heart.fill", size: size, color: NSColor.systemPink)
        case .nativeEmoji:
            return renderEmojiIcon("🐰", size: size)
        }
    }
    
    /// 渲染 SF Symbol 为 NSImage（适配深色/浅色模式）
    private func renderSystemIcon(_ name: String, size: CGFloat, color: NSColor) -> NSImage {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.75, weight: .medium)
        let configured = image.withSymbolConfiguration(config)!
        
        let finalImage = NSImage(size: NSSize(width: size, height: size))
        finalImage.lockFocus()
        
        // 根据系统外观选择颜色
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let adaptiveColor: NSColor
        if isDark {
            // 深色模式：使用更亮的颜色
            adaptiveColor = color.withSystemEffect(.pressed)
        } else {
            adaptiveColor = color
        }
        adaptiveColor.set()
        configured.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        finalImage.unlockFocus()
        
        // 设置为 template 模式，让系统自动适配外观变化
        finalImage.isTemplate = false  // 已手动适配颜色
        
        return finalImage
    }
    
    /// 渲染 Emoji 为 NSImage
    private func renderEmojiIcon(_ emoji: String, size: CGFloat) -> NSImage {
        let font = NSFont.systemFont(ofSize: size * 0.8)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attributedString = NSAttributedString(string: emoji, attributes: attributes)
        let stringSize = attributedString.size()
        
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let point = NSPoint(
            x: (size - stringSize.width) / 2,
            y: (size - stringSize.height) / 2
        )
        attributedString.draw(at: point)
        image.unlockFocus()
        return image
    }
}

extension PixelArtRenderer {
    /// 将像素数据渲染为 NSImage
    static func renderNSImage(
        pixels: [[UInt8]],
        palette: [Color],
        size: CGFloat
    ) -> NSImage {
        let rows = pixels.count
        guard rows > 0 else { return NSImage(size: NSSize(width: size, height: size)) }
        let cols = pixels[0].count
        let pixelW = size / CGFloat(cols)
        let pixelH = size / CGFloat(rows)
        
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        for (row, rowData) in pixels.enumerated() {
            for (col, colorIndex) in rowData.enumerated() where colorIndex > 0 {
                let color = palette[Int(colorIndex) - 1]
                let rect = CGRect(
                    x: CGFloat(col) * pixelW,
                    y: CGFloat(row) * pixelH,
                    width: pixelW + 0.5,
                    height: pixelH + 0.5
                )
                // 将 SwiftUI Color 转换为 NSColor
                let nsColor = NSColor(color)
                nsColor.setFill()
                context.fill(rect)
            }
        }
        
        image.unlockFocus()
        return image
    }
}
