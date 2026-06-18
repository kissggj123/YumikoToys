import Foundation
import AppKit
import UserNotifications
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers

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

    // Removed ScreenCaptureKit Display Helper

    // MARK: - Area Capture

    func captureArea() {
        Task {
            let isTemp = (outputMode == .clipboardOnly)
            let resolved = isTemp ? (NSTemporaryDirectory() as NSString).appendingPathComponent("temp_area_\(UUID().uuidString).png") : (defaultPath(isMovie: false) as NSString).expandingTildeInPath
            
            // -i: 交互式区域选择, -x: 静音
            let args = ["-i", "-x", resolved]

            if let path = await runScreencapture(args: args), FileManager.default.fileExists(atPath: path) {
                if let image = NSImage(contentsOfFile: path) {
                    showPreviewWindow(image: image)
                }
                
                switch outputMode {
                case .clipboardOnly:
                    copyFileToClipboard(path: path)
                case .both:
                    copyFileToClipboard(path: path)
                    fallthrough
                default:
                    if outputMode != .clipboardOnly {
                        notify(title: "截图成功", body: "截图已保存至桌面")
                    }
                }
            }
        }
    }

    // MARK: - Fullscreen Capture

    func captureFullscreen() {
        Task {
            let isTemp = (outputMode == .clipboardOnly)
            let resolved = isTemp ? (NSTemporaryDirectory() as NSString).appendingPathComponent("temp_full_\(UUID().uuidString).png") : (defaultPath(isMovie: false) as NSString).expandingTildeInPath
            
            // -m: 主屏幕, -x: 静音
            let args = ["-m", "-x", resolved]
            
            if let path = await runScreencapture(args: args), FileManager.default.fileExists(atPath: path) {
                if let image = NSImage(contentsOfFile: path) {
                    showPreviewWindow(image: image)
                }
                
                switch outputMode {
                case .clipboardOnly:
                    copyFileToClipboard(path: path)
                case .both:
                    copyFileToClipboard(path: path)
                    fallthrough
                default:
                    if outputMode != .clipboardOnly {
                        notify(title: "截图成功", body: "截图已保存至桌面")
                    }
                }
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
        Task {
            let isTemp = (outputMode == .clipboardOnly)
            let baseName = "temp_all_\(UUID().uuidString)"
            let resolved = isTemp ? (NSTemporaryDirectory() as NSString).appendingPathComponent("\(baseName).png") : (defaultPath(isMovie: false) as NSString).expandingTildeInPath
            
            // screencapture -x 对多屏幕会自动添加 " 1", " 2" 等后缀，如果只有一个屏幕则不加后缀
            let args = ["-x", resolved]
            
            if let _ = await runScreencapture(args: args) {
                // 寻找生成的文件
                let fileManager = FileManager.default
                let dir = (resolved as NSString).deletingLastPathComponent
                let name = (resolved as NSString).lastPathComponent
                let nameWithoutExt = (name as NSString).deletingPathExtension
                let ext = (name as NSString).pathExtension
                
                var capturedImages: [(screen: NSScreen, image: NSImage, index: Int)] = []
                
                // 优先检查单个屏幕的情况
                if fileManager.fileExists(atPath: resolved) {
                    if let img = NSImage(contentsOfFile: resolved) {
                        capturedImages.append((screen: NSScreen.screens.first!, image: img, index: 1))
                    }
                } else {
                    // 多屏幕情况: screencapture 会生成 name 1.png, name 2.png
                    for (index, screen) in NSScreen.screens.enumerated() {
                        let multiPath = (dir as NSString).appendingPathComponent("\(nameWithoutExt) \(index + 1).\(ext)")
                        if fileManager.fileExists(atPath: multiPath) {
                            if let img = NSImage(contentsOfFile: multiPath) {
                                capturedImages.append((screen: screen, image: img, index: index + 1))
                            }
                        }
                    }
                }
                
                guard !capturedImages.isEmpty else {
                    notify(title: "截图失败", body: "未能找到多屏截图文件")
                    return
                }

                if capturedImages.count == 1 {
                    let img = capturedImages[0].image
                    showPreviewWindow(image: img)
                    let finalPath = isTemp ? ((NSTemporaryDirectory() as NSString).appendingPathComponent("\(baseName).png")) : resolved
                    // 如果是单屏，有可能生成的名字是带 1 的，所以重命名为 resolved
                    if !fileManager.fileExists(atPath: resolved) {
                        let multiPath = (dir as NSString).appendingPathComponent("\(nameWithoutExt) 1.\(ext)")
                        try? fileManager.moveItem(atPath: multiPath, toPath: resolved)
                    }

                    if outputMode == .clipboardOnly || outputMode == .both {
                        copyFileToClipboard(path: resolved)
                    } else {
                        notify(title: "截图成功", body: "屏幕截图已保存至桌面")
                    }
                } else {
                    openMultiScreenPreview(capturedImages)
                    // 对于多屏，我们这里暂时不将所有图都塞入剪贴板，因为剪贴板处理多图比较复杂，直接提示成功
                    notify(title: "多屏截图", body: "已捕获 \(capturedImages.count) 个屏幕的截图")
                }
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

// Custom overlay view completely removed in favor of native screencapture -i

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
