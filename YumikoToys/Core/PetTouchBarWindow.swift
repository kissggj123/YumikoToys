//
//  PetTouchBarWindow.swift
//  YumikoToys
//
//  参考 TouchBarPets 项目：
//  使用 SpriteKit (SKScene + SKSpriteNode) 渲染帧动画，
//  通过一个极小的始终置顶浮窗保持前台状态，让 NSTouchBar 常驻。
//

import AppKit
import SpriteKit
import Darwin

// MARK: - MTMR-style private API bridge

private enum PetSystemTouchBarBridge {
    private static let addSystemTrayItemSelector = NSSelectorFromString(
        "addSystemTrayItem:"
    )
    private static let removeSystemTrayItemSelector = NSSelectorFromString(
        "removeSystemTrayItem:"
    )
    private static let presentSelector = NSSelectorFromString(
        "presentSystemModalTouchBar:systemTrayItemIdentifier:"
    )
    private static let presentWithoutControlStripSelector = NSSelectorFromString(
        "presentSystemModalTouchBar:placement:systemTrayItemIdentifier:"
    )
    private static let dismissSelector = NSSelectorFromString(
        "dismissSystemModalTouchBar:"
    )
    private static let minimizeSelector = NSSelectorFromString(
        "minimizeSystemModalTouchBar:"
    )
    private static let dfrFoundationPath =
        "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation"

    static func registerSystemTrayItem(_ item: NSTouchBarItem) -> Bool {
        guard NSTouchBarItem.responds(to: addSystemTrayItemSelector) else { return false }
        NSTouchBarItem.addSystemTrayItem(item)
        return true
    }

    static func unregisterSystemTrayItem(_ item: NSTouchBarItem) {
        guard NSTouchBarItem.responds(to: removeSystemTrayItemSelector) else { return }
        NSTouchBarItem.removeSystemTrayItem(item)
    }

    static func setSystemModalCloseBoxVisible(_ visible: Bool) -> Bool {
        guard let handle = dlopen(dfrFoundationPath, RTLD_LAZY),
              let symbol = dlsym(handle, "DFRSystemModalShowsCloseBoxWhenFrontMost") else {
            return false
        }

        typealias SetCloseBoxVisibility = @convention(c) (Bool) -> Void
        unsafeBitCast(symbol, to: SetCloseBoxVisibility.self)(visible)
        return true
    }

    static func present(
        _ touchBar: NSTouchBar,
        systemTrayItemIdentifier identifier: NSTouchBarItem.Identifier
    ) -> Bool {
        if NSTouchBar.responds(to: presentWithoutControlStripSelector) {
            NSTouchBar.presentSystemModalTouchBar(
                touchBar,
                placement: 1,
                systemTrayItemIdentifier: identifier
            )
            return true
        }

        guard NSTouchBar.responds(to: presentSelector) else { return false }
        NSTouchBar.presentSystemModalTouchBar(
            touchBar,
            systemTrayItemIdentifier: identifier
        )
        return true
    }

    static func dismiss(_ touchBar: NSTouchBar) {
        if NSTouchBar.responds(to: dismissSelector) {
            NSTouchBar.dismissSystemModalTouchBar(touchBar)
        } else if NSTouchBar.responds(to: minimizeSelector) {
            NSTouchBar.minimizeSystemModalTouchBar(touchBar)
        }
    }
}

// MARK: - Manager

private final class PetTouchBarAnchorWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PetTouchBarWindowManager {
    static let shared = PetTouchBarWindowManager()
    private static let systemTrayItemIdentifier = NSTouchBarItem.Identifier(
        "com.Lite.YumikoToys.touchbar.system"
    )

    private var anchorWindow: NSWindow?
    private var touchBarVC: PetTouchBarViewController?
    private var systemTouchBar: NSTouchBar?
    private var systemTrayItem: NSTouchBarItem?
    private var notificationTokens: [NSObjectProtocol] = []

    private init() {}

    func updateTouchBarState(isEnabled: Bool) {
        if isEnabled {
            install()
        } else {
            uninstall()
        }
    }

