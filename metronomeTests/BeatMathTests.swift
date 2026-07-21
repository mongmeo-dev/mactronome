import XCTest
@testable import metronome

final class BeatMathTests: XCTestCase {
    func test_120bpm_at_44100() {
        XCTAssertEqual(framesPerBeat(bpm: 120, sampleRate: 44100), 22050)
    }

    func test_60bpm_at_44100() {
        XCTAssertEqual(framesPerBeat(bpm: 60, sampleRate: 44100), 44100)
    }

    func test_100bpm_at_48000_rounds() {
        // 48000 * 60 / 100 = 28800
        XCTAssertEqual(framesPerBeat(bpm: 100, sampleRate: 48000), 28800)
    }

    func test_fractional_rounds_to_nearest() {
        // 44100 * 60 / 130 = 20353.84... -> 20354
        XCTAssertEqual(framesPerBeat(bpm: 130, sampleRate: 44100), 20354)
    }
}
