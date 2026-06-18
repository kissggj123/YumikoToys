import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared Data Model (mirrors the main app's WidgetSyncData)

struct WidgetMilestone: Codable, Identifiable {
    let id: String
    let icon: String
    let label: String
    let date: String
    let countDisplay: String

    enum CodingKeys: String, CodingKey {
        case id, icon, label, date, countDisplay
    }

    init(id: String, icon: String, label: String, date: String, countDisplay: String) {
        self.id = id
        self.icon = icon
        self.label = label
        self.date = date
        self.countDisplay = countDisplay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        self.icon = try container.decode(String.self, forKey: .icon)
        self.label = try container.decode(String.self, forKey: .label)
        self.date = try container.decode(String.self, forKey: .date)
        self.countDisplay = try container.decode(String.self, forKey: .countDisplay)
    }
}

struct WidgetSyncData: Codable {
    let petName: String
    let avatar: String
    let startDate: Date
    let totalDays: Double
    let milestones: [WidgetMilestone]
    let proactiveBubbleText: String?
    let appVersion: String
    let displayStyle: String

    // v2
    let title: String
    let totalHours: Double
    let hoursPart: Int
    let minutesPart: Int
    let secondsPart: Int
    let themePrimaryHex: String

    // 注意：主 App 侧的 WidgetSyncData 多一个 schemaVersion 字段。
    // 主 App 写出的 JSON 一定包含 schemaVersion，若 Widget 端
    // 用 auto-generated decoder 会解码失败。为保持向前兼容，
    // 我们手动解码并主动忽略 schemaVersion 字段。
    enum CodingKeys: String, CodingKey {
        case petName, avatar, startDate, totalDays, milestones,
             proactiveBubbleText, appVersion, displayStyle,
             title, totalHours, hoursPart, minutesPart, secondsPart,
             themePrimaryHex
    }

    // 成员初始化器（供 defaultData 最后回退使用）
    init(petName: String, avatar: String, startDate: Date, totalDays: Double,
         milestones: [WidgetMilestone], proactiveBubbleText: String?,
         appVersion: String, displayStyle: String,
         title: String, totalHours: Double, hoursPart: Int, minutesPart: Int, secondsPart: Int,
         themePrimaryHex: String) {
        self.petName = petName
        self.avatar = avatar
        self.startDate = startDate
        self.totalDays = totalDays
        self.milestones = milestones
        self.proactiveBubbleText = proactiveBubbleText
        self.appVersion = appVersion
        self.displayStyle = displayStyle
        self.title = title
        self.totalHours = totalHours
        self.hoursPart = hoursPart
        self.minutesPart = minutesPart
        self.secondsPart = secondsPart
        self.themePrimaryHex = themePrimaryHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 全部字段用 decodeIfPresent，即使主 App 版本调整也能容错
        self.petName = (try container.decodeIfPresent(String.self, forKey: .petName)) ?? "兔可可"
        self.avatar = (try container.decodeIfPresent(String.self, forKey: .avatar)) ?? "🐰"
        self.startDate = (try container.decodeIfPresent(Date.self, forKey: .startDate)) ?? Date()
        self.totalDays = (try container.decodeIfPresent(Double.self, forKey: .totalDays)) ?? 0.0
        self.milestones = (try container.decodeIfPresent([WidgetMilestone].self, forKey: .milestones)) ?? []
        self.proactiveBubbleText = try container.decodeIfPresent(String.self, forKey: .proactiveBubbleText)
        self.appVersion = (try container.decodeIfPresent(String.self, forKey: .appVersion)) ?? ""
        self.displayStyle = (try container.decodeIfPresent(String.self, forKey: .displayStyle)) ?? "classic"

        // v2 字段，缺省则按 totalDays 推断
        self.title = (try container.decodeIfPresent(String.self, forKey: .title)) ?? "在一起已经"
        if let hours = try container.decodeIfPresent(Double.self, forKey: .totalHours) {
            self.totalHours = hours
            self.hoursPart = try container.decodeIfPresent(Int.self, forKey: .hoursPart) ?? Int(hours)
            self.minutesPart = try container.decodeIfPresent(Int.self, forKey: .minutesPart) ?? 0
            self.secondsPart = try container.decodeIfPresent(Int.self, forKey: .secondsPart) ?? 0
        } else {
            let t = totalDays * 86_400
            self.totalHours = t / 3_600
            self.hoursPart = Int(self.totalHours)
            let remain = t - Double(self.hoursPart) * 3_600
            self.minutesPart = Int(remain / 60)
            self.secondsPart = Int(remain - Double(self.minutesPart) * 60)
        }
        self.themePrimaryHex = (try container.decodeIfPresent(String.self, forKey: .themePrimaryHex)) ?? "FF6B9D"
    }
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), info: defaultData())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date(), info: loadData() ?? defaultData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        var data = loadData() ?? defaultData()
        if let shared = UserDefaults(suiteName: "group.com.Lite.YumikoToys"),
           let styleOverride = shared.string(forKey: "widget_display_style") {
            data = WidgetSyncData(
                petName: data.petName, avatar: data.avatar,
                startDate: data.startDate, totalDays: data.totalDays,
                milestones: data.milestones, proactiveBubbleText: data.proactiveBubbleText,
                appVersion: data.appVersion, displayStyle: styleOverride,
                title: data.title, totalHours: data.totalHours, hoursPart: data.hoursPart,
                minutesPart: data.minutesPart, secondsPart: data.secondsPart,
                themePrimaryHex: data.themePrimaryHex
            )
        }
        let entries = [SimpleEntry(date: Date(), info: data)]
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: entries, policy: .after(nextRefresh))
        completion(timeline)
    }

    private func defaultData() -> WidgetSyncData {
        // 纯占位数据（Widget 首次安装 / 数据尚未写入时的兜底显示）
        // 注意：绝对不使用 fatalError，避免 Widget 崩溃。
        let totalDays: Double = 827.085
        let totalSeconds = totalDays * 86_400
        let totalHours = totalSeconds / 3_600
        let hoursPart = Int(totalHours)
        let remain = totalSeconds - Double(hoursPart) * 3_600
        let minutesPart = Int(remain / 60)
        let secondsPart = Int(remain - Double(minutesPart) * 60)

        let json = """
        {
          "petName":"兔可可","avatar":"🐰",
          "startDate":"2024-03-12T00:00:00Z",
          "totalDays":\(totalDays),
          "milestones":[
            {"icon":"🌱","label":"下一个100天","date":"2026-08-29","countDisplay":"(第9个)"},
            {"icon":"🌿","label":"下一个180天","date":"2026-08-29","countDisplay":"(第5个)"},
            {"icon":"☘️","label":"下一个300天","date":"2026-08-29","countDisplay":"(第3个)"},
            {"icon":"🎉","label":"下一周年","date":"2027-03-12","countDisplay":"(第3周年)"}
          ],
          "proactiveBubbleText":null,
          "appVersion":"4.5.1","displayStyle":"classic",
          "title":"在一起已经","totalHours":\(totalHours),"hoursPart":\(hoursPart),
          "minutesPart":\(minutesPart),"secondsPart":\(secondsPart),
          "themePrimaryHex":"FF6B9D"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = json.data(using: .utf8),
           let v = try? decoder.decode(WidgetSyncData.self, from: data) {
            return v
        }
        // 最严重的回退：手动构造 WidgetSyncData 需要 JSON 解码，所以这里再试一次空的里程碑
        // （理论上上面的硬编码 JSON 不可能失败）
        let fallback = #"{"petName":"兔可可","avatar":"🐰","startDate":"2024-03-12T00:00:00Z","totalDays":\#(totalDays),"milestones":[],"proactiveBubbleText":null,"appVersion":"4.5.1","displayStyle":"classic","title":"在一起已经","totalHours":\#(totalHours),"hoursPart":\#(hoursPart),"minutesPart":\#(minutesPart),"secondsPart":\#(secondsPart),"themePrimaryHex":"FF6B9D"}"#
        if let data = fallback.data(using: .utf8),
           let v = try? decoder.decode(WidgetSyncData.self, from: data) {
            return v
        }
        // 极难到达的路径——用最小字段解码。若仍失败则重走 defaultData，避免无限递归
        assertionFailure("Widget defaultData 构造失败，请检查 JSON 格式")
        return WidgetSyncData(
            petName: "兔可可", avatar: "🐰",
            startDate: Date(timeIntervalSinceReferenceDate: 0),
            totalDays: totalDays,
            milestones: [], proactiveBubbleText: nil,
            appVersion: "4.5.1", displayStyle: "classic",
            title: "在一起已经", totalHours: totalHours, hoursPart: hoursPart,
            minutesPart: minutesPart, secondsPart: secondsPart,
            themePrimaryHex: "FF6B9D"
        )
    }

    private func loadData() -> WidgetSyncData? {
        let fileManager = FileManager.default
        let groupID = "group.com.Lite.YumikoToys"

        // 机制 1：UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: groupID),
           let data = sharedDefaults.data(forKey: "widget_payload"),
           data.count > 0 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let v = try? decoder.decode(WidgetSyncData.self, from: data) {
                return v
            }
        }

        // 机制 2：App Group 容器中的 JSON 文件
        var fileCandidates: [URL] = []
        if let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            fileCandidates.append(container.appendingPathComponent("widget.json"))
        }
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            fileCandidates.append(appSupport.appendingPathComponent("com.Lite.YumikoToys/widget.json"))
        }
        fileCandidates.append(
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/com.Lite.YumikoToys/widget.json")
        )

        for url in fileCandidates {
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                let data = try Data(contentsOf: url)
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

// MARK: - Color Helpers

extension Color {
    /// 将 #RRGGBB / RRGGBB 解析为 Color
    static func hex(_ string: String) -> Color {
        var clean = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard clean.count == 6 else { return Color(red: 1.0, green: 0.42, blue: 0.62) }

        var rgb: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Gradient Background (themed)

struct GradientBackground: View {
    let primaryHex: String

    var body: some View {
        let primary = Color.hex(primaryHex)
        ZStack {
            LinearGradient(colors: [
                primary.opacity(0.85),
                primary.opacity(0.45)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: geo.size.width * 0.75,
                               height: geo.size.width * 0.75)
                        .position(x: geo.size.width * 0.85,
                                  y: geo.size.height * 0.12)
                        .blur(radius: geo.size.width * 0.12)
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: geo.size.width * 0.6,
                               height: geo.size.width * 0.6)
                        .position(x: geo.size.width * 0.15,
                                  y: geo.size.height * 0.85)
                        .blur(radius: geo.size.width * 0.1)
                }
            }
        }
    }
}

// MARK: - Small Widget Views (Classic / Compact / Detailed)

// Classic: 信息均衡 — 头像+宠物名、大号天数、时分秒、1 条里程碑
struct SmallWidgetView_Classic: View {
    let info: WidgetSyncData

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(info.avatar).font(.system(size: 14))
                Text(info.title + " " + info.petName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", info.totalDays))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                Text("天")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            Text(String(format: "%d小时 %d分 %d秒",
                        info.hoursPart, info.minutesPart, info.secondsPart))
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)

            if let first = info.milestones.first {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 2) {
                        Text(first.icon).font(.system(size: 8))
                        Text(first.label)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        Spacer()
                        Text(first.countDisplay)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Text(first.date)
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.28))
                .cornerRadius(5)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
    }
}

// Compact: 极简居中 — 头像、大天数、宠物名，无其他
struct SmallWidgetView_Compact: View {
    let info: WidgetSyncData

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Spacer(minLength: 0)
            Text(info.avatar).font(.system(size: 16))

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(String(format: "%.0f", info.totalDays))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                Text("天")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            Text(info.petName)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }
}

// Detailed: 全信息 — 宠物+标题、小时/分/秒、多条里程碑
struct SmallWidgetView_Detailed: View {
    let info: WidgetSyncData

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(info.avatar).font(.system(size: 10))
                Text(info.title + " " + info.petName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%dh %dm %ds",
                            info.hoursPart, info.minutesPart, info.secondsPart))
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.2f", info.totalDays))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                Text("天")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 1) {
                ForEach(info.milestones.prefix(3), id: \.label) { m in
                    HStack(spacing: 2) {
                        Text(m.icon).font(.system(size: 7))
                        Text(m.label).font(.system(size: 7, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(m.date).font(.system(size: 6, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                        Text(m.countDisplay).font(.system(size: 6, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1.5)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(3)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(8)
    }
}

// MARK: - Medium Widget Views (Classic / Compact / Detailed)

// Classic: 两列 — 左侧宠物+天数+hms，右侧 4 条里程碑
struct MediumWidgetView_Classic: View {
    let info: WidgetSyncData

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(info.avatar).font(.system(size: 14))
                    Text(info.petName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.3f", info.totalDays))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    Text("天")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }

                Text(String(format: "已到来 %d 小时 %d 分 %d 秒",
                            info.hoursPart, info.minutesPart, info.secondsPart))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(info.milestones.prefix(4).enumerated()), id: \.offset) { _, m in
                    HStack(spacing: 4) {
                        Text(m.icon).font(.system(size: 8))
                        Text(m.label)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(m.date)
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                        Text(m.countDisplay)
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.22))
                    .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
    }
}

// Compact: 横向居中极简 — 头像、超大大号天数、宠物名，无里程碑
struct MediumWidgetView_Compact: View {
    let info: WidgetSyncData

    var body: some View {
        HStack(spacing: 14) {
            Text(info.avatar).font(.system(size: 26))

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.0f", info.totalDays))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    Text("天")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                Text(info.petName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
    }
}

// Detailed: 横向全信息 — 宠物+标题，4 条里程碑+日期，hms
struct MediumWidgetView_Detailed: View {
    let info: WidgetSyncData

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(info.avatar).font(.system(size: 12))
                Text(info.petName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%dh %dm %ds",
                            info.hoursPart, info.minutesPart, info.secondsPart))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.2f", info.totalDays))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                Text("天")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 1) {
                ForEach(info.milestones.prefix(4), id: \.label) { m in
                    HStack(spacing: 4) {
                        Text(m.icon).font(.system(size: 8))
                        Text(m.label).font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(m.date).font(.system(size: 7, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                        Text(m.countDisplay).font(.system(size: 7, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.black.opacity(0.22))
                    .cornerRadius(3)
                }
            }
        }
        .padding(10)
    }
}

// MARK: - Entry View Dispatcher (按 displayStyle + widgetFamily 切换)

struct YumikoWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let style = entry.info.displayStyle

        Group {
            switch family {
            case .systemMedium:
                switch style {
                case "compact":  MediumWidgetView_Compact(info: entry.info)
                case "detailed": MediumWidgetView_Detailed(info: entry.info)
                default:         MediumWidgetView_Classic(info: entry.info)
                }
            default:
                switch style {
                case "compact":  SmallWidgetView_Compact(info: entry.info)
                case "detailed": SmallWidgetView_Detailed(info: entry.info)
                default:         SmallWidgetView_Classic(info: entry.info)
                }
            }
        }
        .containerBackground(for: .widget) {
            GradientBackground(primaryHex: entry.info.themePrimaryHex)
        }
    }
}

// MARK: - Widget Bundle (桌面 widget + 控制中心 widget)

@main
struct YumikoWidgetBundle: WidgetBundle {
    var body: some Widget {
        YumikoDesktopWidget()
        YumikoControlWidget()
    }
}

/// 桌面 widget 主体（从原 YumikoWidget 拆出来）
struct YumikoDesktopWidget: Widget {
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

// MARK: - 控制中心 Widget（macOS 14+）
//
// 用户在「控制中心 → 编辑控件」里加进来后会常驻菜单栏。
// 设计目的：让用户从菜单栏快速看到"和兔可可在一起了 X 天"，
//           点击后能跳到主 App 或触发 AppIntent。
//
// 实现要求：
//   1) widget bundle 包含一个 ControlWidget（用 WidgetBundle 组合）
//   2) AppIntent 用于响应点击事件（写 App Group 标志位，主 App 监听到就执行动作）
//   3) 数据源用 WidgetSyncData 同一份（共享 App Group）
//   4) Info.plist 不需要新增 NSExtensionPointIdentifier，因为 controlcenter-widget
//      是从 widget bundle 自动识别的（widget 自身有 App Group 即可）

/// 控制中心 widget 用的 AppIntent：点一下打开主 App
/// SDK 27+ 的 `OpenIntent` 协议签名已变更（需要 `Value` 关联类型 + `target` 属性），
/// 直接用更宽松的 `AppIntent` 协议 + `openAppWhenRun = true` 是最稳的写法，
/// 既能复用 `ControlWidgetButton` 的 `OpenIntent` 初始化器，也不会因 SDK 升级再次破坏。
struct OpenYumikoToysIntent: AppIntent {
    static var title: LocalizedStringResource = "打开 YumikoToys"
    static var description = IntentDescription("点按后启动主 App")

    /// 触发方式：点击后会自动拉起主 App
    static var openAppWhenRun: Bool { return true }

    func perform() async throws -> some IntentResult {
        // 标记"用户从控制中心点过"，让主 App 启动后能感知
        if let shared = UserDefaults(suiteName: "group.com.Lite.YumikoToys") {
            shared.set(Date().timeIntervalSince1970, forKey: "control_center_open_at")
        }
        return .result()
    }
}

/// 控制中心 widget 主体
struct YumikoControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "YumikoControlCenterWidget") {
            ControlWidgetButton(action: OpenYumikoToysIntent()) {
                let info = loadWidgetData()
                VStack(alignment: .center, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(info.avatar).font(.system(size: 16))
                        Text(String(format: "%.0f", info.totalDays))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                        Text("天")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    Text(info.petName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(2)
            }
        }
        .displayName("兔可可的相伴")
        .description("在控制中心直接看到你和宠物相伴的天数。")
    }
}

/// 简单的同步加载（控制中心 widget 必须极快返回，所以失败就退到默认值）
private func loadWidgetData() -> WidgetSyncData {
    if let shared = UserDefaults(suiteName: "group.com.Lite.YumikoToys"),
       let data = shared.data(forKey: "widget_payload"),
       data.count > 0 {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let v = try? decoder.decode(WidgetSyncData.self, from: data) {
            return v
        }
    }
    // 兜底
    return WidgetSyncData(
        petName: "兔可可", avatar: "🐰",
        startDate: Date(timeIntervalSinceReferenceDate: 0),
        totalDays: 827.0,
        milestones: [], proactiveBubbleText: nil,
        appVersion: "", displayStyle: "compact",
        title: "在一起已经", totalHours: 19848, hoursPart: 19848,
        minutesPart: 0, secondsPart: 0,
        themePrimaryHex: "FF6B9D"
    )
}
