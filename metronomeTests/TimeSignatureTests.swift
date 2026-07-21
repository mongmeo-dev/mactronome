// metronomeTests/TimeSignatureTests.swift
import XCTest
@testable import metronome

final class TimeSignatureTests: XCTestCase {
    func test_fourFour_firstBeatIsAccent() {
        let ts = TimeSignature.fourFour
        XCTAssertTrue(ts.isAccent(beatIndex: 0))
        XCTAssertFalse(ts.isAccent(beatIndex: 1))
        XCTAssertFalse(ts.isAccent(beatIndex: 2))
        XCTAssertFalse(ts.isAccent(beatIndex: 3))
    }

    func test_threeFour_hasThreeBeats() {
        XCTAssertEqual(TimeSignature.threeFour.beatsPerBar, 3)
    }

    func test_beatIndex_wraps_conceptually_only_first_is_accent() {
        let ts = TimeSignature.fourFour
        // 인덱스는 항상 0..<beatsPerBar 범위로 스케줄러가 전달한다.
        XCTAssertTrue(ts.isAccent(beatIndex: 0))
    }

    func test_noteValues_areStandardDenominators() {
        XCTAssertEqual(TimeSignature.noteValues, [2, 4, 8, 16])
    }
    func test_withNoteValue_changesDenominatorOnly() {
        let ts = TimeSignature(beatsPerBar: 4, noteValue: 4).withNoteValue(8)
        XCTAssertEqual(ts.beatsPerBar, 4)
        XCTAssertEqual(ts.noteValue, 8)
    }
}
