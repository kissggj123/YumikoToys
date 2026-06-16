import WidgetKit
import SwiftUI

struct WidgetSyncData: Codable {
    let petName: String
    let avatar: String
    let startDate: Date
    let totalDays: Double
    let milestones: [WidgetMilestone]
    let proactiveBubbleText: String?
    let appVersion: String
    let displayStyle: String?
}

struct WidgetMilestone: Codable {
    let icon: String
    let label: String
    let date: String
    let countDisplay: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), info: defaultData)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), info: loadData() ?? defaultData)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let data = loadData() ?? defaultData
        let entries = [
            SimpleEntry(date: Date(), info: data)
        ]
        let timeline = Timeline(entries: entries, policy: .after(Date().addingTimeInterval(10)))
        completion(timeline)
    }
    
    private var defaultData: WidgetSyncData {
        WidgetSyncData(
            petName: "兔可可",
            avatar: "🐰",
            startDate: Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 12))!,
            totalDays: 826.936,
            milestones: [
                WidgetMilestone(icon: "🌱", label: "下一个100天", date: "2026-08-29", countDisplay: "(第9个)"),
                WidgetMilestone(icon: "🌿", label: "下一个180天", date: "2026-08-29", countDisplay: "(第5个)")
            ],
            proactiveBubbleText: "你好呀！我是你的智能助理。",
            appVersion: "4.5.1",
            displayStyle: "classic"
        )
    }
    
    private func loadData() -> WidgetSyncData? {
        let fileManager = FileManager.default
        
        let searchPaths: [URL] = [
            fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Lite.YumikoToys")?.appendingPathComponent("widget.json"),
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("com.Lite.YumikoToys/widget.json"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.Lite.YumikoToys/widget.json")
        ].compactMap { $0 }
        
        for fileURL in searchPaths {
            guard fileManager.fileExists(atPath: fileURL.path) else { continue }
            
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(WidgetSyncData.self, from: data)
            } catch {
                continue
            }
        }
        return nil
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let info: WidgetSyncData
}

// MARK: - Gradient Background
struct GradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 12/255, green: 15/255, blue: 45/255),
                    Color(red: 18/255, green: 12/255, blue: 35/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color(red: 0/255, green: 180/255, blue: 255/255).opacity(0.3))
                        .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                        .blur(radius: geo.size.width * 0.25)
                        .position(x: geo.size.width * 0.9, y: geo.size.height * 0.15)
                    
                    Circle()
                        .fill(Color(red: 255/255, green: 50/255, blue: 140/255).opacity(0.25))
                        .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                        .blur(radius: geo.size.width * 0.25)
                        .position(x: geo.size.width * 0.1, y: geo.size.height * 0.85)
                }
            }
            
            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear,
                    Color.black.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let info: WidgetSyncData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(info.avatar)
                    .font(.system(size: 14))
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(info.petName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("v\(info.appVersion)")
                        .font(.system(size: 6, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.03))
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
            
            Spacer(minLength: 6)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.3f", info.totalDays))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                
                Text("天")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.leading, 2)
            
            Spacer(minLength: 6)
            
            if let first = info.milestones.first {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Text(first.icon)
                            .font(.system(size: 7))
                        Text(first.label)
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Text(first.date)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.2))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                )
            }
        }
        .padding(7)
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let info: WidgetSyncData
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(info.avatar)
                        .font(.system(size: 16))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        )
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(info.petName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("v\(info.appVersion)")
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer(minLength: 6)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.3f", info.totalDays))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundColor(.white)
                    
                    Text("天")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.leading, 2)
                
                Spacer(minLength: 4)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 7))
                    Text(info.startDate, style: .timer)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.3))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .trailing, spacing: 0) {
                if let bubble = info.proactiveBubbleText, !bubble.isEmpty {
                    Text(bubble)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.purple.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.purple.opacity(0.45), lineWidth: 0.5)
                        )
                        .multilineTextAlignment(.trailing)
                        .lineLimit(4)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer(minLength: 4)
                
                VStack(alignment: .trailing, spacing: 3) {
                    ForEach(info.milestones.prefix(2), id: \.label) { milestone in
                        HStack(spacing: 3) {
                            Text(milestone.icon)
                                .font(.system(size: 8))
                            Text(milestone.label)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            Text(milestone.countDisplay)
                                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(10)
    }
}

// MARK: - Compact Small Widget
struct CompactSmallWidgetView: View {
    let info: WidgetSyncData

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(info.avatar)
                .font(.system(size: 28))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", info.totalDays))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(.white)
                Text("天")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            Text(info.petName)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }
}

