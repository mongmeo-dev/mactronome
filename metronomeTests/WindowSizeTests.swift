import XCTest
import SwiftUI
import AppKit
@testable import metronome

/// 본 창이 노트북 화면 안에 들어가는지 실제로 레이아웃해서 측정합니다.
///
/// 배경: 사운드/연습/표시 설정을 한 컬럼에 전부 펼쳐 두던 시절
/// 창 높이가 1,100pt 를 넘었습니다. 창은 `.windowResizability(.contentSize)` 라
/// 리사이즈도 안 되고 스크롤뷰도 없어서, 13" 노트북에서는 하단 시작 버튼에
/// 접근할 방법이 아예 없었습니다.
@MainActor
final class WindowSizeTests: XCTestCase {

    /// 13" 맥북(1470×956pt)의 화면 높이에서 메뉴바(약 25pt)를 뺀 안전 높이입니다.
    private static let safeHeight: CGFloat = 930

    /// 주어진 상태로 본 창 콘텐츠를 실제 레이아웃해 크기를 잽니다.
    private func measure(_ state: MetronomeState) -> CGSize {
        let host = NSHostingView(rootView: MetronomeScreen().environmentObject(state))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    /// 기본 설정(4/4, 4분음표)에서 안전 높이 안에 들어와야 합니다.
    func test_defaultLayout_fitsOnLaptopScreen() {
        let size = measure(MetronomeState())
        XCTAssertLessThan(size.height, Self.safeHeight,
                          "기본 창 높이 \(size.height)pt 가 안전 높이를 넘습니다")
        XCTAssertGreaterThan(size.height, 300, "측정이 실패했거나 콘텐츠가 비었습니다")
    }

    /// 최악 설정(12박 × 6잇단 + 오류 배너)에서도 안전 높이 안에 들어와야 합니다.
    /// 수정 전에는 1,163pt 였습니다.
    func test_worstCaseLayout_fitsOnLaptopScreen() {
        let state = MetronomeState()
        state.setSubdivision(4) // subCounts[4] == 6 (6잇단)
        while state.grid.count < 12 { state.addBeat() }
        state.lastError = "오디오 장치를 사용할 수 없습니다"

        let size = measure(state)
        XCTAssertEqual(state.grid.count, 12)
        XCTAssertEqual(state.pulsesPerBeat, 6)
        XCTAssertLessThan(size.height, Self.safeHeight,
                          "최악 창 높이 \(size.height)pt 가 안전 높이를 넘습니다")
    }

    /// 창 높이의 유일한 가변 요소는 악센트 바 영역이고, 그 영역은 `maxVisibleRows`
    /// 로 상한이 걸려 있어야 합니다. 즉 최악 높이 − 기본 높이 = 2줄 − 1줄 입니다.
    /// 다른 가변 요소가 새로 들어오면(=창 높이가 다시 발산하면) 이 테스트가 깨집니다.
    func test_windowHeight_growsOnlyByCappedAccentArea() {
        let base = measure(MetronomeState()).height

        let state = MetronomeState()
        state.setSubdivision(4)
        while state.grid.count < 12 { state.addBeat() }
        let worst = measure(state).height

        let oneRow = AccentBarsView.visibleHeight(beatCount: 4, pulses: 1)
        let cappedRows = AccentBarsView.visibleHeight(beatCount: 12, pulses: 6)
        XCTAssertEqual(worst - base, cappedRows - oneRow, accuracy: 1.0,
                       "악센트 바 영역 외에 창 높이를 늘리는 요소가 생겼습니다")
    }

    /// 컴팩트 모드는 일반 모드보다 훨씬 작아야 합니다(항상 위에 띄워 두는 용도).
    func test_compactMode_isMuchSmaller() {
        let normal = measure(MetronomeState())

        let state = MetronomeState()
        state.compact = true
        let compact = measure(state)

        XCTAssertEqual(compact.width, Theme.Layout.compactWindowWidth, accuracy: 1.0)
        XCTAssertLessThan(compact.height, normal.height / 2,
                          "컴팩트 높이 \(compact.height)pt 가 일반 \(normal.height)pt 의 절반 이상입니다")
    }

    /// 컴팩트 모드는 박자 수가 늘어도 창이 눈에 띄게 커지면 안 됩니다.
    func test_compactMode_staysSmallWithManyBeats() {
        let state = MetronomeState()
        state.compact = true
        let before = measure(state).height
        while state.grid.count < 12 { state.addBeat() }
        XCTAssertEqual(measure(state).height, before, accuracy: 1.0)
    }

    /// 창 폭은 디자인 폭에 고정되어야 합니다(가로 스크롤/잘림 방지).
    func test_windowWidth_matchesDesign() {
        let size = measure(MetronomeState())
        XCTAssertEqual(size.width, Theme.Layout.windowWidth, accuracy: 1.0)
    }

    /// 설정 창도 화면 안에 들어와야 합니다.
    func test_settingsWindow_fitsOnLaptopScreen() {
        let state = MetronomeState()
        state.trainerEnabled = true // 트레이너 스테퍼 3개가 펼쳐진 상태
        let host = NSHostingView(rootView: SettingsScreen(state: state))
        host.layoutSubtreeIfNeeded()
        XCTAssertLessThan(host.fittingSize.height, Self.safeHeight,
                          "설정 창 높이 \(host.fittingSize.height)pt 가 안전 높이를 넘습니다")
    }
}
