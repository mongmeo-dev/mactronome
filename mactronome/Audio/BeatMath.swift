import Foundation

/// BPM과 샘플레이트로 한 박자당 프레임 수를 계산합니다.
///
/// `noteValue`는 박(beat)에 해당하는 음표의 분모입니다(4=4분음표, 8=8분음표 …).
/// BPM은 항상 4분음표 기준(MM)으로 해석하므로, 한 박의 길이는 4분음표의 `4/noteValue`배입니다.
/// 예: 120 BPM · noteValue 8 → 4분음표 22050프레임의 절반인 11025프레임마다 한 박.
func framesPerBeat(bpm: Double, sampleRate: Double, noteValue: Int = 4) -> Int {
    precondition(bpm > 0 && sampleRate > 0 && noteValue > 0)
    let quarterFrames = sampleRate * 60.0 / bpm
    return Int((quarterFrames * 4.0 / Double(noteValue)).rounded())
}
