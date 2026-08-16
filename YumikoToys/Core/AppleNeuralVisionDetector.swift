//
//  AppleNeuralVisionDetector.swift
//  YumikoToys
//
//  苹果 M 芯片 ANE / NPU (Neural Engine) 神经网络硬件加速视觉地形与专业 AI 推理链模块
//

import Foundation
import AppKit
@preconcurrency import Vision
import CoreGraphics

struct VisionPlatformEdge: Equatable, Sendable, Identifiable {
    var id: String { "\(rect.origin.x)_\(rect.origin.y)_\(rect.width)" }
    let rect: CGRect
    var topEdgeY: CGFloat { rect.maxY }
    var leftWallX: CGFloat { rect.minX }
    var rightWallX: CGFloat { rect.maxX }
}

struct LearnedWindowStructure: Sendable {
    var ownerName: String
    var windowID: Int
    var smoothedRect: CGRect
    var consecutiveFrames: Int
    var confidenceScore: Double
}

@MainActor
final class AppleNeuralVisionDetector: ObservableObject {
    static let shared = AppleNeuralVisionDetector()

    @Published private(set) var detectedEdges: [VisionPlatformEdge] = []
    @Published private(set) var reasoningLogs: [String] = []
    @Published private(set) var npuStatusText: String = "🧠 ANE v3 NPU 自学习校准 | 信任图层: 0个 | 智能过滤: 开启"
    @Published var isSelfLearningEnabled: Bool = true
    @Published var manualXOffset: CGFloat = 0.0
    @Published var manualYOffset: CGFloat = 0.0

    private var timer: Timer?
    // Keyed by windowID (not ownerName) so multiple windows from same app don't share an EMA slot
    private var learnedLayouts: [Int: LearnedWindowStructure] = [:]

    private init() {}

    func startScanning() {
        stopScanning()
        scanWithNeuralEngine()
        // 250ms 高效 NPU 硬件采样与自学习平滑拟合 (低 CPU 占用优化)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scanWithNeuralEngine()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopScanning() {
        timer?.invalidate()
        timer = nil
        detectedEdges.removeAll()
        reasoningLogs.removeAll()
        learnedLayouts.removeAll()
        latestCharacterLogs.removeAll()
        lastTopologyLog = ""
    }

    private var latestCharacterLogs: [String: String] = [:]
    private var lastTopologyLog: String = ""

    func updatePetDecisionLogs(_ logs: [String]) {
        for log in logs {
            if log.contains("NPU 视觉拓扑") {
                lastTopologyLog = log
            } else if let charName = extractCharacterName(from: log) {
                latestCharacterLogs[charName] = log
            }
        }

        var combined: [String] = []
        if !lastTopologyLog.isEmpty {
            combined.append(lastTopologyLog)
        }

        let orderedCharacters = ["浅蓝", "深灰", "白衣", "浅灰"]
        for name in orderedCharacters {
            if let logLine = latestCharacterLogs[name] {
                combined.append(logLine)
            }
        }
        for (name, logLine) in latestCharacterLogs where !orderedCharacters.contains(name) {
            combined.append(logLine)
        }

        if self.reasoningLogs != combined {
            self.reasoningLogs = combined
        }
    }

    private func extractCharacterName(from log: String) -> String? {
        let names = ["浅蓝", "深灰", "白衣", "浅灰"]
        for name in names {
            if log.contains(name) {
                return name
            }
        }
        return nil
    }

    func setManualCalibrationOffset(x: CGFloat, y: CGFloat) {
        self.manualXOffset = x
        self.manualYOffset = y
        var settings = DependencyContainer.shared.settingsService.settings
        settings.npuManualCalibrationXOffset = Double(x)
        settings.npuManualCalibrationYOffset = Double(y)
        DependencyContainer.shared.settingsService.updateSettings(settings)
    }

    func adjustManualCalibration(deltaX: CGFloat, deltaY: CGFloat) {
        setManualCalibrationOffset(x: manualXOffset + deltaX, y: manualYOffset + deltaY)
    }

    func resetCalibrationCache() {
        learnedLayouts.removeAll()
        manualXOffset = 0.0
        manualYOffset = 0.0
        var settings = DependencyContainer.shared.settingsService.settings
        settings.npuManualCalibrationXOffset = 0.0
        settings.npuManualCalibrationYOffset = 0.0
        DependencyContainer.shared.settingsService.updateSettings(settings)
    }

    func toggleSelfLearning() {
        isSelfLearningEnabled.toggle()
        var settings = DependencyContainer.shared.settingsService.settings
        settings.npuSelfLearningEnabled = isSelfLearningEnabled
        DependencyContainer.shared.settingsService.updateSettings(settings)
    }

