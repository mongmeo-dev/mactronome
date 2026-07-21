import Foundation

/// BPM과 샘플레이트로 한 박자당 프레임 수를 계산합니다.
func framesPerBeat(bpm: Double, sampleRate: Double) -> Int {
    precondition(bpm > 0 && sampleRate > 0)
    return Int((sampleRate * 60.0 / bpm).rounded())
}
