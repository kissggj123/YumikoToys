//
//  AdaptiveLayoutManager.swift
//  YumikoToys
//
//  界面自适应管理器 - 根据系统参数动态调整布局
//

import SwiftUI
import AppKit

/// 屏幕尺寸类别
enum ScreenSizeCategory: String, CaseIterable {
    case compact    // 小屏幕 (< 13寸)
    case regular    // 标准屏幕 (13-16寸)
    case large      // 大屏幕 (> 16寸)
    
    init(width: CGFloat) {
        switch width {
        case ..<1280:
            self = .compact
        case 1280..<1920:
            self = .regular
        default:
            self = .large
        }
    }
}

/// 界面自适应管理器
@MainActor
final class AdaptiveLayoutManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AdaptiveLayoutManager()
    
    // MARK: - Published Properties
    
    @Published var screenSizeCategory: ScreenSizeCategory = .regular
    @Published var isDarkMode: Bool = false
    @Published var accessibilityReduceMotion: Bool = false
    @Published var accessibilityLargeText: Bool = false
    
    // MARK: - Layout Constants
    
    struct LayoutConstants {
        let windowMinWidth: CGFloat
        let windowIdealWidth: CGFloat
        let windowMaxWidth: CGFloat
        let windowMinHeight: CGFloat
        let cardPadding: CGFloat
        let cardSpacing: CGFloat
        let fontScale: CGFloat
        let iconSize: CGFloat
        let buttonSize: CGFloat
        
        static func forCategory(_ category: ScreenSizeCategory, largeText: Bool) -> LayoutConstants {
            let fontScale: CGFloat = largeText ? 1.2 : 1.0
            
            switch category {
            case .compact:
                return LayoutConstants(
                    windowMinWidth: 360,
                    windowIdealWidth: 400,
                    windowMaxWidth: 480,
                    windowMinHeight: 520,
                    cardPadding: 16,
                    cardSpacing: 12,
                    fontScale: fontScale * 0.9,
                    iconSize: 36,
                    buttonSize: 64
                )
            case .regular:
                return LayoutConstants(
                    windowMinWidth: 420,
                    windowIdealWidth: 460,
                    windowMaxWidth: 520,
                    windowMinHeight: 580,
                    cardPadding: 20,
                    cardSpacing: 16,
                    fontScale: fontScale,
                    iconSize: 40,
                    buttonSize: 72
                )
            case .large:
                return LayoutConstants(
                    windowMinWidth: 480,
                    windowIdealWidth: 520,
                    windowMaxWidth: 600,
                    windowMinHeight: 640,
                    cardPadding: 24,
                    cardSpacing: 20,
                    fontScale: fontScale * 1.1,
                    iconSize: 44,
                    buttonSize: 80
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var layoutConstants: LayoutConstants {
        LayoutConstants.forCategory(screenSizeCategory, largeText: accessibilityLargeText)
    }
    
    // MARK: - Initialization
    
    private init() {
        updateScreenCategory()
        updateAppearance()
        updateAccessibility()
        setupObservers()
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // 监听屏幕变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // 监听外观变化
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceDidChange),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
        
        // 监听辅助功能变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityDidChange),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func screenDidChange() {
        updateScreenCategory()
    }
    
    @objc private func appearanceDidChange() {
        updateAppearance()
    }
    
    @objc private func accessibilityDidChange() {
        updateAccessibility()
    }
    
    private func updateScreenCategory() {
        guard let screen = NSScreen.main else { return }
        let width = screen.visibleFrame.width
        let newCategory = ScreenSizeCategory(width: width)
        
        if newCategory != screenSizeCategory {
            screenSizeCategory = newCategory
            LoggerService.shared.info("Screen category updated: \(newCategory.rawValue) (width: \(Int(width))px)")
        }
    }
    
    private func updateAppearance() {
        let newIsDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if newIsDarkMode != isDarkMode {
            isDarkMode = newIsDarkMode
            LoggerService.shared.info("Dark mode updated: \(newIsDarkMode)")
        }
    }
    
    private func updateAccessibility() {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let largeText = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        
        if reduceMotion != accessibilityReduceMotion {
            accessibilityReduceMotion = reduceMotion
            LoggerService.shared.info("Reduce motion updated: \(reduceMotion)")
        }
        
        // 检测大字体设置（通过系统字体大小）
        let fontSize = NSFont.systemFontSize
        let isLargeText = fontSize > 13
        if isLargeText != accessibilityLargeText {
            accessibilityLargeText = isLargeText
            LoggerService.shared.info("Large text updated: \(isLargeText)")
        }
    }
}

// MARK: - View Extensions

extension View {
    /// 应用自适应布局修饰符
    func adaptiveLayout() -> some View {
        modifier(AdaptiveLayoutModifier())
    }
}

struct AdaptiveLayoutModifier: ViewModifier {
    @StateObject private var layoutManager = AdaptiveLayoutManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.layoutConstants, layoutManager.layoutConstants)
            .environment(\.isDarkMode, layoutManager.isDarkMode)
            .environment(\.reduceMotion, layoutManager.accessibilityReduceMotion)
    }
}

// MARK: - Environment Keys

private struct LayoutConstantsKey: EnvironmentKey {
    static let defaultValue = AdaptiveLayoutManager.LayoutConstants.forCategory(.regular, largeText: false)
}

private struct IsDarkModeKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var layoutConstants: AdaptiveLayoutManager.LayoutConstants {
        get { self[LayoutConstantsKey.self] }
        set { self[LayoutConstantsKey.self] = newValue }
    }
    
    var isDarkMode: Bool {
        get { self[IsDarkModeKey.self] }
        set { self[IsDarkModeKey.self] = newValue }
    }
    
    var reduceMotion: Bool {
        get { self[ReduceMotionKey.self] }
        set { self[ReduceMotionKey.self] = newValue }
    }
}

// MARK: - Font Extensions

extension Font {
    /// 自适应字体大小
    static func adaptive(_ size: CGFloat, layoutConstants: AdaptiveLayoutManager.LayoutConstants) -> Font {
        .system(size: size * layoutConstants.fontScale)
    }
}
