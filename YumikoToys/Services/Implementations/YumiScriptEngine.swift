//
//  YumiScriptEngine.swift
//  YumikoToys
//
//  自研 YumiScript 脚本编译与解析器（v1.0.0）
//

import Foundation
import AppKit
import UserNotifications

/// YumiScript 核心执行引擎
@MainActor
final class YumiScriptEngine {
    
    /// 执行一段 YumiScript 脚本并返回包含所有日志信息的输出文本
    static func execute(_ script: String) async -> String {
        var logs: [String] = []
        let lines = script.components(separatedBy: .newlines)
        
        logs.append("=== YumiScript Engine v1.0.0 ===")
        logs.append("开始执行脚本，总行数: \(lines.count)")
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过空行和注释行
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("//") {
                continue
            }
            
            logs.append("[\(index + 1)] 执行: \(trimmed)")
            
            // 解析指令与参数
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let cmdToken = parts.first else { continue }
            let command = cmdToken.lowercased()
            let rawArgs = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
            
            // 清理参数中的前后双引号/单引号
            let argsStr = cleanQuotes(rawArgs)
            
            switch command {
            case "launch":
                guard !argsStr.isEmpty else {
                    logs.append("错误: launch 命令缺少应用名称参数")
                    continue
                }
                // 预校验：先确认 app 实际存在（搜标准安装目录 + NSWorkspace bundle id 回退）
                // 避免 AppleScript 在主线程弹"定位 App"对话框把整个 App 卡死
                let resolvedPath = Self.resolveInstalledAppPath(named: argsStr)
                if resolvedPath == nil {
                    logs.append(" 启动失败: 找不到应用 \"\(argsStr)\"（已搜索 /Applications、/System/Applications 和已安装的 bundle id）")
                    logs.append(" 提示: 请确认应用名拼写正确，且应用已安装；如名字带引号或反斜杠，请用 \\\" 转义")
                    continue
                }

                // 用 `open -a "AppName"` 而非 AppleScript：
                //  1) open 找不到应用时 stderr 直接报错，不会弹"定位"对话框
                //  2) 异步激活，不阻塞主线程
                //  3) 自动处理路径转义（我们再手工 escape 一次双引号作为防御）
                let escaped = Self.shellEscape(argsStr)
                let shellCmd = "open -a \(escaped)"
                let shellResult = await SkillService.shared.runShell(shellCmd)
                if shellResult.contains("error") || shellResult.contains("Unable") {
                    // 二次兜底：直接用 AppleScript activate（已加 5s 超时，不会卡死）
                    logs.append(" `open` 失败（\(shellResult)），改用 AppleScript 兜底…")
                    let appleScript = "tell application \"\(argsStr.replacingOccurrences(of: "\"", with: "\\\""))\" to activate"
                    let result = await SkillService.shared.runAppleScript(appleScript)
                    if result.contains("error") {
                        logs.append(" 启动失败: \(result)")
                    } else {
                        logs.append(" 启动应用 \"\(argsStr)\" 成功（AppleScript 兜底）")
                    }
                } else {
                    logs.append(" 启动应用 \"\(argsStr)\" 成功（\(resolvedPath ?? "")）")
                }
                
            case "screenshot":
                // 委托给 ScreenMediaHelper：自动展开 ~、保证父目录、判定退出码、给出友好提示
                let target: String? = argsStr.isEmpty ? nil : (argsStr as NSString).expandingTildeInPath
                let result = await ScreenMediaHelper.shared.captureFullscreenAsync(targetPath: target)
                switch result.status {
                case .success:
                    logs.append(" 截图成功：\(result.message)")
                    logs.append(" 输出路径：\(result.path ?? "?")")
                case .cancelled:
                    logs.append(" 已取消截图（用户按 Esc）")
                case .denied:
                    logs.append(" 截图权限被拒绝：\(result.message)")
                    logs.append(" 请到 系统设置 → 隐私与安全性 → 屏幕录制 中授予权限后重试。")
                case .failed:
                    logs.append(" 截图失败：\(result.message)")
                }

            case "record":
                // record [seconds] [path]
                let argsParts = argsStr.split(separator: " ").map(String.init)
                let duration = Int(argsParts.first ?? "5") ?? 5
                let path: String? = argsParts.count > 1
                    ? (argsParts[1] as NSString).expandingTildeInPath
                    : nil

                let result = await ScreenMediaHelper.shared.recordForDuration(seconds: duration, outputPath: path)
                switch result.status {
                case .success:
                    logs.append(" 录屏完成（\(duration) 秒）：\(result.path ?? "?")")
                case .cancelled:
                    logs.append(" 录屏被取消")
                case .denied:
                    logs.append(" 录屏权限被拒绝：\(result.message)")
                    logs.append(" 请到 系统设置 → 隐私与安全性 → 屏幕录制 中授予权限。")
                case .failed:
                    logs.append(" 录屏失败：\(result.message)")
                }
                
            case "notify":
                let title: String
                let message: String

