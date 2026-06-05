//
//  FullDiskAccessHelper.swift
//  YumikoToys
//
//  完全磁盘访问权限检测与引导助手
//

import Foundation
import AppKit
import SwiftUI
import UserNotifications

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
        
        // 0. 模拟写入空临时文件进行写测试（针对自签名应用优化，增加备选目录，不依赖 NSTemporaryDirectory()）
        for home in homeDirs {
            let writePaths = [
                home + "/Library/Application Support/com.apple.TCC/YumikoToys_test_fda.txt",
                home + "/Library/Safari/YumikoToys_test_fda.txt",
                home + "/Library/Calendars/YumikoToys_test_fda.txt",
                home + "/Library/Reminders/YumikoToys_test_fda.txt",
                home + "/Library/Preferences/com.apple.TCC_test_fda.txt",
                "/Library/Preferences/com.apple.TCC_test_fda.txt"
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
            testPaths.append(home + "/Library/Calendars/Calendar Cache")
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
            testDirs.append(home + "/Library/Calendars")
            testDirs.append(home + "/Library/Reminders")
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
        
        // 3. 对 TCC 签名身份变化后的额外容错兜底探针（非 NSTemporaryDirectory()，比如尝试读取用户的某些偏好设置文件）
        // 探测是否可以读取某些通常无法在严格沙盒或被限制环境下读取的系统配置文件
        let fallbackFiles = [
            "/private/var/db/SystemPolicy-control/default.plist",
            "/Library/Security/Trust Settings/Admin.plist"
        ]
        for path in fallbackFiles {
            if FileManager.default.isReadableFile(atPath: path) {
                return true
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
            ),
            LLMSkill(
                name: "read_file_content",
                description: "读取指定路径下文件内容并返回文本。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "path": {"type": "string", "description": "要读取文件的绝对路径，例如 /Users/username/document.txt"}
                    },
                    "required": ["path"]
                }
                """,
                scriptType: "shell",
                scriptContent: "cat \"{{path}}\""
            ),
            LLMSkill(
                name: "write_file_content",
                description: "向指定路径写入文件内容。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "path": {"type": "string", "description": "要写入的绝对文件路径"},
                        "content": {"type": "string", "description": "要写入的具体文本内容"}
                    },
                    "required": ["path", "content"]
                }
                """,
                scriptType: "shell",
                scriptContent: "echo \"{{content}}\" > \"{{path}}\""
            ),
            LLMSkill(
                name: "get_clipboard",
                description: "获取当前系统剪贴板中的文本内容。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {},
                    "required": []
                }
                """,
                scriptType: "shell",
                scriptContent: "pbpaste"
            ),
            LLMSkill(
                name: "set_clipboard",
                description: "设置系统剪贴板文本。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "text": {"type": "string", "description": "要复制到剪切板的文本内容"}
                    },
                    "required": ["text"]
                }
                """,
                scriptType: "shell",
                scriptContent: "echo -n \"{{text}}\" | pbcopy"
            ),
            LLMSkill(
                name: "search_files",
                description: "通过 Spotlight 引擎搜索符合条件的文件列表。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "query": {"type": "string", "description": "Spotlight 搜索查询关键词"},
                        "path": {"type": "string", "description": "可选：指定搜索的文件夹绝对路径范围"}
                    },
                    "required": ["query"]
                }
                """,
                scriptType: "shell",
                scriptContent: "if [ -n \"{{path}}\" ]; then mdfind -onlyin \"{{path}}\" \"{{query}}\"; else mdfind \"{{query}}\"; fi"
            ),
            LLMSkill(
                name: "send_notification",
                description: "触发 macOS 系统横幅通知推送。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "title": {"type": "string", "description": "通知标题"},
                        "message": {"type": "string", "description": "通知的具体消息正文内容"}
                    },
                    "required": ["title", "message"]
                }
                """,
                scriptType: "notification",
                scriptContent: ""
            ),
            LLMSkill(
                name: "take_screenshot",
                description: "对屏幕进行截图并保存到指定路径（留空则自动保存到桌面）。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "path": {"type": "string", "description": "截图保存的绝对目标路径，例如 ~/Desktop/screen.png，留空则自动保存到桌面"}
                    },
                    "required": []
                }
                """,
                scriptType: "shell",
                scriptContent: "SAVE_PATH=\"${1:-$HOME/Desktop/screenshot_$(date +%Y%m%d_%H%M%S).png}\"; screencapture -x \"$SAVE_PATH\" 2>&1 && echo \"截图已保存到: $SAVE_PATH\""
            ),
            LLMSkill(
                name: "control_volume",
                description: "控制系统输出音量大小百分比。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "level": {"type": "number", "description": "音量大小，0至100之间的整数"}
                    },
                    "required": ["level"]
                }
                """,
                scriptType: "applescript",
                scriptContent: "set volume output volume {{level}}"
            ),
            LLMSkill(
                name: "get_battery_status",
                description: "查询当前电池充电状态与电量百分比。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {},
                    "required": []
                }
                """,
                scriptType: "shell",
                scriptContent: "pmset -g batt"
            ),
            LLMSkill(
                name: "get_wifi_status",
                description: "查询当前 Wi-Fi 网络连接的 SSID 和状态。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {},
                    "required": []
                }
                """,
                scriptType: "shell",
                scriptContent: "networksetup -getairportnetwork en0"
            ),
            LLMSkill(
                name: "change_wallpaper",
                description: "使用 AppleScript 更改桌面壁纸图片。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "path": {"type": "string", "description": "壁纸图片的绝对文件路径"}
                    },
                    "required": ["path"]
                }
                """,
                scriptType: "applescript",
                scriptContent: "tell application \"Finder\" to set desktop picture to POSIX file \"{{path}}\""
            ),
            LLMSkill(
                name: "query_calendar",
                description: "使用 AppleScript 查询未来几天内的系统日历日程事件。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "days": {"type": "number", "description": "查询未来几天内的日历日程事件数，如 7"}
                    },
                    "required": ["days"]
                }
                """,
                scriptType: "applescript",
                scriptContent: """
                tell application "Calendar"
                    set targetDate to (current date) + ({{days}} * days)
                    set output to ""
                    repeat with aCalendar in calendars
                        repeat with aEvent in (events of aCalendar whose start date is greater than or equal to (current date) and start date is less than or equal to targetDate)
                            set output to output & (summary of aEvent) & " | " & (start date of aEvent as string) & "\\n"
                        end repeat
                    end repeat
                    return output
                end tell
                """
            ),
            LLMSkill(
                name: "get_running_processes",
                description: "查询活跃的系统进程列表，按 CPU 使用率排序。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {},
                    "required": []
                }
                """,
                scriptType: "shell",
                scriptContent: "ps -Ao pid,pcpu,pmem,comm -r | head -n 11"
            ),
            LLMSkill(
                name: "system_garbage_cleanup",
                description: "清理系统废纸篓、Xcode DerivedData 衍生缓存等垃圾，释放磁盘空间。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "deepClean": {"type": "boolean", "description": "是否开启深度清理（包括 Xcode 衍生数据）"}
                    },
                    "required": ["deepClean"]
                }
                """,
                scriptType: "shell",
                scriptContent: """
                echo "=== 开始系统清理 ==="
                echo "正在清理废纸篓..."
                rm -rf ~/.Trash/* 2>/dev/null || true
                if [ "{{deepClean}}" = "true" ]; then
                    echo "执行深度清理..."
                    echo "正在清理 Xcode 缓存..."
                    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
                    echo "正在清理系统用户 Caches..."
                    rm -rf ~/Library/Caches/* 2>/dev/null || true
                fi
                echo "=== 清理完成 ==="
                """
            ),
            LLMSkill(
                name: "reminders_manager",
                description: "管理 macOS 系统待办事项（Reminders）。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "action": {"type": "string", "description": "操作：list (列出未完成), add (添加)"},
                        "title": {"type": "string", "description": "待办名称（仅add操作需要）"},
                        "daysOffset": {"type": "number", "description": "截止天数偏移（仅add操作可选）"}
                    },
                    "required": ["action"]
                }
                """,
                scriptType: "applescript",
                scriptContent: """
                tell application "Reminders"
                    if "{{action}}" is "list" then
                        set output to ""
                        set todoList to reminders of default list
                        repeat with todo in todoList
                            if not completed of todo then
                                set output to output & (name of todo) & " | " & (due date of todo as string) & "\\n"
                            end if
                        end repeat
                        return output
                    else if "{{action}}" is "add" then
                        set newTodo to make new reminder with properties {name:"{{title}}"}
                        if "{{daysOffset}}" is not "" then
                            set due date of newTodo to (current date) + ({{daysOffset}} * days)
                        end if
                        return "成功添加待办事项: {{title}}"
                    end if
                end tell
                """
            ),
            LLMSkill(
                name: "search_web",
                description: "通过公开搜索引擎快速查询网页链接和摘要信息。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "query": {"type": "string", "description": "要查询的关键字"}
                    },
                    "required": ["query"]
                }
                """,
                scriptType: "shell",
                scriptContent: "Q=\"{{query}}\"; ENCODED=$(python3 -c \"import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))\" \"$Q\" 2>/dev/null || echo \"$Q\"); curl -s -L -m 15 --user-agent \"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)\" \"https://html.duckduckgo.com/html/?q=$ENCODED\" | grep -oE 'class=\"result__url[^>]+>[^<]+' | head -n 5 | sed 's/.*>//g;s/[ \t]*$//g'"
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
        
        // MARK: theme skill
        if skill.scriptType == "theme" || name == "set_god_mode_style" {
            return await executeGodModeSkill(arguments: arguments)
        }
        
        // MARK: notification skill — use native UNUserNotificationCenter to avoid osascript TCC issues
        if skill.scriptType == "notification" || name == "send_notification" {
            return await executeNotificationSkill(arguments: arguments)
        }
        
        // Process arguments substitution
        var script = skill.scriptContent
        for (key, value) in arguments {
            let strVal = "\(value)"
            script = script.replacingOccurrences(of: "{{\(key)}}", with: strVal)
        }
        // 清理所有未传入的可选参数模板，防止脚本报错
        if let regex = try? NSRegularExpression(pattern: "\\{\\{.*?\\}\\}", options: []) {
            let range = NSRange(script.startIndex..., in: script)
            script = regex.stringByReplacingMatches(in: script, options: [], range: range, withTemplate: "")
        }
        
        if skill.scriptType == "shell" {
            return await runShell(script)
        } else if skill.scriptType == "applescript" {
            return await runAppleScript(script)
        }
        
        return "{\"error\": \"未知的技能类型: \(skill.scriptType)\"}"
    }
    
    private func executeNotificationSkill(arguments: [String: Any]) async -> String {
        let title = arguments["title"] as? String ?? "通知"
        let message = arguments["message"] as? String ?? ""
        
        return await withCheckedContinuation { continuation in
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else {
                    continuation.resume(returning: "{\"error\": \"通知权限未授权，请在系统设置中开启通知权限\"}")
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "com.yumikotoys.skill.\(UUID().uuidString)",
                    content: content,
                    trigger: nil
                )
                center.add(request) { error in
                    if let e = error {
                        continuation.resume(returning: "{\"error\": \"\(e.localizedDescription)\"}")
                    } else {
                        continuation.resume(returning: "{\"success\": true, \"message\": \"通知已发送: \(title)\"}")
                    }
                }
            }
        }
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
            // Extract a clean error message from the error dict
            let errorMsg: String
            if let msg = (error[NSAppleScript.errorMessage] as? String) ??
                         (error[NSAppleScript.errorBriefMessage] as? String) {
                errorMsg = msg
            } else {
                errorMsg = error.description
            }
            if let data = try? JSONSerialization.data(withJSONObject: ["error": errorMsg], options: []),
               let str = String(data: data, encoding: .utf8) {
                return str
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

// MARK: - CLI Installer

public struct CLIInstaller {
    public static func install() async throws {
        let scriptContent = """
        #!/bin/bash
        
        ACTION=$1
        CONTAINER_TMP="$HOME/Library/Containers/com.Lite.YumikoToys/Data/tmp"
        
        if [ "$ACTION" = "install" ]; then
            echo "Installing ytskill to /usr/local/bin/ytskill..."
            if [ "$(id -u)" -ne 0 ]; then
                sudo cp "$0" /usr/local/bin/ytskill
                sudo chmod +x /usr/local/bin/ytskill
            else
                cp "$0" /usr/local/bin/ytskill
                chmod +x /usr/local/bin/ytskill
            fi
            echo "ytskill installed successfully at /usr/local/bin/ytskill"
            exit 0
        fi
        
        if [ "$ACTION" = "list" ]; then
            mkdir -p "$CONTAINER_TMP"
            TEMP_FILE=$(mktemp "$CONTAINER_TMP/ytskill_list.XXXXXX")
            open "yumikotoys://skill?action=list&output=$TEMP_FILE"
            
            COUNTER=0
            while [ ! -s "$TEMP_FILE" ] && [ $COUNTER -lt 50 ]; do
                sleep 0.1
                COUNTER=$((COUNTER+1))
            done
            
            if [ -s "$TEMP_FILE" ]; then
                cat "$TEMP_FILE"
            else
                echo "Error: Timeout waiting for response from YumikoToys"
                rm -f "$TEMP_FILE"
                exit 1
            fi
            rm -f "$TEMP_FILE"
            exit 0
        fi
        
        if [ "$ACTION" = "run" ]; then
            NAME=$2
            if [ -z "$NAME" ]; then
                echo "Usage: ytskill run <name> [--args '{\\"key\\":\\"value\\"}']"
                exit 1
            fi
            
            ARGS=""
            if [ "$3" = "--args" ] && [ -n "$4" ]; then
                ARGS="$4"
            fi
            
            mkdir -p "$CONTAINER_TMP"
            TEMP_FILE=$(mktemp "$CONTAINER_TMP/ytskill_run.XXXXXX")
            
            if command -v python3 >/dev/null 2>&1; then
                ENCODED_ARGS=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$ARGS'''))")
            elif command -v python >/dev/null 2>&1; then
                ENCODED_ARGS=$(python -c "import urllib.parse; print(urllib.parse.quote('''$ARGS'''))")
            else
                ENCODED_ARGS=$(echo -n "$ARGS" | curl -s -o /dev/null -w "%{url_effective}" --data-urlencode @- "" | cut -c 3-)
            fi
        
            open "yumikotoys://skill?action=run&name=$NAME&args=$ENCODED_ARGS&output=$TEMP_FILE"
            
            COUNTER=0
            while [ ! -s "$TEMP_FILE" ] && [ $COUNTER -lt 100 ]; do
                sleep 0.1
                COUNTER=$((COUNTER+1))
            done
            
            if [ -s "$TEMP_FILE" ]; then
                cat "$TEMP_FILE"
            else
                echo "Error: Timeout or execution failure from YumikoToys"
                rm -f "$TEMP_FILE"
                exit 1
            fi
            rm -f "$TEMP_FILE"
            exit 0
        fi
        
        echo "YumikoToys Skill CLI Tool"
        echo "Usage:"
        echo "  ytskill list                          # 列出所有技能"
        echo "  ytskill run <name> [--args '{\\"k\\":\\"v\\"}']  # 执行技能"
        echo "  ytskill install                        # 安装/更新 CLI"
        exit 1
        """
        
        let tempDir = NSTemporaryDirectory()
        let tempFilePath = (tempDir as NSString).appendingPathComponent("ytskill")
        
        try scriptContent.write(toFile: tempFilePath, atomically: true, encoding: .utf8)
        
        let appleScriptSource = """
        do shell script "mkdir -p /usr/local/bin && cp '\(tempFilePath)' /usr/local/bin/ytskill && chmod +x /usr/local/bin/ytskill" with administrator privileges
        """
        
        guard let appleScript = NSAppleScript(source: appleScriptSource) else {
            throw NSError(domain: "CLIInstaller", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建 AppleScript 实例"])
        }
        
        var errorInfo: NSDictionary?
        _ = appleScript.executeAndReturnError(&errorInfo)
        
        // Clean up temp file
        try? FileManager.default.removeItem(atPath: tempFilePath)
        
        if let error = errorInfo {
            let errorMsg = error.description
            throw NSError(domain: "CLIInstaller", code: -2, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }
}
