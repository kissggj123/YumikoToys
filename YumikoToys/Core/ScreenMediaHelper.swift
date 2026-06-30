import Foundation
import AppKit
import UserNotifications
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers
import ScreenCaptureKit
import AVFoundation

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

    // MARK: - 公开结果类型

    /// 截图/录屏操作的统一返回结果（给 YumiScriptEngine 等调用方用）
    struct CaptureResult: Sendable, Equatable {
        enum Status: String, Sendable, Equatable {
            case success
            case cancelled   // 用户取消
            case denied      // 权限被拒
            case failed      // 其他失败
        }
        let status: Status
        let path: String?         // 截图 / 录屏产物路径（成功时必有）
        let message: String       // 给用户看的中文消息
        var isSuccess: Bool { status == .success }
    }

    // MARK: - Permission Guard

    /// 主动尝试申请屏幕录制权限（不卡住流程）。
    /// 不再当作 hard gate —— TCC 在授权后第一次调用 screencapture 才会激活，
    /// 所以应"尝试 + 失败时引导"，而不是"未通过就拒绝执行"。
    @discardableResult
    private func requestScreenCaptureIfNeeded() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        // 第一次：主动拉起系统的授权弹窗
        CGRequestScreenCaptureAccess()
        return false
    }

    /// 截图/录屏失败时统一处理：
    ///   1) 在控制台 / 通知解释原因
    ///   2) 提示用户去系统设置
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
        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.displayP3)!
        let properties: [CFString: Any] = [
            kCGImagePropertyColorModel: "RGB",
            kCGImagePropertyProfileName: colorSpace.name ?? "Display P3"
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
    }

    // MARK: - screencapture runner (Async/Await)

    /// 执行 /usr/sbin/screencapture 并返回 (退出码, stderr)
    /// 退出码语义：
    ///   0  = 成功
    ///   1  = 用户取消（-i 模式按 Esc / 取消选择）
    ///   其他 = 失败（权限不足、参数错误等）
    private func runScreencapture(args: [String]) async -> (exitCode: Int32, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = FileHandle.nullDevice

        self.activeProcesses.append(process)

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrStr = String(data: stderrData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                Task { @MainActor in
                    self.activeProcesses.removeAll(where: { $0 === proc })
                }
                continuation.resume(returning: (proc.terminationStatus, stderrStr))
            }

            do {
                try process.run()
            } catch {
                Task { @MainActor in
                    self.notify(title: "截图失败", body: "无法运行 screencapture：\(error.localizedDescription)")
                    self.activeProcesses.removeAll(where: { $0 === process })
                }
                continuation.resume(returning: (-1, error.localizedDescription))
            }
        }
    }

    // MARK: - 异步公开 API（给 YumiScript / 自动脚本用）

    /// 全屏截图（返回结构化结果）
    func captureFullscreenAsync(targetPath: String? = nil) async -> CaptureResult {
        // 1) 先尝试拉起授权弹窗
        requestScreenCaptureIfNeeded()

        // 2) 准备路径：传入 > 桌面默认
        let resolved: String
        if let target = targetPath {
            resolved = (target as NSString).expandingTildeInPath
        } else {
            resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        }

        // 确保父目录存在
        ensureParentDirectoryExists(for: resolved)

        // 3) 调 screencapture
        let args = ["-m", "-x", resolved]
        let (code, stderr) = await runScreencapture(args: args)

        // 4) 结果判定
        switch code {
        case 0:
            if FileManager.default.fileExists(atPath: resolved) {
                return CaptureResult(status: .success, path: resolved,
                                     message: "全屏截图已保存：\(resolved)")
            } else {
                return CaptureResult(status: .failed, path: nil,
                                     message: "screencapture 退出 0 但文件未生成：\(stderr)")
            }
        case 1:
            return CaptureResult(status: .cancelled, path: nil,
                                 message: "已取消截图")
        default:
            // 权限不足的特征：进程被 kill 或 stderr 含 "denied" / "permission"
            let lower = stderr.lowercased()
            let denied = lower.contains("denied") || lower.contains("permission") || code == -1
            if denied {
                return CaptureResult(status: .denied, path: nil,
                                     message: "屏幕录制权限被拒绝。请到 系统设置 → 隐私与安全性 → 屏幕录制 中开启本应用。")
            }
            return CaptureResult(status: .failed, path: nil,
                                 message: "截图失败（退出码 \(code)）：\(stderr.isEmpty ? "无错误信息" : stderr)")
        }
    }

    /// 区域截图（交互式），返回结构化结果
    func captureAreaAsync() async -> CaptureResult {
        requestScreenCaptureIfNeeded()
        let resolved = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("area_\(Self.filenameFormatter.string(from: Date())).png")
        ensureParentDirectoryExists(for: resolved)
        let args = ["-i", "-x", resolved]
        let (code, stderr) = await runScreencapture(args: args)
        switch code {
        case 0:
            if FileManager.default.fileExists(atPath: resolved) {
                return CaptureResult(status: .success, path: resolved,
                                     message: "区域截图已保存：\(resolved)")
            } else {
                return CaptureResult(status: .failed, path: nil, message: "截图未生成文件")
            }
        case 1:
            return CaptureResult(status: .cancelled, path: nil, message: "已取消区域截图")
        default:
            return CaptureResult(status: .failed, path: nil,
                                 message: "区域截图失败（退出码 \(code)）：\(stderr.isEmpty ? "无错误信息" : stderr)")
        }
    }

    /// 开始录屏（异步，限时）—— 给脚本调用方用
    /// - Parameter seconds: 录屏时长（秒）
    /// - Parameter outputPath: 输出 .mov 路径，默认桌面
    /// - Parameter includeAudio: 是否同时录系统音频（true 会触发"麦克风/音频"权限弹窗，默认 false）
    /// - Returns: 结构化结果（含最终文件路径或失败原因）
    ///
    /// 实现说明：
    ///   用 `screencapture -v <path>` 启动视频录制（不录音频），等 N 秒后用 interrupt 结束。
    ///   这种方式只触发「屏幕录制」一项授权，不会触发「麦克风/系统音频」授权。
    func recordForDuration(seconds: Int,
                           outputPath: String? = nil,
                           includeAudio: Bool = false) async -> CaptureResult {
        requestScreenCaptureIfNeeded()

        let resolved: String
        if let outputPath = outputPath {
            resolved = (outputPath as NSString).expandingTildeInPath
        } else {
            resolved = (defaultPath(isMovie: true) as NSString).expandingTildeInPath
        }
        ensureParentDirectoryExists(for: resolved)

        // 关键：用 -v 启动视频录制（不录音频，避免触发音频 TCC 弹窗）
        // -A 单独追加只在 includeAudio=true 时
        // screencapture -V999999 旧的写法不仅会录音频还会弹"screen and audio"那种双授权弹窗
        var args: [String] = ["-v"]
        if includeAudio {
            args.append("-A")  // 系统音频（会触发音频权限）
        }
        args.append(resolved)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args
        process.standardError = FileHandle.nullDevice

        self.activeProcesses.append(process)
        self.recordProcess = process
        self.isRecording = true
        self.currentRecordURL = URL(fileURLWithPath: resolved)

        do {
            try process.run()
        } catch {
            self.activeProcesses.removeAll(where: { $0 === process })
            self.isRecording = false
            self.recordProcess = nil
            return CaptureResult(status: .failed, path: nil,
                                 message: "无法启动录屏：\(error.localizedDescription)")
        }

        // 给用户清晰反馈：录屏已开始
        notify(title: "录屏已开始",
               body: "正在录制 \(seconds) 秒（不录音频）。录制过程中请勿关闭此应用。\n如弹出屏幕录制授权，请点「Open System Settings」→ 找到 YumikoToys 打开开关 → 完全退出本 App 再重新打开即可。")

        // 等待指定时长（不要 sleep 太短，否则 .mov 文件还没写入就结束了）
        try? await Task.sleep(nanoseconds: UInt64(max(1, seconds)) * 1_000_000_000)

        // 主动 interrupt（SIGINT = 用户按 Ctrl-C；screencapture 收到后会正确封口 mov 文件）
        if process.isRunning {
            process.interrupt()
            process.waitUntilExit()
        }

        self.recordProcess = nil
        self.isRecording = false
        self.activeProcesses.removeAll(where: { $0 === process })

        if FileManager.default.fileExists(atPath: resolved) {
            return CaptureResult(status: .success, path: resolved,
                                 message: "录屏完成（\(seconds) 秒）：\(resolved)")
        } else {
            return CaptureResult(
                status: .denied, path: nil,
                message: """
                录屏未生成文件——极可能是「屏幕录制」权限未开启。

                【一键解决】系统设置 → 隐私与安全性 → 屏幕录制 → 找到 YumikoToys → 开关滑过一遍（开→关）→ 完全退出本 App → 重新打开后再试。
                """
            )
        }
    }

    /// 把 YumiScript 给的路径展开、确保父目录存在。
    /// 解决 `screencapture "~/Desktop/x.png"` 因 `~` 没展开直接失败的问题。
    private func ensureParentDirectoryExists(for path: String) {
        let expanded = (path as NSString).expandingTildeInPath
        let parent = (expanded as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: parent) {
            try? FileManager.default.createDirectory(
                atPath: parent, withIntermediateDirectories: true)
        }
    }

    // Removed ScreenCaptureKit Display Helper

    // MARK: - Area Capture

    func captureArea() {
        requestScreenCaptureIfNeeded()
        Task {
            let isTemp = (outputMode == .clipboardOnly)
            let resolved = isTemp ? (NSTemporaryDirectory() as NSString).appendingPathComponent("temp_area_\(UUID().uuidString).png") : (defaultPath(isMovie: false) as NSString).expandingTildeInPath
            ensureParentDirectoryExists(for: resolved)

            // -i: 交互式区域选择, -x: 静音
            let args = ["-i", "-x", resolved]

            let (code, stderr) = await runScreencapture(args: args)
            guard code == 0, FileManager.default.fileExists(atPath: resolved) else {
                if code == 1 {
                    // 用户取消 — 不打扰
                    return
                }
                let msg = stderr.isEmpty ? "请检查屏幕录制权限" : stderr
                notify(title: "区域截图失败", body: msg)
                if stderr.lowercased().contains("denied") || stderr.lowercased().contains("permission") {
                    Self.openScreenRecordingSettings()
                }
                return
            }

            if let image = NSImage(contentsOfFile: resolved) {
                showPreviewWindow(image: image)
            }

            switch outputMode {
            case .clipboardOnly:
                copyFileToClipboard(path: resolved)
            case .both:
                copyFileToClipboard(path: resolved)
                fallthrough
            default:
                if outputMode != .clipboardOnly {
                    notify(title: "截图成功", body: "截图已保存至桌面")
                }
            }
        }
    }

    // MARK: - Fullscreen Capture

    func captureFullscreen() {
        requestScreenCaptureIfNeeded()
        Task {
            let isTemp = (outputMode == .clipboardOnly)
            let resolved = isTemp ? (NSTemporaryDirectory() as NSString).appendingPathComponent("temp_full_\(UUID().uuidString).png") : (defaultPath(isMovie: false) as NSString).expandingTildeInPath
            ensureParentDirectoryExists(for: resolved)

            // -m: 主屏幕, -x: 静音
            let args = ["-m", "-x", resolved]

            let (code, stderr) = await runScreencapture(args: args)
            guard code == 0, FileManager.default.fileExists(atPath: resolved) else {
                if code == 1 { return }
                let msg = stderr.isEmpty ? "请检查屏幕录制权限" : stderr
                notify(title: "全屏截图失败", body: msg)
                if stderr.lowercased().contains("denied") || stderr.lowercased().contains("permission") {
                    Self.openScreenRecordingSettings()
                }
                return
            }

            if let image = NSImage(contentsOfFile: resolved) {
                showPreviewWindow(image: image)
            }

            switch outputMode {
            case .clipboardOnly:
                copyFileToClipboard(path: resolved)
            case .both:
                copyFileToClipboard(path: resolved)
                fallthrough
            default:
                if outputMode != .clipboardOnly {
                    notify(title: "截图成功", body: "截图已保存至桌面")
                }
            }
        }
    }

    // MARK: - TouchBar Capture
    //
    // 注意：Apple 从 2021 年起（macOS 12 / 14" MacBook Pro 取消 TouchBar），
    // 就不再有 TouchBar 硬件了。screencapture -b 在新机型上是 no-op。
    // 检测策略：
    //   1) ioreg 查 AppleEmbeddedOSSupportHost / AppleMCCopyControl
    //   2) system_profiler SPUSBDataType 查 Touch Bar（兜底）
    //   3) 都没有就提示用户

    /// 检测当前 Mac 是否有 TouchBar
    static func hasTouchBar() -> Bool {
        // 方法 1：通过 CGDisplay API 检测 TouchBar 虚拟显示器
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(16, &displayIDs, &count)
        for i in 0..<Int(count) {
            let bounds = CGDisplayBounds(displayIDs[i])
            if bounds.height < 100 && bounds.width > 100 {
                return true
            }
        }
        // 方法 2：直接尝试 screencapture -b 作为 fallback
        let testPath = NSTemporaryDirectory() + "touchbar_test_\(UUID().uuidString).png"
        _ = runShell("/usr/sbin/screencapture", ["-b", testPath])
        if FileManager.default.fileExists(atPath: testPath) {
            try? FileManager.default.removeItem(atPath: testPath)
            return true
        }
        return false
    }

    private static func runShell(_ path: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return "" }
        
        // 添加超时保护，防止进程挂起
        let deadline = Date().addingTimeInterval(10)
        while p.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        if p.isRunning {
            p.terminate()
            return ""
        }
        
        return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    func captureTouchBar() {
        // 先检测
        guard Self.hasTouchBar() else {
            notify(title: "TouchBar 不可用",
                   body: "当前 Mac 没有 Touch Bar 硬件（2021 年后的 MacBook Pro 已取消 TouchBar）。\n如果你确认有 TouchBar，请反馈给开发者。")
            return
        }

        requestScreenCaptureIfNeeded()
        Task {
            let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
            ensureParentDirectoryExists(for: resolved)
            var args = ["-b"]
            if outputMode == .clipboardOnly { args.append("-c") }
            args.append(resolved)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = args
            process.standardError = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            self.activeProcesses.append(process)

            do {
                try process.run()
            } catch {
                self.activeProcesses.removeAll(where: { $0 === process })
                self.notify(title: "TouchBar 截图失败", body: "无法运行 screencapture：\(error.localizedDescription)")
                return
            }

            // 15 秒超时（TouchBar 截图可能较慢）
            let deadline = Date().addingTimeInterval(15)
            while process.isRunning && Date() < deadline {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            if process.isRunning {
                process.terminate()
                self.notify(title: "TouchBar 截图超时", body: "screencapture 进程在 15 秒后仍未完成，已终止。")
                self.activeProcesses.removeAll(where: { $0 === process })
                return
            }
            self.activeProcesses.removeAll(where: { $0 === process })

            let code = process.terminationStatus
            if code == 0, FileManager.default.fileExists(atPath: resolved) {
                if let image = NSImage(contentsOfFile: resolved) {
                    showPreviewWindow(image: image)
                }
                if self.outputMode == .clipboardOnly || self.outputMode == .both {
                    self.copyFileToClipboard(path: resolved)
                }
                if self.outputMode != .clipboardOnly {
                    self.notify(title: "TouchBar 截图成功", body: "已保存到桌面：\(resolved)")
                }
            } else if code == 1 {
                // 用户取消 — 不提示
            } else {
                // screencapture -b 可能不支持，尝试 screencapture -c -b（复制到剪贴板）
                let fallbackArgs = ["-c", "-b"]
                let fallbackProcess = Process()
                fallbackProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                fallbackProcess.arguments = fallbackArgs
                fallbackProcess.standardError = FileHandle.nullDevice
                fallbackProcess.standardOutput = FileHandle.nullDevice
                self.activeProcesses.append(fallbackProcess)

                do {
                    try fallbackProcess.run()
                    let fallbackDeadline = Date().addingTimeInterval(10)
                    while fallbackProcess.isRunning && Date() < fallbackDeadline {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                    }
                    if fallbackProcess.isRunning {
                        fallbackProcess.terminate()
                    }
                    self.activeProcesses.removeAll(where: { $0 === fallbackProcess })

                    if fallbackProcess.terminationStatus == 0 {
                        self.notify(title: "TouchBar 截图成功", body: "TouchBar 截图已复制到剪贴板")
                    } else {
                        self.notify(title: "TouchBar 截图失败", body: "screencapture -b 不支持当前设备，请检查屏幕录制权限")
                        Self.openScreenRecordingSettings()
                    }
                } catch {
                    self.activeProcesses.removeAll(where: { $0 === fallbackProcess })
                    self.notify(title: "TouchBar 截图失败", body: "请检查屏幕录制权限")
                    Self.openScreenRecordingSettings()
                }
            }
        }
    }

    // MARK: - Multi-Screen Capture
    //
    // 优先使用 screencapture -D 截取所有显示器，然后用 NSScreen 坐标裁剪分屏。
    // 如果 screencapture -D 失败（权限不足等），回退到 ScreenCaptureKit 逐屏拍摄。

    func captureAllScreens() {
        requestScreenCaptureIfNeeded()

        Task {
            // 方案 A：screencapture -D 截取所有显示器（简单可靠）
            let allScreensPath = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("all_screens_\(Self.filenameFormatter.string(from: Date())).png")
            ensureParentDirectoryExists(for: allScreensPath)

            let (code, _) = await runScreencapture(args: ["-D", allScreensPath])

            if code == 0, FileManager.default.fileExists(atPath: allScreensPath),
               let fullImage = NSImage(contentsOfFile: allScreensPath) {
                // screencapture -D 成功：裁剪各屏幕
                await handleMultiScreenResult(fullImage: fullImage)
                try? FileManager.default.removeItem(atPath: allScreensPath)
                return
            }

            // 方案 B：ScreenCaptureKit 逐屏拍摄（回退）
            await captureAllScreensViaScreenCaptureKit()
        }
    }

    /// 处理 screencapture -D 的全屏结果，裁剪出各显示器区域
    private func handleMultiScreenResult(fullImage: NSImage) {
        let screens = NSScreen.screens
        guard screens.count > 1 else {
            // 单屏：直接预览
            showPreviewWindow(image: fullImage)
            notify(title: "多屏截图", body: "已捕获 1 个屏幕的截图")
            return
        }

        guard let fullRep = fullImage.representations.first,
              let fullCG = fullRep.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            notify(title: "多屏截图失败", body: "无法解析截图数据")
            return
        }

        let primaryFrame = screens.first?.frame ?? .zero
        let fullSize = fullImage.size

        var capturedImages: [(screen: NSScreen, image: NSImage, index: Int)] = []
        for (idx, screen) in screens.enumerated() {
            let frame = screen.frame
            let scale = screen.backingScaleFactor
            // NSScreen 坐标（左下角原点）→ CGImage 坐标（左上角原点）
            let x = (frame.origin.x - primaryFrame.origin.x) * scale
            let y = (primaryFrame.maxY - frame.maxY) * scale
            let w = frame.width * scale
            let h = frame.height * scale

            let cropRect = CGRect(x: x, y: y, width: w, height: h)
                .intersection(CGRect(origin: .zero, size: CGSize(width: fullSize.width * scale, height: fullSize.height * scale)))
                .intersection(CGRect(origin: .zero, size: CGSize(width: fullCG.width, height: fullCG.height)))

            guard cropRect.width > 0, cropRect.height > 0,
                  let cropped = fullCG.cropping(to: cropRect) else { continue }

            let nsImage = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
            capturedImages.append((screen: screen, image: nsImage, index: idx + 1))
        }

        guard !capturedImages.isEmpty else {
            notify(title: "多屏截图失败", body: "未能裁剪出任何屏幕")
            return
        }

        if capturedImages.count == 1 {
            showPreviewWindow(image: capturedImages[0].image)
        } else {
            openMultiScreenPreview(capturedImages)
        }
        notify(title: "多屏截图", body: "已捕获 \(capturedImages.count) 个屏幕的截图")
    }

    /// ScreenCaptureKit 逐屏拍摄（回退方案）
    private func captureAllScreensViaScreenCaptureKit() {
        Task {
            var capturedImages: [(screen: NSScreen, image: NSImage, index: Int)] = []
            let displayIDs = await Self.fetchDisplayIDsViaSC()

            guard !displayIDs.isEmpty else {
                await MainActor.run {
                    self.notify(title: "多屏截图失败", body: "未找到任何显示器")
                }
                return
            }

            let primaryFrame = NSScreen.screens.first?.frame ?? .zero

            for (idx, displayID) in displayIDs.enumerated() {
                guard let cgImage = await Self.captureSingleDisplay(displayID) else { continue }

                if let screen = NSScreen.screens.first(where: {
                    ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
                }) {
                    let frame = screen.frame
                    let scale = screen.backingScaleFactor
                    let x = (frame.origin.x - primaryFrame.origin.x) * scale
                    let flippedY = (primaryFrame.maxY - frame.maxY) * scale
                    let cropRect = CGRect(x: x, y: flippedY,
                                          width: frame.width * scale,
                                          height: frame.height * scale)
                        .intersection(CGRect(origin: .zero, size: CGSize(width: cgImage.width, height: cgImage.height)))
                    if cropRect.width > 0, cropRect.height > 0,
                       let cropped = cgImage.cropping(to: cropRect) {
                        let nsImage = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
                        capturedImages.append((screen: screen, image: nsImage, index: idx + 1))
                    }
                }
            }

            guard !capturedImages.isEmpty else {
                await MainActor.run {
                    self.notify(title: "多屏截图失败", body: "未能成功拍摄任何显示器（请检查屏幕录制权限）")
                }
                return
            }

            await MainActor.run {
                if capturedImages.count == 1 {
                    self.showPreviewWindow(image: capturedImages[0].image)
                } else {
                    self.openMultiScreenPreview(capturedImages)
                }
                self.notify(title: "多屏截图",
                       body: "已捕获 \(capturedImages.count) 个屏幕的截图")
            }
        }
    }

    /// ScreenCaptureKit 获取所有 displayID（辅助）
    private static func fetchDisplayIDsViaSC() async -> [CGDirectDisplayID] {
        guard let content = try? await SCShareableContent.current else { return [] }
        return content.displays.map { $0.displayID }
    }

    /// ScreenCaptureKit 拍摄单个显示器（返回 CGImage 或 nil）
    private static func captureSingleDisplay(_ displayID: CGDirectDisplayID) async -> CGImage? {
        guard let content = try? await SCShareableContent.current,
              let display = content.displays.first(where: { $0.displayID == displayID }) else {
            return nil
        }
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCScreenshotConfiguration()
        config.showsCursor = false
        return await withCheckedContinuation { continuation in
            SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: config) { output, _ in
                continuation.resume(returning: output?.sdrImage)
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        // 软申请权限（不再 hard gate）
        requestScreenCaptureIfNeeded()

        guard !isRecording else { return }
        let resolved = (defaultPath(isMovie: true) as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // 改用 -v 启动视频录制（不录音频，避免触发「screen and audio」双授权弹窗）
        // 旧版 -V 999999 会同时要求屏幕录制+麦克风/音频两个 TCC 权限
        process.arguments = ["-v", resolved]
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
        // 软申请权限（不再 hard gate）
        requestScreenCaptureIfNeeded()
        Task {
            let tempPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("annotation_\(Self.filenameFormatter.string(from: Date())).png")
            ensureParentDirectoryExists(for: tempPath)

            let (code, stderr) = await runScreencapture(args: ["-i", "-o", tempPath])
            if code == 0, FileManager.default.fileExists(atPath: tempPath) {
                openAnnotationEditor(imagePath: tempPath)
            } else if code != 1 {
                // 非取消 → 提示用户
                notify(title: "截图标注失败",
                       body: stderr.isEmpty ? "请检查屏幕录制权限" : stderr)
                Self.openScreenRecordingSettings()
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

        // 确保窗口在最前面
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFront(nil)
    }

    private func openMultiScreenPreview(_ screens: [(screen: NSScreen, image: NSImage, index: Int)]) {
        let id = UUID()
        let previewView = MultiScreenPreviewView(screens: screens) { [weak self] in
            self?.floatingWindows.removeValue(forKey: id)
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "多屏截图预览"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentView = NSHostingView(rootView: previewView)
        window.center()

        floatingWindows[id] = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
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
    var onClose: (() -> Void)?
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onClose?() }
                }
                .buttonStyle(.bordered)

                Button("复制到剪贴板") {
                    if let idx = selectedIndex,
                       let item = screens.first(where: { $0.index == idx }) {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.writeObjects([item.image])
                        onClose?()
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
