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
    case animeHandDrawn = "animeHandDrawn" // 二次元手绘风（大尺寸界面用）
    case animePixel = "animePixel"         // 二次元像素风（小尺寸/状态栏用）
    case petBlue = "petBlue"               // 蓝兔桌宠
    case petGray = "petGray"               // 灰猫桌宠
    case petWhite = "petWhite"             // 白鼠桌宠
    case petTall = "petTall"               // 松鼠桌宠

    var id: String { rawValue }
    
    /// 是否仅用于状态栏图标（不影响界面中的图标）
    var isStatusBarOnly: Bool {
        switch self {
        case .originalHattie, .petBlue, .petGray, .petWhite, .petTall:
            return true
        default:
            return false
        }
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
        case .animeHandDrawn: return "✏️ 二次元手绘"
        case .animePixel: return "🎮 二次元像素"
        case .petBlue: return "桌宠浅蓝队员 (蓝兔)"
        case .petGray: return "桌宠深灰队员 (灰猫)"
        case .petWhite: return "桌宠白衣队员 (白鼠)"
        case .petTall: return "桌宠浅灰队员 (松鼠)"
        }
    }
    
    var description: String {
        switch self {
        case .originalHattie: return "原始 Hattie 手绘图标"
        case .pixelAnimal: return "像素风格绘制的可爱动物"
        case .pixelSF: return "像素风格重绘的 SF Symbols"
        case .nativeSF: return "系统原生 SF Symbols 图标"
        case .nativeEmoji: return "系统原生 Emoji 表情"
        case .animeHandDrawn: return "圆润线条手绘风格，二次元柔和美感"
        case .animePixel: return "精致像素风二次元图标，适合状态栏小尺寸"
        case .petBlue: return "桌宠浅蓝队员动态步行动画"
        case .petGray: return "桌宠深灰队员动态步行动画"
        case .petWhite: return "桌宠白衣队员动态步行动画"
        case .petTall: return "桌宠浅灰队员动态步行动画"
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
            case .animeHandDrawn:
                AnimeHandDrawnIcon(button: button, size: size, color: color)
            case .animePixel:
                AnimePixelIcon(button: button, size: size, color: color)
            case .petBlue, .petGray, .petWhite, .petTall:
                PixelAnimalIcon(button: button, size: size)
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

// MARK: - 二次元手绘风图标

/// 真正的手绘感：圆润笔触 + 微颤曲线 + 可爱装饰元素
struct AnimeHandDrawnIcon: View {
    let button: FunctionButton
    let size: CGFloat
    let color: Color

    /// 圆润笔触样式
    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: max(1.6, size * 0.065), lineCap: .round, lineJoin: .round)
    }

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let softFill = color.opacity(0.12)
            let midFill = color.opacity(0.35)

            switch button {
            case .anniversary:
                drawCalendar(context: &context, w: w, h: h, softFill: softFill, midFill: midFill)
            case .aiChat:
                drawChatBubble(context: &context, w: w, h: h, softFill: softFill, midFill: midFill)
            case .changelog:
                drawSparkle(context: &context, w: w, h: h, softFill: softFill, midFill: midFill)
            case .settings:
                drawGear(context: &context, w: w, h: h, softFill: softFill, midFill: midFill)
            case .about:
                drawInfo(context: &context, w: w, h: h, softFill: softFill, midFill: midFill)
            case .quit:
                drawPower(context: &context, w: w, h: h, softFill: softFill, midFill: midFill)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: 日历 — 圆润本体 + 爱心日期 + 小挂钩

    private func drawCalendar(context: inout GraphicsContext, w: CGFloat, h: CGFloat, softFill: Color, midFill: Color) {
        // 主体：超圆角矩形
        let bodyRect = CGRect(x: w*0.1, y: w*0.24, width: w*0.8, height: h*0.66)
        let bodyPath = Path(roundedRect: bodyRect, cornerRadius: w*0.16)
        context.fill(bodyPath, with: .color(softFill))
        context.stroke(bodyPath, with: .color(color), style: stroke)

        // 顶部分隔线（微弯手绘感）
        var divider = Path()
        divider.move(to: CGPoint(x: w*0.14, y: h*0.42))
        divider.addQuadCurve(to: CGPoint(x: w*0.86, y: h*0.42),
                             control: CGPoint(x: w*0.5, y: h*0.40))
        context.stroke(divider, with: .color(color.opacity(0.5)), style: stroke)

        // 两个圆润挂钩
        for xPos in [w*0.3, w*0.62] {
            let hook = Path(roundedRect: CGRect(x: xPos, y: w*0.1, width: w*0.09, height: h*0.22),
                            cornerRadius: w*0.045)
            context.fill(hook, with: .color(color.opacity(0.7)))
        }

        // 爱心日期标记（取代普通圆点）
        drawMiniHeart(context: &context, cx: w*0.32, cy: h*0.58, r: w*0.07, fill: midFill)
        drawMiniHeart(context: &context, cx: w*0.55, cy: h*0.58, r: w*0.07, fill: color.opacity(0.55))
        // 小圆点
        let dot = Path(ellipseIn: CGRect(x: w*0.72 - w*0.04, y: h*0.55, width: w*0.08, height: w*0.08))
        context.fill(dot, with: .color(color.opacity(0.3)))
        // 第二行小点
        for i in 0..<3 {
            let d = Path(ellipseIn: CGRect(x: w*(0.26 + Double(i)*0.2) - w*0.03, y: h*0.72, width: w*0.06, height: w*0.06))
            context.fill(d, with: .color(color.opacity(0.25)))
        }
    }

    // MARK: 对话气泡 — 圆润大泡 + 猫耳尾巴 + 表情点

    private func drawChatBubble(context: inout GraphicsContext, w: CGFloat, h: CGFloat, softFill: Color, midFill: Color) {
        // 主气泡（超大圆角）
        let bubbleRect = CGRect(x: w*0.06, y: h*0.06, width: w*0.88, height: h*0.62)
        let bubblePath = Path(roundedRect: bubbleRect, cornerRadius: w*0.22)
        context.fill(bubblePath, with: .color(softFill))
        context.stroke(bubblePath, with: .color(color), style: stroke)

        // 猫耳形尾巴（两条弧线汇合，比三角更可爱）
        var tail = Path()
        tail.move(to: CGPoint(x: w*0.22, y: h*0.66))
        tail.addQuadCurve(to: CGPoint(x: w*0.12, y: h*0.92),
                          control: CGPoint(x: w*0.08, y: h*0.8))
        tail.addQuadCurve(to: CGPoint(x: w*0.4, y: h*0.66),
                          control: CGPoint(x: w*0.3, y: h*0.82))
        context.fill(tail, with: .color(midFill))
        context.stroke(tail, with: .color(color), style: stroke)

        // 三个表情点（大小渐变，像正在输入）
        let dotSizes: [CGFloat] = [0.09, 0.11, 0.09]
        for (i, ds) in dotSizes.enumerated() {
            let dotR = w * ds
            let dot = Path(ellipseIn: CGRect(
                x: w*(0.28 + Double(i)*0.16) - dotR/2,
                y: h*0.34 - dotR/2,
                width: dotR, height: dotR))
            context.fill(dot, with: .color(color.opacity(0.4 + Double(i)*0.15)))
        }

        // 右上角小星星装饰
        drawMiniSparkle(context: &context, cx: w*0.82, cy: h*0.14, r: w*0.06, fill: color.opacity(0.5))
    }

    // MARK: 闪光 — 四角圆润星 + 小星尘

    private func drawSparkle(context: inout GraphicsContext, w: CGFloat, h: CGFloat, softFill: Color, midFill: Color) {
        let cx = w/2, cy = h/2
        // 主星：用 quad curve 画出内凹弧线（不是直线连接）
        let outerR = w * 0.42
        let innerR = w * 0.16
        var star = Path()
        let points = 4
        for i in 0..<(points * 2) {
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let r = i % 2 == 0 ? outerR : innerR
            let pt = CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r)
            if i == 0 {
                star.move(to: pt)
            } else {
                // 用弧线代替直线，产生内凹的圆润感
                let prevAngle = Double(i-1) * .pi / Double(points) - .pi / 2
                let prevR = (i-1) % 2 == 0 ? outerR : innerR
                let midAngle = (prevAngle + angle) / 2
                let bulge = (prevR + r) / 2 * 0.7
                let ctrl = CGPoint(x: cx + cos(midAngle) * bulge, y: cy + sin(midAngle) * bulge)
                star.addQuadCurve(to: pt, control: ctrl)
            }
        }
        star.closeSubpath()
        context.fill(star, with: .color(softFill))
        context.stroke(star, with: .color(color), style: stroke)

        // 中心小圆
        let coreR = w * 0.08
        let core = Path(ellipseIn: CGRect(x: cx - coreR, y: cy - coreR, width: coreR*2, height: coreR*2))
        context.fill(core, with: .color(midFill))

        // 周围小星尘
        drawMiniSparkle(context: &context, cx: w*0.78, cy: h*0.18, r: w*0.055, fill: color.opacity(0.5))
        drawMiniSparkle(context: &context, cx: w*0.2, cy: h*0.75, r: w*0.04, fill: color.opacity(0.35))
        let dot = Path(ellipseIn: CGRect(x: w*0.75, y: h*0.72, width: w*0.06, height: w*0.06))
        context.fill(dot, with: .color(color.opacity(0.3)))
    }

    // MARK: 齿轮 — 圆润花瓣形 + 中心爱心

    private func drawGear(context: inout GraphicsContext, w: CGFloat, h: CGFloat, softFill: Color, midFill: Color) {
        let cx = w/2, cy = h/2
        let outerR = w * 0.4
        let innerR = w * 0.28
        let teeth = 6

        // 花瓣形齿轮（用弧线连接，不是尖角）
        var gear = Path()
        for i in 0..<(teeth * 2) {
            let angle = Double(i) * .pi / Double(teeth) - .pi / 2
            let r = i % 2 == 0 ? outerR : innerR
            let pt = CGPoint(x: cx + cos(angle) * r, y: cy + sin(angle) * r)
            if i == 0 {
                gear.move(to: pt)
            } else {
                let prevAngle = Double(i-1) * .pi / Double(teeth) - .pi / 2
                let prevR = (i-1) % 2 == 0 ? outerR : innerR
                let midAngle = (prevAngle + angle) / 2
                let bulge = (prevR + r) / 2 * 1.08
                let ctrl = CGPoint(x: cx + cos(midAngle) * bulge, y: cy + sin(midAngle) * bulge)
                gear.addQuadCurve(to: pt, control: ctrl)
            }
        }
        gear.closeSubpath()
        context.fill(gear, with: .color(softFill))
        context.stroke(gear, with: .color(color), style: stroke)

        // 中心爱心（取代普通圆孔）
        drawMiniHeart(context: &context, cx: cx, cy: cy + w*0.02, r: w*0.1, fill: midFill)
    }

    // MARK: 信息 — 圆润圈 + 可爱 i（圆点+弯竖线）

    private func drawInfo(context: inout GraphicsContext, w: CGFloat, h: CGFloat, softFill: Color, midFill: Color) {
        let cx = w/2, cy = h/2
        let r = w * 0.4
        let circle = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r*2, height: r*2))
        context.fill(circle, with: .color(softFill))
        context.stroke(circle, with: .color(color), style: stroke)

        // i 的圆点
        let dotR = w * 0.065
        let dot = Path(ellipseIn: CGRect(x: cx - dotR, y: cy - r*0.52 - dotR, width: dotR*2, height: dotR*2))
        context.fill(dot, with: .color(color.opacity(0.8)))

        // i 的竖线（微弯，手绘感）
        var stem = Path()
        stem.move(to: CGPoint(x: cx, y: cy - r*0.18))
        stem.addQuadCurve(to: CGPoint(x: cx, y: cy + r*0.55),
                          control: CGPoint(x: cx + w*0.03, y: cy + r*0.2))
        context.stroke(stem, with: .color(color.opacity(0.8)),
                       style: StrokeStyle(lineWidth: max(1.8, w*0.08), lineCap: .round))

        // 小装饰点
        let sparkle = Path(ellipseIn: CGRect(x: w*0.72, y: h*0.2, width: w*0.06, height: w*0.06))
        context.fill(sparkle, with: .color(color.opacity(0.35)))
    }

    // MARK: 电源 — 圆润弧线 + 小爱心顶端

    private func drawPower(context: inout GraphicsContext, w: CGFloat, h: CGFloat, softFill: Color, midFill: Color) {
        let cx = w/2, cy = h*0.54
        let r = w * 0.34

        // 圆弧（开口朝上）
        var arc = Path()
        arc.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                   startAngle: .degrees(-55), endAngle: .degrees(235), clockwise: false)
        context.stroke(arc, with: .color(color),
                       style: StrokeStyle(lineWidth: max(2.0, w*0.08), lineCap: .round))

        // 竖线（圆润端头）
        var line = Path()
        line.move(to: CGPoint(x: cx, y: cy - r*1.15))
        line.addQuadCurve(to: CGPoint(x: cx, y: cy - r*0.3),
                          control: CGPoint(x: cx + w*0.02, y: cy - r*0.7))
        context.stroke(line, with: .color(color),
                       style: StrokeStyle(lineWidth: max(2.0, w*0.08), lineCap: .round))

        // 底部小爱心装饰
        drawMiniHeart(context: &context, cx: cx, cy: cy + r*0.5, r: w*0.06, fill: midFill)
    }

    // MARK: - 装饰元素绘制工具

    /// 迷你爱心
    private func drawMiniHeart(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, fill: Color) {
        var heart = Path()
        heart.move(to: CGPoint(x: cx, y: cy + r*0.7))
        heart.addQuadCurve(to: CGPoint(x: cx - r, y: cy - r*0.1),
                           control: CGPoint(x: cx - r*1.1, y: cy + r*0.5))
        heart.addQuadCurve(to: CGPoint(x: cx, y: cy - r*0.5),
                           control: CGPoint(x: cx - r*0.5, y: cy - r*0.9))
        heart.addQuadCurve(to: CGPoint(x: cx + r, y: cy - r*0.1),
                           control: CGPoint(x: cx + r*0.5, y: cy - r*0.9))
        heart.addQuadCurve(to: CGPoint(x: cx, y: cy + r*0.7),
                           control: CGPoint(x: cx + r*1.1, y: cy + r*0.5))
        heart.closeSubpath()
        context.fill(heart, with: .color(fill))
    }

    /// 迷你四角星（闪光）
    private func drawMiniSparkle(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, fill: Color) {
        var sparkle = Path()
        sparkle.move(to: CGPoint(x: cx, y: cy - r))
        sparkle.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + r*0.15, y: cy - r*0.15))
        sparkle.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx + r*0.15, y: cy + r*0.15))
        sparkle.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - r*0.15, y: cy + r*0.15))
        sparkle.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx - r*0.15, y: cy - r*0.15))
        sparkle.closeSubpath()
        context.fill(sparkle, with: .color(fill))
    }
}

