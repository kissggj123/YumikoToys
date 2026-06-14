//
//  AppScanner.swift
//  YumikoToys
//
//  应用列表扫描器 (v4.5.0 - 快捷获取与归类已加载应用)
//

import Foundation

struct InstalledAppInfo: Identifiable, Hashable, Sendable {
    var id: String { path }
    let name: String
    let path: String
    let category: String
}

final class AppScanner {
    static func scanInstalledApps() -> [InstalledAppInfo] {
        var apps: [InstalledAppInfo] = []
        let fm = FileManager.default
        
        let searchDirs = [
            "/Applications",
            "/System/Applications",
            "/Users/\(NSUserName())/Applications"
        ]
        
        for dir in searchDirs {
            guard let subPaths = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for subPath in subPaths {
                if subPath.hasSuffix(".app") {
                    let fullPath = (dir as NSString).appendingPathComponent(subPath)
                    let name = (subPath as NSString).deletingPathExtension
                    
                    // Simple categorization
                    var category = "其他应用"
                    if dir.contains("/System/") {
                        category = "系统应用"
                    } else if ["Xcode", "Terminal", "VS Code", "VSCodium", "Cursor", "IntelliJ IDEA", "Postman", "SourceTree", "GitHub Desktop", "iTerm"].contains(where: { name.contains($0) }) {
                        category = "开发工具"
                    } else if ["Safari", "Chrome", "Edge", "Firefox", "Opera", "QQBrowser", "WeChat", "QQ", "DingTalk", "Slack", "Discord", "Lark", "Feishu"].contains(where: { name.contains($0) }) {
                        category = "社交与浏览器"
                    } else if ["Pages", "Keynote", "Numbers", "Word", "Excel", "PowerPoint", "Notes", "Reminders", "Calendar", "Mail", "Calculator"].contains(where: { name.contains($0) }) {
                        category = "办公与效率"
                    }
                    
                    apps.append(InstalledAppInfo(name: name, path: fullPath, category: category))
                }
            }
        }
        
        return apps.sorted(by: { $0.name.localizedCompare($1.name) == .orderedAscending })
    }
}
