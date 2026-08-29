//
//  NIOCheckinLib.swift
//  YumikoToys
//
//  签到数据解析 + 调度逻辑（从 NIO-Dash TS 重写）
//

import Foundation

enum NIOCheckinLib {

    static let checkinHour = 9
    static let checkinMinute = 0
    static let retryCooldownMs: Int = 5 * 60 * 1000

    // MARK: - 本地日历日

    static func localDayKey(_ date: Date = Date()) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    // MARK: - 签到窗口

    static func isCheckinWindowOpen(_ date: Date = Date()) -> Bool {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return minutes >= checkinHour * 60 + checkinMinute
    }

    // MARK: - 签到响应解析（兼容多层嵌套）

    static func extractCheckinFields(_ raw: Any) -> (checkedIn: Bool, days: Int)? {
        func parseCheckedIn(_ v: Any?) -> Bool? {
            if let b = v as? Bool { return b }
            if let n = v as? Int { return n != 0 }
            if let s = v as? String {
                if s == "1" || s == "true" { return true }
                if s == "0" || s == "false" { return false }
            }
            if let n = v as? Double { return n != 0 }
            return nil
        }
        func parseDays(_ v: Any?) -> Int? {
            if let n = v as? Int { return n }
            if let n = v as? Double, n.isFinite { return Int(n) }
            if let s = v as? String, let n = Double(s), n.isFinite { return Int(n) }
            return nil
        }

        var checkedIn: Bool?
        var days: Int?

        func visit(_ obj: Any, depth: Int) {
            guard depth <= 8 else { return }
            guard let dict = obj as? [String: Any] else { return }
            if checkedIn == nil {
                if let v = parseCheckedIn(dict["checked_in"] ?? dict["checkedIn"]) {
                    checkedIn = v
                }
                if let nested = dict["checked_in"] as? [String: Any] {
                    if let v = parseCheckedIn(nested["checked"]) { checkedIn = v }
                    if let d = parseDays(nested["days"]) { days = d }
                }
            }
            if days == nil {
                if let d = parseDays(dict["continuous_days"] ?? dict["continuousDays"] ?? dict["days"]) {
                    days = d
                }
            }
            if checkedIn != nil && days != nil { return }
            for value in dict.values { visit(value, depth: depth + 1) }
            if checkedIn != nil && days != nil { return }
        }

        visit(raw, depth: 0)
        guard checkedIn != nil || days != nil else { return nil }
        return (checkedIn ?? false, days ?? 0)
    }

    static func normalizeCheckinData(_ raw: Any) -> NIOCheckinData? {
        guard let record = raw as? [String: Any] else { return nil }
        let extracted: (checkedIn: Bool, days: Int)?
        if record["checked_in"] != nil || record["continuous_days"] != nil {
            let ci = (record["checked_in"] as? Bool) ?? (record["checked_in"] as? Int).map { $0 != 0 } ?? false
            let cd = (record["continuous_days"] as? Int) ?? (record["continuous_days"] as? Double).map { Int($0) } ?? 0
            extracted = (ci, cd)
        } else {
            extracted = extractCheckinFields(raw)
        }
        guard let ext = extracted else { return nil }
        return NIOCheckinData(
            checkedIn: ext.checkedIn,
            continuousDays: ext.days,
            serverTime: record["server_time"] as? Int,
            requestId: record["request_id"] as? String
        )
    }
}

// MARK: - 拉取间隔调度

enum NIOPollSchedule {

    static let drivingDefault = 300
    static let dayDefault = 300
    static let nightDefault = 300
    static let changeDefault = 600

    static func parsePollSec(_ value: Int?, fallback: Int) -> Int {
        guard let v = value, v > 0 else { return fallback }
        return max(15, v)
    }

    static func isDaytime(_ date: Date = Date()) -> Bool {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return minutes >= 9 * 60 && minutes <= 17 * 60
    }

    static func isDrivingVehicleState(_ state: Int?) -> Bool {
        state == 1
    }

    enum PollReason: String {
        case driving, day, night
        var label: String {
            switch self {
            case .driving: return "行驶中"
            case .day: return "白天"
            case .night: return "夜间"
            }
        }
    }

    static func vehiclePollReason(vehicleState: Int?, date: Date = Date()) -> PollReason {
        if isDrivingVehicleState(vehicleState) { return .driving }
        return isDaytime(date) ? .day : .night
    }

    static func vehiclePollInterval(
        driving: Int?, day: Int?, night: Int?,
        vehicleState: Int?, date: Date = Date()
    ) -> (intervalSec: Int, reason: PollReason) {
        let d = parsePollSec(driving, fallback: drivingDefault)
        let dayV = parsePollSec(day, fallback: dayDefault)
        let nightV = parsePollSec(night, fallback: nightDefault)
        let reason = vehiclePollReason(vehicleState: vehicleState, date: date)
        let interval = reason == .driving ? d : reason == .day ? dayV : nightV
        return (interval, reason)
    }

    static func changePollInterval(_ value: Int?) -> Int {
        parsePollSec(value, fallback: changeDefault)
    }

    static func minVehiclePollSec(driving: Int?, day: Int?, night: Int?) -> Int {
        min(
            parsePollSec(driving, fallback: drivingDefault),
            min(parsePollSec(day, fallback: dayDefault), parsePollSec(night, fallback: nightDefault))
        )
    }
}
