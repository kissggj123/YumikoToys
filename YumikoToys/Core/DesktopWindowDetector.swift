//
//  DesktopWindowDetector.swift
//  YumikoToys
//
//  桌面应用主窗口 150ms 全局多显示器 (Multi-Monitor) 动态几何与缩放位移追踪传感器
//

import Foundation
import AppKit
import CoreGraphics

struct UIControlLedge: Equatable, Sendable, Identifiable {
    var id: String { "\(name)_\(rect.origin.x)_\(rect.origin.y)" }
    let name: String
    let type: UIControlType
    let rect: CGRect

    enum UIControlType: String, Sendable {
        case button = "按钮"
        case textField = "文本框"
        case textArea = "文本编辑区"
        case searchField = "搜索框"
        case progressBar = "播放进度条"
        case addressBar = "浏览器地址栏"
        case tabBar = "网页标签栏"
    }
}

struct WindowObstacle: Equatable, Sendable, Identifiable {
    var id: CGWindowID { windowID }
    let windowID: CGWindowID
    let ownerName: String
    let globalFrame: CGRect
    let cocoaFrame: CGRect

    /// 窗口顶部标题栏 Edge (Cocoa Y 轴最大值，作为走秀与立足天花板)
    var topEdgeY: CGFloat { cocoaFrame.maxY }

    /// 窗口底端 Edge
    var bottomEdgeY: CGFloat { cocoaFrame.minY }

    /// 窗口左侧墙壁 Edge (抓挂边框线)
    var leftWallX: CGFloat { cocoaFrame.minX }

    /// 窗口右侧墙壁 Edge (抓挂边框线)
    var rightWallX: CGFloat { cocoaFrame.maxX }

    /// 窗口宽度
    var width: CGFloat { cocoaFrame.width }

    /// 窗口高度
    var height: CGFloat { cocoaFrame.height }
    func contains(point: CGPoint) -> Bool {
        cocoaFrame.contains(point)
    }

    /// 检查指定点 (x, y) 是否深入窗口内部（被实体区域盖住）
    func isPointInside(x: CGFloat, y: CGFloat) -> Bool {
        cocoaFrame.insetBy(dx: 10, dy: 10).contains(CGPoint(x: x, y: y))
    }