// MARK: - Compact Medium Widget
struct CompactMediumWidgetView: View {
    let info: WidgetSyncData

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(info.avatar)
                    .font(.system(size: 24))
                Text(info.petName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            VStack(alignment: .center, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.3f", info.totalDays))
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundColor(.white)
                    Text("天")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill").font(.system(size: 7))
                    Text(info.startDate, style: .timer)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 2) {
                Text("v\(info.appVersion)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                if let first = info.milestones.first {
                    Text("\(first.icon) \(first.label)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Detailed Small Widget
struct DetailedSmallWidgetView: View {
    let info: WidgetSyncData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(info.avatar).font(.system(size: 12))
                Text(info.petName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("v\(info.appVersion)")
                    .font(.system(size: 6, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.03))
            .cornerRadius(6)

            Spacer(minLength: 4)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.3f", info.totalDays))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(.white)
                Text("天")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer(minLength: 3)

            ForEach(info.milestones.prefix(2), id: \.label) { milestone in
                HStack(spacing: 3) {
                    Text(milestone.icon).font(.system(size: 6))
                    Text(milestone.label)
                        .font(.system(size: 6, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                    Spacer()
                    Text(milestone.countDisplay)
                        .font(.system(size: 6, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            if let bubble = info.proactiveBubbleText, !bubble.isEmpty {
                Spacer(minLength: 3)
                Text(bubble)
                    .font(.system(size: 6, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(7)
    }
}

// MARK: - Detailed Medium Widget
struct DetailedMediumWidgetView: View {
    let info: WidgetSyncData

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Text(info.avatar).font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(info.petName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text("v\(info.appVersion)")
                            .font(.system(size: 6, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.03))
                .cornerRadius(6)

                Spacer(minLength: 4)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.3f", info.totalDays))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundColor(.white)
                    Text("天")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer(minLength: 3)

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill").font(.system(size: 6))
                    Text(info.startDate, style: .timer)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.3))
                .cornerRadius(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 3) {
                if let bubble = info.proactiveBubbleText, !bubble.isEmpty {
                    Text(bubble)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.purple.opacity(0.3))
                        )
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 3)

                ForEach(info.milestones.prefix(3), id: \.label) { milestone in
                    HStack(spacing: 3) {
                        Text(milestone.icon).font(.system(size: 7))
                        Text(milestone.label)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                        Spacer()
                        Text(milestone.countDisplay)
                            .font(.system(size: 6, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(10)
    }
}

struct YumikoWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    private var style: String { entry.info.displayStyle ?? "classic" }

    var body: some View {
        Group {
            if family == .systemMedium {
                switch style {
                case "compact":  CompactMediumWidgetView(info: entry.info)
                case "detailed": DetailedMediumWidgetView(info: entry.info)
                default:         MediumWidgetView(info: entry.info)
                }
            } else {
                switch style {
                case "compact":  CompactSmallWidgetView(info: entry.info)
                case "detailed": DetailedSmallWidgetView(info: entry.info)
                default:         SmallWidgetView(info: entry.info)
                }
            }
        }
        .containerBackground(for: .widget) {
            GradientBackground()
        }
    }
}

@main
struct YumikoWidget: Widget {
    let kind: String = "YumikoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            YumikoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("兔可可的相伴桌面")
        .description("展示您和宠物相伴的累计天数与心智里程碑。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
