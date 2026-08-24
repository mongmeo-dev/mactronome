import Foundation

/// 클릭 사운드를 코드로 생성합니다. (음색/강세 레벨별)
struct ClickSynth {
    struct ClickBuffers {
        let accent: [Float]
        let normal: [Float]
    }

    /// 지수 감쇠 파형 클릭 한 개를 생성합니다(사인 기본).
    static func makeClick(sampleRate: Double, frequency: Double, durationSeconds: Double) -> [Float] {
        makeClick(sampleRate: sampleRate, frequency: frequency, durationSeconds: durationSeconds,
                  waveform: .sine, decay: 25)
    }

    /// 파형과 감쇠를 지정 가능한 일반 클릭 생성기입니다.
    static func makeClick(sampleRate: Double,
                          frequency: Double,
                          durationSeconds: Double,
                          waveform: Waveform,
                          decay: Double) -> [Float] {
        let count = Int(sampleRate * durationSeconds)
        guard count > 0 else { return [] }
        var samples = [Float](repeating: 0, count: count)
        let decayRate = decay / durationSeconds
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let envelope = exp(-decayRate * t)
            let value = wave(waveform, frequency: frequency, t: t)
            samples[i] = Float(value * envelope)
        }
        return samples
    }

    private static func wave(_ waveform: Waveform, frequency: Double, t: Double) -> Double {
        let phase = frequency * t
        switch waveform {
        case .sine:
            return sin(2.0 * Double.pi * phase)
        case .square:
            return sin(2.0 * Double.pi * phase) >= 0 ? 0.7 : -0.7
        }
    }

    /// 강박(고음)/약박(저음) 버퍼 쌍을 생성합니다.
    static func make(sampleRate: Double) -> ClickBuffers {
        let accent = makeClick(sampleRate: sampleRate, frequency: 1500, durationSeconds: 0.02)
        let normal = makeClick(sampleRate: sampleRate, frequency: 1000, durationSeconds: 0.02)
        return ClickBuffers(accent: accent, normal: normal)
    }

    /// 강세 레벨 0~3의 클릭 버퍼 배열을 생성합니다. 레벨 0(mute)은 무음입니다.
    static func makeLevelBuffers(sampleRate: Double, sound: ClickSound = .beep) -> [[Float]] {
        return AccentLevel.allCases.map { level in
            guard level.gain > 0 else {
                // 무음: duration만큼 0으로 채운 버퍼
                let count = Int(sampleRate * sound.duration)
                return [Float](repeating: 0, count: count)
            }
            let base = makeClick(sampleRate: sampleRate,
                                 frequency: sound.frequency(for: level),
                                 durationSeconds: sound.duration,
                                 waveform: sound.waveform,
                                 decay: sound.decay)
            return base.map { $0 * level.gain }
        }
    }
}
