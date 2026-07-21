import Foundation
import Atomics

/// 펄스(박자의 하위 분할) 단위로 발화하는 실시간 안전 스케줄러입니다.
final class PulseScheduler {
    struct Tick {
        let didFire: Bool
        let pulseIndex: Int
        let beatIndex: Int
        let level: Int
    }

    let grid = PulseGridChannel()
    private let sampleRate: Double
    private let framesPerBeatAtomic = ManagedAtomic<Int>(22050)

    // 오디오 스레드 전용 상태.
    private var framesUntilNextPulse = 0
    private var pulseIndex = 0
    private var activePlan = PulsePlan.default

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func setFramesPerBeat(_ frames: Int) {
        framesPerBeatAtomic.store(max(1, frames), ordering: .relaxed)
    }

    func reset() {
        framesUntilNextPulse = 0
        pulseIndex = 0
        activePlan = grid.current()
    }

    private func framesPerPulse(for plan: PulsePlan) -> Int {
        let fpb = framesPerBeatAtomic.load(ordering: .relaxed)
        return max(1, fpb / max(1, plan.pulsesPerBeat))
    }

    /// 프레임 1개 진행. 펄스 경계면 didFire=true. 실시간 안전(할당·락 없음).
    func advanceOneFrame() -> Tick {
        if framesUntilNextPulse > 0 {
            framesUntilNextPulse -= 1
            return Tick(didFire: false, pulseIndex: pulseIndex, beatIndex: 0, level: 0)
        }

        // 시퀀스 시작(pulseIndex 0)에서 최신 plan 반영.
        if pulseIndex == 0 {
            activePlan = grid.current()
        }
        let plan = activePlan
        let idx = pulseIndex % plan.pulseCount
        let level = plan.levels[idx]
        let beatIndex = plan.beatBoundaries[idx]

        framesUntilNextPulse = framesPerPulse(for: plan) - 1
        pulseIndex = (idx + 1) % plan.pulseCount

        return Tick(didFire: true, pulseIndex: idx, beatIndex: beatIndex, level: level)
    }
}
