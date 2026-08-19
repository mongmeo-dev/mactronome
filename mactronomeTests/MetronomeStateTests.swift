import XCTest
@testable import mactronome

@MainActor
final class MetronomeStateTests: XCTestCase {
    func test_defaultGrid_matchesSpec() {
        let state = MetronomeState()
        XCTAssertEqual(state.grid, [[.strong], [.weak], [.medium], [.weak]])
    }

    func test_defaultBPM_is132() {
        let state = MetronomeState()
        XCTAssertEqual(state.bpm, 132)
    }

    func test_setBPM_clampsToLowerBound() {
        let state = MetronomeState()
        state.setBPM(10)
        XCTAssertEqual(state.bpm, 30)
    }

    func test_setBPM_clampsToUpperBound() {
        let state = MetronomeState()
        state.setBPM(1000)
        XCTAssertEqual(state.bpm, 300)
    }

    func test_togglePlay_flipsIsPlaying_startThenStop() {
        let state = MetronomeState()
        XCTAssertFalse(state.isPlaying)
        state.togglePlay()
        XCTAssertTrue(state.isPlaying)
        state.togglePlay()
        XCTAssertFalse(state.isPlaying)
    }

    func test_cycleCell_strongWrapsToMute() {
        let state = MetronomeState()
        // grid[0][0] starts as .strong (rawValue 3)
        state.cycleCell(beat: 0, pulse: 0)
        XCTAssertEqual(state.grid[0][0], .mute)
    }

    func test_cycleCell_weakAdvancesToMedium() {
        let state = MetronomeState()
        // grid[1][0] starts as .weak (rawValue 1)
        state.cycleCell(beat: 1, pulse: 0)
        XCTAssertEqual(state.grid[1][0], .medium)
    }

    /// 컨텍스트 메뉴에서 강세를 직접 지정할 수 있어야 합니다.
    /// (순환만 있으면 강박 → 중강 으로 한 단계 되돌리는 데 세 번 눌러야 합니다.)
    func test_setCell_assignsLevelDirectly() {
        let state = MetronomeState()
        state.setCell(beat: 0, pulse: 0, level: .medium)
        XCTAssertEqual(state.grid[0][0], .medium)
        state.setCell(beat: 0, pulse: 0, level: .mute)
        XCTAssertEqual(state.grid[0][0], .mute)
    }

    /// 범위를 벗어난 좌표는 무시해야 합니다(그리드 리사이즈 중 들어온 입력 방어).
    func test_outOfBoundsCell_isIgnored() {
        let state = MetronomeState()
        let before = state.grid
        state.cycleCell(beat: 99, pulse: 0)
        state.cycleCell(beat: 0, pulse: 99)
        state.cycleCell(beat: -1, pulse: 0)
        state.setCell(beat: 99, pulse: 0, level: .strong)
        state.setCell(beat: 0, pulse: -1, level: .strong)
        XCTAssertEqual(state.grid, before)
    }

    /// 좌표 유효성 판정이 실제 그리드 크기를 따라야 합니다.
    func test_isValidCell_tracksGridSize() {
        let state = MetronomeState()
        XCTAssertTrue(state.isValidCell(beat: 0, pulse: 0))
        XCTAssertFalse(state.isValidCell(beat: 0, pulse: 1))
        state.setSubdivision(1) // 펄스 2개로 확장
        XCTAssertTrue(state.isValidCell(beat: 0, pulse: 1))
        XCTAssertFalse(state.isValidCell(beat: state.grid.count, pulse: 0))
    }

    // MARK: - 음소거

    /// 음소거를 켜면 0이 되고, 풀면 직전 볼륨으로 정확히 돌아와야 합니다.
    func test_toggleMute_restoresPreviousVolume() {
        let state = MetronomeState()
        state.volume = 0.35
        XCTAssertFalse(state.isMuted)

        state.toggleMute()
        XCTAssertTrue(state.isMuted)
        XCTAssertEqual(state.volume, 0)

        state.toggleMute()
        XCTAssertFalse(state.isMuted)
        XCTAssertEqual(state.volume, 0.35, accuracy: 0.0001)
    }

