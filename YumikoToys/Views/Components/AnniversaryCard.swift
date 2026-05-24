//
//  AnniversaryCard.swift
//  YumikoToys
//
//  纪念日信息卡片组件（Equatable 优化：仅在天数变化时重绘）
//

import SwiftUI

struct AnniversaryCard: View, Equatable {
    let info: AnniversaryInfo
    
    static func == (lhs: AnniversaryCard, rhs: AnniversaryCard) -> Bool {
        lhs.info.calculation.days == rhs.info.calculation.days
    }
    
    @State private var animatedDays: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            headerSection
            Divider().background(Color.white.opacity(0.2))
            milestonesSection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.pink.opacity(0.15), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                animatedDays = info.calculation.totalDays
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "rabbit.fill")
                    .font(.title3)
                    .foregroundStyle(.pink)
                Text(info.anniversary.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.3f", animatedDays))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                Text("天啦")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(info.milestones) { milestone in
                MilestoneRow(milestone: milestone)
            }
        }
    }
}

// MARK: - MilestoneRow（Equatable 优化）

private struct MilestoneRow: View, Equatable {
    let milestone: AnniversaryMilestone
    
    static func == (lhs: MilestoneRow, rhs: MilestoneRow) -> Bool {
        lhs.milestone.id == rhs.milestone.id
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(milestone.icon)
                .font(.title3)
            Text(milestone.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("是 \(milestone.formattedDate) (第\(milestone.count)\(milestone.unit))")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    let anniversary = Anniversary(
        title: "兔可可到来",
        startDate: Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 12))!,
        type: .countUp,
        emoji: "🐰"
    )
    AnniversaryCard(info: AnniversaryInfo.calculate(from: anniversary))
        .padding()
        .frame(width: 400)
}
