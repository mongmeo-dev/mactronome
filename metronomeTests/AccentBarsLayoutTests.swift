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
}
