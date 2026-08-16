//
//  PetPlaygroundService.swift
//  YumikoToys
//
//  双面板解耦架构 + 马里奥“信仰之跃”抛物线跳跃引擎 (Mario Leap of Faith Physics Engine)
//

import Foundation
import AppKit
import SwiftUI
import SpriteKit

struct MovementLane: Equatable, Sendable {
    var minX: CGFloat
    var maxX: CGFloat
    var y: CGFloat
}

enum PetCharacter: String, CaseIterable, Identifiable {
    case blue = "blue"
    case gray = "gray"
    case white = "white"
    case tall = "tall"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: return "浅蓝"
        case .gray: return "深灰"
        case .white: return "白衣"
        case .tall: return "浅灰"
        }
    }

    var speed: CGFloat {
        switch self {
        case .blue: return 48.0
        case .gray: return 54.0
        case .white: return 42.0
        case .tall: return 56.0
        }
    }

    var framesPerSecond: Double { 12.0 }

    var startsFacingRight: Bool {
        switch self {
        case .blue, .white: return true
        case .gray, .tall: return false
        }
    }

    var frameNames: [String] {
        (0...5).map { "pet_\(rawValue)_frame_\($0)" }
    }

    static var all: [PetCharacter] {
        allCases
    }
}

struct PetPlaygroundItem: Identifiable {
    let id: UUID = UUID()
    let character: PetCharacter
    var position: CGPoint
    var facingRight: Bool
    var stateTime: TimeInterval = 0
}

@MainActor
final class PetPlaygroundEngine: ObservableObject {
    static let shared = PetPlaygroundEngine()

    @Published var pets: [PetPlaygroundItem] = []
    @Published var isPaused: Bool = false

    private var lane: MovementLane = MovementLane(minX: 50, maxX: 1000, y: 100)

    private init() {}

    func start() {
        if pets.isEmpty {
            resetPositions()
        }
    }

    func stop() {
        pets.removeAll()
    }

    func updateMovementLane(_ newLane: MovementLane) {
        self.lane = newLane
    }

    func resetPets() {
        resetPositions()
    }

    func resetPositions() {
        let characters = PetCharacter.all
        let screenWidth = max(lane.maxX - lane.minX, 200)

        pets = characters.enumerated().map { index, character in
            let startX = lane.minX + screenWidth * (0.08 + CGFloat(index) * 0.25)
            return PetPlaygroundItem(
                character: character,
                position: CGPoint(x: startX, y: lane.y),
                facingRight: character.startsFacingRight
            )
        }
    }
}

struct PetPlaygroundSpriteView: View {
    let pet: PetPlaygroundItem
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSImage())
            .resizable()
            .frame(width: size, height: size)
            .scaleEffect(x: pet.facingRight ? -1 : 1, y: 1)
    }
}

struct PetPlaygroundOverlayView: View {
    @ObservedObject private var visionDetector = AppleNeuralVisionDetector.shared
    @State private var isMinimized: Bool = false
    @State private var showCalibrationPanel: Bool = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if isMinimized {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isMinimized = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.green)
                        Text("🧠 ANE NPU Multi-Screen")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.85))
                            .overlay(
                                Capsule().stroke(Color.green.opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu.fill")
                            .foregroundStyle(.green)
                        Text(visionDetector.npuStatusText)
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isMinimized = true
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(4)
                                .background(Circle().fill(Color.white.opacity(0.2)))
                        }
                        .buttonStyle(.plain)
                    }

                    // NPU 自学习与手工标记校准控制栏
                    HStack(spacing: 6) {
                        Button {
                            visionDetector.toggleSelfLearning()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: visionDetector.isSelfLearningEnabled ? "checkmark.circle.fill" : "circle")
                                Text(visionDetector.isSelfLearningEnabled ? "自学习:开" : "自学习:关")
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(visionDetector.isSelfLearningEnabled ? .green : .gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCalibrationPanel.toggle()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "scope")
                                Text("🎯 手工标记校准")
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            visionDetector.resetCalibrationCache()
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("重置校准")
                            }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                        .buttonStyle(.plain)
                    }

                    if showCalibrationPanel {
                        HStack(spacing: 6) {
                            Text("📍 偏移:")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))

                            Button("X-5") { visionDetector.adjustManualCalibration(deltaX: -5, deltaY: 0) }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                                .font(.system(size: 8.5))

                            Button("X+5") { visionDetector.adjustManualCalibration(deltaX: 5, deltaY: 0) }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                                .font(.system(size: 8.5))

                            Button("Y-5") { visionDetector.adjustManualCalibration(deltaX: 0, deltaY: -5) }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .font(.system(size: 8.5))

                            Button("Y+5") { visionDetector.adjustManualCalibration(deltaX: 0, deltaY: 5) }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .font(.system(size: 8.5))
                        }
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                    }

                    Divider()
                        .background(Color.white.opacity(0.25))

                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(Array(visionDetector.reasoningLogs.prefix(8).enumerated()), id: \.offset) { idx, log in
                                    Text(log)
                                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.green.opacity(0.95))
                                        .lineLimit(1)
                                        .id("\(idx)_\(log)")
                                }
                            }
                        }
                        .frame(maxHeight: 85)
                        .onChange(of: visionDetector.reasoningLogs) { newLogs in
                            if let lastIdx = newLogs.indices.last {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(lastIdx, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .frame(width: 440)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.88))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.45), lineWidth: 1)
                        )
                )
            }
        }
        .padding(10)
    }
}

struct PetMotionData {
    var heartRate: Int = 72
    var steps: Int = 0
    var calories: Double = 0.0
}

final class PetNode: SKNode {
    let character: PetCharacter
    let spriteNode: SKSpriteNode
    let hudNode: SKNode
    let bpmLabel: SKLabelNode
    let stepsLabel: SKLabelNode
    let kcalLabel: SKLabelNode
    let hudBackground: SKShapeNode

    var motionData = PetMotionData()
    var isStateLocked: Bool = false
    var isBeingDragged: Bool = false
    var currentPetState: MotionState = .onGround
    
    private var stepAccumulator: Double = 0.0
    private var physioBPM: Double = 72.0
    private var breathingPhase: Double = Double.random(in: 0...6.28)

    enum MotionState: Equatable {
        case onGround
        case climbingLeftWall(WindowObstacle)
        case climbingRightWall(WindowObstacle)
        case walkingRoof(WindowObstacle)
        case vaultingControl(WindowObstacle, UIControlLedge)
        case slidingTextBox(WindowObstacle, UIControlLedge)
        case grindingProgressBar(WindowObstacle, UIControlLedge)
        case sprintingBrowserTab(WindowObstacle, UIControlLedge)
        case restingOnControl(WindowObstacle, UIControlLedge)
        case crawlingOnControl(WindowObstacle, UIControlLedge)
        case resting
    }

