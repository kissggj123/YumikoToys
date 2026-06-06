//
//  Theme.swift
//  YumikoToys
//
//  ResolvedTheme 结构体，用于解决主界面和状态栏主题色独立配置后的色彩解析
//

import SwiftUI

@MainActor struct ResolvedTheme: Equatable, Sendable {
    let color: ThemeColor
    let customHex: String
    
    var backgroundColor: Color { color.backgroundColor(customHex: customHex) }
    var nsBackgroundColor: NSColor { color.nsBackgroundColor(customHex: customHex) }
    var accentColor: Color { color.accentColor(customHex: customHex) }
    var iconGradient: [Color] { color.iconGradient(customHex: customHex) }
    var textColor: Color { color.textColor(customHex: customHex) }
    var secondaryTextColor: Color { color.secondaryTextColor(customHex: customHex) }
    var cardBackgroundColor: Color { color.cardBackgroundColor(customHex: customHex) }
    var buttonBackgroundColor: Color { color.buttonBackgroundColor(customHex: customHex) }
    var isDarkTheme: Bool { color.isDarkTheme(customHex: customHex) }
    var isCustomLight: Bool { color.isCustomLight(customHex: customHex) }
    var isCustomDarkBackground: Bool { color.isCustomDarkBackground(customHex: customHex) }
    var isAccentLight: Bool { color.isAccentLight(customHex: customHex) }
    var borderColor: Color { color.borderColor(customHex: customHex) }
    var dividerColor: Color { color.dividerColor(customHex: customHex) }
    var toggleOnColor: Color { color.toggleOnColor(customHex: customHex) }
    var toggleBackgroundColor: Color { color.toggleBackgroundColor(customHex: customHex) }
    var primaryButtonBackground: Color { color.primaryButtonBackground(customHex: customHex) }
    var primaryButtonTextColor: Color { color.primaryButtonTextColor(customHex: customHex) }
    var secondaryButtonBackground: Color { color.secondaryButtonBackground(customHex: customHex) }
    var destructiveButtonColor: Color { color.destructiveButtonColor(customHex: customHex) }
    var iconColor: Color { color.iconColor(customHex: customHex) }
    var hoverBackgroundColor: Color { color.hoverBackgroundColor(customHex: customHex) }
}
