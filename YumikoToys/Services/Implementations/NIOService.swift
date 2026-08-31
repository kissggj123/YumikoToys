//
//  NIOService.swift
//  YumikoToys
//
//  蔚来 NIO 数据服务（API 拉取 + 动态签名 + 内存缓存 + 运行诊断 + 持久化）
//  从 NIO-Dash TypeScript 重构
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class NIOService: ObservableObject {

    // MARK: - Published 状态

    @Published var vehicleData: NIOVehicleResponse?
    @Published var serviceSummary: NIOServiceSummary?
    @Published var checkinData: NIOCheckinData?
    @Published var history: [NIOVehicleSnapshot] = []
    @Published var dailyPaths: [NIODailyPath] = []
    @Published var dailyMileageDeltas: [NIODailyDelta] = []
    @Published var fetchLogs: [NIOFetchLogEntry] = []
    @Published var isLoadingVehicle = false
    @Published var isLoadingChange = false
    @Published var isLoadingCheckin = false
    @Published var lastError: String?
    @Published var lastVehicleFetch: Date?
    @Published var lastChangeFetch: Date?
    @Published var lastCheckinFetch: Date?
    @Published var is403Detected = false

    // MARK: - 调度状态

    private var vehicleTimer: Timer?
    private var changeTimer: Timer?
    private var checkinTimer: Timer?

    // MARK: - 网络 Session（配置 15 秒超时，避免网络假死导致界面卡顿）

    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    // MARK: - 数据目录

    private let dataDir: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("YumikoToys", isDirectory: true)
            .appendingPathComponent("nio-data", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private var vehicleFile: URL { dataDir.appendingPathComponent("vehicle.json") }
    private var cachedTyreFile: URL { dataDir.appendingPathComponent("cached-tyre.json") }
    private var cachedLvBattFile: URL { dataDir.appendingPathComponent("cached-lv-batt.json") }
    private var cachedKeyFile: URL { dataDir.appendingPathComponent("cached-key.json") }
    private var cachedHeatingFile: URL { dataDir.appendingPathComponent("cached-heating.json") }
    private var cachedWindowFile: URL { dataDir.appendingPathComponent("cached-window.json") }
    private var cachedFrdgFile: URL { dataDir.appendingPathComponent("cached-frdg.json") }
    private var cachedBoxFile: URL { dataDir.appendingPathComponent("cached-box.json") }
    private var cachedLightFile: URL { dataDir.appendingPathComponent("cached-light.json") }
    private var changeFile: URL { dataDir.appendingPathComponent("change.json") }
    private var checkinFile: URL { dataDir.appendingPathComponent("checkin.json") }
    private var checkinMetaFile: URL { dataDir.appendingPathComponent("checkin-meta.json") }
    private var historyFile: URL { dataDir.appendingPathComponent("history.json") }
    private var fetchLogFile: URL { dataDir.appendingPathComponent("fetch-log.json") }

    private var cachedTyreStatus: [String: NIOJSONValue]? = nil
    private var cachedLvBattStatus: [String: NIOJSONValue]? = nil
    private var cachedKeyStatus: [String: NIOJSONValue]? = nil
    private var cachedHeatingStatus: [String: NIOJSONValue]? = nil
    private var cachedWindowStatus: [String: NIOJSONValue]? = nil
    private var cachedFrdgStatus: [String: NIOJSONValue]? = nil
    private var cachedBoxStatus: [String: NIOJSONValue]? = nil
    private var cachedLightStatus: [String: NIOJSONValue]? = nil

    static let shared = NIOService()

    private init() {
        loadAllFromDisk()
        startScheduling()
    }

    // MARK: - 配置读取

    private var settings: AppSettings {
        DependencyContainer.shared.settingsService.settings
    }

    var isConfigured: Bool {
        let s = settings
        let hasVehicle = (!s.nioVehicleApiURL.isEmpty && !s.nioVehicleAccessToken.isEmpty) ||
                         (!s.nioVehicleId.isEmpty && !s.nioDeviceId.isEmpty && !s.nioVehicleAccessToken.isEmpty)
        let hasChange = (!s.nioChangeApiURL.isEmpty && !s.nioChangeAccessToken.isEmpty)
        let hasCheckin = !s.nioCheckinApiURL.isEmpty
        return hasVehicle || hasChange || hasCheckin
    }

    // MARK: - 启动调度

    func startScheduling() {
        stopScheduling()
        guard isConfigured else { return }
        refreshAll()
        scheduleVehiclePoll()
        scheduleChangePoll()
        scheduleCheckinPoll()
    }

    func stopScheduling() {
        vehicleTimer?.invalidate(); vehicleTimer = nil
        changeTimer?.invalidate(); changeTimer = nil
        checkinTimer?.invalidate(); checkinTimer = nil
    }

    private var lastFetchTimestamp: Date? = nil

    private func scheduleVehiclePoll() {
        vehicleTimer?.invalidate()
        let s = settings
        guard !s.nioVehicleApiURL.isEmpty || (!s.nioVehicleId.isEmpty && !s.nioDeviceId.isEmpty) else { return }
        let state = vehicleData?.data?.status?.exteriorStatus?.vehicleState
        let result = NIOPollSchedule.vehiclePollInterval(
            driving: s.nioPollDrivingSec,
            day: s.nioPollDaySec,
            night: s.nioPollNightSec,
            vehicleState: state
        )
        // 5 分钟 (300 秒) 周期性定时拉取，若 403 则退避 15 分钟 (900秒) 避免撞车
        let targetInterval = max(60, result.intervalSec)
        let baseInterval = is403Detected ? max(900, TimeInterval(targetInterval)) : TimeInterval(targetInterval)
        let jitter = Double.random(in: -20...35)
        let interval = max(60, baseInterval + jitter)

        vehicleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in await self?.fetchVehicle() }
        }
    }

    private func scheduleChangePoll() {
        changeTimer?.invalidate()
        guard !settings.nioChangeApiURL.isEmpty else { return }
        let base = TimeInterval(NIOPollSchedule.changePollInterval(settings.nioChangePollIntervalSec))
        let jitter = Double.random(in: -15...30)
        let interval = max(60, base + jitter)
        changeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in await self?.fetchChange() }
        }
    }

    private func scheduleCheckinPoll() {
        checkinTimer?.invalidate()
        guard !settings.nioCheckinApiURL.isEmpty else { return }
        let ms = msUntilNextCheckinWake()
        let interval = TimeInterval(ms) / 1000
        checkinTimer = Timer.scheduledTimer(withTimeInterval: max(1, interval), repeats: false) { [weak self] _ in
            Task { @MainActor in await self?.fetchCheckin() }
        }
    }

    private func msUntilNextCheckinWake() -> Int {
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: now)

        if !NIOCheckinLib.isCheckinWindowOpen(now) {
            let todaySlot = cal.date(bySettingHour: NIOCheckinLib.checkinHour, minute: NIOCheckinLib.checkinMinute, second: 0, of: now) ?? now
            if now < todaySlot {
                return max(1000, Int(todaySlot.timeIntervalSince(now) * 1000))
            }
        }

        let dayKey = NIOCheckinLib.localDayKey(now)
        let meta = readCheckinMeta()
        if meta.runDay == dayKey {
            if checkinData?.checkedIn != true {
                let nextRetry = (meta.at ?? 0) + NIOCheckinLib.retryCooldownMs
                let nowMs = Int(now.timeIntervalSince1970 * 1000)
                if nowMs < nextRetry {
                    return max(1000, nextRetry - nowMs)
                }
                return 0
            }
            var tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
            tomorrow = cal.date(bySettingHour: NIOCheckinLib.checkinHour, minute: NIOCheckinLib.checkinMinute, second: 0, of: tomorrow) ?? tomorrow
            return max(1000, Int(tomorrow.timeIntervalSince(now) * 1000))
        }
        return 0
    }

    // MARK: - 手动刷新

    func refreshAll() {
        Task {
            async let v: () = fetchVehicle(force: true)
            async let c: () = fetchChange()
            async let k: () = fetchCheckin()
            _ = await (v, c, k)
        }
    }

    // MARK: - 车辆 API 拉取

    func fetchVehicle(force: Bool = false) async {
        let s = settings
        guard !isLoadingVehicle else { return }

        // 防抖节流阀：防止 10 秒内双端或连续点击造成的并发突发请求
        if !force, let last = lastFetchTimestamp, Date().timeIntervalSince(last) < 10.0 {
            return
        }

        var targetURL: URL?
        var requestMethod = "GET"

        // 1. 与 Electron 版 loadFetchConfig 一致的获取策略：优先原样重放抓包的完整 RVS URL。
        //    该 URL 的 field= 参数覆盖 tyre_status（胎压）等全部状态块；
        //    Widget 接口是桌面小组件的精简数据源，不含胎压块，仅作未配置 URL 时的回退。
        if !s.nioVehicleApiURL.isEmpty {
            let rawUrlStr = s.nioVehicleApiURL.trimmingCharacters(in: .whitespacesAndNewlines)
            var fullUrl = rawUrlStr
            if !rawUrlStr.lowercased().hasPrefix("http://") && !rawUrlStr.lowercased().hasPrefix("https://") {
                fullUrl = "https://\(rawUrlStr)"
            }
            if let resigned = NIOVehicleLib.autoResignRvsURL(fullUrl, secret: s.nioVehicleSignSecret, algo: s.nioVehicleSignAlgo) {
                targetURL = URL(string: resigned)
            }
            if targetURL == nil {
                targetURL = URL(string: fullUrl)
            }
        }

        // 2. 未配置 URL 且具备完整的 Widget 参数时，动态生成带当前时间戳和签名的 URL 回退
        if targetURL == nil,
           s.nioVehicleApiMode == "widget" || (!s.nioVehicleId.isEmpty && !s.nioDeviceId.isEmpty && !s.nioVehicleSignSecret.isEmpty) {
            if let built = NIOVehicleLib.buildWidgetURL(
                vehicleId: s.nioVehicleId,
                deviceId: s.nioDeviceId,
                secret: s.nioVehicleSignSecret,
                algo: s.nioVehicleSignAlgo.isEmpty ? "md5_append" : s.nioVehicleSignAlgo
            ) {
                targetURL = built.url
            }
        }

        guard let url = targetURL else { return }

        isLoadingVehicle = true
        defer {
            isLoadingVehicle = false
            scheduleVehiclePoll()
        }

        let finalURL = url

        var req = URLRequest(url: finalURL)
        req.httpMethod = requestMethod
        req.setValue("application/json,text/json,text/plain", forHTTPHeaderField: "Accept")
        req.setValue("zh-CN,zh-Hans;q=0.9", forHTTPHeaderField: "Accept-Language")

        let appVer = NIOVehicleLib.extractQueryParam(from: finalURL.absoluteString, key: "app_ver") ?? "6.5.3"
        req.setValue("NextevCar/\(appVer) (com.do1.WeiLaiApp; build:2586; iOS 26.2.1) Alamofire/5.9.1", forHTTPHeaderField: "User-Agent")

        let host = finalURL.host?.lowercased() ?? ""
        if host.contains("icar.nio.com") {
            req.setValue("tsp.nio.com", forHTTPHeaderField: "Host")
        }

        let token = normalizeBearer(s.nioVehicleAccessToken)
        if !token.isEmpty {
            req.setValue(token, forHTTPHeaderField: "Authorization")
        }

        let logEntry = NIOFetchLogEntry(
            category: "vehicle", level: "info",
            message: "车辆 · 开始拉取…",
            detail: nil, timestamp: Date(),
            requestURL: finalURL.absoluteString, requestMethod: requestMethod,
            requestBody: nil, responsePreview: nil, statusCode: nil
        )
        appendLog(logEntry)

        var httpResponse: HTTPURLResponse? = nil
        var responseText: String = ""

        do {
            let (data, response) = try await urlSession.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw NIOError.invalidJSON }
            httpResponse = http
            let text = String(data: data, encoding: .utf8) ?? ""
            responseText = text

            let rawJson = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
            let resultCode = (rawJson?["result_code"] as? String) ?? (rawJson?["resultCode"] as? String) ?? ""
            let debugMsg = (rawJson?["debug_msg"] as? String) ?? ""

            // 若 RVS 接口因参数签名校验不匹配（如 invalid_param 或 sign_failed），自动无感降级到小组件接口拉取并从落盘恢复胎压
            let isSignProblem = (resultCode == "sign_failed" || resultCode.contains("sign") || resultCode == "invalid_param" || debugMsg.contains("sign") || debugMsg.contains("timestamp") || debugMsg.contains("app_id"))
            if isSignProblem && finalURL.host?.contains("icar.nio.com") == true && !s.nioDeviceId.isEmpty && !s.nioVehicleId.isEmpty {
                LoggerService.shared.warning("[NIOService] RVS 签名不匹配，自动无感切换至小组件接口拉取并恢复胎压缓存...")
                var fallbackURL: URL? = nil
                if !s.nioVehicleSignSecret.isEmpty {
                    fallbackURL = NIOVehicleLib.buildWidgetURL(
                        vehicleId: s.nioVehicleId,
                        deviceId: s.nioDeviceId,
                        secret: s.nioVehicleSignSecret,
                        algo: s.nioVehicleSignAlgo.isEmpty ? "md5_append" : s.nioVehicleSignAlgo
                    )?.url
                }
                if fallbackURL == nil {
                    let sgn = NIOVehicleLib.extractQueryParam(from: finalURL.absoluteString, key: "sign") ?? ""
                    let ts = NIOVehicleLib.extractQueryParam(from: finalURL.absoluteString, key: "timestamp") ?? "\(Int(Date().timeIntervalSince1970))"
                    if !sgn.isEmpty {
                        let widgetStr = "https://app.nio.com/app/api/icar/v2/widget/info?widget_size=large&app_id=10002&widget_functions=rvs_set_doorlock%2Crvs_set_air_conditioner%2Crvs_set_tailgate%2Crvs_exe_findme&lang=zh-CN&region=cn&device_id=\(s.nioDeviceId)&timestamp=\(ts)&vehicle_id=\(s.nioVehicleId)&app_ver=6.7.15&sign=\(sgn)"
                        fallbackURL = URL(string: widgetStr)
                    }
                }
                if let fbURL = fallbackURL {
                    var fbReq = URLRequest(url: fbURL)
                    fbReq.httpMethod = "GET"
                    fbReq.setValue("application/json", forHTTPHeaderField: "Accept")
                    fbReq.setValue("VehicleWidgetExtension/6.7.15 (com.do1.WeiLaiApp.NIOVehicleWidget; build:2644; iOS 27.0.0) Alamofire/5.9.1", forHTTPHeaderField: "User-Agent")
                    if !token.isEmpty { fbReq.setValue(token, forHTTPHeaderField: "Authorization") }
                    if let (fbData, fbResp) = try? await urlSession.data(for: fbReq),
                       let fbHttp = fbResp as? HTTPURLResponse, fbHttp.statusCode == 200,
                       let fbJson = (try? JSONSerialization.jsonObject(with: fbData, options: [])) as? [String: Any],
                       let fbNormData = try? JSONSerialization.data(withJSONObject: RVSRormalizer.normalize(fbJson)),
                       let fbDecoded = try? JSONDecoder().decode(NIOVehicleResponse.self, from: fbNormData) {
                        var fbFinal = fbDecoded
                        if let cached = self.cachedTyreStatus {
                            fbFinal.data?.status?.tyreStatus = cached
                        }
                        self.vehicleData = fbFinal
                        self.lastVehicleFetch = Date()
                        self.lastFetchTimestamp = Date()
                        self.lastError = nil
                        self.is403Detected = false
                        saveJSONAsync(fbFinal, to: vehicleFile)
                        appendSnapshot(fbFinal)
                        updateLog(logEntry, statusCode: 200, preview: "Widget 智能回退成功（已恢复胎压缓存）")
                        return
                    }
                }
            }

            // 精准区分【签名不匹配 sign_failed】与【账号 Token 被踢 auth_failed】
            if resultCode == "sign_failed" || resultCode.contains("sign") {
                self.is403Detected = true
                let hint = "签名校验被拒 (sign_failed)：抓包 URL 的签名与当前 App 版本不匹配。请在蔚来 App 中下拉刷新重新抓取完整的状态 URL（请勿改动任何参数）。"
                self.lastError = hint
                updateLog(logEntry, statusCode: http.statusCode, preview: String(text.prefix(300)))
                throw NIOError.unauthorized403(hint)
            }

            if http.statusCode == 403 || http.statusCode == 401 || resultCode == "auth_failed" || resultCode.contains("auth") || resultCode.contains("token") {
                self.is403Detected = true
                let hint = "鉴权 Token 失效：蔚来账号已在其他设备重新登录或已过期。请重新抓取并更新 Token。"
                self.lastError = hint
                updateLog(logEntry, statusCode: http.statusCode, preview: String(text.prefix(300)))
                throw NIOError.unauthorized403(hint)
            }

            if http.statusCode != 200 {
                throw NIOError.httpError(http.statusCode, String(text.prefix(500)))
            }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw NIOError.emptyResponse
            }

            guard let rawDict = rawJson else { throw NIOError.invalidJSON }

            let normalized = RVSRormalizer.normalize(rawDict)
            let normalizedData = try JSONSerialization.data(withJSONObject: normalized)
            let decoded = try JSONDecoder().decode(NIOVehicleResponse.self, from: normalizedData)
            var finalDecoded = decoded

            // 智能数据继承与落盘缓存：当车辆驻车休眠或使用精简 Widget 接口时，若未包含有效字段，自动继承与落盘全量有效数据
            // 1. 胎压
            if NIOVehicleLib.extractTyreInfo(finalDecoded.data?.status?.tyreStatus).hasData {
                if let newTyre = finalDecoded.data?.status?.tyreStatus {
                    self.cachedTyreStatus = newTyre
                    saveJSONAsync(newTyre, to: cachedTyreFile)
                }
            } else {
                if let oldTyre = self.vehicleData?.data?.status?.tyreStatus, NIOVehicleLib.extractTyreInfo(oldTyre).hasData {
                    finalDecoded.data?.status?.tyreStatus = oldTyre
                } else if let cached = self.cachedTyreStatus, NIOVehicleLib.extractTyreInfo(cached).hasData {
                    finalDecoded.data?.status?.tyreStatus = cached
                }
            }

            // 2. 12V 辅助蓄电池
            if let newLv = finalDecoded.data?.status?.lvBattStatus, !newLv.isEmpty {
                self.cachedLvBattStatus = newLv
                saveJSONAsync(newLv, to: cachedLvBattFile)
            } else {
                if let oldLv = self.vehicleData?.data?.status?.lvBattStatus, !oldLv.isEmpty {
                    finalDecoded.data?.status?.lvBattStatus = oldLv
                } else if let cached = self.cachedLvBattStatus, !cached.isEmpty {
                    finalDecoded.data?.status?.lvBattStatus = cached
                }
            }

            // 3. 智能钥匙感应
            if let newKey = finalDecoded.data?.status?.keyStatus, !newKey.isEmpty {
                self.cachedKeyStatus = newKey
                saveJSONAsync(newKey, to: cachedKeyFile)
            } else {
                if let oldKey = self.vehicleData?.data?.status?.keyStatus, !oldKey.isEmpty {
                    finalDecoded.data?.status?.keyStatus = oldKey
                } else if let cached = self.cachedKeyStatus, !cached.isEmpty {
                    finalDecoded.data?.status?.keyStatus = cached
                }
            }

            // 4. 座椅舒适与方向盘加热
            if let newHeat = finalDecoded.data?.status?.heatingStatus, !newHeat.isEmpty {
                self.cachedHeatingStatus = newHeat
                saveJSONAsync(newHeat, to: cachedHeatingFile)
            } else {
                if let oldHeat = self.vehicleData?.data?.status?.heatingStatus, !oldHeat.isEmpty {
                    finalDecoded.data?.status?.heatingStatus = oldHeat
                } else if let cached = self.cachedHeatingStatus, !cached.isEmpty {
                    finalDecoded.data?.status?.heatingStatus = cached
                }
            }

            // 5. 车窗开度
            if let newWin = finalDecoded.data?.status?.windowStatus, !newWin.isEmpty {
                self.cachedWindowStatus = newWin
                saveJSONAsync(newWin, to: cachedWindowFile)
            } else {
                if let oldWin = self.vehicleData?.data?.status?.windowStatus, !oldWin.isEmpty {
                    finalDecoded.data?.status?.windowStatus = oldWin
                } else if let cached = self.cachedWindowStatus, !cached.isEmpty {
                    finalDecoded.data?.status?.windowStatus = cached
                }
            }

            // 6. 车载冰箱与储物
            if let newFrdg = finalDecoded.data?.status?.frdgStatus, !newFrdg.isEmpty {
                self.cachedFrdgStatus = newFrdg
                saveJSONAsync(newFrdg, to: cachedFrdgFile)
            } else {
                if let oldFrdg = self.vehicleData?.data?.status?.frdgStatus, !oldFrdg.isEmpty {
                    finalDecoded.data?.status?.frdgStatus = oldFrdg
                } else if let cached = self.cachedFrdgStatus, !cached.isEmpty {
                    finalDecoded.data?.status?.frdgStatus = cached
                }
            }
            if let newBox = finalDecoded.data?.status?.boxStatus, !newBox.isEmpty {
                self.cachedBoxStatus = newBox
                saveJSONAsync(newBox, to: cachedBoxFile)
            } else {
                if let oldBox = self.vehicleData?.data?.status?.boxStatus, !oldBox.isEmpty {
                    finalDecoded.data?.status?.boxStatus = oldBox
                } else if let cached = self.cachedBoxStatus, !cached.isEmpty {
                    finalDecoded.data?.status?.boxStatus = cached
                }
            }

            // 7. 车外灯光
            if let newLight = finalDecoded.data?.status?.lightStatus, !newLight.isEmpty {
                self.cachedLightStatus = newLight
                saveJSONAsync(newLight, to: cachedLightFile)
            } else {
                if let oldLight = self.vehicleData?.data?.status?.lightStatus, !oldLight.isEmpty {
                    finalDecoded.data?.status?.lightStatus = oldLight
                } else if let cached = self.cachedLightStatus, !cached.isEmpty {
                    finalDecoded.data?.status?.lightStatus = cached
                }
            }

            // 8. 空调与座舱温度
            if finalDecoded.data?.status?.hvacStatus?.temperature == nil {
                if let oldTemp = self.vehicleData?.data?.status?.hvacStatus?.temperature {
                    if finalDecoded.data?.status?.hvacStatus != nil {
                        finalDecoded.data?.status?.hvacStatus?.temperature = oldTemp
                    } else {
                        finalDecoded.data?.status?.hvacStatus = NIOHvacStatus(temperature: oldTemp)
                    }
                }
            }
            if finalDecoded.data?.status?.hvacStatus?.outsideTemperature == nil {
                if let oldOutTemp = self.vehicleData?.data?.status?.hvacStatus?.outsideTemperature {
                    finalDecoded.data?.status?.hvacStatus?.outsideTemperature = oldOutTemp
                }
            }

            self.vehicleData = finalDecoded
            self.lastVehicleFetch = Date()
            self.lastFetchTimestamp = Date()
            self.lastError = nil
            self.is403Detected = false

            // 异步后台落盘，绝不阻塞主线程
            saveJSONAsync(finalDecoded, to: vehicleFile)

            appendSnapshot(finalDecoded)
            updateLog(logEntry, statusCode: http.statusCode, preview: String(text.prefix(200)))

            LoggerService.shared.info("[NIOService] 车辆拉取成功")

            if let checkedIn = finalDecoded.data?.checkedIn {
                let ci = NIOCheckinData(
                    checkedIn: checkedIn.checked ?? false,
                    continuousDays: checkedIn.days ?? 0
                )
                self.checkinData = ci
                saveJSONAsync(ci, to: checkinFile)
            }
        } catch let err as DecodingError {
                let desc: String
                switch err {
                case .typeMismatch(let type, let context):
                    desc = "类型不匹配: 期望 \(type), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)"
                case .valueNotFound(let type, let context):
                    desc = "缺少值: \(type), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)"
                case .keyNotFound(let key, let context):
                    desc = "缺少字段: \(key.stringValue), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)"
                case .dataCorrupted(let context):
                    desc = "数据损坏: 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")) - \(context.debugDescription)"
                @unknown default:
                    desc = err.localizedDescription
                }
                self.lastError = desc
                appendLog(NIOFetchLogEntry(
                    category: "vehicle", level: "error",
                    message: "解析失败：\(desc)", detail: desc,
                    timestamp: Date(),
                    requestURL: finalURL.absoluteString, requestMethod: requestMethod,
                    requestBody: nil, responsePreview: responseText.isEmpty ? nil : String(responseText.prefix(300)), statusCode: httpResponse?.statusCode
                ))
                LoggerService.shared.warning("[NIOService] 车辆解码失败: \(desc)")
            } catch {
                let nsErr = error as NSError
                if error is CancellationError || (error as? URLError)?.code == .cancelled || nsErr.code == NSURLErrorCancelled || error.localizedDescription.lowercased().contains("cancel") {
                    return
                }
                let msg = error.localizedDescription
                self.lastError = msg
                appendLog(NIOFetchLogEntry(
                    category: "vehicle", level: "error",
                    message: "拉取失败：\(msg)", detail: msg,
                    timestamp: Date(),
                    requestURL: finalURL.absoluteString, requestMethod: requestMethod,
                    requestBody: nil, responsePreview: responseText.isEmpty ? nil : String(responseText.prefix(300)), statusCode: httpResponse?.statusCode
                ))
                LoggerService.shared.warning("[NIOService] 车辆拉取失败: \(msg)")
            }
    }

    // MARK: - 换电 API 拉取

    func fetchChange() async {
        let s = settings
        var changeURLStr = s.nioChangeApiURL
        if changeURLStr.contains("app.nio.com/app/api/service_charge") {
            changeURLStr = "https://gateway-front-external.nio.com/moat/1100367/api/v1/otd/car/ext/general/serviceOrder/getTabOrder?offset=0&limit=200&orderTypes=pe_shaman,pe_shaman_change,service_pe_discharge,battery_flexible_upgrade,nsom_so_maintenance,nsom_so_chauffeur,chauffeur_vehicle_delivery,so_case_accident&hash_type=sha256&lang=zh&region=US&tz_offset=28800&app_ver=6.5.3"
        }
        guard !changeURLStr.isEmpty else { return }
        guard !isLoadingChange else { return }
        isLoadingChange = true
        defer { isLoadingChange = false }

        do {
            let url = try URL(string: changeURLStr) ?? { throw NIOError.configError("换电 API URL 无效") }()
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("VehicleWidgetExtension/6.5.3 (com.do1.WeiLaiApp.NIOVehicleWidget; build:2612; iOS 26.5.0) Alamofire/5.9.1", forHTTPHeaderField: "User-Agent")
            let token = normalizeBearer(s.nioChangeAccessToken.isEmpty ? s.nioVehicleAccessToken : s.nioChangeAccessToken)
            if !token.isEmpty {
                req.setValue(token, forHTTPHeaderField: "Authorization")
            }

            appendLog(NIOFetchLogEntry(
                category: "change", level: "info",
                message: "换电 · 开始拉取…",
                detail: nil, timestamp: Date(),
                requestURL: changeURLStr, requestMethod: "POST",
                requestBody: nil, responsePreview: nil, statusCode: nil
            ))

            let (data, response) = try await urlSession.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw NIOError.invalidJSON }
            let text = String(data: data, encoding: .utf8) ?? ""

            if http.statusCode != 200 {
                throw NIOError.httpError(http.statusCode, String(text.prefix(500)))
            }

            let decoded = try JSONDecoder().decode(NIOChangeResponse.self, from: data)
            let summary = NIOOrderLib.analyzeServiceOrders(decoded)
            self.serviceSummary = summary
            self.lastChangeFetch = Date()

            saveJSONAsync(decoded, to: changeFile)
            appendLog(NIOFetchLogEntry(
                category: "change", level: "info",
                message: "换电拉取成功（\(summary.total) 单）",
                detail: nil, timestamp: Date(),
                requestURL: nil, requestMethod: nil,
                requestBody: nil, responsePreview: String(text.prefix(200)), statusCode: http.statusCode
            ))
            LoggerService.shared.info("[NIOService] 换电拉取成功")
        } catch {
            let msg = error.localizedDescription
            self.lastError = msg
            appendLog(NIOFetchLogEntry(
                category: "change", level: "error",
                message: "换电拉取失败：\(msg)", detail: msg,
                timestamp: Date(),
                requestURL: s.nioChangeApiURL, requestMethod: "POST",
                requestBody: nil, responsePreview: nil, statusCode: nil
            ))
            LoggerService.shared.warning("[NIOService] 换电拉取失败: \(msg)")
        }

        scheduleChangePoll()
    }

    // MARK: - 签到 API 拉取

    func fetchCheckin() async {
        let s = settings
        var checkinURLStr = s.nioCheckinApiURL
        if checkinURLStr.contains("app.nio.com/app/api/users/checkin") {
            checkinURLStr = "https://gateway-front-external.nio.com/moat/10086//n/c/award/square?event=checkin&collection_id=1843940587332317185"
        }
        guard !checkinURLStr.isEmpty else { return }
        guard !isLoadingCheckin else { return }
        isLoadingCheckin = true
        defer { isLoadingCheckin = false }

        do {
            let url = try URL(string: checkinURLStr) ?? { throw NIOError.configError("签到 API URL 无效") }()
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("VehicleWidgetExtension/6.5.3 (com.do1.WeiLaiApp.NIOVehicleWidget; build:2612; iOS 26.5.0) Alamofire/5.9.1", forHTTPHeaderField: "User-Agent")
            let token = normalizeBearer(s.nioCheckinAccessToken.isEmpty ? s.nioVehicleAccessToken : s.nioCheckinAccessToken)
            if !token.isEmpty {
                req.setValue(token, forHTTPHeaderField: "Authorization")
            }

            appendLog(NIOFetchLogEntry(
                category: "checkin", level: "info",
                message: "签到 · 开始拉取…",
                detail: nil, timestamp: Date(),
                requestURL: checkinURLStr, requestMethod: "GET",
                requestBody: nil, responsePreview: nil, statusCode: nil
            ))

            let (data, response) = try await urlSession.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw NIOError.invalidJSON }

            if http.statusCode != 200 {
                let text = String(data: data, encoding: .utf8) ?? ""
                throw NIOError.httpError(http.statusCode, String(text.prefix(500)))
            }

            let raw = try JSONSerialization.jsonObject(with: data, options: [])
            let normalized = NIOCheckinLib.normalizeCheckinData(raw)
            if let ci = normalized {
                self.checkinData = ci
                self.lastCheckinFetch = Date()
                saveJSONAsync(ci, to: checkinFile)
                saveCheckinMeta(ok: true, error: nil)
            }
            appendLog(NIOFetchLogEntry(
                category: "checkin", level: "info",
                message: "签到拉取成功（\(normalized?.checkedIn == true ? "已签到" : "未签到")）",
                detail: nil, timestamp: Date(),
                requestURL: nil, requestMethod: nil,
                requestBody: nil, responsePreview: nil, statusCode: http.statusCode
            ))
            LoggerService.shared.info("[NIOService] 签到拉取成功")
        } catch {
            let msg = error.localizedDescription
            self.lastError = msg
            saveCheckinMeta(ok: false, error: msg)
            appendLog(NIOFetchLogEntry(
                category: "checkin", level: "error",
                message: "签到拉取失败：\(msg)", detail: msg,
                timestamp: Date(),
                requestURL: s.nioCheckinApiURL, requestMethod: "GET",
                requestBody: nil, responsePreview: nil, statusCode: nil
            ))
            LoggerService.shared.warning("[NIOService] 签到拉取失败: \(msg)")
        }

        scheduleCheckinPoll()
    }

    // MARK: - 一键诊断连接测试

    func runDiagnostic() async -> NIODiagnosticReport {
        var report = NIODiagnosticReport()
        report.isRunning = true

        let s = settings

        // 步骤 1：配置检查
        var configDetail = ""
        let hasUrl = !s.nioVehicleApiURL.isEmpty
        let hasWidgetParams = !s.nioVehicleId.isEmpty && !s.nioDeviceId.isEmpty
        let hasToken = !s.nioVehicleAccessToken.isEmpty

        if hasWidgetParams && !s.nioVehicleSignSecret.isEmpty {
            configDetail = "已配置 Widget 动态签名模式 (Vehicle ID: \(s.nioVehicleId), Device ID: \(s.nioDeviceId))"
            report.steps.append(NIODiagnosticStep(name: "配置参数校验", status: .success, detail: configDetail))
        } else if hasUrl {
            configDetail = "已配置 URL 模式 (URL: \(s.nioVehicleApiURL.prefix(45))...)"
            report.steps.append(NIODiagnosticStep(name: "配置参数校验", status: .success, detail: configDetail))
        } else {
            report.steps.append(NIODiagnosticStep(name: "配置参数校验", status: .failure, detail: "尚未配置车辆 API URL 或 Widget 参数"))
            report.summary = "配置不完整，请先填写车辆 API 配置。"
            report.isRunning = false
            return report
        }

        // 步骤 2：Token 格式校验
        if hasToken {
            let token = s.nioVehicleAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.contains(where: { $0.asciiValue == nil }) {
                report.steps.append(NIODiagnosticStep(name: "Token 格式与编码", status: .failure, detail: "Token 包含非 ASCII 字符，请确认复制的是英文 Token"))
            } else {
                report.steps.append(NIODiagnosticStep(name: "Token 格式与编码", status: .success, detail: "Bearer Token 格式有效 (长度: \(token.count))"))
            }
        } else {
            report.steps.append(NIODiagnosticStep(name: "Token 格式与编码", status: .warning, detail: "未填写 Access Token（部分接口可能需鉴权）"))
        }

        // 步骤 3：动态签名校验
        if s.nioVehicleApiMode == "widget" || (hasWidgetParams && !s.nioVehicleSignSecret.isEmpty) {
            if let built = NIOVehicleLib.buildWidgetURL(
                vehicleId: s.nioVehicleId,
                deviceId: s.nioDeviceId,
                secret: s.nioVehicleSignSecret,
                algo: s.nioVehicleSignAlgo.isEmpty ? "md5_append" : s.nioVehicleSignAlgo
            ) {
                report.steps.append(NIODiagnosticStep(name: "动态 MD5 签名生成", status: .success, detail: "成功生成当前时间戳 (\(built.timestamp)) 与 32位签名 (\(built.sign))"))
            } else {
                report.steps.append(NIODiagnosticStep(name: "动态 MD5 签名生成", status: .failure, detail: "未能成功计算签名，请检查 Vehicle ID 与 Secret"))
            }
        }

        // 步骤 4：网络请求与 403 鉴权检测
        var targetURL: URL?
        if hasUrl {
            let rawUrlStr = s.nioVehicleApiURL.trimmingCharacters(in: .whitespacesAndNewlines)
            var fullUrl = rawUrlStr
            if !rawUrlStr.lowercased().hasPrefix("http://") && !rawUrlStr.lowercased().hasPrefix("https://") {
                fullUrl = "https://\(rawUrlStr)"
            }
            if let resigned = NIOVehicleLib.autoResignRvsURL(fullUrl, secret: s.nioVehicleSignSecret, algo: s.nioVehicleSignAlgo) {
                targetURL = URL(string: resigned)
            }
            if targetURL == nil {
                targetURL = URL(string: fullUrl)
            }
        } else if s.nioVehicleApiMode == "widget" || (hasWidgetParams && !s.nioVehicleSignSecret.isEmpty) {
            targetURL = NIOVehicleLib.buildWidgetURL(
                vehicleId: s.nioVehicleId,
                deviceId: s.nioDeviceId,
                secret: s.nioVehicleSignSecret,
                algo: s.nioVehicleSignAlgo.isEmpty ? "md5_append" : s.nioVehicleSignAlgo
            )?.url
        }

        guard let testURL = targetURL else {
            report.steps.append(NIODiagnosticStep(name: "网络请求测试", status: .failure, detail: "URL 无法解析"))
            report.summary = "URL 无效"
            report.isRunning = false
            return report
        }

        do {
            var req = URLRequest(url: testURL)
            req.httpMethod = "GET"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("VehicleWidgetExtension/6.5.3 (com.do1.WeiLaiApp.NIOVehicleWidget; build:2612; iOS 26.5.0) Alamofire/5.9.1", forHTTPHeaderField: "User-Agent")
            let token = normalizeBearer(s.nioVehicleAccessToken)
            if !token.isEmpty {
                req.setValue(token, forHTTPHeaderField: "Authorization")
            }

            let start = Date()
            let (data, response) = try await urlSession.data(for: req)
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            guard let http = response as? HTTPURLResponse else { throw NIOError.invalidJSON }

            if http.statusCode == 200 {
                report.steps.append(NIODiagnosticStep(name: "网络连通与 HTTP 状态", status: .success, detail: "HTTP 200 OK（耗时 \(elapsed)ms）"))

                // 步骤 5：JSON 解析与字段结构
                let raw = try JSONSerialization.jsonObject(with: data, options: [])
                if let dict = raw as? [String: Any] {
                    let normalized = RVSRormalizer.normalize(dict)
                    let normalizedData = try JSONSerialization.data(withJSONObject: normalized)
                    let decoded = try JSONDecoder().decode(NIOVehicleResponse.self, from: normalizedData)
                    if decoded.data?.status != nil {
                        let soc = decoded.data?.status?.socStatus?.soc ?? 0
                        let range = decoded.data?.status?.socStatus?.remainingRange ?? 0
                        report.steps.append(NIODiagnosticStep(name: "数据结构与解析", status: .success, detail: "成功解析车辆状态（当前电量 \(Int(soc))%，续航 \(Int(range))km）"))
                        report.summary = "✅ 诊断通过：API 接口连通正常，数据解析成功！"
                        self.is403Detected = false
                    } else {
                        report.steps.append(NIODiagnosticStep(name: "数据结构与解析", status: .warning, detail: "接口响应缺少 data.status 字段"))
                        report.summary = "⚠️ 接口已连接但数据字段不完整，请确认 URL 指向正确的车辆接口。"
                    }
                }
            } else if http.statusCode == 403 || http.statusCode == 401 {
                report.is403Detected = true
                self.is403Detected = true
                report.steps.append(NIODiagnosticStep(name: "网络连通与 HTTP 状态", status: .failure, detail: "HTTP \(http.statusCode) 鉴权失败：签名或 Token 已过期"))
                report.summary = "❌ 诊断失败：HTTP 403/401 签名或 Token 过期。"
                report.recommendation = "【解决方案】：\n1. 若使用 URL 模式，请重新从 Postman/抓包工具复制最新 GET URL（含最新 sign 与 timestamp）并填入。\n2. 推荐使用「Widget 动态签名模式」：填写 Vehicle ID、Device ID 与 Sign Secret，应用将实时动态计算签名，永久不再过期。"
            } else {
                report.steps.append(NIODiagnosticStep(name: "网络连通与 HTTP 状态", status: .failure, detail: "HTTP \(http.statusCode)"))
                report.summary = "❌ 诊断失败：服务器返回状态码 \(http.statusCode)"
            }
        } catch {
            report.steps.append(NIODiagnosticStep(name: "网络请求测试", status: .failure, detail: "请求失败: \(error.localizedDescription)"))
            report.summary = "❌ 诊断失败：网络请求发生异常，请检查网络连接。"
        }

        report.isRunning = false
        return report
    }

    // MARK: - 历史快照（内存缓存 + 异步后台落盘，彻底解决 UI 卡死）

    private func appendSnapshot(_ resp: NIOVehicleResponse) {
        do {
            let snap = try NIOVehicleLib.snapshotFromResponse(resp)
            guard snap.isValidGPS || snap.ts > 0 else { return }
            if history.contains(where: { $0.snapshotKey == snap.snapshotKey }) { return }
            history.append(snap)
            if history.count > 2000 { history = Array(history.suffix(2000)) }
            let snapshotList = self.history
            let targetFile = self.historyFile
            updateDerivedMetrics(from: snapshotList)
            // 异步后台写盘，不阻塞主线程 RunLoop
            Task.detached(priority: .utility) {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(snapshotList) {
                    try? data.write(to: targetFile, options: .atomic)
                }
            }
        } catch {
            // 快照提取失败不阻断主流程
        }
    }

    private func updateDerivedMetrics(from snapshots: [NIOVehicleSnapshot]) {
        let copy = snapshots
        Task.detached(priority: .userInitiated) {
            let paths = NIOVehicleLib.buildDailyPaths(history: copy)
            let deltas = NIOVehicleLib.computeDailyMileageDeltas(history: copy)
            await MainActor.run {
                NIOService.shared.dailyPaths = paths
                NIOService.shared.dailyMileageDeltas = deltas
            }
        }
    }

    /// 从内存秒级返回历史快照（不产生磁盘 I/O）
    func loadHistory() -> [NIOVehicleSnapshot] {
        return history
    }

    // MARK: - 状态栏标题构建

    func trayTitle() -> String? {
        let fields = settings.nioTrayDisplayFields
        guard !fields.isEmpty else { return nil }
        guard let status = vehicleData?.data?.status else { return nil }
        var parts: [String] = []
        for f in fields {
            switch f {
            case .soc:
                if let soc = status.socStatus?.soc {
                    parts.append(soc == soc.rounded() ? "\(Int(soc))%" : String(format: "%.1f%%", soc))
                }
            case .range:
                if let r = status.socStatus?.remainingRange {
                    parts.append("\(Int(r))km")
                }
            case .actualRange:
                if let best = NIOVehicleLib.bestRange(cltcKm: status.socStatus?.remainingRange, actualKm: status.socStatus?.remainingActualRange) {
                    parts.append("\(best.km)km")
                } else if let r = status.socStatus?.remainingActualRange {
                    parts.append("\(Int(r))km")
                }
            case .vehicleState:
                if let st = status.exteriorStatus?.vehicleState {
                    parts.append(NIOVehicleLib.vehicleStateLabel(st))
                }
            case .mileage:
                if let m = status.exteriorStatus?.mileage {
                    parts.append("\(Int(m))km")
                }
            case .orders:
                if let count = serviceSummary?.total {
                    parts.append("\(count)单")
                }
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func previewTrayTitle() -> String {
        let parts = settings.nioTrayDisplayFields.map { f -> String in
            switch f {
            case .soc: return "85%"
            case .range: return "420km"
            case .actualRange: return "315km"
            case .vehicleState: return "已驻车"
            case .mileage: return "15871km"
            case .orders: return "12单"
            }
        }
        return parts.isEmpty ? "蔚来" : parts.joined(separator: " · ")
    }

    // MARK: - 内部工具

    private func normalizeBearer(_ raw: String) -> String {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return "" }
        return token.hasPrefix("Bearer ") ? token : "Bearer \(token)"
    }

    private func saveJSONAsync<T: Encodable>(_ obj: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(obj) {
            Task.detached(priority: .utility) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private func appendLog(_ entry: NIOFetchLogEntry) {
        fetchLogs.append(entry)
        if fetchLogs.count > 500 { fetchLogs = Array(fetchLogs.suffix(500)) }
        saveLogsAsync()
    }

    private func updateLog(_ entry: NIOFetchLogEntry, statusCode: Int?, preview: String?) {
        if let idx = fetchLogs.lastIndex(where: { $0.id == entry.id }) {
            fetchLogs[idx].statusCode = statusCode
            fetchLogs[idx].responsePreview = preview
            saveLogsAsync()
        }
    }

    private func saveLogsAsync() {
        let logs = self.fetchLogs
        let file = self.fetchLogFile
        Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(logs) {
                try? data.write(to: file, options: .atomic)
            }
        }
    }

    // MARK: - 签到元数据

    struct CheckinMeta: Codable {
        var ok: Bool?
        var at: Int?
        var error: String?
        var runDay: String?
    }

    private func readCheckinMeta() -> CheckinMeta {
        guard FileManager.default.fileExists(atPath: checkinMetaFile.path),
              let data = try? Data(contentsOf: checkinMetaFile) else { return CheckinMeta() }
        return (try? JSONDecoder().decode(CheckinMeta.self, from: data)) ?? CheckinMeta()
    }

    private func saveCheckinMeta(ok: Bool?, error: String?) {
        let meta = CheckinMeta(
            ok: ok,
            at: Int(Date().timeIntervalSince1970 * 1000),
            error: error,
            runDay: NIOCheckinLib.localDayKey()
        )
        saveJSONAsync(meta, to: checkinMetaFile)
    }

    // MARK: - 从磁盘加载（仅在初始化时加载一次进内存）

    private func loadAllFromDisk() {
        func readDict(_ url: URL) -> [String: NIOJSONValue]? {
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode([String: NIOJSONValue].self, from: data)
        }

        cachedTyreStatus = readDict(cachedTyreFile)
        cachedLvBattStatus = readDict(cachedLvBattFile)
        cachedKeyStatus = readDict(cachedKeyFile)
        cachedHeatingStatus = readDict(cachedHeatingFile)
        cachedWindowStatus = readDict(cachedWindowFile)
        cachedFrdgStatus = readDict(cachedFrdgFile)
        cachedBoxStatus = readDict(cachedBoxFile)
        cachedLightStatus = readDict(cachedLightFile)

        if FileManager.default.fileExists(atPath: vehicleFile.path),
           let data = try? Data(contentsOf: vehicleFile) {
            vehicleData = try? JSONDecoder().decode(NIOVehicleResponse.self, from: data)
            if vehicleData?.data?.status?.tyreStatus == nil || !NIOVehicleLib.extractTyreInfo(vehicleData?.data?.status?.tyreStatus).hasData {
                if let cached = cachedTyreStatus { vehicleData?.data?.status?.tyreStatus = cached }
            }
            if vehicleData?.data?.status?.lvBattStatus == nil || vehicleData?.data?.status?.lvBattStatus?.isEmpty == true {
                if let cached = cachedLvBattStatus { vehicleData?.data?.status?.lvBattStatus = cached }
            }
            if vehicleData?.data?.status?.keyStatus == nil || vehicleData?.data?.status?.keyStatus?.isEmpty == true {
                if let cached = cachedKeyStatus { vehicleData?.data?.status?.keyStatus = cached }
            }
            if vehicleData?.data?.status?.heatingStatus == nil || vehicleData?.data?.status?.heatingStatus?.isEmpty == true {
                if let cached = cachedHeatingStatus { vehicleData?.data?.status?.heatingStatus = cached }
            }
            if vehicleData?.data?.status?.windowStatus == nil || vehicleData?.data?.status?.windowStatus?.isEmpty == true {
                if let cached = cachedWindowStatus { vehicleData?.data?.status?.windowStatus = cached }
            }
            if vehicleData?.data?.status?.frdgStatus == nil || vehicleData?.data?.status?.frdgStatus?.isEmpty == true {
                if let cached = cachedFrdgStatus { vehicleData?.data?.status?.frdgStatus = cached }
            }
            if vehicleData?.data?.status?.boxStatus == nil || vehicleData?.data?.status?.boxStatus?.isEmpty == true {
                if let cached = cachedBoxStatus { vehicleData?.data?.status?.boxStatus = cached }
            }
            if vehicleData?.data?.status?.lightStatus == nil || vehicleData?.data?.status?.lightStatus?.isEmpty == true {
                if let cached = cachedLightStatus { vehicleData?.data?.status?.lightStatus = cached }
            }
        }
        if FileManager.default.fileExists(atPath: changeFile.path),
           let data = try? Data(contentsOf: changeFile),
           let resp = try? JSONDecoder().decode(NIOChangeResponse.self, from: data) {
            serviceSummary = NIOOrderLib.analyzeServiceOrders(resp)
        }
        if FileManager.default.fileExists(atPath: checkinFile.path),
           let data = try? Data(contentsOf: checkinFile) {
            checkinData = try? JSONDecoder().decode(NIOCheckinData.self, from: data)
        }
        if FileManager.default.fileExists(atPath: historyFile.path),
           let data = try? Data(contentsOf: historyFile) {
            history = (try? JSONDecoder().decode([NIOVehicleSnapshot].self, from: data)) ?? []
            updateDerivedMetrics(from: history)
        }
        if FileManager.default.fileExists(atPath: fetchLogFile.path),
           let data = try? Data(contentsOf: fetchLogFile) {
            fetchLogs = (try? JSONDecoder().decode([NIOFetchLogEntry].self, from: data)) ?? []
        }
    }
}
