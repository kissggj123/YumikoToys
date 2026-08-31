//
//  NIODashboardView.swift
//  YumikoToys
//
//  蔚来车辆全功能看板（移植自 NIO-Dash，无主线程阻塞，全功能组件套件）
//

import SwiftUI
import Charts
import MapKit

struct NIODashboardView: View {
    let themeColor: ThemeColor
    @ObservedObject private var service = NIOService.shared
    @State private var showLogs = false
    @State private var rawJSONTitle: String = ""
    @State private var rawJSONContent: String?
    @State private var selectedDayIndex = 0
    @State private var trendPreset = 60
    @State private var expandedOrderId: String?

    private var status: NIOVehicleStatus? { service.vehicleData?.data?.status }
    private var settings: AppSettings { DependencyContainer.shared.settingsService.settings }
    private var hiddenCards: Set<String> {
        Set(settings.nioHiddenCards)
    }

    var body: some View {
        ZStack {
            themeColor.animeOrBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    headerBar

                    if service.is403Detected {
                        error403Banner
                    }

                    if !service.isConfigured {
                        notConfiguredView
                    } else {
                        // 车辆顶部展示图
                        vehicleHeroBanner

                        if !hiddenCards.contains("battery") { batteryCard }
                        efficiencyCard
                        maintenanceCard
                        if !hiddenCards.contains("doors_visual") { doorsVisualCard }
                        windowsCard
                        drivingParkingCard
                        if !hiddenCards.contains("tyre") { tyreGridCard }
                        if !hiddenCards.contains("cockpit") { cockpitGridCard }
                        seatComfortCard
                        keySensorsCard
                        if !hiddenCards.contains("special") { specialStatesCard }
                        lightsCard

                        ordersSection
                        checkinCard
                        dailyPathCard
                        trendChartsCard
                        fetchLogButton
                    }
                }
                .padding(14)
            }