    /// 볼륨이 이미 0인 상태에서 음소거를 풀면 들리는 값으로 복구해야 합니다.
    /// (0으로 저장된 채 앱을 다시 켠 경우 무음에서 벗어날 방법이 없어집니다.)
    func test_unmute_fromZeroStart_restoresAudibleVolume() {
        let state = MetronomeState()
        state.volume = 0
        state.toggleMute()
        XCTAssertGreaterThan(state.volume, 0)
    }

    /// 음소거 중 슬라이더로 볼륨을 올리면 음소거가 자연히 풀린 것으로 봐야 합니다.
    func test_isMuted_followsVolume() {
        let state = MetronomeState()
        state.volume = 0
        XCTAssertTrue(state.isMuted)
        state.volume = 0.5
        XCTAssertFalse(state.isMuted)
    }

    func test_addBeat_appendsRowOfWeak_withPulsesPerBeatCount() {
        let state = MetronomeState()
        let beforeCount = state.grid.count
        state.addBeat()
        XCTAssertEqual(state.grid.count, beforeCount + 1)
        XCTAssertEqual(state.grid.last, Array(repeating: .weak, count: state.pulsesPerBeat))
    }

    func test_addBeat_stopsAt12() {
        let state = MetronomeState()
        for _ in 0..<20 {
            state.addBeat()
        }
        XCTAssertEqual(state.grid.count, 12)
    }

    func test_removeBeat_removesLastRow() {
        let state = MetronomeState()
        state.addBeat()
        let beforeCount = state.grid.count
        state.removeBeat()
        XCTAssertEqual(state.grid.count, beforeCount - 1)
    }

    func test_removeBeat_stopsAt1() {
        let state = MetronomeState()
        for _ in 0..<20 {
            state.removeBeat()
        }
        XCTAssertEqual(state.grid.count, 1)
    }

    func test_setSubdivision_resizesRows_padWithWeak_preservingPrefix() {
        let state = MetronomeState()
        // default grid rows are length 1: [.strong],[.weak],[.medium],[.weak]
        state.setSubdivision(1) // subCounts[1] == 2
        XCTAssertEqual(state.subIdx, 1)
        XCTAssertEqual(state.pulsesPerBeat, 2)
        XCTAssertEqual(state.grid, [
            [.strong, .weak],
            [.weak, .weak],
            [.medium, .weak],
            [.weak, .weak],
        ])
    }

    func test_setSubdivision_slicesLongerRows() {
        let state = MetronomeState()
        state.setSubdivision(2) // subCounts[2] == 4
        XCTAssertEqual(state.pulsesPerBeat, 4)
        state.setSubdivision(0) // subCounts[0] == 1, slice back down
        XCTAssertEqual(state.pulsesPerBeat, 1)
        XCTAssertEqual(state.grid, [[.strong], [.weak], [.medium], [.weak]])
    }

    func test_tapForTesting_twoTaps_halfSecondApart_givesApprox120BPM() {
        let state = MetronomeState()
        state.setBPM(60) // start away from 120 to prove tap changed it
        _ = state.tapForTesting(at: 0.0)
        _ = state.tapForTesting(at: 0.5)
        XCTAssertEqual(state.bpm, 120.0, accuracy: 1.0)
    }

    func test_updateGrid_propagation_doesNotCrashWhileStopped() {
        let state = MetronomeState()
        XCTAssertFalse(state.isPlaying)
        state.addBeat()
        state.setSubdivision(2)
        state.setBPM(140)
        // No crash expected; engine updates are no-ops on audio output while stopped.
    }
    func test_noteValue_parsesDenom() {
        let state = MetronomeState()
        XCTAssertEqual(state.noteValue, 4)
        state.setDenom("8")
        XCTAssertEqual(state.denom, "8")
        XCTAssertEqual(state.noteValue, 8)
    }

    func test_subCounts_hasNoDuplicateForQuarter() {
        // 마지막 분할 타일은 4분음표(1펄스)와 중복이 아니어야 한다(5잇단=5).
        XCTAssertEqual(MetronomeState.subCounts, [1, 2, 4, 3, 6, 5])
        XCTAssertEqual(Set(MetronomeState.subCounts).count, MetronomeState.subCounts.count)
    }

    func test_defaultSoundAndVolume() {
        let state = MetronomeState()
        XCTAssertEqual(state.sound, .woodBlock)
        XCTAssertEqual(state.volume, 0.8, accuracy: 0.0001)
    }

}