    init(character: PetCharacter, textures: [SKTexture]) {
        self.character = character

        let texture = textures.first ?? SKTexture()
        self.spriteNode = SKSpriteNode(texture: texture)
        self.spriteNode.size = CGSize(width: 135, height: 135)
        self.spriteNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        self.hudNode = SKNode()

        self.hudBackground = SKShapeNode()
        self.hudBackground.fillColor = NSColor.black.withAlphaComponent(0.78)
        self.hudBackground.strokeColor = NSColor.white.withAlphaComponent(0.35)
        self.hudBackground.lineWidth = 1.0
        self.hudNode.addChild(self.hudBackground)

        self.bpmLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        self.bpmLabel.fontSize = 10
        self.bpmLabel.fontColor = .systemRed
        self.bpmLabel.verticalAlignmentMode = .center
        self.bpmLabel.horizontalAlignmentMode = .left

        self.stepsLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        self.stepsLabel.fontSize = 10
        self.stepsLabel.fontColor = .systemCyan
        self.stepsLabel.verticalAlignmentMode = .center
        self.stepsLabel.horizontalAlignmentMode = .center

        self.kcalLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        self.kcalLabel.fontSize = 10
        self.kcalLabel.fontColor = .systemOrange
        self.kcalLabel.verticalAlignmentMode = .center
        self.kcalLabel.horizontalAlignmentMode = .right

        self.hudNode.addChild(self.bpmLabel)
        self.hudNode.addChild(self.stepsLabel)
        self.hudNode.addChild(self.kcalLabel)

        super.init()

        addChild(self.spriteNode)

        if !textures.isEmpty {
            let anim = SKAction.animate(with: textures, timePerFrame: 1.0 / character.framesPerSecond, resize: false, restore: false)
            self.spriteNode.run(.repeatForever(anim), withKey: "walkAnim")
        }

        updateHUDTextAndDynamicLayout()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateMotion(dt: CGFloat) {
        let walkSpeed = currentPetState == .resting ? 0.0 : Double(character.speed)
        stepAccumulator += walkSpeed * Double(dt) * 0.65
        if stepAccumulator >= 1.0 {
            let stepsToAdd = Int(stepAccumulator)
            motionData.steps += stepsToAdd
            stepAccumulator -= Double(stepsToAdd)
            motionData.calories = Double(motionData.steps) * 0.041
        }

        breathingPhase += Double(dt) * 1.5
        let sinusArrhythmia = sin(breathingPhase) * 2.2

        let targetBaseBPM: Double
        switch currentPetState {
        case .onGround:
            targetBaseBPM = 96.0 + sinusArrhythmia
        case .climbingLeftWall, .climbingRightWall:
            targetBaseBPM = 142.0 + sinusArrhythmia * 1.5
        case .walkingRoof:
            targetBaseBPM = 110.0 + sinusArrhythmia
        case .vaultingControl:
            targetBaseBPM = 158.0 + sinusArrhythmia * 2.0
        case .slidingTextBox:
            targetBaseBPM = 125.0 + sinusArrhythmia * 1.2
        case .grindingProgressBar:
            targetBaseBPM = 168.0 + sinusArrhythmia * 2.5
        case .sprintingBrowserTab:
            targetBaseBPM = 160.0 + sinusArrhythmia * 2.0
        case .crawlingOnControl:
            targetBaseBPM = 105.0 + sinusArrhythmia
        case .restingOnControl, .resting:
            targetBaseBPM = 68.0 + sinusArrhythmia
        }

        if targetBaseBPM > physioBPM {
            physioBPM += (targetBaseBPM - physioBPM) * Double(dt) * 1.6
        } else {
            physioBPM -= (physioBPM - targetBaseBPM) * Double(dt) * 0.55
        }
        motionData.heartRate = max(60, min(180, Int(round(physioBPM))))

        updateHUDTextAndDynamicLayout()
        updateHUDWorldPosition()
    }

    private func updateHUDTextAndDynamicLayout() {
        let stepStr = "\(motionData.steps)"
        let kcalStr = String(format: "%.1fk", motionData.calories)

        bpmLabel.text = "❤️\(motionData.heartRate)"
        stepsLabel.text = "👟\(stepStr)"
        kcalLabel.text = "🔥\(kcalStr)"

        let extraStepsWidth = CGFloat(max(0, stepStr.count - 3)) * 8.5
        let extraKcalWidth = CGFloat(max(0, kcalStr.count - 4)) * 7.5
        let bgWidth: CGFloat = max(168.0, 142.0 + extraStepsWidth + extraKcalWidth)
        let bgHeight: CGFloat = 22.0

        let bgRect = CGRect(x: -bgWidth / 2, y: -bgHeight / 2, width: bgWidth, height: bgHeight)
        self.hudBackground.path = CGPath(roundedRect: bgRect, cornerWidth: 11, cornerHeight: 11, transform: nil)

        let margin: CGFloat = 12.0
        bpmLabel.position = CGPoint(x: -bgWidth / 2 + margin, y: 0)
        stepsLabel.position = CGPoint(x: 0, y: 0)
        kcalLabel.position = CGPoint(x: bgWidth / 2 - margin, y: 0)
    }

    func updateHUDWorldPosition() {
        guard let scene = self.scene else {
            hudNode.removeFromParent()
            return
        }
        if hudNode.parent !== scene {
            hudNode.removeFromParent()
            scene.addChild(hudNode)
        }
        hudNode.position = CGPoint(x: self.position.x, y: self.position.y + 78.0)
        hudNode.zRotation = 0.0
        hudNode.xScale = 1.0
        hudNode.yScale = 1.0
        hudNode.alpha = self.alpha
        hudNode.isHidden = self.isHidden
    }

    /// 马里奥“信仰之跃”抛物线跳跃物理引擎 (Mario Leap of Faith Parabola Physics)
    func performMarioLeap(to targetPoint: CGPoint, targetState: MotionState) {
        removeAllActions()
        isStateLocked = true

        let startPos = self.position
        let dx = targetPoint.x - startPos.x
        if dx != 0 {
            spriteNode.xScale = dx > 0 ? -1.0 : 1.0
        }

        let peakHeight: CGFloat = max(90.0, abs(targetPoint.y - startPos.y) + 70.0)
        let duration: TimeInterval = 0.58

        let leapAction = SKAction.customAction(withDuration: duration) { node, elapsedTime in
            let t = CGFloat(elapsedTime / duration)
            let curX = startPos.x + (targetPoint.x - startPos.x) * t
            let curY = startPos.y + (targetPoint.y - startPos.y) * t + peakHeight * sin(t * .pi)
            node.position = CGPoint(x: curX, y: curY)
        }

        let rotateJump = SKAction.sequence([
            SKAction.rotate(byAngle: dx > 0 ? -.pi * 2 : .pi * 2, duration: duration)
        ])

        let landingBounce = SKAction.sequence([
            SKAction.moveBy(x: 0, y: -10, duration: 0.08),
            SKAction.moveBy(x: 0, y: 10, duration: 0.08)
        ])

        let resetRotation = SKAction.rotate(toAngle: 0.0, duration: 0.05)

        let unlockAction = SKAction.run { [weak self] in
            guard let self else { return }
            self.zRotation = 0.0
            self.isStateLocked = false
            self.currentPetState = targetState
        }

        run(SKAction.sequence([
            SKAction.group([leapAction, rotateJump]),
            resetRotation,
            landingBounce,
            unlockAction
        ]))
    }
}

@MainActor
final class PetDesktopScene: SKScene {
    private var lane: MovementLane = MovementLane(minX: 50, maxX: 1000, y: 100)
    private var targetScreen: NSScreen?
    private var screenIndex: Int = 0
    private var screenCount: Int = 1
    private var lastUpdateTime: TimeInterval?
    private var isPausedState: Bool = false
    private var petNodes: [PetNode] = []
    private var logUpdateCounter: Int = 0
    
