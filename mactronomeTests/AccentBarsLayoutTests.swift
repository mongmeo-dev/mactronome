import XCTest
import SwiftUI
@testable import mactronome

/// AccentBarsView 의 폭 계산/줄바꿈 판정 로직(순수 함수)을 검증합니다.
/// 목표: 6잇단(pulses=6)에서 한 줄 폭이 가용 폭을 넘어 레이아웃이 깨지지 않고,
///       넘칠 때만 그룹 2개씩 줄바꿈으로 전환되는지 회귀 방지합니다.
final class AccentBarsLayoutTests: XCTestCase {

    // MARK: - groupWidth

    /// pulses=1(4분음표)이면 메인 바 1개의 폭입니다.
    func test_groupWidth_singlePulse() {
        XCTAssertEqual(AccentBarsView.groupWidth(pulses: 1), 28, accuracy: 0.001)
    }

    /// pulses=6(6잇단): 28 + 11×5 + 10×5 = 133.
    func test_groupWidth_sextuplet() {
        XCTAssertEqual(AccentBarsView.groupWidth(pulses: 6), 133, accuracy: 0.001)
    }

    /// pulses 가 0이면 폭은 0입니다(음수 방지).
    func test_groupWidth_zeroPulseIsSafe() {
        XCTAssertEqual(AccentBarsView.groupWidth(pulses: 0), 0, accuracy: 0.001)
    }

    /// 원박-분할박과 분할박-다음 원박 사이의 간격은 같아야 합니다.
    func test_spacingBetweenBeats_matchesSpacingWithinBeat() {
        XCTAssertEqual(AccentBarsView.beatSpacing, AccentBarsView.barSpacing)
        XCTAssertEqual(AccentBarsView.barSpacing, 10)
    }

    // MARK: - overflowsSingleRow

    /// 4분음표(pulses=1) 4박자는 한 줄에 넉넉히 들어갑니다 → 넘치지 않음.
    func test_singleRow_quarterNoteFourBeats_fits() {
        XCTAssertFalse(AccentBarsView.overflowsSingleRow(beatCount: 4, pulses: 1))
    }

    /// 16분음표(pulses=4) 4박자는 10pt 간격에서 가용 폭을 넘습니다.
    func test_singleRow_sixteenthFourBeats_overflows() {
        // 그룹폭 = 28 + 11×3 + 10×3 = 91. 4개 = 364 + spacing 10×3(30) = 394 > 392.
        XCTAssertTrue(AccentBarsView.overflowsSingleRow(beatCount: 4, pulses: 4))
    }

    /// 6잇단(pulses=6) 4박자는 한 줄 폭(562pt)이 가용 폭 392를 넘습니다 → 줄바꿈 필요.
    func test_sextuplet_fourBeats_overflows() {
        XCTAssertTrue(AccentBarsView.overflowsSingleRow(beatCount: 4, pulses: 6))
    }

    /// 6잇단이라도 박자 2개면 한 줄(276pt)에 들어갑니다 → 넘치지 않음.
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
    /// 4분음표 그룹폭 28 → 28×10 + 10×9 = 370 ≤ 392, 11개면 408 > 392 이므로 10개.
    func test_groupsPerRow_quarterNote_tenPerRow() {
        XCTAssertEqual(AccentBarsView.groupsPerRow(pulses: 1), 10)
    }

    /// 8분음표 그룹폭 49 → 49×6 + 10×5 = 344 ≤ 392, 7개면 403 > 392 이므로 6개.
    func test_groupsPerRow_eighthNote_sixPerRow() {
        XCTAssertEqual(AccentBarsView.groupsPerRow(pulses: 2), 6)
    }

    /// 6잇단 그룹폭 133 → 133×2 + 10 = 276 ≤ 392, 3개면 419 > 392 이므로 2개.
    func test_groupsPerRow_sextuplet_twoPerRow() {
        XCTAssertEqual(AccentBarsView.groupsPerRow(pulses: 6), 2)
    }

    /// 계산된 개수는 언제나 실제로 가용 폭 안에 들어가고,
    /// 한 개 더 놓으면 반드시 넘쳐야 합니다(경계 검증).
    func test_groupsPerRow_isTightUpperBound() {
        for pulses in 1...6 {
            let n = AccentBarsView.groupsPerRow(pulses: pulses)
            let width = AccentBarsView.groupWidth(pulses: pulses)
            let used = width * CGFloat(n) + AccentBarsView.beatSpacing * CGFloat(n - 1)
            let usedPlusOne = width * CGFloat(n + 1) + AccentBarsView.beatSpacing * CGFloat(n)
            XCTAssertLessThanOrEqual(used, AccentBarsView.defaultAvailableWidth,
                                     "pulses=\(pulses): \(n)개가 가용 폭을 넘습니다")
            XCTAssertGreaterThan(usedPlusOne, AccentBarsView.defaultAvailableWidth,
                                 "pulses=\(pulses): \(n + 1)개도 들어가는데 덜 배치했습니다")
        }
    }

    /// 어떤 분할이든 최소 1개는 배치해야 합니다(0 나눗셈/무한 루프 방지).
    func test_groupsPerRow_isAtLeastOne() {
        for pulses in 0...12 {
            XCTAssertGreaterThanOrEqual(AccentBarsView.groupsPerRow(pulses: pulses), 1)
        }
    }

