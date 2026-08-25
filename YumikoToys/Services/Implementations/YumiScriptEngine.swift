//
//  YumiScriptEngine.swift
//  YumikoToys
//
//  自研 YumiScript 核心脚本编译与解析执行引擎（v6.0.0 快捷指令原子能力版）
//  支持：文件全套管理(读/写/追加/复制/移动/删)、YumikoToys本体操控(桌宠/主题/截图/录屏/纪念日)、AI大模型、系统API、TTS语音与模态输入
//

import Foundation
import AppKit
import UserNotifications
import Vision
import AVFoundation

/// YumiScript 核心执行引擎
@MainActor
final class YumiScriptEngine {
    
    /// 自定义宏过程存储表：宏名称 -> 脚本行
    private static var customMacros: [String: [String]] = [:]
    
    /// 执行一段 YumiScript 脚本并返回包含所有日志信息的输出文本
    static func execute(_ script: String) async -> String {
        var logs: [String] = []
        let lines = script.components(separatedBy: .newlines)
        var lastOutput: String = ""
        var userVariables: [String: String] = [:]
        
        logs.append("=== YumiScript Engine v6.0 (捷径原子能力 & YumikoToys控制) ===")
        logs.append("开始执行脚本，总行数: \(lines.count)")
        
        var lineIndex = 0
        while lineIndex < lines.count {
            let line = lines[lineIndex]
            lineIndex += 1
            
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过空行和注释行
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("//") {
                continue
            }
            
            // 0. 支持定义宏 / 插件过程 (def my_action ... end)
            if trimmed.lowercased().hasPrefix("def ") {
                let macroName = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "{", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                var macroLines: [String] = []
                while lineIndex < lines.count {
                    let subLine = lines[lineIndex]
                    lineIndex += 1
                    let subTrim = subLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    if subTrim == "end" || subTrim == "}" {
                        break
                    }
                    macroLines.append(subLine)
                }
                customMacros[macroName] = macroLines
                logs.append(" 注册自定义插件过程: [\(macroName)] (\(macroLines.count) 行)")
                continue
            }
            
            logs.append("[\(lineIndex)] 执行: \(trimmed)")
            
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
            guard let firstPart = parts.first else { continue }
            let command = String(firstPart).lowercased()
            let rawArgs = parts.count > 1 ? String(parts[1]) : ""
            
            // 3. 分发指令执行
            switch command {
            // MARK: - 文件与磁盘原子操作 (file write / append / read / delete / copy / move / mkdir / list / exists)
            case "file":
                let fileLog = await handleFileCommand(rawArgs: rawArgs, userVariables: userVariables, lastOutput: lastOutput)
                lastOutput = fileLog.output
                logs.append(" 📁 \(fileLog.message)")
                
            // MARK: - 操控 YumikoToys 本身 (app pet / theme / anniversary / screenshot / record)
            case "app", "yumiko":
                let appLog = await handleAppCommand(rawArgs: rawArgs, userVariables: userVariables, lastOutput: lastOutput)
                lastOutput = appLog.output
                logs.append(" 🐰 \(appLog.message)")
                
            // MARK: - 交互式输入框 (input "提示文本" ["默认值"])
            case "input", "prompt", "askinput":
                let (promptText, defaultVal) = parseNotificationArgs(rawArgs)
                let finalPrompt = interpolateVariables(promptText.isEmpty ? "请输入内容:" : promptText, variables: userVariables, lastOutput: lastOutput)
                let finalDef = interpolateVariables(defaultVal, variables: userVariables, lastOutput: lastOutput)
                
                let inputRes = await promptUserTextInput(prompt: finalPrompt, defaultValue: finalDef)
                lastOutput = inputRes
                logs.append(" ✍️ 用户输入结果: \"\(inputRes)\"")
                
            // MARK: - 调用自定义宏 / 插件过程 (call macro_name)
            case "call", "run":
                let macroName = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                if let macroBody = customMacros[macroName] {
                    logs.append(" 正在调用插件过程 [\(macroName)]...")
                    let subLogs = await execute(macroBody.joined(separator: "\n"))
                    logs.append(" 过程 [\(macroName)] 执行完成:\n\(subLogs)")
                } else {
                    logs.append(" 错误: 未找到名为 \"\(macroName)\" 的自定义插件过程")
                }
                
            // MARK: - AI 大模型指令 (ai / ask / glm)
            case "ai", "ask", "glm":
                let prompt = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                guard !prompt.isEmpty else {
                    logs.append(" 错误: ai 命令缺少提示词参数")
                    continue
                }
                logs.append(" 正在请求 AI 大模型分析处理...")
                do {
                    let aiResponse = try await DependencyContainer.shared.glmService.sendMessage(
                        prompt,
                        context: [],
                        saveToHistory: false
                    )
                    let cleanResp = aiResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    lastOutput = cleanResp
                    logs.append(" 🤖 AI 响应成功 (共 \(cleanResp.count) 字):\n\(cleanResp)")
                } catch {
                    let fallbackMsg = "AI 服务响应异常: \(error.localizedDescription)"
                    lastOutput = fallbackMsg
                    logs.append(" ⚠️ \(fallbackMsg)")
                }
                
            // MARK: - 语音合成 TTS (tts / say / speak)
            case "tts", "say", "speak":
                let textToSay = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                guard !textToSay.isEmpty else {
                    logs.append(" 错误: tts 命令缺少朗读文本")
                    continue
                }
                let synthesizer = NSSpeechSynthesizer()
                synthesizer.startSpeaking(textToSay)
                lastOutput = textToSay
                logs.append(" 🗣️ 语音朗读: \"\(textToSay)\"")
                
            // MARK: - 视觉 OCR 文字识别 (ocr)
            case "ocr":
                let pathArg = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                var imageToProcess: NSImage? = nil
                
                if pathArg.isEmpty {
                    // 默认截取当前主屏幕进行 OCR
                    let screenRes = await ScreenMediaHelper.shared.captureFullscreenAsync(targetPath: nil)
                    if let savedPath = screenRes.path {
                        imageToProcess = NSImage(contentsOfFile: savedPath)
                    }
                } else {
                    let expanded = (pathArg as NSString).expandingTildeInPath
                    imageToProcess = NSImage(contentsOfFile: expanded)
                }
                
                if let nsImg = imageToProcess, let cgImg = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    let ocrResult = await performOCR(on: cgImg)
                    lastOutput = ocrResult
                    logs.append(" 👁️ OCR 识别结果:\n\(ocrResult)")
                } else {
                    lastOutput = "OCR 读取图像失败"
                    logs.append(" ⚠️ OCR 处理失败：未获取到有效图像")
                }
                
            // MARK: - HTTP 网络请求 (http get / http post)
            case "http", "fetch":
                let argStr = interpolateVariables(rawArgs, variables: userVariables, lastOutput: lastOutput)
                let res = await performHttpRequest(argStr)
                lastOutput = res
                logs.append(" 🌐 HTTP 响应:\n\(res)")
                
            // MARK: - 交互式模态弹窗与输入 (alert / choose)
            case "alert":
                let (title, message) = parseNotificationArgs(rawArgs)
                let finalTitle = interpolateVariables(title, variables: userVariables, lastOutput: lastOutput)
                let finalMsg = interpolateVariables(message.isEmpty ? "$OUTPUT" : message, variables: userVariables, lastOutput: lastOutput)
                let alert = NSAlert()
                alert.messageText = finalTitle.isEmpty ? "YumiScript 提示" : finalTitle
                alert.informativeText = finalMsg
                alert.addButton(withTitle: "确定")
                alert.addButton(withTitle: "取消")
                let response = alert.runModal()
                lastOutput = (response == .alertFirstButtonReturn) ? "确定" : "取消"
                logs.append(" 💬 模态弹窗用户选择: \(lastOutput)")
                
            case "choose", "select":
                let optionsRaw = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                let options = optionsRaw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                if let chosen = await promptChoose(options: options) {
                    lastOutput = chosen
                    logs.append(" 📋 用户选择项: \"\(chosen)\"")
                } else {
                    lastOutput = "未选择"
                    logs.append(" 📋 用户取消了选择")
                }
                
            // MARK: - 启动应用
            case "launch":
                let appName = interpolateVariables(cleanQuotes(rawArgs), variables: userVariables, lastOutput: lastOutput)
                guard !appName.isEmpty else {
                    logs.append(" 错误: launch 命令缺少应用名称")
                    continue
                }
                
                let resolvedPath = resolveInstalledAppPath(appName)
                guard let safeResolvedPath = resolvedPath else {
                    logs.append(" 启动失败: 找不到应用 \"\(appName)\"（已搜索 /Applications、/System/Applications 和已安装的 bundle id）")
                    logs.append(" 提示: 请确认应用名拼写正确，且应用已安装")
                    continue
                }

                let allowMultiple = DependencyContainer.shared.settingsService.settings.allowMultipleInstances
                let url = URL(fileURLWithPath: safeResolvedPath)
                var success = false

                if allowMultiple {
                    // 多开模式：通过 macOS 原生 /usr/bin/open -n 分离进程实现真多开
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    process.arguments = ["-n", safeResolvedPath]
                    success = await withCheckedContinuation { continuation in
                        process.terminationHandler = { p in
                            continuation.resume(returning: p.terminationStatus == 0)
                        }
                        do {
                            try process.run()
                        } catch {
                            continuation.resume(returning: false)
                        }
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
                    logs.append(" 启动应用 \"\(appName)\" 成功\(allowMultiple ? " [多开独立实例]" : "")（\(safeResolvedPath)）")
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
                
            // MARK: - 系统高级控制与硬件 API
            case "sys", "system", "ping":
                var targetArg = interpolateVariables(rawArgs, variables: userVariables, lastOutput: lastOutput).trimmingCharacters(in: .whitespacesAndNewlines)
                if let varValue = userVariables[targetArg] {
                    targetArg = varValue
                }
                
                let lowerArg = targetArg.lowercased()
                
                if lowerArg == "lock" {
                    lockScreen()
                    lastOutput = "屏幕已锁定"
                    logs.append(" 已锁定 Mac 屏幕 🔒")
                } else if lowerArg == "sleep" || lowerArg == "locksleep" || lowerArg == "lockandsleep" {
                    lockScreen()
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    let _ = await SkillService.shared.runAppleScript("tell application \"System Events\" to sleep")
                    lastOutput = "已锁定屏幕并进入系统休眠"
                    logs.append(" 已锁定屏幕并进入休眠 🌙💤")
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
                } else if lowerArg == "battery" {
                    let battRes = await runRawShell("pmset -g batt | grep -o '[0-9]*%; [a-zA-Z]*' || pmset -g batt")
                    lastOutput = "电池状态: " + battRes
                    logs.append(" 🔋 \(lastOutput)")
                } else if lowerArg.hasPrefix("volume") {
                    let volArg = lowerArg.replacingOccurrences(of: "volume", with: "").trimmingCharacters(in: .whitespaces)
                    if let volVal = Int(volArg) {
                        let _ = await SkillService.shared.runAppleScript("set volume output volume \(max(0, min(100, volVal)))")
                        lastOutput = "音量已设置为 \(volVal)%"
                    } else if volArg == "mute" || volArg == "togglemute" {
                        let _ = await SkillService.shared.runAppleScript("""
                        set curMute to output muted of (get volume settings)
                        set volume output muted (not curMute)
                        """)
                        lastOutput = "已切换系统静音状态 🔇"
                    } else {
                        let curVol = await SkillService.shared.runAppleScript("output volume of (get volume settings)")
                        lastOutput = "当前音量: \(curVol.trimmingCharacters(in: .whitespacesAndNewlines))%"
                    }
                    logs.append(" 🔊 \(lastOutput)")
                } else if lowerArg.hasPrefix("brightness") {
                    let bArg = lowerArg.replacingOccurrences(of: "brightness", with: "").trimmingCharacters(in: .whitespaces)
                    if let bVal = Double(bArg) {
                        let percent = max(0.0, min(1.0, bVal / 100.0))
                        let _ = await runRawShell("brightness \(percent) 2>/dev/null || true")
                        lastOutput = "屏幕亮度已调至 \(Int(bVal))%"
                    } else {
                        lastOutput = "屏幕亮度调节完成"
                    }
                    logs.append(" 🔆 \(lastOutput)")
                } else if lowerArg == "beep" {
                    NSSound.beep()
                    lastOutput = "已播放蜂鸣提示音 🔔"
                    logs.append(" 🔔 \(lastOutput)")
                } else if lowerArg.hasPrefix("finder") || lowerArg.hasPrefix("reveal") {
                    let path = targetArg.replacingOccurrences(of: "finder", with: "").replacingOccurrences(of: "reveal", with: "").trimmingCharacters(in: .whitespaces)
                    let expanded = (path as NSString).expandingTildeInPath
                    NSWorkspace.shared.selectFile(expanded, inFileViewerRootedAtPath: "")
                    lastOutput = "已在访达中定位: \(expanded)"
                    logs.append(" 📁 \(lastOutput)")
                } else if lowerArg.hasPrefix("trash") {
                    let path = targetArg.replacingOccurrences(of: "trash", with: "").trimmingCharacters(in: .whitespaces)
                    let expanded = (path as NSString).expandingTildeInPath
                    let url = URL(fileURLWithPath: expanded)
                    try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    lastOutput = "已移入废纸篓: \(expanded)"
                    logs.append(" 🗑️ \(lastOutput)")
                } else if lowerArg == "togglemute" || lowerArg == "mute" {
                    let _ = await SkillService.shared.runAppleScript("""
                    set curMute to output muted of (get volume settings)
                    set volume output muted (not curMute)
                    """)
                    lastOutput = "已切换系统静音状态 🔇"
                    logs.append(" \(lastOutput)")
                } else if lowerArg == "ip" || lowerArg.isEmpty {
                    let res = await measureNetworkLatency(to: "223.5.5.5")
                    if let ms = res.latency {
                        lastOutput = "内网IP: \(res.localIP) | 延迟: \(String(format: "%.1f", ms))ms (连通正常 📶)"
                    } else {
                        lastOutput = "内网IP: \(res.localIP) | 网络离线 ⚠️"
                    }
                    logs.append(" 网络诊断结果: \(lastOutput)")
                } else {
                    var pingTarget = targetArg
                    if pingTarget.lowercased().hasPrefix("ip ") {
                        pingTarget = String(pingTarget.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if pingTarget.lowercased().hasPrefix("ping ") {
                        pingTarget = String(pingTarget.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if let mapped = userVariables[pingTarget] {
                        pingTarget = mapped
                    }
                    
                    let res = await measureNetworkLatency(to: pingTarget)
                    if let ms = res.latency {
                        lastOutput = "内网IP: \(res.localIP) | 目标 \(pingTarget) 延迟: \(String(format: "%.1f", ms))ms (连通良好 📶)"
                    } else {
                        lastOutput = "内网IP: \(res.localIP) | 目标 \(pingTarget) 连接超时 ⚠️"
                    }
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

                // 1. 弹出专属精美渲染悬浮 HUD 弹窗
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
    
    // MARK: - 文件与磁盘原子操作处理器 (File Operations)
    
    private static func handleFileCommand(rawArgs: String, userVariables: [String: String], lastOutput: String) async -> (output: String, message: String) {
        let parts = rawArgs.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let first = parts.first else {
            return ("", "错误: file 指令缺少子操作 (write/read/append/delete/copy/move/mkdir/list/exists)")
        }
        
        let op = String(first).lowercased()
        let rest = parts.count > 1 ? String(parts[1]) : ""
        let fileManager = FileManager.default
        
        switch op {
        case "write", "save":
            // file write "路径" "内容"
            let (pathRaw, contentRaw) = parseNotificationArgs(rest)
            let path = (interpolateVariables(cleanQuotes(pathRaw), variables: userVariables, lastOutput: lastOutput) as NSString).expandingTildeInPath
            let content = interpolateVariables(contentRaw.isEmpty ? lastOutput : contentRaw, variables: userVariables, lastOutput: lastOutput)
            
            guard !path.isEmpty else { return ("", "错误: file write 缺少目标路径") }
            
            let dirUrl = URL(fileURLWithPath: path).deletingLastPathComponent()
            try? fileManager.createDirectory(at: dirUrl, withIntermediateDirectories: true)
            
            do {
                try content.write(toFile: path, atomically: true, encoding: .utf8)
                return (path, "成功写入文件: \(path) (共 \(content.count) 字符)")
            } catch {
                return ("", "写入文件失败: \(error.localizedDescription)")
            }
            
        case "append":
            // file append "路径" "内容"
            let (pathRaw, contentRaw) = parseNotificationArgs(rest)
            let path = (interpolateVariables(cleanQuotes(pathRaw), variables: userVariables, lastOutput: lastOutput) as NSString).expandingTildeInPath
            let content = interpolateVariables(contentRaw.isEmpty ? lastOutput : contentRaw, variables: userVariables, lastOutput: lastOutput)
            
            guard !path.isEmpty else { return ("", "错误: file append 缺少目标路径") }
            
            let fileUrl = URL(fileURLWithPath: path)
            let dirUrl = fileUrl.deletingLastPathComponent()
            try? fileManager.createDirectory(at: dirUrl, withIntermediateDirectories: true)
            
            if !fileManager.fileExists(atPath: path) {
                try? content.write(toFile: path, atomically: true, encoding: .utf8)
                return (content, "文件不存在，已新建并写入: \(path)")
            } else {
                if let fileHandle = try? FileHandle(forWritingTo: fileUrl) {
                    fileHandle.seekToEndOfFile()
                    if let data = ("\n" + content).data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    try? fileHandle.close()
                    return (content, "成功追加内容到文件: \(path)")
                } else {
                    return ("", "无法打开文件进行追加")
                }
            }
            
        case "read":
            // file read "路径"
            let path = (interpolateVariables(cleanQuotes(rest), variables: userVariables, lastOutput: lastOutput) as NSString).expandingTildeInPath
            guard !path.isEmpty else { return ("", "错误: file read 缺少路径") }
            
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                return (content, "读取文件成功 (\(content.count) 字符): \(path)")
            } catch {
                return ("", "读取文件失败: \(error.localizedDescription)")
            }
            
        case "delete", "trash", "remove":
            // file delete "路径"
            let path = (interpolateVariables(cleanQuotes(rest), variables: userVariables, lastOutput: lastOutput) as NSString).expandingTildeInPath
            guard !path.isEmpty else { return ("", "错误: file delete 缺少路径") }
            let url = URL(fileURLWithPath: path)
            
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                return (path, "已将文件安全移入废纸篓: \(path)")
            } catch {
                do {
                    try fileManager.removeItem(at: url)
                    return (path, "已永久删除文件: \(path)")
                } catch {
                    return ("", "删除文件失败: \(error.localizedDescription)")
                }
            }
            
        case "mkdir":
            // file mkdir "目录路径"
            let path = (interpolateVariables(cleanQuotes(rest), variables: userVariables, lastOutput: lastOutput) as NSString).expandingTildeInPath
            guard !path.isEmpty else { return ("", "错误: file mkdir 缺少目录路径") }
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
                return (path, "成功创建目录: \(path)")
            } catch {
                return ("", "创建目录失败: \(error.localizedDescription)")
            }
            
        case "list":
            // file list "目录路径"
            let path = (interpolateVariables(cleanQuotes(rest), variables: userVariables, lastOutput: lastOutput) as NSString).expandingTildeInPath
            guard !path.isEmpty else { return ("", "错误: file list 缺少目录路径") }
            if let files = try? fileManager.contentsOfDirectory(atPath: path) {
                let joined = files.joined(separator: ", ")
                return (joined, "目录内共有 \(files.count) 个文件: \(joined)")
            } else {
                return ("", "读取目录文件清单失败")
            }
            
        case "exists":
            // file exists "路径"
            let path = (interpolateVariables(cleanQuotes(rest), variables: userVariables, lastOutput: lastOutput) as NSString).expandingTildeInPath
            let exists = fileManager.fileExists(atPath: path)
            return (exists ? "true" : "false", "检查路径存在性: \(path) -> \(exists ? "存在" : "不存在")")
            
        default:
            return ("", "未知 file 子指令 \"\(op)\"")
        }
    }
    
    // MARK: - 操控 YumikoToys 本身原子处理器 (YumikoToys Internal App Controls)
    
    private static func handleAppCommand(rawArgs: String, userVariables: [String: String], lastOutput: String) async -> (output: String, message: String) {
        let parts = rawArgs.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let domain = parts.first?.lowercased() else {
            return ("", "错误: app 指令缺少功能域 (pet/theme/anniversary/screenshot/record/hud)")
        }
        
        let subArg = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() : ""
        
        switch domain {
        // MARK: 🐶 桌面桌宠控制
        case "pet":
            if subArg == "on" || subArg == "start" || subArg == "summon" {
                PetPlaygroundService.shared.setEnabled(true)
                return ("桌宠已开启", "桌宠已就绪并降临桌面 🐾")
            } else if subArg == "off" || subArg == "stop" || subArg == "dismiss" {
                PetPlaygroundService.shared.setEnabled(false)
                return ("桌宠已隐藏", "桌宠已安全收回休息 💤")
            } else if subArg == "toggle" || subArg.isEmpty {
                let current = PetPlaygroundService.shared.isEnabled
                PetPlaygroundService.shared.setEnabled(!current)
                return (!current ? "桌宠已开启" : "桌宠已隐藏", "已切换桌宠状态 -> \(!current ? "显示 🐾" : "隐藏 💤")")
            } else if subArg == "status" {
                let st = PetPlaygroundService.shared.isEnabled ? "正在运行" : "已休眠"
                return (st, "当前桌宠状态: \(st)")
            } else {
                return ("", "未知 pet 指令: \(subArg) (支持: on, off, toggle, status)")
            }
            
        // MARK: 🎨 二次元主题控制
        case "theme":
            if subArg == "toggle" || subArg.isEmpty {
                AnimeThemeService.shared.isEnabled.toggle()
                let cur = AnimeThemeService.shared.isEnabled
                return (cur ? "二次元主题已开启" : "二次元主题已关闭", "已切换二次元主题 -> \(cur ? "开启 🌸" : "关闭")")
            } else if subArg == "healing" {
                AnimeThemeService.shared.isEnabled = true
                AnimeThemeService.shared.currentStyle = .healing
                return ("日系治愈", "已切换为【日系治愈风】主题 🌸")
            } else if subArg == "cyber" {
                AnimeThemeService.shared.isEnabled = true
                AnimeThemeService.shared.currentStyle = .cyber
                return ("赛博二次元", "已切换为【赛博朋克】主题 ⚡")
            } else if subArg == "kawaii" {
                AnimeThemeService.shared.isEnabled = true
                AnimeThemeService.shared.currentStyle = .kawaii
                return ("软萌可爱", "已切换为【软萌可爱】主题 🎀")
            } else if subArg == "makoto" {
                AnimeThemeService.shared.isEnabled = true
                AnimeThemeService.shared.currentStyle = .makoto
                return ("新海诚写实", "已切换为【新海诚精致写实】主题 ☁️")
            } else {
                return ("", "未知 theme 风格: \(subArg) (支持: toggle, healing, cyber, kawaii, makoto)")
            }
            
        // MARK: 📅 纪念日查询
        case "anniversary":
            let annivService = DependencyContainer.shared.anniversaryService
            let info = annivService.activeAnniversaryInfo
            if let target = annivService.activeAnniversary {
                let days = info?.calculation.days ?? 0
                let text = "\(target.title): \(days) 天"
                return (text, "置顶纪念日 -> \(text)")
            } else {
                return ("无置顶纪念日", "当前未设置置顶纪念日")
            }
            
        // MARK: 📸 触发截图与录屏
        case "screenshot":
            if subArg == "area" {
                ScreenMediaHelper.shared.captureArea()
                return ("区域截图已触发", "已开启区域截图")
            } else if subArg == "annotate" {
                ScreenMediaHelper.shared.openScreenshotAnnotation()
                return ("截图标注已打开", "已启动截图标注工具")
            } else if subArg == "touchbar" {
                ScreenMediaHelper.shared.captureTouchBar()
                return ("TouchBar截图已触发", "已触发 TouchBar 截图")
            } else {
                ScreenMediaHelper.shared.captureFullscreen()
                return ("全屏截图已触发", "已截取全屏并复制到剪贴板")
            }
            
        default:
            return ("", "未知 app 子指令 \"\(domain)\"")
        }
    }
    
    // MARK: - 交互式文本输入提示框
    
    private static func promptUserTextInput(prompt: String, defaultValue: String) async -> String {
        let script = """
        display dialog "\(prompt.replacingOccurrences(of: "\"", with: "\\\""))" default answer "\(defaultValue.replacingOccurrences(of: "\"", with: "\\\""))" with title "YumiScript 用户输入" buttons {"确定", "取消"} default button "确定"
        text returned of result
        """
        let res = await SkillService.shared.runAppleScript(script)
        let trimmed = res.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "false" || trimmed.contains("error") {
            return defaultValue
        }
        return trimmed
    }
    
    // MARK: - 视觉 OCR 文字识别引擎
    
    private static func performOCR(on cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { (request, error) in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "OCR 识别出错: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - HTTP 网络请求处理
    
    private static func performHttpRequest(_ raw: String) async -> String {
        let parts = raw.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let first = parts.first else { return "HTTP 参数缺失" }
        
        let method = String(first).uppercased()
        let rest = parts.count > 1 ? String(parts[1]) : ""
        
        var targetUrlStr = rest
        var postData: String? = nil
        
        if method == "POST" {
            let postParts = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            targetUrlStr = String(postParts.first ?? "")
            postData = postParts.count > 1 ? cleanQuotes(String(postParts[1])) : nil
        }
        
        guard let url = URL(string: cleanQuotes(targetUrlStr)) else {
            return "无效的 URL: \(targetUrlStr)"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = (method == "POST") ? "POST" : "GET"
        request.timeoutInterval = 10.0
        
        if let postData = postData {
            request.httpBody = postData.data(using: .utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            let body = String(data: data, encoding: .utf8) ?? "无法解析的二进制响应"
            return "HTTP \(status):\n\(body)"
        } catch {
            return "HTTP 请求失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 原生无包装 Shell 执行 (避免 JSON 污染，采用非阻塞 terminationHandler)
    
    static func runRawShell(_ script: String) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        return await withCheckedContinuation { continuation in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                continuation.resume(returning: output)
            }
            do {
                try task.run()
            } catch {
                continuation.resume(returning: "执行失败: \(error.localizedDescription)")
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
        
        // 校验变量名格式：仅允许字母、数字、下划线且不能包含空格
        guard !varName.isEmpty, !varName.contains(" ") else { return nil }
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
            let restAfterFirstQuote = trimmed.dropFirst()
            if let endQuoteIdx = restAfterFirstQuote.firstIndex(of: "\"") {
                let title = String(restAfterFirstQuote[..<endQuoteIdx])
                let remainder = String(restAfterFirstQuote[restAfterFirstQuote.index(after: endQuoteIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let message = cleanQuotes(remainder)
                return (title, message)
            }
        }
        
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count >= 2 {
            return (cleanQuotes(String(parts[0])), cleanQuotes(String(parts[1])))
        } else {
            return ("YumiScript", cleanQuotes(trimmed))
        }
    }
    
    // MARK: - 交互式菜单选择
    
    private static func promptChoose(options: [String]) async -> String? {
        let joined = options.map { "\"\($0)\"" }.joined(separator: ", ")
        let script = """
        choose from list {\(joined)} with prompt "请选择要执行的项目:" default items {item 1 of {\(joined)}}
        """
        let res = await SkillService.shared.runAppleScript(script)
        let trimmed = res.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "false" || trimmed.contains("error") || trimmed.isEmpty {
            return nil
        }
        return trimmed
    }
    
    // MARK: - 系统锁屏
    
    private static func lockScreen() {
        var locked = false
        if let libHandle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY) {
            if let sym = dlsym(libHandle, "SACLockScreenImmediate") {
                typealias Func = @convention(c) () -> Void
                let fn = unsafeBitCast(sym, to: Func.self)
                fn()
                locked = true
            }
            dlclose(libHandle)
        }
        if !locked {
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

    /// 解析已安装应用路径
    private static func resolveInstalledAppPath(_ appName: String) -> String? {
        let trimmedName = cleanQuotes(appName)
        if trimmedName.hasPrefix("/") && FileManager.default.fileExists(atPath: trimmedName) {
            return trimmedName
        }

        let allDirs = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices",
            "/System/Library/CoreServices/Applications",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
        ]

        for dir in allDirs {
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for item in items where item.hasSuffix(".app") {
                let nameWithoutExt = (item as NSString).deletingPathExtension
                if nameWithoutExt.caseInsensitiveCompare(trimmedName) == .orderedSame {
                    return (dir as NSString).appendingPathComponent(item)
                }
            }
        }
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

    /// 双协议混合测速（ICMP Ping + TCP 端口自适应握手）
    private static func measureNetworkLatency(to target: String) async -> (localIP: String, latency: Double?, isOnline: Bool) {
        let localIP = await runRawShell("ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || ipconfig getifaddr en2 2>/dev/null || echo \"127.0.0.1\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let pingRaw = await runRawShell("ping -c 2 -W 1500 \(target) 2>/dev/null")
        if let timeRange = pingRaw.range(of: #"time=([0-9.]+)\s*ms"#, options: .regularExpression) {
            let match = String(pingRaw[timeRange])
            let numStr = match.replacingOccurrences(of: "time=", with: "").replacingOccurrences(of: "ms", with: "").trimmingCharacters(in: .whitespaces)
            if let ms = Double(numStr) {
                return (localIP, ms, true)
            }
        }
        
        for port in [53, 80, 443, 22] {
            let start = Date()
            let ncRes = await runRawShell("nc -z -G 1.5 \(target) \(port) 2>/dev/null && echo OK")
            if ncRes.contains("OK") {
                let elapsedMs = max(1.0, Double(round(Date().timeIntervalSince(start) * 10000) / 10))
                return (localIP, elapsedMs, true)
            }
        }
        
        return (localIP, nil, false)
    }
}
