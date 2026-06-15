//
//  ProactiveAgentService.swift
//  YumikoToys
//
//  主动智能助理心跳引擎服务 (Proactive Heartbeat Assistant Engine)
//  借鉴 openclaw 的智能决策设计，周期性分析系统负载、用户情绪、作息及工作区状态，进行主动交互或自动化清理
//

import Foundation
import AppKit
import Combine
import WidgetKit
import UserNotifications

@MainActor
final class ProactiveAgentService: ObservableObject {
    
    // MARK: - Properties
    
    private let settingsService: SettingsServiceProtocol
    private let apiSettingsService: APISettingsServiceProtocol
    private let backgroundLearningService: BackgroundLearningService
    
    @Published private(set) var activityLogs: [String] = []
    
    private var heartbeatTimer: Timer?
    private var isRunning = false
    
    // MARK: - Initializer
    
    init(
        settingsService: SettingsServiceProtocol,
        apiSettingsService: APISettingsServiceProtocol,
        backgroundLearningService: BackgroundLearningService
    ) {
        self.settingsService = settingsService
        self.apiSettingsService = apiSettingsService
        self.backgroundLearningService = backgroundLearningService
    }
    
    // MARK: - Service Lifecycle
    
    func initialize() async {
        LoggerService.shared.info("ProactiveAgentService: Starting initialization")
        loadLogs()
        
        // 自动根据设置启动服务
        if settingsService.settings.enableProactiveAssistant {
            startService()
        }
    }
    
    func startService() {
        guard !isRunning else { return }
        isRunning = true
        restartTimer()
        log("智能助理后台监测服务已开启")
        
        // 首次开启时后台触发一次 tick
        Task {
            await tick()
        }
    }
    
    func stopService() {
        guard isRunning else { return }
        isRunning = false
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        log("智能助理后台监测服务已暂停")
    }
    
