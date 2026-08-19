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
    private var lastFiredBeat = -1   // 직전에 발화한 펄스의 소속 beat

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func setFramesPerBeat(_ frames: Int) {
        framesPerBeatAtomic.store(max(1, frames), ordering: .relaxed)
    }

    func reset() {
        framesUntilNextPulse = 0
        pulseIndex = 0
        lastFiredBeat = -1
        activePlan = grid.current()
    }

    /// 박 경계에서 대기 중인 최신 plan을 채택합니다.
    ///
    /// 정책: "다음 박(beat) 경계부터 반영".
    /// 지금 막 `beat`번째 박을 시작하려는 시점이며, 여기서 grid의 최신 plan을 읽어
    /// 그 박에 해당하는 위치(pulseIndex)로 이어서 재생해야 합니다.
    ///
    /// 구현 시 고려할 것:
    /// - `grid.current()`로 최신 plan을 읽습니다(할당·락 없음, 실시간 안전).
    /// - 새 plan은 이전 plan과 pulseCount·beat 수가 다를 수 있습니다.
    ///   따라서 `pulseIndex`를 새 plan 기준으로 재해석해야 합니다.
    /// - 새 plan에서 `beat`번째 박이 존재하면 그 박의 첫 펄스로 이어갑니다
    ///   (`PulsePlan.firstPulseIndex(ofBeat:)` 활용).
    /// - 새 plan의 박 수가 더 적어 `beat`가 존재하지 않으면 마디 처음(0)으로 감쌉니다.
    ///
    private func applyPlanAtBeatBoundary(beat: Int) {
        let newPlan = grid.current()
        // 새 plan에 해당 beat가 없으면(박 수가 줄어든 경우) 마디 처음으로 감쌉니다.
        let targetBeat = beat <= newPlan.lastBeat ? beat : 0
        activePlan = newPlan
        pulseIndex = newPlan.firstPulseIndex(ofBeat: targetBeat)
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

        // 박 경계에서 최신 plan 반영: 다음에 발화할 펄스가 새로운 beat의 첫 펄스이면
        // (또는 마디 처음이면) 대기 중인 plan을 지금 시점에 맞춰 교체합니다.
        let currentBeat = activePlan.beatBoundaries[pulseIndex % activePlan.pulseCount]
        if currentBeat != lastFiredBeat {
            applyPlanAtBeatBoundary(beat: currentBeat)
        }

        let plan = activePlan
        let idx = pulseIndex % plan.pulseCount
        let level = plan.levels[idx]
        let beatIndex = plan.beatBoundaries[idx]
        let pulseOffset = plan.pulseOffsets[idx]

        framesUntilNextPulse = framesPerPulse(for: plan) - 1
        pulseIndex = (idx + 1) % plan.pulseCount
        lastFiredBeat = beatIndex

        return Tick(didFire: true, pulseIndex: pulseOffset, beatIndex: beatIndex, level: level)
    }
}
