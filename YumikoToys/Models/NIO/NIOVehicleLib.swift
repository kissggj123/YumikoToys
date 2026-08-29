//
//  NIOVehicleLib.swift
//  YumikoToys
//
//  RVS 归一化 + 车辆数据工具函数 + 动态签名 + 轨迹计算（从 NIO-Dash 重写）
//

import Foundation
import CryptoKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - 智能解析返回结果

struct NIOSmartParseResult {
    var mode: String?              // "url" | "widget"
    var vehicleURL: String?
    var vehicleToken: String?
    var vehicleId: String?
    var deviceId: String?
    var sign: String?
    var timestamp: String?
    var changeURL: String?
    var changeToken: String?
    var checkinURL: String?
    var checkinToken: String?
    var notes: [String] = []
}

enum NIOVehicleLib {

    static let widgetBaseURL = "https://app.nio.com/app/api/icar/v2/widget/info"

    // MARK: - GPS 校验

    static func isValidGPS(lat: Double, lng: Double) -> Bool {
        guard lat.isFinite, lng.isFinite else { return false }
        return !(abs(lat) < 0.01 && abs(lng) < 0.01)
    }

    // MARK: - MD5 签名计算

    static func md5(_ text: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func sortedQuery(_ params: [String: String]) -> String {
        params.keys.sorted().map { key in
            "\(key)=\(params[key] ?? "")"
        }.joined(separator: "&")
    }

    static func computeWidgetSign(params: [String: String], secret: String, algo: String = "md5_append") -> String {
        let base = sortedQuery(params)
        switch algo {
        case "md5_prepend":
            return md5(secret + base)
        case "md5_append_key":
            return md5("\(base)&key=\(secret)")
        case "md5_append":
            fallthrough
        default:
            return md5(base + secret)
        }
    }

    // MARK: - 动态 Widget URL 构建

    static func buildWidgetURL(
        vehicleId: String,
        deviceId: String,
        secret: String?,
        algo: String = "md5_append",
        fixedSign: String? = nil,
        fixedTimestamp: String? = nil,
        appVer: String = "6.5.3",
        region: String = "cn",
        lang: String = "zh-CN",
        appId: String = "10002",
        functions: String = "rvs_run_frequent_appointment,rvs_set_defender_mode,rvs_rpa_out,rvs_exe_findme",
        size: String = "medium"
    ) -> (url: URL, timestamp: String, sign: String)? {
        guard !vehicleId.isEmpty, !deviceId.isEmpty else { return nil }

        var params: [String: String] = [
            "region": region,
            "app_id": appId,
            "lang": lang,
            "vehicle_id": vehicleId,
            "app_ver": appVer,
            "device_id": deviceId,
            "widget_functions": functions,
            "widget_size": size
        ]

        let currentTs = fixedTimestamp?.isEmpty == false ? fixedTimestamp! : String(Int(Date().timeIntervalSince1970))
        params["timestamp"] = currentTs

        let signValue: String
        if let sec = secret, !sec.isEmpty {
            signValue = computeWidgetSign(params: params, secret: sec, algo: algo)
        } else if let fs = fixedSign, !fs.isEmpty {
            signValue = fs
        } else {
            return nil
        }
        params["sign"] = signValue

        var components = URLComponents(string: widgetBaseURL)
        components?.queryItems = params.keys.sorted().map { URLQueryItem(name: $0, value: params[$0]) }
        guard let url = components?.url else { return nil }
        return (url, currentTs, signValue)
    }

    // MARK: - 智能 URL / cURL 解析器

    static func smartParseInput(_ input: String) -> NIOSmartParseResult {
        var res = NIOSmartParseResult()
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return res }

        // 0. 支持直接粘贴 auto_sniff 生成的 JSON 格式
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
            if let data = trimmed.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let vUrl = json["vehicle_url"] as? String, !vUrl.isEmpty { res.vehicleURL = vUrl }
                if let vTok = json["vehicle_token"] as? String, !vTok.isEmpty {
                    res.vehicleToken = vTok.replacingOccurrences(of: "Bearer ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let vId = json["vehicle_id"] as? String, !vId.isEmpty { res.vehicleId = vId }
                if let dId = json["device_id"] as? String, !dId.isEmpty { res.deviceId = dId }
                if let s = json["sign"] as? String, !s.isEmpty { res.sign = s }
                if let ts = json["timestamp"] as? String, !ts.isEmpty { res.timestamp = ts }
                if let mode = json["mode"] as? String, !mode.isEmpty { res.mode = mode }
                if let cUrl = json["change_url"] as? String, !cUrl.isEmpty { res.changeURL = cUrl }
                if let kUrl = json["checkin_url"] as? String, !kUrl.isEmpty { res.checkinURL = kUrl }
            }
        }

        // 1. 尝试抽取 Authorization Bearer Token (支持 base64 中的 +, /, =)
        if res.vehicleToken == nil || res.vehicleToken?.isEmpty == true {
            if let match = trimmed.range(of: #"(?:Bearer\s+|Authorization:\s*Bearer\s*|\"vehicle_token\":\s*\"(?:Bearer\s*)?)([A-Za-z0-9\-_./+=]+)"#, options: .regularExpression) {
                let tokenSubstring = trimmed[match]
                let cleanToken = tokenSubstring
                    .replacingOccurrences(of: "Authorization:", with: "")
                    .replacingOccurrences(of: "Bearer", with: "")
                    .replacingOccurrences(of: "\"vehicle_token\":", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanToken.isEmpty {
                    res.vehicleToken = cleanToken
                    res.notes.append("已自动提取 Bearer Token")
                }
            }
        }

        // 2. 检查是否为完整 URL / cURL
        let urlStrings = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
        for rawUrl in urlStrings {
            let initialUrl = rawUrl.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`,;"))
            guard let components = URLComponents(string: initialUrl) else { continue }
            let path = components.path.lowercased()
            let host = components.host?.lowercased() ?? ""

            // 无论任何接口，尝试从路径中抽取 /vehicle/{vid}/status
            if res.vehicleId == nil || res.vehicleId?.isEmpty == true {
                if components.path.contains("/vehicle/") {
                    let parts = components.path.components(separatedBy: "/vehicle/")
                    if parts.count > 1 {
                        let candidate = parts[1].components(separatedBy: "/")[0]
                        if !candidate.isEmpty {
                            res.vehicleId = candidate
                        }
                    }
                }
            }

            // 从 queryItems 中抽取 device_id, vehicle_id, sign, timestamp
            if let items = components.queryItems {
                for item in items {
                    switch item.name.lowercased() {
                    case "vehicle_id", "vehicleid", "vid":
                        if res.vehicleId == nil || res.vehicleId?.isEmpty == true {
                            res.vehicleId = item.value
                        }
                    case "device_id", "deviceid", "did":
                        if res.deviceId == nil || res.deviceId?.isEmpty == true {
                            res.deviceId = item.value
                        }
                    case "sign":
                        if res.sign == nil || res.sign?.isEmpty == true {
                            res.sign = item.value
                        }
                    case "timestamp", "ts":
                        if res.timestamp == nil || res.timestamp?.isEmpty == true {
                            res.timestamp = item.value
                        }
                    default: break
                    }
                }
            }

            var normalizedComponents = components
            // 自动修复抓包抓到直连 IP (如 101.42.114.130) 导致的 HTTPS TLS 证书域名不匹配问题
            if !host.contains("nio.com") {
                if path.contains("rvs") || path.contains("status") {
                    normalizedComponents.host = "icar.nio.com"
                    normalizedComponents.scheme = "https"
                } else if path.contains("widget") || path.contains("charge") || path.contains("checkin") || path.contains("order") {
                    normalizedComponents.host = "app.nio.com"
                    normalizedComponents.scheme = "https"
                }
            }
            let cleanUrl = normalizedComponents.url?.absoluteString ?? rawUrl.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`,;"))

            if path.contains("widget") || host.contains("app.nio.com") {
                res.vehicleURL = cleanUrl
                if res.mode == nil { res.mode = "widget" }
                res.notes.append("识别到车辆 Widget 接口，已提取 vehicle_id 与 device_id")
            } else if path.contains("rvs/vehicle") || path.contains("status") || host.contains("icar.nio.com") {
                res.vehicleURL = cleanUrl
                if res.mode == nil { res.mode = "url" }
                res.notes.append("识别到车辆 RVS 状态接口，已提取 Vehicle ID 与 Device ID")
            } else if path.contains("gettaborder") || path.contains("serviceorder") || path.contains("service-order") {
                res.changeURL = cleanUrl
                res.notes.append("识别到换电 / 服务订单接口")
            } else if path.contains("award/square") || path.contains("checkin") {
                res.checkinURL = cleanUrl
                res.notes.append("识别到签到接口")
            }
        }

        // 3. 纯 Token 粘贴容错
        if res.vehicleURL == nil && res.changeURL == nil && res.checkinURL == nil {
            if trimmed.hasPrefix("eyJ") || trimmed.count > 40 {
                let token = trimmed.replacingOccurrences(of: "Bearer ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                res.vehicleToken = token
                res.notes.append("识别为纯 Token 文本")
            }
        }

        return res
    }

    /// 从 URL 字符串中提取指定 Query 参数（纯文本匹配，避免 URLComponents 重新编解码破坏签名）
    static func extractQueryParam(from urlString: String, key: String) -> String? {
        guard let queryStart = urlString.firstIndex(of: "?") else { return nil }
        let queryString = String(urlString[urlString.index(after: queryStart)...])
        let pairs = queryString.split(separator: "&")
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count >= 2, parts[0] == key {
                return String(parts[1])
            }
        }
        return nil
    }

    // MARK: - 路径测距与按天轨迹计算

    static func segmentMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let r = 6371000.0 // 地球半径（米）
        let toRad = { (d: Double) in d * .pi / 180.0 }
        let dLat = toRad(lat2 - lat1)
        let dLng = toRad(lng2 - lng1)
        let a = sin(dLat / 2.0) * sin(dLat / 2.0) +
                cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLng / 2.0) * sin(dLng / 2.0)
        return 2.0 * r * asin(min(1.0, sqrt(a)))
    }

    static func buildDailyPaths(history: [NIOVehicleSnapshot]) -> [NIODailyPath] {
        let validPoints = history.filter { $0.isValidGPS && $0.ts > 0 }
        guard !validPoints.isEmpty else { return [] }

        var byDay: [String: [NIOVehicleSnapshot]] = [:]
        let cal = Calendar.current
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "yyyy-MM-dd"

        let labelFmt = DateFormatter()
        labelFmt.locale = Locale(identifier: "zh_CN")
        labelFmt.dateFormat = "MM月dd日 EEE"

        for snap in validPoints {
            let date = Date(timeIntervalSince1970: TimeInterval(snap.ts) / 1000.0)
            let key = dayFmt.string(from: date)
            byDay[key, default: []].append(snap)
        }

        var results: [NIODailyPath] = []
        for (dayKey, points) in byDay {
            let sorted = points.sorted { $0.ts < $1.ts }
            var distance = 0.0
            if sorted.count > 1 {
                for i in 0..<(sorted.count - 1) {
                    let m = segmentMeters(lat1: sorted[i].lat, lng1: sorted[i].lng, lat2: sorted[i+1].lat, lng2: sorted[i+1].lng)
                    if m > 10.0 { // 过滤微小漂移
                        distance += m
                    }
                }
            }
            let firstDate = Date(timeIntervalSince1970: TimeInterval(sorted.first?.ts ?? 0) / 1000.0)
            let label = labelFmt.string(from: firstDate)
            results.append(NIODailyPath(
                day: dayKey,
                label: label,
                points: sorted,
                distanceKm: distance / 1000.0,
                startTime: sorted.first?.ts ?? 0,
                endTime: sorted.last?.ts ?? 0
            ))
        }

        return results.sorted { $0.day > $1.day }
    }

    static func computeDailyMileageDeltas(history: [NIOVehicleSnapshot]) -> [NIODailyDelta] {
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "yyyy-MM-dd"

        let labelFmt = DateFormatter()
        labelFmt.locale = Locale(identifier: "zh_CN")
        labelFmt.dateFormat = "MM/dd"

        var byDay: [String: [NIOVehicleSnapshot]] = [:]
        for snap in history where snap.mileage > 0 && snap.ts > 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(snap.ts) / 1000.0)
            let key = dayFmt.string(from: date)
            byDay[key, default: []].append(snap)
        }

        var results: [NIODailyDelta] = []
        for (day, points) in byDay {
            let sorted = points.sorted { $0.ts < $1.ts }
            if let first = sorted.first, let last = sorted.last {
                let diff = max(0.0, last.mileage - first.mileage)
                let date = Date(timeIntervalSince1970: TimeInterval(first.ts) / 1000.0)
                results.append(NIODailyDelta(day: day, label: labelFmt.string(from: date), delta: diff))
            }
        }
        return results.sorted { $0.day < $1.day }
    }

    // MARK: - 标签与格式化函数

    static func vehicleStateLabel(_ state: Int) -> String {
        switch state {
        case 0: return "未知"
        case 1: return "行驶中"
        case 2: return "已驻车"
        case 3: return "充电中"
        case 4: return "换电中"
        default: return "状态\(state)"
        }
    }

    static func isRealCharging(socStatus: NIOSocStatus?, offcarStatus: [String: NIOJSONValue]?) -> Bool {
        let chargeState = socStatus?.chargeState ?? 0
        guard chargeState == 1 else { return false }

        // 露营模式排查：开启露营模式时，车辆维持座舱放电，非插枪充电
        if let offcar = offcarStatus {
            let camping = modeActive(offcar["camping_mode_status"] ?? offcar["camping_mode"])
            if camping { return false }

            let powerHold = modeActive(offcar["power_hold_mode_status"] ?? offcar["power_hold_mode"])
            if powerHold && (socStatus?.chargerType ?? 0) == 0 {
                return false
            }
        }

        // 对外放电（V2L）排查
        if let v2l = socStatus?.v2lStatus, v2l == 1 {
            return false
        }

        return true
    }

    static func smartChargeStateDescription(socStatus: NIOSocStatus?, offcarStatus: [String: NIOJSONValue]?) -> String {
        if let offcar = offcarStatus {
            let camping = modeActive(offcar["camping_mode_status"] ?? offcar["camping_mode"])
            if camping { return "露营模式 ⛺️" }

            let powerHold = modeActive(offcar["power_hold_mode_status"] ?? offcar["power_hold_mode"])
            if powerHold && (socStatus?.chargerType ?? 0) == 0 {
                return "离车不下电 🔋"
            }
        }

        if let v2l = socStatus?.v2lStatus, v2l == 1 {
            return "对外放电 ⚡️"
        }

        let state = socStatus?.chargeState ?? 0
        switch state {
        case 0: return "未充电"
        case 1: return "充电中 ⚡️"
        case 2: return "充电完成 🌸"
        case 3: return "充电故障 ⚠️"
        default: return "状态\(state)"
        }
    }

    static func chargeStateLabel(_ state: Int) -> String {
        switch state {
        case 0: return "未充电"
        case 1: return "充电中"
        case 2: return "充电完成"
        case 3: return "充电故障"
        default: return "状态\(state)"
        }
    }

    /// GCJ-02 火星坐标转 WGS-84（解决地图几百米偏差问题，移植自 ha-nio）
    static func gcj02ToWgs84(lat: Double, lng: Double) -> (lat: Double, lng: Double) {
        let pi = Double.pi
        let a = 6378245.0
        let ee = 0.00669342162296594323

        func transformLat(x: Double, y: Double) -> Double {
            var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
            ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
            ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0
            ret += (160.0 * sin(y / 12.0 * pi) + 320.0 * sin(y * pi / 30.0)) * 2.0 / 3.0
            return ret
        }

        func transformLng(x: Double, y: Double) -> Double {
            var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
            ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0
            ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0
            ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0
            return ret
        }

        var dLat = transformLat(x: lng - 105.0, y: lat - 35.0)
        var dLng = transformLng(x: lng - 105.0, y: lat - 35.0)
        let radLat = lat / 180.0 * pi
        var magic = sin(radLat)
        magic = 1.0 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1.0 - ee)) / (magic * sqrtMagic) * pi)
        dLng = (dLng * 180.0) / (a / sqrtMagic * cos(radLat) * pi)
        return (lat: lat - dLat, lng: lng - dLng)
    }

    /// 续航达成率推算（实际估算 / 标准续航，返回如 79.5 表示 79.5%）
    static func rangeAchievementRatio(actual: Double?, standard: Double?) -> Double? {
        guard let s = standard, s > 0 else { return nil }
        if let a = actual, a > 0 {
            return (a / s) * 100.0
        }
        // 当车机休眠未上报 actual 时，采用 CLTC 推算实估 (0.795)
        let estimated = Double(cltcToEstimatedRange(s))
        return (estimated / s) * 100.0
    }

    static func chargerTypeLabel(_ type: Int) -> String {
        switch type {
        case 1: return "直流快充"
        case 2: return "交流慢充"
        case 3: return "超充桩"
        default: return type > 0 ? "充电类型\(type)" : "未接入"
        }
    }

    static func windowPosLabel(_ val: Int) -> String {
        switch val {
        case 1: return "全关"
        case 2: return "微开"
        case 3: return "半开"
        case 4: return "全开"
        default: return val == 0 ? "全关" : "\(val)%"
        }
    }

    static func vehlModeLabel(_ val: Int) -> String {
        switch val {
        case 1: return "运动"
        case 2: return "经济"
        case 3: return "舒适"
        case 4: return "运动+"
        case 5: return "自定义"
        default: return "标准"
        }
    }

    static func doorLabel(closed: Int) -> String {
        closed == 1 ? "关闭" : "开启"
    }

    static func heatLevelLabel(_ sts: Int) -> String {
        if sts <= 0 { return "关闭" }
        if sts == 1 { return "低" }
        if sts == 2 { return "中" }
        return "高"
    }

    struct TyreWheelInfo {
        var press: Double?
        var temp: Int?

        var displayPress: String {
            guard let p = press else { return "—" }
            if p > 50 {
                return String(format: "%.1f bar", p / 100.0)
            } else if p > 10 {
                return String(format: "%.1f bar", p / 10.0)
            } else {
                return String(format: "%.1f bar", p)
            }
        }

        var displayTemp: String {
            guard let t = temp else { return "" }
            return "\(t)℃"
        }
    }

    struct TyreStatusInfo {
        var fl: TyreWheelInfo = .init()
        var fr: TyreWheelInfo = .init()
        var rl: TyreWheelInfo = .init()
        var rr: TyreWheelInfo = .init()
        var hasData: Bool {
            fl.press != nil || fr.press != nil || rl.press != nil || rr.press != nil ||
            fl.temp != nil || fr.temp != nil || rl.temp != nil || rr.temp != nil
        }
    }

    static func extractTyreInfo(_ block: [String: NIOJSONValue]?) -> TyreStatusInfo {
        guard let b = block, !b.isEmpty else {
            return TyreStatusInfo()
        }
        func findDouble(_ keys: [String]) -> Double? {
            for k in keys {
                if let val = b[k] {
                    if let d = val.doubleValue, d > 0 {
                        if d > 50.0 { return d / 100.0 }
                        if d > 10.0 { return d / 10.0 }
                        return d
                    }
                }
                for (bk, bv) in b {
                    if bk.caseInsensitiveCompare(k) == .orderedSame || bk.lowercased().replacingOccurrences(of: "_", with: "") == k.lowercased().replacingOccurrences(of: "_", with: "") {
                        if let d = bv.doubleValue, d > 0 {
                            if d > 50.0 { return d / 100.0 }
                            if d > 10.0 { return d / 10.0 }
                            return d
                        }
                    }
                }
            }
            return nil
        }
        func findInt(_ keys: [String]) -> Int? {
            for k in keys {
                if let val = b[k], let i = val.intValue {
                    return i
                }
                for (bk, bv) in b {
                    if bk.caseInsensitiveCompare(k) == .orderedSame || bk.lowercased().replacingOccurrences(of: "_", with: "") == k.lowercased().replacingOccurrences(of: "_", with: "") {
                        if let i = bv.intValue {
                            return i
                        }
                    }
                }
            }
            return nil
        }

        let flPress = findDouble([
            "front_left_wheel_press_bar", "front_left_wheel_press", "front_left_tire_pressure", "front_left_tire_press",
            "fl_pressure_bar", "fl_pressure", "fl_tyre_press", "fl_tire_press", "fl_wheel_press", "fl_press",
            "press_fl", "pressure_fl", "realtime_tyre_press_frnt_le", "realtime_tire_press_frnt_le", "realtime_tyre_press_fl",
            "tyre_press_fl", "tire_press_fl", "tyre_pressure_front_left", "tire_pressure_front_left", "front_left_press",
            "fl_tpms_press", "tpms_fl_press", "tpms_front_left_press", "tyre_press_front_left"
        ])
        let flTemp = findInt([
            "front_left_wheel_temp", "front_left_tire_temperature", "front_left_tire_temp", "front_left_temp",
            "fl_temp", "temp_fl", "fl_tyre_temp", "fl_tire_temp", "fl_wheel_temp",
            "realtime_tyre_temp_frnt_le", "realtime_tire_temp_frnt_le", "realtime_tyre_temp_fl",
            "tyre_temp_fl", "tire_temp_fl", "tyre_temperature_front_left", "tire_temperature_front_left",
            "fl_tpms_temp", "tpms_fl_temp"
        ])

        let frPress = findDouble([
            "front_right_wheel_press_bar", "front_right_wheel_press", "front_right_tire_pressure", "front_right_tire_press",
            "fr_pressure_bar", "fr_pressure", "fr_tyre_press", "fr_tire_press", "fr_wheel_press", "fr_press",
            "press_fr", "pressure_fr", "realtime_tyre_press_frnt_ri", "realtime_tire_press_frnt_ri", "realtime_tyre_press_fr",
            "tyre_press_fr", "tire_press_fr", "tyre_pressure_front_right", "tire_pressure_front_right", "front_right_press",
            "fr_tpms_press", "tpms_fr_press", "tpms_front_right_press", "tyre_press_front_right"
        ])
        let frTemp = findInt([
            "front_right_wheel_temp", "front_right_tire_temperature", "front_right_tire_temp", "front_right_temp",
            "fr_temp", "temp_fr", "fr_tyre_temp", "fr_tire_temp", "fr_wheel_temp",
            "realtime_tyre_temp_frnt_ri", "realtime_tire_temp_frnt_ri", "realtime_tyre_temp_fr",
            "tyre_temp_fr", "tire_temp_fr", "tyre_temperature_front_right", "tire_temperature_front_right",
            "fr_tpms_temp", "tpms_fr_temp"
        ])

        let rlPress = findDouble([
            "rear_left_wheel_press_bar", "rear_left_wheel_press", "rear_left_tire_pressure", "rear_left_tire_press",
            "rl_pressure_bar", "rl_pressure", "rl_tyre_press", "rl_tire_press", "rl_wheel_press", "rl_press",
            "press_rl", "pressure_rl", "realtime_tyre_press_re_le", "realtime_tire_press_re_le", "realtime_tyre_press_rl",
            "tyre_press_rl", "tire_press_rl", "tyre_pressure_rear_left", "tire_pressure_rear_left", "rear_left_press",
            "rl_tpms_press", "tpms_rl_press", "tpms_rear_left_press", "tyre_press_rear_left"
        ])
        let rlTemp = findInt([
            "rear_left_wheel_temp", "rear_left_tire_temperature", "rear_left_tire_temp", "rear_left_temp",
            "rl_temp", "temp_rl", "rl_tyre_temp", "rl_tire_temp", "rl_wheel_temp",
            "realtime_tyre_temp_re_le", "realtime_tire_temp_re_le", "realtime_tyre_temp_rl",
            "tyre_temp_rl", "tire_temp_rl", "tyre_temperature_rear_left", "tire_temperature_rear_left",
            "rl_tpms_temp", "tpms_rl_temp"
        ])

        let rrPress = findDouble([
            "rear_right_wheel_press_bar", "rear_right_wheel_press", "rear_right_tire_pressure", "rear_right_tire_press",
            "rr_pressure_bar", "rr_pressure", "rr_tyre_press", "rr_tire_press", "rr_wheel_press", "rr_press",
            "press_rr", "pressure_rr", "realtime_tyre_press_re_ri", "realtime_tire_press_re_ri", "realtime_tyre_press_rr",
            "tyre_press_rr", "tire_press_rr", "tyre_pressure_rear_right", "tire_pressure_rear_right", "rear_right_press",
            "rr_tpms_press", "tpms_rr_press", "tpms_rear_right_press", "tyre_press_rear_right"
        ])
        let rrTemp = findInt([
            "rear_right_wheel_temp", "rear_right_tire_temperature", "rear_right_tire_temp", "rear_right_temp",
            "rr_temp", "temp_rr", "rr_tyre_temp", "rr_tire_temp", "rr_wheel_temp",
            "realtime_tyre_temp_re_ri", "realtime_tire_temp_re_ri", "realtime_tyre_temp_rr",
            "tyre_temp_rr", "tire_temp_rr", "tyre_temperature_rear_right", "tire_temperature_rear_right",
            "rr_tpms_temp", "tpms_rr_temp"
        ])

        return TyreStatusInfo(
            fl: TyreWheelInfo(press: flPress, temp: flTemp),
            fr: TyreWheelInfo(press: frPress, temp: frTemp),
            rl: TyreWheelInfo(press: rlPress, temp: rlTemp),
            rr: TyreWheelInfo(press: rrPress, temp: rrTemp)
        )
    }

    static func extractTyreInfo(from status: NIOVehicleStatus?) -> TyreStatusInfo {
        guard let s = status else { return TyreStatusInfo() }
        let direct = extractTyreInfo(s.tyreStatus)
        if direct.hasData { return direct }

        if let maint = s.maintainStatus, let encoded = try? JSONEncoder().encode(maint), let dict = try? JSONDecoder().decode([String: NIOJSONValue].self, from: encoded) {
            let fromMaint = extractTyreInfo(dict)
            if fromMaint.hasData { return fromMaint }
        }
        return direct
    }

    static func defenderModeActive(_ offcar: [String: NIOJSONValue]?) -> (isActive: Bool, warnCount: Int) {
        guard let o = offcar else { return (false, 0) }
        let warnCount = o["defender_mode_warn_count"]?.intValue ?? 0
        if let mode = o["defender_mode"]?.intValue {
            return (mode >= 2, warnCount)
        }
        if let status = o["defender_mode_status"]?.intValue {
            return (status >= 2, warnCount)
        }
        if let b = o["defender_mode"]?.boolValue ?? o["defender_mode_status"]?.boolValue {
            return (b, warnCount)
        }
        return (false, warnCount)
    }

    static func modeActive(_ value: NIOJSONValue?, activeValue: Int = 1) -> Bool {
        guard let v = value else { return false }
        if let i = v.intValue { return i >= activeValue }
        if let b = v.boolValue { return b }
        return false
    }

    static func modeActive(_ value: Int?, activeValue: Int = 1) -> Bool {
        guard let v = value else { return false }
        return v >= activeValue
    }

    static func formatVehicleId(_ id: String?) -> String {
        guard let id = id, !id.isEmpty else { return "—" }
        if id.count <= 9 { return id }
        let start = id.prefix(4)
        let end = id.suffix(5)
        return "\(start)…\(end)"
    }

    static func fullChargeRangeKm(remainingRange: Double, soc: Double) -> Int? {
        guard soc > 0 else { return nil }
        return Int((remainingRange / soc * 100).rounded())
    }

    /// 将 CLTC 工况续航估算为实际可用续航（实估）
    /// 蔚来实测换算系数约 0.795（740km CLTC ≈ 588km 实估）
    /// 若 API 直接返回 remaining_actual_range，优先使用真实值；本函数用于无实估数据时的推算
    static func cltcToEstimatedRange(_ cltcKm: Double, factor: Double = 0.795) -> Int {
        return Int((cltcKm * factor).rounded())
    }

    /// 获取最佳可用续航：优先实估，无实估则用 CLTC 推算
    static func bestRange(cltcKm: Double?, actualKm: Double?) -> (km: Int, isEstimated: Bool)? {
        if let act = actualKm, act > 0 {
            return (Int(act.rounded()), false)
        }
        if let cltc = cltcKm, cltc > 0 {
            return (cltcToEstimatedRange(cltc), true)
        }
        return nil
    }

    static func batteryPackLabel(fullRangeKm: Int) -> String {
        // fullRangeKm 是基于 remaining_range（CLTC 工况续航）倒推的满电 CLTC 续航
        // 蔚来各电池包 CLTC 满电续航实测区间：
        // 75kWh ≈ 500~599km CLTC / 100kWh ≈ 600~849km CLTC / 150kWh ≈ 850km+
        switch fullRangeKm {
        case ..<500:
            return "（数据估算中）"
        case 500..<600:
            return "（75度电池）"
        case 600..<850:
            return "（100度电池）"
        case 850...:
            return "（150度电池）"
        default:
            return ""
        }
    }

    static func mapsUrl(lat: Double, lng: Double) -> String {
        "https://www.openstreetmap.org/?mlat=\(lat)&mlon=\(lng)#map=16/\(lat)/\(lng)"
    }

    static func fmtTime(_ ms: Int) -> String {
        guard ms > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "MM/dd HH:mm"
        return fmt.string(from: date)
    }

    static func fmtClock(_ ms: Int) -> String {
        guard ms > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    static func fmtDay(_ ms: Int) -> String {
        guard ms > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "MM/dd"
        return fmt.string(from: date)
    }

    struct FotaDisplayInfo {
        let osName: String
        let shortVer: String
        let fullDisplay: String
        let rawVersion: String
    }

    static func parseFotaInfo(version: String?, model: String? = nil) -> FotaDisplayInfo {
        let raw = version?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var os = ""

        // 优先匹配 Cedar S，再匹配 Cedar，以及 Banyan, Alder, Aspen, Coconut, SkyOS, Pine 等
        let osCandidates = ["Cedar S", "Cedar_S", "Cedar-S", "Cedar", "Banyan", "Alder", "Aspen", "Coconut", "SkyOS", "Pine"]
        for candidate in osCandidates {
            if raw.localizedCaseInsensitiveContains(candidate) {
                if candidate.hasPrefix("Cedar") {
                    os = candidate.contains("S") ? "Cedar S" : "Cedar"
                } else {
                    os = candidate
                }
                break
            }
        }

        // 中文别名容错
        if os.isEmpty {
            if raw.contains("雪松S") || raw.contains("雪松 S") {
                os = "Cedar S"
            } else if raw.contains("雪松") {
                os = "Cedar"
            } else if raw.contains("榕") {
                os = "Banyan"
            } else if raw.contains("赤杨") {
                os = "Alder"
            } else if raw.contains("白杨") {
                os = "Aspen"
            } else if raw.contains("椰子") || raw.contains("乐道") {
                os = "Coconut"
            } else if raw.contains("天枢") {
                os = "SkyOS"
            }
        }

        // 若字符串中未显式包含 OS 名称，根据车型推断
        if os.isEmpty {
            let m = (model ?? "").uppercased()
            if m.contains("ET9") || m.contains("NT2.5") || m.contains("NT3") {
                os = "Cedar S"
            } else if m.contains("L60") || m.contains("ONVO") {
                os = "Coconut"
            } else if m.contains("ET5") || m.contains("ET7") || m.contains("ES7") || m.contains("EC7") || m.contains("ES6") || m.contains("EC6") || m.contains("ES8") {
                os = "Banyan"
            } else {
                os = "Banyan"
            }
        }

        var verNum = ""
        if raw.contains("*") {
            let parts = raw.components(separatedBy: "*")
            if parts.count > 1, let match = parts.last?.range(of: #"\d+\.\d+(\.\d+)?"#, options: .regularExpression) {
                verNum = String(parts.last![match])
            }
        }
        if verNum.isEmpty {
            let pattern = #"\b\d+\.\d+(\.\d+)?(\.\d+)?\b"#
            if let match = raw.range(of: pattern, options: .regularExpression) {
                verNum = String(raw[match])
            }
        }
        if verNum.isEmpty {
            verNum = raw.isEmpty ? "智能系统" : raw
        }

        let fullDisplay: String
        if verNum == "智能系统" {
            fullDisplay = os + " 智能系统"
        } else if raw.hasPrefix(os) {
            fullDisplay = "\(os) \(verNum)"
        } else {
            fullDisplay = "\(os) \(verNum)"
        }

        return FotaDisplayInfo(osName: os, shortVer: verNum, fullDisplay: fullDisplay, rawVersion: raw)
    }

    static func shortFotaVersion(_ version: String?) -> String {
        return parseFotaInfo(version: version).shortVer
    }

    /// 一键唤起已安装的蔚来官方 App (若未安装则自动跳转 App Store 蔚来官方国区页面 id1116095987)
    static func openNIOApp() {
        #if os(iOS)
        let candidateSchemes = [
            "weilai://",
            "nio://",
            "do1://",
            "nioapp://",
            "weilaiapp://"
        ]
        for scheme in candidateSchemes {
            if let url = URL(string: scheme), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return
            }
        }
        if let defaultUrl = URL(string: "weilai://") {
            UIApplication.shared.open(defaultUrl, options: [:]) { success in
                if !success {
                    if let appStoreUrl = URL(string: "itms-apps://apps.apple.com/app/id1116095987") {
                        UIApplication.shared.open(appStoreUrl, options: [:], completionHandler: nil)
                    }
                }
            }
        }
        #elseif os(macOS)
        if let url = URL(string: "weilai://") {
            NSWorkspace.shared.open(url)
        } else if let appStoreUrl = URL(string: "https://apps.apple.com/cn/app/%E8%94%9A%E6%9D%A5/id1116095987") {
            NSWorkspace.shared.open(appStoreUrl)
        }
        #endif
    }

    // MARK: - 快照提取

    static func snapshotFromResponse(_ resp: NIOVehicleResponse) throws -> NIOVehicleSnapshot {
        guard let status = extractVehicleStatus(resp) else {
            throw NIOError.missingStatus
        }
        let lat = status.positionStatus?.latitude ?? 0
        let lng = status.positionStatus?.longitude ?? 0
        let posTs = status.positionStatus?.sampleTime ?? 0
        let socTs = status.socStatus?.sampleTime ?? 0
        let hasPos = isValidGPS(lat: lat, lng: lng)
        let ts = (hasPos && posTs > 0) ? posTs : (socTs > 0 ? socTs : Int(Date().timeIntervalSince1970 * 1000))
        return NIOVehicleSnapshot(
            ts: ts,
            soc: status.socStatus?.soc ?? 0,
            range: status.socStatus?.remainingRange ?? 0,
            actualRange: status.socStatus?.remainingActualRange ?? 0,
            mileage: status.exteriorStatus?.mileage ?? 0,
            lat: lat,
            lng: lng,
            insideTemp: status.hvacStatus?.temperature ?? 0,
            outsideTemp: status.hvacStatus?.outsideTemperature ?? 0
        )
    }

    static func extractVehicleStatus(_ resp: NIOVehicleResponse) -> NIOVehicleStatus? {
        guard let data = resp.data, let status = data.status else { return nil }
        if hasMinimalStatus(status) { return status }
        return nil
    }

    static func hasMinimalStatus(_ s: NIOVehicleStatus) -> Bool {
        return s.socStatus != nil || s.exteriorStatus != nil || s.positionStatus != nil
    }

    // MARK: - 车门与部件动态解析（仅展示车辆实际返回存在的传感器部件，防止出现不存在的内容）

    struct ParsedDoorItem: Identifiable, Hashable {
        let id: String
        let title: String
        let isClosed: Bool
        let customClosedLabel: String
        let customOpenLabel: String
        let icon: String
    }

    static func parseAvailableDoors(doorStatus: [String: NIOJSONValue]?, windowStatus: [String: NIOJSONValue]?) -> [ParsedDoorItem] {
        guard let doors = doorStatus, !doors.isEmpty else { return [] }
        var items: [ParsedDoorItem] = []

        // 1. 左前门
        if let fl = doors["door_ajar_front_left_status"]?.intValue ?? doors["front_left_door_ajar_status"]?.intValue ?? doors["door_ajr_sts_fl"]?.intValue ?? doors["door_fl"]?.intValue {
            items.append(ParsedDoorItem(id: "door_fl", title: "左前门", isClosed: fl == 1, customClosedLabel: "关好 🐾", customOpenLabel: "未关好 ⚠️", icon: fl == 1 ? "car.side.fill" : "car.side.front.open.fill"))
        }

        // 2. 前机盖 / 机舱盖 (蔚来 ET5 等车型为机舱盖，官方仪表显示为前机盖)
        if let hood = doors["engine_hood_ajar_status"]?.intValue ?? doors["engine_hood_sts"]?.intValue ?? doors["hood"]?.intValue {
            items.append(ParsedDoorItem(id: "hood", title: "前机盖", isClosed: hood == 1, customClosedLabel: "雪豹守好 🐆", customOpenLabel: "开启 ⚠️", icon: hood == 1 ? "car.side.front.open.fill" : "exclamationmark.triangle.fill"))
        }

        // 3. 右前门
        if let fr = doors["door_ajar_front_right_status"]?.intValue ?? doors["front_right_door_ajar_status"]?.intValue ?? doors["door_ajr_sts_fr"]?.intValue ?? doors["door_fr"]?.intValue {
            items.append(ParsedDoorItem(id: "door_fr", title: "右前门", isClosed: fr == 1, customClosedLabel: "关好 🐾", customOpenLabel: "未关好 ⚠️", icon: fr == 1 ? "car.side.fill" : "car.side.front.open.fill"))
        }

        // 4. 左后门
        if let rl = doors["door_ajar_rear_left_status"]?.intValue ?? doors["rear_left_door_ajar_status"]?.intValue ?? doors["door_ajr_sts_rl"]?.intValue ?? doors["door_rl"]?.intValue {
            items.append(ParsedDoorItem(id: "door_rl", title: "左后门", isClosed: rl == 1, customClosedLabel: "关好 🐾", customOpenLabel: "未关好 ⚠️", icon: rl == 1 ? "car.side.fill" : "car.side.rear.open.fill"))
        }

        // 5. 后备箱 (仅当接口包含后备箱字段时展示)
        if let trunk = doors["tailgate_ajar_status"]?.intValue ?? doors["tailgate_sts"]?.intValue ?? doors["trunk"]?.intValue {
            items.append(ParsedDoorItem(id: "trunk", title: "后备箱", isClosed: trunk == 1, customClosedLabel: "雪豹守好 🐆", customOpenLabel: "开启 ⚠️", icon: trunk == 1 ? "car.side.rear.open.fill" : "exclamationmark.triangle.fill"))
        }

        // 6. 右后门
        if let rr = doors["door_ajar_rear_right_status"]?.intValue ?? doors["rear_right_door_ajar_status"]?.intValue ?? doors["door_ajr_sts_rr"]?.intValue ?? doors["door_rr"]?.intValue {
            items.append(ParsedDoorItem(id: "door_rr", title: "右后门", isClosed: rr == 1, customClosedLabel: "关好 🐾", customOpenLabel: "未关好 ⚠️", icon: rr == 1 ? "car.side.fill" : "car.side.rear.open.fill"))
        }

        // 7. 充电口盖 (仅当接口包含充电口盖字段时展示)
        if let chrg = doors["second_charge_port_ajar_status"]?.intValue ?? doors["second_charge_port_cap"]?.intValue ?? doors["charge_port_status"]?.intValue ?? doors["charge_port"]?.intValue {
            items.append(ParsedDoorItem(id: "charge_port", title: "充电口盖", isClosed: chrg == 1, customClosedLabel: "闭好 🐾", customOpenLabel: "开启 ⚠️", icon: chrg == 1 ? "powerplug.fill" : "bolt.badge.automatic.fill"))
        }

        // 8. 整车车锁
        if let lock = doors["vehicle_lock_status"]?.intValue ?? doors["lock_status"]?.intValue ?? doors["lock"]?.intValue {
            items.append(ParsedDoorItem(id: "vehicle_lock", title: "整车车锁", isClosed: lock == 1, customClosedLabel: "雪豹守护 🐆", customOpenLabel: "未上锁 🔓", icon: lock == 1 ? "lock.shield.fill" : "lock.open.fill"))
        }

        // 9. 车窗天窗 (仅当 windowStatus 存在时解析)
        if let win = windowStatus, !win.isEmpty {
            let winFL = win["win_front_left_posn"]?.intValue ?? win["win_posn_fl"]?.intValue ?? 0
            let winFR = win["win_front_right_posn"]?.intValue ?? win["win_posn_fr"]?.intValue ?? 0
            let winRL = win["win_rear_left_posn"]?.intValue ?? win["win_posn_rl"]?.intValue ?? 0
            let winRR = win["win_rear_right_posn"]?.intValue ?? win["win_posn_rr"]?.intValue ?? 0
            let sunRoof = win["sun_roof_posn"]?.intValue ?? 0
            let anyOpen = winFL > 0 || winFR > 0 || winRL > 0 || winRR > 0 || sunRoof > 0
            items.append(ParsedDoorItem(id: "windows", title: "车窗天窗", isClosed: !anyOpen, customClosedLabel: "海獭抱紧 🦦", customOpenLabel: "开启中 ⚠️", icon: !anyOpen ? "square.split.2x2.fill" : "square.split.2x2"))
        }

        return items
    }
}

