import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

final class PetEngine: ObservableObject {
    static let shared = PetEngine()
    static let updateInterval: TimeInterval = 1.0 / 60.0

    @Published private(set) var pets: [Pet] = []
    @Published var isPaused = false

    private let characters: [PetCharacter]
    private var lane: MovementLane
    private var timer: Timer?
    private var previousTick = Date()

    var isRunning: Bool { timer != nil }

    private init() {
        characters = PetCharacter.all
        lane = Self.defaultLane()
        resetPets()
    }

    init(testingIn lane: MovementLane, characters: [PetCharacter] = PetCharacter.all) {
        self.characters = characters
        self.lane = lane
        resetPets()
    }

    func start() {
        guard timer == nil else { return }
        previousTick = Date()
        let timer = Timer(timeInterval: Self.updateInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func updateMovementLane(_ value: MovementLane) {
        guard value.maxX > value.minX, value.y > 0 else { return }
        lane = value
        guard !pets.isEmpty else {
            resetPets()
            return
        }
        for index in pets.indices {
            pets[index].position.x = min(max(pets[index].position.x, lane.minX), lane.maxX)
            pets[index].position.y = lane.y
        }
    }

    func resetPets() {
        let width = max(lane.maxX - lane.minX, 0)
        pets = characters.map { character in
            Pet(
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
    }

    func advance(by rawDelta: TimeInterval) {
        guard !isPaused else { return }
        let delta = min(max(rawDelta, 0), 0.05)
        guard delta > 0 else { return }

        for index in pets.indices {
            var pet = pets[index]
            let direction: CGFloat = pet.facingRight ? 1 : -1
            var nextX = pet.position.x + pet.character.speed * direction * delta

            if nextX >= lane.maxX {
                nextX = lane.maxX
                pet.facingRight = false
            } else if nextX <= lane.minX {
                nextX = lane.minX
                pet.facingRight = true
            }

            pet.position = CGPoint(x: nextX, y: lane.y)
            pet.frameAccumulator += delta * pet.character.framesPerSecond
            while pet.frameAccumulator >= 1.0 - 0.000_000_1 {
                pet.frameAccumulator = max(0, pet.frameAccumulator - 1)
                pet.frameIndex = (pet.frameIndex + 1) % max(pet.character.frameNames.count, 1)
            }
            pets[index] = pet
        }
    }

    private func tick() {
        let now = Date()
        let delta = now.timeIntervalSince(previousTick)
        previousTick = now
        advance(by: delta)
    }

    private static func defaultLane() -> MovementLane {
        #if os(macOS)
        let size = NSScreen.main?.frame.size ?? CGSize(width: 1200, height: 800)
        #else
        let size = UIScreen.main.bounds.size
        #endif
        let halfPet: CGFloat = 75
        let margin: CGFloat = 12
        return MovementLane(
            minX: halfPet + margin,
            maxX: max(halfPet + margin, size.width - halfPet - margin),
            y: max(halfPet + margin, size.height - halfPet - margin)
        )
    }
}
