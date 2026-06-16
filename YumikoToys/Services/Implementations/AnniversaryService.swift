//
//  AnniversaryService.swift
//  YumikoToys
//
//  纪念日服务实现（性能优化版）
//
//  核心优化：
//  1. 拆分秒级 Publisher（countdownTextPublisher）和数据级 Publisher（activeAnniversaryInfoPublisher）
//  2. 秒级更新只推送轻量字符串，不触发完整 AnniversaryInfo 重算
//  3. 异步存储队列，避免主线程 I/O 阻塞
//  4. 批量删除方法
//

import Foundation
import Combine
import WidgetKit

@MainActor
final class AnniversaryService: AnniversaryServiceProtocol {
    
    // MARK: - Properties
    
    private(set) var anniversaries: [Anniversary] = []
    private(set) var activeAnniversary: Anniversary?
    private(set) var activeAnniversaryInfo: AnniversaryInfo?
    
    // 低频：纪念日列表变化
    private var anniversariesSubject = CurrentValueSubject<[Anniversary], Never>([])
    // 低频：完整信息（仅在纪念日数据变化时推送）
    private var activeAnniversaryInfoSubject = CurrentValueSubject<AnniversaryInfo?, Never>(nil)
    // 高频：秒级倒计时文本（每秒推送轻量字符串）
    private var countdownTextSubject = PassthroughSubject<String, Never>()
    // 中频：状态栏短文本
    private var statusBarTextSubject = PassthroughSubject<String, Never>()
    private var statusBarLine1Subject = CurrentValueSubject<String, Never>("")
    
    var anniversariesPublisher: AnyPublisher<[Anniversary], Never> {
        anniversariesSubject.eraseToAnyPublisher()
    }
    
    var activeAnniversaryInfoPublisher: AnyPublisher<AnniversaryInfo?, Never> {
        activeAnniversaryInfoSubject.eraseToAnyPublisher()
    }
    
    var countdownTextPublisher: AnyPublisher<String, Never> {
        countdownTextSubject.eraseToAnyPublisher()
    }
    
    var statusBarTextPublisher: AnyPublisher<String, Never> {
        statusBarTextSubject.eraseToAnyPublisher()
    }
    
    var statusBarLine1Publisher: AnyPublisher<String, Never> {
        statusBarLine1Subject.eraseToAnyPublisher()
    }
    
    private var updateTimer: Timer?
    private var lastMinute = -1  // 追踪分钟变化，用于状态栏更新
    private var lastSyncedDayCount = -1
    private var lastSyncedAnniversaryId: UUID? = nil
    
    private let storageKey = "yumikotoys.anniversaries"
    private let activeIdKey = "yumikotoys.activeAnniversaryId"
    
    private let storageService: StorageServiceProtocol
    private let timeSyncService: TimeSyncService
    
    var serviceName: String { "AnniversaryService" }
    
    // MARK: - Initialization
    
    init(storageService: StorageServiceProtocol, timeSyncService: TimeSyncService) {
        self.storageService = storageService
        self.timeSyncService = timeSyncService
    }
    
    // MARK: - ServiceLifecycle
    
    func initialize() async {
        loadAnniversaries()
        startSecondUpdates()
        LoggerService.shared.info("AnniversaryService initialized with \(anniversaries.count) anniversaries")
    }
    
    func start() async {}
    
    func stop() {
        stopSecondUpdates()
        saveAnniversariesSync()
        LoggerService.shared.info("AnniversaryService stopped")
    }
    
    // MARK: - CRUD 操作
    
    func addAnniversary(_ anniversary: Anniversary) {
        anniversaries.append(anniversary)
        
        if anniversaries.count == 1 {
            setActiveAnniversary(id: anniversary.id)
        }
        
        saveAnniversariesAsync()
        anniversariesSubject.send(anniversaries)
        LoggerService.shared.info("Added anniversary: \(anniversary.title)")
    }
    
    func updateAnniversary(_ anniversary: Anniversary) {
        guard let index = anniversaries.firstIndex(where: { $0.id == anniversary.id }) else {
            LoggerService.shared.warning("Anniversary not found for update: \(anniversary.id)")
            return
        }
        
        var updated = anniversary
        updated.updatedAt = Date()
        anniversaries[index] = updated
        
        if activeAnniversary?.id == anniversary.id {
            activeAnniversary = updated
            refreshFullInfo()
        }
        
        saveAnniversariesAsync()
        anniversariesSubject.send(anniversaries)
        LoggerService.shared.info("Updated anniversary: \(anniversary.title)")
    }
    
    func deleteAnniversary(id: UUID) {
        let title = anniversaries.first(where: { $0.id == id })?.title ?? "Unknown"
        anniversaries.removeAll { $0.id == id }
        
        if activeAnniversary?.id == id {
            activeAnniversary = anniversaries.first
            refreshFullInfo()
        }
        
        saveAnniversariesAsync()
        anniversariesSubject.send(anniversaries)
        LoggerService.shared.info("Deleted anniversary: \(title)")
    }
    
