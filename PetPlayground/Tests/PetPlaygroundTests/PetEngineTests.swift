@testable import PetPlayground
import XCTest

final class PetEngineTests: XCTestCase {
    private let lane = MovementLane(minX: 75, maxX: 1125, y: 700)

    func testPetsAdvanceAtIndependentSpeeds() {
        let engine = PetEngine(testingIn: lane)
        let before = engine.pets

        engine.advance(by: 0.05)

        XCTAssertEqual(engine.pets.count, 4)
        let firstDistance = abs(engine.pets[0].position.x - before[0].position.x)
        let secondDistance = abs(engine.pets[1].position.x - before[1].position.x)
        XCTAssertNotEqual(firstDistance, secondDistance)
    }

    func testPetsAdvanceFramesAtIndependentRates() {
        let slow = makeCharacter(id: "slow", framesPerSecond: 2)
        let fast = makeCharacter(id: "fast", framesPerSecond: 8)
        let engine = PetEngine(testingIn: lane, characters: [slow, fast])

        for _ in 0..<10 {
            engine.advance(by: 0.05)
        }

        XCTAssertEqual(engine.pets[0].frameIndex, 1)
        XCTAssertEqual(engine.pets[1].frameIndex, 4)
    }

    func testPetReversesAtHorizontalEdge() {
        let narrowLane = MovementLane(minX: 75, maxX: 76, y: 700)
        let engine = PetEngine(testingIn: narrowLane)

        engine.advance(by: 0.05)

        XCTAssertTrue(engine.pets.allSatisfy { (75...76).contains($0.position.x) })
        XCTAssertFalse(engine.pets[0].facingRight)
    }

    func testPauseFreezesMovementAndFrames() {
        let engine = PetEngine(testingIn: lane)
        engine.isPaused = true
        let before = engine.pets

        engine.advance(by: 0.05)

        XCTAssertEqual(engine.pets, before)
    }

    func testRegroupUsesDistinctConfiguredPositions() {
        let engine = PetEngine(testingIn: lane)

        engine.advance(by: 0.05)
        engine.resetPets()

        XCTAssertEqual(Set(engine.pets.map { $0.position.x }).count, 4)
        XCTAssertTrue(engine.pets.allSatisfy { $0.position.y == lane.y })
        XCTAssertEqual(engine.pets.map(\.frameIndex), [0, 2, 4, 1])
    }

    func testAllAnimationFramesAreBundled() {
        let frameNames = PetCharacter.all.flatMap(\.frameNames)

        XCTAssertEqual(frameNames.count, 24)
        for frameName in frameNames {
            XCTAssertNotNil(
                Bundle.module.url(forResource: frameName, withExtension: "png"),
                "Missing animation frame: \(frameName).png"
            )
        }
    }

    func testSpriteFacesItsMovementDirection() {
        XCTAssertEqual(PetSprite.horizontalScale(facingRight: true), -1)
        XCTAssertEqual(PetSprite.horizontalScale(facingRight: false), 1)
    }

    func testEngineUsesSixtyHertzUpdatesAndStopIsIdempotent() {
        let engine = PetEngine(testingIn: lane)

        XCTAssertEqual(PetEngine.updateInterval, 1.0 / 60.0, accuracy: 0.000_001)
        engine.start()
        XCTAssertTrue(engine.isRunning)
        engine.stop()
        engine.stop()
        XCTAssertFalse(engine.isRunning)
    }

    private func makeCharacter(id: String, framesPerSecond: Double) -> PetCharacter {
        PetCharacter(
            id: id,
            displayName: id,
            frameNames: (0..<6).map { "\(id)_\($0)" },
            initialFraction: 0.5,
            speed: 50,
            framesPerSecond: framesPerSecond,
            initialFrame: 0,
            startsFacingRight: true
        )
    }
}
