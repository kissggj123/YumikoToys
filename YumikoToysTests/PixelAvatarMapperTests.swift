//
//  PixelAvatarMapperTests.swift
//  YumikoToysTests
//
//  像素头像映射器测试
//

import XCTest
@testable import YumikoToys

final class PixelAvatarMapperTests: XCTestCase {

    // MARK: - 已有 6 种动物映射测试

    func testLookupRabbit() {
        let result = PixelAvatarMapper.lookup("🐰")
        XCTAssertNotNil(result.pixels.first, "🐰 应该有对应的像素数据")
        XCTAssertEqual(result.pixels.count, 16, "像素矩阵应为 16 行")
        XCTAssertEqual(result.pixels[0].count, 16, "像素矩阵应为 16 列")
        XCTAssertTrue(result.palette.count > 0, "调色板不应为空")
    }

    func testLookupCat() {
        let result = PixelAvatarMapper.lookup("🐱")
        XCTAssertNotNil(result.pixels.first, "🐱 应该有对应的像素数据")
    }

    func testLookupFox() {
        let result = PixelAvatarMapper.lookup("🦊")
        XCTAssertNotNil(result.pixels.first, "🦊 应该有对应的像素数据")
    }

    func testLookupBear() {
        let result = PixelAvatarMapper.lookup("🐻")
        XCTAssertNotNil(result.pixels.first, "🐻 应该有对应的像素数据")
    }

    func testLookupPanda() {
        let result = PixelAvatarMapper.lookup("🐼")
        XCTAssertNotNil(result.pixels.first, "🐼 应该有对应的像素数据")
    }

    func testLookupUnicorn() {
        let result = PixelAvatarMapper.lookup("🦄")
        XCTAssertNotNil(result.pixels.first, "🦄 应该有对应的像素数据")
    }

    // MARK: - 新增 8 种动物映射测试

    func testLookupDog() {
        let result = PixelAvatarMapper.lookup("🐶")
        XCTAssertNotNil(result.pixels.first, "🐶 应该有对应的像素数据")
    }

    func testLookupHamster() {
        let result = PixelAvatarMapper.lookup("🐹")
        XCTAssertNotNil(result.pixels.first, "🐹 应该有对应的像素数据")
    }

    func testLookupFrog() {
        let result = PixelAvatarMapper.lookup("🐸")
        XCTAssertNotNil(result.pixels.first, "🐸 应该有对应的像素数据")
    }

    func testLookupPenguin() {
        let result = PixelAvatarMapper.lookup("🐧")
        XCTAssertNotNil(result.pixels.first, "🐧 应该有对应的像素数据")
    }

    func testLookupParrot() {
        let result = PixelAvatarMapper.lookup("🦜")
        XCTAssertNotNil(result.pixels.first, "🦜 应该有对应的像素数据")
    }

    func testLookupTurtle() {
        let result = PixelAvatarMapper.lookup("🐢")
        XCTAssertNotNil(result.pixels.first, "🐢 应该有对应的像素数据")
    }

    func testLookupFish() {
        let result = PixelAvatarMapper.lookup("🐟")
        XCTAssertNotNil(result.pixels.first, "🐟 应该有对应的像素数据")
    }

    func testLookupLizard() {
        let result = PixelAvatarMapper.lookup("🦎")
        XCTAssertNotNil(result.pixels.first, "🦎 应该有对应的像素数据")
    }

    func testLookupPawPrint() {
        let result = PixelAvatarMapper.lookup("🐾")
        XCTAssertNotNil(result.pixels.first, "🐾 应该有对应的像素数据")
    }

    // MARK: - 回退测试

    func testLookupUnknownEmojiFallsBackToPawPrint() {
        let result = PixelAvatarMapper.lookup("🚀")
        let pawResult = PixelAvatarMapper.lookup("🐾")
        XCTAssertEqual(result.pixels, pawResult.pixels, "未知 Emoji 应回退到爪印像素数据")
    }

    func testLookupEmptyStringFallsBackToPawPrint() {
        let result = PixelAvatarMapper.lookup("")
        let pawResult = PixelAvatarMapper.lookup("🐾")
        XCTAssertEqual(result.pixels, pawResult.pixels, "空字符串应回退到爪印像素数据")
    }

    // MARK: - 数据完整性测试

    func testAllMappingsHaveValidDimensions() {
        let allEmojis = ["🐰", "🐱", "🐶", "🐹", "🐻", "🐼", "🦊", "🐸", "🐧", "🦜", "🐢", "🐟", "🦎", "🐾"]
        for emoji in allEmojis {
            let result = PixelAvatarMapper.lookup(emoji)
            XCTAssertEqual(result.pixels.count, 16, "\(emoji) 像素矩阵应为 16 行")
            for (rowIdx, row) in result.pixels.enumerated() {
                XCTAssertEqual(row.count, 16, "\(emoji) 第\(rowIdx)行应为 16 列")
            }
            XCTAssertTrue(result.palette.count > 0, "\(emoji) 调色板不应为空")
        }
    }

    func testPixelValuesWithinPaletteRange() {
        let allEmojis = ["🐰", "🐱", "🐶", "🐹", "🐻", "🐼", "🦊", "🐸", "🐧", "🦜", "🐢", "🐟", "🦎", "🐾"]
        for emoji in allEmojis {
            let result = PixelAvatarMapper.lookup(emoji)
            let maxIndex = result.palette.count
            for (rowIdx, row) in result.pixels.enumerated() {
                for (colIdx, value) in row.enumerated() {
                    if value > 0 {
                        XCTAssertLessThanOrEqual(value, UInt8(maxIndex),
                            "\(emoji)[\(rowIdx)][\(colIdx)] 值 \(value) 超出调色板范围 \(maxIndex)")
                    }
                }
            }
        }
    }
}
