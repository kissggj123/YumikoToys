//
//  FontManager.swift
//  YumikoToys
//
//  字体管理器 - 管理可爱字体加载和应用
//

import SwiftUI
import CoreText
import AppKit

/// 字体管理器
final class FontManager: @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = FontManager()
    
    // MARK: - Properties
    
    /// 可爱字体名称
    private(set) var cuteFontName: String = "AaGXLZGKADS"
    
    /// 字体是否已加载
    private(set) var isFontLoaded: Bool = false
    
    /// 线程安全锁
    private let lock = NSRecursiveLock()
    
    /// 当前启用的字体类型和参数
    private var activeFont: AppFont = .cute
    private var activeCustomFontPath: String?
    private var activeSystemFontFamily: String?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 注册字体并开启 swizzling
    func registerFonts() {
        // 触发 NSFont 方法的 swizzling
        _ = NSFont.swizzleSystemFont
        
        // 尝试从 Bundle 中加载可爱字体
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
    
    /// 更新当前活跃的字体设置（线程安全）
    func updateActiveFont(type: AppFont, customPath: String?, systemFamily: String?) {
        lock.lock()
        self.activeFont = type
        self.activeCustomFontPath = customPath
        self.activeSystemFontFamily = systemFamily
        lock.unlock()
        
        // 如果是外部自定义字体，则静默注册该字体
        if type == .custom, let path = customPath {
            _ = registerCustomFont(atPath: path)
        }
        
        LoggerService.shared.info("FontManager active font updated to: \(type.rawValue)")
    }
    
    /// 获取当前生效的 Font 字体
    func currentFont(size: CGFloat) -> Font {
        lock.lock()
        let type = activeFont
        let customPath = activeCustomFontPath
        let systemFamily = activeSystemFontFamily
        lock.unlock()
        
        switch type {
        case .system:
            return .system(size: size)
        case .cute:
            if isFontLoaded {
                return .custom(cuteFontName, size: size)
            }
            return .system(size: size)
        case .systemCustom:
            if let family = systemFamily {
                return .custom(family, size: size)
            }
            return .system(size: size)
        case .custom:
            if let customPath = customPath,
               let fontName = registerCustomFont(atPath: customPath) {
                return .custom(fontName, size: size)
            }
            return .system(size: size)
        }
    }
    
    /// 兼容旧代码：获取可爱/当前生效的 Font
    func cuteFont(size: CGFloat) -> Font {
        return currentFont(size: size)
    }
    
    /// 兼容旧代码：获取可爱/当前生效的 NSFont
    func cuteNSFont(size: CGFloat) -> NSFont {
        return resolveActiveNSFont(size: size, weight: .regular)
    }
    
    /// 动态解析当前活跃的 NSFont（用于 swizzling 拦截）
    func resolveActiveNSFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        lock.lock()
        let type = activeFont
        let customPath = activeCustomFontPath
        let systemFamily = activeSystemFontFamily
        lock.unlock()
        
        switch type {
        case .system:
            return NSFont.customSystemFont(ofSize: size, weight: weight)
        case .cute:
            if isFontLoaded, let font = NSFont(name: cuteFontName, size: size) {
                return font
            }
            return NSFont.customSystemFont(ofSize: size, weight: weight)
        case .systemCustom:
            if let family = systemFamily, let font = NSFont(name: family, size: size) {
                return font
            }
            return NSFont.customSystemFont(ofSize: size, weight: weight)
        case .custom:
            if let customPath = customPath,
               let fontName = registerCustomFont(atPath: customPath),
               let font = NSFont(name: fontName, size: size) {
                return font
            }
            return NSFont.customSystemFont(ofSize: size, weight: weight)
        }
    }
    
    /// 注册外部自定义字体文件
    func registerCustomFont(atPath path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        return registerCustomFont(at: url)
    }
    
    func registerCustomFont(at url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(dataProvider) else {
            return nil
        }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        
        if let fontName = cgFont.postScriptName as String? {
            if success {
                LoggerService.shared.info("✅ Registered custom font: \(fontName)")
            }
            return fontName
        }
        return nil
    }
    
    // MARK: - Private Methods
    
    private func registerFont(at url: URL) {
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        
        if success {
            if NSFont(name: cuteFontName, size: 12) != nil {
                isFontLoaded = true
                LoggerService.shared.info("✅ Cute font registered successfully: \(cuteFontName)")
            }
        } else {
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
    /// 可爱/当前全局生效字体
    static func cute(_ size: CGFloat) -> Font {
        FontManager.shared.currentFont(size: size)
    }
}

// MARK: - NSFont Extension

extension NSFont {
    /// 可爱/当前全局生效字体
    static func cute(_ size: CGFloat) -> NSFont {
        FontManager.shared.resolveActiveNSFont(size: size, weight: .regular)
    }
    
    // MARK: - Method Swizzling for Global Font Settings
    
    static let swizzleSystemFont: Void = {
        let originalSelector = #selector(NSFont.systemFont(ofSize:))
        let swizzledSelector = #selector(NSFont.customSystemFont(ofSize:))
        if let originalMethod = class_getClassMethod(NSFont.self, originalSelector),
           let swizzledMethod = class_getClassMethod(NSFont.self, swizzledSelector) {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
        
        let originalWeightSelector = #selector(NSFont.systemFont(ofSize:weight:))
        let swizzledWeightSelector = #selector(NSFont.customSystemFont(ofSize:weight:))
        if let originalWeightMethod = class_getClassMethod(NSFont.self, originalWeightSelector),
           let swizzledWeightMethod = class_getClassMethod(NSFont.self, swizzledWeightSelector) {
            method_exchangeImplementations(originalWeightMethod, swizzledWeightMethod)
        }
        
        let originalBoldSelector = #selector(NSFont.boldSystemFont(ofSize:))
        let swizzledBoldSelector = #selector(NSFont.customBoldSystemFont(ofSize:))
        if let originalBoldMethod = class_getClassMethod(NSFont.self, originalBoldSelector),
           let swizzledBoldMethod = class_getClassMethod(NSFont.self, swizzledBoldSelector) {
            method_exchangeImplementations(originalBoldMethod, swizzledBoldMethod)
        }
    }()
    
    @objc class func customSystemFont(ofSize size: CGFloat) -> NSFont {
        return FontManager.shared.resolveActiveNSFont(size: size, weight: .regular)
    }
    
    @objc class func customSystemFont(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        return FontManager.shared.resolveActiveNSFont(size: size, weight: weight)
    }
    
    @objc class func customBoldSystemFont(ofSize size: CGFloat) -> NSFont {
        return FontManager.shared.resolveActiveNSFont(size: size, weight: .bold)
    }
}

// MARK: - Poke Integration Service

final class PokeService: @unchecked Sendable {
    static let shared = PokeService()
    
    private let lock = NSRecursiveLock()
    private var enablePoke = false
    private var pokeApiKey = ""
    
    private init() {}
    
    /// 更新 Poke 设置（线程安全）
    func updatePokeSettings(enablePoke: Bool, apiKey: String?) {
        lock.lock()
        self.enablePoke = enablePoke
        self.pokeApiKey = apiKey ?? ""
        lock.unlock()
        
        LoggerService.shared.info("PokeService settings updated: enabled=\(enablePoke)")
    }
    
    /// 向 Poke 平台同步一条消息 (Fire and Forget)
    func sendMessage(_ message: String) {
        lock.lock()
        let enabled = enablePoke
        let apiKey = pokeApiKey
        lock.unlock()
        
        guard enabled, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        guard let url = URL(string: "https://poke.com/api/v1/inbound-sms/webhook") else {
            LoggerService.shared.error("Invalid Poke URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["message": message]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            LoggerService.shared.error("Failed to serialize Poke request body")
            return
        }
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                LoggerService.shared.error("Failed to send message to Poke: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    LoggerService.shared.info("Successfully synchronized message to Poke")
                } else {
                    LoggerService.shared.warning("Poke API returned non-200 status code: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
}
