//
//  PetProfileCardView.swift
//  YumikoToys
//
//  宠物名片弹窗卡片（可爱风格 v2）
//

import SwiftUI

struct PetProfileCardView: View {
    let anniversary: Anniversary
    let calculation: AnniversaryCalculation
    let onClose: () -> Void
    
    @State private var isCloseHovered = false
    @State private var appeared = false
    @State private var floatAnimation = false
    @State private var heartBeatAnimation = false
    
    private var petAge: PetAge {
        PetAgeCalculator.calculate(
            from: anniversary.startDate,
            emoji: anniversary.displayAvatar,
            dogSize: anniversary.dogSize
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部关闭按钮
            HStack {
                // 可爱装饰
                HStack(spacing: 3) {
                    Text("🌸")
                        .font(.system(size: 10))
                        .opacity(0.6)
                    Text("⭐")
                        .font(.system(size: 10))
                        .opacity(0.6)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: 26, height: 26)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isCloseHovered ? Color(hex: "FF6B9D") : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .help("关闭名片")
                .onHover { isCloseHovered = $0 }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            // 1. 可爱头像区
            VStack(spacing: 12) {
                ZStack {
                    // 可爱背景圆
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFE4EC"), Color(hex: "FFD6E8"), Color(hex: "E8D6FF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: Color(hex: "FF6B9D").opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    // 头像
                    PixelAvatarView(emoji: anniversary.displayAvatar, size: 56)
                        .scaleEffect(floatAnimation ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: floatAnimation)
                }

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text(anniversary.displayPetName)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        if let gender = anniversary.petGender {
                            ZStack {
                                if gender.isRainbow {
                                    // 彩虹渐变背景
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(PetGender.rainbowGradient)
                                        .frame(width: 22, height: 22)
                                } else {
                                    // 单色背景
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(gender.color.opacity(0.15))
                                        .frame(width: 22, height: 22)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(gender.color.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                
                                Text(gender.emoji)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(gender.isRainbow ? .white : gender.color)
                            }
                        }
                    }

                    // 可爱物种标签
                    HStack(spacing: 4) {
                        Text("🐾")
                            .font(.system(size: 10))
                        Text(anniversary.species ?? "神秘萌宠")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: "FF6B9D"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(hex: "FF6B9D").opacity(0.1))
                    )
                }
            }
            .padding(.bottom, 16)

            // 2. 可爱年龄卡片
            HStack(spacing: 10) {
                cuteAgeCard(
                    emoji: "🎂",
                    title: "实际年龄",
                    value: petAge.displayText,
                    color: "34C759"
                )

                // 人类年龄卡片（带换算说明按钮）
                humanAgeCardWithInfo
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            // 3. 可爱陪伴时间
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text("💕")
                        .font(.system(size: 12))
                        .scaleEffect(heartBeatAnimation ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: heartBeatAnimation)
                    
                    Text("累计陪伴时间")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Text(calculation.detailedString)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "FF6B9D").opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "FF6B9D").opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            // 4. 可爱档案信息
            VStack(spacing: 10) {
                cuteInfoRow(emoji: "📅", title: "纪念日", value: formatDate(anniversary.startDate))

                if anniversary.displayAvatar == "🐶", let size = anniversary.dogSize {
                    cuteInfoRow(emoji: "📏", title: "体型", value: size.displayName)
                }

                cuteInfoRow(emoji: "⏰", title: "计时模式", value: anniversary.type.displayName)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            // 可爱分割线
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { i in
                    Circle()
                        .fill([Color(hex: "FF6B9D"), Color(hex: "C44FE2"), Color(hex: "22D3EE")][i % 3].opacity(0.25))
                        .frame(width: 4, height: 4)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 16)
        }
        .frame(width: 320, height: 480)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                
                // 可爱背景装饰
                VStack {
                    HStack {
                        Text("🌟")
                            .font(.system(size: 40))
                            .opacity(0.04)
                            .offset(x: -20, y: 20)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("💖")
                            .font(.system(size: 35))
                            .opacity(0.04)
                            .offset(x: 15, y: -15)
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "FF6B9D").opacity(0.35), Color(hex: "C44FE2").opacity(0.25), Color(hex: "22D3EE").opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color(hex: "FF6B9D").opacity(0.12), radius: 25, x: 0, y: 12)
        .scaleEffect(appeared ? 1.0 : 0.9)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: appeared)
        .onAppear {
            appeared = true
            floatAnimation = true
            heartBeatAnimation = true
        }
        .contentShape(Rectangle())
    }

    // MARK: - 可爱年龄卡片

    private func cuteAgeCard(emoji: String, title: String, value: String, color: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: color))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: color).opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: color).opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - 可爱信息行

    private func cuteInfoRow(emoji: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 12))

            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }

    // MARK: - 人类年龄卡片（带信息按钮）

    @State private var showFormulaPopover = false

    private var humanAgeCardWithInfo: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("👤")
                    .font(.system(size: 12))
                Text("人类年龄")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer()

                // 信息按钮
                Button(action: { showFormulaPopover.toggle() }) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "FF9500").opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("查看换算说明")
                .popover(isPresented: $showFormulaPopover, arrowEdge: .top) {
                    formulaPopoverContent
                }
            }

            Text(petAge.humanAgeDecimalText)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "FF9500"))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "FF9500").opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "FF9500").opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - 换算说明 Popover

    private var formulaPopoverContent: some View {
        let formula = PetAgeCalculator.conversionDescription(for: anniversary.displayAvatar)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("📖")
                    .font(.system(size: 14))
                Text("年龄换算说明")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            Divider()

            Text(formula)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
    }
}



#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        PetProfileCardView(
            anniversary: Anniversary(
                title: "测试",
                startDate: Date().addingTimeInterval(-86400 * 799),
                petName: "兔可可",
                petGender: .female,
                species: "安哥拉兔",
                avatarEmoji: "🐰",
                dogSize: nil
            ),
            calculation: AnniversaryInfo.calculateTime(from: Date().addingTimeInterval(-86400 * 799)),
            onClose: {}
        )
    }
}
