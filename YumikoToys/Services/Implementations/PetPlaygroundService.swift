//
//  PetPlaygroundService.swift
//  YumikoToys
//
//  桌宠爬爬乐服务实现（集成 4 人桌宠动画悬浮层与 SpriteKit 硬件加速补帧引擎）
//

import Foundation
import SwiftUI
import AppKit
import SpriteKit
import Combine
import QuartzCore

// MARK: - Models

struct MovementLane: Equatable, Sendable {
    var minX: CGFloat
    var maxX: CGFloat
    var y: CGFloat
}

struct PetCharacter: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let frameNames: [String]
    let initialFraction: CGFloat
    let speed: CGFloat
    let framesPerSecond: Double
    let initialFrame: Int
    let startsFacingRight: Bool

    // 精准调校 6 帧素材的步频与位移比例（6.8 ~ 7.5 FPS）
    static let all: [PetCharacter] = [
        make(id: "blue", displayName: "浅蓝队员", initialFraction: 0.08,
             speed: 42, framesPerSecond: 6.8, initialFrame: 0, startsFacingRight: true),
        make(id: "gray", displayName: "深灰队员", initialFraction: 0.34,
             speed: 52, framesPerSecond: 7.2, initialFrame: 2, startsFacingRight: false),
        make(id: "white", displayName: "白衣队员", initialFraction: 0.62,
             speed: 46, framesPerSecond: 7.0, initialFrame: 4, startsFacingRight: true),
        make(id: "tall", displayName: "浅灰队员", initialFraction: 0.86,
             speed: 56, framesPerSecond: 7.5, initialFrame: 1, startsFacingRight: false)
    ]

    private static func make(
        id: String,
        displayName: String,
        initialFraction: CGFloat,
        speed: CGFloat,
        framesPerSecond: Double,
        initialFrame: Int,
        startsFacingRight: Bool
    ) -> PetCharacter {
        PetCharacter(
            id: id,
            displayName: displayName,
            frameNames: (0..<6).map { "pet_\(id)_frame_\($0)" },
            initialFraction: initialFraction,
            speed: speed,
            framesPerSecond: framesPerSecond,
            initialFrame: initialFrame,
            startsFacingRight: startsFacingRight
        )
    }
}

struct PetItem: Identifiable, Equatable, Sendable {
    var id: String { character.id }
    let character: PetCharacter
    var position: CGPoint
    var facingRight: Bool
    var frameIndex: Int
    var frameAccumulator: Double
}

// MARK: - Image Preloader

@MainActor
final class PetImagePreloader {
    static let shared = PetImagePreloader()
    private var cache: [String: NSImage] = [:]

    private init() {}

    func preloadAll() {
        guard cache.isEmpty else { return }
        for character in PetCharacter.all {
            for name in character.frameNames {
                if let img = load(name: name) {
                    cache[name] = img
                }
            }
        }
    }

    func image(named name: String) -> NSImage? {
        if let cached = cache[name] {
            return cached
        }
        let img = load(name: name)
        if let img {
            cache[name] = img
        }
        return img
    }

    private func load(name: String) -> NSImage? {
        let candidates: [NSImage?] = [
            Bundle.main.url(forResource: name, withExtension: "png").flatMap { NSImage(contentsOf: $0) },
            NSImage(contentsOfFile: Bundle.main.bundlePath + "/Contents/Resources/\(name).png"),
            NSImage(contentsOfFile: Bundle.main.bundlePath + "/Contents/Resources/PetPlayground/\(name).png"),
            NSImage(contentsOfFile: "/Applications/YumikoToys.app/Contents/Resources/\(name).png")
        ]
        return candidates.compactMap({ $0 }).first
    }
}

// MARK: - Engine

@MainActor
final class PetPlaygroundEngine: ObservableObject {
    static let shared = PetPlaygroundEngine()

    @Published var isPaused = false {
        didSet {
            PetPlaygroundService.shared.updatePauseState(isPaused)
        }
    }

    @Published private(set) var pets: [PetItem] = []
    private let characters: [PetCharacter]
    private var lane: MovementLane

    var isRunning: Bool { PetPlaygroundService.shared.isEnabled }

    private init() {
        characters = PetCharacter.all
        lane = Self.defaultLane()
        resetPets()
    }

    func start() {
        PetImagePreloader.shared.preloadAll()
    }

    func stop() {}

    func updateMovementLane(_ value: MovementLane) {
        guard value.maxX > value.minX, value.y > 0 else { return }
        lane = value
        PetPlaygroundService.shared.updateLane(lane)
    }

