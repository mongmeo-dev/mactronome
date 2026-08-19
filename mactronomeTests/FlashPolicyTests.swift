import XCTest
@testable import mactronome

/// 전체 화면 비주얼 플래시의 점멸률 제한을 검증합니다.
/// 목표: 어떤 BPM/분할 조합에서도 초당 3회를 넘지 않습니다(WCAG 2.3.1).
final class FlashPolicyTests: XCTestCase {

    // MARK: - 박 단위 게이팅

    /// 분할 펄스(박의 첫 펄스가 아님)에서는 절대 점멸하지 않습니다.
    func test_subPulse_neverFlashes() {
        var policy = FlashPolicy()
        XCTAssertFalse(policy.shouldFlash(at: 0, isBeatStart: false))
        XCTAssertFalse(policy.shouldFlash(at: 10, isBeatStart: false))
        XCTAssertNil(policy.lastFlashTime, "거부된 펄스는 시각을 갱신하지 않아야 합니다")
    }

    /// 첫 박은 항상 점멸합니다.
    func test_firstBeat_flashes() {
        var policy = FlashPolicy()
        XCTAssertTrue(policy.shouldFlash(at: 100, isBeatStart: true))
        XCTAssertEqual(policy.lastFlashTime, 100)
    }

    // MARK: - 최소 간격

    /// 최소 간격보다 빨리 들어온 박은 건너뜁니다.
    func test_tooSoon_isSkipped() {
        var policy = FlashPolicy()
        XCTAssertTrue(policy.shouldFlash(at: 0, isBeatStart: true))
        XCTAssertFalse(policy.shouldFlash(at: 0.2, isBeatStart: true))
        XCTAssertEqual(policy.lastFlashTime, 0, "거부 시 마지막 점멸 시각은 유지되어야 합니다")
    }

    /// 최소 간격이 지나면 다시 점멸합니다.
    func test_afterInterval_flashesAgain() {
        var policy = FlashPolicy()
        XCTAssertTrue(policy.shouldFlash(at: 0, isBeatStart: true))
        XCTAssertTrue(policy.shouldFlash(at: FlashPolicy.minimumInterval, isBeatStart: true))
    }

    /// 최대 BPM(300) × 최대 분할(6잇단)에서도 실제 점멸이 초당 3회를 넘지 않아야 합니다.
    /// 과거 구현은 이 조건에서 초당 30회 전체 화면 점멸을 냈습니다.
    func test_worstCase_staysUnderThreePerSecond() {
        var policy = FlashPolicy()
        let bpm = 300.0
        let pulsesPerBeat = 6
        let pulseInterval = 60.0 / bpm / Double(pulsesPerBeat)

        var flashes: [TimeInterval] = []
        // 10초 동안의 모든 펄스를 흘려보냅니다.
        let pulseCount = Int(10.0 / pulseInterval)
        for i in 0..<pulseCount {
            let time = Double(i) * pulseInterval
            let isBeatStart = i % pulsesPerBeat == 0
            if policy.shouldFlash(at: time, isBeatStart: isBeatStart) {
                flashes.append(time)
            }
        }

        XCTAssertFalse(flashes.isEmpty, "고 BPM 에서도 점멸은 나와야 합니다")
        // 임의의 1초 창에서 3회를 넘지 않는지 확인합니다.
        for start in flashes {
            let inWindow = flashes.filter { $0 >= start && $0 < start + 1.0 }.count
            XCTAssertLessThanOrEqual(inWindow, 3,
                                     "1초 안에 \(inWindow)회 점멸했습니다(최대 3회)")
        }
    }

    /// 일반적인 템포(120 BPM 4/4)에서는 매 박마다 그대로 점멸해야 합니다.
    /// 제한이 과하게 걸려 피드백이 사라지면 안 됩니다.
    func test_normalTempo_flashesEveryBeat() {
        var policy = FlashPolicy()
        let beatInterval = 60.0 / 120.0 // 0.5초
        var flashes = 0
        for i in 0..<8 {
            if policy.shouldFlash(at: Double(i) * beatInterval, isBeatStart: true) {
                flashes += 1
            }
        }
        XCTAssertEqual(flashes, 8, "120 BPM 에서는 모든 박이 점멸해야 합니다")
    }

    /// reset 후에는 간격과 무관하게 즉시 점멸합니다(재생 재시작).
    func test_reset_allowsImmediateFlash() {
        var policy = FlashPolicy()
        XCTAssertTrue(policy.shouldFlash(at: 0, isBeatStart: true))
        policy.reset()
        XCTAssertNil(policy.lastFlashTime)
        XCTAssertTrue(policy.shouldFlash(at: 0.01, isBeatStart: true))
    }

    // MARK: - 모션 감소

    /// 모션 감소가 켜지면 강박/약박 구분 없이 낮은 불투명도로 눌러야 합니다.
    func test_reduceMotion_lowersPeakOpacity() {
        let normalAccent = FlashPolicy.peakOpacity(isAccent: true, reduceMotion: false)
        let reducedAccent = FlashPolicy.peakOpacity(isAccent: true, reduceMotion: true)
        let reducedWeak = FlashPolicy.peakOpacity(isAccent: false, reduceMotion: true)

        XCTAssertLessThan(reducedAccent, normalAccent)
        XCTAssertEqual(reducedAccent, reducedWeak, "모션 감소 시에는 강약 대비를 없앱니다")
    }

    /// 모션 감소 시 페이드는 더 완만해야 합니다.
    func test_reduceMotion_slowsFade() {
        XCTAssertGreaterThan(FlashPolicy.fadeDuration(reduceMotion: true),
                             FlashPolicy.fadeDuration(reduceMotion: false))
    }

    /// 강박은 약박보다 밝아야 합니다(기본 동작 유지).
    func test_accentIsBrighterThanWeak() {
        XCTAssertGreaterThan(FlashPolicy.peakOpacity(isAccent: true, reduceMotion: false),
                             FlashPolicy.peakOpacity(isAccent: false, reduceMotion: false))
    }
}
