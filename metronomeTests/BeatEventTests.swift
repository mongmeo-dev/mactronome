import XCTest
@testable import metronome

final class BeatEventTests: XCTestCase {
    func test_initialSnapshot_hasZeroSequence() {
        let channel = BeatEventChannel()
        XCTAssertEqual(channel.latest().sequence, 0)
    }

    func test_publish_incrementsSequence_andCarriesData() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 2, pulseIndex: 5, isAccent: false)
        let snap = channel.latest()
        XCTAssertEqual(snap.sequence, 1)
        XCTAssertEqual(snap.beatIndex, 2)
        XCTAssertEqual(snap.pulseIndex, 5)
        XCTAssertFalse(snap.isAccent)
    }

    func test_publish_accent_roundTrips() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 0, pulseIndex: 0, isAccent: true)
        let snap = channel.latest()
        XCTAssertEqual(snap.beatIndex, 0)
        XCTAssertEqual(snap.pulseIndex, 0)
        XCTAssertTrue(snap.isAccent)
    }

    func test_multiplePublishes_sequenceMonotonic() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 0, pulseIndex: 0, isAccent: true)
        channel.publish(beatIndex: 1, pulseIndex: 2, isAccent: false)
        channel.publish(beatIndex: 2, pulseIndex: 7, isAccent: false)
        XCTAssertEqual(channel.latest().sequence, 3)
        XCTAssertEqual(channel.latest().beatIndex, 2)
        XCTAssertEqual(channel.latest().pulseIndex, 7)
    }

    func test_publish_maxBoundaryValues_roundTrip() {
        let channel = BeatEventChannel()
        // beatIndex 16비트 최대, pulseIndex 8비트 최대
        channel.publish(beatIndex: 0xFFFF, pulseIndex: 0xFF, isAccent: true)
        let snap = channel.latest()
        XCTAssertEqual(snap.beatIndex, 0xFFFF)
        XCTAssertEqual(snap.pulseIndex, 0xFF)
        XCTAssertTrue(snap.isAccent)
    }

    func test_fields_doNotBleed_acrossBitBoundaries() {
        let channel = BeatEventChannel()
        // beatIndex는 최대, pulseIndex는 0, accent false → 인접 필드 침범 없어야 함
        channel.publish(beatIndex: 0xFFFF, pulseIndex: 0, isAccent: false)
        let snap = channel.latest()
        XCTAssertEqual(snap.beatIndex, 0xFFFF)
        XCTAssertEqual(snap.pulseIndex, 0)
        XCTAssertFalse(snap.isAccent)
    }
}