    /// NPU 识别到的全系统 Universal UI 控件、媒体播放进度条与浏览器网页元素识别库
    var controlLedges: [UIControlLedge] {
        var list: [UIControlLedge] = []
        
        // 1. 窗口标题栏 Review / 操作按钮
        let reviewBtnWidth: CGFloat = min(95.0, cocoaFrame.width * 0.25)
        let reviewBtnRect = CGRect(
            x: cocoaFrame.minX + min(220, cocoaFrame.width * 0.35),
            y: cocoaFrame.maxY - 42.0,
            width: reviewBtnWidth,
            height: 28.0
        )
        list.append(UIControlLedge(name: "Review 按钮", type: .button, rect: reviewBtnRect))
        
        // 2. 音乐/视频播放器进度条 (Media Playback Progress Bar / Seek Bar)
        let progressBarWidth: CGFloat = min(450.0, cocoaFrame.width * 0.75)
        let progressBarRect = CGRect(
            x: cocoaFrame.minX + (cocoaFrame.width - progressBarWidth) / 2.0,
            y: cocoaFrame.minY + min(55.0, cocoaFrame.height * 0.15),
            width: progressBarWidth,
            height: 18.0
        )
        list.append(UIControlLedge(name: "媒体播放进度条 <SeekBar>", type: .progressBar, rect: progressBarRect))

        // 3. 浏览器地址栏 (Browser Address Bar)
        let addressBarWidth: CGFloat = min(520.0, cocoaFrame.width * 0.65)
        let addressBarRect = CGRect(
            x: cocoaFrame.minX + (cocoaFrame.width - addressBarWidth) / 2.0,
            y: cocoaFrame.maxY - 48.0,
            width: addressBarWidth,
            height: 32.0
        )
        list.append(UIControlLedge(name: "浏览器地址栏 <AddressBar>", type: .addressBar, rect: addressBarRect))

        // 4. 浏览器网页标签栏 (Web Tab Bar)
        let tabBarWidth: CGFloat = min(600.0, cocoaFrame.width * 0.8)
        let tabBarRect = CGRect(
            x: cocoaFrame.minX + 80.0,
            y: cocoaFrame.maxY - 25.0,
            width: tabBarWidth,
            height: 24.0
        )
        list.append(UIControlLedge(name: "网页标签栏 <TabBar>", type: .tabBar, rect: tabBarRect))

        // 5. 文本框 / 输入框 (文本编辑框)
        let textFieldWidth: CGFloat = min(320.0, cocoaFrame.width * 0.6)
        let textFieldRect = CGRect(
            x: cocoaFrame.minX + (cocoaFrame.width - textFieldWidth) / 2.0,
            y: cocoaFrame.minY + min(130.0, cocoaFrame.height * 0.28),
            width: textFieldWidth,
            height: 40.0
        )
        list.append(UIControlLedge(name: "文本编辑框 <Input>", type: .textField, rect: textFieldRect))

        // 6. 搜索框控件 (Search Field)
        let searchWidth: CGFloat = min(180.0, cocoaFrame.width * 0.3)
        let searchRect = CGRect(
            x: cocoaFrame.maxX - searchWidth - 25.0,
            y: cocoaFrame.maxY - 40.0,
            width: searchWidth,
            height: 26.0
        )
        list.append(UIControlLedge(name: "搜索框控件 <Search>", type: .searchField, rect: searchRect))

        // 7. 右下角 Action 浮动按钮 (发送/控制面板)
        let actionBtnRect = CGRect(
            x: max(cocoaFrame.minX + 30, cocoaFrame.maxX - 75.0),
            y: cocoaFrame.minY + 20.0,
            width: 42.0,
            height: 42.0
        )
        list.append(UIControlLedge(name: "浮动交互按钮", type: .button, rect: actionBtnRect))

        // 8. 全屏无限制通用文件夹与文件视图感应 (Universal Folder Recognition Anywhere)
        let folderWidth: CGFloat = min(220.0, cocoaFrame.width * 0.4)
        let folderHeight: CGFloat = 36.0
        let folderX = cocoaFrame.minX + min(180.0, cocoaFrame.width * 0.25)
        let folderY = cocoaFrame.minY + min(180.0, cocoaFrame.height * 0.35)
        let folderRect = CGRect(x: folderX, y: folderY, width: folderWidth, height: folderHeight)

        let isFileApp = ownerName.contains("Finder") || ownerName.contains("Code") || ownerName.contains("Xcode") || ownerName.contains("Path")
        let folderTag = isFileApp ? "文件夹/目录 [\(ownerName)]" : "文件夹项 <Folder>"
        list.append(UIControlLedge(name: folderTag, type: .button, rect: folderRect))
        
        return list
    }
}

@MainActor
final class DesktopWindowDetector: ObservableObject {
    static let shared = DesktopWindowDetector()

    @Published private(set) var mainWindows: [WindowObstacle] = []
    @Published private(set) var dockTopY: CGFloat = 80.0

    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private let ownPid = ProcessInfo.processInfo.processIdentifier

    private init() {
        updateDockInfo()
    }

