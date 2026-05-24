//
//  IconStyleSystem.swift
//  YumikoToys
//
//  多风格图标系统 - 支持4种风格
//

import SwiftUI

/// 图标风格类型
enum IconStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case originalHattie = "originalHattie" // 原始 Hattie 资源图标（仅状态栏）
    case pixelAnimal = "pixelAnimal"       // 像素风格绘制的可爱动物
    case pixelSF = "pixelSF"               // 像素风格重绘 SF Symbols
    case nativeSF = "nativeSF"             // 原生 SF Symbols
    case nativeEmoji = "nativeEmoji"       // 原生动物 Emoji
    
    var id: String { rawValue }
    
    /// 是否仅用于状态栏图标（不影响界面中的图标）
    var isStatusBarOnly: Bool {
        self == .originalHattie
    }
    
    /// 用于界面显示的风格列表（排除仅状态栏的风格）
    static var uiStyles: [IconStyle] {
        allCases.filter { !$0.isStatusBarOnly }
    }
    
    var displayName: String {
        switch self {
        case .originalHattie: return "🐰 Hattie"
        case .pixelAnimal: return "🐾 像素动物"
        case .pixelSF: return "🎨 像素 SF"
        case .nativeSF: return "🔣 原生 SF"
        case .nativeEmoji: return "😊 原生 Emoji"
        }
    }
    
    var description: String {
        switch self {
        case .originalHattie: return "原始 Hattie 手绘图标"
        case .pixelAnimal: return "像素风格绘制的可爱动物"
        case .pixelSF: return "像素风格重绘的 SF Symbols"
        case .nativeSF: return "系统原生 SF Symbols 图标"
        case .nativeEmoji: return "系统原生 Emoji 表情"
        }
    }
}

/// 功能按钮类型
enum FunctionButton: String, CaseIterable, Identifiable {
    case anniversary = "anniversary"   // 纪念日
    case aiChat = "aiChat"             // AI对话
    case changelog = "changelog"       // 更新日志
    case settings = "settings"         // 设置
    case about = "about"               // 关于
    case quit = "quit"                 // 退出
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .anniversary: return "纪念日"
        case .aiChat: return "AI对话"
        case .changelog: return "更新日志"
        case .settings: return "设置"
        case .about: return "关于"
        case .quit: return "退出"
        }
    }
    
    /// 侧边栏简短标题（2-3 字）
    var shortTitle: String {
        switch self {
        case .anniversary: return "纪念日"
        case .aiChat: return "红皇后AI"
        case .changelog: return "更新日志"
        case .settings: return "设置"
        case .about: return "关于"
        case .quit: return "退出"
        }
    }
    
    /// 映射到 MenuItemIdentifier
    var menuItemIdentifier: MenuItemIdentifier {
        switch self {
        case .anniversary: return .anniversaryManager
        case .aiChat: return .aiChat
        case .changelog: return .changelog
        case .settings: return .layoutManager
        case .about: return .about
        case .quit: return .quit
        }
    }
}

/// 图标提供者协议
protocol IconProvider {
    func icon(for button: FunctionButton, style: IconStyle, size: CGFloat) -> AnyView
}

/// 多风格图标视图
struct StyledIconView: View {
    let button: FunctionButton
    let style: IconStyle
    let size: CGFloat
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        Group {
            switch style {
            case .originalHattie:
                OriginalHattieIcon(button: button, size: size)
            case .pixelSF:
                PixelSFIcon(button: button, size: size, color: color)
            case .pixelAnimal:
                PixelAnimalIcon(button: button, size: size)
            case .nativeSF:
                NativeSFIcon(button: button, size: size, color: color)
            case .nativeEmoji:
                NativeEmojiIcon(button: button, size: size)
            }
        }
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - 原始 Hattie 图标

struct OriginalHattieIcon: View {
    let button: FunctionButton
    let size: CGFloat
    
    var body: some View {
        if let nsImage = NSImage(named: "hattie off") {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.none)
                .frame(width: size, height: size)
        } else {
            // 回退到像素动物
            PixelAnimalIcon(button: button, size: size)
        }
    }
}

// MARK: - 像素 SF Symbols

struct PixelSFIcon: View {
    let button: FunctionButton
    let size: CGFloat
    let color: Color
    
