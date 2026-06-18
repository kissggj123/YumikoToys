import Foundation
import AppKit
import UserNotifications
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import ScreenCaptureKit

@MainActor
final class ScreenMediaHelper: ObservableObject {
    static let shared = ScreenMediaHelper()

    @Published var isRecording = false
    private var recordProcess: Process?
    private var currentRecordURL: URL?

    private var activeProcesses: [Process] = []

    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    private var floatingWindows: [UUID: NSWindow] = [:]
    private var selectionWindow: NSWindow?

    private init() {}

    // MARK: - Permission Guard
    
    /// 拦截录屏权限，防止 macOS 的 TCC 安全机制在授权后强行 Kill 掉我们的 App
    private func requireScreenCapturePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        } else {
            // 如果尚未授权，向系统请求授权弹窗
            CGRequestScreenCaptureAccess()
            
            // 提醒用户，如果不重启就强行截图会导致闪退
            notify(title: "需要录屏权限", body: "请在系统设置中允许录屏。授权后【必须完全退出并重新打开软件】才能生效，否则系统保护机制将导致闪退！")
            return false
        }
    }

    static func openScreenRecordingSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        if let url = URL(string: urlString) {
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

    // MARK: - Output Mode

    private var outputMode: ScreenshotOutputMode {
        DependencyContainer.shared.settingsService.settings.screenshotOutputMode
    }

    // MARK: - Image Saving
    
    private func saveCGImageAsPNG(_ cgImage: CGImage, to path: String) {
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
    }

    // MARK: - screencapture runner (Async/Await)

    private func runScreencapture(args: [String]) async -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args
        process.standardError = FileHandle.nullDevice
        
        self.activeProcesses.append(process)

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                if proc.terminationStatus != 0 {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: args.last)
                }
                Task { @MainActor in
                    self.activeProcesses.removeAll(where: { $0 === proc })
                }
            }

            do {
                try process.run()
            } catch {
                Task { @MainActor in
                    self.notify(title: "截图失败", body: "无法运行 screencapture：\(error.localizedDescription)")
                    self.activeProcesses.removeAll(where: { $0 === process })
                }
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - ScreenCaptureKit Display Helper

    private func getSCDisplay(for screen: NSScreen) async throws -> SCDisplay {
        let content = try await SCShareableContent.current
        
        // 修复潜在崩溃：先安全转为 NSNumber 再获取 uint32 值
        guard let screenNumber = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else {
            throw NSError(domain: "ScreenMediaHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法识别屏幕标识"])
        }
        guard let display = content.displays.first(where: { $0.displayID == screenNumber }) else {
            throw NSError(domain: "ScreenMediaHelper", code: 2, userInfo: [NSLocalizedDescriptionKey: "未找到对应的系统显示器"])
        }
        return display
    }

    // MARK: - Area Capture

    func captureArea() {
        guard requireScreenCapturePermission() else { return }
        
        guard !NSScreen.screens.isEmpty else {
            notify(title: "截图失败", body: "无法获取屏幕信息")
            return
        }
        showSelectionOverlay()
    }

    private func showSelectionOverlay() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

        let overlay = AreaSelectionOverlayView { [weak self] rect in
            guard let self else { return }
            self.selectionWindow?.orderOut(nil)
            
            guard !rect.isEmpty, rect.width > 2, rect.height > 2 else {
                self.selectionWindow?.close()
                self.selectionWindow = nil
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.captureAreaWithRect(rect, on: screen)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.selectionWindow?.close()
                    self.selectionWindow = nil
                }
            }
        }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.level = .screenSaver + 1
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: overlay)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        selectionWindow = window
    }

    private func captureAreaWithRect(_ rect: NSRect, on screen: NSScreen) {
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath

        Task {
            do {
                let display = try await getSCDisplay(for: screen)
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                // 不指定 width 和 height，以截取最原生的物理像素分辨率
                config.showsCursor = false
                // 使用苹果专业色域 Display P3，同时保持 32BGRA 格式，完美兼容广色域且防止 HDR 格式导致的裁剪崩溃
                config.colorSpaceName = CGColorSpace.displayP3
                config.pixelFormat = kCVPixelFormatType_32BGRA
                
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                
                let scale = CGFloat(cgImage.width) / CGFloat(screen.frame.width)
                let cropRect = CGRect(
                    x: rect.minX * scale,
                    y: rect.minY * scale,
                    width: rect.width * scale,
                    height: rect.height * scale
                ).integral // 四舍五入到整数像素
                
                // 【关键防崩点】通过取交集，确保剪裁区域绝对不会越界，否则 cgImage.cropping 会崩溃
                let imageRect = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
                let safeCropRect = cropRect.intersection(imageRect)
                
                guard safeCropRect.width > 0, safeCropRect.height > 0,
                      let croppedImage = cgImage.cropping(to: safeCropRect) else {
                    notify(title: "截图失败", body: "图像裁剪过程失败。")
                    return
                }
                
                let image = NSImage(cgImage: croppedImage, size: rect.size)
                self.saveCGImageAsPNG(croppedImage, to: resolved)
                self.showPreviewWindow(image: image)

                switch self.outputMode {
                case .clipboardOnly, .both:
                    self.copyFileToClipboard(path: resolved)
                    if self.outputMode == .both { fallthrough }
                default:
                    if self.outputMode != .clipboardOnly {
                        self.notify(title: "截图成功", body: "截图已保存至桌面")
                    }
                }
            } catch {
                self.notify(title: "捕获异常", body: "未获得权限或捕获受阻：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - Fullscreen Capture

    func captureFullscreen() {
        guard requireScreenCapturePermission() else { return }
        
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        
        Task {
            do {
                let display = try await getSCDisplay(for: screen)
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                // 不指定 width 和 height，以截取最原生的物理像素分辨率
                config.showsCursor = false
                config.colorSpaceName = CGColorSpace.displayP3
                config.pixelFormat = kCVPixelFormatType_32BGRA
                
                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                let image = NSImage(cgImage: cgImage, size: screen.frame.size)
                
                self.saveCGImageAsPNG(cgImage, to: resolved)
                self.showPreviewWindow(image: image)

                switch self.outputMode {
                case .clipboardOnly, .both:
                    self.copyFileToClipboard(path: resolved)
                    if self.outputMode == .both { fallthrough }
                default:
                    if self.outputMode != .clipboardOnly {
                        self.notify(title: "截图成功", body: "屏幕截图已保存至桌面")
                    }
                }
            } catch {
                self.notify(title: "捕获异常", body: "未获得权限或捕获受阻：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - TouchBar Capture

    func captureTouchBar() {
        Task {
            let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
            var args = ["-b"]
            if outputMode == .clipboardOnly { args.append("-c") }
            args.append(resolved)

            if let path = await runScreencapture(args: args) {
                if outputMode == .both {
                    copyFileToClipboard(path: resolved)
                } else {
                    notify(title: "TouchBar 截图成功", body: "截图已保存至桌面")
                }
            }
        }
    }

    // MARK: - Multi-Screen Capture

    func captureAllScreens() {
        guard requireScreenCapturePermission() else { return }
        
        Task {
            var capturedImages: [(screen: NSScreen, image: NSImage, index: Int)] = []
            
            do {
                let content = try await SCShareableContent.current
                
                for (index, screen) in NSScreen.screens.enumerated() {
                    guard let screenNumber = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
                          let display = content.displays.first(where: { $0.displayID == screenNumber }) else {
                        continue
                    }
                    
                    let filter = SCContentFilter(display: display, excludingWindows: [])
                    let config = SCStreamConfiguration()
                    // 不指定 width 和 height，以截取最原生的物理像素分辨率
                    config.showsCursor = false
                    config.colorSpaceName = CGColorSpace.displayP3
                    config.pixelFormat = kCVPixelFormatType_32BGRA
                    
                    if let cgImage = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) {
                        let image = NSImage(cgImage: cgImage, size: screen.frame.size)
                        capturedImages.append((screen: screen, image: image, index: index + 1))
                    }
                }
                
                guard !capturedImages.isEmpty else {
                    notify(title: "截图失败", body: "无法获取屏幕图像，请检查系统录屏权限")
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
                notify(title: "截图失败", body: "获取屏幕权限异常：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        // 由于录像使用的是 screencapture，它也需要权限保护
        guard requireScreenCapturePermission() else { return }
        
        guard !isRecording else { return }
        let resolved = (defaultPath(isMovie: true) as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-V", "999999", resolved]
        process.standardError = FileHandle.nullDevice
        
        self.activeProcesses.append(process)
        
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self = self else { return }
                self.activeProcesses.removeAll(where: { $0 === proc })
                if proc.terminationStatus != 0 {
                    self.notify(title: "录屏异常终止", body: "请检查空间或权限设置")
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
            notify(title: "录屏失败", body: "无法运行进程：\(error.localizedDescription)")
            self.activeProcesses.removeAll(where: { $0 === process })
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
        guard requireScreenCapturePermission() else { return }
        Task {
            let tempPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("annotation_\(Self.filenameFormatter.string(from: Date())).png")

            if let path = await runScreencapture(args: ["-i", "-o", tempPath]) {
                openAnnotationEditor(imagePath: path)
            }
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
        notify(title: "已复制到剪贴板", body: "截图已成功放入剪贴板")
    }

    // MARK: - Preview Windows

    private func showPreviewWindow(image: NSImage?) {
        guard let image else { return }
        let id = UUID()
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
}

// MARK: - Area Selection Overlay

struct AreaSelectionOverlayView: View {
    let onCapture: (NSRect) -> Void
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let start = startPoint, let end = currentPoint {
                    let rect = CGRect(
                        x: min(start.x, end.x),
                        y: min(start.y, end.y),
                        width: abs(end.x - start.x),
                        height: abs(end.y - start.y)
                    )
                    
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: geo.size))
                        path.addRect(rect)
                    }
                    .fill(Color.black.opacity(0.4), style: FillStyle(eoFill: true))

                    Rectangle()
                        .stroke(Color.white, lineWidth: 1.5)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    Text("\(Int(rect.width)) × \(Int(rect.height))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .position(x: rect.midX, y: max(20, rect.minY - 14))
                } else {
                    // 没有划线之前，只显示一层基础蒙版
                    Color.black.opacity(0.4)
                }
            }
            .contentShape(Rectangle()) // 确保透明区域也能吃到手势
            .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if startPoint == nil {
                                        startPoint = value.startLocation
                                    }
                                    currentPoint = value.location
                                }
                                .onEnded { value in
                                    if let start = startPoint {
                                        let end = value.location
                                        let finalRect = NSRect(
                                            x: min(start.x, end.x),
                                            y: min(start.y, end.y),
                                            width: abs(end.x - start.x),
                                            height: abs(end.y - start.y)
                                        )
                                        startPoint = nil
                                        currentPoint = nil
                                        
                                        // 【关键修复点】：放到下一个主线程周期去执行外部回调，防止在 SwiftUI Gesture 内部发生窗口卸载
                                        DispatchQueue.main.async {
                                            onCapture(finalRect)
                                        }
                                    } else {
                                        startPoint = nil
                                        currentPoint = nil
                                    }
                                }
                        )
            .onKeyPress(.escape) {
                startPoint = nil
                currentPoint = nil
                onCapture(.zero)
                return .handled
            }
        }
        .ignoresSafeArea()
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
