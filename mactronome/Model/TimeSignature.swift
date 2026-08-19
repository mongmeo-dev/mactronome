// metronome/Model/TimeSignature.swift
import Foundation

/// 박자표를 나타내는 값 타입입니다.
struct TimeSignature: Equatable {
    let beatsPerBar: Int
    let noteValue: Int

    /// 0-based 박자 인덱스가 강박(첫 박)인지 반환합니다.
    func isAccent(beatIndex: Int) -> Bool {
        beatIndex % beatsPerBar == 0
    }

    static let fourFour = TimeSignature(beatsPerBar: 4, noteValue: 4)
    static let threeFour = TimeSignature(beatsPerBar: 3, noteValue: 4)
    static let twoFour = TimeSignature(beatsPerBar: 2, noteValue: 4)
    static let sixEight = TimeSignature(beatsPerBar: 6, noteValue: 8)

    static let presets: [TimeSignature] = [twoFour, threeFour, fourFour, sixEight]

    static let noteValues: [Int] = [2, 4, 8, 16]

    /// 분모만 바꾼 새 값을 반환합니다.
    func withNoteValue(_ value: Int) -> TimeSignature {
        TimeSignature(beatsPerBar: beatsPerBar, noteValue: value)
    }
}

extension TimeSignature {
    var label: String { "\(beatsPerBar)/\(noteValue)" }
}