// MARK: - RVS 归一化器

enum RVSRormalizer {

    /// 将 RVS 平铺响应归一化为 data.status 结构
    static func normalize(_ raw: [String: Any]) -> [String: Any] {
        guard let data = raw["data"] as? [String: Any] else { return raw }

        var status: [String: Any] = [:]
        if let existing = data["status"] as? [String: Any] {
            status = existing
        }

        let fieldMap: [(from: String, to: String)] = [
            ("soc", "soc_status"),
            ("position", "position_status"),
            ("exterior", "exterior_status"),
            ("hvac", "hvac_status"),
            ("door", "door_status"),
            ("window", "window_status"),
            ("connection", "connection_status"),
            ("heating", "heating_status"),
            ("maintain", "maintain_status"),
            ("fota", "fota_status"),
            ("offcar_mode_status", "offcar_mode_status"),
            ("tyre", "tyre_status"),
            ("lv_batt", "lv_batt_status"),
            ("device_status", "device_status"),
            ("charge_status_order", "charge_status_order"),
            ("light", "light_status"),
            ("key", "key_status"),
            ("special", "special_status"),
            ("trip_share", "trip_share_status"),
            ("remote_operate", "remote_operate_status"),
            ("offcar_power_swap", "offcar_power_swap_status"),
            ("box", "box_status"),
            ("frdg", "frdg_status"),
        ]

        for (from, to) in fieldMap {
            if let v = data[from] as? [String: Any], status[to] == nil {
                status[to] = v
            }
            if let v = data[to] as? [String: Any], status[to] == nil {
                status[to] = v
            }
        }

        let directKeys = [
            "light_status", "key_status", "special_status", "trip_share_status",
            "nearby_car_ctrl", "power_swap_order", "remote_operate_status",
            "offcar_power_swap_status", "box_status", "frdg_status",
            "mix_auth_status", "tyre_status", "window_status",
            "maintain_status", "lv_batt_status", "device_status",
            "charge_status_order",
        ]
        for key in directKeys {
            if let v = data[key] as? [String: Any], status[key] == nil {
                status[key] = v
            }
        }

        // 内部别名归一化（如 status["tire_status"] 或 status["tyre"] 映射到 status["tyre_status"]）
        if status["tyre_status"] == nil {
            for alt in ["tire_status", "tyre", "tire", "tyres", "tires", "tyre_pressure", "tire_pressure", "tpms_status", "tyre_press_status"] {
                if let v = status[alt] as? [String: Any] {
                    status["tyre_status"] = v
                    break
                }
            }
        }

        // 如果 tyre_status 依然为空，收集扁平 tyre / tire 键或 maintain_status 中的胎压数据
        if status["tyre_status"] == nil {
            var extractedTyres: [String: Any] = [:]
            for (k, v) in status {
                let lk = k.lowercased()
                if lk.contains("tyre") || lk.contains("tire") || lk.contains("wheel_press") || lk.contains("wheel_temp") || lk.contains("press_bar") || lk.contains("press_fl") || lk.contains("press_fr") || lk.contains("press_rl") || lk.contains("press_rr") {
                    extractedTyres[k] = v
                }
            }
            if let maint = status["maintain_status"] as? [String: Any] {
                for (k, v) in maint {
                    let lk = k.lowercased()
                    if lk.contains("tyre") || lk.contains("tire") || lk.contains("wheel_press") || lk.contains("wheel_temp") || lk.contains("press_bar") || lk.contains("press_fl") || lk.contains("press_fr") || lk.contains("press_rl") || lk.contains("press_rr") {
                        extractedTyres[k] = v
                    }
                }
            }
            if let ext = status["exterior_status"] as? [String: Any] {
                for (k, v) in ext {
                    let lk = k.lowercased()
                    if lk.contains("tyre") || lk.contains("tire") || lk.contains("wheel_press") || lk.contains("wheel_temp") || lk.contains("press_bar") {
                        extractedTyres[k] = v
                    }
                }
            }
            if !extractedTyres.isEmpty {
                status["tyre_status"] = extractedTyres
            }
        }

        if let vid = data["vehicle_id"] as? String, !vid.isEmpty, status["vehicle_id"] == nil {
            status["vehicle_id"] = vid
        }

        guard !status.isEmpty else { return raw }

        var result = raw
        var newData = data
        newData["status"] = status
        result["data"] = newData
        return result
    }
}