    func resetPets() {
        let width = max(lane.maxX - lane.minX, 0)
        pets = characters.map { character in
            PetItem(
                character: character,
                position: CGPoint(
                    x: lane.minX + width * character.initialFraction,
                    y: lane.y
                ),
                facingRight: character.startsFacingRight,
                frameIndex: character.initialFrame % max(character.frameNames.count, 1),
                frameAccumulator: 0
            )
        }
        PetPlaygroundService.shared.resetPositions()
    }

    func advance(by rawDelta: TimeInterval) {}

    private static func defaultLane() -> MovementLane {
        let size = NSScreen.main?.frame.size ?? CGSize(width: 1200, height: 800)
        let halfPet: CGFloat = 75
        let margin: CGFloat = 12
        return MovementLane(
            minX: halfPet + margin,
            maxX: max(halfPet + margin, size.width - halfPet - margin),
            y: halfPet + margin // 底部 Y 坐标（程序栏上方）
        )
    }
}

// MARK: - SwiftUI Views (兼容预览组件)

struct PetPlaygroundSpriteView: View {
    let pet: PetItem
    var size: CGFloat = 150

    private var nsImage: NSImage? {
        guard pet.character.frameNames.indices.contains(pet.frameIndex) else { return nil }
        let name = pet.character.frameNames[pet.frameIndex]
        return PetImagePreloader.shared.image(named: name)
    }

    var body: some View {
        Group {
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.purple.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(x: pet.facingRight ? -1 : 1, y: 1)
    }
}

struct PetPlaygroundOverlayView: View {
    @ObservedObject private var engine = PetPlaygroundEngine.shared

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.clear

                ForEach(engine.pets) { pet in
                    PetPlaygroundSpriteView(pet: pet, size: 150)
                        .position(pet.position)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }
}

// MARK: - SpriteKit 桌面平滑补帧场景 (优先使用)

final class PetDesktopScene: SKScene {
    private var lane: MovementLane = MovementLane(minX: 50, maxX: 1000, y: 100)
    private var lastUpdateTime: TimeInterval?
    private var isPausedState: Bool = false

    func setupScene(lane: MovementLane) {
        self.lane = lane
        backgroundColor = .clear
        scaleMode = .resizeFill
        removeAllChildren()

        let characters = PetCharacter.all
        let width = max(lane.maxX - lane.minX, 100)

        for character in characters {
            let textures = loadTextures(character: character)
            guard !textures.isEmpty else { continue }

            let sprite = SKSpriteNode(texture: textures[0])
            sprite.size = CGSize(width: 150, height: 150)
            
            let startX = lane.minX + width * character.initialFraction
            sprite.position = CGPoint(x: startX, y: lane.y)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            sprite.name = character.id

            let facingRight = character.startsFacingRight
            sprite.xScale = facingRight ? -1.0 : 1.0

            let nodeData = NSMutableDictionary()
            nodeData["speed"] = character.speed
            nodeData["facingRight"] = facingRight
            nodeData["minX"] = lane.minX
            nodeData["maxX"] = lane.maxX
            sprite.userData = nodeData

            addChild(sprite)

            // 平滑步行动画
            let animation = SKAction.animate(
                with: textures,
                timePerFrame: 1.0 / character.framesPerSecond,
                resize: false,
                restore: false
            )
            sprite.run(.repeatForever(animation), withKey: "walkAnim")
        }
    }

    func updateLane(_ newLane: MovementLane) {
        self.lane = newLane
        enumerateChildNodes(withName: "//*") { node, _ in
            node.userData?["minX"] = newLane.minX
            node.userData?["maxX"] = newLane.maxX
            node.position.y = newLane.y
            node.position.x = min(max(node.position.x, newLane.minX), newLane.maxX)
        }
    }

    func setPausedState(_ paused: Bool) {
        self.isPausedState = paused
        self.isPaused = paused
    }

