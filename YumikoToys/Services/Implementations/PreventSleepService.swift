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
    
    // 多个断言 ID（显示器睡眠 + 系统睡眠）
    private var displayAssertionID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
    private var idleAssertionID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
    
    private let storageService: StorageServiceProtocol
    private let settingsKey = "yumikotoys.preventSleep"
    
    var serviceName: String { "PreventSleepService" }
    
    // MARK: - Initialization
    
    init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
    }
    
    // MARK: - ServiceLifecycle
    
    func initialize() async {
        // 加载之前的设置
        if let enabled: Bool = storageService.load(forKey: settingsKey), enabled {
            enablePreventSleep()
        }
        LoggerService.shared.info("PreventSleepService initialized, enabled: \(isPreventSleepEnabled)")
    }
    
    func start() async {
        // 服务已启动
    }
    
    func stop() {
        disablePreventSleep()
        LoggerService.shared.info("PreventSleepService stopped")
    }
    
    // MARK: - PreventSleepServiceProtocol
    
    func enablePreventSleep() {
        guard !isPreventSleepEnabled else {
            LoggerService.shared.debug("Prevent sleep already enabled")
            return
        }
        
        // 1. 阻止显示器睡眠
        let displayResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "YumikoToys Prevent Display Sleep" as CFString,
            &displayAssertionID
        )
        
        // 2. 阻止系统空闲睡眠
        let idleResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "YumikoToys Prevent System Sleep" as CFString,
            &idleAssertionID
        )
        
        if displayResult == kIOReturnSuccess && idleResult == kIOReturnSuccess {
            isPreventSleepEnabled = true
            isPreventSleepEnabledSubject.send(true)
            storageService.save(true, forKey: settingsKey)
            LoggerService.shared.info("Prevent sleep enabled (display + system)")
            
            // 提权：在独立的子进程中执行，彻底绝缘 NSAppleScript 内存泄漏闪退
            Task {
                await executePrivilegedPmset(disableSleep: true)
            }
        } else {
            LoggerService.shared.error("Failed to enable prevent sleep: display=\(displayResult), idle=\(idleResult)")
            releaseAssertions()
        }
    }
    
    func disablePreventSleep() {
        guard isPreventSleepEnabled else {
            LoggerService.shared.debug("Prevent sleep already disabled")
            return
        }
        
        releaseAssertions()
        
        // 提权关闭：在独立的子进程中执行
        Task {
            await executePrivilegedPmset(disableSleep: false)
        }
        
        isPreventSleepEnabled = false
        isPreventSleepEnabledSubject.send(false)
        storageService.save(false, forKey: settingsKey)
        LoggerService.shared.info("Prevent sleep disabled")
    }
    
    func togglePreventSleep() {
        if isPreventSleepEnabled {
            disablePreventSleep()
        } else {
            enablePreventSleep()
        }
    }
    
    // MARK: - Private Methods
    
    /// 执行特权全局 pmset 物理屏蔽（利用 Process 异步调用，100% 杜绝 objc_release 闪退）
    private func executePrivilegedPmset(disableSleep: Bool) async {
        guard let savedPassword = YumikoToysKeychain.getSavedPassword(), !savedPassword.isEmpty else {
            return
        }
        
        let value = disableSleep ? "1" : "0"
        let scriptText = "sudo pmset -a disablesleep \(value)"
        
        let escapedScript = scriptText.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let appleScriptSource = """
        do shell script "\(escapedScript)" with administrator privileges user name "\(NSUserName())" password "\(savedPassword)"
        """
        
        // 【核心提权安全升级】弃用不安全的 NSAppleScript 指针管理，改用完全物理隔离的 Process 子进程
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", appleScriptSource]
        
        do {
            try process.run()
            Task.detached {
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    LoggerService.shared.info("✅ Privileged pmset disablesleep \(value) successfully applied")
                } else {
                    LoggerService.shared.error("❌ Privileged pmset failed with exit code: \(process.terminationStatus)")
                }
            }
        } catch {
            LoggerService.shared.error("Process execution error: \(error)")
        }
    }
    
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
