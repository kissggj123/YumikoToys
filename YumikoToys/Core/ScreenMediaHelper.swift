//
//  ScreenMediaHelper.swift
//  YumikoToys
//
//  截图与录屏助手 (v6.0.0 - 多屏截图 / 标注修复 / 颜色选择器)
//

import Foundation
import AppKit
import UserNotifications
import ScreenCaptureKit
import SwiftUI
import CoreGraphics

@MainActor
final class ScreenMediaHelper: ObservableObject {
    static let shared = ScreenMediaHelper()

    @Published var isRecording = false
    private var recordProcess: Process?
    private var currentRecordURL: URL?

    private init() {}

    // MARK: - Screen Recording Permission

    static var hasScreenRecordingPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }

    private func ensureScreenRecordingPermission() -> Bool {
        if Self.hasScreenRecordingPermission {
            return true
        }
        Self.requestScreenRecordingPermission()
        notify(title: "需要屏幕录制权限", body: "请在系统设置中授予屏幕录制权限后重试")
        return false
    }

    // MARK: - Notification Helper

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Output Mode

    private var outputMode: ScreenshotOutputMode {
        DependencyContainer.shared.settingsService.settings.screenshotOutputMode
    }

    private func showPreview(image: NSImage) {
        _ = FloatingScreenshotPreviewWindow(image: image)
    }

    func captureArea() {
        guard ensureScreenRecordingPermission() else { return }
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        let tempPath = (annotationTempPath() as NSString).expandingTildeInPath
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", tempPath]
        
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if FileManager.default.fileExists(atPath: tempPath) {
                    if let image = NSImage(contentsOfFile: tempPath) {
                        self.showPreview(image: image)
                    }
                    
                    if self.outputMode == .clipboardOnly {
                        self.copyFileToClipboard(path: tempPath)
                        try? FileManager.default.removeItem(atPath: tempPath)
                    } else if self.outputMode == .fileOnly {
                        try? FileManager.default.moveItem(atPath: tempPath, toPath: resolved)
                        self.notify(title: "截图成功", body: "截图已保存至桌面")
                    } else if self.outputMode == .both {
                        try? FileManager.default.copyItem(atPath: tempPath, toPath: resolved)
                        self.copyFileToClipboard(path: resolved)
                        try? FileManager.default.removeItem(atPath: tempPath)
                    }
                }
            }
        }
        
        do { try process.run() } catch {
            LoggerService.shared.error("Failed to run area capture: \(error)")
        }
    }

    func captureFullscreen() {
        guard ensureScreenRecordingPermission() else { return }
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        let tempPath = (annotationTempPath() as NSString).expandingTildeInPath
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [tempPath]
        
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if FileManager.default.fileExists(atPath: tempPath) {
                    if let image = NSImage(contentsOfFile: tempPath) {
                        self.showPreview(image: image)
                    }
                    
                    if self.outputMode == .clipboardOnly {
                        self.copyFileToClipboard(path: tempPath)
                        try? FileManager.default.removeItem(atPath: tempPath)
                    } else if self.outputMode == .fileOnly {
                        try? FileManager.default.moveItem(atPath: tempPath, toPath: resolved)
                        self.notify(title: "截图成功", body: "截图已保存至桌面")
                    } else if self.outputMode == .both {
                        try? FileManager.default.copyItem(atPath: tempPath, toPath: resolved)
                        self.copyFileToClipboard(path: resolved)
                        try? FileManager.default.removeItem(atPath: tempPath)
                    }
                }
            }
        }
        
        do { try process.run() } catch {
            LoggerService.shared.error("Failed to run fullscreen capture: \(error)")
        }
    }

    func captureTouchBar() {
        guard ensureScreenRecordingPermission() else { return }
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

        var args = ["-b"]
        if outputMode == .clipboardOnly {
            args.append("-c")
        }
        args.append(resolved)

        process.arguments = args

        if outputMode == .both {
            process.terminationHandler = { [weak self] _ in
                Task { @MainActor in
                    if FileManager.default.fileExists(atPath: resolved) {
                        self?.copyFileToClipboard(path: resolved)
                    }
                }
            }
        }

        do {
            try process.run()
            notify(title: "TouchBar 截图成功", body: "截图已保存至桌面")
        } catch {
            LoggerService.shared.error("Failed to run touchbar capture: \(error)")
        }
    }

    // MARK: - Capture All Screens (SCScreenshotManager – modern ScreenCaptureKit API)

    func captureAllScreens() {
        guard ensureScreenRecordingPermission() else { return }
        Task {
            await captureAllScreensAsync()
        }
    }

    private func captureAllScreensAsync() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            let scDisplays = content.displays

            guard !scDisplays.isEmpty else {
                notify(title: "截图失败", body: "无法枚举屏幕")
                return
            }

            var capturedImages: [(screen: NSScreen, image: NSImage, index: Int)] = []

            for (index, scDisplay) in scDisplays.enumerated() {
                // Find matching NSScreen by displayID to get backing scale factor (Retina support)
                let matchedScreen = NSScreen.screens.first { screen in
                    let did = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                    return did == scDisplay.displayID
                } ?? NSScreen.main ?? NSScreen.screens.first!

                let backingScale = matchedScreen.backingScaleFactor
                let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
                let config = SCStreamConfiguration()
                // Capture at native Retina resolution for high quality
                config.width  = Int(Double(scDisplay.width) * Double(backingScale))
                config.height = Int(Double(scDisplay.height) * Double(backingScale))
                config.showsCursor = false
                
                // Professional Display P3 Color space
                config.colorSpaceName = CGColorSpace.displayP3

                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                let nsImage = NSImage(cgImage: cgImage, size: matchedScreen.frame.size)
                capturedImages.append((screen: matchedScreen, image: nsImage, index: index + 1))
            }

            guard !capturedImages.isEmpty else {
                notify(title: "截图失败", body: "无法获取屏幕图像")
                return
            }

            if capturedImages.count == 1 {
                let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
                saveImage(capturedImages[0].image, to: resolved)
                
                // Show floating preview
                self.showPreview(image: capturedImages[0].image)
                
                if outputMode == .clipboardOnly || outputMode == .both {
                    self.copyFileToClipboard(path: resolved)
                } else {
                    notify(title: "截图成功", body: "屏幕截图已保存至桌面")
                }
            } else {
                openMultiScreenPreview(capturedImages)
            }

        } catch {
            LoggerService.shared.error("captureAllScreens failed: \(error)")
            notify(title: "截图失败", body: "屏幕截图出错：\(error.localizedDescription)")
        }
    }

    private func openMultiScreenPreview(_ screens: [(screen: NSScreen, image: NSImage, index: Int)]) {
        let previewView = MultiScreenPreviewView(screens: screens)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "多屏截图预览"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: previewView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func saveImage(_ image: NSImage, to path: String) {
        _ = image.savePNG(to: path)
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        guard ensureScreenRecordingPermission() else { return }
        let resolved = (defaultPath(isMovie: true) as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-V", "999999", resolved]
        do {
            try process.run()
            self.recordProcess = process
            self.isRecording = true
            self.currentRecordURL = URL(fileURLWithPath: resolved)
            notify(title: "录屏已开始", body: "正在录制，点击状态栏按钮可停止")
        } catch {
            LoggerService.shared.error("Failed to start screen recording: \(error)")
        }
    }

    func stopRecording() {
        guard isRecording, let process = recordProcess else { return }
        process.interrupt()
        self.recordProcess = nil
        self.isRecording = false
        if let url = currentRecordURL {
            notify(title: "录屏保存成功", body: "录制视频已保存至桌面：\(url.lastPathComponent)")
        }
    }

    // MARK: - Clipboard Helper

    private func copyFileToClipboard(path: String) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Copy the raw PNG data directly to prevent any re-encoding and distortion
        if let data = try? Data(contentsOf: url) {
            pasteboard.setData(data, forType: .png)
        }
        
        pasteboard.writeObjects([url as NSURL])
        notify(title: "已复制到剪贴板", body: "截图已复制到剪贴板")
    }

    // MARK: - Screenshot Annotation

    func openScreenshotAnnotation() {
        guard ensureScreenRecordingPermission() else { return }
        let tempPath = (annotationTempPath() as NSString).expandingTildeInPath

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-o", tempPath]

        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self = self, FileManager.default.fileExists(atPath: tempPath) else { return }
                self.openAnnotationEditor(imagePath: tempPath)
            }
        }

        do { try process.run() } catch {
            LoggerService.shared.error("Failed to run annotation capture: \(error)")
        }
    }

    private func openAnnotationEditor(imagePath: String) {
        guard let image = NSImage(contentsOfFile: imagePath) else { return }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: max(image.size.width, 800), height: max(image.size.height, 600)),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "截图标注工具"
        window.isReleasedWhenClosed = false

        let annotationView = ScreenshotAnnotationView(
            image: image,
            imagePath: imagePath,
            onSave: { [weak window] _ in window?.close() }
        )
        window.contentView = NSHostingView(rootView: annotationView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func defaultPath(isMovie: Bool) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let filename = isMovie
            ? "recording_\(df.string(from: Date())).mov"
            : "screenshot_\(df.string(from: Date())).png"
        let desktop = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first
            ?? NSTemporaryDirectory()
        return (desktop as NSString).appendingPathComponent(filename)
    }

    private func annotationTempPath() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let filename = "annotation_\(df.string(from: Date())).png"
        return (NSTemporaryDirectory() as NSString).appendingPathComponent(filename)
    }
}

