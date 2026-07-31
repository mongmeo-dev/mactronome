import XCTest
@testable import metronome

/// 스크롤 델타를 정수 스텝으로 바꾸는 누적기를 검증합니다.
/// 목표: 천천히 굴려도 반응이 사라지지 않고, 빠르게 굴려도 값이 튀지 않습니다.
final class StepAccumulatorTests: XCTestCase {

    /// 스텝에 못 미치는 입력은 아직 스텝을 만들지 않지만 버려지지도 않습니다.
    func test_smallDeltas_accumulateIntoOneStep() {
        var acc = StepAccumulator(pointsPerStep: 4)
        XCTAssertEqual(acc.consume(1), 0)
        XCTAssertEqual(acc.consume(1), 0)
        XCTAssertEqual(acc.consume(1), 0)
        XCTAssertEqual(acc.consume(1), 1, "잔여분이 쌓여 한 스텝이 되어야 합니다")
    }

    /// 큰 입력은 여러 스텝을 한 번에 냅니다.
    func test_largeDelta_yieldsMultipleSteps() {
        var acc = StepAccumulator(pointsPerStep: 4)
        XCTAssertEqual(acc.consume(14), 3)
        XCTAssertEqual(acc.remainder, 2, accuracy: 0.0001, "나머지는 이월되어야 합니다")
    }

    /// 음수 방향도 대칭으로 동작해야 합니다.
    func test_negativeDeltas_areSymmetric() {
        var acc = StepAccumulator(pointsPerStep: 4)
        XCTAssertEqual(acc.consume(-14), -3)
        XCTAssertEqual(acc.remainder, -2, accuracy: 0.0001)
    }

    /// 방향을 바꾸면 잔여분이 상쇄되어 값이 튀지 않아야 합니다.
    func test_reversingDirection_cancelsRemainder() {
        var acc = StepAccumulator(pointsPerStep: 4)
        XCTAssertEqual(acc.consume(3), 0)
        XCTAssertEqual(acc.consume(-3), 0, "3만큼 올렸다 내리면 순변화가 없어야 합니다")
        XCTAssertEqual(acc.remainder, 0, accuracy: 0.0001)
    }

    /// 누적 입력량과 총 스텝 수가 비례해야 합니다(장기 드리프트 없음).
    func test_totalSteps_matchTotalInput() {
        var acc = StepAccumulator(pointsPerStep: 4)
        var total: Double = 0
        for _ in 0..<100 { total += acc.consume(1.0) }
        XCTAssertEqual(total, 25, "100pt / 4pt = 25스텝")
    }

    /// reset 은 잔여분을 비웁니다.
    func test_reset_clearsRemainder() {
        var acc = StepAccumulator(pointsPerStep: 4)
        _ = acc.consume(3)
        acc.reset()
        XCTAssertEqual(acc.remainder, 0)
        XCTAssertEqual(acc.consume(3), 0, "리셋 후에는 처음부터 다시 쌓입니다")
    }

    /// 0 이하의 민감도가 들어와도 나눗셈이 발산하면 안 됩니다.
    func test_degenerateStepSize_isClamped() {
        var acc = StepAccumulator(pointsPerStep: 0)
        XCTAssertGreaterThan(acc.pointsPerStep, 0)
        XCTAssertTrue(acc.consume(1).isFinite)
    }

    /// NaN/무한 델타는 무시해야 합니다(트랙패드 이벤트 방어).
    func test_nonFiniteDelta_isIgnored() {
        var acc = StepAccumulator(pointsPerStep: 4)
        XCTAssertEqual(acc.consume(.nan), 0)
        XCTAssertEqual(acc.consume(.infinity), 0)
        XCTAssertEqual(acc.remainder, 0)
    }
}
