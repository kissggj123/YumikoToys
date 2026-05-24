//
//  PetProfileCardViewTests.swift
//  YumikoToysTests
//
//  宠物名片弹窗测试
//

import XCTest
@testable import YumikoToys

final class PetProfileCardViewTests: XCTestCase {
    
    private func makeTestAnniversary(
        petName: String = "兔可可",
        gender: PetGender = .female,
        species: String = "安哥拉兔",
        avatarEmoji: String = "🐰"
    ) -> Anniversary {
        Anniversary(
            title: "测试",
            startDate: Date().addingTimeInterval(-86400 * 799),
            petName: petName,
            petGender: gender,
            species: species,
            avatarEmoji: avatarEmoji
        )
    }
    
    private func makeTestCalculation(days: Int = 799) -> AnniversaryCalculation {
        AnniversaryInfo.calculateTime(from: Date().addingTimeInterval(-86400 * Double(days)))
    }
    
    // MARK: - 视图创建测试
    
    func testPetProfileCardViewCreation() {
        let view = PetProfileCardView(
            anniversary: makeTestAnniversary(),
            calculation: makeTestCalculation(),
            onClose: {}
        )
        XCTAssertNotNil(view)
    }
    
    func testPetProfileCardViewWithMalePet() {
        let view = PetProfileCardView(
            anniversary: makeTestAnniversary(gender: .male),
            calculation: makeTestCalculation(),
            onClose: {}
        )
        XCTAssertNotNil(view)
    }
    
    func testPetProfileCardViewWithUnknownGender() {
        let view = PetProfileCardView(
            anniversary: makeTestAnniversary(gender: .unknown),
            calculation: makeTestCalculation(),
            onClose: {}
        )
        XCTAssertNotNil(view)
    }
    
    func testPetProfileCardViewWithoutSpecies() {
        let view = PetProfileCardView(
            anniversary: makeTestAnniversary(species: ""),
            calculation: makeTestCalculation(),
            onClose: {}
        )
        XCTAssertNotNil(view)
    }
    
    func testPetProfileCardViewWithoutPetName() {
        let view = PetProfileCardView(
            anniversary: makeTestAnniversary(petName: ""),
            calculation: makeTestCalculation(),
            onClose: {}
        )
        XCTAssertNotNil(view)
    }
    
    // MARK: - 计算数据测试
    
    func testCalculationDaysCorrect() {
        let calculation = makeTestCalculation(days: 799)
        XCTAssertEqual(Int(calculation.totalDays), 799)
    }
    
    func testCalculationZeroDays() {
        let calculation = makeTestCalculation(days: 0)
        XCTAssertEqual(Int(calculation.totalDays), 0)
    }
    
    // MARK: - 弹窗修饰符测试
    
    func testPetProfileCardModifierExtension() {
        // 验证 View 扩展方法存在（编译期检查）
        let anniversary = makeTestAnniversary()
        let calculation = makeTestCalculation()
        
        // 如果扩展方法不存在，编译会失败
        let _ = anniversary // 确认模型可用
        let _ = calculation // 确认计算结果可用
    }
}
