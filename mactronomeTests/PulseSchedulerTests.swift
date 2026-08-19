import XCTest
@testable import mactronome

final class PulseSchedulerTests: XCTestCase {
    private func makeScheduler(grid: [[Int]], pulsesPerBeat: Int, framesPerBeat: Int) -> PulseScheduler {
        let s = PulseScheduler(sampleRate: 44100)
        s.grid.publish(PulsePlan(grid: grid, pulsesPerBeat: pulsesPerBeat))
        s.setFramesPerBeat(framesPerBeat)
        s.reset()
        return s
    }

    func test_firesOnFirstFrame_withFirstLevel() {
        let s = makeScheduler(grid: [[3],[1],[2],[1]], pulsesPerBeat: 1, framesPerBeat: 10)
        let tick = s.advanceOneFrame()
        XCTAssertTrue(tick.didFire)
        XCTAssertEqual(tick.pulseIndex, 0)
        XCTAssertEqual(tick.beatIndex, 0)
        XCTAssertEqual(tick.level, 3)
    }

    func test_pulsesPerBeat1_firesEveryFramesPerBeat() {
        let s = makeScheduler(grid: [[3],[1],[2],[1]], pulsesPerBeat: 1, framesPerBeat: 10)
        var fires: [Int] = []
        for f in 0..<41 {
            if s.advanceOneFrame().didFire { fires.append(f) }
        }
        XCTAssertEqual(fires, [0,10,20,30,40])
    }

    func test_subdivision2_firesEveryHalfBeat_withLevels() {
        // 2박자, 박자당 2펄스, framesPerBeat 10 -> framesPerPulse 5
        let s = makeScheduler(grid: [[3,1],[2,1]], pulsesPerBeat: 2, framesPerBeat: 10)
        var events: [(Int, Int, Int)] = [] // (frame, pulseIndex, level)
        for f in 0..<21 {
            let t = s.advanceOneFrame()
            if t.didFire { events.append((f, t.pulseIndex, t.level)) }
        }
        // frames 0,5,10,15,20 에서 발화; 각 박 안의 펄스 인덱스 0,1,0,1,0.
        XCTAssertEqual(events.map { $0.0 }, [0,5,10,15,20])
        XCTAssertEqual(events.map { $0.1 }, [0,1,0,1,0])
        XCTAssertEqual(events.map { $0.2 }, [3,1,2,1,3])
    }

    func test_pulseIndexResetsAtEveryBeatBoundary() {
        let s = makeScheduler(grid: [[3], [1], [2], [1]], pulsesPerBeat: 1, framesPerBeat: 1)
        var events: [(beat: Int, pulse: Int)] = []

        for _ in 0..<4 {
            let tick = s.advanceOneFrame()
            events.append((tick.beatIndex, tick.pulseIndex))
        }

        XCTAssertEqual(events.map(\.beat), [0, 1, 2, 3])
        XCTAssertEqual(events.map(\.pulse), [0, 0, 0, 0])
    }

    func test_beatIndexTracksBoundaries() {
        let s = makeScheduler(grid: [[3,1],[2,1]], pulsesPerBeat: 2, framesPerBeat: 10)
        var beats: [Int] = []
        for _ in 0..<20 {
            let t = s.advanceOneFrame()
            if t.didFire { beats.append(t.beatIndex) }
        }
        // 펄스 0,1 -> beat 0; 펄스 2,3 -> beat 1
        XCTAssertEqual(beats, [0,0,1,1])
    }

    // 재생 중 분할 변경이 "다음 박 경계"에서 반영되고, 현재 박은 옛 plan을 유지함을 검증.
    func test_planChange_appliesAtNextBeatBoundary_notMidBeat() {
        // 4박자, 박자당 1펄스, framesPerBeat 10 -> 박마다 1발화.
        let s = makeScheduler(grid: [[3],[1],[2],[1]], pulsesPerBeat: 1, framesPerBeat: 10)

        // beat0 발화(frame 0).
        var t = s.advanceOneFrame()
        XCTAssertTrue(t.didFire)
        XCTAssertEqual(t.beatIndex, 0)
        XCTAssertEqual(t.level, 3)

        // beat0 진행 중(펄스 사이)에 새 plan을 publish: 모든 박 레벨을 바꾼 새 grid.
        s.grid.publish(PulsePlan(grid: [[0],[0],[0],[0]], pulsesPerBeat: 1))

        // beat0 나머지 프레임(1..9)은 발화 없음 → 현재 박 값은 이미 확정(옛 plan 반영).
        for _ in 1..<10 { XCTAssertFalse(s.advanceOneFrame().didFire) }

        // 다음 박 경계(frame 10)에서 새 plan 반영: level 0.
        t = s.advanceOneFrame()
        XCTAssertTrue(t.didFire)
        XCTAssertEqual(t.beatIndex, 1)
        XCTAssertEqual(t.level, 0, "다음 박부터 새 plan이 즉시 반영되어야 함")
    }

    // 분할 수가 바뀌어도(1펄스 → 2펄스) 다음 박 경계부터 새 펄스 수로 재생됨을 검증.
    func test_planChange_changesSubdivisionAtNextBeat() {
        // 시작: 2박자, 박자당 1펄스, framesPerBeat 10.
        let s = makeScheduler(grid: [[3],[1]], pulsesPerBeat: 1, framesPerBeat: 10)

        _ = s.advanceOneFrame() // beat0 발화(frame 0), level 3

        // 박자당 2펄스로 분할 변경 publish.
        s.grid.publish(PulsePlan(grid: [[3,1],[2,1]], pulsesPerBeat: 2))

        for _ in 1..<10 { _ = s.advanceOneFrame() } // beat0 마무리

        // beat1 경계(frame 10)부터 새 plan: framesPerPulse=5 → 5프레임 간격으로 두 펄스.
        var fires: [(Int, Int)] = [] // (relativeFrame, level)
        for f in 0..<10 {
            let t = s.advanceOneFrame()
            if t.didFire { fires.append((f, t.level)) }
        }
        // frame 10(f=0): beat1 첫 펄스 level 2, frame 15(f=5): beat1 둘째 펄스 level 1.
        XCTAssertEqual(fires.map { $0.0 }, [0, 5])
        XCTAssertEqual(fires.map { $0.1 }, [2, 1])
    }
}
