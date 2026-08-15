//
//  PreventSleepService.swift
//  YumikoToys
//
//  防休眠服务实现（原生 + 进程级安全沙盒物理提权版）
//

import Foundation
import IOKit.pwr_mgt
import Combine

/// 防休眠服务实现
@MainActor
final class PreventSleepService: PreventSleepServiceProtocol {
    
    // MARK: - Properties
    
    private(set) var isPreventSleepEnabled: Bool = false
    
    private var isPreventSleepEnabledSubject = CurrentValueSubject<Bool, Never>(false)
    
    var isPreventSleepEnabledPublisher: AnyPublisher<Bool, Never> {
        isPreventSleepEnabledSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Sleep Guard Telemetry
    private(set) var activeAssertionOwner: String = "系统准备就绪 (无第三方程序接管)"
    private(set) var activeAssertionType: String = "系统睡眠正常"

    private var activeAssertionOwnerSubject = CurrentValueSubject<String, Never>("系统准备就绪 (无第三方程序接管)")

    var activeAssertionOwnerPublisher: AnyPublisher<String, Never> {
        activeAssertionOwnerSubject.eraseToAnyPublisher()
    }

    private var guardTimer: Timer?
    
    // 多个断言 ID（显示器睡眠 + 系统睡眠）
    private var displayAssertionID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
    private var idleAssertionID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
    
    private let storageService: StorageServiceProtocol
    private let settingsKey = "yumikotoys.preventSleep"
    private let autoDisableOnLaunchKey = "yumikotoys.preventSleep.autoDisableOnLaunch"
    
    var autoDisableSleepOnLaunch: Bool {
        get {
            storageService.load(forKey: autoDisableOnLaunchKey) ?? false
        }
        set {
            storageService.save(newValue, forKey: autoDisableOnLaunchKey)
        }
    }
    
    func setAutoDisableSleepOnLaunch(_ enabled: Bool) {
        autoDisableSleepOnLaunch = enabled
        LoggerService.shared.info("Set autoDisableSleepOnLaunch: \(enabled)")
    }
    
    nonisolated var serviceName: String { "PreventSleepService" }
    
    // MARK: - Initialization
    
    init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }
    
    // MARK: - ServiceLifecycle
    
    func initialize() async {
        // 自动清理历史版本可能遗留的系统级守护进程 plist
        let legacyDaemonPath = "/Library/LaunchDaemons/com.yumikotoys.sleepdaemon.plist"
        if FileManager.default.fileExists(atPath: legacyDaemonPath) {
            LoggerService.shared.warning("Cleaning up legacy sleep daemon at \(legacyDaemonPath)...")
            let process = Process()
            process.launchPath = "/bin/rm"
            process.arguments = ["-f", legacyDaemonPath]
            try? process.run()
        }

        // 只有在用户显式开启“开机自启时自动禁用休眠”选项时，才在启动时自动开启防休眠断言；否则自动跑开机恢复睡眠保护
        let autoDisable = storageService.load(forKey: autoDisableOnLaunchKey) ?? false
        if autoDisable {
            enablePreventSleep()
        } else {
            restoreSystemSleepMode()
        }
        startSleepGuardMonitoring()
        LoggerService.shared.info("PreventSleepService initialized, enabled: \(isPreventSleepEnabled), autoDisableOnLaunch: \(autoDisable)")
    }
    
    func start() async {
        startSleepGuardMonitoring()
    }
    
    func stop() {
        guardTimer?.invalidate()
        guardTimer = nil
        disablePreventSleep()
        LoggerService.shared.info("PreventSleepService stopped")
    }

    // MARK: - Low-Overhead Sleep Guard Monitoring (Async Utility Thread)

