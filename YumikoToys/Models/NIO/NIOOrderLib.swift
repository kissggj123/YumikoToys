//
//  NIOOrderLib.swift
//  YumikoToys
//
//  换电 / 服务订单分析与格式化（从 NIO-Dash TS 重写）
//

import Foundation

enum NIOOrderLib {

    static let orderTypeLabels: [String: String] = [
        "pe_shaman_change": "换电",
        "pe_shaman": "充电",
        "service_pe_discharge": "放电",
        "battery_flexible_upgrade": "灵活升级",
        "nsom_so_maintenance": "一键维保",
        "nsom_so_chauffeur": "驾享服务",
        "so_case_accident": "事故报案",
        "chauffeur_vehicle_delivery": "一键送车",
    ]

    static func orderTypeLabel(_ order: NIOServiceOrder) -> String {
        order.orderName ?? orderTypeLabels[order.orderType] ?? order.orderType
    }

    static func shortStationName(_ address: String) -> String {
        var s = address
        if s.hasSuffix("蔚来换电站") {
            s = String(s.dropLast("蔚来换电站".count))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func orderStatusTone(_ order: NIOServiceOrder) -> String {
        let name = order.orderStatusName ?? ""
        let code = order.orderStatus ?? ""
        if code == "100" || code == "1000" || name.contains("完成") || name.contains("已支付") {
            return "success"
        }
        if code == "255" || code == "900" || name.contains("取消") || name.contains("终止") {
            return "danger"
        }
        if name.contains("进行") || name.contains("等待") || code == "30" {
            return "warning"
        }
        return "neutral"
    }

    static func fmtMoney(_ value: Double) -> String {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "zh_CN")
        nf.numberStyle = .currency
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        return nf.string(from: NSNumber(value: value)) ?? "¥\(value)"
    }

    static func fmtSwapDate(_ ms: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy/MM/dd HH:mm"
        return fmt.string(from: date)
    }

    static func orderSpentAmount(_ order: NIOServiceOrder) -> Double {
        if let cash = order.priceCash, let amt = Double(cash), amt > 0 {
            return amt
        }
        return parsePaymentInfo(order).reduce(0) { $0 + ($1.amount ?? 0) }
    }

    static func orderAmount(_ order: NIOServiceOrder) -> String {
        if let desc = order.payDesc, !desc.isEmpty { return desc }
        let spent = orderSpentAmount(order)
        if spent > 0 { return fmtMoney(spent) }
        let items = parsePaymentInfo(order)
        if !items.isEmpty {
            return items.map { "\($0.name) ¥\($0.amount ?? 0)" }.joined(separator: "；")
        }
        return "—"
    }

    struct PaymentInfoItem {
        let name: String
        let amount: Double?
        let type: Int?
    }

    static func parsePaymentInfo(_ order: NIOServiceOrder) -> [PaymentInfoItem] {
        guard let ext = order.extendInfo else { return [] }
        guard let payment = ext["payment_info"], case .object(let dict) = payment else { return [] }
        guard let itemsVal = dict["payment_items"], case .array(let arr) = itemsVal else { return [] }

        return arr.compactMap { item -> PaymentInfoItem? in
            guard case .object(let itemDict) = item else { return nil }
            let name = itemDict["payment_name"]?.stringValue ?? ""
            let amount = itemDict["amount"]?.numberValue
            let type = itemDict["type"]?.numberValue.map { Int($0) }
            return PaymentInfoItem(name: name, amount: amount, type: type)
        }
    }

    static func orderStationName(_ order: NIOServiceOrder) -> String {
        if let addr = order.resourceAddress { return shortStationName(addr) }
        if let name = order.pickUpName { return shortStationName(name) }
        if let name = order.returnName { return shortStationName(name) }
        if let addr = order.address { return addr }
        if let ext = order.extendInfo {
            if let dealer = ext["dealer_info"], case .object(let d) = dealer,
               let name = d["dealer_name"]?.stringValue { return name }
            if let loc = ext["expected_service_location"], case .object(let l) = loc,
               let name = l["poi_name"]?.stringValue { return name }
        }
        return "—"
    }

    static func isCompletedOrder(_ order: NIOServiceOrder) -> Bool {
        let name = order.orderStatusName ?? ""
        return order.orderStatus == "100" || order.orderStatus == "1000" ||
               name.contains("完成") || name.contains("已支付")
    }

    static func isCancelledOrder(_ order: NIOServiceOrder) -> Bool {
        let name = order.orderStatusName ?? ""
        return order.orderStatus == "255" || order.orderStatus == "900" || name.contains("取消")
    }

    static func classifyUpgradeRent(_ amount: Double) -> String {
        return (amount >= 0 && amount <= 399) ? "day" : "month"
    }

    static func orderDetailLines(_ order: NIOServiceOrder) -> [(label: String, value: String)] {
        var lines: [(label: String, value: String)] = []
        if let no = order.orderNo, !no.isEmpty {
            lines.append((label: "订单号", value: no))
        }
        if let vin = order.vinCode, !vin.isEmpty {
            lines.append((label: "VIN", value: vin))
        }
        lines.append((label: "类型", value: orderTypeLabel(order)))
        lines.append((label: "时间", value: fmtSwapDate(order.createTime)))
        if let st = order.orderStatusName {
            lines.append((label: "状态", value: st))
        }
        lines.append((label: "金额", value: orderAmount(order)))
        let station = orderStationName(order)
        if station != "—" {
            lines.append((label: "换电站/地点", value: station))
        }
        if let addr = order.address, !addr.isEmpty && addr != station {
            lines.append((label: "详细地址", value: addr))
        }
        return lines
    }

    // MARK: - 订单分析

    static func analyzeServiceOrders(_ response: NIOChangeResponse) -> NIOServiceSummary {
        let orders = (response.resultData?.data ?? []).sorted { $0.createTime > $1.createTime }

        var typeMap: [String: NIOTypeStat] = [:]
        for order in orders {
            let label = orderTypeLabel(order)
            var prev = typeMap[order.orderType] ?? NIOTypeStat(type: order.orderType, label: label, count: 0, spent: 0)
            prev.count += 1
            if let cash = order.priceCash, let amt = Double(cash), amt > 0 {
                prev.spent += amt
            } else {
                let items = parsePaymentInfo(order)
                prev.spent += items.reduce(0) { $0 + ($1.amount ?? 0) }
            }
            typeMap[order.orderType] = prev
        }
        let byType = typeMap.values.sorted { $0.count > $1.count }

        let swapOrders = orders.filter { $0.orderType == "pe_shaman_change" }
        let swapCompleted = swapOrders.filter { $0.orderStatus == "100" }
        let swapCancelled = swapOrders.filter { isCancelledOrder($0) }
        let swapSpent = swapCompleted.reduce(0) { $0 + (Double($1.priceCash ?? "0") ?? 0) }

        let upgradeOrders = orders.filter { $0.orderType == "battery_flexible_upgrade" }
        let upgradeCompleted = upgradeOrders.filter { isCompletedOrder($0) }
        let upgradeCancelled = upgradeOrders.filter { isCancelledOrder($0) }
        let upgradeSpent = upgradeCompleted.reduce(0) { $0 + orderSpentAmount($1) }
        var upgradeDayCount = 0
        var upgradeMonthCount = 0
        for order in upgradeCompleted {
            let kind = classifyUpgradeRent(orderSpentAmount(order))
            if kind == "day" { upgradeDayCount += 1 } else { upgradeMonthCount += 1 }
        }

        var stationMap: [String: NIOStationStat] = [:]
        for order in swapCompleted {
            guard let addr = order.resourceAddress, !addr.isEmpty else { continue }
            let name = shortStationName(addr)
            var prev = stationMap[name] ?? NIOStationStat(name: name, count: 0, spent: 0)
            prev.count += 1
            prev.spent += Double(order.priceCash ?? "0") ?? 0
            stationMap[name] = prev
        }
        let topStations = stationMap.values.sorted { $0.count > $1.count || $0.spent > $1.spent }.prefix(5)

        let monthlyStats = computeMonthlyStats(orders)

        return NIOServiceSummary(
            total: orders.count,
            byType: byType,
            swapCompleted: swapCompleted.count,
            swapCancelled: swapCancelled.count,
            swapSpent: swapSpent,
            swapAvgSpent: swapCompleted.isEmpty ? 0 : swapSpent / Double(swapCompleted.count),
            upgradeCount: upgradeOrders.count,
            upgradeCompleted: upgradeCompleted.count,
            upgradeCancelled: upgradeCancelled.count,
            upgradeSpent: upgradeSpent,
            upgradeAvgSpent: upgradeCompleted.isEmpty ? 0 : upgradeSpent / Double(upgradeCompleted.count),
            upgradeDayCount: upgradeDayCount,
            upgradeMonthCount: upgradeMonthCount,
            lastOrderTime: orders.first?.createTime,
            topSwapStations: Array(topStations),
            monthlyStats: monthlyStats,
            orders: orders
        )
    }

    static func computeMonthlyStats(_ orders: [NIOServiceOrder]) -> [NIOMonthlyStat] {
        let cal = Calendar(identifier: .gregorian)
        var byMonth: [String: [NIOServiceOrder]] = [:]

        for order in orders {
            guard order.createTime > 0 else { continue }
            let date = Date(timeIntervalSince1970: TimeInterval(order.createTime) / 1000.0)
            let comps = cal.dateComponents([.year, .month], from: date)
            guard let y = comps.year, let m = comps.month else { continue }
            let key = String(format: "%04d-%02d", y, m)
            byMonth[key, default: []].append(order)
        }

        var results: [NIOMonthlyStat] = []
        for (key, monthOrders) in byMonth {
            let parts = key.split(separator: "-")
            let y = parts.first ?? ""
            let m = parts.last ?? ""
            let label = "\(y) 年 \(Int(m) ?? 0) 月"

            let swapOrders = monthOrders.filter { $0.orderType == "pe_shaman_change" }
            let swapCompleted = swapOrders.filter { isCompletedOrder($0) }
            let swapSpent = swapCompleted.reduce(0.0) { $0 + orderSpentAmount($1) }

            let completedOrders = monthOrders.filter { isCompletedOrder($0) }
            let totalSpent = completedOrders.reduce(0.0) { $0 + orderSpentAmount($1) }

            results.append(NIOMonthlyStat(
                monthKey: key,
                label: label,
                swapCount: swapCompleted.count,
                swapSpent: swapSpent,
                totalOrders: monthOrders.count,
                totalSpent: totalSpent
            ))
        }

        return results.sorted { $0.monthKey > $1.monthKey }
    }
}
