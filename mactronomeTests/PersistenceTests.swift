import XCTest
@testable import mactronome

@MainActor
final class PersistenceTests: XCTestCase {
    private func makeStore() -> UserDefaults {
        let suite = "metronome.test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    func test_defaultInit_isNotPersisted() {
        // store 없이 생성하면 기본값 고정(기존 테스트 동작 보존).
        let state = MetronomeState()
        XCTAssertEqual(state.bpm, 132)
    }

    func test_changesArePersisted_andRestored() {
        let store = makeStore()
        let a = MetronomeState(store: store)
        a.setBPM(150)
        a.setDenom("8")
        a.setSubdivision(2)
        a.sound = .cowbell
        a.volume = 0.5
        a.cycleCell(beat: 0, pulse: 0) // strong -> mute

        // 같은 저장소로 새 인스턴스를 만들면 복원되어야 한다.
        let b = MetronomeState(store: store)
        XCTAssertEqual(b.bpm, 150)
        XCTAssertEqual(b.denom, "8")
        XCTAssertEqual(b.subIdx, 2)
        XCTAssertEqual(b.sound, .cowbell)
        XCTAssertEqual(b.volume, 0.5, accuracy: 0.0001)
        XCTAssertEqual(b.grid[0][0], .mute)
    }

    func test_emptyStore_usesDefaults() {
        let state = MetronomeState(store: makeStore())
        XCTAssertEqual(state.bpm, 132)
        XCTAssertEqual(state.denom, "4")
        XCTAssertEqual(state.grid, [[.strong], [.weak], [.medium], [.weak]])
    }

    func test_corruptOrOutOfRangeBPM_isClamped() {
        let store = makeStore()
        let a = MetronomeState(store: store)
        a.setBPM(500) // setBPM clamps to 300 before persisting
        let b = MetronomeState(store: store)
        XCTAssertEqual(b.bpm, 300)
    }

    func test_settingsCodable_roundTrips() throws {
        let s = MetronomeSettings(bpm: 100, denom: "8", subIdx: 3,
                                  grid: [[3], [1]], sound: .clave, volume: 0.6)
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(MetronomeSettings.self, from: data)
        XCTAssertEqual(s, decoded)
    }
    func test_displayAndPolyFields_persist() {
        let store = makeStore()
        let a = MetronomeState(store: store)
        a.polyPulses = 3
        a.visualFlash = true
        a.appearance = .dark
        a.floating = true
        a.trainerEnabled = true
        a.countInBars = 2

        let b = MetronomeState(store: store)
        XCTAssertEqual(b.polyPulses, 3)
        XCTAssertTrue(b.visualFlash)
        XCTAssertEqual(b.appearance, .dark)
        XCTAssertTrue(b.floating)
        XCTAssertTrue(b.trainerEnabled)
        XCTAssertEqual(b.countInBars, 2)
    }

    func test_legacySettings_decodeWithDefaults() throws {
        // 구버전(신규 키 없음) JSON도 기본값으로 디코딩되어야 한다.
        let legacy = """
        {"bpm":128,"denom":"4","subIdx":0,"grid":[[3],[1],[2],[1]],"sound":"beep","volume":0.7}
        """.data(using: .utf8)!
        let s = try JSONDecoder().decode(MetronomeSettings.self, from: legacy)
        XCTAssertEqual(s.bpm, 128)
        XCTAssertEqual(s.sound, .beep)
        XCTAssertEqual(s.polyPulses, 0)
        XCTAssertEqual(s.appearance, .system)
        XCTAssertFalse(s.visualFlash)
        XCTAssertFalse(s.floating)
        XCTAssertEqual(s.countInBars, 0)
    }

}
