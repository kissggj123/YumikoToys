//
//  WidgetSyncDataTests.swift
//  YumikoToysTests
//
//  时间分量推断 & 主题色（totalHours / hoursPart / minutesPart / secondsPart / themePrimaryHex）
//

import XCTest
@testable import YumikoToys

final class WidgetSyncDataTests: XCTestCase {

    // MARK: - 时间分量推断

    func testDeriveTimeParts_整小时() {
        let parts = WidgetSyncData.deriveTimeParts(from: 2.5)
        // 2.5 天 = 60 小时 = 60h 0m 0s
        XCTAssertEqual(parts.totalHours, 60, accuracy: 1e-6)
        XCTAssertEqual(parts.hoursPart, 60)
        XCTAssertEqual(parts.minutesPart, 0)
        XCTAssertEqual(parts.secondsPart, 0)
    }

    func testDeriveTimeParts_含分秒() {
        // 0.01 天 = 14.4 分 = 14 分 24 秒 = 0h 14m 24s
        let parts = WidgetSyncData.deriveTimeParts(from: 0.01)
        XCTAssertEqual(parts.totalHours, 0.24, accuracy: 1e-6)
        XCTAssertEqual(parts.hoursPart, 0)
        XCTAssertEqual(parts.minutesPart, 14)
        // secondsPart 是 floor((totalHours - hoursPart*1 - minutesPart/60) * 3600)
        // totalHours = 0.24; 0.24*3600 - 14*60 = 864 - 840 = 24
        XCTAssertEqual(parts.secondsPart, 24)
    }

    func testDeriveTimeParts_四舍五入稳定性() {
        // 1 天 精确值
        let parts = WidgetSyncData.deriveTimeParts(from: 1.0)
        XCTAssertEqual(parts.hoursPart, 24)
        XCTAssertEqual(parts.minutesPart, 0)
        XCTAssertEqual(parts.secondsPart, 0)
    }

    // MARK: - 编码 & 解码（版本兼容性）

    func testRoundTripEncodeDecode() {
        let milestone = WidgetMilestone(
            icon: "🌱",
            title: "100天",
            subtitle: "里程碑",
            dateString: "2025-08-29",
            countText: "(第 1 个)"
        )
        let data = WidgetSyncData(
            petName: "兔可可",
            avatar: "🐰",
            startDate: Date(timeIntervalSince1970: 0),
            totalDays: 123.456,
            milestones: [milestone],
            proactiveBubbleText: "你好呀~",
            appVersion: "1.0.0",
            displayStyle: "classic",
            totalHours: 2962.944,
            hoursPart: 2962,
            minutesPart: 56,
            secondsPart: 38,
            themePrimaryHex: "#FF7A8A"
        )

        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(data)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(WidgetSyncData.self, from: jsonData)

            XCTAssertEqual(decoded.schemaVersion, 1)
            XCTAssertEqual(decoded.petName, "兔可可")
            XCTAssertEqual(decoded.avatar, "🐰")
            XCTAssertEqual(decoded.totalDays, 123.456, accuracy: 1e-6)
            XCTAssertEqual(decoded.displayStyle, "classic")
            XCTAssertEqual(decoded.themePrimaryHex, "#FF7A8A")
            XCTAssertEqual(decoded.milestones.count, 1)
            XCTAssertEqual(decoded.milestones.first?.title, "100天")
            XCTAssertEqual(decoded.hoursPart, 2962)
            XCTAssertEqual(decoded.minutesPart, 56)
            XCTAssertEqual(decoded.secondsPart, 38)
            XCTAssertEqual(decoded.appVersion, "1.0.0")
        } catch {
            XCTFail("编码/解码失败: \(error)")
        }
    }

    // MARK: - sample() 预览数据不为空

    func testSamplePreviewData() {
        let sample = WidgetSyncData.sample()
        XCTAssertFalse(sample.petName.isEmpty)
        XCTAssertEqual(sample.displayStyle, "classic")
        XCTAssertFalse(sample.milestones.isEmpty)
        // sample 必须有合法主题色
        XCTAssertFalse(sample.themePrimaryHex.isEmpty)
    }
}