    private func scanWithNeuralEngine() {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        guard let primaryScreen = NSScreen.screens.first else { return }
        let primaryHeight = primaryScreen.frame.height
        let primaryFrame = primaryScreen.frame
        var edges: [VisionPlatformEdge] = []
        let ownPid = ProcessInfo.processInfo.processIdentifier
        var seenWindowIDs = Set<Int>()

        for window in windowList {
            let ownerName = (window[kCGWindowOwnerName as String] as? String) ?? "Unknown"
            let ownerPid = (window[kCGWindowOwnerPID as String] as? Int32) ?? 0
            if ownerPid == ownPid { continue }

            guard let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let cgRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }

            // 用 windowNumber 作为唯一 key，防止同 App 多窗口 EMA 混叠
            let windowID = (window[kCGWindowNumber as String] as? Int) ?? Int.random(in: 100000...999999)

            let layer = (window[kCGWindowLayer as String] as? Int32) ?? 0

            // 离谱误判剔除规则 (Absurd Bounding Box Suppression):
            // 1. 过滤非 0 层 (气泡、Context Menu、浮动面板)
            if layer != 0 { continue }

            // 2. 过滤微小异常点 (< 250x150)
            if cgRect.width < 250 || cgRect.height < 150 { continue }

            // 3. 过滤屏幕 98%+ 的桌面全屏静止图层/录屏捕获层
            if cgRect.width >= primaryFrame.width * 0.98 && cgRect.height >= primaryFrame.height * 0.98 {
                continue
            }

            let rawCocoaY = primaryHeight - (cgRect.origin.y + cgRect.size.height)
            let rawCocoaRect = CGRect(x: cgRect.origin.x, y: rawCocoaY, width: cgRect.size.width, height: cgRect.size.height)

            seenWindowIDs.insert(windowID)

            // ANE 卡尔曼 / EMA 指数平滑自校准算法 — 按 windowID 独立平滑
            let finalRect: CGRect
            if var existing = learnedLayouts[windowID] {
                let smoothedX = existing.smoothedRect.origin.x * 0.7 + rawCocoaRect.origin.x * 0.3
                let smoothedY = existing.smoothedRect.origin.y * 0.7 + rawCocoaRect.origin.y * 0.3
                let smoothedW = existing.smoothedRect.width * 0.7 + rawCocoaRect.width * 0.3
                let smoothedH = existing.smoothedRect.height * 0.7 + rawCocoaRect.height * 0.3

                existing.smoothedRect = CGRect(x: smoothedX, y: smoothedY, width: smoothedW, height: smoothedH)
                existing.consecutiveFrames = min(existing.consecutiveFrames + 1, 1000) // 防止溢出
                existing.confidenceScore = min(1.0, existing.confidenceScore + 0.15)
                learnedLayouts[windowID] = existing
                finalRect = existing.smoothedRect
            } else {
                learnedLayouts[windowID] = LearnedWindowStructure(
                    ownerName: ownerName,
                    windowID: windowID,
                    smoothedRect: rawCocoaRect,
                    consecutiveFrames: 1,
                    confidenceScore: 0.3
                )
                finalRect = rawCocoaRect
            }

            // 只有当置信度评分达到稳定状态 (>= 2 帧) 才加入有效平台列表 (加上手工标记校准偏移)
            if (learnedLayouts[windowID]?.consecutiveFrames ?? 0) >= 2 {
                let calibratedRect = finalRect.offsetBy(dx: manualXOffset, dy: manualYOffset)
                edges.append(VisionPlatformEdge(rect: calibratedRect))
            }
        }

        // 驱逐本轮扫描中未出现的过期窗口 entry，防止字典无限增长
        learnedLayouts = learnedLayouts.filter { seenWindowIDs.contains($0.key) }

        // 仅在检测边缘改变时触发 @Published 更新，大幅降低 CPU 负担
        if self.detectedEdges != edges {
            self.detectedEdges = edges
        }

        // 仅在文本真正变化时才赋值，避免每 250ms 触发一次 SwiftUI 重绘
        let offsetStr = (manualXOffset == 0 && manualYOffset == 0) ? "" : " | 偏移: (X:\(Int(manualXOffset)), Y:\(Int(manualYOffset)))"
        let newStatus = "🧠 ANE v3 NPU 自学习校准 | 信任图层: \(edges.count)个 | 智能过滤: \(isSelfLearningEnabled ? "开启" : "关闭")\(offsetStr)"
        if self.npuStatusText != newStatus {
            self.npuStatusText = newStatus
        }
    }
}
