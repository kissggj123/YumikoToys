//
//  FullDiskAccessHelper.swift
//  YumikoToys
//
//  完全磁盘访问权限检测与引导助手
//

import Foundation
import AppKit
import SwiftUI

public struct FullDiskAccessHelper {
    
    /// 检查当前应用是否拥有完全磁盘访问权限（FDA）
    public static var hasFullDiskAccess: Bool {
        // 获取真实的用户 Home 目录与 Sandbox Home 目录
        var homeDirs = [NSHomeDirectory()]
        if let pw = getpwuid(getuid()), let home = pw.pointee.pw_dir {
            let realHome = String(cString: home)
            if !homeDirs.contains(realHome) {
                homeDirs.append(realHome)
            }
        }
        
        // 0. 模拟写入空临时文件进行写测试（针对自签名应用优化）
        for home in homeDirs {
            let writePaths = [
                home + "/Library/Application Support/com.apple.TCC/YumikoToys_test_fda.txt",
                home + "/Library/Safari/YumikoToys_test_fda.txt"
            ]
            for path in writePaths {
                if let file = fopen(path, "w") {
                    fclose(file)
                    remove(path)
                    return true
                }
            }
        }
        
        // 收集待测试的受 TCC 保护的文件路径
        var testPaths: [String] = []
        for home in homeDirs {
            testPaths.append(home + "/Library/Application Support/com.apple.TCC/TCC.db")
            testPaths.append(home + "/Library/Safari/History.db")
            testPaths.append(home + "/Library/Safari/Bookmarks.plist")
            testPaths.append(home + "/Library/Messages/chat.db")
        }
        testPaths.append("/Library/Preferences/com.apple.TimeMachine.plist")
        
        // 1. 尝试使用 fopen 打开受保护的文件
        for path in testPaths {
            if let file = fopen(path, "r") {
                fclose(file)
                return true
            } else {
                // 如果 fopen 返回 NULL，且错误码是 ENOENT (文件不存在)，
                // 说明我们有权限访问该目录（否则会被拒绝并返回 EACCES 或 EPERM）。
                // 对于确定的系统受保护路径（如 com.apple.TCC/TCC.db 或 Safari/History.db），
                // 能够确定文件不存在本身就意味着我们拥有目录遍历/读取权限，即拥有 FDA。
                if errno == ENOENT {
                    return true
                }
            }
        }
        
        // 收集待测试的受 TCC 保护的目录路径
        var testDirs: [String] = []
        for home in homeDirs {
            testDirs.append(home + "/Library/Application Support/com.apple.TCC")
            testDirs.append(home + "/Library/Safari")
            testDirs.append(home + "/Library/Messages")
            testDirs.append(home + "/Library/Mail")
        }
        
        // 2. 尝试列出受限文件夹的内容
        for dir in testDirs {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue {
                do {
                    _ = try FileManager.default.contentsOfDirectory(atPath: dir)
                    return true
                } catch {
                    // 如果错误不是权限拒绝（比如目录为空等其他原因），也有可能意味着 FDA 已赋予
                    let nsError = error as NSError
                    if nsError.domain == NSCocoaErrorDomain {
                        // Cocoa error 257 = NSFileReadNoPermissionError
                        // Cocoa error 513 = NSFileWriteNoPermissionError
                        if nsError.code != 257 && nsError.code != 513 {
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    /// 跳转到系统设置的完全磁盘访问权限面板
    public static func openSystemPrivacySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - 大模型技能系统定义

public struct LLMSkill: Codable, Sendable, Identifiable {
    public var id: String { name }
    public var name: String
    public var description: String
    public var parametersJSON: String
    public var scriptType: String // "shell", "applescript", "theme"
    public var scriptContent: String
}

@MainActor
public final class SkillService: ObservableObject {
    public static let shared = SkillService()
    
    @Published public var customSkills: [LLMSkill] = []
    
    private let userDefaultsKey = "YumikoToys_CustomSkills"
    
    private init() {
        loadSkills()
    }
    
    public func loadSkills() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let skills = try? JSONDecoder().decode([LLMSkill].self, from: data) {
            self.customSkills = skills
        } else {
            self.customSkills = []
        }
    }
    
    public func saveSkills() {
        if let data = try? JSONEncoder().encode(customSkills) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    public func addOrUpdateSkill(_ skill: LLMSkill) {
        if let index = customSkills.firstIndex(where: { $0.name == skill.name }) {
            customSkills[index] = skill
        } else {
            customSkills.append(skill)
        }
        saveSkills()
    }
    
    public func deleteSkill(name: String) {
        customSkills.removeAll(where: { $0.name == name })
        saveSkills()
    }
    
    // Built-in skills definition
    public func getBuiltInSkills() -> [LLMSkill] {
        return [
            LLMSkill(
                name: "set_god_mode_style",
                description: "调整上帝模式（God Mode）的主题颜色和大小参数，自定义一切界面的背景、文字、卡片、描边、圆角等。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "enabled": {"type": "boolean", "description": "是否开启上帝模式/自定义主题颜色配置"},
                        "backgroundColorHex": {"type": "string", "description": "主背景色十六进制码，如 #1E1E2E"},
                        "cardBackgroundColorHex": {"type": "string", "description": "卡片及聊天气泡背景色十六进制码，如 #252538"},
                        "textColorHex": {"type": "string", "description": "主文本颜色十六进制码，如 #FFFFFF"},
                        "accentColorHex": {"type": "string", "description": "主题强调色/按钮突出色十六进制码，如 #8B5CF6"},
                        "borderColorHex": {"type": "string", "description": "边框和描边颜色十六进制码，如 #3F3F5F"},
                        "dividerColorHex": {"type": "string", "description": "分割线颜色十六进制码，如 #2E2E3E"},
                        "cornerRadius": {"type": "number", "description": "圆角半径大小（4.0到32.0之间），例如 16.0"}
                    },
                    "required": ["enabled"]
                }
                """,
                scriptType: "theme",
                scriptContent: ""
            ),
            LLMSkill(
                name: "run_shell_command",
                description: "执行自定义 Terminal 终端 shell 脚本指令，并获取返回的控制台输出。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "command": {"type": "string", "description": "要执行的 Shell 指令或脚本内容，例如 ls -la 或 ps aux"}
                    },
                    "required": ["command"]
                }
                """,
                scriptType: "shell",
                scriptContent: "{{command}}"
            ),
            LLMSkill(
                name: "open_macos_application",
                description: "通过 AppleScript 运行/唤醒指定的 macOS 应用程序。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "appName": {"type": "string", "description": "应用程序的名称，例如 Safari 或 Xcode"}
                    },
                    "required": ["appName"]
                }
                """,
                scriptType: "applescript",
                scriptContent: "tell application \"{{appName}}\" to activate"
            ),
            LLMSkill(
                name: "get_system_info",
                description: "快速抓取当前 macOS 系统的硬件及运行状态，包括系统版本、CPU负载和物理内存分配用量。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {},
                    "required": []
                }
                """,
                scriptType: "shell",
                scriptContent: "echo \"=== OS Info ===\"; uname -a; sw_vers; echo \"=== CPU Usage ===\"; top -l 1 | head -n 12; echo \"=== Memory Stats ===\"; vm_stat | head -n 8"
            )
        ]
    }
    
    public func getAllSkills() -> [LLMSkill] {
        return getBuiltInSkills() + customSkills
    }
    
    public func executeSkill(name: String, arguments: [String: Any]) async -> String {
        guard let skill = getAllSkills().first(where: { $0.name == name }) else {
            return "{\"error\": \"未找到对应技能: \(name)\"}"
        }
        
        if skill.scriptType == "theme" || name == "set_god_mode_style" {
            return await executeGodModeSkill(arguments: arguments)
        }
        
        // Process arguments substitution
        var script = skill.scriptContent
        for (key, value) in arguments {
            let strVal = "\(value)"
            script = script.replacingOccurrences(of: "{{\(key)}}", with: strVal)
        }
        
        if skill.scriptType == "shell" {
            return await runShell(script)
        } else if skill.scriptType == "applescript" {
            return await runAppleScript(script)
        }
        
        return "{\"error\": \"未知的技能类型: \(skill.scriptType)\"}"
    }
    
    private func executeGodModeSkill(arguments: [String: Any]) async -> String {
        let settingsService = DependencyContainer.shared.settingsService
        var currentSettings = settingsService.settings
        
        if let enabled = arguments["enabled"] as? Bool {
            currentSettings.godModeEnabled = enabled
        }
        
        if let bgHex = arguments["backgroundColorHex"] as? String {
            currentSettings.customBackgroundColorHex = cleanHex(bgHex)
        }
        
        if let cardHex = arguments["cardBackgroundColorHex"] as? String {
            currentSettings.customCardBackgroundColorHex = cleanHex(cardHex)
        }
        
        if let textHex = arguments["textColorHex"] as? String {
            currentSettings.customTextColorHex = cleanHex(textHex)
        }
        
        if let accentHex = arguments["accentColorHex"] as? String {
            currentSettings.customAccentColorHex = cleanHex(accentHex)
        }
        
        if let borderHex = arguments["borderColorHex"] as? String {
            currentSettings.customBorderColorHex = cleanHex(borderHex)
        }
        
        if let dividerHex = arguments["dividerColorHex"] as? String {
            currentSettings.customDividerColorHex = cleanHex(dividerHex)
        }
        
        if let radius = arguments["cornerRadius"] as? Double {
            currentSettings.customCornerRadius = radius
        } else if let radiusInt = arguments["cornerRadius"] as? Int {
            currentSettings.customCornerRadius = Double(radiusInt)
        }
        
        let settingsToUpdate = currentSettings
        await MainActor.run {
            settingsService.updateSettings(settingsToUpdate)
        }
        
        let responseDict: [String: Any] = [
            "success": true,
            "message": "上帝模式配色修改成功",
            "godModeEnabled": settingsToUpdate.godModeEnabled,
            "backgroundColor": settingsToUpdate.customBackgroundColorHex,
            "cardBackgroundColor": settingsToUpdate.customCardBackgroundColorHex,
            "textColor": settingsToUpdate.customTextColorHex,
            "accentColor": settingsToUpdate.customAccentColorHex,
            "borderColor": settingsToUpdate.customBorderColorHex,
            "dividerColor": settingsToUpdate.customDividerColorHex,
            "cornerRadius": settingsToUpdate.customCornerRadius
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: responseDict, options: [.prettyPrinted]),
           let jsonStr = String(data: data, encoding: .utf8) {
            return jsonStr
        }
        return "{\"success\": true}"
    }
    
    private func cleanHex(_ hex: String) -> String {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") {
            clean.removeFirst()
        }
        return clean.uppercased()
    }
    
    private func runShell(_ script: String) async -> String {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let cleanOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                let response: [String: String] = ["output": cleanOutput]
                if let jsonData = try? JSONSerialization.data(withJSONObject: response, options: []),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    return jsonStr
                }
                return output
            }
            return "{\"status\": \"executed\"}"
        } catch {
            return "{\"error\": \"\(error.localizedDescription)\"}"
        }
    }
    
    private func runAppleScript(_ script: String) async -> String {
        guard let appleScript = NSAppleScript(source: script) else {
            return "{\"error\": \"无法创建 AppleScript 实例\"}"
        }
        
        var errorInfo: NSDictionary?
        let result = appleScript.executeAndReturnError(&errorInfo)
        if let error = errorInfo {
            let errorMsg = error.description
            let response: [String: String] = ["error": errorMsg]
            if let jsonData = try? JSONSerialization.data(withJSONObject: response, options: []),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                return jsonStr
            }
            return "{\"error\": \"\(errorMsg)\"}"
        }
        let output = result.stringValue ?? ""
        let response: [String: String] = ["output": output]
        if let jsonData = try? JSONSerialization.data(withJSONObject: response, options: []),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
                return jsonStr
        }
        return output
    }
}
