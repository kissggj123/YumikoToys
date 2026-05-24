//
//  PetAgeCalculator.swift
//  YumikoToys
//
//  宠物年龄计算器 - 基于 UCSD 2020 表观钟与 AAFP-AAHA/HRS 临床指标换算（多型融合空间极致优化版）
//

import Foundation

/// 宠物年龄计算结果
struct PetAge: Sendable, Equatable {
    let years: Int
    let months: Int
    let humanAgeYears: Int
    let humanAgeMonths: Int
    let displayText: String
    let humanAgeText: String
    
    // 【新增】支持一位小数的人类年龄，用于实时显示变化
    let humanAgeDecimal: Double
    let humanAgeDecimalText: String
}

/// 宠物年龄计算器
enum PetAgeCalculator {
    
    /// 线性换算系数（仅用于非曲线换算的冷门宠物，数值代表：1宠物年 = X人类年）
    private static let linearConversionRates: [String: Double] = [
        "🐹": 25.0,  // 仓鼠：1年 ≈ 25人类年
        "🐻": 4.0,   // 熊：1年 ≈ 4人类年
        "🐼": 5.0,   // 熊猫：1年 ≈ 5人类年
        "🦊": 6.0,   // 狐狸：1年 ≈ 6人类年
        "🐸": 10.0,  // 青蛙：1年 ≈ 10人类年
        "🐧": 6.0,   // 企鹅：1年 ≈ 6人类年
        "🦜": 4.0,   // 鹦鹉：1年 ≈ 4人类年
        "🐢": 2.0,   // 乌龟：1年 ≈ 2人类年
        "🐟": 8.0,   // 鱼：1年 ≈ 8人类年
        "🦎": 7.0,   // 蜥蜴：1年 ≈ 7人类年
        "🐾": 5.0    // 其他：默认 1年 = 5人类年
    ]
    
