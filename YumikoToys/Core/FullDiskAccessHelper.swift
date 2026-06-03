//
//  FullDiskAccessHelper.swift
//  YumikoToys
//
//  完全磁盘访问权限检测与引导助手
//

import Foundation
import AppKit

public struct FullDiskAccessHelper {
    
    /// 检查当前应用是否拥有完全磁盘访问权限（FDA）
    public static var hasFullDiskAccess: Bool {
        // 尝试读取受系统 TCC FDA 保护的文件或目录
        let testPaths = [
            NSHomeDirectory() + "/Library/Safari/History.db",
            NSHomeDirectory() + "/Library/Messages/chat.db",
            "/Library/Preferences/com.apple.TimeMachine.plist"
        ]
        
        for path in testPaths {
            if let file = fopen(path, "r") {
                fclose(file)
                return true
            }
        }
        
        // 尝试列出受限文件夹的内容
        let testDirs = [
            NSHomeDirectory() + "/Library/Safari",
            NSHomeDirectory() + "/Library/Messages"
        ]
        
        for dir in testDirs {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue {
                do {
                    _ = try FileManager.default.contentsOfDirectory(atPath: dir)
                    return true
                } catch {
                    // 继续尝试
                }
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
