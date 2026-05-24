//
//  PixelAvatarView.swift
//  YumikoToys
//
//  像素艺术头像组件 - Emoji → 像素数据映射 + Canvas 渲染
//

import SwiftUI

// MARK: - Emoji → 像素数据映射器

/// 将宠物 Emoji 映射到对应的 16×16 像素矩阵和调色板
enum PixelAvatarMapper {

    /// 所有支持的 Emoji 及其像素数据映射
    private static let mapping: [String: (pixels: [[UInt8]], palette: [Color])] = [
        // 已有 6 种（复用 PixelAnimalData + PixelPalette）
        "🐰": (PixelAnimalData.rabbit, PixelPalette.rabbit),
        "🐱": (PixelAnimalData.cat, PixelPalette.cat),
        "🦊": (PixelAnimalData.fox, PixelPalette.fox),
        "🐻": (PixelAnimalData.bear, PixelPalette.bear),
        "🐼": (PixelAnimalData.panda, PixelPalette.panda),
        "🦄": (PixelAnimalData.unicorn, PixelPalette.unicorn),
        // 新增 8 种
        "🐶": (PixelAnimalData.dog, PixelPalette.dog),
        "🐹": (PixelAnimalData.hamster, PixelPalette.hamster),
        "🐸": (PixelAnimalData.frog, PixelPalette.frog),
        "🐧": (PixelAnimalData.penguin, PixelPalette.penguin),
        "🦜": (PixelAnimalData.parrot, PixelPalette.parrot),
        "🐢": (PixelAnimalData.turtle, PixelPalette.turtle),
        "🐟": (PixelAnimalData.fish, PixelPalette.fish),
        "🦎": (PixelAnimalData.lizard, PixelPalette.lizard),
        "🐾": (PixelAnimalData.pawPrint, PixelPalette.pawPrint),
    ]

    /// 默认回退数据（爪印）
    private static let fallback: (pixels: [[UInt8]], palette: [Color]) = (
        PixelAnimalData.pawPrint, PixelPalette.pawPrint
    )

    /// 查找 Emoji 对应的像素数据
    /// - Parameter emoji: Emoji 字符串
    /// - Returns: (像素矩阵, 调色板)，未匹配时回退到爪印
    static func lookup(_ emoji: String) -> (pixels: [[UInt8]], palette: [Color]) {
        guard !emoji.isEmpty else { return fallback }
        return mapping[emoji] ?? fallback
    }
}

// MARK: - 像素头像视图

/// 像素艺术风格的宠物头像视图
/// 将 Emoji 实时转换为对应的像素艺术头像
struct PixelAvatarView: View {
    /// 头像对应的 Emoji
    let emoji: String
    /// 头像尺寸（正方形）
    let size: CGFloat

    /// 渐变背景色（默认粉→紫）
    var gradientColors: [Color] {
        [Color(hex: "FF6B9D"), Color(hex: "C44FE2")]
    }

    var body: some View {
        let avatarData = PixelAvatarMapper.lookup(emoji)

        ZStack {
            // 渐变圆形背景
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 像素图案
            Canvas { context, canvasSize in
                PixelArtRenderer.draw(
                    context: context,
                    size: canvasSize,
                    pixels: avatarData.pixels,
                    palette: avatarData.palette
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - 像素头像小型预览（用于 Emoji 选择器）

/// Emoji 选择器中的小型像素预览
struct PixelAvatarMiniPreview: View {
    let emoji: String
    let isSelected: Bool
    let size: CGFloat = 40

    var body: some View {
        let avatarData = PixelAvatarMapper.lookup(emoji)

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected
                        ? Color(hex: "FF6B9D").opacity(0.15)
                        : Color.clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected
                                ? Color(hex: "FF6B9D")
                                : Color.secondary.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

            Canvas { context, canvasSize in
                PixelArtRenderer.draw(
                    context: context,
                    size: canvasSize,
                    pixels: avatarData.pixels,
                    palette: avatarData.palette
                )
            }
            .frame(width: size - 8, height: size - 8)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("像素头像预览")
            .font(.title2.bold())

        HStack(spacing: 16) {
            ForEach(["🐰", "🐱", "🐶", "🐹", "🐻", "🐼", "🦊"], id: \.self) { emoji in
                VStack(spacing: 4) {
                    PixelAvatarView(emoji: emoji, size: 60)
                    Text(emoji)
                        .font(.caption)
                }
            }
        }

        HStack(spacing: 16) {
            ForEach(["🐸", "🐧", "🦜", "🐢", "🐟", "🦎", "🐾"], id: \.self) { emoji in
                VStack(spacing: 4) {
                    PixelAvatarView(emoji: emoji, size: 60)
                    Text(emoji)
                        .font(.caption)
                }
            }
        }

        Divider()

        Text("Emoji 选择器像素预览")
            .font(.headline)

        HStack(spacing: 8) {
            ForEach(["🐰", "🐱", "🐶", "🐹", "🐻", "🐼", "🦊", "🐸", "🐧", "🦜", "🐢", "🐟", "🦎", "🐾"], id: \.self) { emoji in
                PixelAvatarMiniPreview(emoji: emoji, isSelected: emoji == "🐰")
            }
        }
    }
    .padding()
    .frame(width: 600)
}
