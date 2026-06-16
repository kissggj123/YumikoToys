//
//  ScreenshotAnnotationModule.swift
//  YumikoToys
//
//  真·截图标注模块
//  - 像素化 / 模糊：基于 CIImage 渲染（真像素化/高斯模糊，而非灰色方块）
//  - 文字：原生 NSTextField 弹窗编辑、拖动重定位、按回车保存、可编辑字号/颜色/背景
//  - 撤销 / 重做：完整的 Undo/Redo 栈
//
//  设计思路：
//  1. 在屏幕显示层（SwiftUI Canvas）使用预先渲染的“马赛克/模糊版 NSImage”
//     作为背景，利用 context 以“源区域覆盖”的方式显示真像素化效果（与 Snipaste 一致）。
//  2. 在导出层直接调用 MosaicRenderer 对原图（像素坐标系）做同样处理，再叠加矢量标注。
//  3. 所有用户交互（拖动、文字编辑）通过 ViewModel 的 @Published 状态驱动。
//

import Foundation
import AppKit
import SwiftUI
import CoreImage

// MARK: - ViewModel

@MainActor
final class ScreenshotAnnotationViewModel: ObservableObject {
    let image: NSImage
    let imagePath: String

    @Published var paths: [AnnotationPath] = []
    @Published var currentPath: AnnotationPath?
    @Published var selectedPathId: UUID?

    @Published var tool: AnnotationTool = .mosaicPixel
    @Published var strokeWidth: CGFloat = 8
    @Published var annotationColor: Color = .red

    @Published var showTextInput = false
    @Published var textInputContent = ""
    @Published var textInputPosition: CGPoint = .zero
    @Published var editingTextId: UUID?

    @Published var lastDragLocation: CGPoint = .zero
    @Published var numberCounter: Int = 1

    // 用于 Canvas 内绘制马赛克效果的“预览版图像”
    private(set) var mosaicPreview: MosaicPreview
    private let mosaicRenderer = MosaicRenderer()

    // 撤销栈（数组。每次路径变更 push 一次）
    private var undoStack: [[AnnotationPath]] = []
    private var redoStack: [[AnnotationPath]] = []

    init(image: NSImage, imagePath: String) {
        self.image = image
        self.imagePath = imagePath
        self.mosaicPreview = MosaicPreview(base: image, renderer: mosaicRenderer)
    }

    // MARK: - 撤销 / 重做

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func snapshotForUndo() {
        undoStack.append(paths)
        redoStack.removeAll()
    }