// MARK: - 错误

enum NIOError: LocalizedError {
    case missingStatus
    case emptyResponse
    case htmlResponse
    case invalidJSON
    case httpError(Int, String)
    case configError(String)
    case unauthorized403(String)

    var errorDescription: String? {
        switch self {
        case .missingStatus: return "车辆数据缺少 data.status"
        case .emptyResponse: return "API 返回空内容"
        case .htmlResponse: return "API 返回 HTML 而非 JSON，请检查 Authorization / sign / timestamp"
        case .invalidJSON: return "API 不是合法 JSON"
        case .httpError(let code, let text): return "API \(code): \(text)"
        case .configError(let msg): return msg
        case .unauthorized403(let msg): return "HTTP 403 鉴权失败：\(msg)"
        }
    }
}

// MARK: - 蔚来全系车型与官方配色库（移植自 ha-nio 官方渲染图库）

public struct NIOCarColor: Identifiable, Hashable {
    public var id: String { slug }
    public let slug: String
    public let name: String
    public let fileName: String

    public init(slug: String, name: String, fileName: String) {
        self.slug = slug
        self.name = name
        self.fileName = fileName
    }
}

public struct NIOCarModel: Identifiable, Hashable {
    public var id: String { slug }
    public let slug: String
    public let name: String
    public let defaultColorSlug: String
    public let colors: [NIOCarColor]

