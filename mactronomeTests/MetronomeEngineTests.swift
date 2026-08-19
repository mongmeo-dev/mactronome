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
}