    func resetPositions() {
        let width = max(lane.maxX - lane.minX, 100)
        enumerateChildNodes(withName: "//*") { node, _ in
            guard let id = node.name,
                  let char = PetCharacter.all.first(where: { $0.id == id }) else { return }
            let startX = self.lane.minX + width * char.initialFraction
            node.position = CGPoint(x: startX, y: self.lane.y)
            let facingRight = char.startsFacingRight
            node.xScale = facingRight ? -1.0 : 1.0
            node.userData?["facingRight"] = facingRight
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isPausedState else { return }

        let dt: CGFloat
        if let lastUpdateTime {
            let rawDt = currentTime - lastUpdateTime
            dt = CGFloat(min(max(rawDt, 0.001), 0.033))
        } else {
            dt = 1.0 / 60.0
        }
        self.lastUpdateTime = currentTime

        enumerateChildNodes(withName: "//*") { node, _ in
            guard let speed = node.userData?["speed"] as? CGFloat,
                  let minX = node.userData?["minX"] as? CGFloat,
                  let maxX = node.userData?["maxX"] as? CGFloat,
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

    private func loadTextures(character: PetCharacter) -> [SKTexture] {
        character.frameNames.compactMap { name in
            let candidates: [NSImage?] = [
                Bundle.main.url(forResource: name, withExtension: "png").flatMap { NSImage(contentsOf: $0) },
                NSImage(contentsOfFile: Bundle.main.bundlePath + "/Contents/Resources/\(name).png"),
                NSImage(contentsOfFile: Bundle.main.bundlePath + "/Contents/Resources/PetPlayground/\(name).png"),
                NSImage(contentsOfFile: "/Applications/YumikoToys.app/Contents/Resources/\(name).png")
            ]
            if let img = candidates.compactMap({ $0 }).first {
                let texture = SKTexture(image: img)
                texture.filteringMode = .nearest
                return texture
            }
            return nil
        }
    }
}

// MARK: - Service Implementation

@MainActor
final class PetPlaygroundService: ObservableObject {
    static let shared = PetPlaygroundService()

    @Published private(set) var isEnabled: Bool = false
    private var overlays: [NSPanel] = []
    private var scenes: [PetDesktopScene] = []

    private init() {}

    func initialize() {
        let enabled = DependencyContainer.shared.settingsService.settings.isPetPlaygroundEnabled
        if enabled {
            startPlayground()
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        if enabled {
            startPlayground()
        } else {
            stopPlayground()
        }
        var settings = DependencyContainer.shared.settingsService.settings
        settings.isPetPlaygroundEnabled = enabled
        DependencyContainer.shared.settingsService.updateSettings(settings)
    }

    func togglePlayground() {
        setEnabled(!isEnabled)
    }

    func togglePause() {
        PetPlaygroundEngine.shared.isPaused.toggle()
    }

    func updatePauseState(_ isPaused: Bool) {
        scenes.forEach { $0.setPausedState(isPaused) }
    }

    func updateLane(_ lane: MovementLane) {
        scenes.forEach { $0.updateLane(lane) }
    }

    func resetPositions() {
        scenes.forEach { $0.resetPositions() }
    }

    private func startPlayground() {
        isEnabled = true
        PetPlaygroundEngine.shared.start()
        installOverlays()
        PetTouchBarWindowManager.shared.install()
        LoggerService.shared.info("PetPlaygroundService started desktop pets overlay")
    }

    private func stopPlayground() {
        isEnabled = false
        PetPlaygroundEngine.shared.stop()
        removeOverlays()
        PetTouchBarWindowManager.shared.uninstall()
        LoggerService.shared.info("PetPlaygroundService stopped desktop pets overlay")
    }

    private func installOverlays() {
        removeOverlays()
        scenes.removeAll()

        overlays = NSScreen.screens.map { screen in
            let lane = Self.movementLane(for: screen)
            if let mainScreen = NSScreen.main, screen === mainScreen {
                PetPlaygroundEngine.shared.updateMovementLane(lane)
            }

            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.ignoresMouseEvents = true
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false

            let skView = SKView(frame: NSRect(origin: .zero, size: screen.frame.size))
            skView.allowsTransparency = true
            skView.wantsLayer = true
            skView.layer?.backgroundColor = NSColor.clear.cgColor
            skView.autoresizingMask = [.width, .height]
            skView.ignoresSiblingOrder = true

            let scene = PetDesktopScene(size: screen.frame.size)
            scene.setupScene(lane: lane)
            skView.presentScene(scene)
            scenes.append(scene)

            panel.contentView = skView
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            return panel
        }
    }

    private func removeOverlays() {
        scenes.removeAll()
        overlays.forEach {
            $0.orderOut(nil)
            $0.close()
        }
        overlays.removeAll()
    }

    private static func movementLane(for screen: NSScreen) -> MovementLane {
        let frame = screen.frame
        let visible = screen.visibleFrame
        
        // AppKit 坐标系中 (0,0) 在屏幕左下角，visible.minY 为 Dock 程序栏顶部起点
        let localVisible = CGRect(
            x: visible.minX - frame.minX,
            y: visible.minY - frame.minY,
            width: visible.width,
            height: visible.height
        )
        let halfPet: CGFloat = 75
        let margin: CGFloat = 12
        return MovementLane(
            minX: localVisible.minX + halfPet + margin,
            maxX: max(
                localVisible.minX + halfPet + margin,
                localVisible.maxX - halfPet - margin
            ),
            y: localVisible.minY + halfPet + margin // 精确置于屏幕底部 Dock 上方
        )
    }
}