    func undo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(paths)
        paths = undoStack.removeLast()
    }

    func redo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(paths)
        paths = redoStack.removeLast()
    }

    // MARK: - 路径变更

    func addPath(_ path: AnnotationPath) {
        snapshotForUndo()
        paths.append(path)
    }

    func updatePath(with id: UUID, mutate: (inout AnnotationPath) -> Void) {
        guard let idx = paths.firstIndex(where: { $0.id == id }) else { return }
        snapshotForUndo()
        mutate(&paths[idx])
    }

    func removePath(with id: UUID) {
        snapshotForUndo()
        paths.removeAll { $0.id == id }
        if selectedPathId == id { selectedPathId = nil }
    }

    // MARK: - 文字编辑

    func beginCreateText(at point: CGPoint) {
        editingTextId = nil
        textInputContent = ""
        textInputPosition = point
        showTextInput = true
    }

    func beginEditText(_ path: AnnotationPath) {
        editingTextId = path.id
        textInputContent = path.text ?? ""
        showTextInput = true
    }

    func commitText() {
        defer { showTextInput = false }
        guard !textInputContent.isEmpty else { return }
        if let editId = editingTextId {
            updatePath(with: editId) { $0.text = self.textInputContent }
        } else {
            addPath(
                AnnotationPath(
                    tool: .text,
                    points: [textInputPosition],
                    color: annotationColor,
                    width: strokeWidth,
                    text: textInputContent
                )
            )
        }
    }

    // MARK: - 图像渲染（导出全分辨率）

    func renderAnnotatedImage() -> NSImage {
        // 1. 以像素尺寸为基底输出（保持 Retina 原分辨率）
        let pixelsWide: Int
        let pixelsHigh: Int
        if let rep = image.representations.first as? NSBitmapImageRep {
            pixelsWide = rep.pixelsWide
            pixelsHigh = rep.pixelsHigh
        } else {
            pixelsWide = Int(image.size.width)
            pixelsHigh = Int(image.size.height)
        }
        let pixelSize = NSSize(width: pixelsWide, height: pixelsHigh)

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        var current = NSImage(cgImage: cgImage, size: pixelSize)

        // 2. 收集所有马赛克标注区域（以图像像素坐标），逐个应用
        let displayToPixelScale: CGFloat = pixelSize.width / canvasSize.width  // canvasSize 是显示尺寸
        let canvasH = canvasSize.height
        let imgH = pixelSize.height

        for path in paths {
            switch path.tool {
            case .mosaicPixel, .mosaicBlur:
                guard let r = path.rect, r.width > 0, r.height > 0 else { continue }
                let imgRect = NSRect(
                    x:      r.minX      * displayToPixelScale,
                    y:      (canvasH - r.maxY) * displayToPixelScale,
                    width:  r.width     * displayToPixelScale,
                    height: r.height    * displayToPixelScale
                )
                let tool: MosaicTool = path.tool == .mosaicPixel
                    ? .pixelate(blockSize: max(6, path.width * displayToPixelScale))
                    : .blur(radius: max(2, path.width * 0.5 * displayToPixelScale))
                current = mosaicRenderer.apply(tool, rect: imgRect, to: current)

            default:
                // 矢量/文字标注：在“像素坐标位图”上绘制
                break
            }
        }

        // 3. 在输出图像上叠加矢量 / 文字
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return current }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        current.draw(in: NSRect(origin: .zero, size: pixelSize))

        for path in paths {
            drawVectorPath(path, displayToPixelScale: displayToPixelScale, canvasHeight: canvasH, imageHeight: imgH)
        }

        NSGraphicsContext.restoreGraphicsState()
        let result = NSImage(size: pixelSize)
        result.addRepresentation(bitmap)
        return result
    }

    private func drawVectorPath(_ path: AnnotationPath, displayToPixelScale s: CGFloat, canvasHeight ch: CGFloat, imageHeight ih: CGFloat) {
        func toImage(_ p: CGPoint) -> NSPoint {
            NSPoint(x: p.x * s, y: ih - p.y * s)
        }
        func toImageRect(_ r: CGRect) -> NSRect {
            NSRect(
                x: r.minX * s,
                y: (ch - r.maxY) * s,
                width: r.width * s,
                height: r.height * s
            )
        }
        let nsColor = NSColor(path.color)

        switch path.tool {
        case .frame:
            guard let r = path.rect else { break }
            nsColor.setStroke()
            let bp = NSBezierPath(rect: toImageRect(r))
            bp.lineWidth = path.width * s
            bp.stroke()

        case .circle:
            guard let r = path.rect else { break }
            nsColor.setStroke()
            let bp = NSBezierPath(ovalIn: toImageRect(r))
            bp.lineWidth = path.width * s
            bp.stroke()

        case .line:
            guard path.points.count > 1 else { break }
            nsColor.setStroke()
            let bp = NSBezierPath()
            bp.move(to: toImage(path.points[0]))
            for pt in path.points.dropFirst() { bp.line(to: toImage(pt)) }
            bp.lineWidth = path.width * s
            bp.lineCapStyle = .round
            bp.stroke()

        case .arrow:
            guard let start = path.points.first, let end = path.points.last else { break }
            nsColor.setStroke()
            let startPt = toImage(start)
            let endPt = toImage(end)
            let bp = NSBezierPath()
            bp.move(to: startPt)
            bp.line(to: endPt)
            bp.lineWidth = path.width * s
            bp.lineCapStyle = .round
            bp.stroke()

            let angle = atan2(endPt.y - startPt.y, endPt.x - startPt.x)
            let headLen = max(16, path.width * 2) * s
            let headAng: CGFloat = .pi / 6
            let p1 = NSPoint(
                x: endPt.x - headLen * cos(angle - headAng),
                y: endPt.y - headLen * sin(angle - headAng)
            )
            let p2 = NSPoint(
                x: endPt.x - headLen * cos(angle + headAng),
                y: endPt.y - headLen * sin(angle + headAng)
            )
            let head = NSBezierPath()
            head.move(to: p1)
            head.line(to: endPt)
            head.line(to: p2)
            head.lineWidth = path.width * s
            head.stroke()

        case .text:
            guard let text = path.text, let pt = path.points.first else { break }
            let fontSize = path.width * 3 * s
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(6, fontSize), weight: .semibold),
                .foregroundColor: nsColor
            ]
            let textSize = (text as NSString).size(withAttributes: attrs)
            let offsetX = path.offset.width * s
            let offsetY = path.offset.height * s

            let ip = toImage(pt)
            // 在 Canvas 中 y 向下为正；文字绘制 origin 在左下。
            let textOrigin = NSPoint(x: ip.x + offsetX, y: ip.y - offsetY - textSize.height)
            let bgRect = NSRect(
                x: textOrigin.x - 4,
                y: textOrigin.y - 2,
                width: textSize.width + 8,
                height: textSize.height + 4
            )
            NSColor(white: 0, alpha: 0.65).setFill()
            NSBezierPath(roundedRect: bgRect, xRadius: 4, yRadius: 4).fill()
            NSAttributedString(string: text, attributes: attrs).draw(at: textOrigin)

        case .number:
            guard let pt = path.points.first else { break }
            let radius: CGFloat = 12 * s
            let ip = toImage(pt)
            let center = NSPoint(x: ip.x, y: ip.y)
            let circleRect = NSRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            nsColor.setFill()
            NSBezierPath(ovalIn: circleRect).fill()

            let text = path.text ?? "\(path.numberIndex)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(8, 13 * s), weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let numSize = (text as NSString).size(withAttributes: attrs)
            (text as NSString).draw(
                at: NSPoint(x: center.x - numSize.width / 2, y: center.y - numSize.height / 2),
                withAttributes: attrs
            )

        case .mosaicPixel, .mosaicBlur:
            // 已在像素层完成，此处不重复处理
            break
        }
    }

    // Canvas 显示尺寸（用于坐标转换）
    var canvasSize: CGSize = .zero
}

