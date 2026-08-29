//
//  NIOConfigView.swift
//  YumikoToys
//
//  NIO API 配置编辑界面（支持智能抓包解析、Widget 动态签名模式与一键诊断）
//

import SwiftUI

struct NIOConfigView: View {
    let themeColor: ThemeColor
    var onSaved: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var nioEnabled = false
    @State private var apiMode = "url" // "url" | "widget"
    @State private var vehicleURL = ""
    @State private var vehicleToken = ""
    @State private var vehicleId = ""
    @State private var deviceId = ""
    @State private var vehicleSignSecret = ""
    @State private var vehicleSignAlgo = "md5_append"
    @State private var changeURL = ""
    @State private var changeToken = ""
    @State private var checkinURL = ""
    @State private var checkinToken = ""
    @State private var drivingSec = "900"
    @State private var daySec = "1800"
    @State private var nightSec = "3600"
    @State private var changeInterval = "3600"
    @State private var trayFields: Set<NIODisplayField> = [.soc, .range]
    @State private var hiddenCards: Set<String> = []
    @State private var preferActualRange: Bool = false

    // 智能解析状态
    @State private var smartInputText = ""
    @State private var smartParseNotice: String?

    // 诊断状态
    @State private var isDiagnosing = false
    @State private var diagnosticReport: NIODiagnosticReport?

