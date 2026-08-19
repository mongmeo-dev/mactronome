import XCTest
@testable import mactronome

final class TapTempoTests: XCTestCase {
    func test_firstTap_returnsNil() {
        var tt = TapTempo()
        XCTAssertNil(tt.tap(at: 0.0))
    }

    func test_twoTaps_500ms_gives120bpm() {
        var tt = TapTempo()
        _ = tt.tap(at: 0.0)
        let bpm = tt.tap(at: 0.5) // 0.5s 간격 -> 120 BPM
        XCTAssertNotNil(bpm)
        XCTAssertEqual(bpm!, 120.0, accuracy: 0.01)
    }

    func test_evenTaps_average() {
        var tt = TapTempo()
        _ = tt.tap(at: 0.0)
        _ = tt.tap(at: 0.5)
        let bpm = tt.tap(at: 1.0) // 일정 0.5s 간격 -> 120 BPM
        XCTAssertEqual(bpm!, 120.0, accuracy: 0.01)
    }

    func test_gapOverTwoSeconds_resetsWindow() {
        var tt = TapTempo()
        _ = tt.tap(at: 0.0)
        _ = tt.tap(at: 0.5)
        // 2초 초과 공백 후 탭 -> 윈도우 리셋되어 nil
        XCTAssertNil(tt.tap(at: 3.0))
    }
}