    public init(slug: String, name: String, defaultColorSlug: String, colors: [NIOCarColor]) {
        self.slug = slug
        self.name = name
        self.defaultColorSlug = defaultColorSlug
        self.colors = colors
    }
}

public enum NIOVehicleModelLib {

    /// 蔚来官方 9 大车型与全配色库
    public static let models: [NIOCarModel] = [
        NIOCarModel(
            slug: "et5",
            name: "ET5",
            defaultColorSlug: "cloud_dawn_yellow",
            colors: [
                NIOCarColor(slug: "cloud_dawn_yellow", name: "云初黄", fileName: "et5_cloud_dawn_yellow.webp"),
                NIOCarColor(slug: "mirror_pink", name: "镜空粉", fileName: "et5_mirror_pink.webp"),
                NIOCarColor(slug: "far_sky_purple", name: "远空紫", fileName: "et5_far_sky_purple.webp"),
                NIOCarColor(slug: "stratosphere_blue", name: "同温层蓝", fileName: "et5_stratosphere_blue.webp"),
                NIOCarColor(slug: "cloud_white", name: "云白", fileName: "et5_cloud_white.webp"),
                NIOCarColor(slug: "star_gray", name: "星灰", fileName: "et5_star_gray.webp"),
                NIOCarColor(slug: "deep_black", name: "深空黑", fileName: "et5_deep_black.webp"),
                NIOCarColor(slug: "moon_silver", name: "月辉银", fileName: "et5_moon_silver.webp")
            ]
        ),
        NIOCarModel(
            slug: "et5t",
            name: "ET5 Touring",
            defaultColorSlug: "cloud_dawn_yellow",
            colors: [
                NIOCarColor(slug: "cloud_dawn_yellow", name: "云初黄", fileName: "et5t_cloud_dawn_yellow.webp"),
                NIOCarColor(slug: "sunlight_gold", name: "日光金", fileName: "et5t_sunlight_gold.webp"),
                NIOCarColor(slug: "mirror_pink", name: "镜空粉", fileName: "et5t_mirror_pink.webp"),
                NIOCarColor(slug: "stratosphere_blue", name: "同温层蓝", fileName: "et5t_stratosphere_blue.webp"),
                NIOCarColor(slug: "cloud_white", name: "云白", fileName: "et5t_cloud_white.webp"),
                NIOCarColor(slug: "star_gray", name: "星灰", fileName: "et5t_star_gray.webp"),
                NIOCarColor(slug: "deep_black", name: "深空黑", fileName: "et5t_deep_black.webp"),
                NIOCarColor(slug: "moon_silver", name: "月辉银", fileName: "et5t_moon_silver.webp")
            ]
        ),
        NIOCarModel(
            slug: "es6",
            name: "ES6",
            defaultColorSlug: "stratosphere_blue",
            colors: [
                NIOCarColor(slug: "stratosphere_blue", name: "同温层蓝", fileName: "es6_stratosphere_blue.webp"),
                NIOCarColor(slug: "galaxy_purple", name: "银河紫", fileName: "es6_galaxy_purple.webp"),
                NIOCarColor(slug: "southern_star_blue", name: "南极星蓝", fileName: "es6_southern_star_blue.webp"),
                NIOCarColor(slug: "dawn_gold", name: "曙光金", fileName: "es6_dawn_gold.webp"),
                NIOCarColor(slug: "cloud_white", name: "云白", fileName: "es6_cloud_white.webp"),
                NIOCarColor(slug: "star_gray", name: "星灰", fileName: "es6_star_gray.webp"),
                NIOCarColor(slug: "deep_black", name: "深空黑", fileName: "es6_deep_black.webp"),
                NIOCarColor(slug: "moon_silver", name: "月辉银", fileName: "es6_moon_silver.webp")
            ]
        ),
        NIOCarModel(
            slug: "ec6",
            name: "EC6",
            defaultColorSlug: "mirage_purple",
            colors: [
                NIOCarColor(slug: "mirage_purple", name: "灵境紫", fileName: "ec6_mirage_purple.webp"),
                NIOCarColor(slug: "radiant_silver", name: "辉银", fileName: "ec6_radiant_silver.webp"),
                NIOCarColor(slug: "southern_star_blue", name: "南极星蓝", fileName: "ec6_southern_star_blue.webp"),
                NIOCarColor(slug: "stratosphere_blue", name: "同温层蓝", fileName: "ec6_stratosphere_blue.webp"),
                NIOCarColor(slug: "dawn_gold", name: "曙光金", fileName: "ec6_dawn_gold.webp"),
                NIOCarColor(slug: "cloud_white", name: "云白", fileName: "ec6_cloud_white.webp"),
                NIOCarColor(slug: "star_gray", name: "星灰", fileName: "ec6_star_gray.webp"),
                NIOCarColor(slug: "deep_black", name: "深空黑", fileName: "ec6_deep_black.webp")
            ]
        ),
        NIOCarModel(
            slug: "es8",
            name: "ES8",
            defaultColorSlug: "southern_star_blue",
            colors: [
                NIOCarColor(slug: "southern_star_blue", name: "南极星蓝", fileName: "es8_southern_star_blue.webp"),
                NIOCarColor(slug: "star_ripple_gray", name: "星澜灰", fileName: "es8_star_ripple_gray.webp"),
                NIOCarColor(slug: "dawn_gold", name: "曙光金", fileName: "es8_dawn_gold.webp"),
                NIOCarColor(slug: "cloud_white", name: "云白", fileName: "es8_cloud_white.webp"),
                NIOCarColor(slug: "polar_night_black", name: "极夜黑", fileName: "es8_polar_night_black.webp"),
                NIOCarColor(slug: "moon_silver", name: "月辉银", fileName: "es8_moon_silver.webp"),
                NIOCarColor(slug: "nebula_red", name: "星云红", fileName: "es8_nebula_red.webp")
            ]
        ),
        NIOCarModel(
            slug: "et7",
            name: "ET7",
            defaultColorSlug: "southern_star_blue",
            colors: [
                NIOCarColor(slug: "southern_star_blue", name: "南极星蓝", fileName: "et7_southern_star_blue.webp"),
                NIOCarColor(slug: "aurora_green", name: "极光绿", fileName: "et7_aurora_green.webp"),
                NIOCarColor(slug: "dawn_gold", name: "曙光金", fileName: "et7_dawn_gold.webp"),
                NIOCarColor(slug: "cloud_white", name: "云白", fileName: "et7_cloud_white.webp"),
                NIOCarColor(slug: "star_gray", name: "星灰", fileName: "et7_star_gray.webp"),
                NIOCarColor(slug: "deep_black", name: "深空黑", fileName: "et7_deep_black.webp"),
                NIOCarColor(slug: "moon_silver", name: "月辉银", fileName: "et7_moon_silver.webp")
            ]
        ),
        NIOCarModel(
            slug: "ec7",
            name: "EC7",
            defaultColorSlug: "nebula_red",
            colors: [
                NIOCarColor(slug: "nebula_red", name: "星云红", fileName: "ec7_nebula_red.webp"),
                NIOCarColor(slug: "southern_star_blue", name: "南极星蓝", fileName: "ec7_southern_star_blue.webp"),
                NIOCarColor(slug: "stratosphere_blue", name: "同温层蓝", fileName: "ec7_stratosphere_blue.webp"),
                NIOCarColor(slug: "dawn_gold", name: "曙光金", fileName: "ec7_dawn_gold.webp"),
                NIOCarColor(slug: "cloud_white", name: "云白", fileName: "ec7_cloud_white.webp"),
                NIOCarColor(slug: "star_gray", name: "星灰", fileName: "ec7_star_gray.webp"),
                NIOCarColor(slug: "deep_black", name: "深空黑", fileName: "ec7_deep_black.webp")
            ]
        ),
        NIOCarModel(
            slug: "es7",
            name: "ES7",
            defaultColorSlug: "stratosphere_blue",
            colors: [
                NIOCarColor(slug: "stratosphere_blue", name: "同温层蓝", fileName: "es7_stratosphere_blue.webp"),
                NIOCarColor(slug: "southern_star_blue", name: "南极星蓝", fileName: "es7_southern_star_blue.webp"),
                NIOCarColor(slug: "dawn_gold", name: "曙光金", fileName: "es7_dawn_gold.webp"),
                NIOCarColor(slug: "cloud_white", name: "云白", fileName: "es7_cloud_white.webp"),
                NIOCarColor(slug: "star_gray", name: "星灰", fileName: "es7_star_gray.webp"),
                NIOCarColor(slug: "deep_black", name: "深空黑", fileName: "es7_deep_black.webp"),
                NIOCarColor(slug: "moon_silver", name: "月辉银", fileName: "es7_moon_silver.webp")
            ]
        ),
        NIOCarModel(
            slug: "et9",
            name: "ET9",
            defaultColorSlug: "deep_black",
            colors: [
                NIOCarColor(slug: "deep_black", name: "深空黑", fileName: "et9_deep_black.webp"),
                NIOCarColor(slug: "cloud_white", name: "云白", fileName: "et9_cloud_white.webp"),
                NIOCarColor(slug: "morning_gold", name: "晨金", fileName: "et9_morning_gold.webp"),
                NIOCarColor(slug: "moon_silver", name: "月辉银", fileName: "et9_moon_silver.webp")
            ]
        )
    ]

