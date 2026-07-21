import XCTest
@testable import metronome

final class BeatEventTests: XCTestCase {
    func test_initialSnapshot_hasZeroSequence() {
        let channel = BeatEventChannel()
        XCTAssertEqual(channel.latest().sequence, 0)
    }

    func test_publish_incrementsSequence_andCarriesData() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 2, isAccent: false)
        let snap = channel.latest()
        XCTAssertEqual(snap.sequence, 1)
        XCTAssertEqual(snap.beatIndex, 2)
        XCTAssertFalse(snap.isAccent)
    }

    func test_publish_accent_roundTrips() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 0, isAccent: true)
        let snap = channel.latest()
        XCTAssertEqual(snap.beatIndex, 0)
        XCTAssertTrue(snap.isAccent)
    }

    func test_multiplePublishes_sequenceMonotonic() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 0, isAccent: true)
        channel.publish(beatIndex: 1, isAccent: false)
        channel.publish(beatIndex: 2, isAccent: false)
        XCTAssertEqual(channel.latest().sequence, 3)
        XCTAssertEqual(channel.latest().beatIndex, 2)
    }
}
