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
        var userVariables: [String: String] = [:]
        
        logs.append("=== YumiScript Engine v3.0.0 (支持自定义变量) ===")
        logs.append("开始执行脚本，总行数: \(lines.count)")
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过空行和注释行
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("//") {
                continue
            }
            
            logs.append("[\(index + 1)] 执行: \(trimmed)")
            
            // 1. 检查是否为变量赋值语句 (var a = 123, let b = "abc", set c = ..., key = value)
            if let (varName, varExpr) = parseVariableAssignment(trimmed) {
                let evaluatedValue = await evaluateExpression(varExpr, variables: userVariables, lastOutput: lastOutput)
                userVariables[varName] = evaluatedValue
                lastOutput = evaluatedValue
                logs.append("   ↳ 变量赋值: $\(varName) = \"\(evaluatedValue)\"")
                continue
            }
            
            // 2. 解析指令与原始参数
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let cmdToken = parts.first else { continue }
            let command = cmdToken.lowercased()
            let rawArgs = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
            
            switch command {
            case "launch":
                let appName = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                guard !appName.isEmpty else {
                    logs.append(" 错误: launch 命令缺少应用名称参数")
                    continue
                }
                let resolvedPath = Self.resolveInstalledAppPath(named: appName)
                if resolvedPath == nil {
                    logs.append(" 启动失败: 找不到应用 \"\(appName)\"（已搜索 /Applications、/System/Applications 和已安装的 bundle id）")
                    logs.append(" 提示: 请确认应用名拼写正确，且应用已安装")
                    continue
                }

                let allowMultiple = DependencyContainer.shared.settingsService.settings.allowMultipleInstances
                let url = URL(fileURLWithPath: resolvedPath!)
                var success = false

                if allowMultiple {
                    // 多开模式：通过 macOS 原生 /usr/bin/open -n 分离进程实现真多开
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
                    lastOutput = "已启动 \(appName)"
                    logs.append(" 启动应用 \"\(appName)\" 成功\(allowMultiple ? " [多开独立实例]" : "")（\(resolvedPath ?? "")）")
                } else {
                    logs.append(" 启动失败，改用 AppleScript 兜底…")
                    let appleScript = "tell application \"\(appName.replacingOccurrences(of: "\"", with: "\\\""))\" to activate"
                    let result = await SkillService.shared.runAppleScript(appleScript)
                    if result.contains("error") {
                        logs.append(" 启动失败: \(result)")
                    } else {
                        lastOutput = "已启动 \(appName)"
                        logs.append(" 启动应用 \"\(appName)\" 成功（AppleScript 兜底）")
                    }
                }
                
            case "open":
                let target = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                guard !target.isEmpty else {
                    logs.append(" 错误: open 命令缺少路径或 URL")
                    continue
                }
                let expandedPath = (target as NSString).expandingTildeInPath
                if let url = URL(string: target), url.scheme != nil {
                    NSWorkspace.shared.open(url)
                    lastOutput = "已打开网页/链接: \(target)"
                    logs.append(" 已打开 URL: \(target)")
                } else if FileManager.default.fileExists(atPath: expandedPath) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: expandedPath))
                    lastOutput = "已打开目录: \(expandedPath)"
                    logs.append(" 已打开路径: \(expandedPath)")
                } else {
                    let res = await runRawShell("open \"\(expandedPath)\"")
                    lastOutput = res
                    logs.append(" 执行 open 结果: \(res)")
                }
                
            case "copy", "clipboard":
                let textToCopy = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                guard !textToCopy.isEmpty else {
                    logs.append(" 错误: copy 命令缺少文本参数")
                    continue
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(textToCopy, forType: .string)
                lastOutput = textToCopy
                logs.append(" 已写入系统剪贴板: \"\(textToCopy.prefix(50))\(textToCopy.count > 50 ? "..." : "")\"")
                
            case "paste":
                let clip = NSPasteboard.general.string(forType: .string) ?? ""
                lastOutput = clip
                logs.append(" 读取剪贴板内容（共 \(clip.count) 字）: \(clip.prefix(60))")
                
            case "sys", "system", "ping":
                var targetArg = interpolateVariables(rawArgs, variables: userVariables, lastOutput: lastOutput).trimmingCharacters(in: .whitespacesAndNewlines)
                // 如果参数本身是一个变量名（未加 $），尝试从变量表中提取
                if let varValue = userVariables[targetArg] {
                    targetArg = varValue
                }
                
                let lowerArg = targetArg.lowercased()
                
                if lowerArg == "lock" {
                    lockScreen()
                    lastOutput = "屏幕已锁定"
                    logs.append(" 已锁定 Mac 屏幕 🔒")
                } else if lowerArg == "emptytrash" {
                    let _ = await SkillService.shared.runAppleScript("tell application \"Finder\" to empty trash")
                    lastOutput = "废纸篓已清空"
                    logs.append(" 已清空废纸篓 🗑️")
                } else if lowerArg == "toggletheme" || lowerArg == "darkmode" || lowerArg == "lightmode" {
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
                } else if lowerArg == "purge" || lowerArg == "cleanmem" {
                    let _ = await runRawShell("/usr/sbin/purge 2>/dev/null || true")
                    lastOutput = "内存缓存已释放 ⚡"
                    logs.append(" \(lastOutput)")
                } else if lowerArg == "cpu" {
                    let cpuRes = await runRawShell("ps -Ao %cpu,comm -r | head -4 | awk 'NR>1 {print $2 \"(\" $1 \"%)\"}' | paste -sd ', ' -")
                    lastOutput = "Top CPU: " + cpuRes
                    logs.append(" 进程负载: \(lastOutput)")
                } else if lowerArg == "disk" {
                    let diskRes = await runRawShell("df -h / | awk 'NR==2 {print \"总量 \" $2 \", 已用 \" $3 \" (\" $5 \"), 可用 \" $4}'")
                    lastOutput = "主磁盘空间: " + diskRes
                    logs.append(" 磁盘空间: \(lastOutput)")
                } else if lowerArg == "togglemute" || lowerArg == "mute" {
                    let _ = await SkillService.shared.runAppleScript("""
                    set curMute to output muted of (get volume settings)
                    set volume output muted (not curMute)
                    """)
                    lastOutput = "已切换系统静音状态 🔇"
                    logs.append(" \(lastOutput)")
                } else if lowerArg == "ip" || lowerArg.isEmpty {
                    let ipRes = await runRawShell("""
                    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "无内网")
                    PING_MS=$(ping -c 1 -t 2 223.5.5.5 2>/dev/null | awk -F'/' 'END{print $5}')
                    if [ -n "$PING_MS" ]; then
                        echo "内网IP: $LOCAL_IP | 延迟: ${PING_MS}ms (连通正常 📶)"
                    else
                        echo "内网IP: $LOCAL_IP | 网络离线 ⚠️"
                    fi
                    """)
                    lastOutput = ipRes
                    logs.append(" 网络诊断结果: \(lastOutput)")
                } else {
                    // 支持 sys <ip/host>、sys ip <ip/host>、sys ping <ip/host> 或直接 ping <ip/host>
                    var pingTarget = targetArg
                    if pingTarget.lowercased().hasPrefix("ip ") {
                        pingTarget = String(pingTarget.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if pingTarget.lowercased().hasPrefix("ping ") {
                        pingTarget = String(pingTarget.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if let mapped = userVariables[pingTarget] {
                        pingTarget = mapped
                    }
                    
                    let pingRes = await runRawShell("""
                    TARGET="\(pingTarget)"
                    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
                    PING_MS=$(ping -c 1 -t 2 "$TARGET" 2>/dev/null | awk -F'/' 'END{print $5}')
                    if [ -n "$PING_MS" ]; then
                        echo "内网IP: $LOCAL_IP | 目标 $TARGET 延迟: ${PING_MS}ms (连通良好 📶)"
                    else
                        echo "内网IP: $LOCAL_IP | 目标 $TARGET 连接超时 ⚠️"
                    fi
                    """)
                    lastOutput = pingRes
                    logs.append(" 网络目标诊断: \(lastOutput)")
                }
                
            case "applescript", "osascript":
                let scriptContent = interpolateVariables(rawArgs, variables: userVariables, lastOutput: lastOutput)
                guard !scriptContent.isEmpty else {
                    logs.append(" 错误: applescript 命令缺少脚本内容")
                    continue
                }
                let result = await SkillService.shared.runAppleScript(cleanQuotes(scriptContent))
                lastOutput = result.trimmingCharacters(in: .whitespacesAndNewlines)
                logs.append(" AppleScript 执行结果: \(lastOutput)")

            case "screenshot":
                let targetStr = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                let target: String? = targetStr.isEmpty ? nil : (targetStr as NSString).expandingTildeInPath
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
                let durStr = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                let argsParts = durStr.split(separator: " ").map(String.init)
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
                
            case "notify", "toast", "hud", "dialog":
                let (titleRaw, messageRaw) = parseNotificationArgs(rawArgs)
                let title = interpolateVariables(titleRaw, variables: userVariables, lastOutput: lastOutput)
                let message = interpolateVariables(messageRaw.isEmpty ? "$OUTPUT" : messageRaw, variables: userVariables, lastOutput: lastOutput)

                let finalTitle = title.isEmpty ? "YumiScript" : title
                let finalBody = message.isEmpty ? lastOutput : message

                // 1. 弹出专属精美渲染悬浮 HUD 弹窗（支持超长文本、全格式滚动、一键复制，彻底解决通知截断）
                PluginResultHUDManager.shared.show(
                    title: finalTitle,
                    message: finalBody,
                    icon: "bolt.fill",
                    isSuccess: !finalBody.contains("失败") && !finalBody.contains("错误")
                )

                // 2. 同时发送系统通知
                let content = UNMutableNotificationContent()
                content.title = finalTitle
                content.body = finalBody
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                UNUserNotificationCenter.current().add(request) { _ in }
                logs.append(" 发送通知/渲染弹窗: [\(finalTitle)] \(finalBody)")
                
            case "shell":
                let cmdToRun = interpolateVariables(rawArgs, variables: userVariables, lastOutput: lastOutput)
                guard !cmdToRun.isEmpty else {
                    logs.append(" 错误: shell 命令缺少指令参数")
                    continue
                }
                let cleanResult = await runRawShell(cmdToRun)
                lastOutput = cleanResult
                logs.append(" 执行 Shell 结果:\n\(cleanResult)")
                
            case "wait", "sleep":
                let secStr = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                guard let seconds = Double(secStr) else {
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
    
    // MARK: - 原生无包装 Shell 执行 (避免 JSON 污染)
    
    static func runRawShell(_ script: String) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try task.run()
                    task.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: "执行失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 变量解析与赋值
    
    /// 解析变量赋值语句：var a = "123", let b = hello, set count = 5, my_var = ...
    private static func parseVariableAssignment(_ line: String) -> (name: String, expr: String)? {
        var str = line
        if str.hasPrefix("var ") {
            str = String(str.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else if str.hasPrefix("let ") {
            str = String(str.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        } else if str.hasPrefix("set ") {
            str = String(str.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        }
        
        guard let eqIdx = str.firstIndex(of: "=") else { return nil }
        let varName = String(str[..<eqIdx]).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "$", with: "")
        let expr = String(str[str.index(after: eqIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !varName.isEmpty else { return nil }
        return (varName, expr)
    }
    
    /// 计算变量赋值右侧表达式 (支持直接值、shell 指令、paste 剪贴板、变量引用)
    private static func evaluateExpression(_ expr: String, variables: [String: String], lastOutput: String) async -> String {
        let interpolated = interpolateVariables(expr, variables: variables, lastOutput: lastOutput)
        let trimmed = cleanQuotes(interpolated)
        
        if trimmed.hasPrefix("shell ") {
            let cmd = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            return await runRawShell(cmd)
        } else if trimmed == "paste" || trimmed == "clipboard" {
            return NSPasteboard.general.string(forType: .string) ?? ""
        }
        
        return cleanQuotes(trimmed)
    }
    
    // MARK: - 变量替换
    
    static func interpolateVariables(_ input: String, variables: [String: String], lastOutput: String) -> String {
        var str = input
        
        // 1. 系统内置变量
        str = str.replacingOccurrences(of: "$OUTPUT", with: lastOutput)
        str = str.replacingOccurrences(of: "${OUTPUT}", with: lastOutput)
        
        if str.contains("$CLIPBOARD") || str.contains("${CLIPBOARD}") {
            let clip = NSPasteboard.general.string(forType: .string) ?? ""
            str = str.replacingOccurrences(of: "$CLIPBOARD", with: clip)
            str = str.replacingOccurrences(of: "${CLIPBOARD}", with: clip)
        }
        
        if str.contains("$DATE") || str.contains("$TIME") || str.contains("$DATETIME") || str.contains("$USER") || str.contains("$HOME") {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let dateStr = df.string(from: Date())
            df.dateFormat = "HH:mm:ss"
            let timeStr = df.string(from: Date())
            let datetimeStr = "\(dateStr) \(timeStr)"
            let user = NSUserName()
            let home = NSHomeDirectory()
            
            str = str.replacingOccurrences(of: "$DATE", with: dateStr)
            str = str.replacingOccurrences(of: "${DATE}", with: dateStr)
            str = str.replacingOccurrences(of: "$TIME", with: timeStr)
            str = str.replacingOccurrences(of: "${TIME}", with: timeStr)
            str = str.replacingOccurrences(of: "$DATETIME", with: datetimeStr)
            str = str.replacingOccurrences(of: "${DATETIME}", with: datetimeStr)
            str = str.replacingOccurrences(of: "$USER", with: user)
            str = str.replacingOccurrences(of: "${USER}", with: user)
            str = str.replacingOccurrences(of: "$HOME", with: home)
            str = str.replacingOccurrences(of: "${HOME}", with: home)
        }
        
        // 2. 自定义变量替换 ($var, ${var})
        for (key, value) in variables {
            str = str.replacingOccurrences(of: "${\(key)}", with: value)
            str = str.replacingOccurrences(of: "$\(key)", with: value)
        }
        
        return str
    }
    
    // MARK: - 通知参数精准解析
    
    /// 解析形如: "标题" "内容" 或 "标题" 内容 或 仅内容
    private static func parseNotificationArgs(_ raw: String) -> (title: String, message: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("YumiScript", "") }
        
        // 如果以引号开头
        if trimmed.hasPrefix("\"") {
            // 寻找第一个结束引号
            let restAfterFirstQuote = trimmed.dropFirst()
            if let endQuoteIdx = restAfterFirstQuote.firstIndex(of: "\"") {
                let title = String(restAfterFirstQuote[..<endQuoteIdx])
                let remainder = String(restAfterFirstQuote[restAfterFirstQuote.index(after: endQuoteIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let message = cleanQuotes(remainder)
                return (title, message)
            }
        }
        
        // 否则按第一个空格分割
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count >= 2 {
            return (cleanQuotes(String(parts[0])), cleanQuotes(String(parts[1])))
        } else {
            return ("YumiScript", cleanQuotes(trimmed))
        }
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
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'") && trimmed.count >= 2) {
            trimmed.removeFirst()
            trimmed.removeLast()
        }
        return trimmed
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
