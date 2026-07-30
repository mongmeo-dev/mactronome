import XCTest
import SwiftUI
@testable import metronome

/// AccentBarsView 의 폭 계산/줄바꿈 판정 로직(순수 함수)을 검증합니다.
/// 목표: 6잇단(pulses=6)에서 한 줄 폭이 가용 폭을 넘어 레이아웃이 깨지지 않고,
///       넘칠 때만 그룹 2개씩 줄바꿈으로 전환되는지 회귀 방지합니다.
final class AccentBarsLayoutTests: XCTestCase {

    // MARK: - groupWidth

    /// pulses=1(4분음표)이면 메인 바 1개 + 좌우 padding 만큼입니다. (28 + 12)
    func test_groupWidth_singlePulse() {
        XCTAssertEqual(AccentBarsView.groupWidth(pulses: 1), 40, accuracy: 0.001)
    }

    /// pulses=6(6잇단): 28 + 11×5 + 4×5 + 12 = 115.
    func test_groupWidth_sextuplet() {
        XCTAssertEqual(AccentBarsView.groupWidth(pulses: 6), 115, accuracy: 0.001)
    }

    /// pulses 가 0이어도 안전하게 padding 폭을 반환합니다(음수 방지).
    func test_groupWidth_zeroPulseIsSafe() {
        XCTAssertEqual(AccentBarsView.groupWidth(pulses: 0),
                       AccentBarsView.groupHorizontalPadding, accuracy: 0.001)
    }

    // MARK: - overflowsSingleRow

    /// 4분음표(pulses=1) 4박자는 한 줄에 넉넉히 들어갑니다 → 넘치지 않음.
    func test_singleRow_quarterNoteFourBeats_fits() {
        XCTAssertFalse(AccentBarsView.overflowsSingleRow(beatCount: 4, pulses: 1))
    }

    /// 16분음표(pulses=4) 4박자까지는 기존처럼 한 줄에 들어가야 합니다(기존 동작 유지).
    func test_singleRow_sixteenthFourBeats_fits() {
        // 그룹폭 = 28 + 11×3 + 4×3 + 12 = 85. 4개 = 340 + spacing 16×3(48) = 388 ≤ 392.
        XCTAssertFalse(AccentBarsView.overflowsSingleRow(beatCount: 4, pulses: 4))
    }

    /// 6잇단(pulses=6) 4박자는 한 줄 폭(약 508pt)이 가용 폭 392를 넘습니다 → 줄바꿈 필요.
    func test_sextuplet_fourBeats_overflows() {
        XCTAssertTrue(AccentBarsView.overflowsSingleRow(beatCount: 4, pulses: 6))
    }

    /// 6잇단이라도 박자 2개면 한 줄(약 246pt)에 들어갑니다 → 넘치지 않음.
    func test_sextuplet_twoBeats_fits() {
        XCTAssertFalse(AccentBarsView.overflowsSingleRow(beatCount: 2, pulses: 6))
    }

    /// 줄바꿈 시 한 줄에 놓이는 그룹 2개는 항상 가용 폭 안에 들어와야 합니다.
    /// (모든 분할 중 가장 넓은 6잇단 기준으로 검증)
    func test_twoSextupletGroupsPerRow_alwaysFit() {
        XCTAssertFalse(AccentBarsView.overflowsSingleRow(beatCount: 2, pulses: 6))
    }

    /// 박자 0개는 넘치지 않습니다(엣지 케이스).
    func test_zeroBeats_neverOverflows() {
        XCTAssertFalse(AccentBarsView.overflowsSingleRow(beatCount: 0, pulses: 6))
    }

    // MARK: - groupsPerRow

    /// 가용 폭 안에 실제로 들어가는 개수를 계산해야 합니다(과거엔 상수 2 고정).
    /// 4분음표 그룹폭 40 → 40×7 + 16×6 = 376 ≤ 392, 8개면 416 > 392 이므로 7개.
    func test_groupsPerRow_quarterNote_sevenPerRow() {
        XCTAssertEqual(AccentBarsView.groupsPerRow(pulses: 1), 7)
    }

    /// 8분음표 그룹폭 55 → 55×5 + 16×4 = 339 ≤ 392, 6개면 410 > 392 이므로 5개.
    func test_groupsPerRow_eighthNote_fivePerRow() {
        XCTAssertEqual(AccentBarsView.groupsPerRow(pulses: 2), 5)
    }