    /// 4분음표 8박은 일정한 간격으로 한 줄에 들어갑니다.
    func test_quarterNoteEightBeats_isOneRow() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 8, pulses: 1), 1)
    }

    /// 4분음표 최대 설정 12박은 기본 폭에서 2줄로 배치됩니다.
    func test_quarterNoteTwelveBeats_isTwoRows() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 12, pulses: 1), 2)
        XCTAssertEqual(AccentBarsView.contentHeight(beatCount: 12, pulses: 1), 190, accuracy: 0.001)
    }

    /// 최대 설정(12박 × 6잇단)은 기본 폭에서 6줄입니다.
    func test_worstCase_twelveBeatsSextuplet_isSixRows() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 12, pulses: 6), 6)
        XCTAssertEqual(AccentBarsView.contentHeight(beatCount: 12, pulses: 6), 602, accuracy: 0.001)
    }

    /// 창을 넓히면 같은 박자들이 더 적은 줄로 재배치되어야 합니다.
    func test_rowCount_decreasesAsAvailableWidthGrows() {
        XCTAssertEqual(
            AccentBarsView.rowCount(beatCount: 4, pulses: 6, availableWidth: 392),
            2
        )
        XCTAssertEqual(
            AccentBarsView.rowCount(beatCount: 4, pulses: 6, availableWidth: 562),
            1
        )
    }
    // MARK: - visibleHeight (창 높이 상한)

    /// 한 줄이면 표시 높이와 콘텐츠 높이가 같습니다.
    func test_visibleHeight_matchesContentHeight_whenWithinCap() {
        for (beats, pulses) in [(4, 1), (2, 6), (4, 4)] {
            XCTAssertEqual(AccentBarsView.visibleHeight(beatCount: beats, pulses: pulses),
                           AccentBarsView.contentHeight(beatCount: beats, pulses: pulses),
                           accuracy: 0.001,
                           "beats=\(beats) pulses=\(pulses)")
        }
    }

    /// 상한을 넘는 줄 수는 표시 높이가 `maxVisibleRows` 에서 멈춰야 합니다(초과분은 스크롤).
    func test_visibleHeight_isCappedAtMaxVisibleRows() {
        let capped = AccentBarsView.visibleHeight(beatCount: 12, pulses: 6)
        let full = AccentBarsView.contentHeight(beatCount: 12, pulses: 6)
        XCTAssertLessThan(capped, full)
        XCTAssertEqual(capped, 190, accuracy: 0.001) // 87×2 + 16
    }

    /// 두 줄이 모두 보이는 경우에는 불필요한 스크롤을 만들지 않아야 합니다.
    func test_twoVisibleRows_doNotNeedScrolling() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 4, pulses: 6), 2)
        XCTAssertFalse(AccentBarsView.needsScrolling(beatCount: 4, pulses: 6))
    }

    /// 표시 상한을 넘는 경우에만 세로 스크롤이 필요합니다.
    func test_rowsBeyondVisibleCap_needScrolling() {
        XCTAssertTrue(AccentBarsView.needsScrolling(beatCount: 12, pulses: 6))
    }

    /// 어떤 박자/분할 조합에서도 표시 높이는 상한을 넘지 않아야 합니다.
    func test_visibleHeight_neverExceedsCap_forAnyConfiguration() {
        let cap = AccentBarsView.singleGroupRowHeight * CGFloat(AccentBarsView.maxVisibleRows)
            + AccentBarsView.rowSpacing * CGFloat(AccentBarsView.maxVisibleRows - 1)
        for beats in 1...12 {
            for pulses in MetronomeState.subCounts {
                XCTAssertLessThanOrEqual(
                    AccentBarsView.visibleHeight(beatCount: beats, pulses: pulses), cap,
                    "beats=\(beats) pulses=\(pulses) 에서 상한을 넘었습니다"
                )
            }
        }
    }


    // MARK: - rowCount

    /// 한 줄에 들어가는 배치는 항상 1줄입니다.
    func test_rowCount_fitsSingleRow() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 4, pulses: 1), 1)
    }

    /// 6잇단 4박자는 한 줄 한도(2개)를 넘어 2줄(2+2)이 됩니다.
    func test_rowCount_sextupletFourBeats_twoRows() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 4, pulses: 6), 2)
    }

    /// 6잇단 5박자는 2개씩 끊으면 3줄(2+2+1)입니다.
    func test_rowCount_sextupletFiveBeats_threeRows() {
        XCTAssertEqual(AccentBarsView.rowCount(beatCount: 5, pulses: 6), 3)
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
    /// 2줄 = 87×2 + rowSpacing(16) = 190.
    func test_contentHeight_twoRows_isTaller() {
        let single = AccentBarsView.contentHeight(beatCount: 2, pulses: 6)
        let wrapped = AccentBarsView.contentHeight(beatCount: 4, pulses: 6)
        XCTAssertEqual(single, 87, accuracy: 0.001)
        XCTAssertEqual(wrapped, 190, accuracy: 0.001)
        XCTAssertGreaterThan(wrapped, single)
    }
}
