import XCTest
@testable import metronome

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

    func test_noStore_presetsAreInMemoryOnly() {
        let state = MetronomeState() // store nil
        state.saveCurrentAsPreset(named: "메모리")
        XCTAssertEqual(state.presets.count, 1) // 저장은 되지만 영속 안 됨
    }
}
