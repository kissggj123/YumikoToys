//
//  YumikoToysHelperApp.swift
//  YumikoToysHelper
//
//  Created by YumikoToys on 10/9/24.
//  Copyright © 2026 Menglolita. All rights reserved.
//

import SwiftUI
import Foundation
import AppKit

@main
struct YumikoToysHelperApp: App {
    init() {
        // 启动时检查并启动主应用
        checkAndLaunchMainApp()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    // 检查并启动主应用
    private func checkAndLaunchMainApp() {
        // 主应用的Bundle Identifier
        let mainAppBundleIdentifier = "com.Lite.YumikoToys"
        
        // 检查主应用是否已在运行
        let runningApps = NSWorkspace.shared.runningApplications
        let isMainAppRunning = runningApps.contains { app in
            app.bundleIdentifier == mainAppBundleIdentifier
        }
        
        if !isMainAppRunning {
            // 尝试从应用目录启动主应用
            if let mainAppPath = findMainAppPath() {
                NSWorkspace.shared.open(URL(fileURLWithPath: mainAppPath))
            }
        }
        
        // Helper应用完成任务后退出
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSApplication.shared.terminate(nil)
        }
    }
    
    // 查找主应用的路径
    private func findMainAppPath() -> String? {
        // 常见的应用路径
        let possiblePaths = [
            "/Applications/YumikoToys.app",
            "~/Applications/YumikoToys.app",
            "~/Documents/Xcodetools/YumikoToys Lite/YumikoToys.app"
        ]
        
        for path in possiblePaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return expandedPath
            }
        }
        
        return nil
    }
}
