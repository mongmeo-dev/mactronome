import XCTest
@testable import mactronome

final class MetronomeEngineTests: XCTestCase {
    func test_initialState_notRunning() {
        XCTAssertFalse(MetronomeEngine().isRunning)
    }
    func test_startThenStop_togglesRunning() throws {
        let e = MetronomeEngine()
        defer { e.shutdown() }
        try e.start()
        XCTAssertTrue(e.isRunning)
        e.stop()
        XCTAssertFalse(e.isRunning)
    }
    func test_updateGrid_whileStopped_doesNotCrash() {
        let e = MetronomeEngine()
        e.updateGrid([[3],[1],[2],[1]], pulsesPerBeat: 1)
        XCTAssertFalse(e.isRunning)
    }
    func test_configurationChange_keepsAlive() throws {
        let e = MetronomeEngine()
        defer { e.shutdown() }
        e.updateBPM(150)
        try e.start()
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: nil)
        e.stop()
        XCTAssertFalse(e.isRunning)
    }

    func test_playbackPublishesEveryBeatIndex() throws {
        let e = MetronomeEngine()
        defer { e.shutdown() }
        e.updateBPM(300)
        e.updateGrid([[3], [1], [2], [1]], pulsesPerBeat: 1)
        try e.start()

        let deadline = Date().addingTimeInterval(1.2)
        var observedBeats = Set<Int>()
        var lastSequence: UInt64 = 0
        while Date() < deadline, observedBeats.count < 4 {
            let snapshot = e.beatChannel.latest()
            if snapshot.sequence != lastSequence {
                lastSequence = snapshot.sequence
                observedBeats.insert(snapshot.beatIndex)
            }
            Thread.sleep(forTimeInterval: 0.01)
        }

        XCTAssertEqual(observedBeats, Set(0..<4))
    }
}