    func attach(to window: NSWindow) {
        guard systemTouchBar == nil,
              let touchBarVC,
              window !== anchorWindow else { return }
        window.touchBar = touchBarVC.makeTouchBar()
    }

    func install() {
        if systemTouchBar != nil {
            return
        }
        if let anchorWindow, anchorWindow.isVisible {
            return
        }
        anchorWindow = nil

        let vc = PetTouchBarViewController()
        touchBarVC = vc
        PetHealthModel.shared.start()

        let trayItem = NSCustomTouchBarItem(identifier: Self.systemTrayItemIdentifier)
        trayItem.customizationLabel = "兔可可 Touch Bar"
        trayItem.view = NSImageView(
            image: NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "兔可可")
                ?? NSImage()
        )
        let trayItemRegistered = PetSystemTouchBarBridge.registerSystemTrayItem(trayItem)

        if trayItemRegistered,
           let systemTouchBar = vc.makeTouchBar(),
           PetSystemTouchBarBridge.setSystemModalCloseBoxVisible(false),
           PetSystemTouchBarBridge.present(
               systemTouchBar,
               systemTrayItemIdentifier: Self.systemTrayItemIdentifier
           ) {
            self.systemTouchBar = systemTouchBar
            self.systemTrayItem = trayItem
            LoggerService.shared.info("PetTouchBarWindowManager: system modal Touch Bar installed")
            return
        }

        if trayItemRegistered {
            PetSystemTouchBarBridge.unregisterSystemTrayItem(trayItem)
        }

        let window = PetTouchBarAnchorWindow(
            contentRect: NSRect(x: 0, y: 0, width: 16, height: 16),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = vc
        window.touchBar = vc.makeTouchBar()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.alphaValue = 0.01

        if let screen = NSScreen.main {
            window.setFrameOrigin(NSPoint(
                x: screen.frame.maxX - 20,
                y: screen.frame.minY + 4
            ))
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(vc.view)
        anchorWindow = window

        for appWindow in NSApp.windows where appWindow !== window {
            attach(to: appWindow)
        }

        let activationToken = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let window = self.anchorWindow, window.isVisible else { return }
                window.orderFrontRegardless()
                if NSApp.keyWindow !== window {
                    window.makeKey()
                }
            }
        }
        notificationTokens.append(activationToken)

        LoggerService.shared.info("PetTouchBarWindowManager: anchor window installed")
    }

    func uninstall() {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
        PetHealthModel.shared.stop()

        if let systemTouchBar {
            PetSystemTouchBarBridge.dismiss(systemTouchBar)
            _ = PetSystemTouchBarBridge.setSystemModalCloseBoxVisible(true)
            if let systemTrayItem {
                PetSystemTouchBarBridge.unregisterSystemTrayItem(systemTrayItem)
            }
            self.systemTrayItem = nil
            self.systemTouchBar = nil
            touchBarVC = nil
            LoggerService.shared.info("PetTouchBarWindowManager: system modal Touch Bar removed")
            return
        }

        anchorWindow?.orderOut(nil)
        anchorWindow?.touchBar = nil
        anchorWindow?.close()
        anchorWindow = nil
        touchBarVC = nil
        LoggerService.shared.info("PetTouchBarWindowManager: anchor window removed")
    }
}

// MARK: - Manager

private extension Notification.Name {
    static let petDidLevelUp = Notification.Name("YumikoToys.petDidLevelUp")
}

@MainActor
final class PetHealthModel {
    static let shared = PetHealthModel()
    static let magicCost: Double = 25

    private(set) var health: Double = 100
    private(set) var mana: Double = 100
    private(set) var experience: Double = 0
    private(set) var level = 1

    var experienceNeeded: Double {
        100 + Double(level - 1) * 25
    }

    private var timer: Timer?
    private var lastUpdate = Date()
    private var isHealthRecovering = false
    private var isManaRecovering = false
    private var observers: [UUID: (Double, Double, Double, Int, Double) -> Void] = [:]

    private init() {}

