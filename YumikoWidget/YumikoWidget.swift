import WidgetKit
import SwiftUI

struct WidgetSyncData: Codable {
    let petName: String
    let avatar: String
    let startDate: Date
    let totalDays: Double
    let milestones: [WidgetMilestone]
    let proactiveBubbleText: String?
}

struct WidgetMilestone: Codable {
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
            totalDays: 826.0,
            milestones: [
                WidgetMilestone(label: "下一个100天", date: "2026-08-29", countDisplay: "(第9个)"),
                WidgetMilestone(label: "下一个180天", date: "2026-08-29", countDisplay: "(第5个)")
            ],
            proactiveBubbleText: "你好呀！我是你的智能助理。"
        )
    }
    
    private func loadData() -> WidgetSyncData? {
        let fileManager = FileManager.default
        
        let searchPaths: [URL] = [
            // 1. App Groups shared container (for properly signed apps)
            fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.Lite.YumikoToys")?.appendingPathComponent("widget.json"),
            // 2. Application Support (for self-signed apps)
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("com.Lite.YumikoToys/widget.json"),
            // 3. Home directory Application Support (fallback)
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

// MARK: - Fluid Background View
struct FluidWidgetBackground: View {
    var body: some View {
        ZStack {
            // Deep cosmic base gradient
            LinearGradient(
                colors: [
                    Color(red: 10/255, green: 14/255, blue: 42/255),
                    Color(red: 16/255, green: 10/255, blue: 32/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Glowing fluid orbs
            GeometryReader { geo in
                ZStack {
                    // Cyan glow top-right
                    Circle()
                        .fill(Color(red: 0/255, green: 180/255, blue: 255/255).opacity(0.35))
                        .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                        .blur(radius: geo.size.width * 0.3)
                        .position(x: geo.size.width * 0.95, y: geo.size.height * 0.1)
                    
                    // Pink/Purple glow bottom-left
                    Circle()
                        .fill(Color(red: 255/255, green: 40/255, blue: 130/255).opacity(0.35))
                        .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                        .blur(radius: geo.size.width * 0.3)
                        .position(x: geo.size.width * 0.05, y: geo.size.height * 0.9)
                }
            }
            
            // Premium glass shine overlay
            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.clear,
                    Color.black.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Small Widget (1:1 Ratio)
struct SmallWidgetView: View {
    let info: WidgetSyncData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Avatar + Title stack
            HStack(spacing: 5) {
                // Avatar box
                Text(info.avatar)
                    .font(.system(size: 15))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(info.petName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("联结发展阶段")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            
            Spacer(minLength: 4)
            
            // Days Counter
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", info.totalDays))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                
                Text("天")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.leading, 4)
            
            Spacer(minLength: 4)
            
            // Next milestone
            if let first = info.milestones.first {
                VStack(alignment: .leading, spacing: 1) {
                    Text(first.label)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\(first.date)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(0.95)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.2))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                )
            }
        }
        .padding(8)
    }
}

// MARK: - Medium Widget (2:1 Ratio)
struct MediumWidgetView: View {
    let info: WidgetSyncData
    
    var body: some View {
        HStack(spacing: 16) {
            // Left Column
            VStack(alignment: .leading, spacing: 0) {
                // Header (Avatar + Title)
                HStack(spacing: 8) {
                    Text(info.avatar)
                        .font(.system(size: 18))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(info.petName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("联结发展阶段")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer(minLength: 4)
                
                // Companion days
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.0f", info.totalDays))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("天")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.leading, 2)
                
                Spacer(minLength: 4)
                
                Divider()
                    .background(Color.white.opacity(0.15))
                    .padding(.bottom, 6)
                
                // Milestones list
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(info.milestones.prefix(2), id: \.label) { milestone in
                        HStack {
                            Text(milestone.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                            Spacer()
                            Text("\(milestone.date) \(milestone.countDisplay)")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right Column (Timer / status)
            VStack(alignment: .trailing, spacing: 0) {
                // Live countup timer capsule
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(info.startDate, style: .timer)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.35))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                
                if let bubble = info.proactiveBubbleText, !bubble.isEmpty {
                    Spacer(minLength: 4)
                    Text(bubble)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.purple.opacity(0.35))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.purple.opacity(0.55), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                } else {
                    Spacer()
                }
            }
        }
        .padding(12)
    }
}

struct YumikoWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if family == .systemMedium {
                MediumWidgetView(info: entry.info)
            } else {
                SmallWidgetView(info: entry.info)
            }
        }
        .containerBackground(for: .widget) {
            FluidWidgetBackground()
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
    }
}
