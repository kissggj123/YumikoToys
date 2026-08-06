//
//  PetPerformanceMonitor.swift
//  YumikoToys
//
//  桌宠渲染引擎与进程 CPU/内存 真实实时监控模块
//

import Foundation
import Combine
import AppKit
import Darwin

@MainActor
final class PetPerformanceMonitor: ObservableObject {
    static let shared = PetPerformanceMonitor()

    @Published private(set) var cpuUsage: Double = 0.0
    @Published private(set) var memoryUsageMB: Double = 0.0

    private var timer: Timer?
    private var lastUserTime: UInt64 = 0
    private var lastSystemTime: UInt64 = 0
    private var lastCpuCheckTime: Date = Date()

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        stopMonitoring()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
        updateMetrics()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateMetrics() {
        // 1. 内存 (Mach Resident Size Footprint)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            memoryUsageMB = Double(info.resident_size) / (1024.0 * 1024.0)
        }

        // 2. CPU 使用率 (Mach Thread Times Info Delta)
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        let threadRes = task_threads(mach_task_self_, &threadList, &threadCount)

        if threadRes == KERN_SUCCESS, let list = threadList {
            var totalUser: UInt64 = 0
            var totalSystem: UInt64 = 0

            for i in 0..<Int(threadCount) {
                var thInfo = thread_basic_info()
                var thCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size) / 4
                let thRes = withUnsafeMutablePointer(to: &thInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(thCount)) {
                        thread_info(list[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &thCount)
                    }
                }
                if thRes == KERN_SUCCESS {
                    if (thInfo.flags & TH_FLAGS_IDLE) == 0 {
                        totalUser += UInt64(thInfo.user_time.seconds) * 1_000_000 + UInt64(thInfo.user_time.microseconds)
                        totalSystem += UInt64(thInfo.system_time.seconds) * 1_000_000 + UInt64(thInfo.system_time.microseconds)
                    }
                }
            }

            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: list)), vm_size_t(threadCount * UInt32(MemoryLayout<thread_t>.stride)))

            let now = Date()
            let timeDelta = now.timeIntervalSince(lastCpuCheckTime)
            if timeDelta > 0 && lastUserTime > 0 && totalUser >= lastUserTime && totalSystem >= lastSystemTime {
                let userDelta = Double(totalUser - lastUserTime) / 1_000_000.0
                let systemDelta = Double(totalSystem - lastSystemTime) / 1_000_000.0
                let totalCpuSeconds = userDelta + systemDelta
                let rawCpu = (totalCpuSeconds / timeDelta) * 100.0
                cpuUsage = max(0.0, rawCpu)
            }
            lastUserTime = totalUser
            lastSystemTime = totalSystem
            lastCpuCheckTime = now
        }
    }

    // MARK: - 引擎与状态判定

    var statusBarEngineName: String {
        let style = DependencyContainer.shared.settingsService.settings.statusBarIconStyle
        switch style {
        case .petBlue, .petGray, .petWhite, .petTall:
            return "SpriteKit (SKSpriteNode)"
        default:
            return "AppKit (NSImage)"
        }
    }

    var isStatusBarActive: Bool {
        let style = DependencyContainer.shared.settingsService.settings.statusBarIconStyle
        switch style {
        case .petBlue, .petGray, .petWhite, .petTall: return true
        default: return false
        }
    }

    var statusBarFPS: String {
        isStatusBarActive ? "7 FPS" : "静态"
    }

    var touchBarEngineName: String {
        let enabled = DependencyContainer.shared.settingsService.settings.isPetTouchBarEnabled
        return enabled ? "SpriteKit (SKScene)" : "未启用"
    }

    var isTouchBarActive: Bool {
        DependencyContainer.shared.settingsService.settings.isPetTouchBarEnabled
    }

    var touchBarFPS: String {
        isTouchBarActive ? "60 FPS" : "0 FPS"
    }

    var desktopEngineName: String {
        let enabled = DependencyContainer.shared.settingsService.settings.isPetPlaygroundEnabled
        return enabled ? "SpriteKit (PetDesktopScene)" : "未启用"
    }

    var isDesktopActive: Bool {
        DependencyContainer.shared.settingsService.settings.isPetPlaygroundEnabled
    }

    var desktopFPS: String {
        isDesktopActive ? "60 FPS" : "0 FPS"
    }
}