    private var draggedPetNode: PetNode?
    private var dragOffset: CGPoint = .zero

    var isDraggingPet: Bool {
        draggedPetNode != nil
    }

    var activeTargetScreen: NSScreen? {
        targetScreen
    }

    func setDraggedPetNode(_ node: PetNode?, dragOffset: CGPoint = .zero) {
        self.draggedPetNode = node
        self.dragOffset = dragOffset
    }

    func removePetNode(_ node: PetNode) {
        if draggedPetNode === node {
            draggedPetNode = nil
        }
        node.hudNode.removeFromParent()
        node.removeFromParent()
        petNodes.removeAll(where: { $0 === node })
    }

    func addPetNode(_ node: PetNode) {
        if !petNodes.contains(where: { $0 === node }) {
            petNodes.append(node)
            addChild(node)
        }
    }

    func hitTestPetNode(at point: CGPoint) -> PetNode? {
        for petNode in petNodes {
            let pos = petNode.position
            if abs(point.x - pos.x) < 65 && abs(point.y - pos.y) < 65 {
                return petNode
            }
        }
        return nil
    }

    func handleMouseDown(at point: CGPoint) {
        if let hitNode = hitTestPetNode(at: point) {
            draggedPetNode = hitNode
            dragOffset = CGPoint(x: point.x - hitNode.position.x, y: point.y - hitNode.position.y)
            hitNode.isStateLocked = true
            hitNode.isBeingDragged = true
            hitNode.removeAllActions()
            hitNode.zRotation = 0.0
        }
    }

    func handleMouseDragged(to point: CGPoint) {
        guard let petNode = draggedPetNode else { return }
        petNode.position = CGPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y)

        // 跨屏拖拽实测检测 (Cross-Screen Drag Transfer):
        let globalMouse = NSEvent.mouseLocation
        if let currentScreen = targetScreen, !NSPointInRect(globalMouse, currentScreen.frame) {
            if let destScreen = NSScreen.screens.first(where: { NSPointInRect(globalMouse, $0.frame) }) {
                PetPlaygroundService.shared.transferDraggedPet(petNode, fromScene: self, toScreen: destScreen, globalMouse: globalMouse)
            }
        }
    }

    func handleMouseUp(at point: CGPoint) {
        guard let petNode = draggedPetNode else { return }
        petNode.isBeingDragged = false
        petNode.isStateLocked = false

        guard let targetScreen else {
            petNode.currentPetState = .onGround
            draggedPetNode = nil
            return
        }

        let screenWidth = targetScreen.frame.width
        let screenHeight = targetScreen.frame.height
        let pos = petNode.position
        let dockTopY = DesktopWindowDetector.shared.dockTopY + 45.0

        if pos.y >= screenHeight - 80 {
            petNode.position.y = screenHeight - 45.0
            petNode.currentPetState = .onGround
        } else if pos.x <= 80 {
            petNode.position.x = 25.0
            petNode.zRotation = .pi / 2
        } else if pos.x >= screenWidth - 80 {
            petNode.position.x = screenWidth - 25.0
            petNode.zRotation = -.pi / 2
        } else if pos.y <= dockTopY + 50 {
            petNode.position.y = dockTopY
            petNode.currentPetState = .onGround
            petNode.zRotation = 0.0
        } else {
            let mainWindows = DesktopWindowDetector.shared.obstacles(for: targetScreen)
            if let nearbyWin = mainWindows.first(where: { abs($0.topEdgeY + 45.0 - pos.y) < 70 && pos.x >= $0.leftWallX - 30 && pos.x <= $0.rightWallX + 30 }) {
                petNode.position.y = nearbyWin.topEdgeY + 45.0
                petNode.currentPetState = .walkingRoof(nearbyWin)
                petNode.zRotation = 0.0
            } else {
                petNode.performMarioLeap(to: CGPoint(x: pos.x, y: dockTopY), targetState: .onGround)
            }
        }

        draggedPetNode = nil
    }

    func isPetNear(screenPoint: NSPoint) -> Bool {
        guard let view = self.view, let window = view.window else { return false }
        if draggedPetNode != nil { return true }
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let scenePoint = self.convertPoint(fromView: windowPoint)
        return hitTestPetNode(at: scenePoint) != nil
    }

