import CoreGraphics
import Foundation

struct MovementLane: Equatable {
    var minX: CGFloat
    var maxX: CGFloat
    var y: CGFloat
}

struct PetCharacter: Identifiable, Equatable {
    let id: String
    let displayName: String
    let frameNames: [String]
    let initialFraction: CGFloat
    let speed: CGFloat
    let framesPerSecond: Double
    let initialFrame: Int
    let startsFacingRight: Bool

    static let all: [PetCharacter] = [
        make(id: "blue", displayName: "浅蓝队员", initialFraction: 0.08,
             speed: 46, framesPerSecond: 7.0, initialFrame: 0, startsFacingRight: true),
        make(id: "gray", displayName: "深灰队员", initialFraction: 0.34,
             speed: 59, framesPerSecond: 8.2, initialFrame: 2, startsFacingRight: false),
        make(id: "white", displayName: "白衣队员", initialFraction: 0.62,
             speed: 53, framesPerSecond: 7.6, initialFrame: 4, startsFacingRight: true),
        make(id: "tall", displayName: "浅灰队员", initialFraction: 0.86,
             speed: 66, framesPerSecond: 8.6, initialFrame: 1, startsFacingRight: false)
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

struct Pet: Identifiable, Equatable {
    var id: String { character.id }
    let character: PetCharacter
    var position: CGPoint
    var facingRight: Bool
    var frameIndex: Int
    var frameAccumulator: Double
}
