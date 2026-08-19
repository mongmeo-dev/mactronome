import XCTest
@testable import mactronome

final class PolyVoiceTests: XCTestCase {

    private func firePositions(_ voice: PolyVoice, frames: Int) -> [Int] {
        var fires: [Int] = []
        for f in 0..<frames {
            if voice.advanceOneFrame() { fires.append(f) }
        }
        return fires
    }

    func test_disabledWhenCountBelowTwo() {
        let v = PolyVoice()
        v.setFramesPerBar(1200)
        v.setPulseCount(0)
        v.reset()
        XCTAssertEqual(firePositions(v, frames: 1200), [])
        v.setPulseCount(1)
        v.reset()
        XCTAssertEqual(firePositions(v, frames: 1200), [])
    }

    func test_threeOverBar_evenlySpaced() {
        let v = PolyVoice()
        v.setFramesPerBar(1200)
        v.setPulseCount(3)
        v.reset()
        // 첫 마디: 0, 400, 800. 다음 마디 시작: 1200.
        XCTAssertEqual(firePositions(v, frames: 1201), [0, 400, 800, 1200])
    }

    func test_exactlyKFiresPerBar_forNonDivisible() {
        // 1000프레임을 3으로 나눠도 마디당 정확히 3회 발화(재정렬로 드리프트 없음).
        let v = PolyVoice()
        v.setFramesPerBar(1000)
        v.setPulseCount(3)
        v.reset()
        let fires = firePositions(v, frames: 1000 * 10)
        XCTAssertEqual(fires.count, 30) // 10마디 × 3
        // 각 마디의 첫 발화는 정확히 마디 경계(0,1000,2000,...) → 주 보이스와 고정.
        for bar in 0..<10 {
            XCTAssertTrue(fires.contains(bar * 1000), "마디 \(bar) 다운비트 누락")
        }
    }

    func test_fourOverBar_positions() {
        let v = PolyVoice()
        v.setFramesPerBar(800)
        v.setPulseCount(4)
        v.reset()
        XCTAssertEqual(firePositions(v, frames: 800), [0, 200, 400, 600])
    }
}