    private var settings: AppSettings { DependencyContainer.shared.settingsService.settings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                toggleRow
                smartParseSection
                modeSelectorSection

                if apiMode == "widget" {
                    widgetModeSection
                } else {
                    vehicleUrlSection
                }

                changeSection
                checkinSection
                diagnosticSection
                cardDisplaySection
                pollSection
                trayDisplaySection

                Spacer(minLength: 10)
                saveButton
            }
            .padding(16)
        }
        .background(themeColor.animeOrBackground)
        .onAppear { loadFromSettings() }
    }

    // MARK: - 启用开关

    private var toggleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("蔚来看板功能")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(themeColor.animeOrTextPrimary)
                Text("实时监控蔚来车辆状态、电池、车门、换电订单与行驶轨迹")
                    .font(.system(size: 8))
                    .foregroundStyle(themeColor.animeOrTextSecondary)
            }
            Spacer()
            Toggle("", isOn: $nioEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(themeColor.animeOrAccent)
        }
    }

    // MARK: - 智能解析抓包内容

    private var smartParseSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("⚡️ 智能解析抓包内容")
            Text("直接粘贴 Proxyman / Postman / Charles 复制的完整 URL、cURL 或 Token，自动识别填充")
                .font(.system(size: 8))
                .foregroundStyle(themeColor.animeOrTextSecondary)

            TextEditor(text: $smartInputText)
                .font(.system(size: 9, design: .monospaced))
                .scrollContentBackground(.hidden)
                .foregroundStyle(themeColor.animeOrTextPrimary)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(themeColor.animeOrButton))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(themeColor.animeOrBorder, lineWidth: 0.5))
                .frame(height: 55)

            HStack {
                Button(action: runSmartParse) {
                    HStack(spacing: 4) {
                        Image(systemName: "wand.and.stars")
                        Text("一键识别并填充")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(themeColor.animeOrAccent))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                if let notice = smartParseNotice {
                    Text(notice)
                        .font(.system(size: 8))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrCardBackground))
    }

    private func runSmartParse() {
        let res = NIOVehicleLib.smartParseInput(smartInputText)
        var count = 0
        if let token = res.vehicleToken, !token.isEmpty {
            vehicleToken = token
            count += 1
        }
        if let vid = res.vehicleId, !vid.isEmpty {
            vehicleId = vid
            count += 1
        }
        if let did = res.deviceId, !did.isEmpty {
            deviceId = did
            count += 1
        }
        if let vurl = res.vehicleURL, !vurl.isEmpty {
            vehicleURL = vurl
            count += 1
        }
        if let curl = res.changeURL, !curl.isEmpty {
            changeURL = curl
            count += 1
        }
        if let kurl = res.checkinURL, !kurl.isEmpty {
            checkinURL = kurl
            count += 1
        }
        if let mode = res.mode {
            apiMode = mode
        }
        if count > 0 {
            smartParseNotice = "已成功提取 \(count) 项配置！"
            smartInputText = ""
        } else {
            smartParseNotice = "未能识别出配置项，请检查粘贴的内容"
        }
    }

    // MARK: - 模式切换

    private var modeSelectorSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("车辆接口模式")
            HStack(spacing: 8) {
                modeOption(id: "url", title: "URL 抓包模式", desc: "直接填入包含 sign 的 URL")
                modeOption(id: "widget", title: "Widget 动态签名 (推荐)", desc: "填入 Secret 每次动态计算，永不过期")
            }
        }
    }

    private func modeOption(id: String, title: String, desc: String) -> some View {
        Button(action: { apiMode = id }) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: apiMode == id ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(apiMode == id ? themeColor.animeOrAccent : themeColor.animeOrTextSecondary)
                    Text(title)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(themeColor.animeOrTextPrimary)
                }
                Text(desc)
                    .font(.system(size: 7))
                    .foregroundStyle(themeColor.animeOrTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(apiMode == id ? themeColor.animeOrAccent.opacity(0.1) : themeColor.animeOrButton))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(apiMode == id ? themeColor.animeOrAccent.opacity(0.4) : Color.clear, lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Widget 动态签名模式配置

    private var widgetModeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Widget 动态签名配置")
            labeledField("Vehicle ID (车辆ID)", text: $vehicleId, placeholder: "如 17位VIN 或 9位ID", secure: false)
            labeledField("Device ID (设备ID)", text: $deviceId, placeholder: "抓包中的 device_id", secure: false)
            labeledField("Sign Secret (签名密钥)", text: $vehicleSignSecret, placeholder: "动态签名密钥，填入后每次自动生成有效签名", secure: true)

            HStack {
                Text("签名算法:")
                    .font(.system(size: 8))
                    .foregroundStyle(themeColor.animeOrTextSecondary)
                Picker("", selection: $vehicleSignAlgo) {
                    Text("md5(query + secret)").tag("md5_append")
                    Text("md5(secret + query)").tag("md5_prepend")
                    Text("md5(query + &key= + secret)").tag("md5_append_key")
                }
                .labelsHidden()
            }

            labeledField("Access Token (Bearer)", text: $vehicleToken, placeholder: "抓包得到的 Bearer Token", secure: true)
        }
    }

    // MARK: - URL 模式配置

    private var vehicleUrlSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("车辆 API（RVS 状态抓包 URL）")
            labeledField("完整 API URL", text: $vehicleURL, placeholder: "https://icar.nio.com/api/2/rvs/vehicle/... 或 https://app.nio.com/...", secure: false)
            labeledField("Access Token (Bearer)", text: $vehicleToken, placeholder: "Bearer Token", secure: true)
        }
    }

    // MARK: - 换电服务配置

    private var changeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("换电 / 服务订单 API（可选）")
            labeledField("API URL", text: $changeURL, placeholder: "https://gateway-front-external.nio.com/...", secure: false)
            labeledField("Access Token（留空则共用车辆 Token）", text: $changeToken, placeholder: "Bearer Token", secure: true)
        }
    }

    // MARK: - 签到配置

    private var checkinSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("签到 API（可选）")
            labeledField("API URL", text: $checkinURL, placeholder: "https://gateway-front-external.nio.com/...", secure: false)
            labeledField("Access Token（留空则共用车辆 Token）", text: $checkinToken, placeholder: "Bearer Token", secure: true)
        }
    }

    // MARK: - 一键诊断功能

    private var diagnosticSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("🩺 一键连接与鉴权诊断")
            Text("测试车辆接口连通性、Token 有效性与 403 鉴权过期排查")
                .font(.system(size: 8))
                .foregroundStyle(themeColor.animeOrTextSecondary)

            Button(action: startDiagnostic) {
                HStack(spacing: 6) {
                    Image(systemName: isDiagnosing ? "waveform.path.ecg" : "stethoscope")
                    Text(isDiagnosing ? "正在诊断测试中…" : "开始一键诊断测试")
                }
                .font(.system(size: 10, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(themeColor.animeOrButton))
                .foregroundStyle(themeColor.animeOrAccent)
            }
            .buttonStyle(.plain)
            .disabled(isDiagnosing)

            if let report = diagnosticReport {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(report.steps) { step in
                        HStack(spacing: 6) {
                            stepStatusIcon(step.status)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(step.name)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(themeColor.animeOrTextPrimary)
                                Text(step.detail)
                                    .font(.system(size: 8))
                                    .foregroundStyle(themeColor.animeOrTextSecondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if !report.summary.isEmpty {
                        Text(report.summary)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(report.is403Detected ? .orange : themeColor.animeOrTextPrimary)
                            .padding(.top, 4)
                    }

                    if !report.recommendation.isEmpty {
                        Text(report.recommendation)
                            .font(.system(size: 8))
                            .foregroundStyle(themeColor.animeOrAccent)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrAccent.opacity(0.1)))
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(themeColor.animeOrButton.opacity(0.4)))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrCardBackground))
    }

    private func stepStatusIcon(_ status: NIODiagnosticStep.StepStatus) -> some View {
        switch status {
        case .pending:
            return Image(systemName: "circle").foregroundStyle(themeColor.animeOrTextSecondary).font(.system(size: 10))
        case .running:
            return Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(themeColor.animeOrAccent).font(.system(size: 10))
        case .success:
            return Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 10))
        case .warning:
            return Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.system(size: 10))
        case .failure:
            return Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.system(size: 10))
        }
    }

    private func startDiagnostic() {
        saveTemporarySettings()
        isDiagnosing = true
        Task {
            let res = await NIOService.shared.runDiagnostic()
            self.diagnosticReport = res
            self.isDiagnosing = false
        }
    }

    // MARK: - 看板卡片显隐控制

    private var cardDisplaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("看板卡片显示定制")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(NIOCardRegistry.allCards) { card in
                    Button(action: { toggleCard(card.id) }) {
                        HStack(spacing: 4) {
                            Image(systemName: !hiddenCards.contains(card.id) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 9))
                                .foregroundStyle(!hiddenCards.contains(card.id) ? themeColor.animeOrAccent : themeColor.animeOrTextSecondary)
                            Text(card.label)
                                .font(.system(size: 8))
                                .foregroundStyle(themeColor.animeOrTextPrimary)
                            Spacer()
                        }
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleCard(_ id: String) {
        if hiddenCards.contains(id) {
            hiddenCards.remove(id)
        } else {
            hiddenCards.insert(id)
        }
    }

    // MARK: - 轮询间隔

    private var pollSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("拉取调度间隔（秒）与显示偏好")
            HStack(spacing: 8) {
                intervalField("行驶中", text: $drivingSec)
                intervalField("白天 (09-17)", text: $daySec)
                intervalField("夜间", text: $nightSec)
                intervalField("换电订单", text: $changeInterval)
            }

            Toggle(isOn: $preferActualRange) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("🎯 电量里程默认首选实估")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(themeColor.animeOrTextPrimary)
                    Text("开启后看板默认优先展示结合驾驶能耗计算的实际估算续航，标准续航作为副标")
                        .font(.system(size: 8))
                        .foregroundStyle(themeColor.animeOrTextSecondary)
                }
            }
            .toggleStyle(.checkbox)
            .padding(.top, 4)
        }
    }

    // MARK: - 状态栏显示项

    private var trayDisplaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("状态栏显示项")
            Text("预览：\(previewTitle())")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(themeColor.animeOrTextSecondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(NIODisplayField.allCases) { field in
                    Button(action: { toggleField(field) }) {
                        HStack(spacing: 4) {
                            Image(systemName: trayFields.contains(field) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 9))
                                .foregroundStyle(trayFields.contains(field) ? themeColor.animeOrAccent : themeColor.animeOrTextSecondary)
                            Text(field.label)
                                .font(.system(size: 9))
                                .foregroundStyle(themeColor.animeOrTextPrimary)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 保存按钮

    private var saveButton: some View {
        Button(action: save) {
            Text("保存并同步配置")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8).fill(themeColor.animeOrAccent))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionTitle(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(themeColor.animeOrAccent)
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(themeColor.animeOrTextSecondary)
            if secure {
                SecureField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9, design: .monospaced))
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton))
            } else {
                TextField(placeholder, text: text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9, design: .monospaced))
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton))
            }
        }
    }

    private func intervalField(_ label: String, text: Binding<String>) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7))
                .foregroundStyle(themeColor.animeOrTextSecondary)
            TextField("0", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 9, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 4).fill(themeColor.animeOrButton))
        }
    }

    private func toggleField(_ field: NIODisplayField) {
        if trayFields.contains(field) {
            if trayFields.count > 1 { trayFields.remove(field) }
        } else {
            trayFields.insert(field)
        }
    }

    private func previewTitle() -> String {
        NIODisplayField.allCases.filter { trayFields.contains($0) }.map { $0.example }.joined(separator: " · ")
    }

    private func loadFromSettings() {
        let s = settings
        nioEnabled = s.nioEnabled
        apiMode = s.nioVehicleApiMode
        vehicleURL = s.nioVehicleApiURL
        vehicleToken = s.nioVehicleAccessToken
        vehicleId = s.nioVehicleId
        deviceId = s.nioDeviceId
        vehicleSignSecret = s.nioVehicleSignSecret
        vehicleSignAlgo = s.nioVehicleSignAlgo
        changeURL = s.nioChangeApiURL
        changeToken = s.nioChangeAccessToken
        checkinURL = s.nioCheckinApiURL
        checkinToken = s.nioCheckinAccessToken
        let d = s.nioPollDrivingSec == 900 ? 300 : s.nioPollDrivingSec
        let day = s.nioPollDaySec == 1800 ? 300 : s.nioPollDaySec
        let night = s.nioPollNightSec == 3600 ? 300 : s.nioPollNightSec
        let chg = s.nioChangePollIntervalSec == 3600 ? 600 : s.nioChangePollIntervalSec
        drivingSec = String(d)
        daySec = String(day)
        nightSec = String(night)
        changeInterval = String(chg)
        trayFields = Set(s.nioTrayDisplayFields)
        hiddenCards = Set(s.nioHiddenCards)
        preferActualRange = s.nioPreferActualRange
    }

    private func saveTemporarySettings() {
        let s = settings
        var newSettings = s
        newSettings.nioEnabled = nioEnabled
        newSettings.nioVehicleApiMode = apiMode
        newSettings.nioVehicleApiURL = vehicleURL.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioVehicleAccessToken = vehicleToken.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioVehicleId = vehicleId.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioDeviceId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioVehicleSignSecret = vehicleSignSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioVehicleSignAlgo = vehicleSignAlgo
        newSettings.nioPreferActualRange = preferActualRange
        DependencyContainer.shared.settingsService.updateSettings(newSettings)
    }

    private func save() {
        let s = settings
        var newSettings = s
        newSettings.nioEnabled = nioEnabled
        newSettings.nioVehicleApiMode = apiMode
        newSettings.nioVehicleApiURL = vehicleURL.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioVehicleAccessToken = vehicleToken.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioVehicleId = vehicleId.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioDeviceId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioVehicleSignSecret = vehicleSignSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioVehicleSignAlgo = vehicleSignAlgo
        newSettings.nioChangeApiURL = changeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioChangeAccessToken = changeToken.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioCheckinApiURL = checkinURL.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioCheckinAccessToken = checkinToken.trimmingCharacters(in: .whitespacesAndNewlines)
        newSettings.nioPollDrivingSec = Int(drivingSec) ?? 300
        newSettings.nioPollDaySec = Int(daySec) ?? 300
        newSettings.nioPollNightSec = Int(nightSec) ?? 300
        newSettings.nioChangePollIntervalSec = Int(changeInterval) ?? 600
        newSettings.nioTrayDisplayFields = NIODisplayField.allCases.filter { trayFields.contains($0) }
        newSettings.nioHiddenCards = Array(hiddenCards)
        newSettings.nioPreferActualRange = preferActualRange

        DependencyContainer.shared.settingsService.updateSettings(newSettings)
        NIOService.shared.stopScheduling()
        NIOService.shared.startScheduling()
        NIOService.shared.refreshAll()
        if let onSaved {
            onSaved()
        } else {
            dismiss()
        }
    }
}

