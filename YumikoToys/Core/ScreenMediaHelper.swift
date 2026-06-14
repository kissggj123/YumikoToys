//
//  ScreenMediaHelper.swift
//  YumikoToys
//
//  截图与录屏助手 (v4.5.0 - 多显示器、TouchBar与不限时录制)
//

import Foundation
import AppKit
import UserNotifications

@MainActor
final class ScreenMediaHelper: ObservableObject {
    static let shared = ScreenMediaHelper()

    @Published var isRecording = false
    private var recordProcess: Process?
    private var currentRecordURL: URL?

    private init() {}

    // MARK: - Notification Helper

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func captureArea() {
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", resolved]
        do { try process.run() } catch {
            LoggerService.shared.error("Failed to run area capture: \(error)")
        }
    }

    func captureFullscreen() {
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [resolved]
        do {
            try process.run()
            notify(title: "全屏截图成功", body: "截图已保存至桌面")
        } catch {
            LoggerService.shared.error("Failed to run fullscreen capture: \(error)")
        }
    }

    func captureTouchBar() {
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-b", resolved]
        do {
            try process.run()
            notify(title: "TouchBar 截图成功", body: "截图已保存至桌面")
        } catch {
            LoggerService.shared.error("Failed to run touchbar capture: \(error)")
        }
    }

    func captureAllScreens() {
        let resolved = (defaultPath(isMovie: false) as NSString).expandingTildeInPath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = [resolved]
        do {
            try process.run()
            notify(title: "多屏截图成功", body: "所有屏幕的截图已保存至桌面")
        } catch {
            LoggerService.shared.error("Failed to run all screens capture: \(error)")
        }
    }

    func startRecording() {
        guard !isRecording else { return }
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
}
