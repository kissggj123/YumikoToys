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
        var lastOutput: String = ""
        
        logs.append("=== YumiScript Engine v2.5.0 ===")
        logs.append("开始执行脚本，总行数: \(lines.count)")
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过空行和注释行
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("//") {
                continue
            }
            
            logs.append("[\(index + 1)] 执行: \(trimmed)")
            
            // 变量替换 ($OUTPUT, $CLIPBOARD, $DATE, $TIME, $USER)
            let processedLine = interpolateVariables(trimmed, lastOutput: lastOutput)
            
            // 解析指令与参数
            let parts = processedLine.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let cmdToken = parts.first else { continue }
            let command = cmdToken.lowercased()
            let rawArgs = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let argsStr = cleanQuotes(rawArgs)
            
            switch command {
            case "launch":
                guard !argsStr.isEmpty else {
                    logs.append(" 错误: launch 命令缺少应用名称参数")
                    continue
                }
                let resolvedPath = Self.resolveInstalledAppPath(named: argsStr)
                if resolvedPath == nil {
                    logs.append(" 启动失败: 找不到应用 \"\(argsStr)\"（已搜索 /Applications、/System/Applications 和已安装的 bundle id）")
                    logs.append(" 提示: 请确认应用名拼写正确，且应用已安装")
                    continue
                }

                let allowMultiple = DependencyContainer.shared.settingsService.settings.allowMultipleInstances
                let url = URL(fileURLWithPath: resolvedPath!)
                var success = false

                if allowMultiple {
                    // 多开模式：优先通过 macOS 原生 /usr/bin/open -n 分离进程实现真多开
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    process.arguments = ["-n", resolvedPath!]
                    do {
                        try process.run()
                        process.waitUntilExit()
                        success = (process.terminationStatus == 0)
                    } catch {
                        success = false
                    }
                }

                if !success {
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.createsNewApplicationInstance = allowMultiple
                    configuration.activates = true
                    
                    success = await withCheckedContinuation { continuation in
                        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { (app, error) in
                            if let _ = error {
                                continuation.resume(returning: false)
                            } else {
                                continuation.resume(returning: true)
                            }
                        }
                    }
                }
                
                if success {
                    lastOutput = "已启动 \(argsStr)"
                    logs.append(" 启动应用 \"\(argsStr)\" 成功\(allowMultiple ? " [多开独立实例]" : "")（\(resolvedPath ?? "")）")
                } else {
                    // AppleScript 兜底
                    logs.append(" 启动失败，改用 AppleScript 兜底…")
                    let appleScript = "tell application \"\(argsStr.replacingOccurrences(of: "\"", with: "\\\""))\" to activate"
                    let result = await SkillService.shared.runAppleScript(appleScript)
                    if result.contains("error") {
                        logs.append(" 启动失败: \(result)")
                    } else {
                        lastOutput = "已启动 \(argsStr)"
                        logs.append(" 启动应用 \"\(argsStr)\" 成功（AppleScript 兜底）")
                    }
                }
                
            case "open":
                guard !argsStr.isEmpty else {
                    logs.append(" 错误: open 命令缺少路径或 URL")
                    continue
                }
                let expandedPath = (argsStr as NSString).expandingTildeInPath
                if let url = URL(string: argsStr), url.scheme != nil {
                    NSWorkspace.shared.open(url)
                    lastOutput = "已打开网页/链接: \(argsStr)"
                    logs.append(" 已打开 URL: \(argsStr)")
                } else if FileManager.default.fileExists(atPath: expandedPath) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: expandedPath))
                    lastOutput = "已打开目录: \(expandedPath)"
                    logs.append(" 已打开路径: \(expandedPath)")
                } else {
                    let res = await SkillService.shared.runShell("open \"\(expandedPath)\"")
                    lastOutput = res.trimmingCharacters(in: .whitespacesAndNewlines)
                    logs.append(" 执行 open 结果: \(res)")
                }
                
            case "copy", "clipboard":
                guard !argsStr.isEmpty else {
                    logs.append(" 错误: copy 命令缺少文本参数")
                    continue
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(argsStr, forType: .string)
                lastOutput = argsStr
                logs.append(" 已写入系统剪贴板: \"\(argsStr.prefix(50))\(argsStr.count > 50 ? "..." : "")\"")
                
            case "paste":
                let clip = NSPasteboard.general.string(forType: .string) ?? ""
                lastOutput = clip
                logs.append(" 读取剪贴板内容（共 \(clip.count) 字）: \(clip.prefix(60))")
                
            case "sys", "system":
                let action = argsStr.lowercased()
                switch action {
                case "lock":
                    lockScreen()
                    lastOutput = "屏幕已锁定"
                    logs.append(" 已锁定 Mac 屏幕 🔒")
                    
                case "emptytrash":
                    let res = await SkillService.shared.runAppleScript("tell application \"Finder\" to empty trash")
                    lastOutput = "废纸篓已清空"
                    logs.append(" 已清空废纸篓 🗑️")
                    
                case "toggletheme", "darkmode", "lightmode":
                    let res = await SkillService.shared.runAppleScript("""
                    tell application "System Events"
                        tell appearance preferences
                            set dark mode to not dark mode
                            return dark mode
                        end tell
                    end tell
                    """)
                    let isDark = res.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
                    lastOutput = isDark ? "已切换为深色模式 🌙" : "已切换为浅色模式 ☀️"
                    logs.append(" \(lastOutput)")
                    
                case "purge", "cleanmem":
                    let _ = await SkillService.shared.runShell("/usr/sbin/purge 2>/dev/null || true")
                    lastOutput = "内存缓存已释放 ⚡"
                    logs.append(" \(lastOutput)")
                    
                case "ip":
                    let ipRes = await SkillService.shared.runShell("""
                    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "无内网")
                    PING_MS=$(ping -c 1 -t 2 223.5.5.5 2>/dev/null | awk -F'/' 'END{print $5}')
                    if [ -n "$PING_MS" ]; then
                        echo "内网IP: $LOCAL_IP | 延迟: ${PING_MS}ms (连通正常 📶)"
                    else
                        echo "内网IP: $LOCAL_IP | 网络离线 ⚠️"
                    fi
                    """)
                    lastOutput = ipRes.trimmingCharacters(in: .whitespacesAndNewlines)
                    logs.append(" 网络诊断结果: \(lastOutput)")
                    
                case "cpu":
                    let cpuRes = await SkillService.shared.runShell("ps -Ao %cpu,comm -r | head -4 | awk 'NR>1 {print $2 \"(\" $1 \"%)\"}' | paste -sd ', ' -")
                    lastOutput = "Top CPU: " + cpuRes.trimmingCharacters(in: .whitespacesAndNewlines)
                    logs.append(" 进程负载: \(lastOutput)")
                    
                case "disk":
                    let diskRes = await SkillService.shared.runShell("df -h / | awk 'NR==2 {print \"总量 \" $2 \", 已用 \" $3 \" (\" $5 \"), 可用 \" $4}'")
                    lastOutput = "主磁盘空间: " + diskRes.trimmingCharacters(in: .whitespacesAndNewlines)
                    logs.append(" 磁盘空间: \(lastOutput)")
                    
                case "togglemute", "mute":
                    let _ = await SkillService.shared.runAppleScript("""
                    set curMute to output muted of (get volume settings)
                    set volume output muted (not curMute)
                    """)
                    lastOutput = "已切换系统静音状态 🔇"
                    logs.append(" \(lastOutput)")
                    
                default:
                    logs.append(" 未知系统动作: \"\(action)\"，支持: lock, emptytrash, toggletheme, purge, ip, cpu, disk, togglemute")
                }
                
            case "applescript", "osascript":
                guard !argsStr.isEmpty else {
                    logs.append(" 错误: applescript 命令缺少脚本内容")
                    continue
                }
                let result = await SkillService.shared.runAppleScript(argsStr)
                lastOutput = result.trimmingCharacters(in: .whitespacesAndNewlines)
                logs.append(" AppleScript 执行结果: \(lastOutput)")

            case "screenshot":
                let target: String? = argsStr.isEmpty ? nil : (argsStr as NSString).expandingTildeInPath
                let result = await ScreenMediaHelper.shared.captureFullscreenAsync(targetPath: target)
                switch result.status {
                case .success:
                    lastOutput = result.path ?? "截图已保存至桌面"
                    logs.append(" 截图成功：\(result.message)")
                    logs.append(" 输出路径：\(result.path ?? "?")")
                case .cancelled:
                    lastOutput = "截图已取消"
                    logs.append(" 已取消截图（用户按 Esc）")
                case .denied:
                    lastOutput = "截图权限被拒绝"
                    logs.append(" 截图权限被拒绝：\(result.message)")
                case .failed:
                    lastOutput = "截图失败: \(result.message)"
                    logs.append(" 截图失败：\(result.message)")
                }

            case "record":
                let argsParts = argsStr.split(separator: " ").map(String.init)
                let duration = Int(argsParts.first ?? "5") ?? 5
                let path: String? = argsParts.count > 1 ? (argsParts[1] as NSString).expandingTildeInPath : nil

                let result = await ScreenMediaHelper.shared.recordForDuration(seconds: duration, outputPath: path)
                switch result.status {
                case .success:
                    lastOutput = result.path ?? "录屏完成"
                    logs.append(" 录屏完成（\(duration) 秒）：\(result.path ?? "?")")
                case .cancelled:
                    lastOutput = "录屏已取消"
                    logs.append(" 录屏被取消")
                case .denied:
                    lastOutput = "录屏权限被拒绝"
                    logs.append(" 录屏权限被拒绝：\(result.message)")
                case .failed:
                    lastOutput = "录屏失败: \(result.message)"
                    logs.append(" 录屏失败：\(result.message)")
                }
                
            case "notify", "toast", "hud":
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
                    message = argsStr.isEmpty ? lastOutput : argsStr
                }

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
                    logs.append(" 错误: shell 命令缺少指令参数")
                    continue
                }
                let result = await SkillService.shared.runShell(argsStr)
                let cleanResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
                lastOutput = cleanResult
                logs.append(" 执行 Shell 结果:\n\(cleanResult)")
                
            case "wait", "sleep":
                guard let seconds = Double(argsStr) else {
                    logs.append(" 错误: wait 命令参数非法，需为数字秒数")
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
    
    // MARK: - 变量替换
    
    private static func interpolateVariables(_ input: String, lastOutput: String) -> String {
        var str = input
        
        // $OUTPUT
        str = str.replacingOccurrences(of: "$OUTPUT", with: lastOutput)
        
        // $CLIPBOARD
        if str.contains("$CLIPBOARD") {
            let clip = NSPasteboard.general.string(forType: .string) ?? ""
            str = str.replacingOccurrences(of: "$CLIPBOARD", with: clip)
        }
        
        // $DATE / $TIME / $USER
        if str.contains("$DATE") || str.contains("$TIME") || str.contains("$USER") {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let dateStr = df.string(from: Date())
            df.dateFormat = "HH:mm:ss"
            let timeStr = df.string(from: Date())
            let user = NSUserName()
            
            str = str.replacingOccurrences(of: "$DATE", with: dateStr)
            str = str.replacingOccurrences(of: "$TIME", with: timeStr)
            str = str.replacingOccurrences(of: "$USER", with: user)
        }
        
        return str
    }
    
    // MARK: - 系统锁屏
    
    private static func lockScreen() {
        let libHandle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
        if let libHandle = libHandle {
            let sym = dlsym(libHandle, "SACLockScreenImmediate")
            if let sym = sym {
                typealias Func = @convention(c) () -> Void
                let fn = unsafeBitCast(sym, to: Func.self)
                fn()
            }
            dlclose(libHandle)
        } else {
            let _ = Process.launchedProcess(launchPath: "/usr/bin/pmset", arguments: ["displaysleepnow"])
        }
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
