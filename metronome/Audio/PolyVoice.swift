import Foundation
import Atomics

/// 폴리리듬 보조 보이스입니다. 한 마디(framesPerBar)를 K개의 균등 펄스로 나눠 발화하며,
/// 매 마디 경계에서 프레임 카운터를 0으로 재정렬해 주 보이스와 **드리프트 없이** 고정됩니다.
///
/// 실시간 안전: advanceOneFrame은 할당·락이 없고, 설정은 atomic으로 주고받습니다.
final class PolyVoice {
    /// 마디당 펄스 수(0 또는 1 이하 = 비활성).
    private let pulseCountAtomic = ManagedAtomic<Int>(0)
    /// 한 마디의 프레임 수.
    private let framesPerBarAtomic = ManagedAtomic<Int>(1)

    // 오디오 스레드 전용 상태.
    private var frameInBar = 0
    private var nextPulse = 0

    var isEnabled: Bool { pulseCountAtomic.load(ordering: .relaxed) > 1 }

    func setPulseCount(_ count: Int) {
        pulseCountAtomic.store(max(0, count), ordering: .relaxed)
    }

    func setFramesPerBar(_ frames: Int) {
        framesPerBarAtomic.store(max(1, frames), ordering: .relaxed)
    }

    /// 재생 시작 시 주 보이스와 같은 프레임(0)에서 함께 출발하도록 재설정합니다.
    func reset() {
        frameInBar = 0
        nextPulse = 0
    }

    /// 프레임 1개 진행. 이번 프레임이 폴리 펄스 경계면 true.
    func advanceOneFrame() -> Bool {
        let count = pulseCountAtomic.load(ordering: .relaxed)
        guard count > 1 else { return false }
        let fpb = max(1, framesPerBarAtomic.load(ordering: .relaxed))

        var fired = false
        if nextPulse < count {
            // 펄스 i의 목표 프레임 = floor(i * framesPerBar / count).
            let target = Int((Int64(nextPulse) * Int64(fpb)) / Int64(count))
            if frameInBar >= target {
                fired = true
                nextPulse += 1
            }
        }

        frameInBar += 1
        if frameInBar >= fpb {
            // 마디 경계: 재정렬(누적 반올림 오차 제거 → 주 보이스와 고정).
            frameInBar = 0
            nextPulse = 0
        }
        return fired
    }
}
