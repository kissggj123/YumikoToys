//
//  Color+Hex.swift
//  YumikoToys
//
//  Color Hex 扩展，支持 3/6/8 位十六进制颜色值
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// 转换为 Hex 字符串
    func toHex() -> String? {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) ?? nsColor.usingColorSpace(.deviceRGB) else {
            return nil
        }
        let r = Int(round(max(0, min(1, rgbColor.redComponent)) * 255.0))
        let g = Int(round(max(0, min(1, rgbColor.greenComponent)) * 255.0))
        let b = Int(round(max(0, min(1, rgbColor.blueComponent)) * 255.0))
        return String(format: "%02X%02X%02X", r, g, b)
    }
    
    /// 比较两个十六进制颜色值是否足够接近（用于打破颜色空间转换引起的微小偏差循环）
    static func isHexClose(_ hex1: String, _ hex2: String) -> Bool {
        let h1 = hex1.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let h2 = hex2.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard h1.count == 6, h2.count == 6 else { return false }
        
        var int1: UInt64 = 0
        var int2: UInt64 = 0
        let s1 = Scanner(string: h1)
        let s2 = Scanner(string: h2)
        guard s1.scanHexInt64(&int1), s2.scanHexInt64(&int2) else { return false }
        
        let r1 = Int((int1 >> 16) & 0xFF)
        let g1 = Int((int1 >> 8) & 0xFF)
        let b1 = Int(int1 & 0xFF)
        
        let r2 = Int((int2 >> 16) & 0xFF)
        let g2 = Int((int2 >> 8) & 0xFF)
        let b2 = Int(int2 & 0xFF)
        
        return abs(r1 - r2) <= 2 && abs(g1 - g2) <= 2 && abs(b1 - b2) <= 2
    }
}