    func start() {
        guard timer == nil else { return }
        lastUpdate = Date()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @discardableResult
    func observe(_ handler: @escaping (Double, Double, Double, Int, Double) -> Void) -> UUID {
        let id = UUID()
        observers[id] = handler
        notify(handler)
        return id
    }

    func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    @discardableResult
    func useMagic() -> Bool {
        guard mana >= Self.magicCost else { return false }
        mana -= Self.magicCost
        isManaRecovering = false
        for observer in observers.values {
            notify(observer)
        }
        return true
    }

    private func tick() {
        let now = Date()
        let delta = min(max(now.timeIntervalSince(lastUpdate), 0), 1)
        lastUpdate = now

        if isHealthRecovering {
            health = min(100, health + delta * 0.18)
            if health >= 100 {
                health = 100
                isHealthRecovering = false
            }
        } else {
            health = max(20, health - delta * 0.08)
            if health <= 20 {
                isHealthRecovering = true
            }
        }

        if isManaRecovering {
            mana = min(100, mana + delta * 0.16)
            if mana >= 100 {
                mana = 100
                isManaRecovering = false
            }
        } else {
            mana = max(20, mana - delta * 0.06)
            if mana <= 20 {
                isManaRecovering = true
            }
        }

        experience += delta * 0.35
        var didLevelUp = false
        while experience >= experienceNeeded {
            experience -= experienceNeeded
            level += 1
            didLevelUp = true
        }
        if didLevelUp {
            health = 100
            isHealthRecovering = false
        }

        for observer in observers.values {
            notify(observer)
        }
        if didLevelUp {
            NotificationCenter.default.post(name: .petDidLevelUp, object: nil)
        }
    }

    private func notify(_ observer: (Double, Double, Double, Int, Double) -> Void) {
        observer(health, mana, experience, level, experienceNeeded)
    }
}

@MainActor
private final class PetStatusView: NSView {
    private let model: PetHealthModel
    private var observerID: UUID?
    private var magicButton: PetMagicButton?
    private var displayedHealth: Double = 100
    private var displayedMana: Double = 100
    private var displayedExperience: Double = 0
    private var displayedLevel = 1
    private var displayedExperienceNeeded: Double = 100

    override var intrinsicContentSize: NSSize {
        NSSize(width: 170, height: 30)
    }

    init(model: PetHealthModel, magicTarget: AnyObject, magicAction: Selector) {
        self.model = model
        super.init(frame: NSRect(x: 0, y: 0, width: 170, height: 30))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let magicButton = PetMagicButton()
        magicButton.target = magicTarget
        magicButton.action = magicAction
        magicButton.frame = NSRect(x: 144, y: 0, width: 24, height: 30)
        self.magicButton = magicButton
        addSubview(magicButton)

        observerID = model.observe { [weak self] health, mana, experience, level, experienceNeeded in
            self?.displayedHealth = health
            self?.displayedMana = mana
            self?.displayedExperience = experience
            self?.displayedLevel = level
            self?.displayedExperienceNeeded = experienceNeeded
            self?.magicButton?.isEnabled = mana >= PetHealthModel.magicCost
            self?.needsDisplay = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observerID {
            let model = model
            MainActor.assumeIsolated {
                model.removeObserver(observerID)
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let hpText = "\(Int(displayedHealth))"
        drawBar(x: 3, value: displayedHealth / 100, color: healthColor, text: hpText)

        let mpText = "\(Int(displayedMana))"
        drawBar(x: 43, value: displayedMana / 100, color: .systemBlue, text: mpText)

        let expPercent = Int((displayedExperience / displayedExperienceNeeded) * 100)
        let expText = "\(expPercent)%"
        drawBar(x: 83, value: displayedExperience / displayedExperienceNeeded, color: .systemPurple, text: expText)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let levelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        let levelText = "L\(displayedLevel)" as NSString
        levelText.draw(
            in: NSRect(x: 121, y: 6, width: 23, height: 16),
            withAttributes: levelAttributes
        )

        let swordAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: (magicButton?.isEnabled ?? false)
                ? NSColor.white
                : NSColor(calibratedWhite: 1, alpha: 0.28)
        ]
        ("🗡️" as NSString).draw(
            in: NSRect(x: 146, y: 5, width: 20, height: 20),
            withAttributes: swordAttributes
        )
    }

    private var healthColor: NSColor {
        if displayedHealth > 60 { return .systemGreen }
        if displayedHealth > 30 { return .systemOrange }
        return .systemRed
    }

    private func drawBar(x: CGFloat, value: Double, color: NSColor, text: String) {
        let barRect = NSRect(x: x, y: 6, width: 36, height: 16)

        NSColor(calibratedWhite: 1, alpha: 0.16).setFill()
        NSBezierPath(roundedRect: barRect, xRadius: 4, yRadius: 4).fill()

        let fraction = max(0, min(1, value))
        guard fraction > 0 else { return }
        color.setFill()
        let fillWidth = max(6, barRect.width * fraction)
        NSBezierPath(
            roundedRect: NSRect(
                x: barRect.minX,
                y: barRect.minY,
                width: fillWidth,
                height: barRect.height
            ),
            xRadius: 4,
            yRadius: 4
        ).fill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.65)
        shadow.shadowOffset = NSSize(width: 0, height: -0.5)
        shadow.shadowBlurRadius = 1.0

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .heavy),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle,
            .shadow: shadow
        ]