// MARK: - 多屏截图预览

struct MultiScreenPreviewView: View {
    let screens: [(screen: NSScreen, image: NSImage, index: Int)]
    @State private var selectedIndex: Int? = nil
    @State private var savedIndices: Set<Int> = []

    var body: some View {
        VStack(spacing: 16) {
            Text("选择要保存的屏幕截图")
                .font(.title3.bold())

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: min(screens.count, 3)),
                spacing: 12
            ) {
                ForEach(screens, id: \.index) { item in
                    VStack(spacing: 6) {
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: item.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 140)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            selectedIndex == item.index ? Color.accentColor : Color.gray.opacity(0.3),
                                            lineWidth: selectedIndex == item.index ? 3 : 1
                                        )
                                )
                                .onTapGesture { selectedIndex = item.index }

                            if savedIndices.contains(item.index) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .padding(4)
                            }
                        }

                        Text("屏幕 \(item.index)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        let size = item.screen.frame.size
                        Text("\(Int(size.width)) × \(Int(size.height))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            HStack(spacing: 12) {
                Button("保存选中屏幕") {
                    if let idx = selectedIndex,
                       let item = screens.first(where: { $0.index == idx }) {
                        saveScreen(item.image, suffix: "screen\(idx)")
                        savedIndices.insert(idx)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIndex == nil)

                Button("保存所有屏幕") {
                    for item in screens {
                        saveScreen(item.image, suffix: "screen\(item.index)")
                        savedIndices.insert(item.index)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { closeWindow() }
                }
                .buttonStyle(.bordered)

                Button("复制到剪贴板") {
                    if let idx = selectedIndex,
                       let item = screens.first(where: { $0.index == idx }) {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.writeObjects([item.image])
                        closeWindow()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(selectedIndex == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 360)
    }

    private func saveScreen(_ image: NSImage, suffix: String) {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let desktop = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first
            ?? NSTemporaryDirectory()
        let path = (desktop as NSString).appendingPathComponent("screenshot_\(suffix)_\(df.string(from: Date())).png")
        _ = image.savePNG(to: path)
    }

    private func closeWindow() { NSApp.keyWindow?.close() }
}

// MARK: - 截图标注工具视图

struct ScreenshotAnnotationView: View {
    let image: NSImage
    let imagePath: String
    let onSave: (String) -> Void

    @State private var tool: AnnotationTool = .mosaicPixel
    @State private var strokeWidth: CGFloat = 8
    @State private var paths: [AnnotationPath] = []
    @State private var currentPath: AnnotationPath?
    @State private var showTextInput = false
    @State private var textInputContent = ""
    @State private var textInputPosition: CGPoint = .zero
    @State private var annotationColor: Color = .red
    @State private var canvasSize: CGSize = .zero
    @State private var selectedPathId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var controlPointDrag: ControlPointType?
    @State private var lastDragLocation: CGPoint = .zero
    @State private var numberCounter: Int = 1
    @State private var editingTextId: UUID?

    private var scaleRatio: CGFloat {
        guard image.size.width > 0, canvasSize.width > 0 else { return 1 }
        return fitSize(imageSize: image.size, to: canvasSize).width / image.size.width
    }

    enum AnnotationTool: String, CaseIterable {
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
    }

    struct AnnotationPath: Identifiable {
        let id = UUID()
        let tool: AnnotationTool
        var points: [CGPoint]
        var rect: CGRect?
        let color: Color
        let width: CGFloat
        var text: String?
        var offset: CGSize = .zero
        var isSelected: Bool = false
        var numberIndex: Int = 0
    }
    
    enum ControlPointType {
        case move
        case scaleTopLeft
        case scaleTopRight
        case scaleBottomLeft
        case scaleBottomRight
        case scaleTop
        case scaleBottom
        case scaleLeft
        case scaleRight
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Toolbar ──────────────────────────────────────────────────────
            HStack(spacing: 10) {
                ForEach(AnnotationTool.allCases, id: \.self) { t in
                    Button(action: { tool = t }) {
                        VStack(spacing: 2) {
                            Image(systemName: t.icon).font(.system(size: 14))
                            Text(t.displayName).font(.system(size: 9))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(tool == t ? Color.accentColor : Color.gray.opacity(0.15))
                        )
                        .foregroundStyle(tool == t ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }

                Divider().frame(height: 24)

                ColorPicker("", selection: $annotationColor)
                    .frame(width: 28, height: 28)
                    .help("选择颜色")

                Divider().frame(height: 24)

                HStack(spacing: 4) {
                    Text("线宽").font(.system(size: 10))
                    Slider(value: $strokeWidth, in: 2...30).frame(width: 80)
                    Text(String(format: "%.0f", strokeWidth)).font(.system(size: 10, design: .monospaced))
                }

                Spacer()

                if selectedPathId != nil {
                    Button("删除") {
                        if let id = selectedPathId {
                            paths.removeAll { $0.id == id }
                            selectedPathId = nil
                        }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Button("撤销") {
                    selectedPathId = nil
                    if !paths.isEmpty { paths.removeLast() }
                }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .disabled(paths.isEmpty)

                Button("保存") { saveAnnotatedImage() }
                    .font(.system(size: 10, weight: .medium))
                    .buttonStyle(.borderedProminent)

                Button("复制") { copyToClipboard() }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)

                Button(action: pinToScreen) {
                    HStack(spacing: 3) {
                        Image(systemName: "pin.fill").font(.system(size: 9))
                        Text("置顶").font(.system(size: 10))
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // ── Canvas ───────────────────────────────────────────────────────
            GeometryReader { geo in
                let imgSize = fitSize(imageSize: image.size, to: geo.size)
                let offset  = CGPoint(
                    x: (geo.size.width  - imgSize.width)  / 2,
                    y: (geo.size.height - imgSize.height) / 2
                )

                ZStack {
                    Color(nsColor: .controlBackgroundColor)

                    Image(nsImage: image)
                        .resizable()
                        .frame(width: imgSize.width, height: imgSize.height)
                        .position(x: offset.x + imgSize.width / 2,
                                  y: offset.y + imgSize.height / 2)

                    Canvas { context, size in
                        for p in paths      { drawPath(p, in: &context, size: size) }
                        if let cp = currentPath { drawPath(cp, in: &context, size: size) }
                    }
                    .frame(width: imgSize.width, height: imgSize.height)
                    .position(x: offset.x + imgSize.width / 2,
                              y: offset.y + imgSize.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if tool == .text || tool == .number { return }
                                let pt = value.location
                                if currentPath == nil {
                                    currentPath = AnnotationPath(
                                        tool: tool,
                                        points: [pt],
                                        rect: nil,
                                        color: tool.isMosaic ? .gray : annotationColor,
                                        width: strokeWidth
                                    )
                                } else {
                                    currentPath?.points.append(pt)
                                    if (tool == .frame || tool == .circle || tool.isMosaic),
                                       let start = currentPath?.points.first {
                                        currentPath?.rect = CGRect(
                                            x: min(start.x, pt.x),
                                            y: min(start.y, pt.y),
                                            width:  abs(pt.x - start.x),
                                            height: abs(pt.y - start.y)
                                        )
                                    }
                                }
                            }
                            .onEnded { value in
                                if tool == .text || tool == .number { return }
                                if let current = currentPath {
                                    var finalPath = current
                                    if tool == .frame || tool == .circle || tool.isMosaic {
                                        let s = current.points.first ?? .zero
                                        let e = current.points.last  ?? .zero
                                        finalPath = AnnotationPath(
                                            tool: tool,
                                            points: current.points,
                                            rect: CGRect(
                                                x: min(s.x, e.x), y: min(s.y, e.y),
                                                width: abs(e.x - s.x), height: abs(e.y - s.y)
                                            ),
                                            color: tool.isMosaic ? .gray : annotationColor,
                                            width: strokeWidth
                                        )
                                    }
                                    paths.append(finalPath)
                                }
                                currentPath = nil
                            }
                    )
                    // Text tool: tap overlay with zero-minimum-distance drag to capture location
                    .overlay(
                        GeometryReader { _ in
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            guard tool == .text || tool == .number else { return }
                                            let pt = value.location
                                            if selectedPathId != nil {
                                                if let idx = paths.firstIndex(where: { $0.id == selectedPathId }) {
                                                    let delta = CGSize(
                                                        width: pt.x - lastDragLocation.x,
                                                        height: pt.y - lastDragLocation.y
                                                    )
                                                    paths[idx].offset.width += delta.width
                                                    paths[idx].offset.height += delta.height
                                                    lastDragLocation = pt
                                                }
                                            }
                                        }
                                        .onEnded { value in
                                            guard tool == .text || tool == .number else { return }
                                            let pt = value.location
                                            if let selId = selectedPathId {
                                                if let idx = paths.firstIndex(where: { $0.id == selId && $0.tool == .text }) {
                                                    let path = paths[idx]
                                                    if let textPoint = path.points.first {
                                                        let textWidth = CGFloat(path.text?.count ?? 0) * path.width * 3 * 0.6
                                                        let textRect = CGRect(
                                                            x: textPoint.x + path.offset.width - 4,
                                                            y: textPoint.y + path.offset.height - 4,
                                                            width: textWidth + 8,
                                                            height: max(path.width * 3, 20) + 8
                                                        )
                                                        if textRect.contains(pt) {
                                                            editingTextId = path.id
                                                            textInputContent = path.text ?? ""
                                                            showTextInput = true
                                                            return
                                                        }
                                                    }
                                                }
                                                selectedPathId = nil
                                            }
                                            var hitAnnotation = false
                                            for (idx, path) in paths.enumerated() where path.tool == .text || path.tool == .number {
                                                if let textPoint = path.points.first {
                                                    let textWidth = CGFloat(path.text?.count ?? 0) * path.width * 3 * 0.6
                                                    let hitSize: CGFloat = path.tool == .number ? 24 : max(path.width * 3, 20)
                                                    let textRect = CGRect(
                                                        x: textPoint.x + path.offset.width - 4,
                                                        y: textPoint.y + path.offset.height - 4,
                                                        width: textWidth + 8,
                                                        height: hitSize + 8
                                                    )
                                                    if textRect.contains(pt) {
                                                        selectedPathId = path.id
                                                        lastDragLocation = pt
                                                        hitAnnotation = true
                                                        break
                                                    }
                                                }
                                            }
                                            if !hitAnnotation {
                                                if tool == .number {
                                                    paths.append(AnnotationPath(
                                                        tool: .number,
                                                        points: [pt],
                                                        color: .red,
                                                        width: strokeWidth,
                                                        text: "\(numberCounter)",
                                                        numberIndex: numberCounter
                                                    ))
                                                    numberCounter += 1
                                                } else {
                                                    textInputPosition = pt
                                                    textInputContent  = ""
                                                    editingTextId = nil
                                                    showTextInput     = true
                                                }
                                            }
                                        }
                                )
                        }
                        .opacity(tool == .text || tool == .number ? 1 : 0)
                    )
                }
                .onChange(of: geo.size) { _, newSize in
                    canvasSize = fitSize(imageSize: image.size, to: newSize)
                }
                .onAppear {
                    canvasSize = fitSize(imageSize: image.size, to: geo.size)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showTextInput) {
            VStack(spacing: 16) {
                Text(editingTextId != nil ? "编辑标注文字" : "输入标注文字").font(.headline)
                TextField("文字内容", text: $textInputContent)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                HStack {
                    Button("取消") { showTextInput = false }
                    Button("确定") {
                        if !textInputContent.isEmpty {
                            if let editId = editingTextId, let idx = paths.firstIndex(where: { $0.id == editId }) {
                                paths[idx].text = textInputContent
                            } else {
                                paths.append(AnnotationPath(
                                    tool: .text,
                                    points: [textInputPosition],
                                    color: annotationColor,
                                    width: strokeWidth,
                                    text: textInputContent
                                ))
                            }
                        }
                        showTextInput = false
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(24)
            .frame(width: 400, height: 180)
        }
    }

    // MARK: - Layout helpers

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

    // MARK: - Canvas Drawing (scaled canvas coordinates)

    private func drawPath(_ path: AnnotationPath, in context: inout GraphicsContext, size: CGSize) {
        switch path.tool {

        case .mosaicPixel, .mosaicBlur:
            if let rect = path.rect, rect.width > 0, rect.height > 0 {
                let blockSize: CGFloat = max(6, path.width)
                var x = rect.minX
                while x < rect.maxX {
                    var y = rect.minY
                    while y < rect.maxY {
                        let br = CGRect(x: x, y: y,
                                        width:  min(blockSize, rect.maxX - x),
                                        height: min(blockSize, rect.maxY - y))
                        let seed = Int(x / blockSize) * 31 + Int(y / blockSize)
                        let gray = Double((seed * 127 + 73) % 60 + 20) / 100.0
                        context.fill(Path(br), with: .color(.init(red: gray, green: gray, blue: gray, opacity: 0.9)))
                        y += blockSize
                    }
                    x += blockSize
                }
            } else if path.points.count > 1 {
                let blockSize: CGFloat = max(6, path.width)
                for (i, point) in path.points.enumerated() {
                    let br = CGRect(x: point.x - blockSize / 2, y: point.y - blockSize / 2,
                                    width: blockSize, height: blockSize)
                    let gray = Double((i * 127 + 73) % 60 + 20) / 100.0
                    context.fill(Path(br), with: .color(.init(red: gray, green: gray, blue: gray, opacity: 0.9)))
                }
            }

        case .frame:
            if let rect = path.rect {
                context.stroke(Path(rect), with: .color(path.color), lineWidth: path.width)
            }

        case .circle:
            if let rect = path.rect {
                let ellipse = Path(ellipseIn: rect)
                context.stroke(ellipse, with: .color(path.color), lineWidth: path.width)
            }

        case .line:
            if path.points.count > 1 {
                var lp = Path()
                lp.move(to: path.points[0])
                for pt in path.points.dropFirst() { lp.addLine(to: pt) }
                context.stroke(lp, with: .color(path.color), lineWidth: path.width)
            }

        case .arrow:
            if path.points.count >= 2, let start = path.points.first, let end = path.points.last {
                var lp = Path()
                lp.move(to: start)
                lp.addLine(to: end)
                context.stroke(lp, with: .color(path.color), lineWidth: path.width)
                
                let dx = end.x - start.x
                let dy = end.y - start.y
                let angle = atan2(dy, dx)
                let headLength: CGFloat = max(12, path.width * 2)
                let headAngle: CGFloat = .pi / 6
                
                let p1 = CGPoint(
                    x: end.x - headLength * cos(angle - headAngle),
                    y: end.y - headLength * sin(angle - headAngle)
                )
                let p2 = CGPoint(
                    x: end.x - headLength * cos(angle + headAngle),
                    y: end.y - headLength * sin(angle + headAngle)
                )
                
                var arrowHead = Path()
                arrowHead.move(to: p1)
                arrowHead.addLine(to: end)
                arrowHead.addLine(to: p2)
                context.stroke(arrowHead, with: .color(path.color), lineWidth: path.width)
            }

        case .text:
            if let text = path.text, let point = path.points.first {
                let fontSize = path.width * 3
                let drawPoint = CGPoint(x: point.x + path.offset.width, y: point.y + path.offset.height)
                let textWidth = CGFloat(text.count) * fontSize * 0.6
                let bgRect = CGRect(
                    x: drawPoint.x - 4,
                    y: drawPoint.y - 2,
                    width: textWidth + 8,
                    height: fontSize + 6
                )
                let bgPath = Path { p in
                    p.addRoundedRect(in: bgRect, cornerSize: CGSize(width: 4, height: 4))
                }
                context.fill(bgPath, with: .color(.black.opacity(0.6)))
                let resolved = context.resolve(
                    Text(text)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundStyle(path.color)
                )
                context.draw(resolved, at: drawPoint, anchor: .topLeading)
                
                if path.id == selectedPathId {
                    let selectionRect = bgRect.insetBy(dx: -3, dy: -3)
                    context.stroke(
                        Path(selectionRect),
                        with: .color(.blue),
                        lineWidth: 1.5
                    )
                    let controlSize: CGFloat = 7
                    let corners = [
                        CGPoint(x: selectionRect.minX, y: selectionRect.minY),
                        CGPoint(x: selectionRect.maxX, y: selectionRect.minY),
                        CGPoint(x: selectionRect.minX, y: selectionRect.maxY),
                        CGPoint(x: selectionRect.maxX, y: selectionRect.maxY),
                    ]
                    for cp in corners {
                        context.fill(
                            Path(CGRect(x: cp.x - controlSize/2, y: cp.y - controlSize/2, width: controlSize, height: controlSize)),
                            with: .color(.blue)
                        )
                    }
                }
            }

        case .number:
            if let point = path.points.first {
                let drawPoint = CGPoint(x: point.x + path.offset.width, y: point.y + path.offset.height)
                let radius: CGFloat = 12
                let circleRect = CGRect(x: drawPoint.x - radius, y: drawPoint.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: circleRect), with: .color(path.color))
                let resolved = context.resolve(
                    Text(path.text ?? "\(path.numberIndex)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )
                context.draw(resolved, at: drawPoint, anchor: .center)
                
                if path.id == selectedPathId {
                    let selRect = circleRect.insetBy(dx: -3, dy: -3)
                    context.stroke(Path(ellipseIn: selRect), with: .color(.blue), lineWidth: 1.5)
                }
            }
        }
    }

    // MARK: - Save / Copy

    private func saveAnnotatedImage() {
        let nsImage = renderAnnotatedImage()
        let desktop = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first
            ?? NSTemporaryDirectory()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        let savePath = (desktop as NSString).appendingPathComponent("annotated_\(df.string(from: Date())).png")

        _ = nsImage.savePNG(to: savePath)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([URL(fileURLWithPath: savePath) as NSURL])
        onSave(savePath)
    }

    private func copyToClipboard() {
        let nsImage = renderAnnotatedImage()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        onSave(imagePath)
    }

    private func pinToScreen() {
        let nsImage = renderAnnotatedImage()
        let imgWidth = nsImage.size.width
        let imgHeight = nsImage.size.height
        let maxSize: CGFloat = 500
        let scale = min(maxSize / imgWidth, maxSize / imgHeight, 1.0)
        let windowWidth = imgWidth * scale
        let windowHeight = imgHeight * scale

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        let window = NSWindow(
            contentRect: NSRect(x: screenFrame.midX - windowWidth/2, y: screenFrame.midY - windowHeight/2, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
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
        onSave(imagePath)
    }

    // MARK: - Render to NSImage (image-coordinate space)
    //
    //  Canvas coords are in the *scaled* display space (canvasSize).
    //  To paint on the full-resolution NSImage we apply:
    //      imagePoint = canvasPoint / scaleRatio
    //  Y is flipped because NSImage origin is bottom-left.

    private func renderAnnotatedImage() -> NSImage {
        let size  = image.size // Size in points
        let ratio = scaleRatio

        // Get actual pixel dimensions from representations to preserve Retina resolution
        let pixelsWide: Int
        let pixelsHigh: Int
        if let rep = image.representations.first {
            pixelsWide = rep.pixelsWide
            pixelsHigh = rep.pixelsHigh
        } else {
            pixelsWide = Int(size.width)
            pixelsHigh = Int(size.height)
        }

        let pixelSize = CGSize(width: pixelsWide, height: pixelsHigh)
        let backingScaleX = CGFloat(pixelsWide) / size.width
        let newRatio = ratio / backingScaleX

        let colorSpaceName = (image.representations.first as? NSBitmapImageRep)?.colorSpaceName ?? .deviceRGB

        guard let imageRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide:   pixelsWide,
            pixelsHigh:   pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha:   true,
            isPlanar:   false,
            colorSpaceName: colorSpaceName,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return image
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: imageRep)

        // Draw original image at native pixel size
        image.draw(in: NSRect(origin: .zero, size: pixelSize))

        // Draw annotations scaled to pixel size
        for path in paths {
            drawAnnotationPathOnImage(path, ratio: newRatio, imageSize: pixelSize)
        }

        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: pixelSize)
        result.addRepresentation(imageRep)
        return result
    }

    /// Convert canvas-space point to AppKit image-space point (flips Y).
    private func canvasToImage(_ pt: CGPoint, ratio: CGFloat, imageHeight: CGFloat) -> NSPoint {
        NSPoint(x: pt.x / ratio, y: imageHeight - pt.y / ratio)
    }

    private func drawAnnotationPathOnImage(_ path: AnnotationPath, ratio: CGFloat, imageSize: CGSize) {
        let nsColor = NSColor(path.color)
        nsColor.setStroke()
        let h = imageSize.height

        switch path.tool {

        case .mosaicPixel, .mosaicBlur:
            if let rect = path.rect, rect.width > 0, rect.height > 0 {
                let imgRect = CGRect(
                    x: rect.minX / ratio,
                    y: h - rect.maxY / ratio,
                    width:  rect.width  / ratio,
                    height: rect.height / ratio
                )
                let blockSize: CGFloat = max(6, path.width / ratio)
                var x = imgRect.minX
                while x < imgRect.maxX {
                    var y = imgRect.minY
                    while y < imgRect.maxY {
                        let br = CGRect(x: x, y: y,
                                        width:  min(blockSize, imgRect.maxX - x),
                                        height: min(blockSize, imgRect.maxY - y))
                        let seed = Int(x / blockSize) * 31 + Int(y / blockSize)
                        let gray = CGFloat((seed * 127 + 73) % 60 + 20) / 100.0
                        NSColor(red: gray, green: gray, blue: gray, alpha: 0.9).setFill()
                        NSBezierPath(rect: br).fill()
                        y += blockSize
                    }
                    x += blockSize
                }
            } else if path.points.count > 1 {
                let blockSize: CGFloat = max(6, path.width / ratio)
                for (i, pt) in path.points.enumerated() {
                    let ip = canvasToImage(pt, ratio: ratio, imageHeight: h)
                    let br = CGRect(x: ip.x - blockSize / 2, y: ip.y - blockSize / 2,
                                    width: blockSize, height: blockSize)
                    let gray = CGFloat((i * 127 + 73) % 60 + 20) / 100.0
                    NSColor(red: gray, green: gray, blue: gray, alpha: 0.9).setFill()
                    NSBezierPath(rect: br).fill()
                }
            }

        case .frame:
            if let rect = path.rect {
                let imgRect = CGRect(
                    x: rect.minX / ratio,
                    y: h - rect.maxY / ratio,
                    width:  rect.width  / ratio,
                    height: rect.height / ratio
                )
                let bp = NSBezierPath(rect: imgRect)
                bp.lineWidth = path.width / ratio
                bp.stroke()
            }

        case .circle:
            if let rect = path.rect {
                let imgRect = CGRect(
                    x: rect.minX / ratio,
                    y: h - rect.maxY / ratio,
                    width:  rect.width  / ratio,
                    height: rect.height / ratio
                )
                let bp = NSBezierPath(ovalIn: imgRect)
                bp.lineWidth = path.width / ratio
                bp.stroke()
            }

        case .line:
            if path.points.count > 1 {
                let bp = NSBezierPath()
                bp.move(to: canvasToImage(path.points[0], ratio: ratio, imageHeight: h))
                for pt in path.points.dropFirst() {
                    bp.line(to: canvasToImage(pt, ratio: ratio, imageHeight: h))
                }
                bp.lineWidth = path.width / ratio
                bp.stroke()
            }

        case .arrow:
            if path.points.count >= 2, let start = path.points.first, let end = path.points.last {
                let ipStart = canvasToImage(start, ratio: ratio, imageHeight: h)
                let ipEnd = canvasToImage(end, ratio: ratio, imageHeight: h)
                
                let bp = NSBezierPath()
                bp.move(to: ipStart)
                bp.line(to: ipEnd)
                bp.lineWidth = path.width / ratio
                bp.stroke()
                
                let dx = ipEnd.x - ipStart.x
                let dy = ipEnd.y - ipStart.y
                let angle = atan2(dy, dx)
                let headLength: CGFloat = max(12, path.width * 2) / ratio
                let headAngle: CGFloat = .pi / 6
                
                let p1 = NSPoint(
                    x: ipEnd.x - headLength * cos(angle - headAngle),
                    y: ipEnd.y - headLength * sin(angle - headAngle)
                )
                let p2 = NSPoint(
                    x: ipEnd.x - headLength * cos(angle + headAngle),
                    y: ipEnd.y - headLength * sin(angle + headAngle)
                )
                
                let arrowHead = NSBezierPath()
                arrowHead.move(to: p1)
                arrowHead.line(to: ipEnd)
                arrowHead.line(to: p2)
                arrowHead.lineWidth = path.width / ratio
                arrowHead.stroke()
            }

        case .text:
            if let text = path.text, let pt = path.points.first {
                let ip = canvasToImage(pt, ratio: ratio, imageHeight: h)
                let offsetX = path.offset.width / ratio
                let offsetY = -path.offset.height / ratio
                let fontSize = (path.width * 3) / ratio
                let attrs: [NSAttributedString.Key: Any] = [
                    .font:            NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                    .foregroundColor: nsColor
                ]
                let textSize = (text as NSString).size(withAttributes: attrs)
                let textOrigin = NSPoint(x: ip.x + offsetX, y: ip.y + offsetY - fontSize)
                let bgRect = NSRect(x: textOrigin.x - 3, y: textOrigin.y - 2, width: textSize.width + 6, height: fontSize + 4)
                NSColor(white: 0, alpha: 0.6).setFill()
                NSBezierPath(roundedRect: bgRect, xRadius: 3, yRadius: 3).fill()
                NSAttributedString(string: text, attributes: attrs)
                    .draw(at: textOrigin)
            }

        case .number:
            if let pt = path.points.first {
                let ip = canvasToImage(pt, ratio: ratio, imageHeight: h)
                let radius: CGFloat = 12 / ratio
                let circleRect = NSRect(x: ip.x - radius, y: ip.y - radius, width: radius * 2, height: radius * 2)
                nsColor.setFill()
                NSBezierPath(ovalIn: circleRect).fill()
                let numStr = path.text ?? "\(path.numberIndex)"
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 13 / ratio, weight: .bold),
                    .foregroundColor: NSColor.white
                ]
                let numSize = (numStr as NSString).size(withAttributes: numAttrs)
                (numStr as NSString).draw(
                    at: NSPoint(x: ip.x - numSize.width / 2, y: ip.y - numSize.height / 2),
                    withAttributes: numAttrs
                )
            }
        }
    }
}

// MARK: - High Performance Image Saving Extension
extension NSImage {
    func savePNG(to path: String) -> Bool {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, cgImage, nil)
        return CGImageDestinationFinalize(destination)
    }
}

// MARK: - Pinned Annotation View
struct PinnedAnnotationView: View {
    let image: NSImage
    let onClose: () -> Void
    @State private var isHovered = false
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(opacity)

            if isHovered {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                    Spacer()
                }
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .onTapGesture { /* consume click */ }
        .onKeyPress(.delete) { onClose(); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
    }
}

// MARK: - Floating Screenshot Preview Window
final class FloatingScreenshotPreviewWindow: NSWindow {
    init(image: NSImage, duration: TimeInterval = 3.0) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        
        let previewSize = CGSize(width: 180, height: 120)
        let rect = NSRect(
            x: screenFrame.minX + 20,
            y: screenFrame.minY + 20,
            width: previewSize.width,
            height: previewSize.height
        )
        
        super.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isReleasedWhenClosed = false
        self.level = .floating
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isOpaque = false
        self.ignoresMouseEvents = false
        
        let contentView = FloatingPreviewContentView(image: image) { [weak self] in
            self?.close()
        }
        self.contentView = NSHostingView(rootView: contentView)
        
        self.makeKeyAndOrderFront(nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                self.animator().alphaValue = 0
            } completionHandler: {
                self.close()
            }
        }
    }
}

struct FloatingPreviewContentView: View {
    let image: NSImage
    let onClose: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Dark glassmorphic card base
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            VStack(spacing: 6) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 85)
                    .cornerRadius(6)
                    .padding(.top, 8)
                
                Text("截图已生成")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, 10)
            
            if isHovered {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .padding(6)
            }
        }
        .frame(width: 180, height: 120)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
