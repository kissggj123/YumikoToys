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
        CGImageDestinationAddImage(destination, cgImage, nil)
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

        // 2) 准备路径：传入 > 桌面默认 > 临时文件
        let isTemp = (targetPath == nil)
        let resolved: String
        if let target = targetPath {
            resolved = (target as NSString).expandingTildeInPath
        } else if isTemp {
            resolved = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("screenshot_\(Self.filenameFormatter.string(from: Date())).png")
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
    // 这里我们做兼容：
    //   1) 检查系统是否有 NSTouchBar（应用层 API）
    //   2) 检查 IORegistry 里有没有 Touch Bar 设备（更可靠）
    //   3) 都没有就提示用户"当前 Mac 不支持 TouchBar 截图"

    /// 检测当前 Mac 是否有 TouchBar
    static func hasTouchBar() -> Bool {
        // 方法 1：NSTouchBar API（应用层）
        // 注意 NSTouchBar 永远在 SDK 里有，但需要 DFRSystemModal 等系统支持
        // 简单判别：检查机器型号
        if let model = runShell("/usr/sbin/system_profiler", ["SPHardwareDataType", "-detailLevel", "mini"])
            .split(separator: "\n").first(where: { $0.contains("Model Name") || $0.contains("Chip") }) {
            // Apple Silicon 14" MacBook Pro（2021+）没有 TouchBar
            // MacBook Pro 13"/15"/16" 2015-2020 才有
            let hasTouchBarKeywords = ["MacBookPro15", "MacBookPro16", "MacBookPro11", "MacBookPro12", "MacBookPro13", "MacBookPro14"]
            if hasTouchBarKeywords.contains(where: { model.contains($0) }) {
                return true
            }
        }
        // 方法 2：用 ioreg 看 BridgeAudio 节点有没有 Touch Bar Device
        if let _ = runShell("/usr/sbin/ioreg", ["-l", "-d", "0", "-w", "0", "-c", "AppleEmbeddedOSSupportHost"])
            .split(separator: "\n").first(where: { $0.contains("TouchBar") }) {
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
        p.waitUntilExit()
        return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    func captureTouchBar() {
        // 先检测
        guard Self.hasTouchBar() else {
            notify(title: "TouchBar 不可用",
                   body: "当前 Mac 机型没有 Touch Bar 硬件（2021 年后的 MacBook Pro 取消了 TouchBar）。\n如果你确认有 TouchBar，请反馈给开发者。")
            return
        }

        requestScreenCaptureIfNeeded()
        Task {
            let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
            ensureParentDirectoryExists(for: resolved)
            var args = ["-b"]
            if outputMode == .clipboardOnly { args.append("-c") }
            args.append(resolved)

            let (code, stderr) = await runScreencapture(args: args)
            if code == 0, FileManager.default.fileExists(atPath: resolved) {
                if outputMode == .clipboardOnly || outputMode == .both {
                    copyFileToClipboard(path: resolved)
                } else {
                    notify(title: "TouchBar 截图成功", body: "已保存到桌面：\(resolved)")
                }
            } else if code == 1 {
                // 用户取消
            } else {
                let msg = stderr.isEmpty ? "请检查屏幕录制权限" : stderr
                notify(title: "TouchBar 截图失败", body: msg)
                if stderr.lowercased().contains("denied") || stderr.lowercased().contains("permission") {
                    Self.openScreenRecordingSettings()
                }
            }
        }
    }

    // MARK: - Multi-Screen Capture
    //
    // 关键改动：不再依赖 screencapture -x 的"自动加后缀"行为（不同 macOS 版本表现不一致，
    // 经常只截主屏而不遍历所有屏）。改为**多源兜底**拿到所有屏幕的 displayID：
    //   1) CGGetActiveDisplayList        —— CoreGraphics 直接枚举（最稳，不受 TCC 影响）
    //   2) SCShareableContent.current    —— 旧方案，作为副路
    //   3) NSScreen.screens              —— 终极兜底
    // 然后**逐屏调用 `screencapture -D<displayID>`** 拍下来，分别保存。
    // 拍完后弹一个多屏预览窗口，让用户看到/取用每张图。

    /// 多源兜底获取所有当前激活的 display ID
    private func enumerateAllDisplayIDs() -> [CGDirectDisplayID] {
        // 1) CoreGraphics：最直接、不依赖 TCC 也不依赖 AppKit 状态
        let maxDisplays: UInt32 = 16
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var count: UInt32 = 0
        let err = CGGetActiveDisplayList(maxDisplays, &ids, &count)
        if err == CGError.success, count > 0 {
            let list = Array(ids.prefix(Int(count)))
            // 去重 + 排除已休眠的 display（isActive=0）
            var seen = Set<CGDirectDisplayID>()
            return list.filter { id in
                guard !seen.contains(id) else { return false }
                seen.insert(id)
                return CGDisplayIsActive(id) != 0 || NSScreen.screens.contains(where: { s in
                    (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == id
                })
            }
        }

        // 2) ScreenCaptureKit：副路
        var result: [CGDirectDisplayID] = []
        let group = DispatchGroup()
        group.enter()
        Task { @MainActor in
            if let content = try? await SCShareableContent.current {
                result = content.displays.map { $0.displayID }
            }
            group.leave()
        }
        _ = group.wait(timeout: .now() + 2)
        if !result.isEmpty { return result }

        // 3) NSScreen：终极兜底
        return NSScreen.screens.compactMap { screen in
            screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        }
    }

    func captureAllScreens() {
        requestScreenCaptureIfNeeded()

        Task { @MainActor in
            // 1) 多源拿到所有 displayID（去重 + 跳过休眠屏）
            let displayIDs = self.enumerateAllDisplayIDs()
            guard !displayIDs.isEmpty else {
                self.notify(title: "多屏截图失败", body: "未找到任何显示器")
                return
            }

            // 2) 逐屏拍
            var capturedImages: [(screen: NSScreen?, image: NSImage, index: Int, displayID: CGDirectDisplayID)] = []
            let isTemp = (outputMode == .clipboardOnly)
            let dir = isTemp ? NSTemporaryDirectory() : ((defaultPath(isMovie: false) as NSString).expandingTildeInPath as NSString).deletingLastPathComponent
            ensureParentDirectoryExists(for: dir)

            for (idx, displayID) in displayIDs.enumerated() {
                let fileName = isTemp
                    ? "screen_\(displayID)_\(UUID().uuidString).png"
                    : "screenshot_multi_\(displayID)_\(Self.filenameFormatter.string(from: Date())).png"
                let resolved = (dir as NSString).appendingPathComponent(fileName)

                // 关键参数：-D<displayID>  指定要拍哪块屏幕
                // -x: 静音
                let args = ["-x", "-D\(displayID)", resolved]
                let (code, stderr) = await runScreencapture(args: args)
                guard code == 0, FileManager.default.fileExists(atPath: resolved) else {
                    if code != 1 {
                        self.notify(title: "显示器 #\(idx+1) 截图失败",
                               body: stderr.isEmpty ? "请检查屏幕录制权限" : stderr)
                    }
                    continue
                }

                if let img = NSImage(contentsOfFile: resolved) {
                    let matchingScreen = NSScreen.screens.first(where: { s in
                        let id = (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
                        return id == displayID
                    })
                    capturedImages.append((screen: matchingScreen, image: img, index: idx + 1, displayID: displayID))
                }
            }

            // 3) 报告结果
            guard !capturedImages.isEmpty else {
                self.notify(title: "多屏截图失败", body: "未能成功拍摄任何显示器")
                return
            }

            // 4) 一张：当成单屏流程；多张：开多屏预览
            if capturedImages.count == 1 {
                let img = capturedImages[0].image
                self.showPreviewWindow(image: img)
                if self.outputMode == .clipboardOnly || self.outputMode == .both {
                    // 单屏：把刚生成的文件路径找到塞剪贴板
                    // 简化为：弹预览窗口里已有"复制到剪贴板"按钮
                } else {
                    self.notify(title: "截图成功", body: "屏幕截图已保存至桌面")
                }
            } else {
                // 适配 openMultiScreenPreview 的入参类型（不要 displayID）
                let pairs: [(screen: NSScreen, image: NSImage, index: Int)] = capturedImages.compactMap { tuple in
                    guard let s = tuple.screen else { return nil }
                    return (s, tuple.image, tuple.index)
                }
                if pairs.isEmpty {
                    // 全是空（理论上不会发生）—— 弹首张图兜底
                    if let first = capturedImages.first {
                        self.showPreviewWindow(image: first.image)
                    }
                } else {
                    self.openMultiScreenPreview(pairs)
                }
                self.notify(title: "多屏截图",
                       body: "已捕获 \(capturedImages.count) 个屏幕的截图（displayID: \(displayIDs.map(String.init).joined(separator: ", "))）")
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
