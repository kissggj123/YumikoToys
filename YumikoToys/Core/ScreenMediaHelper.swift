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

// 截图标注工具视图（新实现）
//
// 详细代码见 ScreenshotAnnotationModule.swift：
//  - 使用 MosaicRenderer 真像素化/高斯模糊（CIImage + CIFilter）
//  - 文字/编号：点击定位 → sheet 编辑 → 拖动重定位
//  - 撤销 / 重做 栈
//
// 这里保留 `PinnedAnnotationView`（在本文件内联实现）以保持二进制兼容。

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
