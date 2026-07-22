//
//  AgentSystemTools.swift
//  YumikoToys
//
//  内置系统工具集 - 剪贴板、App 启动器、系统信息、音量/亮度控制
//

import Foundation
import AppKit

// MARK: - 剪贴板工具

/// 读取剪贴板内容
struct ClipboardReadTool: AgentTool {
    let name = "clipboard_read"
    let description = "读取系统剪贴板中的文本内容"
    let parameters: [AgentToolParameter] = []
    
    func execute(arguments: [String: Any]) async -> AgentToolResult {
        guard let pasteboard = NSPasteboard.general.string(forType: .string) else {
            return .failure("剪贴板为空或不包含文本")
        }
        let truncated = String(pasteboard.prefix(5000))
        let wasTruncated = pasteboard.count > 5000
        return .success(truncated, metadata: wasTruncated ? ["truncated": "true"] : nil)
    }
}

/// 写入剪贴板内容
struct ClipboardWriteTool: AgentTool {
    let name = "clipboard_write"
    let description = "将指定文本写入系统剪贴板"
    let parameters: [AgentToolParameter] = [
        AgentToolParameter(name: "text", type: .string, description: "要复制到剪贴板的文本", required: true, defaultValue: nil)
    ]
    let requiresConfirmation = true
    
    func execute(arguments: [String: Any]) async -> AgentToolResult {
        guard let text = arguments["text"] as? String else {
            return .failure("缺少 text 参数")
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        return .success("已复制到剪贴板（\(text.count) 字符）")
    }
}

// MARK: - App 启动器

struct AppLauncherTool: AgentTool {
    let name = "launch_app"
    let description = "启动指定的 macOS 应用程序。支持常见应用名称如 Safari, Chrome, Terminal, Notes, Calendar, Mail, Finder, System Preferences 等"
    let parameters: [AgentToolParameter] = [
        AgentToolParameter(name: "app_name", type: .string, description: "应用名称（如 Safari, Chrome, Terminal）", required: true, defaultValue: nil)
    ]
    
    func execute(arguments: [String: Any]) async -> AgentToolResult {
        guard let appName = arguments["app_name"] as? String else {
            return .failure("缺少 app_name 参数")
        }
        
        let workspace = NSWorkspace.shared
        
        // 尝试直接通过名称启动
        if let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.\(appName.lowercased())") {
            workspace.open(url)
            return .success("已启动 \(appName)")
        }
        
