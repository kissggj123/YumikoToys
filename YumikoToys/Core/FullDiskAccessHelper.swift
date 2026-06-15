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
import CryptoKit

// MARK: - String Hash Extension

extension String {
    func sha256Hash() -> String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

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
        // First: exact name match → update in place
        if let index = customSkills.firstIndex(where: { $0.name == skill.name }) {
            customSkills[index] = skill
            saveSkills()
            return
        }
        // Second: content hash match → deduplicate identical skills with different names
        if !skill.scriptContent.isEmpty {
            let newContentHash = skill.scriptContent.sha256Hash()
            if let index = customSkills.firstIndex(where: {
                !$0.scriptContent.isEmpty && $0.scriptContent.sha256Hash() == newContentHash
            }) {
                customSkills[index] = skill
                saveSkills()
                return
            }
        }
        customSkills.append(skill)
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
                scriptContent: """
                WIFI_INT=$(networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{getline; print $2}')
                if [ -z "$WIFI_INT" ]; then
                    WIFI_INT="en0"
                fi
                
                IPCONFIG_SSID=$(ipconfig getsummary "$WIFI_INT" 2>/dev/null | awk -F ': ' '/SSID/{print $2}' | xargs)
                if [ -n "$IPCONFIG_SSID" ] && [ "$IPCONFIG_SSID" != "<redacted>" ]; then
                    echo "Current Wi-Fi SSID: $IPCONFIG_SSID"
                    exit 0
                fi
                
                PROFILER_SSID=$(system_profiler SPAirPortDataType 2>/dev/null | awk '/Current Network Information:/{getline; print $0}' | sed 's/^[ \t]*//;s/:[ \t]*$//' | xargs)
                if [ -n "$PROFILER_SSID" ]; then
                    echo "Current Wi-Fi SSID: $PROFILER_SSID"
                    exit 0
                fi
                
                NS_OUT=$(networksetup -getairportnetwork "$WIFI_INT" 2>/dev/null)
                if echo "$NS_OUT" | grep -q "Current Wi-Fi Network"; then
                    echo "$NS_OUT"
                else
                    echo "Wi-Fi is enabled but not associated with a network, or permission is restricted. (Interface: $WIFI_INT)"
                fi
                """
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
            ),
            
            // MARK: - 专业心理学 Skills (v4.4.0)
            
            LLMSkill(
                name: "cbt_cognitive_restructuring",
                description: "CBT 认知重构工具：引导用户识别触发事件、自动化思维、认知扭曲类型，并构建更平衡的替代思维，生成结构化的认知重构报告。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "triggering_event": {"type": "string", "description": "触发负面情绪的具体事件或情境描述"},
                        "automatic_thought": {"type": "string", "description": "事件发生时的第一反应想法（自动化思维）"},
                        "emotion": {"type": "string", "description": "当时的情绪类型，如：焦虑、悲伤、愤怒、恐惧"},
                        "emotion_intensity": {"type": "number", "description": "情绪强度评分 0-10，10 为最强烈"},
                        "distortion_type": {"type": "string", "description": "认知扭曲类型，如：灾难化、过度泛化、非黑即白、读心术、情绪推理等（可选）"}
                    },
                    "required": ["triggering_event", "automatic_thought", "emotion", "emotion_intensity"]
                }
                """,
                scriptType: "openclaw",
                scriptContent: """
                ## CBT 认知重构分析报告
                
                **触发事件**：{{triggering_event}}
                **自动化思维**：{{automatic_thought}}
                **情绪**：{{emotion}}（强度：{{emotion_intensity}}/10）
                
                ### 苏格拉底式质询
                1. 支持这个想法的证据是什么？
                2. 反对这个想法的证据是什么？
                3. 最坏/最好/最可能的结果分别是什么？
                4. 如果是你的好友有这个想法，你会怎么告诉他？
                5. 这个想法是否存在{{distortion_type}}的认知扭曲？
                
                请基于以上框架进行认知重构，生成平衡的替代思维，并设计一个本周可执行的行为实验。
                """
            ),
            LLMSkill(
                name: "dbt_emotion_tracking",
                description: "DBT 情绪强度追踪：采用 DBT 情感温度计方法，帮助用户识别、命名并追踪情绪强度变化，并提供适合当前情绪强度的调节策略。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "emotion_name": {"type": "string", "description": "当前的主要情绪名称，如：愤怒、悲伤、焦虑、空虚、羞耻"},
                        "intensity": {"type": "number", "description": "情绪强度 0-100 的情感温度计评分"},
                        "body_sensation": {"type": "string", "description": "身体上感受到的位置和感觉，如：胸口紧绷、喉咙哽咽（可选）"},
                        "trigger": {"type": "string", "description": "触发因素（可选）"},
                        "urge": {"type": "string", "description": "当前的行动冲动，如：想发火、想逃离（可选）"}
                    },
                    "required": ["emotion_name", "intensity"]
                }
                """,
                scriptType: "openclaw",
                scriptContent: """
                ## DBT 情绪追踪记录
                
                情绪：{{emotion_name}} | 强度：{{intensity}}/100
                身体感受：{{body_sensation}}
                触发因素：{{trigger}}
                行动冲动：{{urge}}
                
                ### 基于强度的干预策略选择
                - **0-30（低强度）**：正念觉察、情绪命名练习
                - **31-60（中强度）**：TIPP 技能（温度、剧烈运动、调整呼吸、放松）
                - **61-80（高强度）**：痛苦耐受技能 ACCEPTS、IMPROVE
                - **81-100（危机强度）**：安全计划激活，寻求即时支持
                
                请根据当前情绪强度 {{intensity}} 提供最适合的 DBT 调节策略，并引导用户完成一个情绪调节练习步骤。
                """
            ),
            LLMSkill(
                name: "act_values_clarification",
                description: "ACT 价值澄清练习：引导用户探索并澄清不同生命领域的核心价值观，并帮助识别当前行为与价值观的一致程度，制定价值驱动的行动计划。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "life_domain": {"type": "string", "description": "要探索的生命领域，如：亲密关系、职业、家庭、健康、个人成长、社区贡献、灵性"},
                        "current_struggle": {"type": "string", "description": "在该领域当前面临的挣扎或困境"},
                        "ideal_self_description": {"type": "string", "description": "在该领域中，理想中的自己是什么样子的（可选）"}
                    },
                    "required": ["life_domain", "current_struggle"]
                }
                """,
                scriptType: "openclaw",
                scriptContent: """
                ## ACT 价值澄清工作表
                
                **生命领域**：{{life_domain}}
                **当前挣扎**：{{current_struggle}}
                **理想自我**：{{ideal_self_description}}
                
                ### 价值探索问题
                1. 在{{life_domain}}这个领域，对你来说什么是真正重要的？
                2. 如果你在这个领域完全按照内心所想生活，你会做什么不同的事？
                3. 是什么阻碍了你向着重要的方向前进？（想法？规则？回避？）
                4. 愿意带着这种不舒适继续前行吗？
                
                请引导用户澄清该领域的核心价值，并制定一个「价值驱动的微小承诺行动」（小到明天就能做到的一步）。
                """
            ),
            LLMSkill(
                name: "mindfulness_body_scan",
                description: "MBSR 正念身体扫描引导：提供结构化的身体扫描冥想脚本，引导用户以非评判的觉察力逐步关注全身各部位的感觉，促进身心放松与当下连接。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "duration_minutes": {"type": "number", "description": "引导时长（分钟），建议 5-45 分钟，默认 15 分钟"},
                        "focus_area": {"type": "string", "description": "特别关注的身体区域，如：头颈部、腰背部、全身（默认全身）"},
                        "intention": {"type": "string", "description": "本次练习的意图，如：放松入睡、减压、减轻疼痛（可选）"}
                    },
                    "required": ["duration_minutes"]
                }
                """,
                scriptType: "openclaw",
                scriptContent: """
                ## 正念身体扫描引导（{{duration_minutes}} 分钟版本）
                
                意图：{{intention}} | 关注区域：{{focus_area}}
                
                请生成一段完整的、温和的正念身体扫描引导词，时长约 {{duration_minutes}} 分钟，遵循 MBSR 标准协议：
                1. 开场安顿与意图设置（1-2分钟）
                2. 呼吸锚定（1分钟）
                3. 从脚趾开始逐步向上扫描（主体部分），重点关注 {{focus_area}}
                4. 当注意力游荡时温和引导回来的指导语
                5. 结束时的整体感受觉察与慢慢回到当下
                
                语言风格：温和、缓慢、非评判，使用第二人称「你」，句子短而有停顿感。
                """
            ),
            LLMSkill(
                name: "ifs_parts_dialogue",
                description: "IFS 内在家庭系统部分对话：引导用户识别并与内在的保护性部分（管理者/消防员）或被流放部分进行对话，促进内在系统理解与整合。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "presenting_part": {"type": "string", "description": "当前浮现的内在部分描述，如：一个不断自我批评的声音、一个想放弃一切的部分"},
                        "part_type": {"type": "string", "description": "部分类型：manager（管理者）/ firefighter（消防员）/ exile（流放者），若不确定可填 unknown"},
                        "what_part_does": {"type": "string", "description": "这个部分通常做什么？它的行为模式是什么？"},
                        "what_part_fears": {"type": "string", "description": "你猜测这个部分最害怕什么会发生？（可选）"}
                    },
                    "required": ["presenting_part", "part_type", "what_part_does"]
                }
                """,
                scriptType: "openclaw",
                scriptContent: """
                ## IFS 内在部分对话框架
                
                **浮现部分**：{{presenting_part}}
                **部分类型**：{{part_type}}
                **行为模式**：{{what_part_does}}
                **核心恐惧**：{{what_part_fears}}
                
                ### 与部分建立关系的引导步骤
                1. 首先检查「自性」(Self) 的在场程度——当前有几分平静、好奇与慈悲？
                2. 带着好奇而非评判，向这个部分问候：「你好，我注意到你了。」
                3. 询问这个部分：「你在试图保护我什么？」
                4. 倾听并感谢它的保护意图，不论策略是否有效
                5. 询问：「如果你不再需要做这些，你希望做什么？」
                
                请以 IFS 治疗师的身份，引导用户与这个{{part_type}}类型的部分展开对话，帮助理解其保护角色并建立慈悲连接。
                """
            ),
            LLMSkill(
                name: "narrative_externalization",
                description: "叙事疗法外化技术：帮助用户将问题从自身「我是问题」中分离，通过命名和外化问题，找回自主性和例外经验，重写生命叙事。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "problem_description": {"type": "string", "description": "用户描述的主要困扰或问题"},
                        "problem_name": {"type": "string", "description": "给问题起一个名字（如「那个批评者」「焦虑怪兽」），用于外化处理（可选）"},
                        "exception_moments": {"type": "string", "description": "问题没有那么强烈或完全不存在的时刻，具体描述（可选）"}
                    },
                    "required": ["problem_description"]
                }
                """,
                scriptType: "openclaw",
                scriptContent: """
                ## 叙事疗法外化对话框架
                
                **主要困扰**：{{problem_description}}
                **问题外化名称**：{{problem_name}}
                **例外时刻**：{{exception_moments}}
                
                ### 叙事外化引导步骤
                1. **命名与外化**：引导用户为问题命名，将「我很焦虑」转化为「焦虑在影响我」
                2. **绘制影响地图**：「{{problem_name}}在你生活的哪些领域产生了影响？」
                3. **评估与立场**：「你对这些影响有什么感受？这符合你想要的生活吗？」
                4. **挖掘例外经验**：探索{{exception_moments}}，寻找用户对问题的抵抗资源
                5. **重写叙事**：「这些例外说明了你具备哪些被忽视的能力和价值？」
                
                请以叙事治疗师身份，运用外化语言和苏格拉底式提问，帮助用户将问题从自我认同中分离，并发现厚实的替代叙事。
                """
            ),
            LLMSkill(
                name: "attachment_assessment",
                description: "依恋风格评估：通过探索性问题评估用户的成人依恋风格（安全型/焦虑型/回避型/混乱型），并提供依恋模式与关系行为的深度解析。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "relationship_concern": {"type": "string", "description": "用户在亲密关系中的主要困扰或问题"},
                        "early_attachment": {"type": "string", "description": "早年与主要照料者（父母）的关系特点描述（可选）"},
                        "current_pattern": {"type": "string", "description": "在当前亲密关系中的行为模式（可选，如：容易嫉妒、害怕亲密、总是距离感等）"}
                    },
                    "required": ["relationship_concern"]
                }
                """,
                scriptType: "openclaw",
                scriptContent: """
                ## 依恋风格评估与分析
                
                **关系困扰**：{{relationship_concern}}
                **早期依恋经历**：{{early_attachment}}
                **当前行为模式**：{{current_pattern}}
                
                ### 依恋评估维度
                基于以上信息，请从以下维度进行评估：
                
                **1. 依恋焦虑维度**（对被遗弃/拒绝的担心程度）
                - 关注迹象：频繁寻求保证、嫉妒、分离焦虑、过度依赖
                
                **2. 依恋回避维度**（对亲密/依赖的不适程度）
                - 关注迹象：情感压抑、强调独立、回避承诺、情感距离感
                
                **3. 内在工作模型**
                - 对自我的信念：我是值得被爱的吗？
                - 对他人的信念：他人是可信赖和可依靠的吗？
                
                请提供初步的依恋倾向分析，解释这些模式可能的早年形成原因，以及在当前关系中的具体表现，并提供1-2个促进安全依恋的实践建议。
                """
            ),
            LLMSkill(
                name: "auto_clean_workspace",
                description: "对指定的文件夹工作区进行自动化整理：按文件类型分类归档（图片/文档/归档包），并删除临时缓存文件。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {
                        "workspacePath": {"type": "string", "description": "要整理的绝对文件夹路径，例如 /Users/username/Desktop"}
                    },
                    "required": ["workspacePath"]
                }
                """,
                scriptType: "shell",
                scriptContent: """
                cd "{{workspacePath}}" || exit 1
                echo "=== Sorting Workspace: {{workspacePath}} ==="
                mkdir -p "Images" "Documents" "Archives"
                
                # Move images
                find . -maxdepth 1 -type f \\( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.webp" \\) -exec mv {} "Images/" \\; 2>/dev/null || true
                
                # Move documents
                find . -maxdepth 1 -type f \\( -name "*.pdf" -o -name "*.docx" -o -name "*.xlsx" -o -name "*.pptx" -o -name "*.txt" -o -name "*.md" \\) -exec mv {} "Documents/" \\; 2>/dev/null || true
                
                # Move archives
                find . -maxdepth 1 -type f \\( -name "*.zip" -o -name "*.tar.gz" -o -name "*.rar" -o -name "*.dmg" \\) -exec mv {} "Archives/" \\; 2>/dev/null || true
                
                # Clean temp files
                find . -maxdepth 1 -type f \\( -name "*.tmp" -o -name "*.log" -o -name "*.temp" \\) -delete 2>/dev/null || true
                
                echo "Done sorting and cleaning up."
                """
            ),
            LLMSkill(
                name: "release_system_memory",
                description: "清理 macOS 系统的非活跃物理内存缓存以释放内存空间。",
                parametersJSON: """
                {
                    "type": "object",
                    "properties": {},
                    "required": []
                }
                """,
                scriptType: "shell",
                scriptContent: "purge || echo 'Purged user-level disk caches.'"
            )
        ]
    }
    
    public func getAllSkills() -> [LLMSkill] {
        return getBuiltInSkills() + customSkills
    }
    
    public func executeSkill(name: String, arguments: [String: Any]) async -> String {
        // 兼容已移除的内置 run_shell_command 技能，将其无缝重定向到底层 runShell 执行
        if name == "run_shell_command" {
            let command = arguments["command"] as? String ?? ""
            return await runShell(command)
        }
        
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
        } else if skill.scriptType == "openclaw" {
            return await runOpenClawSkill(script: script)
        }
        
        return "{\"error\": \"未知的技能类型: \(skill.scriptType)\"}"
    }
    
    private func runOpenClawSkill(script: String) async -> String {
        let settings = DependencyContainer.shared.apiSettingsService.getSettings()
        let activeProvider = settings.currentProvider
        let config = settings.providerConfigs[activeProvider] ?? settings.currentConfig
        
        let providerKey = config.apiKey
        let providerURL = config.apiURL
        let model = config.model
        
        guard !providerKey.isEmpty || activeProvider == .ollama else {
            return "{\"error\": \"未配置当前AI提供商的 API Key，请在设置中配置\"}"
        }
        
        let provider = UniversalLLMProvider(providerType: activeProvider)
        provider.updateAPIKey(providerKey)
        provider.updateBaseURL(providerURL)
        
        let systemPrompt = "你是一个专业的高级助理，请根据以下渲染好的技能模板和参数生成详细的专业报告或分析结果。请直接输出结果，并采用 Markdown 格式，不要包含任何多余的前言或结语。"
        
        let isReasoningModel = model.lowercased().contains("reasoner") || model.lowercased().contains("thinking") || model.lowercased().contains("think") || model.lowercased().contains("r1")
        
        var messages: [ChatMessage] = []
        if isReasoningModel {
            let merged = """
            [System Instructions]
            \(systemPrompt)
            
            [User Message]
            \(script)
            """
            messages.append(ChatMessage(role: "user", content: merged))
        } else {
            messages.append(ChatMessage(role: "user", content: script))
        }
        
        let finalSysPrompt = isReasoningModel ? nil : systemPrompt
        
        do {
            let stream = provider.streamChatWithEvents(
                messages: messages,
                systemPrompt: finalSysPrompt,
                model: model,
                enableThinking: false
            )
            
            var generatedText = ""
            for try await event in stream {
                if case .textContent(let text) = event {
                    generatedText += text
                }
            }
            
            if generatedText.isEmpty {
                return "{\"error\": \"模型生成了空回复\"}"
            }
            return generatedText
        } catch {
            LoggerService.shared.error("Failed to run openclaw skill: \(error)")
            return "{\"error\": \"技能运行出错: \(error.localizedDescription)\"}"
        }
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
    
    public func runShell(_ script: String) async -> String {
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
    
    public func runAppleScript(_ script: String) async -> String {
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