    /// 批量删除所有纪念日（单次 Publisher 事件）
    func deleteAllAnniversaries() {
        anniversaries.removeAll()
        activeAnniversary = nil
        activeAnniversaryInfo = nil
        
        saveAnniversariesAsync()
        anniversariesSubject.send([])
        activeAnniversaryInfoSubject.send(nil)
        LoggerService.shared.info("Deleted all anniversaries")
    }
    
    func setActiveAnniversary(id: UUID) {
        guard let anniversary = anniversaries.first(where: { $0.id == id }) else {
            LoggerService.shared.warning("Anniversary not found for activation: \(id)")
            return
        }
        
        activeAnniversary = anniversary
        refreshFullInfo()
        
        storageService.save(id.uuidString, forKey: activeIdKey)
        LoggerService.shared.info("Set active anniversary: \(anniversary.title)")
    }
    
    func calculateAnniversaryInfo(for anniversary: Anniversary) -> AnniversaryInfo {
        let ntpTime = timeSyncService.currentTime()
        return AnniversaryInfo.calculate(from: anniversary, referenceDate: ntpTime)
    }
    
    // MARK: - 信息更新（分离秒级和数据级）
    
    /// 完整刷新（含里程碑），仅在纪念日数据变化时调用（使用 NTP 修正后的时间）
    private func refreshFullInfo() {
        guard let anniversary = activeAnniversary else {
            activeAnniversaryInfo = nil
            activeAnniversaryInfoSubject.send(nil)
            statusBarLine1Subject.send("")
            return
        }
        let ntpTime = timeSyncService.currentTime()
        activeAnniversaryInfo = AnniversaryInfo.calculate(from: anniversary, referenceDate: ntpTime)
        activeAnniversaryInfoSubject.send(activeAnniversaryInfo)
        updateStatusBarLine1()
        syncWidgetData(forceReload: true)
    }
    
    /// 更新状态栏第一行文字
    private func updateStatusBarLine1() {
        guard let anniversary = activeAnniversary else {
            statusBarLine1Subject.send("")
            return
        }
        statusBarLine1Subject.send(anniversary.statusBarLine1)
    }
    
    // MARK: - 秒级更新（仅推送轻量文本）
    
    private func startSecondUpdates() {
        // 确保 Timer 在主线程的 RunLoop 中运行，并支持所有模式
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        // 添加到 Common 模式，确保在滚动等操作时也能触发
        RunLoop.main.add(updateTimer!, forMode: .common)
        
        // 立即触发一次
        tick()
        
        LoggerService.shared.debug("AnniversaryService timer started")
    }
    