        let textRect = NSRect(x: barRect.minX, y: barRect.minY + 2, width: barRect.width, height: 12)
        (text as NSString).draw(in: textRect, withAttributes: textAttributes)
    }
}

final class PetTouchBarViewController: NSViewController {

    private static let tbID = NSTouchBar.CustomizationIdentifier(
        "com.Lite.YumikoToys.petWalk"
    )
    private static let petStripItemID = NSTouchBarItem.Identifier(
        "com.Lite.YumikoToys.petWalk.strip"
    )
    private static let petHealthItemID = NSTouchBarItem.Identifier(
        "com.Lite.YumikoToys.petWalk.health"
    )

    private weak var petScene: PetWalkScene?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func makeTouchBar() -> NSTouchBar? {
        let tb = NSTouchBar()
        tb.customizationIdentifier = Self.tbID
        tb.delegate = self
        tb.defaultItemIdentifiers = [Self.petStripItemID, .flexibleSpace, Self.petHealthItemID]
        return tb
    }
}

extension PetTouchBarViewController: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar,
                  makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        if identifier == Self.petHealthItemID {
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.customizationLabel = "桌宠状态：生命 / 魔法 / 经验 / 魔法攻击"
            item.view = PetStatusView(
                model: PetHealthModel.shared,
                magicTarget: self,
                magicAction: #selector(useMagic)
            )
            return item
        }

        guard identifier == Self.petStripItemID else { return nil }

        let item = NSCustomTouchBarItem(identifier: identifier)
        item.customizationLabel = "🐾 桌宠爬爬乐"

        let skView = SKView(frame: NSRect(x: 0, y: 0, width: 800, height: 30))
        skView.allowsTransparency = true
        skView.wantsLayer = true
        skView.layer?.backgroundColor = NSColor.clear.cgColor

        let scene = PetWalkScene(size: CGSize(width: 800, height: 30))
        scene.backgroundColor = .clear
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
        petScene = scene

        item.view = skView
        return item
    }

    @objc private func useMagic() {
        guard let petScene, petScene.removeRandomPet() else { return }
        _ = PetHealthModel.shared.useMagic()
    }
}

@MainActor
private final class PetMagicButton: NSButton {
    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 24, height: 30))
        title = ""
        isBordered = false
        setButtonType(.momentaryPushIn)
        alignment = .center
        focusRingType = .none
        toolTip = "消耗 25 点魔法值，随机消灭一个宠物"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 24, height: 30)
    }
}

// MARK: - SpriteKit 4人桌宠平滑巡逻与精准动画场景

final class PetWalkScene: SKScene {

    private struct PetConfig {
        let name: String
        let fps: Double
        let startXFraction: CGFloat
        let speed: CGFloat
        let startsFacingRight: Bool
    }