// MARK: - 二次元像素风图标

/// 独立像素数据 + 双色渲染（主色+亮色内芯），与标准像素SF明显区分
struct AnimePixelIcon: View {
    let button: FunctionButton
    let size: CGFloat
    let color: Color

    var body: some View {
        Canvas { context, canvasSize in
            let pixelData = getPixelData()
            let rows = pixelData.count
            let cols = pixelData.first?.count ?? 0
            guard rows > 0, cols > 0 else { return }

            let pixelW = canvasSize.width / CGFloat(cols)
            let pixelH = canvasSize.height / CGFloat(rows)
            let px = min(pixelW, pixelH)
            let offsetX = (canvasSize.width - px * CGFloat(cols)) / 2
            let offsetY = (canvasSize.height - px * CGFloat(rows)) / 2

            for (row, pixels) in pixelData.enumerated() {
                for (col, value) in pixels.enumerated() where value > 0 {
                    let rect = CGRect(
                        x: offsetX + CGFloat(col) * px,
                        y: offsetY + CGFloat(row) * px,
                        width: px * 0.9,
                        height: px * 0.9
                    )
                    // 双色渲染：1=主色, 2=亮色内芯
                    let fillColor = value == 2 ? color.opacity(0.45) : color.opacity(0.88)
                    let path = Path(roundedRect: rect, cornerRadius: px * 0.22)
                    context.fill(path, with: .color(fillColor))
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func getPixelData() -> [[Int]] {
        switch button {
        case .anniversary: return AnimePixelData.calendar
        case .aiChat:      return AnimePixelData.chatBubble
        case .changelog:   return AnimePixelData.sparkle
        case .settings:    return AnimePixelData.gear
        case .about:       return AnimePixelData.info
        case .quit:        return AnimePixelData.power
        }
    }
}

// MARK: - 二次元专用像素数据（14x14 网格，0=空 1=主色 2=亮色内芯）

enum AnimePixelData {

    /// 日历 — 圆润外框 + 爱心标记
    static let calendar: [[Int]] = [
        [0,0,0,1,1,0,0,0,0,1,1,0,0,0],
        [0,0,0,1,1,0,0,0,0,1,1,0,0,0],
        [0,0,1,1,1,1,1,1,1,1,1,1,0,0],
        [0,1,1,2,2,2,2,2,2,2,2,1,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,1,1,2,2,1,1,2,2,1,0],
        [0,1,2,2,1,1,2,2,1,1,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,1,1,1,1,2,2,2,1,0],
        [0,1,2,2,1,1,1,1,1,1,2,2,1,0],
        [0,1,2,2,2,1,1,1,1,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,1,2,2,2,2,2,2,2,2,1,1,0],
        [0,0,1,1,1,1,1,1,1,1,1,1,0,0],
    ]

    /// 对话气泡 — 圆润泡体 + 猫耳尾巴 + 三点
    static let chatBubble: [[Int]] = [
        [0,0,0,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,1,2,2,2,2,2,2,2,2,1,0,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,1,2,2,1,2,2,1,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,0,1,2,2,2,2,2,2,2,2,1,0,0],
        [0,0,0,1,1,1,1,1,1,1,1,0,0,0],
        [0,0,1,2,1,0,0,0,0,0,0,0,0,0],
        [0,1,2,1,0,0,0,0,0,0,0,0,0,0],
        [0,1,1,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        [0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    ]

    /// 闪光 — 四角星 + 小星尘
    static let sparkle: [[Int]] = [
        [0,0,0,0,0,0,1,1,0,0,0,0,0,0],
        [0,0,0,0,0,1,2,2,1,0,0,0,0,0],
        [0,0,0,0,0,1,2,2,1,0,0,0,0,0],
        [0,0,0,0,1,2,2,2,2,1,0,0,0,0],
        [0,0,0,1,2,2,2,2,2,2,1,0,0,0],
        [0,1,1,2,2,2,2,2,2,2,2,1,1,0],
        [1,2,2,2,2,2,2,2,2,2,2,2,2,1],
        [1,2,2,2,2,2,2,2,2,2,2,2,2,1],
        [0,1,1,2,2,2,2,2,2,2,2,1,1,0],
        [0,0,0,1,2,2,2,2,2,2,1,0,0,0],
        [0,0,0,0,1,2,2,2,2,1,0,0,0,0],
        [0,0,0,0,0,1,2,2,1,0,0,0,0,0],
        [0,0,0,0,0,1,2,2,1,0,0,0,0,0],
        [0,0,0,0,0,0,1,1,0,0,0,0,0,0],
    ]

    /// 齿轮 — 花瓣形 + 爱心中心
    static let gear: [[Int]] = [
        [0,0,0,0,1,1,1,1,1,1,0,0,0,0],
        [0,0,1,1,2,2,2,2,2,2,1,1,0,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [1,2,2,2,2,1,1,1,1,2,2,2,2,1],
        [1,2,2,2,1,1,2,2,1,1,2,2,2,1],
        [1,2,2,2,1,2,2,2,2,1,2,2,2,1],
        [1,2,2,2,1,2,2,2,2,1,2,2,2,1],
        [1,2,2,2,1,1,2,2,1,1,2,2,2,1],
        [1,2,2,2,2,1,1,1,1,2,2,2,2,1],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,0,1,1,2,2,2,2,2,2,1,1,0,0],
        [0,0,0,0,1,1,1,1,1,1,0,0,0,0],
    ]

    /// 信息 — 圆润圈 + 可爱 i
    static let info: [[Int]] = [
        [0,0,0,0,1,1,1,1,1,1,0,0,0,0],
        [0,0,1,1,2,2,2,2,2,2,1,1,0,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,1,1,2,2,2,2,1,0],
        [0,1,2,2,2,2,1,1,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,1,1,2,2,2,2,1,0],
        [0,1,2,2,2,2,1,1,2,2,2,2,1,0],
        [0,1,2,2,2,2,1,1,2,2,2,2,1,0],
        [0,1,2,2,2,2,1,1,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,1,2,2,2,2,2,2,2,2,2,2,1,0],
        [0,0,1,1,2,2,2,2,2,2,1,1,0,0],
        [0,0,0,0,1,1,1,1,1,1,0,0,0,0],
    ]

    /// 电源 — 圆润弧线 + 竖线
    static let power: [[Int]] = [
        [0,0,0,0,0,1,1,1,1,0,0,0,0,0],
        [0,0,0,0,1,2,0,0,2,1,0,0,0,0],
        [0,0,0,1,2,0,0,0,0,2,1,0,0,0],
        [0,0,1,2,0,0,1,1,0,0,2,1,0,0],
        [0,0,1,2,0,0,1,1,0,0,2,1,0,0],
        [0,1,2,0,0,0,1,1,0,0,0,2,1,0],
        [0,1,2,0,0,0,1,1,0,0,0,2,1,0],
        [0,1,2,0,0,0,1,1,0,0,0,2,1,0],
        [0,1,2,0,0,0,1,1,0,0,0,2,1,0],
        [0,1,2,0,0,0,0,0,0,0,0,2,1,0],
        [0,0,1,2,0,0,0,0,0,0,2,1,0,0],
        [0,0,1,2,0,0,0,0,0,0,2,1,0,0],
        [0,0,0,1,2,0,0,0,0,2,1,0,0,0],
        [0,0,0,0,1,1,1,1,1,1,0,0,0,0],
    ]
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