// MARK: - Mosaic Preview（画布层真马赛克/模糊预览）

/// 在 Canvas 层把像素化/模糊效果作为“图案”真实地显示出来：
///  - 将原图预先缩放到 Canvas 显示尺寸
///  - 对每个 mosaic 矩形单独应用滤镜，得到小图 NSImage
///  - Canvas 绘制时把处理后的 NSImage 贴到对应矩形
@MainActor
final class MosaicPreview {
    private let base: NSImage
    private let renderer: MosaicRenderer
    private var displaySize: CGSize = .zero
    private var cached: NSImage?  // 缩放至 displaySize 的预览图

    init(base: NSImage, renderer: MosaicRenderer) {
        self.base = base
        self.renderer = renderer
    }

    func setDisplaySize(_ size: CGSize) {
        guard size != displaySize else { return }
        displaySize = size
        guard size.width > 0, size.height > 0 else { cached = nil; return }
        // 把原图缩放到 displaySize，用于 canvas 层马赛克预览的“源像素”
        let new = NSImage(size: size)
        new.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: size), from: NSRect(origin: .zero, size: base.size), operation: .copy, fraction: 1.0)
        new.unlockFocus()
        cached = new
    }

    /// 在 canvas 坐标的 rect 中应用马赛克/模糊效果并返回贴到 canvas 上的小图
    func renderTile(tool: MosaicTool, rect: CGRect) -> NSImage? {
        guard let source = cached else { return nil }
        guard rect.width > 2, rect.height > 2 else { return nil }
        // NSImage 坐标系：左下为原点
        let srcRect = NSRect(
            x: rect.minX,
            y: displaySize.height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        // 从源图剪切
        let tile = NSImage(size: srcRect.size)
        tile.lockFocus()
        source.draw(
            in: NSRect(origin: .zero, size: srcRect.size),
            from: srcRect,
            operation: .copy,
            fraction: 1.0
        )
        tile.unlockFocus()
        // 应用滤镜（以像素坐标）
        let pixelRect = NSRect(origin: .zero, size: srcRect.size)
        return renderer.apply(tool, rect: pixelRect, to: tile)
    }
}