    // 精准调校 6 帧动画的步频与位移比例
    private let configs: [PetConfig] = [
        PetConfig(name: "blue",  fps: 6.8, startXFraction: 0.08, speed: 30, startsFacingRight: true),
        PetConfig(name: "gray",  fps: 7.2, startXFraction: 0.34, speed: 38, startsFacingRight: false),
        PetConfig(name: "white", fps: 7.0, startXFraction: 0.62, speed: 34, startsFacingRight: true),
        PetConfig(name: "tall",  fps: 7.5, startXFraction: 0.86, speed: 42, startsFacingRight: false),
    ]
    private var defeatedPetNames: Set<String> = []
    private var sceneTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval?
    private var levelUpObserver: NSObjectProtocol?

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        lastUpdateTime = nil
        defeatedPetNames.removeAll()
        removeAllChildren()

        for cfg in configs {
            spawnPet(config: cfg, isRespawn: false)
        }

        levelUpObserver = NotificationCenter.default.addObserver(
            forName: .petDidLevelUp,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.respawnAllDefeatedPets()
        }
    }

    deinit {
        if let levelUpObserver {
            NotificationCenter.default.removeObserver(levelUpObserver)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        sceneTime = currentTime
        let dt: CGFloat
        if let lastUpdateTime {
            let rawDt = currentTime - lastUpdateTime
            dt = CGFloat(min(max(rawDt, 0.001), 0.033))
        } else {
            dt = 1.0 / 60.0
        }
        self.lastUpdateTime = currentTime

        let minX: CGFloat = 18
        let maxX: CGFloat = max(minX + 50, self.size.width - 18)

        enumerateChildNodes(withName: "//*") { node, _ in
            guard let speed = node.userData?["speed"] as? CGFloat,
                  var facingRight = node.userData?["facingRight"] as? Bool else { return }

            let direction: CGFloat = facingRight ? 1.0 : -1.0
            var nextX = node.position.x + speed * direction * dt

            if nextX >= maxX {
                nextX = maxX
                facingRight = false
                node.xScale = 1.0
            } else if nextX <= minX {
                nextX = minX
                facingRight = true
                node.xScale = -1.0
            }

            node.userData?["facingRight"] = facingRight
            node.position.x = nextX
        }
    }

    @discardableResult
    func removeRandomPet() -> Bool {
        let pets = children.filter { node in
            guard node.userData?["speed"] != nil else { return false }
            let magicImmuneUntil = node.userData?["magicImmuneUntil"] as? TimeInterval ?? 0
            let invincibleUntil = node.userData?["invincibleUntil"] as? TimeInterval ?? 0
            return magicImmuneUntil <= sceneTime && invincibleUntil <= sceneTime
        }
        guard let pet = pets.randomElement() else { return false }
        guard let petName = pet.name else { return false }

        defeatedPetNames.insert(petName)
        pet.userData?["speed"] = CGFloat(0)

        let hitFx = SKLabelNode(text: "💥")
        hitFx.fontSize = 15
        hitFx.position = CGPoint(x: pet.position.x, y: pet.position.y + 14)
        hitFx.zPosition = 100
        addChild(hitFx)

        let fxAction = SKAction.sequence([
            .group([
                .moveBy(x: 0, y: 12, duration: 0.35),
                .scale(to: 1.3, duration: 0.15),
                .fadeOut(withDuration: 0.35)
            ]),
            .removeFromParent()
        ])
        hitFx.run(fxAction)

        let redFlash = SKAction.sequence([
            .colorize(with: .red, colorBlendFactor: 1.0, duration: 0.06),
            .colorize(withColorBlendFactor: 0, duration: 0.06)
        ])
        let shake = SKAction.sequence([
            .moveBy(x: -4, y: 0, duration: 0.03),
            .moveBy(x: 8, y: 0, duration: 0.03),
            .moveBy(x: -4, y: 0, duration: 0.03)
        ])
        let dieAnim = SKAction.sequence([
            .group([redFlash, shake]),
            .group([
                .scale(to: 1.35, duration: 0.12),
                .fadeOut(withDuration: 0.2),
                .rotate(byAngle: .pi / 2, duration: 0.2)
            ]),
            .removeFromParent()
        ])
        pet.run(dieAnim)

        let respawnAction = SKAction.sequence([
            .wait(forDuration: 3.5),
            .run { [weak self] in
                self?.respawnSinglePet(name: petName)
            }
        ])
        run(respawnAction)

        return true
    }

    private func spawnPet(config: PetConfig, isRespawn: Bool) {
        let textures = loadTextures(name: config.name)
        guard !textures.isEmpty else { return }

        let minX: CGFloat = 18
        let maxX: CGFloat = max(minX + 50, self.size.width - 18)
        let width = maxX - minX

        let x: CGFloat
        if isRespawn {
            x = CGFloat.random(in: minX...maxX)
        } else {
            x = minX + width * config.startXFraction
        }

        let sprite = SKSpriteNode(texture: textures[0])
        sprite.size = CGSize(width: 28, height: 28)
        sprite.position = CGPoint(x: x, y: size.height / 2)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sprite.name = config.name

        let facingRight = isRespawn ? Bool.random() : config.startsFacingRight
        sprite.xScale = facingRight ? -1.0 : 1.0

        let nodeData = NSMutableDictionary()
        nodeData["speed"] = config.speed
        nodeData["facingRight"] = facingRight
        sprite.userData = nodeData

        let rand = Double.random(in: 0..<1)
        if rand < 0.28 {
            sprite.userData?["invincibleUntil"] = sceneTime + 3.0
            sprite.color = .systemYellow
            sprite.colorBlendFactor = 0.55

            let goldPulse = SKAction.sequence([
                .colorize(withColorBlendFactor: 0.2, duration: 0.25),
                .colorize(withColorBlendFactor: 0.55, duration: 0.25)
            ])
            let goldEffect = SKAction.sequence([
                .repeat(goldPulse, count: 5),
                .colorize(withColorBlendFactor: 0.0, duration: 0.5)
            ])
            sprite.run(goldEffect, withKey: "buffEffect")
        } else if rand < 0.56 {
            sprite.userData?["magicImmuneUntil"] = sceneTime + 3.0
            sprite.color = .systemPurple
            sprite.colorBlendFactor = 0.5

            let purpleEffect = SKAction.sequence([
                .wait(forDuration: 2.5),
                .colorize(withColorBlendFactor: 0.0, duration: 0.5)
            ])
            sprite.run(purpleEffect, withKey: "buffEffect")
        }

        addChild(sprite)

        let walkAnim = SKAction.animate(
            with: textures,
            timePerFrame: 1.0 / config.fps,
            resize: false,
            restore: false
        )
        sprite.run(.repeatForever(walkAnim), withKey: "walkAnim")
    }

    private func respawnSinglePet(name: String) {
        guard defeatedPetNames.contains(name) else { return }
        defeatedPetNames.remove(name)
        guard let config = configs.first(where: { $0.name == name }) else { return }
        spawnPet(config: config, isRespawn: true)
    }

    private func respawnAllDefeatedPets() {
        let names = Array(defeatedPetNames)
        defeatedPetNames.removeAll()

        for name in names {
            guard let config = configs.first(where: { $0.name == name }) else { continue }
            spawnPet(config: config, isRespawn: true)
        }
    }

    private func loadTextures(name: String) -> [SKTexture] {
        (0..<6).compactMap { i -> SKTexture? in
            let frameName = "pet_\(name)_frame_\(i)"
            if let url = Bundle.main.url(forResource: frameName, withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                return SKTexture(image: img)
            }
            let paths = [
                Bundle.main.bundlePath + "/Contents/Resources/\(frameName).png",
                "/Applications/YumikoToys.app/Contents/Resources/\(frameName).png",
            ]
            for path in paths {
                if let img = NSImage(contentsOfFile: path) {
                    return SKTexture(image: img)
                }
            }
            return nil
        }
    }
}