    /// 在控件踩跃点动态渲染 NPU 神经网络霓绿视觉锁定环 (ANE Target Lock Ring)
    func showANEVisionTargetRing(at point: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 18)
        ring.position = point
        ring.strokeColor = NSColor.systemGreen
        ring.fillColor = NSColor.systemGreen.withAlphaComponent(0.22)
        ring.lineWidth = 2.0
        ring.zPosition = 999
        addChild(ring)
        let scaleUp = SKAction.scale(to: 1.6, duration: 0.35)
        let fadeOut = SKAction.fadeOut(withDuration: 0.35)
        let group = SKAction.group([scaleUp, fadeOut])
        let remove = SKAction.removeFromParent()
        ring.run(SKAction.sequence([group, remove]))
    }

    func setupScene(lane: MovementLane, screen: NSScreen, screenIndex: Int, screenCount: Int) {
        self.lane = lane
        self.targetScreen = screen
        self.screenIndex = screenIndex
        self.screenCount = screenCount
        backgroundColor = .clear
        scaleMode = .resizeFill
        for node in petNodes {
            node.hudNode.removeFromParent()
        }
        removeAllChildren()
        petNodes.removeAll()

        let disabledSet = Set(DependencyContainer.shared.settingsService.settings.disabledPetCharacters)
        let enabledCharacters = PetCharacter.all.filter { !disabledSet.contains($0.rawValue) }
        let assignedCharacters: [PetCharacter]
        if screenCount > 1 && !enabledCharacters.isEmpty {
            assignedCharacters = enabledCharacters.enumerated().filter { $0.offset % screenCount == screenIndex }.map { $0.element }
        } else {
            assignedCharacters = enabledCharacters
        }

        let screenWidth = max(lane.maxX - lane.minX, 200)
        let mainWindows = DesktopWindowDetector.shared.obstacles(for: screen)
        let dockTopY = DesktopWindowDetector.shared.dockTopY + 45.0

        for (index, character) in assignedCharacters.enumerated() {
            let textures = loadTextures(character: character)
            guard let petNode = textures.isEmpty ? nil : PetNode(character: character, textures: textures) else {
                continue
            }
            
            let startX: CGFloat
            let startY: CGFloat

            if index == 0 {
                startX = lane.minX + screenWidth * 0.18
                startY = dockTopY
            } else if index == 1 && !mainWindows.isEmpty {
                let win = mainWindows[0]
                startX = min(max(win.leftWallX + 60, lane.minX), lane.maxX - 60)
                startY = win.topEdgeY + 45.0
                petNode.currentPetState = .walkingRoof(win)
            } else {
                startX = lane.minX + screenWidth * (0.2 + CGFloat(index) * 0.35)
                startY = dockTopY
            }

            petNode.position = CGPoint(x: startX, y: startY)
            petNode.spriteNode.xScale = character.startsFacingRight ? -1.0 : 1.0
            
            petNodes.append(petNode)
            addChild(petNode)
        }
    }

    func updateLane(_ newLane: MovementLane) {
        self.lane = newLane
    }

    func setPausedState(_ paused: Bool) {
        self.isPausedState = paused
        self.isPaused = paused
    }

    func resetPositions() {
        let screenWidth = max(lane.maxX - lane.minX, 200)
        let groundY = DesktopWindowDetector.shared.dockTopY + 45.0
        for (index, petNode) in petNodes.enumerated() {
            petNode.removeAllActions()
            petNode.isStateLocked = false
            petNode.currentPetState = .onGround
            petNode.zRotation = 0.0

            let startX = lane.minX + screenWidth * (0.08 + CGFloat(index) * 0.25)
            petNode.position = CGPoint(x: startX, y: groundY)
            petNode.spriteNode.xScale = petNode.character.startsFacingRight ? -1.0 : 1.0
        }
    }

    private var inspectorLayerNode: SKNode?

    /// 类似浏览器开发者工具 (Inspect Element) 的动态 NPU 神经网络识别框与虚拟物理透明墙 Overlay
    func updateDevToolsInspectorOverlays(windows: [WindowObstacle], isEnabled: Bool) {
        if !isEnabled {
            inspectorLayerNode?.removeFromParent()
            inspectorLayerNode = nil
            return
        }

        if inspectorLayerNode == nil {
            let layer = SKNode()
            layer.zPosition = 900
            addChild(layer)
            inspectorLayerNode = layer
        }

        guard let layer = inspectorLayerNode else { return }
        layer.removeAllChildren()

        for win in windows {
            // 1. 窗口虚拟物理透明墙框 (DevTools Bounding Box)
            let winShape = SKShapeNode(rect: win.cocoaFrame, cornerRadius: 8.0)
            winShape.strokeColor = NSColor.systemCyan.withAlphaComponent(0.9)
            winShape.fillColor = NSColor.systemCyan.withAlphaComponent(0.08)
            winShape.lineWidth = 1.5
            layer.addChild(winShape)

            // 窗口识别 Tag Badge
            let labelBg = SKShapeNode(rectOf: CGSize(width: min(220, win.cocoaFrame.width * 0.7), height: 18), cornerRadius: 4)
            labelBg.position = CGPoint(x: win.cocoaFrame.minX + 90, y: win.cocoaFrame.maxY - 10)
            labelBg.fillColor = NSColor.black.withAlphaComponent(0.85)
            labelBg.strokeColor = NSColor.systemCyan
            labelBg.lineWidth = 1.0

            let winLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            winLabel.fontSize = 9
            winLabel.fontColor = .systemCyan
            winLabel.text = "<\(win.ownerName): VirtualWall>"
            winLabel.verticalAlignmentMode = .center
            winLabel.horizontalAlignmentMode = .center
            labelBg.addChild(winLabel)
            layer.addChild(labelBg)

            // 2. 窗口内部 UI 控件与文本框识别框 (DevTools Inspector Control Bounding Box)
            for ledge in win.controlLedges {
                let rect = ledge.rect
                let strokeColor: NSColor
                switch ledge.type {
                case .button, .searchField: strokeColor = .systemGreen
                case .textField, .textArea: strokeColor = .systemYellow
                case .progressBar: strokeColor = .systemPink
                case .addressBar, .tabBar: strokeColor = .systemPurple
                }

                let ctrlShape = SKShapeNode(rect: rect, cornerRadius: 4.0)
                ctrlShape.strokeColor = strokeColor
                ctrlShape.fillColor = strokeColor.withAlphaComponent(0.15)
                ctrlShape.lineWidth = 1.2
                layer.addChild(ctrlShape)

                let tagLabel = SKLabelNode(fontNamed: "Menlo-Bold")
                tagLabel.fontSize = 8
                tagLabel.fontColor = strokeColor
                tagLabel.text = "[\(ledge.type.rawValue)] \(ledge.name)"
                tagLabel.position = CGPoint(x: rect.midX, y: rect.maxY + 4.0)
                tagLabel.horizontalAlignmentMode = .center
                layer.addChild(tagLabel)
            }
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

        guard let targetScreen else { return }
        let mainWindows = DesktopWindowDetector.shared.obstacles(for: targetScreen)
        let dockTopY = DesktopWindowDetector.shared.dockTopY + 45.0
        let screenHeight = targetScreen.frame.height

        let isInspectorEnabled = DependencyContainer.shared.settingsService.settings.showANEVisionInspector
        updateDevToolsInspectorOverlays(windows: mainWindows, isEnabled: isInspectorEnabled)

        logUpdateCounter += 1
        if logUpdateCounter >= 18 {
            logUpdateCounter = 0
            var decisionLogs: [String] = []
            let date = Date()
            let cal = Calendar.current
            let h = cal.component(.hour, from: date)
            let m = cal.component(.minute, from: date)
            let s = cal.component(.second, from: date)
            let ms = Int(date.timeIntervalSince1970 * 10) % 10
            let timeStr = String(format: "%02d:%02d:%02d.%d", h, m, s, ms)
            
            let detectedNames = Array(Set(mainWindows.map { "[\($0.ownerName)]" })).prefix(4).joined(separator: ", ")
            let topStr = detectedNames.isEmpty ? "无窗口" : detectedNames
            decisionLogs.append("⚡️ [\(timeStr)] NPU 视觉拓扑: 识别到 \(topStr) 共 \(mainWindows.count) 个交互图层")
            
            let ids = ["0x01", "0x02", "0x03", "0x04"]
            for (idx, petNode) in petNodes.enumerated() {
                let name = petNode.character.displayName
                let hexId = idx < ids.count ? ids[idx] : "0x00"
                let logLine: String
                let pos = petNode.position
                let steps = petNode.motionData.steps
                
                switch petNode.currentPetState {
                case .onGround:
                    logLine = "🤖 \(name) (\(hexId)): [NPU 跑酷锁] 地面冲刺 (X:\(Int(pos.x))) | 锁存图层: \(topStr)"
                case .climbingLeftWall(let w):
                    logLine = "🤖 \(name) (\(hexId)): [NPU 飞檐走壁 90°] 攀爬 [\(w.ownerName)] 左壁 (Y:\(Int(pos.y)))"
                case .climbingRightWall(let w):
                    logLine = "🤖 \(name) (\(hexId)): [NPU 飞檐走壁 -90°] 攀爬 [\(w.ownerName)] 右壁 (Y:\(Int(pos.y)))"
                case .walkingRoof(let w):
                    logLine = "🤖 \(name) (\(hexId)): [NPU 屋顶走秀] 踩踏 [\(w.ownerName)] 顶端 (X:\(Int(pos.x)))"
                case .vaultingControl(let w, let ledge):
                    logLine = "🤖 \(name) (\(hexId)): [NPU \(ledge.type.rawValue)跑酷] 踩跃 [\(w.ownerName)] 的 [\(ledge.name)] 触发信仰飞跃!"
                case .slidingTextBox(let w, let ledge):
                    logLine = "🤖 \(name) (\(hexId)): [NPU 文本框走秀] 踏上 [\(w.ownerName)] 的 [\(ledge.name)] 平衡走秀滑行!"
                case .grindingProgressBar(let w, let ledge):
                    logLine = "🤖 \(name) (\(hexId)): [NPU 进度条滑行] 踏上 [\(w.ownerName)] 的 [\(ledge.name)] 极速溜冰滑行!"
                case .sprintingBrowserTab(let w, let ledge):
                    logLine = "🤖 \(name) (\(hexId)): [NPU 浏览器跑酷] 踏上 [\(w.ownerName)] 的 [\(ledge.name)] 飞檐走壁冲刺!"
                case .restingOnControl(let w, let ledge):
                    logLine = "🤖 \(name) (\(hexId)): [NPU 控件趴卧] 趴在 [\(w.ownerName)] 的 [\(ledge.name)] 上打盹休息..."
                case .crawlingOnControl(let w, let ledge):
                    logLine = "🤖 \(name) (\(hexId)): [NPU 控件爬行] 在 [\(w.ownerName)] 的 [\(ledge.name)] 表面巡逻走秀!"
                case .resting:
                    logLine = "🤖 \(name) (\(hexId)): [NPU 休息] 原地修整 (X:\(Int(pos.x))) | 👟\(steps)"
                }
                decisionLogs.append(logLine)
            }
            AppleNeuralVisionDetector.shared.updatePetDecisionLogs(decisionLogs)
        }

        for (index, petNode) in petNodes.enumerated() {
            petNode.updateMotion(dt: dt)

            if petNode.isStateLocked || petNode.isBeingDragged { continue }

            let facingRight = petNode.spriteNode.xScale < 0
            let speed = petNode.character.speed
            let dir: CGFloat = facingRight ? 1.0 : -1.0
            var pos = petNode.position

            // 全系统 Universal UI 控件、媒体进度条与浏览器跑酷/控件趴卧动作适配
            for window in mainWindows {
                for ledge in window.controlLedges {
                    let btnRect = ledge.rect
                    if abs(pos.x - btnRect.midX) < 45 && abs(pos.y - btnRect.midY) < 40 {
                        petNode.isStateLocked = true
                        showANEVisionTargetRing(at: CGPoint(x: btnRect.midX, y: btnRect.midY))

                        let shouldRestOnControl = Double.random(in: 0...1.0) < 0.45

                        if shouldRestOnControl {
                            // 特色动作：直接趴在控件/桌面图标上方打盹休息 (Rest & Lie down on control/folder)
                            petNode.currentPetState = .restingOnControl(window, ledge)
                            let hopOnTop = SKAction.move(to: CGPoint(x: btnRect.midX, y: btnRect.maxY + 12.0), duration: 0.15)
                            let snuggleTilt = SKAction.rotate(toAngle: 0.08, duration: 0.18)
                            let restSleep = SKAction.wait(forDuration: TimeInterval.random(in: 2.5...4.5))
                            let resetTilt = SKAction.rotate(toAngle: 0.0, duration: 0.15)
                            let unlock = SKAction.run {
                                petNode.isStateLocked = false
                                petNode.zRotation = 0.0
                                petNode.spriteNode.zRotation = 0.0
                                petNode.currentPetState = .walkingRoof(window)
                            }
                            petNode.run(SKAction.sequence([hopOnTop, snuggleTilt, restSleep, resetTilt, unlock]))
                        } else {
                            switch ledge.type {
                            case .button, .searchField:
                                petNode.currentPetState = .crawlingOnControl(window, ledge)
                                let hopToButton = SKAction.move(to: CGPoint(x: btnRect.minX + 15.0, y: btnRect.maxY + 12.0), duration: 0.14)
                                let crawlAcross = SKAction.move(to: CGPoint(x: btnRect.maxX - 15.0, y: btnRect.maxY + 12.0), duration: 0.35)
                                let wiggle = SKAction.rotate(byAngle: 0.10, duration: 0.1)
                                let resetRot = SKAction.rotate(toAngle: 0.0, duration: 0.12)
                                let unlock = SKAction.run {
                                    petNode.isStateLocked = false
                                    petNode.zRotation = 0.0
                                    petNode.spriteNode.zRotation = 0.0
                                    petNode.currentPetState = .walkingRoof(window)
                                }
                                petNode.run(SKAction.sequence([hopToButton, crawlAcross, wiggle, resetRot, unlock]))

                            case .textField, .textArea:
                                petNode.currentPetState = .slidingTextBox(window, ledge)
                                let startPos = CGPoint(x: btnRect.minX + 15.0, y: btnRect.maxY + 15.0)
                                let endPos = CGPoint(x: btnRect.maxX - 15.0, y: btnRect.maxY + 15.0)
                                
                                let stepOntoText = SKAction.move(to: startPos, duration: 0.12)
                                let slideAlongText = SKAction.move(to: endPos, duration: 0.38)
                                let leapToRoof = SKAction.move(to: CGPoint(x: endPos.x, y: window.topEdgeY + 45.0), duration: 0.2)
                                let unlock = SKAction.run {
                                    petNode.isStateLocked = false
                                    petNode.zRotation = 0.0
                                    petNode.spriteNode.zRotation = 0.0
                                    petNode.currentPetState = .walkingRoof(window)
                                }
                                petNode.run(SKAction.sequence([stepOntoText, slideAlongText, leapToRoof, unlock]))

                            case .progressBar:
                                petNode.currentPetState = .grindingProgressBar(window, ledge)
                                let startPos = CGPoint(x: btnRect.minX + 10.0, y: btnRect.maxY + 12.0)
                                let endPos = CGPoint(x: btnRect.maxX - 10.0, y: btnRect.maxY + 12.0)
                                let stepOntoRail = SKAction.move(to: startPos, duration: 0.1)
                                let tiltSkate = SKAction.rotate(toAngle: -0.15, duration: 0.08)
                                let railGrind = SKAction.move(to: endPos, duration: 0.32)
                                let resetTilt = SKAction.rotate(toAngle: 0.0, duration: 0.08)
                                let leapToRoof = SKAction.move(to: CGPoint(x: endPos.x, y: window.topEdgeY + 45.0), duration: 0.2)
                                let unlock = SKAction.run {
                                    petNode.isStateLocked = false
                                    petNode.zRotation = 0.0
                                    petNode.spriteNode.zRotation = 0.0
                                    petNode.currentPetState = .walkingRoof(window)
                                }
                                petNode.run(SKAction.sequence([stepOntoRail, tiltSkate, railGrind, resetTilt, leapToRoof, unlock]))

                            case .addressBar, .tabBar:
                                petNode.currentPetState = .sprintingBrowserTab(window, ledge)
                                let startPos = CGPoint(x: btnRect.minX + 20.0, y: btnRect.maxY + 12.0)
                                let endPos = CGPoint(x: btnRect.maxX - 20.0, y: btnRect.maxY + 12.0)
                                let stepOntoBar = SKAction.move(to: startPos, duration: 0.1)
                                let tabSprint = SKAction.move(to: endPos, duration: 0.28)
                                let leapToRoof = SKAction.move(to: CGPoint(x: endPos.x, y: window.topEdgeY + 45.0), duration: 0.18)
                                let unlock = SKAction.run {
                                    petNode.isStateLocked = false
                                    petNode.zRotation = 0.0
                                    petNode.spriteNode.zRotation = 0.0
                                    petNode.currentPetState = .walkingRoof(window)
                                }
                                petNode.run(SKAction.sequence([stepOntoBar, tabSprint, leapToRoof, unlock]))
                            }
                        }
                        continue
                    }
                }
            }

            switch petNode.currentPetState {
            case .onGround:
                pos.x += speed * dir * dt
                pos.y = dockTopY

                if pos.x >= lane.maxX - 20 {
                    let frame = targetScreen.frame
                    if let rightScreen = NSScreen.screens.first(where: { abs($0.frame.minX - frame.maxX) < 60 }) {
                        PetPlaygroundService.shared.transferWalkingPet(petNode, fromScene: self, toScreen: rightScreen, enteringLeftEdge: true)
                        return
                    }
                    pos.x = lane.maxX - 20
                    petNode.spriteNode.xScale = 1.0
                } else if pos.x <= lane.minX + 20 {
                    let frame = targetScreen.frame
                    if let leftScreen = NSScreen.screens.first(where: { abs($0.frame.maxX - frame.minX) < 60 }) {
                        PetPlaygroundService.shared.transferWalkingPet(petNode, fromScene: self, toScreen: leftScreen, enteringLeftEdge: false)
                        return
                    }
                    pos.x = lane.minX + 20
                    petNode.spriteNode.xScale = -1.0
                }

                for window in mainWindows {
                    let isClingLeft = facingRight && abs(pos.x - window.leftWallX) < 30 && pos.y < window.topEdgeY
                    let isClingRight = !facingRight && abs(pos.x - window.rightWallX) < 30 && pos.y < window.topEdgeY

                    if isClingLeft {
                        petNode.isStateLocked = true
                        petNode.currentPetState = .climbingLeftWall(window)
                        
                        let clingX = window.leftWallX - 10.0
                        let targetY = min(window.topEdgeY + 45.0, screenHeight - 40.0)
                        let climbDistance = abs(targetY - pos.y)
                        let climbDuration = max(0.35, TimeInterval(climbDistance / (speed * 0.85)))

                        let alignAction = SKAction.move(to: CGPoint(x: clingX, y: pos.y), duration: 0.12)
                        let rotateAction = SKAction.rotate(toAngle: .pi / 2, duration: 0.15)
                        
                        let climbMove = SKAction.moveTo(y: targetY - 12.0, duration: climbDuration)
                        let wiggleSeq = SKAction.sequence([
                            SKAction.rotate(byAngle: 0.07, duration: 0.1),
                            SKAction.rotate(byAngle: -0.14, duration: 0.2),
                            SKAction.rotate(byAngle: 0.07, duration: 0.1)
                        ])
                        let climbWiggle = SKAction.repeat(wiggleSeq, count: max(1, Int(climbDuration * 2.5)))
                        let climbGroup = SKAction.group([climbMove, climbWiggle])
                        
                        let cornerArc = SKAction.move(by: CGVector(dx: 12.0, dy: 12.0), duration: 0.18)
                        let cornerRotate = SKAction.rotate(toAngle: 0.0, duration: 0.18)
                        let cornerGroup = SKAction.group([cornerArc, cornerRotate])

                        let unlockAction = SKAction.run {
                            petNode.isStateLocked = false
                            petNode.zRotation = 0.0
                            petNode.spriteNode.zRotation = 0.0
                            petNode.currentPetState = .walkingRoof(window)
                        }

                        petNode.run(SKAction.sequence([alignAction, rotateAction, climbGroup, cornerGroup, unlockAction]))
                        return
                    } else if isClingRight {
                        petNode.isStateLocked = true
                        petNode.currentPetState = .climbingRightWall(window)

                        let clingX = window.rightWallX + 10.0
                        let targetY = min(window.topEdgeY + 45.0, screenHeight - 40.0)
                        let climbDistance = abs(targetY - pos.y)
                        let climbDuration = max(0.35, TimeInterval(climbDistance / (speed * 0.85)))

                        let alignAction = SKAction.move(to: CGPoint(x: clingX, y: pos.y), duration: 0.12)
                        let rotateAction = SKAction.rotate(toAngle: -.pi / 2, duration: 0.15)

                        let climbMove = SKAction.moveTo(y: targetY - 12.0, duration: climbDuration)
                        let wiggleSeq = SKAction.sequence([
                            SKAction.rotate(byAngle: -0.07, duration: 0.1),
                            SKAction.rotate(byAngle: 0.14, duration: 0.2),
                            SKAction.rotate(byAngle: -0.07, duration: 0.1)
                        ])
                        let climbWiggle = SKAction.repeat(wiggleSeq, count: max(1, Int(climbDuration * 2.5)))
                        let climbGroup = SKAction.group([climbMove, climbWiggle])

                        let cornerArc = SKAction.move(by: CGVector(dx: -12.0, dy: 12.0), duration: 0.18)
                        let cornerRotate = SKAction.rotate(toAngle: 0.0, duration: 0.18)
                        let cornerGroup = SKAction.group([cornerArc, cornerRotate])

                        let unlockAction = SKAction.run {
                            petNode.isStateLocked = false
                            petNode.zRotation = 0.0
                            petNode.spriteNode.zRotation = 0.0
                            petNode.currentPetState = .walkingRoof(window)
                        }

                        petNode.run(SKAction.sequence([alignAction, rotateAction, climbGroup, cornerGroup, unlockAction]))
                        return
                    }
                }

                petNode.position = pos

            case .walkingRoof(let window):
                pos.x += speed * dir * dt

                // 核心 1：遮挡响应逻辑 (Frontmost Window Occlusion Step-Up)
                // 若干员当前踩踏的窗口 roof 被更高 Z-Order 的前台新窗口遮挡，立即踏上新窗口的顶部天花板！
                if let coveringWin = DesktopWindowDetector.shared.isPointOccluded(CGPoint(x: pos.x, y: pos.y), targetWindowID: window.windowID, screen: targetScreen) {
                    let newRoofY = coveringWin.topEdgeY + 45.0
                    petNode.position = CGPoint(x: pos.x, y: newRoofY)
                    petNode.currentPetState = .walkingRoof(coveringWin)
                    return
                }

                // 核心 2：即时监测窗口关闭/最小化/快速拖拽 (Mario Leap of Faith Trigger)
                if let updatedWin = mainWindows.first(where: { $0.windowID == window.windowID }) {
                    pos.y = updatedWin.topEdgeY + 45.0
                    // 越界脱离判定
                    if pos.x < updatedWin.leftWallX - 15 || pos.x > updatedWin.rightWallX + 15 {
                        // 尝试发起马里奥“信仰之跃”寻找附近其他窗口天花板
                        if let targetAltWin = mainWindows.first(where: { $0.windowID != updatedWin.windowID && abs($0.topEdgeY - pos.y) < 250 }) {
                            let targetX = min(max(targetAltWin.leftWallX + 60, lane.minX), lane.maxX - 60)
                            let targetPt = CGPoint(x: targetX, y: targetAltWin.topEdgeY + 45.0)
                            petNode.performMarioLeap(to: targetPt, targetState: .walkingRoof(targetAltWin))
                        } else {
                            let targetPt = CGPoint(x: pos.x, y: dockTopY)
                            petNode.performMarioLeap(to: targetPt, targetState: .onGround)
                        }
                        return
                    }
                } else {
                    // 原窗口已被关闭、最小化或销毁！即刻触发马里奥“信仰之跃”跃迁至附近窗口或 Dock！
                    if let targetAltWin = mainWindows.first(where: { abs($0.topEdgeY - pos.y) < 250 }) {
                        let targetX = min(max(targetAltWin.leftWallX + 60, lane.minX), lane.maxX - 60)
                        let targetPt = CGPoint(x: targetX, y: targetAltWin.topEdgeY + 45.0)
                        petNode.performMarioLeap(to: targetPt, targetState: .walkingRoof(targetAltWin))
                    } else {
                        let targetPt = CGPoint(x: pos.x, y: dockTopY)
                        petNode.performMarioLeap(to: targetPt, targetState: .onGround)
                    }
                    return
                }

                petNode.position = pos

            default:
                break
            }

            for otherIndex in (index + 1)..<petNodes.count {
                let other = petNodes[otherIndex]
                let dx = abs(petNode.position.x - other.position.x)
                let dy = abs(petNode.position.y - other.position.y)
                if dy < 35 && dx < 85 {
                    let pet1FacingRight = petNode.spriteNode.xScale < 0
                    let pet2FacingRight = other.spriteNode.xScale < 0
                    
                    if petNode.position.x < other.position.x {
                        if pet1FacingRight { petNode.spriteNode.xScale = 1.0 }
                        if !pet2FacingRight { other.spriteNode.xScale = -1.0 }
                    } else {
                        if !pet1FacingRight { petNode.spriteNode.xScale = -1.0 }
                        if pet2FacingRight { other.spriteNode.xScale = 1.0 }
                    }
                }
            }
        }
    }

    private func loadTextures(character: PetCharacter) -> [SKTexture] {
        let loaded = character.frameNames.compactMap { name in
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
        if !loaded.isEmpty {
            return loaded
        }
        let size = CGSize(width: 64, height: 64)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.systemPink.set()
        NSRect(origin: .zero, size: size).fill()
        img.unlockFocus()
        return [SKTexture(image: img)]
    }
}

final class PetInteractiveSKView: SKView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        if let scene = self.scene as? PetDesktopScene {
            let scenePoint = scene.convertPoint(fromView: point)
            if scene.hitTestPetNode(at: scenePoint) != nil {
                return self
            }
        }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        let location = self.convert(event.locationInWindow, to: nil)
        if let scene = self.scene as? PetDesktopScene {
            let scenePoint = scene.convertPoint(fromView: location)
            scene.handleMouseDown(at: scenePoint)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let location = self.convert(event.locationInWindow, to: nil)
        if let scene = self.scene as? PetDesktopScene {
            let scenePoint = scene.convertPoint(fromView: location)
            scene.handleMouseDragged(to: scenePoint)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let location = self.convert(event.locationInWindow, to: nil)
        if let scene = self.scene as? PetDesktopScene {
            let scenePoint = scene.convertPoint(fromView: location)
            scene.handleMouseUp(at: scenePoint)
        }
    }
}

@MainActor
final class PetPlaygroundService: ObservableObject {
    static let shared = PetPlaygroundService()

    @Published private(set) var isEnabled: Bool = false
    private var overlays: [NSPanel] = []
    private var hudPanels: [NSPanel] = []
    private var scenes: [PetDesktopScene] = []
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    private init() {}

    func initialize() {
        let settings = DependencyContainer.shared.settingsService.settings
        if settings.isPetPlaygroundEnabled {
            startPlayground()
        }
        PetTouchBarWindowManager.shared.updateTouchBarState(isEnabled: settings.isPetTouchBarEnabled)
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

    func reloadPets() {
        if isEnabled {
            installOverlays()
        }
    }

    func transferDraggedPet(_ petNode: PetNode, fromScene sourceScene: PetDesktopScene, toScreen destScreen: NSScreen, globalMouse: NSPoint) {
        guard let destScene = scenes.first(where: { $0.activeTargetScreen === destScreen }) else { return }
        sourceScene.removePetNode(petNode)
        
        let localX = globalMouse.x - destScreen.frame.minX
        let localY = globalMouse.y - destScreen.frame.minY
        
        petNode.position = CGPoint(x: localX, y: localY)
        petNode.zRotation = 0.0
        petNode.spriteNode.zRotation = 0.0
        petNode.isStateLocked = true
        petNode.isBeingDragged = true
        
        destScene.addPetNode(petNode)
        destScene.setDraggedPetNode(petNode, dragOffset: .zero)
    }

    func transferWalkingPet(_ petNode: PetNode, fromScene sourceScene: PetDesktopScene, toScreen destScreen: NSScreen, enteringLeftEdge: Bool) {
        guard let destScene = scenes.first(where: { $0.activeTargetScreen === destScreen }) else { return }
        sourceScene.removePetNode(petNode)

        let lane = Self.movementLane(for: destScreen)
        let groundY = DesktopWindowDetector.shared.dockTopY + 45.0
        let startX = enteringLeftEdge ? lane.minX + 25 : lane.maxX - 25

        petNode.position = CGPoint(x: startX, y: groundY)
        petNode.zRotation = 0.0
        petNode.spriteNode.zRotation = 0.0
        petNode.isStateLocked = false
        petNode.currentPetState = .onGround

        destScene.addPetNode(petNode)
    }

    private func startPlayground() {
        isEnabled = true
        PetPlaygroundEngine.shared.start()
        DesktopWindowDetector.shared.startScanning()
        AppleNeuralVisionDetector.shared.startScanning()
        installOverlays()
        startMouseMonitoring()
        LoggerService.shared.info("PetPlaygroundService started desktop pets overlay with Apple NPU Vision acceleration")
    }

    private func stopPlayground() {
        isEnabled = false
        PetPlaygroundEngine.shared.stop()
        DesktopWindowDetector.shared.stopScanning()
        AppleNeuralVisionDetector.shared.stopScanning()
        stopMouseMonitoring()
        removeOverlays()
        LoggerService.shared.info("PetPlaygroundService stopped desktop pets overlay")
    }

    private func startMouseMonitoring() {
        stopMouseMonitoring()

        let monitorBlock: (NSEvent) -> Void = { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isEnabled else { return }
                let mouseLocation = NSEvent.mouseLocation
                
                for (idx, panel) in self.overlays.enumerated() {
                    guard self.scenes.indices.contains(idx) else { continue }
                    let scene = self.scenes[idx]
                    let isNear = scene.isPetNear(screenPoint: mouseLocation)
                    let shouldCapture = isNear || scene.isDraggingPet
                    
                    if panel.ignoresMouseEvents != !shouldCapture {
                        panel.ignoresMouseEvents = !shouldCapture
                    }
                }
            }
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp], handler: monitorBlock)
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp]) { event in
            monitorBlock(event)
            return event
        }
    }

    private func stopMouseMonitoring() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    private func installOverlays() {
        removeOverlays()
        scenes.removeAll()

        let screens = NSScreen.screens
        let totalScreens = screens.count

        for (screenIndex, screen) in screens.enumerated() {
            let lane = Self.movementLane(for: screen)
            if let mainScreen = NSScreen.main, screen === mainScreen {
                PetPlaygroundEngine.shared.updateMovementLane(lane)
            }

            // 1. 全屏桌宠 Overlay 面板：默认 ignoresMouseEvents = true (100% 绝对物理穿透，鼠标靠近人物时动态激活拖拽)
            let petPanel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            petPanel.isOpaque = false
            petPanel.backgroundColor = .clear
            petPanel.level = .floating
            petPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            petPanel.ignoresMouseEvents = true
            petPanel.hasShadow = false
            petPanel.hidesOnDeactivate = false
            petPanel.isReleasedWhenClosed = false

            let skView = PetInteractiveSKView(frame: NSRect(origin: .zero, size: screen.frame.size))
            skView.allowsTransparency = true
            skView.wantsLayer = true
            skView.layer?.backgroundColor = NSColor.clear.cgColor
            skView.autoresizingMask = [.width, .height]
            skView.ignoresSiblingOrder = true

            let scene = PetDesktopScene(size: screen.frame.size)
            scene.setupScene(lane: lane, screen: screen, screenIndex: screenIndex, screenCount: totalScreens)
            skView.presentScene(scene)
            scenes.append(scene)

            petPanel.contentView = skView
            petPanel.setFrame(screen.frame, display: true)
            petPanel.orderFrontRegardless()
            overlays.append(petPanel)

            // 2. 右上角微型 NPU Telemetry 推理框面板：支持鼠标按住背景自由拖拽移动与交互穿透
            if screenIndex == 0 {
                let hudWidth: CGFloat = 440
                let hudHeight: CGFloat = 220
                let hudFrame = NSRect(
                    x: screen.frame.maxX - hudWidth - 20,
                    y: screen.frame.maxY - hudHeight - 35,
                    width: hudWidth,
                    height: hudHeight
                )
                let hudPanel = NSPanel(
                    contentRect: hudFrame,
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                hudPanel.isOpaque = false
                hudPanel.backgroundColor = .clear
                hudPanel.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)) + 1)
                hudPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
                hudPanel.ignoresMouseEvents = false
                hudPanel.isMovableByWindowBackground = true
                hudPanel.hasShadow = false
                hudPanel.hidesOnDeactivate = false
                hudPanel.isReleasedWhenClosed = false

                let containerView = NSView(frame: NSRect(origin: .zero, size: hudFrame.size))
                containerView.autoresizingMask = []
                
                let hostingView = NSHostingView(rootView: PetPlaygroundOverlayView())
                hostingView.frame = NSRect(origin: .zero, size: hudFrame.size)
                hostingView.autoresizingMask = [.width, .height]
                containerView.addSubview(hostingView)

                hudPanel.contentView = containerView
                hudPanel.setFrame(hudFrame, display: true)
                hudPanel.orderFrontRegardless()
                hudPanels.append(hudPanel)
            }
        }
    }

    private func removeOverlays() {
        stopMouseMonitoring()
        scenes.removeAll()
        overlays.forEach {
            $0.orderOut(nil)
            $0.close()
        }
        overlays.removeAll()

        hudPanels.forEach {
            $0.orderOut(nil)
            $0.close()
        }
        hudPanels.removeAll()
    }

    private static func movementLane(for screen: NSScreen) -> MovementLane {
        let frame = screen.frame
        let visible = screen.visibleFrame
        
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
            y: localVisible.minY + halfPet + margin
        )
    }
}
