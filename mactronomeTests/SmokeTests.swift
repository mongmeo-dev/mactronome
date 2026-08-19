// metronomeTests/SmokeTests.swift
import XCTest
import Atomics
@testable import mactronome

final class SmokeTests: XCTestCase {
    func test_atomicsIsLinked() {
        let value = ManagedAtomic<Int>(0)
        value.store(42, ordering: .relaxed)
        XCTAssertEqual(value.load(ordering: .relaxed), 42)
    }
}