        // 尝试通过 open 命令
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appName]
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return .success("已启动 \(appName)")
            } else {
                return .failure("无法启动 \(appName)，请确认应用名称是否正确")
            }
        } catch {
            return .failure("启动失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - 系统信息

struct SystemInfoTool: AgentTool {
    let name = "get_system_info"
    let description = "获取当前 Mac 的系统信息，包括 macOS 版本、CPU、内存、磁盘空间、电池状态等"
    let parameters: [AgentToolParameter] = []
    
    func execute(arguments: [String: Any]) async -> AgentToolResult {
        var info: [String] = []
        
        // macOS 版本
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        info.append("macOS: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
        
        // CPU
        info.append("CPU: \(ProcessInfo.processInfo.processorCount) 核心")
        
        // 内存
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(totalMemory) / 1_073_741_824
        info.append("内存: \(String(format: "%.1f", memoryGB)) GB")
        
        // 运行时间
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        info.append("运行时间: \(hours)小时\(minutes)分钟")
        
        // 磁盘空间
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let freeSpace = attrs[.systemFreeSize] as? NSNumber,
           let totalSpace = attrs[.systemSize] as? NSNumber {
            let freeGB = freeSpace.doubleValue / 1_073_741_824
            let totalGB = totalSpace.doubleValue / 1_073_741_824
            info.append("磁盘: \(String(format: "%.1f", freeGB)) GB 可用 / \(String(format: "%.1f", totalGB)) GB 总计")
        }
        
        // 主机名
        info.append("主机名: \(Host.current().localizedName ?? "Unknown")")
        
        return .success(info.joined(separator: "\n"))
    }
}

// MARK: - 系统控制 (AppleScript 桥接)

struct SystemControlTool: AgentTool {
    let name = "system_control"
    let description = "控制系统设置：调整音量(volume_up/volume_down/mute)、亮度(brightness_up/brightness_down)、WiFi(wifi_on/wifi_off/status)、勿扰模式(dnd_on/dnd_off)"
    let parameters: [AgentToolParameter] = [
        AgentToolParameter(name: "action", type: .string, description: "控制动作：volume_up, volume_down, mute, unmute, brightness_up, brightness_down, wifi_on, wifi_off, wifi_status, dnd_on, dnd_off", required: true, defaultValue: nil)
    ]
    let requiresConfirmation = true
    
    func execute(arguments: [String: Any]) async -> AgentToolResult {
        guard let action = arguments["action"] as? String else {
            return .failure("缺少 action 参数")
        }
        
        let script: String
        let description: String
        
        switch action {
        case "volume_up":
            script = "set volume output volume (output volume of (get volume settings) + 10)"
            description = "音量已调高"
        case "volume_down":
            script = "set volume output volume (output volume of (get volume settings) - 10)"
            description = "音量已调低"
        case "mute":
            script = "set volume with output muted"
            description = "已静音"
        case "unmute":
            script = "set volume without output muted"
            description = "已取消静音"
        case "brightness_up":
            script = """
            tell application "System Events"
                key code 144 -- F2 (brightness up)
            end tell
            """
            description = "亮度已调高"
        case "brightness_down":
            script = """
            tell application "System Events"
                key code 145 -- F1 (brightness down)
            end tell
            """
            description = "亮度已调低"
        case "wifi_status":
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            task.arguments = ["-getairportpower", "en0"]
            let pipe = Pipe()
            task.standardOutput = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
                return .success("WiFi 状态: \(output)")
            } catch {
                return .failure("无法获取 WiFi 状态: \(error.localizedDescription)")
            }
        case "wifi_on":
            script = "do shell script \"networksetup -setairportpower en0 on\" with administrator privileges"
            description = "WiFi 已开启"
        case "wifi_off":
            script = "do shell script \"networksetup -setairportpower en0 off\" with administrator privileges"
            description = "WiFi 已关闭"
        default:
            return .failure("不支持的动作: \(action)。支持: volume_up, volume_down, mute, unmute, brightness_up, brightness_down, wifi_on, wifi_off, wifi_status")
        }
        
        return await runAppleScript(script, successMessage: description)
    }
    
    private func runAppleScript(_ script: String, successMessage: String) async -> AgentToolResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appleScript = NSAppleScript(source: script)
                var error: NSDictionary?
                appleScript?.executeAndReturnError(&error)
                
                DispatchQueue.main.async {
                    if let error = error {
                        continuation.resume(returning: .failure("AppleScript 执行失败: \(error)"))
                    } else {
                        continuation.resume(returning: .success(successMessage))
                    }
                }
            }
        }
    }
}

// MARK: - 工具注册中心

/// Agent 工具注册中心 - 管理所有可用的 Agent 工具
@MainActor
final class AgentToolRegistry: ObservableObject {
    static let shared = AgentToolRegistry()
    
    @Published private(set) var tools: [String: AgentTool] = [:]
    
    private init() {
        registerBuiltinTools()
    }
    
    private func registerBuiltinTools() {
        register(ClipboardReadTool())
        register(ClipboardWriteTool())
        register(AppLauncherTool())
        register(SystemInfoTool())
        register(SystemControlTool())
    }
    
    func register(_ tool: AgentTool) {
        tools[tool.name] = tool
    }
    
    func unregister(_ name: String) {
        tools.removeValue(forKey: name)
    }
    
    /// 生成所有已注册工具的 function calling schema
    func generateSchemas() -> [[String: Any]] {
        tools.values.map { $0.toFunctionSchema() }
    }
    
    /// 执行指定工具
    func execute(name: String, arguments: [String: Any]) async -> AgentToolResult {
        guard let tool = tools[name] else {
            return .failure("未找到工具: \(name)")
        }
        return await tool.execute(arguments: arguments)
    }
}