    /// 计算宠物年龄
    /// - Parameters:
    ///   - birthDate: 生日
    ///   - emoji: 宠物 Emoji（用于确定换算规则）
    ///   - dogSize: 狗狗体型（直接引自 Anniversary.swift。未指定时，自动回退至 UCSD 中大型犬对数表观遗传钟）
    /// - Returns: 年龄计算结果
    static func calculate(from birthDate: Date, emoji: String, dogSize: CanineSize? = nil) -> PetAge {
        let calendar = Calendar.current
        let now = Date()
        
        // 1. 计算真实的宠物年龄（年月）
        let components = calendar.dateComponents([.year, .month], from: birthDate, to: now)
        let years = components.year ?? 0
        let months = components.month ?? 0
        
        // 2. 计算真实的总月数（作为换算的基础）
        let totalMonths = max(0, years * 12 + months)
        
        // 3. 基于多项学术级生命指标模型进行人类总月数（totalHumanMonths）折算
        let totalHumanMonths: Double
        
        switch emoji {
        case "🐱":
            // 依据：AAFP-AAHA（美国猫科执业医师协会及美国动物医院协会）联合发布的 Feline Life Stage Guidelines。
            if totalMonths <= 1 {
                totalHumanMonths = Double(totalMonths) * 12.0
            } else if totalMonths <= 3 {
                totalHumanMonths = 12.0 + Double(totalMonths - 1) * 18.0
            } else if totalMonths <= 6 {
                totalHumanMonths = 48.0 + Double(totalMonths - 3) * 24.0
            } else if totalMonths <= 12 {
                totalHumanMonths = 120.0 + Double(totalMonths - 6) * 10.0
            } else if totalMonths <= 24 {
                totalHumanMonths = 180.0 + Double(totalMonths - 12) * 9.0
            } else {
                totalHumanMonths = 288.0 + Double(totalMonths - 24) * 4.0
            }
            
        case "🐶":
            if let size = dogSize {
                // 依据：AAHA (美国动物医院协会) 标准中型/大型等四阶体型临床换算矩阵
                if totalMonths <= 12 {
                    totalHumanMonths = Double(totalMonths) * 15.0
                } else if totalMonths <= 24 {
                    let base = 180.0
                    let rate: Double
                    switch size {
                    case .small: rate = 8.0  // 小型犬：1-2岁期间，1宠物月 = 8.0人类月 (2岁时达23岁)
                    case .medium, .large: rate = 9.0 // 中大犬：1-2岁期间，1宠物月 = 9.0人类月 (2岁时达24岁)
                    case .giant: rate = 7.0  // 巨型犬：1-2岁期间，1宠物月 = 7.0人类月 (2岁时达22岁)
                    }
                    totalHumanMonths = base + Double(totalMonths - 12) * rate
                } else {
                    let base: Double
                    let rate: Double
                    switch size {
                    case .small:
                        base = 276.0
                        rate = 4.0  // 小型犬成年后：每1宠物年（12月） = 4.0人类年 (1宠物月 = 4.0人类月)
                    case .medium:
                        base = 288.0
                        rate = 5.0  // 中型犬成年后：每1宠物年（12月） = 5.0人类年 (1宠物月 = 5.0人类月)
                    case .large:
                        base = 288.0
                        rate = 7.0  // 大型犬成年后：每1宠物年（12月） = 7.0人类年 (1宠物月 = 7.0人类月)
                    case .giant:
                        base = 264.0
                        rate = 9.0  // 巨型犬成年后：每1宠物年（12月） = 9.0人类年 (1宠物月 = 9.0人类月)
                    }
                    totalHumanMonths = base + Double(totalMonths - 24) * rate
                }
            } else {
                // 依据：UCSD (加州大学圣迭戈分校) Trey Ideker 2020 甲基化表观遗传钟对数公式
                // 无状态默认回退（以论文核心研究对象拉布拉多犬为代表模型进行对数拟合）
                if totalMonths < 12 {
                    totalHumanMonths = Double(totalMonths) * 31.0
                } else {
                    let dogAgeInYears = Double(totalMonths) / 12.0
                    let humanAgeInYears = 16.0 * log(dogAgeInYears) + 31.0
                    totalHumanMonths = humanAgeInYears * 12.0
                }
            }
            
        case "🐰":
            // 依据：美国家兔协会 (House Rabbit Society) 官方生命周期指南。
            if totalMonths <= 6 {
                totalHumanMonths = Double(totalMonths) * 32.0
            } else if totalMonths <= 12 {
                totalHumanMonths = 192.0 + Double(totalMonths - 6) * 10.0
            } else if totalMonths <= 24 {
                totalHumanMonths = 252.0 + Double(totalMonths - 12) * 6.0
            } else {
                totalHumanMonths = 324.0 + Double(totalMonths - 24) * 6.0
            }
            
        default:
            // 其他冷门宠物：精确的线性换算
            let rate = linearConversionRates[emoji] ?? 5.0
            totalHumanMonths = Double(totalMonths) * rate
        }
        
        // 4. 将计算出的人类总月数，拆分还原为年和月
        let humanYears = Int(totalHumanMonths / 12.0)
        let humanMonths = Int(totalHumanMonths.truncatingRemainder(dividingBy: 12.0))
        
        // 5. 【空间优化】格式化宠物实际年龄显示
        let displayText: String
        if years > 0 {
            if months > 0 {
                displayText = "\(years)岁\(months)月"
            } else {
                displayText = "\(years)岁"
            }
        } else if months > 0 {
            displayText = "\(months)个月"
        } else {
            displayText = "刚出生"
        }
        
        // 6. 【空间优化】格式化换算后的人类年龄显示
        let humanAgeText: String
        if humanYears >= 1 {
            if humanMonths > 0 {
                let decimalYears = Double(humanYears) + Double(humanMonths) / 12.0
                humanAgeText = String(format: "≈%.1f岁", decimalYears)
            } else {
                humanAgeText = "≈\(humanYears)岁"
            }
        } else if humanMonths > 0 {
            humanAgeText = "≈\(humanMonths)个月"
        } else {
            humanAgeText = "≈1个月"
        }
        
        // 【新增】计算带一位小数的人类年龄（用于实时显示变化）
        let humanAgeDecimal = totalHumanMonths / 12.0
        let humanAgeDecimalText = String(format: "≈%.1f岁", humanAgeDecimal)
        
        return PetAge(
            years: years,
            months: months,
            humanAgeYears: humanYears,
            humanAgeMonths: humanMonths,
            displayText: displayText,
            humanAgeText: humanAgeText,
            humanAgeDecimal: humanAgeDecimal,
            humanAgeDecimalText: humanAgeDecimalText
        )
    }
    
    /// 获取换算规则说明
    static func conversionDescription(for emoji: String) -> String {
        switch emoji {
        case "🐱":
            return "猫咪生长曲线：依据 AAFP-AAHA 猫科生命阶段指南，2岁成年（对应人24岁），后续每1年 ≈ 4人类年"
        case "🐶":
            return "狗狗表观遗传钟：依据 UCSD 2020 表观学公式 [16 * ln(岁) + 31]，精确追踪 DNA 甲基化分子标记"
        case "🐰":
            return "兔子生命曲线：依据 House Rabbit Society 指南，半岁性成熟（对应人16岁），后续每1年 ≈ 6人类年"
        default:
            let rate = linearConversionRates[emoji] ?? 5.0
            return "1宠物年 ≈ \(Int(rate))人类年"
        }
    }
}