    public static func findModel(by slug: String) -> NIOCarModel? {
        models.first { $0.slug.lowercased() == slug.lowercased() }
    }

    #if canImport(AppKit)
    public static func loadCarImage(named name: String) -> NSImage? {
        if let direct = NSImage(named: name) {
            return direct
        }
        let baseName = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension.isEmpty ? "webp" : (name as NSString).pathExtension
        if let path = Bundle.main.path(forResource: baseName, ofType: ext, inDirectory: "Cars") ?? Bundle.main.path(forResource: baseName, ofType: ext) {
            return NSImage(contentsOfFile: path)
        }
        return nil
    }
    #endif
}

// MARK: - 能耗达成率与百公里电耗评分 (range_achievement_rate)

enum NIOEfficiencyLib {
    struct EfficiencyScore {
        var achievementRate: Double      // 达成率 (e.g. 85.2%)
        var grade: String                // "S" / "A" / "B" / "C"
        var title: String                // "黄金脚法 · 超强续航"
        var subtitle: String             // "电耗控制极佳，超越90%车主"
        var icon: String                 // "crown.fill"
        var estimatedKwhPer100Km: Double // 推算百公里电耗 e.g. 15.6 kWh/100km
    }

    static func computeScore(nominalRange: Double?, actualRange: Double?, batteryCapacityKwh: Double = 75.0) -> EfficiencyScore? {
        guard let nominal = nominalRange, nominal > 0,
              let actual = actualRange, actual > 0 else {
            return nil
        }
        let rate = min(150.0, max(10.0, (actual / nominal) * 100.0))
        let kwh100 = round((16.5 / (rate / 100.0)) * 10.0) / 10.0

        if rate >= 90.0 {
            return EfficiencyScore(
                achievementRate: rate,
                grade: "S 级",
                title: "黄金脚法 · 超强续航 ✨",
                subtitle: "百公里电耗极低，动能回收与匀速巡航大师",
                icon: "crown.fill",
                estimatedKwhPer100Km: kwh100
            )
        } else if rate >= 80.0 {
            return EfficiencyScore(
                achievementRate: rate,
                grade: "A 级",
                title: "节能先锋 · 高效巡航 🍃",
                subtitle: "日常驾驶平顺，电能利用效率优异",
                icon: "leaf.fill",
                estimatedKwhPer100Km: kwh100
            )
        } else if rate >= 70.0 {
            return EfficiencyScore(
                achievementRate: rate,
                grade: "B 级",
                title: "从容自若 · 标准表现 🚗",
                subtitle: "兼顾舒适与电耗，符合城市综合工况",
                icon: "car.fill",
                estimatedKwhPer100Km: kwh100
            )
        } else {
            return EfficiencyScore(
                achievementRate: rate,
                grade: "C 级",
                title: "澎湃驾趣 · 动力优先 🔥",
                subtitle: "加速强劲热血，追求极致驾驶快感",
                icon: "flame.fill",
                estimatedKwhPer100Km: kwh100
            )
        }
    }
}

