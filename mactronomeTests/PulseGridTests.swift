import XCTest
@testable import mactronome

final class PulseGridTests: XCTestCase {
    func test_pulsePlan_flattensGrid() {
        // grid [[3],[1],[2],[1]], pulsesPerBeat 1
        let plan = PulsePlan(grid: [[3],[1],[2],[1]], pulsesPerBeat: 1)
        XCTAssertEqual(plan.levels, [3,1,2,1])
        XCTAssertEqual(plan.beatBoundaries, [0,1,2,3])
        XCTAssertEqual(plan.pulseCount, 4)
    }

    func test_pulsePlan_subdivided() {
        // 2 beats, pulsesPerBeat 2
        let plan = PulsePlan(grid: [[3,1],[2,1]], pulsesPerBeat: 2)
        XCTAssertEqual(plan.levels, [3,1,2,1])
        XCTAssertEqual(plan.beatBoundaries, [0,0,1,1])
        XCTAssertEqual(plan.pulseCount, 4)
    }

    func test_channel_publishThenCurrent() {
        let ch = PulseGridChannel()
        let plan = PulsePlan(grid: [[3],[1]], pulsesPerBeat: 1)
        ch.publish(plan)
        let got = ch.current()
        XCTAssertEqual(got.levels, [3,1])
    }

    func test_channel_defaultIsNonEmpty() {
        let ch = PulseGridChannel()
        // 기본값은 최소 1펄스(무음 아님) 이어야 크래시 없음
        XCTAssertGreaterThan(ch.current().pulseCount, 0)
    }
}
