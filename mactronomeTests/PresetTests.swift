import XCTest
@testable import mactronome

@MainActor
final class PresetTests: XCTestCase {
    private func makeStore() -> UserDefaults {
        UserDefaults(suiteName: "metronome.test.\(UUID().uuidString)")!
    }

    func test_saveAndApplyPreset_restoresSettings() {
        let store = makeStore()
        let state = MetronomeState(store: store)
        state.setBPM(90)
        state.setDenom("8")
        state.sound = .clave
        state.saveCurrentAsPreset(named: "느린 연습")

        // 상태를 바꾼 뒤 프리셋을 적용하면 되돌아와야 한다.
        state.setBPM(200)
        state.sound = .beep
        let preset = state.presets.first { $0.name == "느린 연습" }!
        state.applyPreset(preset)

        XCTAssertEqual(state.bpm, 90)
        XCTAssertEqual(state.denom, "8")
        XCTAssertEqual(state.sound, .clave)
    }

    func test_savingSameName_overwrites() {
        let state = MetronomeState(store: makeStore())
        state.setBPM(100)
        state.saveCurrentAsPreset(named: "A")
        state.setBPM(140)
        state.saveCurrentAsPreset(named: "A")
        XCTAssertEqual(state.presets.count, 1)
        XCTAssertEqual(state.presets[0].settings.bpm, 140)
    }

    func test_emptyName_getsGeneratedName() {
        let state = MetronomeState(store: makeStore())
        state.saveCurrentAsPreset(named: "   ")
        XCTAssertEqual(state.presets.count, 1)
        XCTAssertFalse(state.presets[0].name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func test_deletePreset_removesIt() {
        let state = MetronomeState(store: makeStore())
        let p = state.saveCurrentAsPreset(named: "X")
        XCTAssertEqual(state.presets.count, 1)
        state.deletePreset(p)
        XCTAssertTrue(state.presets.isEmpty)
    }

    func test_presetsPersistAcrossInstances() {
        let store = makeStore()
        let a = MetronomeState(store: store)
        a.setBPM(111)
        a.saveCurrentAsPreset(named: "지속")

        let b = MetronomeState(store: store)
        XCTAssertEqual(b.presets.count, 1)
        XCTAssertEqual(b.presets[0].name, "지속")
        XCTAssertEqual(b.presets[0].settings.bpm, 111)
    }

    /// 프리셋은 "BPM·박자·강세·사운드·연습" 만 되돌립니다.
    /// 표시/창 설정(화면 모드·항상 위에·플래시·컴팩트)까지 덮어쓰면
    /// 프리셋을 불러오는 순간 다크 모드가 풀리거나 창 크기가 바뀌어 버립니다.
    func test_applyPreset_doesNotTouchWindowPreferences() {
        let state = MetronomeState(store: makeStore())
        state.appearance = .light
        state.floating = false
        state.visualFlash = false
        state.compact = false
        state.setBPM(90)
        state.saveCurrentAsPreset(named: "밝은 설정")

        // 창/표시 설정을 바꾼 뒤 프리셋을 적용합니다.
        state.appearance = .dark
        state.floating = true
        state.visualFlash = true
        state.compact = true
        state.setBPM(200)

        state.applyPreset(state.presets[0])

        XCTAssertEqual(state.bpm, 90, "음악 설정은 되돌아와야 합니다")
        XCTAssertEqual(state.appearance, .dark, "화면 모드는 유지되어야 합니다")
        XCTAssertTrue(state.floating, "항상 위에는 유지되어야 합니다")
        XCTAssertTrue(state.visualFlash, "비주얼 플래시는 유지되어야 합니다")
        XCTAssertTrue(state.compact, "컴팩트 모드는 유지되어야 합니다")
    }

    // MARK: - 적용 중 프리셋 표시

    /// 프리셋을 적용하면 그 이름이 "적용 중"으로 표시되어야 합니다.
    func test_activePresetName_reflectsAppliedPreset() {
        let state = MetronomeState(store: makeStore())
        state.setBPM(90)
        state.saveCurrentAsPreset(named: "느린 연습")
        XCTAssertEqual(state.activePresetName, "느린 연습")

        state.setBPM(200)
        XCTAssertNil(state.activePresetName, "설정을 바꾸면 적용 중 표시가 사라져야 합니다")

        state.applyPreset(state.presets[0])
        XCTAssertEqual(state.activePresetName, "느린 연습")
    }

    /// 표시/창 설정만 바꾼 경우에는 적용 중 표시가 유지되어야 합니다.
    /// (프리셋은 음악 설정만 담습니다.)
    func test_activePresetName_ignoresWindowPreferences() {
        let state = MetronomeState(store: makeStore())
        state.saveCurrentAsPreset(named: "기본")
        XCTAssertEqual(state.activePresetName, "기본")

        state.appearance = .dark
        state.floating = true
        state.compact = true
        state.visualFlash = true
        XCTAssertEqual(state.activePresetName, "기본",
                       "다크 모드를 켰다고 적용 중 표시가 사라지면 안 됩니다")
    }

    /// 프리셋이 없으면 적용 중 표시도 없습니다.
    func test_activePresetName_isNilWithoutPresets() {
        XCTAssertNil(MetronomeState(store: makeStore()).activePresetName)
    }

    // MARK: - 덮어쓰기 경고

    /// 같은 이름이 이미 있으면 뷰가 확인을 띄울 수 있도록 알려야 합니다.
    func test_presetExists_detectsDuplicateName() {
        let state = MetronomeState(store: makeStore())
        state.saveCurrentAsPreset(named: "A")
        XCTAssertTrue(state.presetExists(named: "A"))
        XCTAssertTrue(state.presetExists(named: "  A  "), "공백은 다듬어 비교해야 합니다")
        XCTAssertFalse(state.presetExists(named: "B"))
        XCTAssertFalse(state.presetExists(named: "   "), "빈 이름은 중복으로 보지 않습니다")
    }

    func test_noStore_presetsAreInMemoryOnly() {
        let state = MetronomeState() // store nil
        state.saveCurrentAsPreset(named: "메모리")
        XCTAssertEqual(state.presets.count, 1) // 저장은 되지만 영속 안 됨
    }
}
