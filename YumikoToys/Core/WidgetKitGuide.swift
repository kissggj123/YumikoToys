import AppKit
import Foundation

/// 把"打开系统小组件 / 通知中心 / 桌面小组件"这种深链集中到一处
/// 避免散落各处写 URL 拼字符串
enum WidgetKitGuide {

    /// 打开 macOS 通知中心（菜单栏右上角的"时间 / 通知中心"图标）
    /// macOS 没有官方 deep link，最稳的办法是直接打开 System Settings 里的"通知中心"面板，
    /// 用户可以点一下右上角的时间图标或者继续在面板里找"编辑小组件"。
    static func openNotificationCenter() {
        // macOS 14+ System Settings: x-apple.systempreferences:com.apple.preference?DesktopAndDock?WidgetSettings
        // 没有标准字段的话先打开 Desktop & Dock 面板
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference?DesktopAndDock") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 打开系统控制中心设置面板
    static func openControlCenterSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference?ControlCenter") {
            NSWorkspace.shared.open(url)
        }
    }
}