    private func startSleepGuardMonitoring() {
        guardTimer?.invalidate()
        scanSystemSleepAssertions()
        // 5.0s 后台轻量级无感采样，0 CPU 占用与零主线程阻塞
        guardTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scanSystemSleepAssertions()
            }
        }
        if let guardTimer {
            RunLoop.main.add(guardTimer, forMode: .common)
        }
    }

    private func scanSystemSleepAssertions() {
        let selfPid = ProcessInfo.processInfo.processIdentifier
        let whitelist = DependencyContainer.shared.settingsService.settings.sleepGuardWhitelist.map { $0.lowercased() }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let task = Process()
            task.launchPath = "/usr/bin/pmset"
            task.arguments = ["-g", "assertions"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    var foundOwner = "系统准备就绪 (无第三方程序接管)"
                    var foundType = "系统睡眠正常"
                    var isPreventedByRogue = false

                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.starts(with: "pid ") {
                            let regexPattern = #"pid\s+(\d+)\(([^)]+)\):\s+\[[^\]]+\]\s+[^\s]+\s+([A-Za-z0-9_]+)"#
                            if let regex = try? NSRegularExpression(pattern: regexPattern),
                               let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) {
                                
                                let pidStr = (trimmed as NSString).substring(with: match.range(at: 1))
                                let procName = (trimmed as NSString).substring(with: match.range(at: 2))
                                let assertType = (trimmed as NSString).substring(with: match.range(at: 3))

                                if let pid = Int32(pidStr), pid != selfPid {
                                    if assertType.contains("Prevent") || assertType.contains("NoDisplay") || assertType.contains("NoIdle") {
                                        let procNameLower = procName.lowercased()
                                        let isWhitelisted = whitelist.contains { procNameLower.contains($0) }

                                        if isWhitelisted {
                                            foundOwner = "\(procName) (PID: \(pidStr)) [AI/开发白名单放行]"
                                            foundType = assertType
                                            break
                                        } else {
                                            foundOwner = "\(procName) (PID: \(pidStr))"
                                            foundType = assertType
                                            isPreventedByRogue = true
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if self.activeAssertionOwner != foundOwner || self.activeAssertionType != foundType {
                            self.activeAssertionOwner = foundOwner
                            self.activeAssertionType = foundType
                            self.activeAssertionOwnerSubject.send(foundOwner)
                        }
                    }
                }
            } catch {
                LoggerService.shared.error("Failed to run pmset -g assertions: \(error)")
            }
        }
    }
    
    private var caffeinateProcess: Process?

    private func executePmsetDisablesleep(_ disable: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            let val = disable ? "1" : "0"
            if let password = YumikoToysKeychain.getSavedPassword(), !password.isEmpty {
                let safePass = password.replacingOccurrences(of: "'", with: "'\\''")
                let process = Process()
                process.launchPath = "/bin/bash"
                process.arguments = ["-c", "echo '\(safePass)' | sudo -S pmset -a disablesleep \(val)"]
                try? process.run()
                process.waitUntilExit()
                LoggerService.shared.info("[PREVENT_SLEEP_DIAGNOSTIC] Executed sudo pmset -a disablesleep \(val) via Keychain password")
            } else {
                let process = Process()
                process.launchPath = "/usr/bin/pmset"
                process.arguments = ["-a", "disablesleep", val]
                try? process.run()
            }
        }
    }

    func enablePreventSleep() {
        LoggerService.shared.info("[PREVENT_SLEEP_DIAGNOSTIC] User toggled Prevent Sleep ON. Creating IOPMAssertions...")
        print("[PREVENT_SLEEP_DIAGNOSTIC] User toggled Prevent Sleep ON. Creating IOPMAssertions...")

        // 先彻底释放可能残留的历史断言句柄，确保每次重新开启均建立全新的物理断言
        releaseAssertions()
        
        // 1. 阻止显示器睡眠 (PreventUserIdleDisplaySleep)
        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "YumikoToys Prevent Display Sleep" as CFString,
            &displayAssertionID
        )
        
        // 2. 阻止系统空闲睡眠 (PreventUserIdleSystemSleep)
        let idleResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "YumikoToys Prevent System Sleep" as CFString,
            &idleAssertionID
        )

        // 3. 启动子进程 caffeinate 加固防休眠锁定
        if caffeinateProcess == nil {
            let proc = Process()
            proc.launchPath = "/usr/bin/caffeinate"
            proc.arguments = ["-u", "-d", "-i", "-s"]
            try? proc.run()
            self.caffeinateProcess = proc
        }

        // 4. 物理设置 pmset disablesleep 1 强制禁用 macOS 苹果菜单中的 Sleep 选项
        executePmsetDisablesleep(true)
        
        if displayResult == kIOReturnSuccess || idleResult == kIOReturnSuccess {
            isPreventSleepEnabled = true
            isPreventSleepEnabledSubject.send(true)
            storageService.save(true, forKey: settingsKey)
            LoggerService.shared.info("[PREVENT_SLEEP_DIAGNOSTIC] Prevent sleep enabled successfully (displayID=\(displayAssertionID), idleID=\(idleAssertionID), displayResult=\(displayResult), idleResult=\(idleResult))")
            print("[PREVENT_SLEEP_DIAGNOSTIC] Prevent sleep enabled successfully (displayID=\(displayAssertionID), idleID=\(idleAssertionID))")
        } else {
            LoggerService.shared.error("[PREVENT_SLEEP_DIAGNOSTIC] Failed to enable prevent sleep: display=\(displayResult), idle=\(idleResult)")
            print("[PREVENT_SLEEP_DIAGNOSTIC] Failed to enable prevent sleep: display=\(displayResult), idle=\(idleResult)")
            releaseAssertions()
            isPreventSleepEnabled = false
            isPreventSleepEnabledSubject.send(false)
        }
    }
    
    func disablePreventSleep() {
        LoggerService.shared.info("[PREVENT_SLEEP_DIAGNOSTIC] User toggled Prevent Sleep OFF. Releasing IOPMAssertions...")
        print("[PREVENT_SLEEP_DIAGNOSTIC] User toggled Prevent Sleep OFF. Releasing IOPMAssertions...")
        
        releaseAssertions()

        if let proc = caffeinateProcess {
            proc.terminate()
            caffeinateProcess = nil
        }

        // 物理设置 pmset disablesleep 0 恢复 macOS 苹果菜单中的 Sleep 选项
        executePmsetDisablesleep(false)
        
        isPreventSleepEnabled = false
        isPreventSleepEnabledSubject.send(false)
        storageService.save(false, forKey: settingsKey)
        LoggerService.shared.info("[PREVENT_SLEEP_DIAGNOSTIC] Prevent sleep disabled")
    }
    
    func togglePreventSleep() {
        if isPreventSleepEnabled {
            disablePreventSleep()
        } else {
            enablePreventSleep()
        }
    }

    func restoreSystemSleepMode() {
        // 1. 强行释放本软件占用的所有底层 IOPMAssertion 物理断言
        releaseAssertions()

        if let proc = caffeinateProcess {
            proc.terminate()
            caffeinateProcess = nil
        }

        isPreventSleepEnabled = false
        isPreventSleepEnabledSubject.send(false)
        storageService.save(false, forKey: settingsKey)

        // 2. 强行终止系统后台残留卡死的 caffeinate 守护进程并解冻 disablesleep 0
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let killTask = Process()
            killTask.launchPath = "/usr/bin/pkill"
            killTask.arguments = ["-9", "-f", "caffeinate"]
            try? killTask.run()
            killTask.waitUntilExit()

            self?.executePmsetDisablesleep(false)
            
            Task { @MainActor in
                self?.scanSystemSleepAssertions()
            }
        }

        LoggerService.shared.info("Manually force-restored system sleep mode and cleared all sleep blocking assertions")
    }
    
    // MARK: - Private Methods
    
    private func releaseAssertions() {
        if displayAssertionID != IOPMAssertionID(kIOPMNullAssertionID) {
            let result = IOPMAssertionRelease(displayAssertionID)
            if result == kIOReturnSuccess {
                displayAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
                LoggerService.shared.debug("Display assertion released")
            } else {
                LoggerService.shared.error("Failed to release display assertion: \(result)")
            }
        }
        
        if idleAssertionID != IOPMAssertionID(kIOPMNullAssertionID) {
            let result = IOPMAssertionRelease(idleAssertionID)
            if result == kIOReturnSuccess {
                idleAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
                LoggerService.shared.debug("Idle assertion released")
            } else {
                LoggerService.shared.error("Failed to release idle assertion: \(result)")
            }
        }
    }
}
