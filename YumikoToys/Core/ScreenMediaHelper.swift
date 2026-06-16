//
//  ScreenMediaHelper.swift
//  YumikoToys
//
//  截图与录屏助手 (v7.0.0 - 重构：提取公共逻辑 / 修复窗口持有 / 缓存 Formatter)
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
    private var lastSettingsOpenTime: Date = .distantPast

    // 缓存 DateFormatter，避免每次创建
    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    private static let tempFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss_SSS"
        return f
    }()

    // 持有浮动预览窗口，防止提前释放
    private var floatingWindows: [ObjectIdentifier: NSWindow] = [:]

    private init() {}

    // MARK: - Permission

    static func openScreenRecordingSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Paths

    private func defaultPath(isMovie: Bool) -> String {
        let suffix = Self.filenameFormatter.string(from: Date())
        let filename = isMovie ? "recording_\(suffix).mov" : "screenshot_\(suffix).png"
        let desktop = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first
            ?? NSTemporaryDirectory()
        return (desktop as NSString).appendingPathComponent(filename)
    }

    private func annotationTempPath() -> String {
        let suffix = Self.tempFormatter.string(from: Date())
        return (NSTemporaryDirectory() as NSString).appendingPathComponent("annotation_\(suffix).png")
    }

    // MARK: - Common screencapture execution

    /// 执行 screencapture 命令，成功后通过 completion 返回临时文件路径
    private func runScreencapture(args: [String],
                                  completion: @escaping (String?) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self = self else { return }
                if proc.terminationStatus != 0 {
                    // 从 arguments 中提取临时路径（最后一个参数通常是输出路径）
                    let tempPath = args.last
                    self.handleScreencaptureFailure(exitCode: proc.terminationStatus, tempPath: tempPath)
                    completion(nil)
                    return
                }
                completion(args.last)
            }
        }

        do {
            try process.run()
        } catch {
            LoggerService.shared.error("Failed to run screencapture: \(error)")
            notify(title: "截图失败", body: "无法运行 screencapture：\(error.localizedDescription)")
            completion(nil)
        }
    }

    // MARK: - Common output handling

    /// 根据 outputMode 处理截图结果
    private func handleCaptureOutput(tempPath: String,
                                     resolvedPath: String,
                                     showPreview image: NSImage? = nil) {
        let mode = DependencyContainer.shared.settingsService.settings.screenshotOutputMode

        if let image = image {
            showPreviewWindow(image: image)
        }

        switch mode {
        case .clipboardOnly:
            copyFileToClipboard(path: tempPath)
            try? FileManager.default.removeItem(atPath: tempPath)

        case .fileOnly:
            try? FileManager.default.moveItem(atPath: tempPath, toPath: resolvedPath)
            notify(title: "截图成功", body: "截图已保存至桌面")

        case .both:
            try? FileManager.default.copyItem(atPath: tempPath, toPath: resolvedPath)
            copyFileToClipboard(path: resolvedPath)
            try? FileManager.default.removeItem(atPath: tempPath)
        }
    }

    private func handleScreencaptureFailure(exitCode: Int32, tempPath: String?) {
        if let temp = tempPath, FileManager.default.fileExists(atPath: temp) {
            return
        }
        if exitCode == 1 {
            return // 用户取消
        }
        LoggerService.shared.error("screencapture 非 0 退出 (exit=\(exitCode))")
        notify(title: "截图/录屏可能需要权限",
               body: "若重复失败，请检查系统设置 → 隐私与安全性 → 屏幕录制")
        let now = Date()
        if now.timeIntervalSince(lastSettingsOpenTime) > 5 {
            lastSettingsOpenTime = now
            Self.openScreenRecordingSettings()
        }
    }

    // MARK: - Area Capture

    func captureArea() {
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        let tempPath = (annotationTempPath() as NSString).expandingTildeInPath

        runScreencapture(args: ["-i", tempPath]) { [weak self] path in
            guard let self, let path else { return }
            let image = NSImage(contentsOfFile: path)
            self.handleCaptureOutput(tempPath: path, resolvedPath: resolved, showPreview: image)
        }
    }

    // MARK: - Fullscreen Capture

    func captureFullscreen() {
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        let tempPath = (annotationTempPath() as NSString).expandingTildeInPath

        runScreencapture(args: [tempPath]) { [weak self] path in
            guard let self, let path else { return }
            let image = NSImage(contentsOfFile: path)
            self.handleCaptureOutput(tempPath: path, resolvedPath: resolved, showPreview: image)
        }
    }

    // MARK: - TouchBar Capture

    func captureTouchBar() {
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        var args = ["-b"]
        if DependencyContainer.shared.settingsService.settings.screenshotOutputMode == .clipboardOnly {
            args.append("-c")
        }
        args.append(resolved)

        runScreencapture(args: args) { [weak self] path in
            guard let self, let path else { return }
            if self.outputMode == .both {
                self.copyFileToClipboard(path: path)
            } else {
                self.notify(title: "TouchBar 截图成功", body: "截图已保存至桌面")
            }
        }
    }

    // MARK: - Multi-Screen Capture (ScreenCaptureKit)

    func captureAllScreens() {
        Task { await captureAllScreensAsync() }
    }

    private func captureAllScreensAsync() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false)
            let scDisplays = content.displays

            guard !scDisplays.isEmpty else {
                notify(title: "截图失败", body: "无法枚举屏幕。请检查屏幕录制权限")
                Self.openScreenRecordingSettings()
                return
            }

            var capturedImages: [(screen: NSScreen, image: NSImage, index: Int)] = []

            for (index, scDisplay) in scDisplays.enumerated() {
                guard let matchedScreen = NSScreen.screens.first(where: { screen in
                    let did = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                    return did == scDisplay.displayID
                }) ?? NSScreen.main ?? NSScreen.screens.first else { continue }

                let backingScale = matchedScreen.backingScaleFactor
                let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width  = Int(Double(scDisplay.width) * Double(backingScale))
                config.height = Int(Double(scDisplay.height) * Double(backingScale))
                config.showsCursor = false
                config.colorSpaceName = CGColorSpace.displayP3

                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config)

                let nsImage = NSImage(cgImage: cgImage, size: matchedScreen.frame.size)
                capturedImages.append((screen: matchedScreen, image: nsImage, index: index + 1))
            }

            guard !capturedImages.isEmpty else {
                notify(title: "截图失败", body: "无法获取屏幕图像。请检查屏幕录制权限")
                Self.openScreenRecordingSettings()
                return
            }

            if capturedImages.count == 1 {
                let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
                let img = capturedImages[0].image
                _ = img.savePNG(to: resolved)
                showPreviewWindow(image: img)

                if outputMode == .clipboardOnly || outputMode == .both {
                    copyFileToClipboard(path: resolved)
                } else {
                    notify(title: "截图成功", body: "屏幕截图已保存至桌面")
                }
            } else {
                openMultiScreenPreview(capturedImages)
            }

        } catch {
            LoggerService.shared.error("captureAllScreens failed: \(error)")
            let ns = error as NSError
            let msg = ns.localizedDescription
            let isPermission = msg.lowercased().contains("permission")
                || msg.lowercased().contains("权限")
                || String(ns.domain).lowercased().contains("scstream")
            if isPermission {
                notify(title: "需要屏幕录制权限",
                       body: "请在系统设置 → 隐私与安全性 → 屏幕录制中授予权限后重试")
                Self.openScreenRecordingSettings()
            } else {
                notify(title: "截图失败", body: "错误：\(msg)")
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        let resolved = (defaultPath(isMovie: true) as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-V", "999999", resolved]
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self = self else { return }
                if proc.terminationStatus != 0 {
                    self.handleScreencaptureFailure(exitCode: proc.terminationStatus, tempPath: nil)
                }
            }
        }
        do {
            try process.run()
            self.recordProcess = process
            self.isRecording = true
            self.currentRecordURL = URL(fileURLWithPath: resolved)
            notify(title: "录屏已开始", body: "正在录制，点击状态栏按钮可停止")
        } catch {
            LoggerService.shared.error("Failed to start screen recording: \(error)")
            notify(title: "录屏失败", body: "无法运行 screencapture：\(error.localizedDescription)")
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

    // MARK: - Annotation

    func openScreenshotAnnotation() {
        let tempPath = (annotationTempPath() as NSString).expandingTildeInPath

        runScreencapture(args: ["-i", "-o", tempPath]) { [weak self] path in
            guard let self, let path else { return }
            self.openAnnotationEditor(imagePath: path)
        }
    }

    // MARK: - Clipboard

    private func copyFileToClipboard(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            pasteboard.setData(data, forType: .png)
        }

        let url = URL(fileURLWithPath: path)
        pasteboard.writeObjects([url as NSURL])
        notify(title: "已复制到剪贴板", body: "截图已复制到剪贴板")
    }

    // MARK: - Preview Windows

    private func showPreviewWindow(image: NSImage) {
        let id = ObjectIdentifier(UUID())
        let window = FloatingScreenshotPreviewWindow(image: image) { [weak self] in
            self?.floatingWindows.removeValue(forKey: id)
        }
        floatingWindows[id] = window
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

    // MARK: - Notification

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
}

// MARK: - Floating Screenshot Preview Window

final class FloatingScreenshotPreviewWindow: NSWindow {
    private let onClose: () -> Void

    init(image: NSImage, duration: TimeInterval = 3.0, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let screenFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)

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
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                self.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                self?.close()
            }
        }
    }

    override func close() {
        super.close()
        onClose()
    }
}

struct FloatingPreviewContentView: View {
    let image: NSImage
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.keyWindow?.close() }
                }
                .buttonStyle(.bordered)

                Button("复制到剪贴板") {
                    if let idx = selectedIndex,
                       let item = screens.first(where: { $0.index == idx }) {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.writeObjects([item.image])
                        NSApp.keyWindow?.close()
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
