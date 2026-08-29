//
//  NIOConfigWindowManager.swift
//  YumikoToys
//
//  独立的 NIO API 配置窗口，避免嵌套在状态栏 Popover 中。
//

import AppKit
import SwiftUI

@MainActor
final class NIOConfigWindowManager: NSObject, NSWindowDelegate {
    static let shared = NIOConfigWindowManager()

    private var window: NSWindow?
    private var controller: NSWindowController?

    private override init() {
        super.init()
    }

    func open(themeColor: ThemeColor) {
        DependencyContainer.shared.windowManager.showWindow(.settings) {
            SettingsView(initialTab: .nio)
        }
    }

    func close() {
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        controller = nil
    }
}
