//
//  NTPServer.swift
//  YumikoToys
//
//  NTP 服务器配置模型
//

import Foundation

/// NTP 服务器预设
enum NTPServerPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case apple = "time.apple.com"
    case appleAsia = "time.asia.apple.com"
    case cnPool = "cn.pool.ntp.org"
    case aliyun = "ntp.aliyun.com"
    case tencent = "ntp.tencentcloud.com"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .apple: return "🍎 Apple 全球"
        case .appleAsia: return "🍎 Apple 亚洲"
        case .cnPool: return "🇨🇳 中国 NTP 池"
        case .aliyun: return "☁️ 阿里云"
        case .tencent: return "☁️ 腾讯云"
        case .custom: return "🔧 自定义"
        }
    }
    
    var description: String {
        switch self {
        case .apple: return "Apple 官方 NTP 服务器"
        case .appleAsia: return "Apple 亚洲区域服务器"
        case .cnPool: return "中国 NTP 服务器池"
        case .aliyun: return "阿里云 NTP 服务"
        case .tencent: return "腾讯云 NTP 服务"
        case .custom: return "自定义 NTP 服务器地址"
        }
    }
    
    /// 获取服务器地址列表
    var servers: [String] {
        switch self {
        case .apple:
            return ["time.apple.com"]
        case .appleAsia:
            return ["time.asia.apple.com"]
        case .cnPool:
            return ["cn.pool.ntp.org"]
        case .aliyun:
            return ["ntp.aliyun.com", "ntp1.aliyun.com", "ntp2.aliyun.com"]
        case .tencent:
            return ["ntp.tencentcloud.com", "time1.cloud.tencent.com"]
        case .custom:
            return [] // 自定义服务器需要单独设置
        }
    }
    
    /// 是否需要代理（国内服务器通常不需要）
    var mayNeedProxy: Bool {
        switch self {
        case .apple, .appleAsia:
            return true
        case .cnPool, .aliyun, .tencent, .custom:
            return false
        }
    }
}

/// NTP 配置
struct NTPConfiguration: Codable, Sendable {
    var selectedPreset: NTPServerPreset
    var customServer: String?
    var useProxy: Bool
    var proxyHost: String?
    var proxyPort: Int?
    
    init(
        selectedPreset: NTPServerPreset = .aliyun,
        customServer: String? = nil,
        useProxy: Bool = false,
        proxyHost: String? = nil,
        proxyPort: Int? = nil
    ) {
        self.selectedPreset = selectedPreset
        self.customServer = customServer
        self.useProxy = useProxy
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
    }
    
    /// 获取当前配置的服务器列表
    var currentServers: [String] {
        if selectedPreset == .custom, let custom = customServer, !custom.isEmpty {
            return [custom]
        }
        return selectedPreset.servers
    }
    
    static let `default` = NTPConfiguration()
}