// MARK: - 维保周期与耗材寿命追踪 (nsom_so_maintenance)

enum NIOMaintenanceTracker {
    struct ConsumableItem: Identifiable, Hashable {
        var id: String { name }
        var name: String             // 耗材名称
        var icon: String             // SF Symbol
        var intervalKm: Double       // 推荐保养间隔里程 (km)
        var intervalMonths: Int      // 推荐保养间隔月数
        var remainingKm: Double      // 剩余可用里程
        var remainingDays: Int       // 剩余可用天数
        var healthPercentage: Double // 0.0 ... 100.0 寿命百分比
        var statusDesc: String       // "健康良好" / "建议关注" / "需要保养"
        var isUrgent: Bool
    }

    struct MaintenanceReport {
        var totalCount: Int
        var totalSpent: Double
        var lastServiceDate: String
        var lastServiceStation: String
        var nextServiceKm: Double
        var items: [ConsumableItem]
        var overallHealthScore: Int  // 0 ... 100
    }

    static func generateReport(currentMileage: Double, orders: [NIOServiceOrder]) -> MaintenanceReport {
        let maintOrders = orders.filter { $0.orderType == "nsom_so_maintenance" }.sorted { $0.createTime > $1.createTime }
        let completed = maintOrders.filter { NIOOrderLib.isCompletedOrder($0) }
        let totalSpent = completed.reduce(0.0) { $0 + NIOOrderLib.orderSpentAmount($1) }
        
        let lastOrder = completed.first
        let lastDate = lastOrder != nil ? NIOOrderLib.fmtSwapDate(lastOrder!.createTime) : "未记录"
        let lastStation = lastOrder?.resourceAddress ?? lastOrder?.address ?? "官方服务中心"

        let configs: [(name: String, icon: String, km: Double, months: Int)] = [
            ("空调滤清器 (CN95)", "air.purifier.fill", 10_000, 12),
            ("轮胎动平衡与换位", "circle.grid.cross.fill", 20_000, 12),
            ("制动液 (刹车油)", "car.rear.and.tire.marks", 40_000, 24),
            ("整车冷却液 (防冻液)", "snowflake.circle.fill", 60_000, 36),
            ("雨刮胶条与洗涤系统", "windshield.front.and.wiper", 15_000, 12)
        ]

        var items: [ConsumableItem] = []
        var totalHealth = 0.0

        for cfg in configs {
            let usedKm = currentMileage.truncatingRemainder(dividingBy: cfg.km)
            let remainKm = max(0.0, cfg.km - usedKm)
            let health = max(0.0, min(100.0, (remainKm / cfg.km) * 100.0))
            totalHealth += health

            let isUrgent = health < 15.0
            let status: String = {
                if health > 60.0 { return "寿命充足 (\(Int(health))%)" }
                if health > 20.0 { return "状态正常 (\(Int(health))%)" }
                return "建议近期检查保养 ⚠️"
            }()

            items.append(ConsumableItem(
                name: cfg.name,
                icon: cfg.icon,
                intervalKm: cfg.km,
                intervalMonths: cfg.months,
                remainingKm: remainKm,
                remainingDays: Int(remainKm / 35.0),
                healthPercentage: health,
                statusDesc: status,
                isUrgent: isUrgent
            ))
        }

        let avgHealth = items.isEmpty ? 100 : Int(totalHealth / Double(items.count))
        let nextKm = items.map { $0.remainingKm }.min() ?? 5000.0

        return MaintenanceReport(
            totalCount: completed.count,
            totalSpent: totalSpent,
            lastServiceDate: lastDate,
            lastServiceStation: lastStation,
            nextServiceKm: nextKm,
            items: items,
            overallHealthScore: avgHealth
        )
    }
}

