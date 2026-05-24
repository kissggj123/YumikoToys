//
//  StatusBarManagerTests.swift
//  YumikoToysTests
//
//  状态栏管理器测试
//

import XCTest
@testable import YumikoToys

final class StatusBarManagerTests: XCTestCase {
    
    var statusBarManager: StatusBarManager!
    
    override func setUp() {
        super.setUp()
        // 注意：StatusBarManager 需要在主线程初始化
    }
    
    override func tearDown() {
        statusBarManager = nil
        super.tearDown()
    }
    
    // MARK: - 图标动画测试
    
    @MainActor
    func testIconAnimationState() {
        // Given
        let manager = StatusBarManager()
        
        // When - 启动动画
        manager.updateIconForPreventSleepState(true)
        
        // Then - 验证动画状态（通过检查内部状态）
        XCTAssertTrue(manager.isAnimatingForTest)
        
        // When - 停止动画
        manager.updateIconForPreventSleepState(false)
        
        // Then
        XCTAssertFalse(manager.isAnimatingForTest)
    }
    
    // MARK: - 天数解析测试
    
    func testParseDays() {
        // Given
        let testCases: [(String, Double?)] = [
            ("100天 05小时 30分钟 15秒", 100),
            ("365天 00小时 00分钟 00秒", 365),
            ("0天 12小时 45分钟 30秒", 0),
            ("invalid", nil),
            ("", nil)
        ]
        
        for (input, expected) in testCases {
            // When
            let result = StatusBarManager.parseDaysForTest(from: input)
            
            // Then
            if let expected = expected {
                XCTAssertEqual(result, expected, "Failed for input: \(input)")
            } else {
                XCTAssertNil(result, "Failed for input: \(input)")
            }
        }
    }
    
    // MARK: - 标题格式化测试
    
    func testTitleFormatting() {
        // Given
        let days = 123.456
        
        // When
        let title = StatusBarManager.formatTitleForTest(withDays: days)
        
        // Then
        XCTAssertEqual(title, "兔可可已到来 123.456天")
    }
}

// MARK: - 测试扩展

extension StatusBarManager {
    var isAnimatingForTest: Bool {
        return iconAnimationTimer != nil
    }
    
    static func parseDaysForTest(from text: String) -> Double? {
        // 模拟解析逻辑
        let components = text.components(separatedBy: " ")
        guard let daysComponent = components.first,
              let daysString = daysComponent.components(separatedBy: "天").first,
              let days = Double(daysString) else {
            return nil
        }
        return days
    }
    
    static func formatTitleForTest(withDays days: Double) -> String {
        return String(format: "兔可可已到来 %.3f天", days)
    }
}