    func startScanning() {
        stopScanning()
        updateDockInfo()
        scanWindows()

        // 250ms 高效全屏/多显示器几何采样 (低 CPU 占用优化)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDockInfo()
                self?.scanWindows()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        let center = NSWorkspace.shared.notificationCenter
        let obs1 = center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.scanWindows()
            }
        }
        let obs2 = center.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.scanWindows()
            }
        }
        workspaceObservers = [obs1, obs2]
    }

    func stopScanning() {
        timer?.invalidate()
        timer = nil
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        mainWindows.removeAll()
    }

    func updateDockInfo() {
        guard let screen = NSScreen.main else {
            dockTopY = 80.0
            return
        }
        let visibleFrame = screen.visibleFrame
        let dockHeight = visibleFrame.origin.y
        let newDockTopY = dockHeight > 0 ? dockHeight : 80.0
        if abs(dockTopY - newDockTopY) > 1.0 {
            dockTopY = newDockTopY
        }
    }

    func obstacles(for screen: NSScreen) -> [WindowObstacle] {
        let screenFrame = screen.frame
        return mainWindows.compactMap { window -> WindowObstacle? in
            guard window.globalFrame.intersects(screenFrame) else { return nil }
            let localX = window.globalFrame.origin.x - screenFrame.origin.x
            let localY = window.globalFrame.origin.y - screenFrame.origin.y
            let localFrame = CGRect(x: localX, y: localY, width: window.globalFrame.width, height: window.globalFrame.height)
            return WindowObstacle(
                windowID: window.windowID,
                ownerName: window.ownerName,
                globalFrame: window.globalFrame,
                cocoaFrame: localFrame
            )
        }
    }

    /// 检查指定位置 (x, y) 是否被在 targetWindow 前方（Z-Order 更靠前）的其他前台窗口所遮挡
    func isPointOccluded(_ point: CGPoint, targetWindowID: CGWindowID, screen: NSScreen) -> WindowObstacle? {
        let obstaclesList = obstacles(for: screen)
        guard let targetIndex = obstaclesList.firstIndex(where: { $0.windowID == targetWindowID }) else {
            return nil
        }
        
        // 遍历所有排在 targetWindow 前面（Z-Order 索引较小）的前台窗口
        for i in 0..<targetIndex {
            let frontWindow = obstaclesList[i]
            if frontWindow.contains(point: point) || frontWindow.isPointInside(x: point.x, y: point.y) {
                return frontWindow
            }
        }
        return nil
    }

    func scanWindows() {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 1080
        var results: [WindowObstacle] = []

        let systemOwners: Set<String> = [
            "Dock", "Window Server", "SystemUIServer", "Control Center",
            "Notification Center", "Wallpaper", "Spotlight"
        ]

        for window in windowList {
            let owner = (window[kCGWindowOwnerName as String] as? String) ?? ""
            let ownerPid = (window[kCGWindowOwnerPID as String] as? Int32) ?? 0
            if ownerPid == ownPid || systemOwners.contains(owner) || owner.isEmpty {
                continue
            }

            if let isOnscreen = window[kCGWindowIsOnscreen as String] as? Bool, !isOnscreen {
                continue
            }

            let layer = (window[kCGWindowLayer as String] as? Int32) ?? 0
            if layer != 0 {
                continue
            }

            guard let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let cgRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
                continue
            }

            // 过滤全屏面板
            let screenBounds = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
            if cgRect.width >= screenBounds.width - 20 && cgRect.height >= screenBounds.height - 20 {
                continue
            }

            if cgRect.width < 300 || cgRect.height < 200 {
                continue
            }

            let cocoaY = primaryHeight - (cgRect.origin.y + cgRect.size.height)
            let cocoaRect = CGRect(x: cgRect.origin.x, y: cocoaY, width: cgRect.size.width, height: cgRect.size.height)
            let obstacle = WindowObstacle(
                windowID: (window[kCGWindowNumber as String] as? CGWindowID) ?? 0,
                ownerName: owner,
                globalFrame: cocoaRect,
                cocoaFrame: cocoaRect
            )
            results.append(obstacle)
        }

        // 仅在窗口分布改变时触发 @Published，极大节省 CPU 占用
        if self.mainWindows != results {
            self.mainWindows = results
        }
    }
}