    func restartTimer() {
        heartbeatTimer?.invalidate()
        guard isRunning else { return }
        
        let intervalMinutes = settingsService.settings.proactiveHeartbeatInterval
        // 转换为秒
        let seconds = max(10.0, intervalMinutes * 60.0) // 确保不低于 10 秒防死循环
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.tick()
            }
        }
        
        log("监测心跳周期已更新为 \(Int(intervalMinutes)) 分钟")
    }
    
    func clearLogs() {
        activityLogs.removeAll()
        saveLogs()
    }
    
    // MARK: - Core Heartbeat (Tick)
    
    private func tick() async {
        // 1. 如果屏幕已锁屏或睡眠，跳过决策以节省 Token 与系统开销
        guard !isScreenLocked() else {
            LoggerService.shared.debug("ProactiveAgentService: Screen is locked, skipping heartbeat.")
            return
        }
        
        LoggerService.shared.info("ProactiveAgentService: Heartbeat tick triggered")
        
        // 2. 收集系统 CPU 与内存负载
        let cpuMemoryStats = await SkillService.shared.runShell("top -l 1 | head -n 10")
        
        // 3. 统计桌面文件堆积数
        let desktopPath = (NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first ?? "~/Desktop")
        let fileManager = FileManager.default
        let desktopFiles = (try? fileManager.contentsOfDirectory(atPath: desktopPath)) ?? []
        let desktopFilesCount = desktopFiles.filter { !$0.hasPrefix(".") }.count
        
        // 4. 获取情绪画像数据
        var psychoContext = "暂无情感画像数据"
        if let profile = backgroundLearningService.getPsychologicalProfile() {
            psychoContext = "主导情绪: \(profile.dominantEmotion), 压力水平: \(String(format: "%.2f", profile.stressLevel)), 幸福感指数: \(String(format: "%.2f", profile.wellBeingScore)), 情绪波动率: \(String(format: "%.2f", profile.emotionalVolatility))"
        }
        
        // 5. 纪念日数据
        var upcomingAnniversaryContext = "当前没有即将到来的纪念日或日程。"
        if let activeAnniversary = DependencyContainer.shared.anniversaryService.activeAnniversary,
           let info = DependencyContainer.shared.anniversaryService.activeAnniversaryInfo {
            upcomingAnniversaryContext = "当前纪念日「\(activeAnniversary.title)」已相伴 \(Int(info.calculation.totalDays)) 天。"
            if let nextMilestone = info.milestones.first {
                upcomingAnniversaryContext += " 最近里程碑「\(nextMilestone.label)」将在 \(nextMilestone.formattedDate) 到来，倒计时 \(nextMilestone.countDisplay)。"
            }
        }
        
        // 6. 确定 LLM 提供商和配置
        let apiSettings = apiSettingsService.getSettings()
        let activeProvider = apiSettings.currentProvider
        let config = apiSettings.providerConfigs[activeProvider] ?? apiSettings.currentConfig
        
        let providerKey = config.apiKey
        let providerURL = config.apiURL
        let model = config.model
        
        guard !providerKey.isEmpty || activeProvider == .ollama else {
            log("跳过本次心跳：未配置当前 AI 提供商的 API 密钥。")
            return
        }
        
        // 7. 构建 LLM 系统提示词与上下文
        let systemPrompt = """
        你是一个运行在 macOS 后台的智能个人助理 (Proactive Heartbeat Engine)。
        你的目标是默默观察系统的状态、用户的作息和心理状态，并决定是否要主动打扰用户或执行一些背景自动化操作。
        
        你必须以 JSON 格式输出决策，不要包含任何多余的前言、结语或 markdown 格式，只返回一个合法的 JSON 对象。
        JSON 格式如下：
        {
          "shouldInteract": true,
          "interactionType": "widget_speech",
          "message": "气泡关怀话语",
          "actionName": "auto_clean_workspace",
          "actionArgs": { "workspacePath": "/Users/username/Desktop" },
          "reason": "心跳分析报告"
        }
        
        支持的动作(actionName)：
        1. "auto_clean_workspace"：当桌面待整理文件较多（例如超过 10 个）且触发器包含 "workspace" 时。参数 "workspacePath" 必须为用户的桌面路径。
        2. "release_system_memory"：当系统空闲内存极低（PhysMem free 极其微小）且触发器包含 "performance" 时。不需要参数。
        3. "none"：不执行任何后台动作。
        
        支持的交互方式(interactionType)：
        1. "widget_speech"：在桌面小组件宠物头像旁显示一个暖心的气泡，保持在 25 字以内。
        2. "system_notification"：发送系统横幅通知。
        3. "none"：不打扰用户。
        
        约束要求：
        - 保持极其克制：shouldInteract 默认为 false，除非检测到明显异常或到了重要节点。
        - 气泡文本要具有心理同理心，特别是当压力水平较高时，给予基于 CBT 或接纳承诺疗法的正向引导。
        """
        
        var userContext = "【当前监控上下文】\n"
        let triggers = settingsService.settings.proactiveEnabledTriggers
        
        if triggers.contains("performance") {
            userContext += "- 系统资源状态 (cpu/memory):\n\(cpuMemoryStats.prefix(500))\n"
        }
        if triggers.contains("workspace") {
            userContext += "- 桌面未整理文件数: \(desktopFilesCount) 个 (桌面路径: \(desktopPath))\n"
        }
        if triggers.contains("emotion") {
            userContext += "- 用户情绪指标: \(psychoContext)\n"
        }
        if triggers.contains("health") {
            userContext += "- 纪念日倒计时关怀: \(upcomingAnniversaryContext)\n"
        }
        
        userContext += "\n请进行观察并输出 JSON 决策。"
        
        // 8. 触发 LLM 请求
        let provider = UniversalLLMProvider(providerType: activeProvider)
        provider.updateAPIKey(providerKey)
        provider.updateBaseURL(providerURL)
        
        let messages = [ChatMessage(role: "user", content: userContext)]
        
        var responseText = ""
        do {
            let stream = provider.streamChat(
                messages: messages,
                systemPrompt: systemPrompt,
                model: model
            )
            for try await chunk in stream {
                responseText += chunk
            }
        } catch {
            log("🔍 心跳周期监测异常：模型查询失败。")
            LoggerService.shared.error("ProactiveAgentService: Stream chat failed: \(error)")
            return
        }
        
        // 9. 解析 JSON 响应
        guard let decision = parseDecision(responseText) else {
            LoggerService.shared.warning("ProactiveAgentService: Failed to parse LLM response: \(responseText)")
            return
        }
        
        // 10. 处理决策
        if let reason = decision.reason, !reason.isEmpty {
            LoggerService.shared.info("ProactiveAgentService reason: \(reason)")
        }
        
        // 处理主动建议与弹窗/气泡
        if decision.shouldInteract {
            let messageText = decision.message ?? ""
            if decision.interactionType == "widget_speech" && !messageText.isEmpty {
                UserDefaults.standard.set(messageText, forKey: "YumikoToys_ProactiveBubbleText")
                UserDefaults.standard.synchronize()
                
                // 强制刷新 Widget
                if let activeAnniversary = DependencyContainer.shared.anniversaryService.activeAnniversary {
                    DependencyContainer.shared.anniversaryService.setActiveAnniversary(id: activeAnniversary.id)
                }
                
                log("💬 气泡关怀：\(messageText)")
            } else if decision.interactionType == "system_notification" && !messageText.isEmpty {
                sendLocalNotification(title: "智能助手关怀", message: messageText)
                log("🔔 主动通知：\(messageText)")
            }
        } else {
            // 如果 LLM 觉得不用展示气泡，静默清除上一次的气泡文字（或者让其在下一次 ticks 时回归正常）
            // 这里我们不主动强力清空以防气泡闪烁，但如果 interactionType 是 "none" 且 shouldInteract 是 false，我们也可以清理
            if decision.interactionType == "none" {
                UserDefaults.standard.removeObject(forKey: "YumikoToys_ProactiveBubbleText")
                UserDefaults.standard.synchronize()
                
                if let activeAnniversary = DependencyContainer.shared.anniversaryService.activeAnniversary {
                    DependencyContainer.shared.anniversaryService.setActiveAnniversary(id: activeAnniversary.id)
                }
            }
        }
        
        // 处理自动化技能执行
        if let action = decision.actionName, action != "none" && !action.isEmpty {
            let autoExecute = settingsService.settings.proactiveAutoExecuteTasks
            let args = decision.actionArgs ?? [:]
            
            if autoExecute {
                log("⚙️ 自动执行技能 '\(action)'...")
                Task {
                    let result = await SkillService.shared.executeSkill(name: action, arguments: args)
                    self.log("⚙️ 技能已完成：\(action)。运行结果已写入系统日志。")
                    LoggerService.shared.info("Executed skill \(action) with result: \(result)")
                }
            } else {
                // 提示确认
                let displayActionName = action == "auto_clean_workspace" ? "整理桌面工作区" : "释放系统物理内存"
                sendLocalNotification(
                    title: "自动整理推荐",
                    message: "建议进行：\(displayActionName)。前往设置页面即可一键启动或开启自动运行。"
                )
                log("💡 推荐任务：系统建议执行「\(displayActionName)」，已发送通知提示。")
            }
        }
        
        if !decision.shouldInteract && (decision.actionName == nil || decision.actionName == "none") {
            log("🔍 心跳周期监测正常，未检测到异常波动。")
        }
    }
    
    // MARK: - Helpers
    
    private func parseDecision(_ text: String) -> ProactiveDecision? {
        var cleanJson = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 清理 Markdown JSON 块包裹
        if cleanJson.hasPrefix("```json") {
            cleanJson = cleanJson.replacingOccurrences(of: "```json", with: "")
            if cleanJson.hasSuffix("```") {
                cleanJson = String(cleanJson.dropLast(3))
            }
        } else if cleanJson.hasPrefix("```") {
            cleanJson = cleanJson.replacingOccurrences(of: "```", with: "")
            if cleanJson.hasSuffix("```") {
                cleanJson = String(cleanJson.dropLast(3))
            }
        }
        cleanJson = cleanJson.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 容错搜索首尾大括号
        if let startRange = cleanJson.range(of: "{"),
           let endRange = cleanJson.range(of: "}", options: .backwards) {
            cleanJson = String(cleanJson[startRange.lowerBound...endRange.upperBound])
        }
        
        guard let data = cleanJson.data(using: .utf8) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(ProactiveDecision.self, from: data)
        } catch {
            LoggerService.shared.warning("ProactiveAgentService: JSON decode failed for: \(cleanJson), error: \(error)")
            return nil
        }
    }
    
    private func sendLocalNotification(title: String, message: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "com.yumikotoys.proactive.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
    
    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeStr = formatter.string(from: Date())
        let formattedLog = "[\(timeStr)] \(message)"
        
        activityLogs.append(formattedLog)
        if activityLogs.count > 100 {
            activityLogs.removeFirst(activityLogs.count - 100)
        }
        saveLogs()
    }
    
    private func saveLogs() {
        UserDefaults.standard.set(activityLogs, forKey: "YumikoToys_ProactiveLogs")
    }
    
    private func loadLogs() {
        if let savedLogs = UserDefaults.standard.stringArray(forKey: "YumikoToys_ProactiveLogs") {
            activityLogs = savedLogs
        }
    }
    
    private func isScreenLocked() -> Bool {
        if let sessionDict = CGSessionCopyCurrentDictionary() as? [String: Any],
           let isLocked = sessionDict["CGSSessionScreenIsLocked"] as? Bool {
            return isLocked
        }
        return false
    }
}

// MARK: - Decodable Decision model

struct ProactiveDecision: Codable {
    let shouldInteract: Bool
    let interactionType: String
    let message: String?
    let actionName: String?
    let actionArgs: [String: String]?
    let reason: String?
}