    var body: some View {
        Canvas { context, canvasSize in
            let pixelSize = canvasSize.width / 16
            let pixelData = getPixelData()
            
            for (row, pixels) in pixelData.enumerated() {
                for (col, isFilled) in pixels.enumerated() where isFilled {
                    let rect = CGRect(
                        x: CGFloat(col) * pixelSize,
                        y: CGFloat(row) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
    }
    
    private func getPixelData() -> [[Bool]] {
        switch button {
        case .anniversary:
            // 日历图标像素数据
            return PixelIconData.calendar
        case .aiChat:
            // 对话气泡像素数据
            return PixelIconData.chatBubble
        case .changelog:
            // 星星/闪光像素数据
            return PixelIconData.sparkles
        case .settings:
            // 齿轮像素数据
            return PixelIconData.gear
        case .about:
            // 信息图标像素数据
            return PixelIconData.info
        case .quit:
            // 电源图标像素数据
            return PixelIconData.power
        }
    }
}

// MARK: - 像素动物图标

struct PixelAnimalIcon: View {
    let button: FunctionButton
    let size: CGFloat
    
    var body: some View {
        let pixelIcon: PixelIcon
        switch button {
        case .anniversary: pixelIcon = .rabbit
        case .aiChat: pixelIcon = .fox
        case .changelog: pixelIcon = .cat
        case .settings: pixelIcon = .bear
        case .about: pixelIcon = .panda
        case .quit: pixelIcon = .unicorn
        }
        
        return PixelIconView(icon: pixelIcon, size: size)
    }
}

// MARK: - 原生 SF Symbols

struct NativeSFIcon: View {
    let button: FunctionButton
    let size: CGFloat
    let color: Color
    
    var body: some View {
        let systemName: String
        switch button {
        case .anniversary: systemName = "calendar.badge.plus"
        case .aiChat: systemName = "bubble.left.and.bubble.right"
        case .changelog: systemName = "sparkles"
        case .settings: systemName = "gearshape.fill"
        case .about: systemName = "info.circle.fill"
        case .quit: systemName = "power"
        }
        
        return Image(systemName: systemName)
            .font(.system(size: size * 0.7))
            .foregroundColor(color)
            .frame(width: size, height: size)
    }
}

// MARK: - 原生 Emoji

struct NativeEmojiIcon: View {
    let button: FunctionButton
    let size: CGFloat
    
    var body: some View {
        let emoji: String
        switch button {
        case .anniversary: emoji = "🐰"
        case .aiChat: emoji = "🦊"
        case .changelog: emoji = "🐱"
        case .settings: emoji = "🐻"
        case .about: emoji = "🐼"
        case .quit: emoji = "🦄"
        }
        
        return Text(emoji)
            .font(.system(size: size * 0.8))
            .frame(width: size, height: size)
    }
}

// MARK: - 像素图标数据

enum PixelIconData {
    // 日历图标
    static let calendar: [[Bool]] = [
        [false, false, true, true, true, true, true, true, true, true, false, false],
        [false, true, true, false, false, false, false, false, false, true, true, false],
        [true, true, false, false, false, false, false, false, false, false, true, true],
        [true, false, false, true, true, false, false, true, true, false, false, true],
        [true, false, false, true, true, false, false, true, true, false, false, true],
        [true, false, false, false, false, false, false, false, false, false, false, true],
        [true, false, false, false, false, false, false, false, false, false, false, true],
        [true, false, false, true, true, false, false, true, true, false, false, true],
        [true, false, false, true, true, false, false, true, true, false, false, true],
        [true, false, false, false, false, false, false, false, false, false, false, true],
        [true, true, false, false, false, false, false, false, false, false, true, true],
        [false, true, true, true, true, true, true, true, true, true, true, false]
    ]
    
    // 对话气泡
    static let chatBubble: [[Bool]] = [
        [false, false, true, true, true, true, true, true, true, true, false, false],
        [false, true, true, false, false, false, false, false, false, true, true, false],
        [true, true, false, false, false, false, false, false, false, false, true, true],
        [true, false, false, false, false, false, false, false, false, false, false, true],
        [true, false, false, false, false, false, false, false, false, false, false, true],
        [true, false, false, false, false, false, false, false, false, false, false, true],
        [true, false, false, false, false, false, false, false, false, false, false, true],
        [true, true, false, false, false, false, false, false, false, false, true, true],
        [false, true, true, true, true, true, true, true, true, true, true, false],
        [false, false, true, true, true, true, true, true, false, true, false, false],
        [false, false, false, false, false, false, false, true, true, false, false, false]
    ]
    
    // 闪光/星星
    static let sparkles: [[Bool]] = [
        [false, false, false, false, false, true, false, false, false, false],
        [false, false, false, false, true, true, true, false, false, false],
        [false, false, false, true, true, true, true, true, false, false],
        [false, false, true, true, true, true, true, true, true, false],
        [false, true, true, true, true, false, true, true, true, true],
        [true, true, true, true, false, false, false, true, true, true],
        [false, true, true, true, true, false, true, true, true, true],
        [false, false, true, true, true, true, true, true, true, false],
        [false, false, false, true, true, true, true, true, false, false],
        [false, false, false, false, true, true, true, false, false, false],
        [false, false, false, false, false, true, false, false, false, false]
    ]
    
    // 齿轮
    static let gear: [[Bool]] = [
        [false, false, false, true, true, true, false, false, false],
        [false, true, true, true, false, true, true, true, false],
        [false, true, false, false, true, false, false, true, false],
        [true, true, false, true, true, true, false, true, true],
        [true, false, true, true, false, true, true, false, true],
        [true, false, true, true, false, true, true, false, true],
        [true, true, false, true, true, true, false, true, true],
        [false, true, false, false, true, false, false, true, false],
        [false, true, true, true, false, true, true, true, false],
        [false, false, false, true, true, true, false, false, false]
    ]
    
    // 信息图标
    static let info: [[Bool]] = [
        [false, false, true, true, true, false, false],
        [false, true, true, false, true, true, false],
        [false, true, true, false, true, true, false],
        [false, false, true, true, true, false, false],
        [false, false, true, true, true, false, false],
        [false, false, true, true, true, false, false],
        [false, false, true, true, true, false, false],
        [false, false, true, true, true, false, false],
        [false, true, true, true, true, true, false],
        [false, true, true, true, true, true, false]
    ]
    
    // 电源图标
    static let power: [[Bool]] = [
        [false, false, false, true, true, true, false, false, false],
        [false, false, true, true, false, true, true, false, false],
        [false, true, true, false, false, false, true, true, false],
        [false, true, true, false, false, false, true, true, false],
        [true, true, false, false, true, false, false, true, true],
        [true, true, false, false, true, false, false, true, true],
        [true, true, false, false, true, false, false, true, true],
        [true, true, false, false, true, false, false, true, true],
        [false, true, true, false, false, false, true, true, false],
        [false, true, true, false, false, false, true, true, false],
        [false, false, true, true, true, true, true, false, false],
        [false, false, false, true, true, true, false, false, false]
    ]
}

// MARK: - 图标风格选择器

struct IconStylePicker: View {
    @Binding var selectedStyle: IconStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("图标风格")
                .font(.headline)
            
            ForEach(IconStyle.allCases) { style in
                IconStyleRow(
                    style: style,
                    isSelected: selectedStyle == style,
                    action: { selectedStyle = style }
                )
            }
        }
    }
}

struct IconStyleRow: View {
    let style: IconStyle
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 预览图标
                HStack(spacing: 4) {
                    StyledIconView(
                        button: .anniversary,
                        style: style,
                        size: 24,
                        color: .pink
                    )
                    StyledIconView(
                        button: .aiChat,
                        style: style,
                        size: 24,
                        color: .orange
                    )
                }
                .frame(width: 60)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                        .font(.system(size: 14, weight: .medium))
                    Text(style.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    VStack(spacing: 20) {
        // 图标预览
        HStack(spacing: 16) {
            ForEach(IconStyle.allCases, id: \.self) { style in
                VStack(spacing: 8) {
                    StyledIconView(
                        button: .anniversary,
                        style: style,
                        size: 40,
                        color: .pink
                    )
                    Text(style.displayName)
                        .font(.caption)
                }
            }
        }
        
        Divider()
        
        // 风格选择器
        IconStylePicker(selectedStyle: .constant(.pixelSF))
    }
    .padding()
}