// MARK: - 数据结构

enum AnnotationTool: String, CaseIterable, Sendable {
    case mosaicPixel = "mosaicPixel"
    case mosaicBlur  = "mosaicBlur"
    case frame       = "frame"
    case circle      = "circle"
    case line        = "line"
    case arrow       = "arrow"
    case text        = "text"
    case number      = "number"

    var displayName: String {
        switch self {
        case .mosaicPixel: return "像素化"
        case .mosaicBlur:  return "模糊"
        case .frame:       return "画框"
        case .circle:      return "圆圈"
        case .line:        return "画线"
        case .arrow:       return "箭头"
        case .text:        return "文字"
        case .number:      return "编号"
        }
    }

    var icon: String {
        switch self {
        case .mosaicPixel: return "squareshape.split.3x3"
        case .mosaicBlur:  return "aqi.medium"
        case .frame:       return "rectangle"
        case .circle:      return "circle"
        case .line:        return "pencil"
        case .arrow:       return "arrow.up.forward"
        case .text:        return "textformat"
        case .number:      return "number"
        }
    }

    var isMosaic: Bool {
        self == .mosaicPixel || self == .mosaicBlur
    }

    var isFreehand: Bool {  // 跟随鼠标轨迹
        self == .line
    }
}

struct AnnotationPath: Identifiable {
    let id = UUID()
    var tool: AnnotationTool
    var points: [CGPoint]
    var rect: CGRect?
    var color: Color
    var width: CGFloat
    var text: String?
    var offset: CGSize = .zero
    var isSelected: Bool = false
    var numberIndex: Int = 0
}

// MARK: - 标注视图

struct ScreenshotAnnotationView: View {
    @StateObject private var vm: ScreenshotAnnotationViewModel
    let onSave: (String) -> Void