                let matches = extractQuotedParams(argsStr)
                if matches.count >= 2 {
                    title = matches[0]
                    message = matches[1]
                } else if matches.count == 1 {
                    title = "YumiScript"
                    message = matches[0]
                } else {
                    title = "YumiScript"
                    message = argsStr
                }

                // 走系统通知中心（沙盒下 AppleScript 的 display notification 经常被拒）
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                UNUserNotificationCenter.current().add(request) { _ in }
                logs.append(" 发送通知: [\(title)] \(message)")
                
            case "shell":
                guard !argsStr.isEmpty else {
                    logs.append("错误: shell 命令缺少指令参数")
                    continue
                }
                let result = await SkillService.shared.runShell(argsStr)
                logs.append(" 执行 Shell 结果:\n\(result)")
                
            case "wait":
                guard let seconds = Double(argsStr) else {
                    logs.append("错误: wait 命令参数非法，需为数字秒数")
                    continue
                }
                logs.append(" 等待 \(seconds) 秒...")
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                
            default:
                logs.append(" 错误: 未知指令 \"\(command)\"")
            }
        }
        
        logs.append("执行结束。")
        return logs.joined(separator: "\n")
    }
    
    // MARK: - 私有解析辅助
    
    private static func cleanQuotes(_ str: String) -> String {
        var trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            trimmed.removeFirst()
            trimmed.removeLast()
        }
        return trimmed
    }
    
    private static func extractQuotedParams(_ str: String) -> [String] {
        var results: [String] = []
        var current = ""
        var inQuotes = false

        for char in str {
            if char == "\"" {
                if inQuotes {
                    results.append(current)
                    current = ""
                    inQuotes = false
                } else {
                    inQuotes = true
                }
            } else {
                if inQuotes {
                    current.append(char)
                } else if char != " " {
                    current.append(char)
                }
            }
        }
        if !current.isEmpty {
            results.append(current)
        }
        return results
    }

    // MARK: - App 启动辅助

    /// 在标准安装目录里找 .app，找不到再用常见 bundle id 兜底。返回 .app 完整路径或 nil。
    /// 给 launch 用——避免 AppleScript 在主线程弹"定位 App"对话框把整个 App 卡死。
    private static func resolveInstalledAppPath(named appName: String) -> String? {
        let trimmedName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        // 1) 标准目录精确匹配 / 模糊匹配
        let dirs = ["/Applications", "/System/Applications", "/System/Library/CoreServices", "/Library/CoreServices"]
        // 用户家目录 ~/Applications
        var allDirs = dirs
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            allDirs.append("\(home)/Applications")
        }

        for dir in allDirs {
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let nameWithoutExt = (item as NSString).deletingPathExtension
                // 精确匹配（不区分大小写）
                if nameWithoutExt.caseInsensitiveCompare(trimmedName) == .orderedSame {
                    return (dir as NSString).appendingPathComponent(item)
                }
            }
        }
        // 模糊匹配（包含关系）
        for dir in allDirs {
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let nameWithoutExt = (item as NSString).deletingPathExtension
                if nameWithoutExt.localizedCaseInsensitiveContains(trimmedName)
                    || trimmedName.localizedCaseInsensitiveContains(nameWithoutExt) {
                    return (dir as NSString).appendingPathComponent(item)
                }
            }
        }

        // 2) 常见 app 名 → bundle id 兜底（解决"Terminal"在 /System/Applications 里叫"终端"中文目录的奇葩情况）
        let knownBundleIds: [String: String] = [
            "Terminal": "com.apple.Terminal",
            "终端": "com.apple.Terminal",
            "Safari": "com.apple.Safari",
            "Xcode": "com.apple.dt.Xcode",
            "Finder": "com.apple.finder",
            "Notes": "com.apple.Notes",
            "备忘录": "com.apple.Notes",
            "Calendar": "com.apple.iCal",
            "日历": "com.apple.iCal",
            "Photos": "com.apple.Photos",
            "照片": "com.apple.Photos",
            "Music": "com.apple.Music",
            "音乐": "com.apple.Music",
            "Messages": "com.apple.MobileSMS",
            "信息": "com.apple.MobileSMS",
            "Mail": "com.apple.mail",
            "邮件": "com.apple.mail",
            "Maps": "com.apple.Maps",
            "地图": "com.apple.Maps",
            "FaceTime": "com.apple.FaceTime",
            "系统偏好设置": "com.apple.systempreferences",
            "System Settings": "com.apple.systempreferences",
            "System Preferences": "com.apple.systempreferences"
        ]
        if let bundleId = knownBundleIds[trimmedName],
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return url.path
        }

        return nil
    }

    /// 把任意字符串 escape 成能塞进 /bin/zsh -c 的安全形式
    /// 简单做法：单引号包裹 + 把字符串里的单引号替换成 '\''（经典的 shell escape 范式）
    private static func shellEscape(_ str: String) -> String {
        let escaped = str.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
