//
//  NIOFetchLogView.swift
//  YumikoToys
//
//  NIO 运行日志查看
//

import SwiftUI

struct NIOFetchLogView: View {
    let themeColor: ThemeColor
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("运行与诊断日志")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeColor.animeOrTextPrimary)
                Spacer()
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding([.top, .horizontal], 10)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(NIOService.shared.fetchLogs.reversed()) { entry in
                        logRow(entry)
                    }
                    if NIOService.shared.fetchLogs.isEmpty {
                        Text("暂无日志")
                            .font(.system(size: 10))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                    }
                }
                .padding(10)
            }
        }
        .background(themeColor.animeOrBackground)
    }

    private func logRow(_ entry: NIOFetchLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconFor(entry.category))
                    .font(.system(size: 9))
                    .foregroundStyle(colorForLevel(entry.level))
                Text(entry.message)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(themeColor.animeOrTextPrimary)
                Spacer()
                Text(timeStr(entry.timestamp))
                    .font(.system(size: 7))
                    .foregroundStyle(themeColor.animeOrTextSecondary)
            }
            if let url = entry.requestURL, !url.isEmpty {
                Text("[\(entry.requestMethod ?? "GET")] \(url)")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(themeColor.animeOrTextSecondary)
                    .lineLimit(2)
            }
            if let status = entry.statusCode {
                Text("HTTP \(status)")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(status == 200 ? .green : .red)
            }
            if let detail = entry.detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 7))
                    .foregroundStyle(.red)
            }
            if let preview = entry.responsePreview, !preview.isEmpty {
                Text(preview)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(themeColor.animeOrTextSecondary)
                    .lineLimit(3)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(themeColor.animeOrCardBackground))
    }

    private func iconFor(_ category: String) -> String {
        switch category {
        case "vehicle": return "car.fill"
        case "change": return "bolt.fill"
        case "checkin": return "calendar.badge.clock"
        default: return "doc.text"
        }
    }

    private func colorForLevel(_ level: String) -> Color {
        switch level {
        case "error": return .red
        case "warning": return .orange
        default: return themeColor.animeOrAccent
        }
    }

    private func timeStr(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: date)
    }
}