    init(image: NSImage, imagePath: String, onSave: @escaping (String) -> Void) {
        self.onSave = onSave
        _vm = StateObject(
            wrappedValue: ScreenshotAnnotationViewModel(image: image, imagePath: imagePath)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            canvasRegion
        }
        .frame(minWidth: 720, minHeight: 480)
        .sheet(isPresented: $vm.showTextInput) { textEditorSheet }
        .onChange(of: vm.selectedPathId) { _, _ in }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            ForEach(AnnotationTool.allCases, id: \.self) { t in
                Button(action: { vm.tool = t; vm.selectedPathId = nil }) {
                    VStack(spacing: 2) {
                        Image(systemName: t.icon).font(.system(size: 14))
                        Text(t.displayName).font(.system(size: 9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(vm.tool == t ? Color.accentColor : Color.gray.opacity(0.15))
                    )
                    .foregroundStyle(vm.tool == t ? .white : .primary)
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 24)

            ColorPicker("", selection: $vm.annotationColor)
                .frame(width: 28, height: 28)
                .help("选择颜色")

            Divider().frame(height: 24)

            HStack(spacing: 4) {
                Text("笔刷").font(.system(size: 10))
                Slider(value: $vm.strokeWidth, in: 2...40).frame(width: 110)
                Text(String(format: "%.0f", vm.strokeWidth))
                    .font(.system(size: 10, design: .monospaced))
            }

            Spacer()

            if vm.selectedPathId != nil {
                Button("删除") {
                    if let id = vm.selectedPathId { vm.removePath(with: id) }
                }
                .font(.system(size: 10)).buttonStyle(.bordered).tint(.red)
            }

            Button("撤销") { vm.undo() }
                .font(.system(size: 10)).buttonStyle(.bordered).disabled(!vm.canUndo)
            Button("重做") { vm.redo() }
                .font(.system(size: 10)).buttonStyle(.bordered).disabled(!vm.canRedo)

            Button("保存") { saveAnnotatedImage() }
                .font(.system(size: 10, weight: .medium)).buttonStyle(.borderedProminent)
            Button("复制") { copyToClipboard() }
                .font(.system(size: 10)).buttonStyle(.bordered)
            Button(action: pinToScreen) {
                HStack(spacing: 3) {
                    Image(systemName: "pin.fill").font(.system(size: 9))
                    Text("置顶").font(.system(size: 10))
                }
            }.buttonStyle(.bordered)
        }
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Canvas Region

    private var canvasRegion: some View {
        GeometryReader { geo in
            let canvas = fitSize(imageSize: vm.image.size, to: geo.size)
            let offset = CGPoint(
                x: (geo.size.width  - canvas.width)  / 2,
                y: (geo.size.height - canvas.height) / 2
            )

            ZStack {
                Color(nsColor: .controlBackgroundColor)

                Image(nsImage: vm.image)
                    .resizable()
                    .frame(width: canvas.width, height: canvas.height)
                    .position(x: offset.x + canvas.width  / 2,
                              y: offset.y + canvas.height / 2)

                // 矢量 / 马赛克 / 文字
                AnnotationCanvas(
                    vm: vm,
                    size: canvas,
                    onStartDrag: startDrag,
                    onDragMoved: dragMoved,
                    onDragEnded: dragEnded,
                    onTapAt: tapAt
                )
                .frame(width: canvas.width, height: canvas.height)
                .position(x: offset.x + canvas.width  / 2,
                          y: offset.y + canvas.height / 2)
            }
            .onAppear { vm.canvasSize = canvas; vm.mosaicPreview.setDisplaySize(canvas) }
            .onChange(of: canvas) { _, newSize in
                vm.canvasSize = newSize
                vm.mosaicPreview.setDisplaySize(newSize)
            }
        }
    }

    // MARK: 文字编辑 sheet

    private var textEditorSheet: some View {
        VStack(spacing: 16) {
            Text(vm.editingTextId != nil ? "编辑标注文字" : "输入标注文字").font(.headline)
            TextField("文字内容", text: $vm.textInputContent)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)
            HStack {
                Button("取消") { vm.showTextInput = false }
                Button("确定") { vm.commitText() }
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(width: 440, height: 200)
    }

    // MARK: 交互

    private func startDrag(at pt: CGPoint) {
        switch vm.tool {
        case .text, .number:
            return  // 由 tap 处理
        default:
            vm.currentPath = AnnotationPath(
                tool: vm.tool,
                points: [pt],
                rect: nil,
                color: vm.tool.isMosaic ? .gray : vm.annotationColor,
                width: vm.strokeWidth
            )
        }
    }

    private func dragMoved(to pt: CGPoint) {
        guard var current = vm.currentPath else { return }
        current.points.append(pt)
        if vm.tool != .line, let start = current.points.first {
            current.rect = CGRect(
                x: min(start.x, pt.x), y: min(start.y, pt.y),
                width: abs(pt.x - start.x), height: abs(pt.y - start.y)
            )
        }
        vm.currentPath = current
    }

    private func dragEnded(at pt: CGPoint) {
        guard var current = vm.currentPath else { return }
        if let start = current.points.first, vm.tool != .line {
            current.rect = CGRect(
                x: min(start.x, pt.x), y: min(start.y, pt.y),
                width: abs(pt.x - start.x), height: abs(pt.y - start.y)
            )
        }
        vm.addPath(current)
        vm.currentPath = nil
    }

    private func tapAt(_ pt: CGPoint) {
        switch vm.tool {
        case .number:
            vm.addPath(
                AnnotationPath(
                    tool: .number,
                    points: [pt],
                    color: .red,
                    width: vm.strokeWidth,
                    text: "\(vm.numberCounter)",
                    numberIndex: vm.numberCounter
                )
            )
            vm.numberCounter += 1
        case .text:
            // 先看是否命中已有文字
            for path in vm.paths where path.tool == .text {
                guard let origin = path.points.first else { continue }
                let fontSize = max(10, path.width * 3)
                let txt = path.text ?? ""
                let approxWidth = CGFloat(txt.count) * fontSize * 0.55
                let r = CGRect(
                    x: origin.x + path.offset.width - 6,
                    y: origin.y + path.offset.height - 4,
                    width: approxWidth + 12,
                    height: fontSize + 8
                )
                if r.contains(pt) {
                    vm.beginEditText(path)
                    return
                }
            }
            vm.beginCreateText(at: pt)
        default:
            break
        }
    }

    // MARK: 保存 / 复制 / 置顶

    private func saveAnnotatedImage() {
        let nsImage = vm.renderAnnotatedImage()
        let desktop = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first
            ?? NSTemporaryDirectory()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let savePath = (desktop as NSString).appendingPathComponent("annotated_\(df.string(from: Date())).png")
        _ = nsImage.savePNG(to: savePath)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([URL(fileURLWithPath: savePath) as NSURL])
        onSave(savePath)
    }

    private func copyToClipboard() {
        let nsImage = vm.renderAnnotatedImage()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([nsImage])
        onSave(vm.imagePath)
    }

    private func pinToScreen() {
        let nsImage = vm.renderAnnotatedImage()
        let maxSize: CGFloat = 560
        let w = nsImage.size.width, h = nsImage.size.height
        let s = min(maxSize / max(w, h), 1.0)
        let windowW = w * s, windowH = h * s

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        let window = NSWindow(
            contentRect: NSRect(x: frame.midX - windowW/2, y: frame.midY - windowH/2,
                                width: windowW, height: windowH),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.title = "置顶标注"
        let hosting = NSHostingView(rootView: PinnedAnnotationView(image: nsImage, onClose: { window.close() }))
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onSave(vm.imagePath)
    }

    // MARK: Layout helpers

    private func fitSize(imageSize: CGSize, to container: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else { return container }
        let imgAspect = imageSize.width / imageSize.height
        let conAspect = container.width / container.height
        if imgAspect > conAspect {
            return CGSize(width: container.width, height: container.width / imgAspect)
        } else {
            return CGSize(width: container.height * imgAspect, height: container.height)
        }
    }
}

// MARK: - 渲染 Canvas

/// 负责：
/// - 用 tapGesture 进行“文字”和“编号”的点输入
/// - 用 DragGesture 进行矩形/线/箭头的绘制
/// - 利用 MosaicRenderer 对 mosaic 路径真像素化预览
struct AnnotationCanvas: View {
    @ObservedObject var vm: ScreenshotAnnotationViewModel
    let size: CGSize

    let onStartDrag: (CGPoint) -> Void
    let onDragMoved: (CGPoint) -> Void
    let onDragEnded: (CGPoint) -> Void
    let onTapAt: (CGPoint) -> Void

    var body: some View {
        Canvas { context, _ in
            for path in vm.paths { draw(path, in: &context) }
            if let cp = vm.currentPath { draw(cp, in: &context) }
        }
        .contentShape(Rectangle())
        .gesture(primaryGesture)
    }

    // 统一手势：区分“点击”（移动距离 < 阈值）和“拖拽”（移动距离 >= 阈值）。
    // - 文本/编号：使用“点击”语义创建新的标注
    // - 其余工具：使用“拖拽”语义绘制矩形/直线/马赛克
    @State private var hasDragMovedBeyondThreshold = false
    private var primaryGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if vm.tool == .text || vm.tool == .number { return }
                let d = hypot(value.translation.width, value.translation.height)
                if d > 3 { hasDragMovedBeyondThreshold = true }
                if vm.currentPath == nil { onStartDrag(value.startLocation) }
                onDragMoved(value.location)
            }
            .onEnded { value in
                if vm.tool == .text || vm.tool == .number {
                    // 短点击
                    onTapAt(value.location)
                    return
                }
                let d = hypot(value.translation.width, value.translation.height)
                if d <= 3 && vm.currentPath == nil {
                    // 空点击：忽略
                    return
                }
                if vm.currentPath == nil { onStartDrag(value.startLocation) }
                onDragEnded(value.location)
                hasDragMovedBeyondThreshold = false
            }
    }

    // MARK: 路径绘制

    private func draw(_ path: AnnotationPath, in context: inout GraphicsContext) {
        switch path.tool {

        case .mosaicPixel, .mosaicBlur:
            guard let rect = path.rect, rect.width > 0, rect.height > 0 else { return }
            let tool: MosaicTool = path.tool == .mosaicPixel
                ? .pixelate(blockSize: max(4, path.width))
                : .blur(radius: max(2, path.width * 0.5))
            if let tile = vm.mosaicPreview.renderTile(tool: tool, rect: rect) {
                // 在 canvas 坐标中贴 tile（注意 y 翻转）
                let drawRect = NSRect(
                    x: rect.minX,
                    y: rect.minY,
                    width: rect.width,
                    height: rect.height
                )
                context.draw(Image(nsImage: tile), in: drawRect)
            }

        case .frame:
            if let rect = path.rect {
                context.stroke(Path(rect), with: .color(path.color), lineWidth: path.width)
            }

        case .circle:
            if let rect = path.rect {
                context.stroke(Path(ellipseIn: rect), with: .color(path.color), lineWidth: path.width)
            }

        case .line:
            if path.points.count > 1 {
                var p = Path()
                p.move(to: path.points[0])
                for pt in path.points.dropFirst() { p.addLine(to: pt) }
                context.stroke(p, with: .color(path.color), lineWidth: path.width)
            }

        case .arrow:
            if path.points.count >= 2,
               let start = path.points.first,
               let end = path.points.last {
                var p = Path()
                p.move(to: start); p.addLine(to: end)
                context.stroke(p, with: .color(path.color), lineWidth: path.width)

                let angle = atan2(end.y - start.y, end.x - start.x)
                let headLen = max(12, path.width * 2)
                let headAng: CGFloat = .pi / 6
                let p1 = CGPoint(
                    x: end.x - headLen * cos(angle - headAng),
                    y: end.y - headLen * sin(angle - headAng)
                )
                let p2 = CGPoint(
                    x: end.x - headLen * cos(angle + headAng),
                    y: end.y - headLen * sin(angle + headAng)
                )
                var head = Path()
                head.move(to: p1); head.addLine(to: end); head.addLine(to: p2)
                context.stroke(head, with: .color(path.color), lineWidth: path.width)
            }

        case .text:
            if let text = path.text, let point = path.points.first {
                let fontSize = path.width * 3
                let drawPoint = CGPoint(x: point.x + path.offset.width, y: point.y + path.offset.height)
                let approxW = CGFloat(text.count) * fontSize * 0.55
                let bgRect = CGRect(
                    x: drawPoint.x - 4, y: drawPoint.y - 2,
                    width: approxW + 8, height: fontSize + 6
                )
                context.fill(Path(roundedRect: bgRect, cornerSize: CGSize(width: 4, height: 4)),
                             with: .color(.black.opacity(0.6)))
                let resolved = context.resolve(
                    Text(text)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundStyle(path.color)
                )
                context.draw(resolved, at: drawPoint, anchor: .topLeading)

                if path.id == vm.selectedPathId {
                    context.stroke(Path(bgRect.insetBy(dx: -3, dy: -3)),
                                   with: .color(.blue), lineWidth: 1.5)
                }
            }

        case .number:
            if let point = path.points.first {
                let drawPoint = CGPoint(x: point.x + path.offset.width, y: point.y + path.offset.height)
                let radius: CGFloat = 12
                let circleRect = CGRect(x: drawPoint.x - radius, y: drawPoint.y - radius,
                                        width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: circleRect), with: .color(path.color))
                let resolved = context.resolve(
                    Text(path.text ?? "\(path.numberIndex)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )
                context.draw(resolved, at: drawPoint, anchor: .center)
                if path.id == vm.selectedPathId {
                    context.stroke(Path(ellipseIn: circleRect.insetBy(dx: -3, dy: -3)),
                                   with: .color(.blue), lineWidth: 1.5)
                }
            }
        }
    }
}

// MARK: - 共享扩展（PNG 保存）

extension NSImage {
    func savePNG(to path: String) -> Bool {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
        let url = URL(fileURLWithPath: path)
        guard let dst = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(dst, cgImage, nil)
        return CGImageDestinationFinalize(dst)
    }
}
