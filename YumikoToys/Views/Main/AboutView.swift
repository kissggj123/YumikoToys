//
//  AboutView.swift
//  YumikoToys
//
//  关于页面视图（v4.0.0 - Dramatis Personae）
//

import SwiftUI

struct AboutView: View {
    @State private var isIconHovered = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // 应用图标
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "FF6B9D").opacity(0.15),
                                    Color(hex: "C44FE2").opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(isIconHovered ? 1.05 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isIconHovered)

                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(
                            color: Color(hex: "FF6B9D").opacity(0.4),
                            radius: isIconHovered ? 20 : 12,
                            x: 0,
                            y: isIconHovered ? 8 : 4
                        )

                    if let customImage = NSImage(named: "YumikoToys") {
                        Image(nsImage: customImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                    } else {
                        Image(systemName: "rabbit.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .onHover { isIconHovered = $0 }

                // 应用名称与版本
                VStack(spacing: 6) {
                    Text(AppConfig.appName)
                        .font(.system(size: 26, weight: .bold, design: .rounded))

                    HStack(spacing: 6) {
                        Text("v\(AppConfig.version)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "FF6B9D"), Color(hex: "C44FE2")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )

                        Text("Build \(AppConfig.buildNumber)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }

                // 主描述
                AboutTextCard {
                    VStack(spacing: 12) {
                        Text("🐷让你合盖状态下也可以为资👦本👧家输出劳动力")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("此工具基于 YumikoToys 🐰可可皇后AI 的粉色钻石魔力实现，没有什么用的小工具。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }

                // 图标说明
                AboutSectionCard(title: "图标说明") {
                    HStack(spacing: 20) {
                        IconLegendItem(emoji: "🐰", label: "兔兔图标", description: "关闭状态")
                        IconLegendItem(emoji: "😴", label: "睡觉的兔兔图标", description: "开启状态")
                    }
                }

                // Dramatis Personae
                AboutSectionCard(title: "Dramatis Personae", subtitle: "或曰：铸就此杰作之功勋名录") {
                    VStack(alignment: .leading, spacing: 14) {
                        CreditsRow(
                            title: "The Grand Artificer",
                            subtitle: "那位伟大的工匠",
                            name: "@泡菜老司机"
                        )
                        CreditsRow(
                            title: "The Limner of the Sigil",
                            subtitle: "徽记的描绘者",
                            name: "@会拧头的ruarua怪"
                        )
                        CreditsRow(
                            title: "The Muse of Whimsy",
                            subtitle: "奇思的缪斯",
                            name: "@cici 的胡扯"
                        )
                        CreditsRow(
                            title: "The Patron of New Marvels",
                            subtitle: "新奇的赞助人",
                            name: "@🐰可可"
                        )
                    }
                }

                // 致谢
                AboutSectionCard(title: "A Note of Gratitude Most Profound", subtitle: "致以最深沉的谢意") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("吾辈亦向此众友献上敬意：")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)

                        Text("@saya.ka, @sayu, @さおり")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(hex: "FF6B9D"))

                        Text("汝等之光，亦使此剧增辉。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }

                // 命运的信使
                AboutSectionCard(title: "A Wyrd Messenger", subtitle: "命运的信使") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("如荒野上之回响，自迷雾中而来，其低语之建言，足以扭转吾辈大业之航向者，乃")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)

                        Text("@小汐shio")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "C44FE2"))

                        Text("也。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                // 底部版权
                VStack(spacing: 4) {
                    Text("© 2026 YumikoToys. All rights reserved.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Text("Made with 🐰 兔可可")
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                }
                .padding(.top, 4)
            }
            .padding(28)
        }
        .frame(minWidth: 420, idealWidth: 460, maxWidth: 520)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                EllipticalGradient(
                    stops: [
                        .init(color: Color(hex: "FF6B9D").opacity(0.06), location: 0.0),
                        .init(color: Color(hex: "C44FE2").opacity(0.03), location: 0.5),
                        .init(color: .clear, location: 0.8)
                    ],
                    center: .top,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.9
                )
            }
        )
    }
}

// MARK: - 文本卡片

private struct AboutTextCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

// MARK: - 分区卡片

private struct AboutSectionCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }

            Divider()
                .background(Color.primary.opacity(0.08))

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 图标说明项

private struct IconLegendItem: View {
    let emoji: String
    let label: String
    let description: String

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

// MARK: - 致敬行

private struct CreditsRow: View {
    let title: String
    let subtitle: String
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "5856D6"))

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.leading, 4)
        }
    }
}

#Preview {
    AboutView()
        .frame(height: 800)
}