    /// 6잇단 그룹폭 115 → 115×3 + 16×2 = 377 ≤ 392, 4개면 508 > 392 이므로 3개.
    func test_groupsPerRow_sextuplet_threePerRow() {
        XCTAssertEqual(AccentBarsView.groupsPerRow(pulses: 6), 3)
    }

    /// 계산된 개수는 언제나 실제로 가용 폭 안에 들어가고,
    /// 한 개 더 놓으면 반드시 넘쳐야 합니다(경계 검증).
    func test_groupsPerRow_isTightUpperBound() {
        for pulses in 1...6 {
            let n = AccentBarsView.groupsPerRow(pulses: pulses)
            let width = AccentBarsView.groupWidth(pulses: pulses)
            let used = width * CGFloat(n) + AccentBarsView.groupSpacing * CGFloat(n - 1)
            let usedPlusOne = width * CGFloat(n + 1) + AccentBarsView.groupSpacing * CGFloat(n)
            XCTAssertLessThanOrEqual(used, AccentBarsView.availableWidth,
                                     "pulses=\(pulses): \(n)개가 가용 폭을 넘습니다")
            XCTAssertGreaterThan(usedPlusOne, AccentBarsView.availableWidth,
                                 "pulses=\(pulses): \(n + 1)개도 들어가는데 덜 배치했습니다")
        }
    }

    /// 어떤 분할이든 최소 1개는 배치해야 합니다(0 나눗셈/무한 루프 방지).
    func test_groupsPerRow_isAtLeastOne() {
        for pulses in 0...12 {
            XCTAssertGreaterThanOrEqual(AccentBarsView.groupsPerRow(pulses: pulses), 1)
        }
    }

    /// 4분음표 8박은 한 줄(7개)을 딱 하나 넘으므로 2줄이면 충분합니다.
    /// 과거 상수 2 고정에서는 4줄로 잘못 쪼개졌습니다.
    func test_quarterNoteEightBeats_isTwoRows() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 8, pulses: 1), 2)
    }

    /// 4분음표 12박도 2줄(7+5)이어야 합니다. 과거에는 6줄이었습니다.
    func test_quarterNoteTwelveBeats_isTwoRows() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 12, pulses: 1), 2)
        XCTAssertEqual(AccentBarsView.contentHeight(beatCount: 12, pulses: 1), 190, accuracy: 0.001)
    }

    /// 최대 설정(12박 × 6잇단)에서도 4줄로 끝나야 합니다(과거 6줄, 602pt).
    func test_worstCase_twelveBeatsSextuplet_isFourRows() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 12, pulses: 6), 4)
        XCTAssertEqual(AccentBarsView.contentHeight(beatCount: 12, pulses: 6), 396, accuracy: 0.001)
    }

    // MARK: - rowCount

    /// 한 줄에 들어가는 배치는 항상 1줄입니다.
    func test_rowCount_fitsSingleRow() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 4, pulses: 1), 1)
    }

    /// 6잇단 4박자는 한 줄 한도(3개)를 넘어 2줄(3+1)이 됩니다.
    func test_rowCount_sextupletFourBeats_twoRows() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 4, pulses: 6), 2)
    }

    /// 6잇단 5박자도 3개씩 끊으면 2줄(3+2)입니다.
    /// (상수 2 고정 시절에는 3줄이었습니다.)
    func test_rowCount_sextupletFiveBeats_twoRows() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 5, pulses: 6), 2)
    }

    /// 박자 0개는 줄이 없습니다.
    func test_rowCount_zeroBeats() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 0, pulses: 6), 0)
    }

    // MARK: - contentHeight

    /// 한 줄 높이 = 바컨테이너(64) + 간격(9) + 라벨(14) = 87.
    func test_contentHeight_singleRow() {
        XCTAssertEqual(AccentBarsView.contentHeight(beatCount: 4, pulses: 1),
                       87, accuracy: 0.001)
    }

    /// 여러 줄이면 창이 늘어나야 하므로 한 줄보다 높이가 커야 합니다.
    /// 2줄 = 87×2 + groupSpacing(16) = 190.
    func test_contentHeight_twoRows_isTaller() {
        let single = AccentBarsView.contentHeight(beatCount: 2, pulses: 6)
        let wrapped = AccentBarsView.contentHeight(beatCount: 4, pulses: 6)
        XCTAssertEqual(single, 87, accuracy: 0.001)
        XCTAssertEqual(wrapped, 190, accuracy: 0.001)
        XCTAssertGreaterThan(wrapped, single)
    }
}