    private func stopSecondUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
        LoggerService.shared.debug("AnniversaryService timer stopped")
    }
    
    /// 智能同步 Widget 并刷新
    private func syncWidgetData(forceReload: Bool = false) {
        guard let anniversary = activeAnniversary else { return }
        let ntpTime = timeSyncService.currentTime()
        let calc = AnniversaryInfo.calculateTime(from: anniversary.startDate, referenceDate: ntpTime)
        let dayCount = Int(calc.totalDays)
        
        // 始终在每次 tick 时更新写入 JSON 文件，以便 Widget 随时读取到最新的浮点天数和数据
        let milestones = AnniversaryInfo.calculateMilestones(from: anniversary.startDate, referenceDate: ntpTime)
        writeWidgetSyncData(anniversary: anniversary, calc: calc, milestones: milestones)
        
        // 仅在天数发生整数变化或切换纪念日时，才通知 OS 刷新 Timeline（防止 API 调用频次超限）
        if forceReload || dayCount != lastSyncedDayCount || anniversary.id != lastSyncedAnniversaryId {
            lastSyncedDayCount = dayCount
            lastSyncedAnniversaryId = anniversary.id
            WidgetCenter.shared.reloadAllTimelines()
            LoggerService.shared.info("Widget timeline reloaded for: \(anniversary.title)")
        }
    }
    
    /// 每秒触发：计算并推送最新数据
    private func tick() {
        guard let anniversary = activeAnniversary else { 
            LoggerService.shared.debug("tick: no active anniversary")
            return 
        }
        
        let ntpTime = timeSyncService.currentTime()
        let calc = AnniversaryInfo.calculateTime(from: anniversary.startDate, referenceDate: ntpTime)
        
        // 【修复】每秒重新计算里程碑，确保已到期时立即切换到下一个
        let milestones = AnniversaryInfo.calculateMilestones(from: anniversary.startDate, referenceDate: ntpTime)
        
        // 更新 activeAnniversaryInfo（包含最新的 totalDays 和 milestones）
        activeAnniversaryInfo = AnniversaryInfo(
            anniversary: anniversary,
            calculation: calc,
            milestones: milestones
        )
        
        // 推送秒级倒计时文本
        countdownTextSubject.send(calc.formattedString)
        
        // 推送更新后的 info
        activeAnniversaryInfoSubject.send(activeAnniversaryInfo)
        
        // 状态栏：仅在分钟变化时更新（减少不必要的 UI 刷新）
        let currentMinute = calc.minutes
        if currentMinute != lastMinute {
            lastMinute = currentMinute
            statusBarTextSubject.send(calc.shortString)
        }
        
        // 智能更新 Widget
        syncWidgetData(forceReload: false)
    }
    
    private func writeWidgetSyncData(anniversary: Anniversary, calc: AnniversaryCalculation, milestones: [AnniversaryMilestone]) {
        let bubbleText = UserDefaults.standard.string(forKey: "YumikoToys_ProactiveBubbleText")
        let name = DependencyContainer.shared.componentLayoutService.currentLayouts.first(where: { $0.type == .daysDisplay })?.customTitle ?? anniversary.displayPetName

        let timeParts = WidgetSyncData.deriveTimeParts(from: calc.totalDays)
        let themeHex = DependencyContainer.shared.settingsService.settings.customThemeColorHex

        let syncData = WidgetSyncData(
            petName: name,
            avatar: anniversary.displayAvatar,
            startDate: anniversary.startDate,
            totalDays: calc.totalDays,
            milestones: milestones.map {
                WidgetMilestone(
                    id: $0.id,
                    icon: $0.icon,
                    label: $0.label,
                    date: $0.formattedDate,
                    countDisplay: $0.countDisplay
                )
            },
            proactiveBubbleText: bubbleText,
            appVersion: AppConfig.version,
            displayStyle: DependencyContainer.shared.settingsService.settings.widgetDisplayStyle.rawValue,
            totalHours: timeParts.totalHours,
            hoursPart: timeParts.hoursPart,
            minutesPart: timeParts.minutesPart,
            secondsPart: timeParts.secondsPart,
            themePrimaryHex: themeHex
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(syncData) else { return }

        let groupID = "group.com.Lite.YumikoToys"
        var anySuccess = false

        // ── 机制 1：UserDefaults(suiteName:)（最可靠，自签名环境下依然可用） ──
        // 这是当前自签名环境下 Widget 能读到数据的首选机制。
        if let sharedDefaults = UserDefaults(suiteName: groupID) {
            sharedDefaults.set(data, forKey: "widget_payload")
            sharedDefaults.synchronize()
            anySuccess = true
            LoggerService.shared.debug("Widget data written to UserDefaults suite: \(groupID)")
        } else {
            LoggerService.shared.warning("UserDefaults(suiteName:) returned nil for \(groupID) — entitlement may be missing or signature invalid")
        }

        // ── 机制 2：App Group / App Support / Home 目录文件（额外冗余） ──
        let fileManager = FileManager.default
        var writePaths: [URL] = []

        if let sharedContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            writePaths.append(sharedContainer.appendingPathComponent("widget.json"))
        } else {
            LoggerService.shared.warning("App Group container unavailable for \(groupID) — signature/entitlements issue")
        }

        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let folderURL = appSupportURL.appendingPathComponent("com.Lite.YumikoToys")
            writePaths.append(folderURL.appendingPathComponent("widget.json"))
        }

        let homeAppSupport = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.Lite.YumikoToys")
        writePaths.append(homeAppSupport.appendingPathComponent("widget.json"))

        for fileURL in writePaths {
            let folderURL = fileURL.deletingLastPathComponent()
            do {
                if !fileManager.fileExists(atPath: folderURL.path) {
                    try fileManager.createDirectory(at: folderURL,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
                }
                try data.write(to: fileURL, options: .atomic)
                if !anySuccess {
                    anySuccess = true
                    LoggerService.shared.debug("Widget data written to: \(fileURL.path)")
                }
            } catch {
                LoggerService.shared.debug("Widget data write failed for \(fileURL.path): \(error.localizedDescription)")
            }
        }

        if !anySuccess {
            LoggerService.shared.warning("Unable to write widget data to any of the candidate paths")
        }
    }
    
    // MARK: - 异步持久化
    
    private func saveAnniversariesAsync() {
        let anniversariesCopy = anniversaries
        let key = storageKey
        let storage = storageService
        Task.detached(priority: .utility) {
            storage.save(anniversariesCopy, forKey: key)
        }
    }
    
    private func saveAnniversariesSync() {
        storageService.save(anniversaries, forKey: storageKey)
    }
    
    // MARK: - 加载
    
    private func loadAnniversaries() {
        if let loaded: [Anniversary] = storageService.load(forKey: storageKey) {
            anniversaries = loaded
        } else {
            createDefaultAnniversary()
        }
        
        if let activeIdString: String = storageService.load(forKey: activeIdKey),
           let activeId = UUID(uuidString: activeIdString),
           let active = anniversaries.first(where: { $0.id == activeId }) {
            activeAnniversary = active
        } else {
            activeAnniversary = anniversaries.first
        }
        
        anniversariesSubject.send(anniversaries)
        refreshFullInfo()
    }
    
    private func createDefaultAnniversary() {
        let defaultAnniversary = Anniversary(
            title: "兔可可到来",
            startDate: Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 12))!,
            type: .countUp,
            emoji: "🐰",
            color: "FF6B6B",
            petName: "兔可可",
            petGender: .female,
            species: "荷兰垂耳兔",
            avatarEmoji: "🐰"
        )
        anniversaries = [defaultAnniversary]
        activeAnniversary = defaultAnniversary
        saveAnniversariesSync()
        LoggerService.shared.info("Created default anniversary")
    }
}
