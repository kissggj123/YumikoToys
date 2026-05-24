//
//  FontManager.swift
//  YumikoToys
//
//  字体管理器 - 管理可爱字体加载和应用
//

import SwiftUI
import CoreText

/// 字体管理器
final class FontManager {
    
    // MARK: - Singleton
    
    static let shared = FontManager()
    
    // MARK: - Properties
    
    /// 可爱字体名称
    private(set) var cuteFontName: String = "AaGXLZGKADS"
    
    /// 字体是否已加载
    private(set) var isFontLoaded: Bool = false
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 注册字体
    func registerFonts() {
        // 尝试从 Bundle 中加载字体
        guard let fontURL = Bundle.main.url(forResource: "AaGXLZGKADS", withExtension: "ttf") else {
            LoggerService.shared.warning("Font file not found in bundle")
            // 尝试从 Resources 目录加载
            let resourcePath = Bundle.main.resourcePath ?? ""
            let fullPath = (resourcePath as NSString).appendingPathComponent("AaGXLZGKADS.ttf")
            
            if FileManager.default.fileExists(atPath: fullPath) {
                registerFont(at: URL(fileURLWithPath: fullPath))
            }
            return
        }
        
        registerFont(at: fontURL)
    }
    
    /// 获取可爱字体
    func cuteFont(size: CGFloat) -> Font {
        if isFontLoaded {
            return .custom(cuteFontName, size: size)
        } else {
            return .system(size: size)
        }
    }
    
    /// 获取可爱 NSFont
    func cuteNSFont(size: CGFloat) -> NSFont {
        if isFontLoaded, let font = NSFont(name: cuteFontName, size: size) {
            return font
        } else {
            return .systemFont(ofSize: size)
        }
    }
    
    // MARK: - Private Methods
    
    private func registerFont(at url: URL) {
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        
        if success {
            // 直接尝试创建字体来验证
            if NSFont(name: cuteFontName, size: 12) != nil {
                isFontLoaded = true
                LoggerService.shared.info("✅ Cute font registered successfully: \(cuteFontName)")
            }
        } else {
            // 检查字体是否已存在（可能之前已注册）
            if NSFont(name: cuteFontName, size: 12) != nil {
                isFontLoaded = true
                LoggerService.shared.info("✅ Font already registered: \(cuteFontName)")
            } else if let error = error?.takeRetainedValue() {
                let errorDescription = CFErrorCopyDescription(error) as String? ?? "Unknown error"
                LoggerService.shared.error("❌ Failed to register font: \(errorDescription)")
            }
        }
    }
}

// MARK: - Font Extension

extension Font {
    /// 可爱字体
    static func cute(_ size: CGFloat) -> Font {
        FontManager.shared.cuteFont(size: size)
    }
}

// MARK: - NSFont Extension

extension NSFont {
    /// 可爱字体
    static func cute(_ size: CGFloat) -> NSFont {
        FontManager.shared.cuteNSFont(size: size)
    }
}
