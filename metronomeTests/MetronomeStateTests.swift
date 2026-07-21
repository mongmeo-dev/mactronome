import XCTest
@testable import metronome

@MainActor
final class MetronomeStateTests: XCTestCase {
    func test_defaultGrid_matchesSpec() {
        let state = MetronomeState()
        XCTAssertEqual(state.grid, [[.strong], [.weak], [.medium], [.weak]])
    }

    func test_defaultBPM_is120() {
        let state = MetronomeState()
        XCTAssertEqual(state.bpm, 120)
    }

    func test_setBPM_clampsToLowerBound() {
        let state = MetronomeState()
        state.setBPM(10)
        XCTAssertEqual(state.bpm, 30)
    }

    func test_setBPM_clampsToUpperBound() {
        let state = MetronomeState()
        state.setBPM(1000)
        XCTAssertEqual(state.bpm, 300)
    }

    func test_togglePlay_flipsIsPlaying_startThenStop() {
        let state = MetronomeState()
        XCTAssertFalse(state.isPlaying)
        state.togglePlay()
        XCTAssertTrue(state.isPlaying)
        state.togglePlay()
        XCTAssertFalse(state.isPlaying)
    }

    func test_cycleCell_strongWrapsToMute() {
        let state = MetronomeState()
        // grid[0][0] starts as .strong (rawValue 3)
        state.cycleCell(beat: 0, pulse: 0)
        XCTAssertEqual(state.grid[0][0], .mute)
    }

    func test_cycleCell_weakAdvancesToMedium() {
        let state = MetronomeState()
        // grid[1][0] starts as .weak (rawValue 1)
        state.cycleCell(beat: 1, pulse: 0)
        XCTAssertEqual(state.grid[1][0], .medium)
    }

    func test_addBeat_appendsRowOfWeak_withPulsesPerBeatCount() {
        let state = MetronomeState()
        let beforeCount = state.grid.count
        state.addBeat()
        XCTAssertEqual(state.grid.count, beforeCount + 1)
        XCTAssertEqual(state.grid.last, Array(repeating: .weak, count: state.pulsesPerBeat))
    }

    func test_addBeat_stopsAt12() {
        let state = MetronomeState()
        for _ in 0..<20 {
            state.addBeat()
        }
        XCTAssertEqual(state.grid.count, 12)
    }

    func test_removeBeat_removesLastRow() {
        let state = MetronomeState()
        state.addBeat()
        let beforeCount = state.grid.count
        state.removeBeat()
        XCTAssertEqual(state.grid.count, beforeCount - 1)
    }

    func test_removeBeat_stopsAt1() {
        let state = MetronomeState()
        for _ in 0..<20 {
            state.removeBeat()
        }
        XCTAssertEqual(state.grid.count, 1)
    }

    func test_setSubdivision_resizesRows_padWithWeak_preservingPrefix() {
        let state = MetronomeState()
        // default grid rows are length 1: [.strong],[.weak],[.medium],[.weak]
        state.setSubdivision(1) // subCounts[1] == 2
        XCTAssertEqual(state.subIdx, 1)
        XCTAssertEqual(state.pulsesPerBeat, 2)
        XCTAssertEqual(state.grid, [
            [.strong, .weak],
            [.weak, .weak],
            [.medium, .weak],
            [.weak, .weak],
        ])
    }

    func test_setSubdivision_slicesLongerRows() {
        let state = MetronomeState()
        state.setSubdivision(2) // subCounts[2] == 4
        XCTAssertEqual(state.pulsesPerBeat, 4)
        state.setSubdivision(0) // subCounts[0] == 1, slice back down
        XCTAssertEqual(state.pulsesPerBeat, 1)
        XCTAssertEqual(state.grid, [[.strong], [.weak], [.medium], [.weak]])
    }

    func test_tapForTesting_twoTaps_halfSecondApart_givesApprox120BPM() {
        let state = MetronomeState()
        state.setBPM(60) // start away from 120 to prove tap changed it
        _ = state.tapForTesting(at: 0.0)
        _ = state.tapForTesting(at: 0.5)
        XCTAssertEqual(state.bpm, 120.0, accuracy: 1.0)
    }

    func test_updateGrid_propagation_doesNotCrashWhileStopped() {
        let state = MetronomeState()
        XCTAssertFalse(state.isPlaying)
        state.addBeat()
        state.setSubdivision(2)
        state.setBPM(140)
        // No crash expected; engine updates are no-ops on audio output while stopped.
    }
}
