import XCTest
@testable import metronome

final class BeatSchedulerTests: XCTestCase {
    func test_firesOnFirstFrame_asAccent() {
        let s = BeatScheduler(sampleRate: 44100)
        s.setFramesPerBeat(10)
        s.setBeatsPerBar(4)
        s.reset()
        let tick = s.advanceOneFrame()
        XCTAssertTrue(tick.didFire)
        XCTAssertEqual(tick.beatIndex, 0)
        XCTAssertTrue(tick.isAccent)
    }

    func test_firesEveryFramesPerBeat() {
        let s = BeatScheduler(sampleRate: 44100)
        s.setFramesPerBeat(10)
        s.setBeatsPerBar(4)
        s.reset()

        var fireFrames: [Int] = []
        for frame in 0..<41 {
            let tick = s.advanceOneFrame()
            if tick.didFire { fireFrames.append(frame) }
        }
        // 0, 10, 20, 30, 40 프레임에서 발화
        XCTAssertEqual(fireFrames, [0, 10, 20, 30, 40])
    }

    func test_beatIndexWrapsPerBar_accentOnlyOnFirst() {
        let s = BeatScheduler(sampleRate: 44100)
        s.setFramesPerBeat(10)
        s.setBeatsPerBar(4)
        s.reset()

        var fires: [(Int, Bool)] = []
        for _ in 0..<41 {
            let tick = s.advanceOneFrame()
            if tick.didFire { fires.append((tick.beatIndex, tick.isAccent)) }
        }
        // 인덱스: 0,1,2,3,0 / accent: true,false,false,false,true
        XCTAssertEqual(fires.map { $0.0 }, [0, 1, 2, 3, 0])
        XCTAssertEqual(fires.map { $0.1 }, [true, false, false, false, true])
    }

    func test_bpmChangeAppliesAtNextBeatBoundary() {
        let s = BeatScheduler(sampleRate: 44100)
        s.setFramesPerBeat(10)
        s.setBeatsPerBar(4)
        s.reset()

        // 첫 5프레임 진행 (박자 진행 중)
        for _ in 0..<5 { _ = s.advanceOneFrame() }
        // 진행 중 변경 -> 현재 박자는 유지, 다음 경계부터 반영
        s.setFramesPerBeat(20)

        var fireFrames: [Int] = []
        // frame 5부터 이어서: 다음 발화는 원래 간격(10)의 경계인 frame 10
        for frame in 5..<51 {
            let tick = s.advanceOneFrame()
            if tick.didFire { fireFrames.append(frame) }
        }
        // frame 10에서 발화(기존 간격 유지), 이후 20 간격 -> 30, 50
        XCTAssertEqual(fireFrames, [10, 30, 50])
    }
}
