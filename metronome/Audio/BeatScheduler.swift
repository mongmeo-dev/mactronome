import Foundation
import Atomics

/// 오디오 렌더 콜백 안에서 샘플(프레임) 단위로 박자를 진행하는 실시간 안전 스케줄러입니다.
final class BeatScheduler {
    struct Tick {
        let didFire: Bool
        let beatIndex: Int
        let isAccent: Bool
    }

    private let sampleRate: Double

    // UI 스레드가 store, 오디오 스레드가 load 합니다.
    private let framesPerBeatAtomic = ManagedAtomic<Int>(22050)
    private let beatsPerBarAtomic = ManagedAtomic<Int>(4)

    // 오디오 스레드 전용 상태 (콜백 직렬 실행이라 단일 스레드 접근).
    private var framesUntilNextBeat: Int = 0
    private var currentBeatIndex: Int = 0
    private var activeFramesPerBeat: Int = 22050

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// UI 스레드에서 호출됩니다.
    func setFramesPerBeat(_ frames: Int) {
        framesPerBeatAtomic.store(max(1, frames), ordering: .relaxed)
    }

    /// UI 스레드에서 호출됩니다.
    func setBeatsPerBar(_ count: Int) {
        beatsPerBarAtomic.store(max(1, count), ordering: .relaxed)
    }

    /// 재생 시작 시 호출됩니다. 다음 advanceOneFrame이 즉시 첫 박을 발화합니다.
    func reset() {
        framesUntilNextBeat = 0
        currentBeatIndex = 0
        activeFramesPerBeat = framesPerBeatAtomic.load(ordering: .relaxed)
    }

    /// 프레임 1개를 진행합니다. 박자 경계면 didFire=true. 실시간 안전(할당·락 없음).
    func advanceOneFrame() -> Tick {
        if framesUntilNextBeat > 0 {
            framesUntilNextBeat -= 1
            return Tick(didFire: false, beatIndex: currentBeatIndex, isAccent: false)
        }

        // 박자 경계: 발화한다.
        let beatsPerBar = beatsPerBarAtomic.load(ordering: .relaxed)
        let index = currentBeatIndex % beatsPerBar
        let isAccent = index == 0

        // 다음 박자 간격을 이 경계에서 반영한다.
        activeFramesPerBeat = framesPerBeatAtomic.load(ordering: .relaxed)
        framesUntilNextBeat = activeFramesPerBeat - 1
        currentBeatIndex = (index + 1) % beatsPerBar

        return Tick(didFire: true, beatIndex: index, isAccent: isAccent)
    }
}
