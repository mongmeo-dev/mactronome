import XCTest
@testable import metronome

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
        // frames 0,5,10,15,20 에서 발화; 펄스 인덱스 0,1,2,3,0; 레벨 3,1,2,1,3
        XCTAssertEqual(events.map { $0.0 }, [0,5,10,15,20])
        XCTAssertEqual(events.map { $0.1 }, [0,1,2,3,0])
        XCTAssertEqual(events.map { $0.2 }, [3,1,2,1,3])
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
}