            // 内联日志查看层（避免 AppKit NSPopover Sheet 锁死问题）
            if showLogs {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 0) {
                    NIOFetchLogView(themeColor: themeColor, onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) { showLogs = false }
                    })
                }
                .background(themeColor.animeOrBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(8)
                .transition(.scale.combined(with: .opacity))
            }

            // 内联原始 JSON 查看层
            if let json = rawJSONContent {
                Color.black.opacity(0.4).ignoresSafeArea()
                NIORawJSONView(themeColor: themeColor, title: rawJSONTitle, jsonText: json) {
                    rawJSONContent = nil
                }
                .background(themeColor.animeOrBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            service.startScheduling()
        }
    }

    // MARK: - 顶部栏

    private var headerBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image("NIO_brand")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())

                Text("蔚来看板")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor.animeOrTextPrimary)

                if let last = service.lastVehicleFetch {
                    Text(NIOVehicleLib.fmtTime(Int(last.timeIntervalSince1970 * 1000)))
                        .font(.system(size: 8))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                }
            }
            Spacer()

            HStack(spacing: 2) {
                Button(action: { service.refreshAll() }) {
                    Image(systemName: service.isLoadingVehicle ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(themeColor.animeOrAccent)
                        .rotationEffect(.degrees(service.isLoadingVehicle ? 360 : 0))
                        .animation(service.isLoadingVehicle ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: service.isLoadingVehicle)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(service.isLoadingVehicle)

                Button(action: { NIOConfigWindowManager.shared.open(themeColor: themeColor) }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showLogs = true } }) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 车辆 Hero 横幅

    private var vehicleHeroBanner: some View {
        let socVal = status?.socStatus?.soc ?? 0.0
        let actualRange = status?.socStatus?.remainingActualRange ?? 0.0
        let nominalRange = status?.socStatus?.remainingRange ?? 0.0
        let preferActual = settings.nioPreferActualRange
        let displayRange: Double = {
            if preferActual && actualRange > 0 {
                return actualRange
            }
            if let best = NIOVehicleLib.bestRange(cltcKm: nominalRange > 0 ? nominalRange : nil, actualKm: actualRange > 0 ? actualRange : nil) {
                return preferActual ? Double(best.km) : (nominalRange > 0 ? nominalRange : Double(best.km))
            }
            return actualRange > 0 ? actualRange : nominalRange
        }()
        let offcar = status?.offcarModeStatus ?? [:]
        let isRealCharging = NIOVehicleLib.isRealCharging(socStatus: status?.socStatus, offcarStatus: offcar)
        let isDriving = (status?.exteriorStatus?.vehicleState == 1)
        let isSleeping = (status?.connectionStatus?.connected == false || (status?.exteriorStatus?.vehicleState ?? 0) <= 0 || (status?.exteriorStatus?.vehicleState ?? 0) == 3)
        let isLocked = (status?.doorStatus?["vehicle_lock_status"]?.intValue ?? 1) == 1
        let windows = status?.windowStatus ?? [:]
        let winOpen = (windows["win_posn_fl"]?.intValue ?? 0) > 0 || (windows["win_posn_fr"]?.intValue ?? 0) > 0 || (windows["win_posn_rl"]?.intValue ?? 0) > 0 || (windows["win_posn_rr"]?.intValue ?? 0) > 0 || (windows["sun_roof_posn"]?.intValue ?? 0) > 0
        let allDoorsClosed = (status?.doorStatus?["door_ajar_front_left_status"]?.intValue ?? 1) == 1 && (status?.doorStatus?["door_ajar_front_right_status"]?.intValue ?? 1) == 1

        return VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Image("ET5_CleanPark")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 90)
                    .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrCardBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let mileage = status?.exteriorStatus?.mileage {
                    Text("\(Int(mileage)) km")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(themeColor.animeOrAccent.opacity(0.85)))
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }

            // 经典 nio-dash 5 联快捷状态条
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image("NIO_brand")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                    Text("ET5 · \(Int(round(displayRange))) km")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack(spacing: 8) {
                    macQuickStatusItem(icon: batteryIcon(for: Int(socVal)), label: "\(Int(socVal))%", color: isRealCharging ? .green : themeColor.animeOrAccent)
                    macQuickStatusItem(icon: isRealCharging ? "bolt.car.fill" : (isDriving ? "car.side.fill" : "car.fill"), label: isRealCharging ? "充电" : (isDriving ? "行驶" : "停放"), color: .white.opacity(0.85))
                    macQuickStatusItem(icon: "zzz", label: isSleeping ? "休眠" : "在线", color: isSleeping ? .secondary : themeColor.animeOrAccent)
                    macQuickStatusItem(icon: isLocked ? "lock.fill" : "lock.open.fill", label: (isLocked && allDoorsClosed) ? "已关" : (isLocked ? "已锁" : "未锁"), color: isLocked ? themeColor.animeOrAccent : .red)
                    macQuickStatusItem(icon: !winOpen ? "square.split.2x2.fill" : "square.split.2x2", label: !winOpen ? "已关" : "开启", color: !winOpen ? themeColor.animeOrAccent : .orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeColor.animeOrBorder, lineWidth: 0.5))
    }

    private func macQuickStatusItem(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .semibold, design: .rounded))
                .foregroundStyle(color.opacity(0.9))
        }
    }

    private func batteryIcon(for soc: Int) -> String {
        if soc >= 85 { return "battery.100percent" }
        if soc >= 60 { return "battery.75percent" }
        if soc >= 35 { return "battery.50percent" }
        if soc >= 10 { return "battery.25percent" }
        return "battery.0percent"
    }

    // MARK: - 403 警告条

    private var error403Banner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text("API 签名或 Token 已过期 (HTTP 403)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(themeColor.animeOrTextPrimary)
                Text("推荐在配置中使用「Widget 动态签名模式」，永久不再过期。")
                    .font(.system(size: 8))
                    .foregroundStyle(themeColor.animeOrTextSecondary)
            }
            Spacer()
            Button(action: { NIOConfigWindowManager.shared.open(themeColor: themeColor) }) {
                Text("修复")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(themeColor.animeOrAccent))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4), lineWidth: 0.8))
    }

    // MARK: - 未配置视图

    private var notConfiguredView: some View {
        VStack(spacing: 12) {
            Image("NIO_brand")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .padding(8)
                .background(Circle().fill(themeColor.animeOrButton))
                .overlay(Circle().stroke(themeColor.animeOrBorder, lineWidth: 0.5))

            Image("ET5_CleanPark")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("尚未配置蔚来 API")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(themeColor.animeOrTextPrimary)
            Text("支持直接粘贴抓包 cURL/URL 智能解析，或配置签名密钥使用动态签名。")
                .font(.system(size: 10))
                .foregroundStyle(themeColor.animeOrTextSecondary)
                .multilineTextAlignment(.center)
            Button(action: { NIOConfigWindowManager.shared.open(themeColor: themeColor) }) {
                Text("立即配置 API")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(themeColor.animeOrAccent))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - 卡片基类

    private func card<Content: View>(title: String, rawData: Any? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor.animeOrTextPrimary)
                Spacer()
                if let raw = rawData {
                    Button(action: {
                        if let data = try? JSONSerialization.data(withJSONObject: raw, options: .prettyPrinted),
                           let str = String(data: data, encoding: .utf8) {
                            rawJSONTitle = title
                            withAnimation(.easeInOut(duration: 0.2)) {
                                rawJSONContent = str
                            }
                        }
                    }) {
                        Text("{ }")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeColor.animeOrTextSecondary.opacity(0.7))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton.opacity(0.5)))
                    }
                    .buttonStyle(.plain)
                }
            }
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrCardBackground))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeColor.animeOrBorder, lineWidth: 0.5))
    }

    private func infoRow(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(themeColor.animeOrTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: highlight ? .bold : .medium))
                .foregroundStyle(highlight ? themeColor.animeOrAccent : themeColor.animeOrTextPrimary)
        }
    }

    private func badgeView(_ text: String, active: Bool, activeColor: Color = .green) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(active ? activeColor.opacity(0.18) : themeColor.animeOrButton.opacity(0.6)))
            .foregroundStyle(active ? activeColor : themeColor.animeOrTextSecondary)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(active ? activeColor.opacity(0.4) : Color.clear, lineWidth: 0.5))
    }

    // MARK: - 1. 电池与续航卡片 (与 iOS 统一的实估/CLTC 智能推算算法)

    private var batteryCard: some View {
        card(title: "⚡️ 电池与续航", rawData: status?.socStatus.flatMap { try? JSONEncoder().encode($0) }.flatMap { try? JSONSerialization.jsonObject(with: $0) }) {
            if let soc = status?.socStatus {
                let socVal = soc.soc ?? 0
                let socStr = (socVal.truncatingRemainder(dividingBy: 1) == 0) ? "\(Int(socVal))" : String(format: "%.1f", socVal)
                let cltcKm = soc.remainingRange
                let actKm = soc.remainingActualRange
                let hasAct = (actKm ?? 0) > 0
                let stdRange = Int(round(cltcKm ?? 0))
                let preferActual = settings.nioPreferActualRange

                // bestRange: 有实估用实估，没有则 CLTC × 0.795 推算
                let best = NIOVehicleLib.bestRange(cltcKm: cltcKm, actualKm: actKm)
                let mainRange = best?.km ?? stdRange
                let isCalcEstimate = best?.isEstimated ?? false

                // 副标签：主显示是实估时显示 CLTC，主显示是 CLTC 时显示推算实估
                let subText: String? = {
                    if preferActual && hasAct {
                        return "🌸 CLTC工况 \(stdRange) km"
                    } else if hasAct {
                        return "🎯 实估续航 \(Int(round(actKm!))) km"
                    } else if isCalcEstimate {
                        return "≈ 实估推算 \(mainRange) km (×0.795)"
                    }
                    return nil
                }()

                VStack(spacing: 6) {
                    HStack(alignment: .bottom, spacing: 6) {
                        HStack(alignment: .bottom, spacing: 2) {
                            Text(soc.soc != nil ? socStr : "—")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(themeColor.animeOrAccent)
                            Text("%")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(themeColor.animeOrAccent)
                                .padding(.bottom, 3)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 2) {
                                Text("\(preferActual && hasAct ? Int(round(actKm!)) : (hasAct ? stdRange : mainRange))")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(themeColor.animeOrTextPrimary)
                                Text("km")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(themeColor.animeOrTextSecondary)
                            }
                            if let sub = subText {
                                Text(sub)
                                    .font(.system(size: 8))
                                    .foregroundStyle(isCalcEstimate ? Color.orange.opacity(0.85) : themeColor.animeOrTextSecondary)
                            }
                        }
                    }

                    // 电量进度条
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(themeColor.animeOrButton)
                            Capsule()
                                .fill(themeColor.animeOrAccent)
                                .frame(width: max(4, geo.size.width * CGFloat(min(100.0, max(0.0, socVal))) / 100.0))
                        }
                    }
                    .frame(height: 6)
                    .padding(.vertical, 2)

                    // 充电状态与满电预估
                    HStack {
                        let isCharging = (soc.chargeState ?? 0) == 1
                        badgeView(NIOVehicleLib.chargeStateLabel(soc.chargeState ?? 0), active: isCharging, activeColor: .green)

                        if let type = soc.chargerType, type > 0 {
                            badgeView(NIOVehicleLib.chargerTypeLabel(type), active: true, activeColor: .blue)
                        }

                        Spacer()

                        if let p = soc.chargingPower, p > 0 {
                            Text(verbatim: "\(String(format: "%.1f", p / 1000.0)) kW")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(themeColor.animeOrAccent)
                        }

                        if let full = soc.remainingRange.flatMap({ r in soc.soc.map { NIOVehicleLib.fullChargeRangeKm(remainingRange: r, soc: $0) } }), let f = full {
                            Text("满电CLTC \(f)km" + NIOVehicleLib.batteryPackLabel(fullRangeKm: f))
                                .font(.system(size: 8))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                        }
                    }

                    // 达成率与 12V 小电瓶系统
                    let lvBatt = status?.lvBattStatus ?? [:]
                    let lvSoc = lvBatt["lv_batt_soc"]?.intValue
                    let lvVolt = lvBatt["lv_batt_volt"]?.numberValue
                    let achieveRate = NIOVehicleLib.rangeAchievementRatio(actual: soc.remainingActualRange, standard: soc.remainingRange)

                    HStack(spacing: 6) {
                        if let rate = achieveRate {
                            HStack(spacing: 2) {
                                Text("达成率")
                                    .font(.system(size: 8))
                                    .foregroundStyle(themeColor.animeOrTextSecondary)
                                Text(verbatim: "\(String(format: "%.1f", rate))%")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(themeColor.animeOrAccent)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(themeColor.animeOrAccent.opacity(0.15))
                            .clipShape(Capsule())
                        }

                        if let maxSoc = soc.maxSoc, maxSoc > 0 {
                            Text("上限 \(Int(maxSoc))%")
                                .font(.system(size: 8))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                        }

                        if let lockSoc = soc.lockSoc, lockSoc > 0 {
                            Text("锁电 \(Int(lockSoc))%")
                                .font(.system(size: 8))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                        }

                        Spacer()

                        if let lvS = lvSoc {
                            HStack(spacing: 2) {
                                Image(systemName: "car.side.fill")
                                    .font(.system(size: 8))
                                Text("12V电瓶 \(lvS)%")
                                    .font(.system(size: 8, weight: .medium))
                                if let volt = lvVolt {
                                    Text(verbatim: "\(String(format: "%.1f", volt))V")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                }
                            }
                            .foregroundStyle(lvS > 50 ? themeColor.animeOrTextSecondary : .pink)
                        }
                    }
                }
            } else {
                Text("暂无电池数据").font(.system(size: 9)).foregroundStyle(themeColor.animeOrTextSecondary)
            }
        }
    }

    // MARK: - 1.1 能耗达成率与百公里电耗评分卡片

    @ViewBuilder
    private var efficiencyCard: some View {
        let nominal = status?.socStatus?.remainingRange
        let actual = status?.socStatus?.remainingActualRange
        if let score = NIOEfficiencyLib.computeScore(nominalRange: nominal, actualRange: actual) {
            card(title: "📈 驾驶能耗达成率与电耗评分") {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(themeColor.animeOrAccent.opacity(0.2))
                                .frame(width: 36, height: 36)
                            Image(systemName: score.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(themeColor.animeOrAccent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(score.title)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(themeColor.animeOrTextPrimary)
                                Spacer()
                                Text(score.grade)
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(themeColor.animeOrAccent.opacity(0.2))
                                    .foregroundStyle(themeColor.animeOrAccent)
                                    .clipShape(Capsule())
                            }
                            Text(score.subtitle)
                                .font(.system(size: 8))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("实估达成率")
                                .font(.system(size: 7))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                            Text(verbatim: "\(String(format: "%.1f", score.achievementRate))%")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(themeColor.animeOrAccent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(themeColor.animeOrButton.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("推算百公里电耗")
                                .font(.system(size: 7))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(verbatim: String(format: "%.1f", score.estimatedKwhPer100Km))
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(themeColor.animeOrTextPrimary)
                                Text("kWh")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(themeColor.animeOrTextSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(themeColor.animeOrButton.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // 达成率进度条
                    VStack(alignment: .leading, spacing: 2) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(themeColor.animeOrButton)
                                Capsule()
                                    .fill(themeColor.animeOrAccent)
                                    .frame(width: max(6, geo.size.width * CGFloat(min(1.0, score.achievementRate / 100.0))))
                            }
                        }
                        .frame(height: 5)

                        HStack {
                            Text("标称 \(Int(nominal ?? 0)) km")
                                .font(.system(size: 7))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                            Spacer()
                            Text("实估 \(Int(actual ?? 0)) km")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(themeColor.animeOrAccent)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 1.2 维保周期与耗材寿命追踪卡片

    @ViewBuilder
    private var maintenanceCard: some View {
        let currentKm = status?.exteriorStatus?.mileage ?? 0.0
        let report = NIOMaintenanceTracker.generateReport(currentMileage: currentKm, orders: service.serviceSummary?.orders ?? [])

        card(title: "🔧 爱车维保周期与耗材寿命") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("全车健康评分")
                            .font(.system(size: 8))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(report.overallHealthScore)")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(themeColor.animeOrAccent)
                            Text("分 优良")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(themeColor.animeOrAccent)
                        }
                    }
                    .padding(6)
                    .background(themeColor.animeOrButton.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("上次维保 · \(report.lastServiceDate)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(themeColor.animeOrTextPrimary)
                        Text(report.lastServiceStation)
                            .font(.system(size: 7))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                            .lineLimit(1)
                        if report.totalCount > 0 {
                            Text("累计 \(report.totalCount) 次维保 · " + NIOOrderLib.fmtMoney(report.totalSpent))
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .background(themeColor.animeOrButton.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                VStack(spacing: 4) {
                    ForEach(report.items) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 8))
                                .foregroundStyle(item.isUrgent ? Color.red : themeColor.animeOrAccent)
                                .frame(width: 12)

                            Text(item.name)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(themeColor.animeOrTextPrimary)

                            Spacer()

                            Text(item.statusDesc)
                                .font(.system(size: 7))
                                .foregroundStyle(item.isUrgent ? Color.red : themeColor.animeOrTextSecondary)

                            Text("余 \(Int(item.remainingKm))km")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(themeColor.animeOrTextPrimary)
                        }
                        .padding(.vertical, 2)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(themeColor.animeOrButton)
                                Capsule()
                                    .fill(item.isUrgent ? Color.red : themeColor.animeOrAccent)
                                    .frame(width: max(4, geo.size.width * CGFloat(min(1.0, max(0.0, item.healthPercentage / 100.0)))))
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }
        }
    }

    // MARK: - 2. 车门、车窗与车锁卡片 (动态解析)

    private var doorsVisualCard: some View {
        let items = NIOVehicleLib.parseAvailableDoors(doorStatus: status?.doorStatus, windowStatus: status?.windowStatus)
        return card(title: "🚪 车门、车窗与车锁", rawData: status?.doorStatus) {
            if items.isEmpty {
                Text("暂无车门数据")
                    .font(.system(size: 9))
                    .foregroundStyle(themeColor.animeOrTextSecondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(items) { item in
                        doorCell(
                            title: item.title,
                            closed: item.isClosed,
                            customLabel: item.isClosed ? item.customClosedLabel : item.customOpenLabel
                        )
                    }
                }
            }
        }
    }

    private func doorCell(title: String, closed: Bool, customLabel: String? = nil) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 8))
                .foregroundStyle(themeColor.animeOrTextSecondary)
            Text(customLabel ?? (closed ? "关好 🐾" : "未关好 ⚠️"))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(closed ? themeColor.animeOrTextPrimary : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(closed ? themeColor.animeOrButton.opacity(0.4) : Color.red.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(closed ? Color.clear : Color.red.opacity(0.3), lineWidth: 0.5))
    }

    // MARK: - 2.5 🪟 车窗与天窗开度透视

    @ViewBuilder
    private var windowsCard: some View {
        let win = status?.windowStatus ?? [:]
        let fl = win["win_posn_fl"]?.intValue ?? 0
        let fr = win["win_posn_fr"]?.intValue ?? 0
        let rl = win["win_posn_rl"]?.intValue ?? 0
        let rr = win["win_posn_rr"]?.intValue ?? 0
        let sunRoof = win["sun_roof_posn"]?.intValue ?? 0
        let mirrorFold = win["rearview_mirror_fold"]?.intValue == 1

        card(title: "🪟 车窗与天窗开度", rawData: status?.windowStatus.flatMap { try? JSONEncoder().encode($0) }.flatMap { try? JSONSerialization.jsonObject(with: $0) }) {
            VStack(spacing: 5) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    macWinTile("左前车窗", pos: fl)
                    macWinTile("右前车窗", pos: fr)
                    macWinTile("左后车窗", pos: rl)
                    macWinTile("右后车窗", pos: rr)
                }
                HStack {
                    badgeView(sunRoof > 0 ? "天窗开启 \(sunRoof)%" : "天窗关闭", active: sunRoof > 0, activeColor: .orange)
                    Spacer()
                    badgeView(mirrorFold ? "后视镜已折叠 🔒" : "后视镜展开", active: mirrorFold, activeColor: themeColor.animeOrAccent)
                }
            }
        }
    }

    private func macWinTile(_ name: String, pos: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name).font(.system(size: 8, weight: .medium)).foregroundStyle(themeColor.animeOrTextSecondary)
                Spacer()
                Text(pos > 0 ? "\(pos)%" : "关严").font(.system(size: 8, weight: .bold)).foregroundStyle(pos > 0 ? Color.orange : themeColor.animeOrAccent)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(themeColor.animeOrButton)
                    if pos > 0 {
                        Capsule().fill(themeColor.animeOrAccent).frame(width: max(3, g.size.width * CGFloat(min(100, pos)) / 100.0))
                    }
                }
            }
            .frame(height: 2.5)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 6).fill(themeColor.animeOrButton.opacity(0.4)))
    }

    // MARK: - 2.6 🚗 驾驶模式与行车泊车

    @ViewBuilder
    private var drivingParkingCard: some View {
        let ext = status?.exteriorStatus
        let vehlMode = ext?.vehlMode ?? 0
        let vehlState = ext?.vehicleState ?? 0
        let tripShare = status?.tripShareStatus?["trip_share_status"]?.intValue ?? 0
        let isRpa = (status?.specialStatus?["rvs_rpa_out"]?.intValue == 1) || (vehlState == 5)

        card(title: "🚗 驾驶模式与行车详情", rawData: status?.exteriorStatus.flatMap { try? JSONEncoder().encode($0) }.flatMap { try? JSONSerialization.jsonObject(with: $0) }) {
            VStack(spacing: 4) {
                HStack {
                    infoRow("驾驶模式", vehlState == 2 ? "上次设定: \(NIOVehicleLib.vehlModeLabel(vehlMode))" : NIOVehicleLib.vehlModeLabel(vehlMode), highlight: true)
                }
                HStack {
                    infoRow("车辆状态", NIOVehicleLib.vehicleStateLabel(vehlState))
                }
                HStack(spacing: 4) {
                    badgeView(isRpa ? "遥控泊车进行中 🅿️" : "遥控泊车待命", active: isRpa, activeColor: .orange)
                    Spacer()
                    badgeView(tripShare > 0 ? "行程分享中 📍" : "行程分享关闭", active: tripShare > 0, activeColor: .orange)
                }
            }
        }
    }

    // MARK: - 3. 轮胎胎压胎温卡片 (4 轮网格)

    private var tyreGridCard: some View {
        card(title: "🛞 轮胎胎压胎温", rawData: status?.tyreStatus) {
            let tyre = NIOVehicleLib.extractTyreInfo(status?.tyreStatus)
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    tyreCell(pos: "左前轮", info: tyre.fl)
                    tyreCell(pos: "右前轮", info: tyre.fr)
                }
                HStack(spacing: 8) {
                    tyreCell(pos: "左后轮", info: tyre.rl)
                    tyreCell(pos: "右后轮", info: tyre.rr)
                }
            }
        }
    }

    private func tyreCell(pos: String, info: NIOVehicleLib.TyreWheelInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(pos)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(themeColor.animeOrTextSecondary)
            HStack {
                Text(info.displayPress)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(info.press != nil ? themeColor.animeOrTextPrimary : themeColor.animeOrTextSecondary)
                Spacer()
                if !info.displayTemp.isEmpty {
                    Text(info.displayTemp)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(themeColor.animeOrButton.opacity(0.4)))
    }

    // MARK: - 4. 智能座舱与车况微缩网格 (2 列紧凑布局)

    private var cockpitGridCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // 左列：座舱温度与空调
                card(title: "🌡️ 座舱与空调") {
                    let hvac = status?.hvacStatus
                    let heat = status?.heatingStatus ?? [:]
                    let steer = heat["steer_wheel_heat_sts"]?.intValue ?? heat["steer_wheel_heating_sts"]?.intValue ?? 0
                    let flHeat = heat["seat_heat_frnt_le_sts"]?.intValue ?? heat["seat_heat_front_left"]?.intValue ?? 0
                    let frHeat = heat["seat_heat_frnt_ri_sts"]?.intValue ?? heat["seat_heat_front_right"]?.intValue ?? 0
                    let seatHeat = max(flHeat, frHeat)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("车内")
                                .font(.system(size: 8))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                            Text(hvac?.temperature != nil ? String(format: "%.1f℃", hvac!.temperature!) : "—")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(themeColor.animeOrTextPrimary)
                            Spacer()
                            Text("车外")
                                .font(.system(size: 8))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                            Text(hvac?.outsideTemperature != nil ? String(format: "%.1f℃", hvac!.outsideTemperature!) : "—")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                        }

                        HStack(spacing: 4) {
                            badgeView(hvac?.airConditionerOn == true ? "空调开启" : "空调关闭", active: hvac?.airConditionerOn == true, activeColor: .blue)
                            Spacer()
                            if steer > 0 {
                                badgeView("方向盘加热", active: true, activeColor: .orange)
                            } else if seatHeat > 0 {
                                badgeView("前排加热", active: true, activeColor: .orange)
                            }
                        }
                    }
                }

                // 右列：智能模式与安全
                card(title: "🐾 车辆模式与安全") {
                    let offcar = status?.offcarModeStatus ?? [:]
                    let defender = NIOVehicleLib.defenderModeActive(offcar)
                    let pet = NIOVehicleLib.modeActive(offcar["pet_mode_status"] ?? offcar["pet_mode"])
                    let camp = NIOVehicleLib.modeActive(offcar["camp_mode_status"] ?? offcar["camping_mode"])
                    let powerHold = NIOVehicleLib.modeActive(offcar["power_hold_mode"] ?? offcar["offcar_power_hold"])
                    let conn = status?.connectionStatus?.connected == true

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            badgeView(defender.isActive ? "守卫开启" : "守卫关闭", active: defender.isActive, activeColor: .red)
                            Spacer()
                            if pet {
                                badgeView("宠物模式", active: true, activeColor: .orange)
                            } else if camp {
                                badgeView("露营模式", active: true, activeColor: .orange)
                            } else if powerHold {
                                badgeView("离车不下电", active: true, activeColor: .blue)
                            } else {
                                badgeView("标准驻车", active: false, activeColor: .secondary)
                            }
                        }

                        HStack {
                            Text("云端连接")
                                .font(.system(size: 8))
                                .foregroundStyle(themeColor.animeOrTextSecondary)
                            Spacer()
                            badgeView(conn ? "在线" : "离线", active: conn, activeColor: .green)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. 特殊状态与储物空间

    @ViewBuilder
    private var specialStatesCard: some View {
        let box = status?.boxStatus ?? [:]
        let frdg = status?.frdgStatus ?? [:]
        let doors = status?.doorStatus ?? [:]
        let isBoxOpen = (box["box_open"]?.boolValue == true || box["box_open"]?.intValue == 1)
        let isBoxLock = (box["box_lock"]?.boolValue == true || box["box_lock"]?.intValue == 1)
        let hasFridge = (frdg["frdg_power"]?.boolValue == true || frdg["frdg_pwr_sts"]?.intValue == 1)
        let hoodOpen = doors["engine_hood_ajar_status"]?.intValue == 1
        let trunkOpen = doors["tailgate_ajar_status"]?.intValue == 1

        if isBoxOpen || isBoxLock || hasFridge || hoodOpen || trunkOpen || !box.isEmpty {
            card(title: "📦 储物空间与车载冰箱") {
                VStack(spacing: 3) {
                    if hoodOpen { infoRow("前备箱/前舱盖", "已开启 ⚠️", highlight: true) }
                    if trunkOpen { infoRow("后备箱/电动尾门", "已开启 ⚠️", highlight: true) }
                    if isBoxOpen { infoRow("密码储物箱", "已开启 🔓") } else if isBoxLock { infoRow("密码储物箱", "已锁定 🔒") }
                    if hasFridge { infoRow("车载冰箱", "制冷运行中 ❄️") }
                }
            }
        }
    }

    // MARK: - 5.1 🪑 座椅舒适与方向盘加热

    @ViewBuilder
    private var seatComfortCard: some View {
        let heat = status?.heatingStatus ?? [:]
        let steer = heat["steer_wheel_heat_sts"]?.intValue ?? heat["steer_wheel_heating_sts"]?.intValue ?? 0
        let flHeat = heat["seat_heat_frnt_le_sts"]?.intValue ?? heat["seat_heat_front_left"]?.intValue ?? 0
        let frHeat = heat["seat_heat_frnt_ri_sts"]?.intValue ?? heat["seat_heat_front_right"]?.intValue ?? 0
        let rlHeat = heat["seat_heat_re_le_sts"]?.intValue ?? heat["seat_heat_rear_left"]?.intValue ?? 0
        let rrHeat = heat["seat_heat_re_ri_sts"]?.intValue ?? heat["seat_heat_rear_right"]?.intValue ?? 0
        let flVent = heat["seat_vent_frnt_le_sts"]?.intValue ?? heat["seat_vent_front_left"]?.intValue ?? 0
        let frVent = heat["seat_vent_frnt_ri_sts"]?.intValue ?? heat["seat_vent_front_right"]?.intValue ?? 0
        let battPre = heat["hv_batt_pre_sts"]?.intValue == 1
        let battWarm = heat["btry_warm_up_sts"]?.intValue == 1

        let hasAny = steer > 0 || flHeat > 0 || frHeat > 0 || rlHeat > 0 || rrHeat > 0 || flVent > 0 || frVent > 0 || battPre || battWarm || !heat.isEmpty

        if hasAny {
            card(title: "🪑 座椅舒适与方向盘加热", rawData: status?.heatingStatus.flatMap { try? JSONEncoder().encode($0) }.flatMap { try? JSONSerialization.jsonObject(with: $0) }) {
                VStack(spacing: 6) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        macSeatTile("主驾座椅", heat: flHeat, vent: flVent)
                        macSeatTile("副驾座椅", heat: frHeat, vent: frVent)
                        macSeatTile("二排左座", heat: rlHeat, vent: 0)
                        macSeatTile("二排右座", heat: rrHeat, vent: 0)
                    }
                    HStack(spacing: 4) {
                        badgeView("方向盘加热" + (steer > 0 ? " \(steer)档" : ""), active: steer > 0, activeColor: .orange)
                        badgeView("电池预热", active: battPre, activeColor: .red)
                        badgeView("电池保温", active: battWarm, activeColor: themeColor.animeOrAccent)
                    }
                }
            }
        }
    }

    private func macSeatTile(_ name: String, heat: Int, vent: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: (heat > 0 || vent > 0) ? "chair.lounge.fill" : "chair.lounge")
                .font(.system(size: 9))
                .foregroundStyle((heat > 0) ? Color.orange : ((vent > 0) ? themeColor.animeOrAccent : themeColor.animeOrTextSecondary.opacity(0.5)))
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 8, weight: .medium)).foregroundStyle(themeColor.animeOrTextPrimary)
                HStack(spacing: 2) {
                    if heat > 0 { Text("\(heat)档加热").font(.system(size: 7, weight: .bold)).foregroundStyle(.orange) }
                    if vent > 0 { Text("\(vent)档通风").font(.system(size: 7, weight: .bold)).foregroundStyle(themeColor.animeOrAccent) }
                    if heat == 0 && vent == 0 { Text("未开启").font(.system(size: 7)).foregroundStyle(themeColor.animeOrTextSecondary.opacity(0.5)) }
                }
            }
            Spacer()
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 6).fill(themeColor.animeOrButton.opacity(0.4)))
    }

    // MARK: - 5.2 🔑 钥匙感知与12V电瓶

    @ViewBuilder
    private var keySensorsCard: some View {
        let key = status?.keyStatus ?? [:]
        let lvBatt = status?.lvBattStatus ?? [:]
        let peUnlock = key["pe_unlock_status"]?.intValue == 1 || key["smart_key_near"]?.intValue == 1
        let handleSensor = key["handle_sensor_status"]?.intValue == 1 || key["door_handle_sensor"]?.intValue == 1
        let lvSoc = lvBatt["lv_batt_soc"]?.intValue
        let lvVolt = lvBatt["lv_batt_volt"]?.numberValue ?? lvBatt["lv_batt_voltage"]?.numberValue

        card(title: "🔑 钥匙感知与低压电瓶", rawData: status?.keyStatus.flatMap { try? JSONEncoder().encode($0) }.flatMap { try? JSONSerialization.jsonObject(with: $0) }) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    badgeView(peUnlock ? "蓝牙靠近: 已感应" : "蓝牙靠近: 待命", active: peUnlock, activeColor: themeColor.animeOrAccent)
                    badgeView(handleSensor ? "门把手: 感应伸出" : "门把手: 收纳", active: handleSensor, activeColor: .orange)
                    if let soc = lvSoc {
                        badgeView("12V: \(soc)%" + (lvVolt != nil ? " (\(String(format: "%.1f", lvVolt!))V)" : ""), active: soc > 40, activeColor: soc > 40 ? .green : .red)
                    } else {
                        badgeView("12V: 待抓包同步", active: false, activeColor: .secondary)
                    }
                }
            }
        }
    }

    // MARK: - 5.5 💡 车外灯光与照明系统

    @ViewBuilder
    private var lightsCard: some View {
        let lights = status?.lightStatus ?? [:]
        if !lights.isEmpty {
            let dipped = lights["dipped_beam_status"]?.intValue == 1
            let main = lights["main_beam_status"]?.intValue == 1
            let position = lights["position_light_status"]?.intValue == 1
            let hazard = lights["hazard_light_status"]?.intValue == 1
            let anyOn = dipped || main || position || hazard

            card(title: "💡 车外灯光与照明系统", rawData: status?.lightStatus.flatMap { try? JSONEncoder().encode($0) }.flatMap { try? JSONSerialization.jsonObject(with: $0) }) {
                VStack(spacing: 6) {
                    // 全局灯光状态胶囊
                    HStack {
                        if hazard {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.white)
                            Text("危险警报双闪开启")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.white)
                        } else if main {
                            Image(systemName: "headlight.high.beam.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.black)
                            Text("远光大灯照明中")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.black)
                        } else if dipped {
                            Image(systemName: "headlight.low.beam.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.black)
                            Text("近光大灯照明中")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.black)
                        } else if position {
                            Image(systemName: "headlight.daytime.running.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.white)
                            Text("示廓位置灯点亮")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.white)
                        } else {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(themeColor.animeOrAccent)
                            Text("全车灯光已熄灭 · 安全驻车")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(themeColor.animeOrTextPrimary.opacity(0.85))
                        }
                        Spacer()
                        badgeView(anyOn ? "开启中" : "全部熄灭", active: anyOn, activeColor: hazard ? .red : (main ? .yellow : .green))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(hazard ? Color.red.opacity(0.8) : (main ? Color.yellow.opacity(0.8) : (dipped ? themeColor.animeOrAccent.opacity(0.8) : themeColor.animeOrButton))))

                    // 2x2 网格
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        macLightTile(name: "近光大灯", icon: "headlight.low.beam.fill", isOn: dipped, activeColor: themeColor.animeOrAccent)
                        macLightTile(name: "远光大灯", icon: "headlight.high.beam.fill", isOn: main, activeColor: .yellow)
                        macLightTile(name: "示廓位置灯", icon: "headlight.daytime.running.fill", isOn: position, activeColor: .purple)
                        macLightTile(name: "危险报警双闪", icon: "exclamationmark.triangle.fill", isOn: hazard, activeColor: .red)
                    }
                }
            }
        }
    }

    private func macLightTile(name: String, icon: String, isOn: Bool, activeColor: Color) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(isOn ? activeColor : themeColor.animeOrButton).frame(width: 22, height: 22)
                Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundStyle(isOn ? (activeColor == .yellow ? Color.black : Color.white) : themeColor.animeOrTextSecondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 8, weight: .bold)).foregroundStyle(isOn ? themeColor.animeOrTextPrimary : themeColor.animeOrTextSecondary)
                Text(isOn ? "已开启" : "已熄灭").font(.system(size: 7)).foregroundStyle(isOn ? activeColor : themeColor.animeOrTextSecondary.opacity(0.6))
            }
            Spacer()
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 6).fill(isOn ? activeColor.opacity(0.12) : themeColor.animeOrButton.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isOn ? activeColor.opacity(0.3) : Color.clear, lineWidth: 0.5))
    }

    // MARK: - 换电与服务订单区

    @ViewBuilder
    private var ordersSection: some View {
        if let summary = service.serviceSummary {
            VStack(spacing: 10) {
                card(title: "📑 服务与换电订单概览") {
                    VStack(spacing: 3) {
                        infoRow("累计服务订单", "\(summary.total) 单", highlight: true)
                        infoRow("换电完成次数", "\(summary.swapCompleted) 次")
                        infoRow("换电累计花费", NIOOrderLib.fmtMoney(summary.swapSpent))
                        if summary.swapCompleted > 0 {
                            infoRow("平均换电花费", NIOOrderLib.fmtMoney(summary.swapAvgSpent))
                        }
                        if summary.upgradeCount > 0 {
                            infoRow("电池灵活升级", "\(summary.upgradeCompleted) 次 (按日: \(summary.upgradeDayCount), 按月: \(summary.upgradeMonthCount))")
                        }
                    }
                }

                // 常用换电站排行
                if !summary.topSwapStations.isEmpty {
                    card(title: "🏆 常用换电站 Top 5") {
                        let maxCount = summary.topSwapStations.map(\.count).max() ?? 1
                        VStack(spacing: 6) {
                            ForEach(summary.topSwapStations) { st in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(st.name)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(themeColor.animeOrTextPrimary)
                                        Spacer()
                                        Text("\(st.count) 次 · \(NIOOrderLib.fmtMoney(st.spent))")
                                            .font(.system(size: 8))
                                            .foregroundStyle(themeColor.animeOrTextSecondary)
                                    }
                                    GeometryReader { g in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(themeColor.animeOrButton)
                                            Capsule()
                                                .fill(themeColor.animeOrAccent)
                                                .frame(width: max(4, g.size.width * CGFloat(st.count) / CGFloat(maxCount)))
                                        }
                                    }
                                    .frame(height: 3)
                                }
                            }
                        }
                    }
                }

                // 可展开全部订单列表
                if !summary.orders.isEmpty {
                    card(title: "📋 订单明细列表（\(summary.total)）") {
                        VStack(spacing: 6) {
                            ForEach(summary.orders.prefix(8)) { order in
                                VStack(alignment: .leading, spacing: 3) {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if expandedOrderId == order.id {
                                                expandedOrderId = nil
                                            } else {
                                                expandedOrderId = order.id
                                            }
                                        }
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(NIOOrderLib.orderTypeLabel(order))
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundStyle(themeColor.animeOrTextPrimary)
                                                Text(NIOOrderLib.fmtSwapDate(order.createTime))
                                                    .font(.system(size: 7))
                                                    .foregroundStyle(themeColor.animeOrTextSecondary)
                                            }
                                            Spacer()
                                            Text(order.orderStatusName ?? "—")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(toneColor(NIOOrderLib.orderStatusTone(order)))
                                            Image(systemName: expandedOrderId == order.id ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 8))
                                                .foregroundStyle(themeColor.animeOrTextSecondary)
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    if expandedOrderId == order.id {
                                        VStack(spacing: 2) {
                                            ForEach(NIOOrderLib.orderDetailLines(order), id: \.label) { line in
                                                infoRow(line.label, line.value)
                                            }
                                        }
                                        .padding(6)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton.opacity(0.3)))
                                    }
                                }
                                .padding(.vertical, 2)
                                if order.id != summary.orders.prefix(8).last?.id {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func toneColor(_ tone: String) -> Color {
        switch tone {
        case "success": return .green
        case "warning": return .orange
        case "danger": return .red
        default: return themeColor.animeOrTextSecondary
        }
    }

    // MARK: - 签到卡片

    @ViewBuilder
    private var checkinCard: some View {
        if let ci = service.checkinData {
            card(title: "📅 每日签到") {
                HStack {
                    Image(systemName: ci.checkedIn ? "checkmark.circle.fill" : "calendar.badge.exclamationmark")
                        .foregroundStyle(ci.checkedIn ? .green : .orange)
                    Text(ci.checkedIn ? "今日已完成签到" : "今日尚未签到")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(themeColor.animeOrTextPrimary)
                    Spacer()
                    Text("已连续签到 \(ci.continuousDays) 天")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(themeColor.animeOrAccent)
                }
            }
        }
    }

    // MARK: - 每日行驶轨迹地图

    @ViewBuilder
    private var dailyPathCard: some View {
        let dailyPaths = service.dailyPaths
        if !dailyPaths.isEmpty {
            card(title: "🗺️ 行驶轨迹地图") {
                let currentDayIndex = min(selectedDayIndex, dailyPaths.count - 1)
                let activePath = dailyPaths[currentDayIndex]

                VStack(spacing: 6) {
                    // 日期选择切换
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(dailyPaths.prefix(7).enumerated()), id: \.element.id) { idx, dp in
                                Button(action: { selectedDayIndex = idx }) {
                                    Text(dp.label)
                                        .font(.system(size: 8, weight: selectedDayIndex == idx ? .bold : .regular))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(selectedDayIndex == idx ? themeColor.animeOrAccent : themeColor.animeOrButton))
                                        .foregroundStyle(selectedDayIndex == idx ? .white : themeColor.animeOrTextSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 地图组件
                    pathMapView(activePath.points)
                        .frame(height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    // 当日行驶统计
                    HStack {
                        infoRow("行驶距离", String(format: "%.1f km", activePath.distanceKm), highlight: true)
                        Spacer()
                        Text("起止: \(NIOVehicleLib.fmtClock(activePath.startTime)) ~ \(NIOVehicleLib.fmtClock(activePath.endTime))")
                            .font(.system(size: 8))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                    }
                }
            }
        }
    }

    private func pathMapView(_ points: [NIOVehicleSnapshot]) -> some View {
        let coords = points.compactMap { snap -> CLLocationCoordinate2D? in
            guard snap.isValidGPS else { return nil }
            return CLLocationCoordinate2D(latitude: snap.lat, longitude: snap.lng)
        }
        guard !coords.isEmpty else {
            return AnyView(Text("无有效坐标点").font(.system(size: 9)).foregroundStyle(themeColor.animeOrTextSecondary))
        }
        let center = coords[coords.count / 2]
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        return AnyView(
            Map(initialPosition: .region(region)) {
                MapPolyline(coordinates: coords)
                    .stroke(themeColor.animeOrAccent, lineWidth: 3)
                if let first = coords.first {
                    Marker("起点", coordinate: first)
                }
                if let last = coords.last, coords.count > 1 {
                    Marker("终点", coordinate: last)
                }
            }
            .allowsHitTesting(false)
        )
    }

    // MARK: - 历史趋势图表

    @ViewBuilder
    private var trendChartsCard: some View {
        let hist = service.history
        let recent = Array(hist.suffix(trendPreset))
        if !recent.isEmpty {
            card(title: "📈 历史趋势分析") {
                VStack(spacing: 8) {
                    // 时间范围选择
                    HStack {
                        Text("采样点: \(recent.count) 条")
                            .font(.system(size: 8))
                            .foregroundStyle(themeColor.animeOrTextSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach([30, 60, 180, 500], id: \.self) { p in
                                Button(action: { trendPreset = p }) {
                                    Text("\(p)")
                                        .font(.system(size: 8, weight: trendPreset == p ? .bold : .regular))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(trendPreset == p ? themeColor.animeOrAccent : themeColor.animeOrButton))
                                        .foregroundStyle(trendPreset == p ? .white : themeColor.animeOrTextSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    socChart(recent)
                    dailyDeltaChart(service.dailyMileageDeltas)
                    mileageChart(recent)
                }
            }
        }
    }

    private func socChart(_ data: [NIOVehicleSnapshot]) -> some View {
        let points = data.enumerated().map { idx, snap in
            TrendPoint(idx: idx, value: snap.soc)
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text("电量趋势 (%)").font(.system(size: 8, weight: .bold)).foregroundStyle(themeColor.animeOrTextSecondary)
            Chart(points) { p in
                LineMark(x: .value("序号", p.idx), y: .value("电量", p.value))
                    .foregroundStyle(themeColor.animeOrAccent)
                    .interpolationMethod(.monotone)
                AreaMark(x: .value("序号", p.idx), y: .value("电量", p.value))
                    .foregroundStyle(LinearGradient(colors: [themeColor.animeOrAccent.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
            }
            .chartYScale(domain: 0...100)
            .frame(height: 60)
        }
    }

    private func dailyDeltaChart(_ deltas: [NIODailyDelta]) -> some View {
        guard !deltas.isEmpty else { return AnyView(EmptyView()) }
        let recentDeltas = Array(deltas.suffix(14))
        return AnyView(
            VStack(alignment: .leading, spacing: 2) {
                Text("近 14 日增里程 (km)").font(.system(size: 8, weight: .bold)).foregroundStyle(themeColor.animeOrTextSecondary)
                Chart(recentDeltas) { d in
                    BarMark(x: .value("日期", d.label), y: .value("增量", d.delta))
                        .foregroundStyle(themeColor.animeOrAccent)
                }
                .frame(height: 55)
            }
        )
    }

    private func mileageChart(_ data: [NIOVehicleSnapshot]) -> some View {
        let points = data.enumerated().map { idx, snap in
            TrendPoint(idx: idx, value: snap.mileage)
        }
        return VStack(alignment: .leading, spacing: 2) {
            Text("总里程趋势 (km)").font(.system(size: 8, weight: .bold)).foregroundStyle(themeColor.animeOrTextSecondary)
            Chart(points) { p in
                LineMark(x: .value("序号", p.idx), y: .value("里程", p.value))
                    .foregroundStyle(themeColor.animeOrAccent)
                    .interpolationMethod(.monotone)
            }
            .frame(height: 55)
        }
    }

    // MARK: - 日志入口按钮

    private var fetchLogButton: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showLogs = true } }) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 9))
                Text("运行与诊断日志（\(service.fetchLogs.count) 条）")
                    .font(.system(size: 9, weight: .medium))
                Spacer()
                if service.lastError != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 8))
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(themeColor.animeOrButton))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 辅助类型

private struct TrendPoint: Identifiable {
    let id = UUID()
    let idx: Int
    let value: Double
}

struct NIOCardJSONSheet: Identifiable {
    let id = UUID()
    let title: String
    let json: String
}

// MARK: - 原始 JSON 检查器

struct NIORawJSONView: View {
    let themeColor: ThemeColor
    let title: String
    let jsonText: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("原始 JSON 结构：\(title)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(themeColor.animeOrTextPrimary)
                Spacer()
                Button(action: { onDismiss?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.top, .horizontal], 10)

            ScrollView {
                Text(jsonText)
                    .font(.system(size: 9, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(themeColor.animeOrCardBackground))
            .padding([.bottom, .horizontal], 10)
        }
        .frame(maxHeight: 280)
    }
}

