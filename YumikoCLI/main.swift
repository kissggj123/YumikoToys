//
//  main.swift
//  YumikoCLI
//

import Foundation
import ArgumentParser
import AppKit

struct Yumiko: ParsableCommand {
    
    static var configuration = CommandConfiguration(
        commandName: "YumikoToys",
        abstract: "一个控制 YumikoToys App 的小工具。",
        subcommands: [Toggle.self]
    )

    // --- 这里是最终、最简、最正确的 @Flag 定义 ---
    // 我们移除了所有不必要的参数 (inversion, exclusivity)
    @Flag(name: [.long, .customShort("v")], help: "显示 YumikoToys 的版本号并退出。")
    var version: Bool = false

    func run() throws {
        if version {
            print("正在获取版本...")
            
            guard let appBundle = NSWorkspace.shared.runningApplications.first(where: { app in
                app.bundleIdentifier == "com.Lite.YumikoToys"
            })?.bundleURL else {
                print("错误：YumikoToys 应用没有在运行，或者找不到它。")
                throw ExitCode.failure
            }
            
            if let versionString = Bundle(url: appBundle)?.infoDictionary?["CFBundleShortVersionString"] as? String {
                print("🐰 YumikoToys 版本: \(versionString)")
            } else {
                print("错误：无法读取版本号。")
                throw ExitCode.failure
            }
            
            // 正常结束 run() 方法即代表成功退出
            return
            
        } else {
            // 如果用户只输入了 YumikoToys，显示帮助信息
            throw CleanExit.helpRequest(self)
        }
    }
}

// "toggle" 子命令 (保持不变)
extension Yumiko {
    struct Toggle: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "toggle",
            abstract: "切换资本家黑奴牛马模式的开关。"
        )

        func run() throws {
            print("正在向 YumikoToys 发送切换指令...")
            
            guard let url = URL(string: "yumikotoys://toggleRegularMode") else { return }
            
            let success = NSWorkspace.shared.open(url)
            
            if success {
                print("✅ 指令已发送！请查看 App 图标状态。")
            } else {
                print("❌ 指令发送失败。请确保 YumikoToys 应用正在运行。")
            }
        }
    }
}

// 入口点 (保持不变)
Yumiko.main()
