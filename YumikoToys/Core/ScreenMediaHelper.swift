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

    func captureArea() {
        guard ensureScreenRecordingPermission() else { return }
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

        var args = ["-i"]
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

        do { try process.run() } catch {
            LoggerService.shared.error("Failed to run area capture: \(error)")
        }
    }

    func captureFullscreen() {
        guard ensureScreenRecordingPermission() else { return }
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

        var args: [String] = []
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
            if outputMode == .clipboardOnly {
                notify(title: "全屏截图成功", body: "截图已复制到剪贴板")
            } else {
                notify(title: "全屏截图成功", body: "截图已保存至桌面")
            }
        } catch {
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
                notify(title: "截图成功", body: "屏幕截图已保存至桌面")
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
        pasteboard.writeObjects([url as NSURL])
        notify(title: "已复制到剪贴板", body: "截图文件已复制到剪贴板")
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

    @State private var tool: AnnotationTool = .mosaic
    @State private var strokeWidth: CGFloat = 8
    @State private var paths: [AnnotationPath] = []
    @State private var currentPath: AnnotationPath?
    @State private var showTextInput = false
    @State private var textInputContent = ""
    @State private var textInputPosition: CGPoint = .zero
    @State private var annotationColor: Color = .red
    @State private var canvasSize: CGSize = .zero

    private var scaleRatio: CGFloat {
        guard image.size.width > 0, canvasSize.width > 0 else { return 1 }
        return fitSize(imageSize: image.size, to: canvasSize).width / image.size.width
    }

    enum AnnotationTool: String, CaseIterable {
        case mosaic = "mosaic"
        case frame  = "frame"
        case line   = "line"
        case text   = "text"

        var displayName: String {
            switch self {
            case .mosaic: return "马赛克"
            case .frame:  return "画框"
            case .line:   return "画线"
            case .text:   return "文字"
            }
        }

        var icon: String {
            switch self {
            case .mosaic: return "square.grid.3x3"
            case .frame:  return "rectangle"
            case .line:   return "pencil"
            case .text:   return "textformat"
            }
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

                Button("撤销") { if !paths.isEmpty { paths.removeLast() } }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .disabled(paths.isEmpty)

                Button("保存") { saveAnnotatedImage() }
                    .font(.system(size: 10, weight: .medium))
                    .buttonStyle(.borderedProminent)

                Button("复制") { copyToClipboard() }
                    .font(.system(size: 10))
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
                                if tool == .text { return }
                                let pt = value.location
                                if currentPath == nil {
                                    currentPath = AnnotationPath(
                                        tool: tool,
                                        points: [pt],
                                        rect: nil,
                                        color: tool == .mosaic ? .gray : annotationColor,
                                        width: strokeWidth
                                    )
                                } else {
                                    currentPath?.points.append(pt)
                                    if (tool == .frame || tool == .mosaic),
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
                                if tool == .text { return }
                                if let current = currentPath {
                                    var finalPath = current
                                    if tool == .frame || tool == .mosaic {
                                        let s = current.points.first ?? .zero
                                        let e = current.points.last  ?? .zero
                                        finalPath = AnnotationPath(
                                            tool: tool,
                                            points: current.points,
                                            rect: CGRect(
                                                x: min(s.x, e.x), y: min(s.y, e.y),
                                                width: abs(e.x - s.x), height: abs(e.y - s.y)
                                            ),
                                            color: tool == .mosaic ? .gray : annotationColor,
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
                                        .onEnded { value in
                                            guard tool == .text else { return }
                                            textInputPosition = value.location
                                            textInputContent  = ""
                                            showTextInput     = true
                                        }
                                )
                        }
                        .opacity(tool == .text ? 1 : 0)
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
                Text("输入标注文字").font(.headline)
                TextField("文字内容", text: $textInputContent)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                HStack {
                    Button("取消") { showTextInput = false }
                    Button("确定") {
                        if !textInputContent.isEmpty {
                            paths.append(AnnotationPath(
                                tool: .text,
                                points: [textInputPosition],
                                color: annotationColor,
                                width: strokeWidth,
                                text: textInputContent
                            ))
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

        case .mosaic:
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

        case .line:
            if path.points.count > 1 {
                var lp = Path()
                lp.move(to: path.points[0])
                for pt in path.points.dropFirst() { lp.addLine(to: pt) }
                context.stroke(lp, with: .color(path.color), lineWidth: path.width)
            }

        case .text:
            if let text = path.text, let point = path.points.first {
                let fontSize = path.width * 3
                let resolved = context.resolve(
                    Text(text)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundStyle(path.color)
                )
                context.draw(resolved, at: point, anchor: .topLeading)
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

    // MARK: - Render to NSImage (image-coordinate space)
    //
    //  Canvas coords are in the *scaled* display space (canvasSize).
    //  To paint on the full-resolution NSImage we apply:
    //      imagePoint = canvasPoint / scaleRatio
    //  Y is flipped because NSImage origin is bottom-left.

    private func renderAnnotatedImage() -> NSImage {
        let size  = image.size
        let ratio = scaleRatio

        let imageRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide:   Int(size.width),
            pixelsHigh:   Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha:   true,
            isPlanar:   false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: imageRep)

        image.draw(in: NSRect(origin: .zero, size: size))

        for path in paths {
            drawAnnotationPathOnImage(path, ratio: ratio, imageSize: size)
        }

        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: size)
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

        case .mosaic:
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

        case .text:
            if let text = path.text, let pt = path.points.first {
                let ip       = canvasToImage(pt, ratio: ratio, imageHeight: h)
                let fontSize = (path.width * 3) / ratio
                let attrs: [NSAttributedString.Key: Any] = [
                    .font:            NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                    .foregroundColor: nsColor
                ]
                NSAttributedString(string: text, attributes: attrs)
                    .draw(at: NSPoint(x: ip.x, y: ip.y - fontSize))
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
