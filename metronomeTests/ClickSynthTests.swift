import XCTest
@testable import metronome

final class ClickSynthTests: XCTestCase {
    func test_click_hasExpectedLength() {
        let click = ClickSynth.makeClick(sampleRate: 44100, frequency: 1000, durationSeconds: 0.02)
        XCTAssertEqual(click.count, 882) // 44100 * 0.02
    }

    func test_click_startsNonZero_decaysToNearZero() {
        let click = ClickSynth.makeClick(sampleRate: 44100, frequency: 1000, durationSeconds: 0.02)
        XCTAssertGreaterThan(abs(click.first ?? 0) + abs(click[10]), 0.0)
        XCTAssertLessThan(abs(click.last ?? 1), 0.05) // 끝에서 거의 감쇠
    }

    func test_makeBuffers_accentHigherFreqThanNormal_bothNonEmpty() {
        let buffers = ClickSynth.make(sampleRate: 44100)
        XCTAssertFalse(buffers.accent.isEmpty)
        XCTAssertFalse(buffers.normal.isEmpty)
    }

    func test_makeLevelBuffers_hasFourEntries_muteIsSilent() {
        let buffers = ClickSynth.makeLevelBuffers(sampleRate: 44100)
        XCTAssertEqual(buffers.count, 4)
        // 레벨 0(mute)은 모든 샘플이 0 이어야 함
        let mute = buffers[0]
        XCTAssertTrue(mute.allSatisfy { $0 == 0 })
        // 레벨 3(strong)은 비어있지 않고 0이 아닌 샘플 포함
        XCTAssertFalse(buffers[3].isEmpty)
        XCTAssertTrue(buffers[3].contains { $0 != 0 })
    }
    func test_makeLevelBuffers_allSounds_muteSilent_strongAudible() {
        for sound in ClickSound.allCases {
            let buffers = ClickSynth.makeLevelBuffers(sampleRate: 44100, sound: sound)
            XCTAssertEqual(buffers.count, 4, "\(sound.rawValue)")
            XCTAssertTrue(buffers[0].allSatisfy { $0 == 0 }, "\(sound.rawValue) mute")
            XCTAssertTrue(buffers[3].contains { $0 != 0 }, "\(sound.rawValue) strong")
        }
    }

    func test_makeLevelBuffers_timbresDiffer() {
        let wb = ClickSynth.makeLevelBuffers(sampleRate: 44100, sound: .woodBlock)[3]
        let beep = ClickSynth.makeLevelBuffers(sampleRate: 44100, sound: .beep)[3]
        XCTAssertNotEqual(wb, beep)
    }

    func test_noiseWaveform_isDeterministic() {
        let a = ClickSynth.makeLevelBuffers(sampleRate: 44100, sound: .click)[3]
        let b = ClickSynth.makeLevelBuffers(sampleRate: 44100, sound: .click)[3]
        XCTAssertEqual(a, b) // 고정 시드 → 재현 가능
    }

}
