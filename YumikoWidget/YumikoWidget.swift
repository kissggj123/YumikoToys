import WidgetKit
import SwiftUI

struct WidgetSyncData: Codable {
    let petName: String
    let avatar: String
    let startDate: Date
    let totalDays: Double
    let milestones: [WidgetMilestone]
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
            totalDays: 824.0,
            milestones: [
                WidgetMilestone(label: "下一个100天", date: "2026-08-29", countDisplay: "(第9个)")
            ]
        )
    }
    
    private func loadData() -> WidgetSyncData? {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let fileURL = appSupportURL.appendingPathComponent("com.Lite.YumikoToys/widget.json")
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WidgetSyncData.self, from: data)
        } catch {
            return nil
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let info: WidgetSyncData
}

struct YumikoWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(entry.info.avatar)
                    .font(.system(size: family == .systemMedium ? 24 : 20))
                    .frame(width: family == .systemMedium ? 36 : 28, height: family == .systemMedium ? 36 : 28)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.info.petName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("联结发展阶段")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if family == .systemMedium {
                    Text(entry.info.startDate, style: .timer)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(String(format: "%.0f", entry.info.totalDays))
                    .font(.system(size: family == .systemMedium ? 36 : 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 255/255, green: 107/255, blue: 157/255))
                
                Text("天")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, family == .systemMedium ? 6 : 4)
            }
            
            if family == .systemMedium {
                if !entry.info.milestones.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(entry.info.milestones.prefix(2), id: \.label) { milestone in
                            HStack {
                                Text(milestone.label)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(milestone.date) \(milestone.countDisplay)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            } else {
                if let milestone = entry.info.milestones.first {
                    Text("\(milestone.label): \(milestone.date)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .containerBackground(Color(red: 30/255, green: 30/255, blue: 46/255), for: .widget)
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
