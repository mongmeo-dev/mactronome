import Foundation

/// 클릭 사운드를 코드로 생성합니다. (강박/약박)
struct ClickSynth {
    struct ClickBuffers {
        let accent: [Float]
        let normal: [Float]
    }

    /// 지수 감쇠 사인파 클릭 한 개를 생성합니다.
    static func makeClick(sampleRate: Double, frequency: Double, durationSeconds: Double) -> [Float] {
        let count = Int(sampleRate * durationSeconds)
        guard count > 0 else { return [] }
        var samples = [Float](repeating: 0, count: count)
        let decay = 25.0 / durationSeconds // 지속시간 내 충분히 감쇠
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let envelope = exp(-decay * t)
            let value = sin(2.0 * Double.pi * frequency * t) * envelope
            samples[i] = Float(value)
        }
        return samples
    }

    /// 강박(고음)/약박(저음) 버퍼 쌍을 생성합니다.
    static func make(sampleRate: Double) -> ClickBuffers {
        let accent = makeClick(sampleRate: sampleRate, frequency: 1500, durationSeconds: 0.02)
        let normal = makeClick(sampleRate: sampleRate, frequency: 1000, durationSeconds: 0.02)
        return ClickBuffers(accent: accent, normal: normal)
    }

    /// 강세 레벨 0~3의 클릭 버퍼 배열을 생성합니다. 레벨 0(mute)은 무음입니다.
    static func makeLevelBuffers(sampleRate: Double) -> [[Float]] {
        return AccentLevel.allCases.map { level in
            guard level.gain > 0 else {
                // 무음: duration만큼 0으로 채운 버퍼
                let count = Int(sampleRate * 0.02)
                return [Float](repeating: 0, count: count)
            }
            let base = makeClick(sampleRate: sampleRate, frequency: level.frequency, durationSeconds: 0.02)
            return base.map { $0 * level.gain }
        }
    }
}
