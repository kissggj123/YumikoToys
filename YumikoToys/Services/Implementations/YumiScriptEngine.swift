//
//  YumiScriptEngine.swift
//  YumikoToys
//
//  自研 YumiScript 脚本编译与解析器（v1.0.0）
//

import Foundation
import AppKit

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
                let appleScript = "tell application \"\(argsStr)\" to activate"
                let result = await SkillService.shared.runAppleScript(appleScript)
                if result.contains("error") {
                    logs.append(" 启动失败: \(result)")
                } else {
                    logs.append(" 启动应用 \"\(argsStr)\" 成功")
                }
                
            case "screenshot":
                let path: String
                if argsStr.isEmpty {
                    let df = DateFormatter()
                    df.dateFormat = "yyyyMMdd_HHmmss"
                    let filename = "screenshot_\(df.string(from: Date())).png"
                    path = "~/Desktop/\(filename)"
                } else {
                    path = argsStr
                }

                let shellCmd = "screencapture -x \"\(path)\""
                let result = await SkillService.shared.runShell(shellCmd)
                if result.contains("error") || result.isEmpty {
                    logs.append(" 截图失败: \(result)")
                    logs.append(" 提示：若截图失败，请到 系统设置 > 隐私与安全性 > 屏幕录制 中开启权限。")
                } else {
                    logs.append(" 截图成功，已保存至 \(path)")
                }

            case "record":
                let argsParts = argsStr.components(separatedBy: " ")
                let duration = argsParts.first.flatMap(Int.init) ?? 5

                let path: String
                if argsParts.count > 1 {
                    path = argsParts[1]
                } else {
                    let df = DateFormatter()
                    df.dateFormat = "yyyyMMdd_HHmmss"
                    let filename = "recording_\(df.string(from: Date())).mov"
                    path = "~/Desktop/\(filename)"
                }

                logs.append(" 开始录屏 \(duration) 秒，请勿遮挡屏幕...")
                let shellCmd = "screencapture -V \(duration) \"\(path)\""
                let result = await SkillService.shared.runShell(shellCmd)
                if result.contains("error") || result.isEmpty {
                    logs.append(" 录屏失败: \(result)")
                    logs.append(" 提示：若录屏失败，请到 系统设置 > 隐私与安全性 > 屏幕录制 中开启权限。")
                } else {
                    logs.append(" 录屏成功，已保存至 \(path)")
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
                
                let appleScript = "display notification \"\(message)\" with title \"\(title)\""
                _ = await SkillService.shared.runAppleScript(appleScript)
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
}
