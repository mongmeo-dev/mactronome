import XCTest
@testable import metronome

@MainActor
final class TrainerTests: XCTestCase {

    private func playing() -> MetronomeState {
        let state = MetronomeState()
        state.togglePlay() // start (registerBarStart는 isPlaying 가드가 있음)
        return state
    }

    func test_barCounter_incrementsPerDownbeat() {
        let state = playing()
        XCTAssertEqual(state.currentBar, 0)
        state.registerBarStart() // 첫 다운비트 = 마디 1
        XCTAssertEqual(state.currentBar, 1)
        state.registerBarStart()
        XCTAssertEqual(state.currentBar, 2)
    }

    func test_barCounter_zeroWhenStopped() {
        let state = playing()
        state.registerBarStart()
        state.registerBarStart()
        state.togglePlay() // stop
        XCTAssertEqual(state.currentBar, 0)
    }

    func test_countIn_consumesBarsBeforeCounting() {
        let state = MetronomeState()
        state.countInBars = 2
        state.togglePlay()
        XCTAssertTrue(state.isCountingIn)
        XCTAssertEqual(state.countInRemaining, 2)

        state.registerBarStart() // count-in 1 소진
        XCTAssertTrue(state.isCountingIn)
        XCTAssertEqual(state.countInRemaining, 1)
        XCTAssertEqual(state.currentBar, 0)

        state.registerBarStart() // count-in 2 소진 → 종료
        XCTAssertFalse(state.isCountingIn)
        XCTAssertEqual(state.currentBar, 0)

        state.registerBarStart() // 첫 실제 마디
        XCTAssertEqual(state.currentBar, 1)
    }

    func test_trainer_bumpsBPMEveryNBars() {
        let state = MetronomeState()
        state.setBPM(120)
        state.trainerEnabled = true
        state.trainerEveryBars = 2
        state.trainerBPMStep = 10
        state.trainerTargetBPM = 200
        state.togglePlay()

        state.registerBarStart() // 마디1 시작 (완료 0)
        XCTAssertEqual(state.bpm, 120)
        state.registerBarStart() // 마디2 시작 (완료 1)
        XCTAssertEqual(state.bpm, 120)
        state.registerBarStart() // 마디3 시작 (완료 2) → bump
        XCTAssertEqual(state.bpm, 130)
        state.registerBarStart() // 완료 3
        XCTAssertEqual(state.bpm, 130)
        state.registerBarStart() // 완료 4 → bump
        XCTAssertEqual(state.bpm, 140)
    }

    func test_trainer_stopsAtTarget() {
        let state = MetronomeState()
        state.setBPM(195)
        state.trainerEnabled = true
        state.trainerEveryBars = 1
        state.trainerBPMStep = 10
        state.trainerTargetBPM = 200
        state.togglePlay()

        state.registerBarStart() // 완료 0
        state.registerBarStart() // 완료 1 → bump: 195+10 클램프 → 200
        XCTAssertEqual(state.bpm, 200)
        state.registerBarStart() // 완료 2 → 이미 목표, 변화 없음
        XCTAssertEqual(state.bpm, 200)
    }

    func test_trainer_disabled_doesNotBump() {
        let state = MetronomeState()
        state.setBPM(120)
        state.trainerEnabled = false
        state.togglePlay()
        for _ in 0..<10 { state.registerBarStart() }
        XCTAssertEqual(state.bpm, 120)
    }
}
