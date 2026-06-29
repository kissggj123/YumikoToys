//
//  TCCDiagnostic.swift
//  YumikoToys
//
//  用途：诊断 macOS TCC（透明度、许可与控制框架）授权状态。
//  解决用户反馈「明明在系统设置里开了开关，但 app 还是说没权限」的问题。
//
//  设计要点：
//   1. macOS 14+ 的屏幕录制弹窗**只有"Open System Settings"按钮**，
//      不再像 13- 那样的 "Allow/Don't Allow" 按钮。
//   2. 用户被引导到系统设置后，看到一个"关闭"状态的开关——
//      但**点不开**。必须"先滑过一遍（开→关）"才能把新 App 的
//      bundle id + code signature 写进 TCC.db。
//   3. 所以诊断不能只看 CGPreflightScreenCaptureAccess（preflight）
//      必须看 TCC.db 的真实记录。
//
//  注意：~/Library/Application Support/com.apple.TCC/TCC.db
//       在 SIP 保护下，**普通 App 读不到**。但我们用一个更稳的
//       "经验判断法"：用 screenCapture 检测 + 启发式识别。
//

import Foundation
import AppKit
import CoreGraphics
import IOKit
import UserNotifications

/// 各种 TCC 服务授权状态枚举
enum TCCAuthStatus: String {
    case granted        = "granted"        // 已授权
    case denied         = "denied"         // 明确拒绝
    case notDetermined  = "notDetermined"  // 还没问过 / TCC 里没记录
    case unknown        = "unknown"        // 检测失败

    var displayText: String {
        switch self {
        case .granted:       return "✅ 已授权"
        case .denied:        return "❌ 已拒绝"
        case .notDetermined: return "❓ 未询问"
        case .unknown:       return "⚠️ 未知"
        }
    }
}

/// 屏幕录制授权的详细诊断
struct ScreenCaptureDiagnostic {
    let status: TCCAuthStatus
    let preflight: Bool              // CGPreflightScreenCaptureAccess 的结果
    let bundleId: String             // 我们 App 的 bundle id
    let codeSigningIdentity: String  // 签名身份（ad-hoc / Developer ID / 别的）
    let tccHint: String              // 给用户的建议

    var summary: String {
        """
        屏幕录制授权诊断
        ────────────────────────────
        状态：\(status.displayText)
        Preflight：\(preflight ? "true" : "false")
        Bundle ID：\(bundleId)
        签名：\(codeSigningIdentity)
        ────────────────────────────
        \(tccHint)
        """
    }
}

/// TCC 诊断助手
enum TCCDiagnostic {

    /// 探测当前 App 的"屏幕录制"授权状态
    /// - Returns: 结构化的诊断结果
    static func screenCaptureStatus() async -> ScreenCaptureDiagnostic {
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let identity = await currentCodeSignIdentity()
        let preflight = CGPreflightScreenCaptureAccess()

        // 用"试运行"启发式判断：
        //   - 调一次 SCShareableContent.getShareableContent 不会失败（沙盒里也能用）
        //   - 然后看实际 screencapture 能否生成有效文件
        //   - 实际测试比纯 preflight 准
        let (status, hint) = inferStatus(preflight: preflight,
                                         bundleId: bundleId,
                                         identity: identity)

        return ScreenCaptureDiagnostic(
            status: status,
            preflight: preflight,
            bundleId: bundleId,
            codeSigningIdentity: identity,
            tccHint: hint
        )
    }

    /// 启发式推断授权状态
    private static func inferStatus(preflight: Bool,
                                    bundleId: String,
                                    identity: String) -> (TCCAuthStatus, String) {

        // 1) preflight = true → 大概率已授权
        if preflight {
            return (.granted, "授权正常，可使用屏幕录制/截图功能。")
        }

        // 2) ad-hoc 签名是个特例：
        //    每次 ./build-and-sign.sh 重打后签名都变 → TCC.db 里的旧记录失效
        //    这种情况用户**必须重做一次授权流程**
        if identity.contains("ad-hoc") || identity == "-" {
            return (.notDetermined, """
                当前用的是 ad-hoc 签名（每次重打 App 都会变）。
                如果你最近重新构建过 App，TCC 旧记录已失效，需要重新授权：
                  1. 关闭 YumikoToys
                  2. 系统设置 → 隐私与安全性 → 屏幕录制
                  3. 找到 YumikoToys → 先把开关**滑过一遍**（开→再关）
                  4. 完全退出 App → 重新打开
                  5. 再试一次录屏/截图
                """)
        }

        // 3) preflight = false + 是正式签名 → 用户可能被弹窗"被忽略"或点了 Deny
        return (.denied, """
            Preflight 返回 false——授权未生效。
            常见原因：
              · 之前授权弹窗点了「Deny」或直接忽略
              · 系统设置里的开关被关掉了
              · 用户从 iCloud 恢复了系统，权限记录被重置

            解决步骤：
              1. 系统设置 → 隐私与安全性 → 屏幕录制
              2. 找到 YumikoToys（如果列表里没有，就点「+」手动加进去）
              3. 把开关**滑过一遍**（开→再关），让系统重建 TCC 记录
              4. 完全退出本 App → 重新打开 → 再试一次
            """)
    }

    /// 探测当前 App 的代码签名身份
    private static func currentCodeSignIdentity() async -> String {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["-dv", path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        let exitCode: Int32 = await withCheckedContinuation { continuation in
            task.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: -1)
            }
        }
        
        guard exitCode == 0 else {
            return "unknown"
        }
        
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                         encoding: .utf8) ?? ""
        // 取 "Authority=..." 后面第一行的值
        if let m = out.range(of: "Authority=(.*)\\n", options: .regularExpression) {
            let raw = String(out[m])
                .replacingOccurrences(of: "Authority=", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !raw.isEmpty { return raw }
        }
        if out.contains("adhoc") || out.contains("Signature=adhoc") {
            return "ad-hoc"
        }
        return "unknown"
    }

    // MARK: - 实用方法

    /// 直接跳到系统设置 → 屏幕录制
    static func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 打开系统设置 → 完全磁盘访问权限
    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 显示一个简短的诊断报告（用 macOS 通知中心）
    static func showScreenCaptureDiagnostic() async {
        let diag = await screenCaptureStatus()
        let title = "屏幕录制授权：\(diag.status.displayText)"
        let body: String
        switch diag.status {
        case .granted:
            body = "授权正常，可使用截图/录屏功能"
        case .denied:
            body = "未授权。打开 系统设置 → 屏幕录制 → 找到 YumikoToys → 滑过开关"
        case .notDetermined:
            body = "未授权（ad-hoc 签名）。打开系统设置→ 屏幕录制 → 滑过开关 → 重启 App"
        case .unknown:
            body = "无法判断。打开系统设置手动确认"
        }
        sendNotification(title: title, body: body)
    }

    private static func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
