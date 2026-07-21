import Foundation
import Atomics

/// UI의 grid를 오디오가 읽기 쉬운 평탄 펄스 시퀀스로 변환한 불변 계획입니다.
struct PulsePlan {
    let levels: [Int]          // 전체 펄스의 강세 레벨(일렬)
    let beatBoundaries: [Int]  // 각 펄스의 소속 박자 인덱스
    let pulseCount: Int
    let pulsesPerBeat: Int

    init(grid: [[Int]], pulsesPerBeat: Int) {
        var lv: [Int] = []
        var bb: [Int] = []
        for (b, row) in grid.enumerated() {
            for level in row {
                lv.append(level)
                bb.append(b)
            }
        }
        // 빈 grid 방어: 최소 1펄스(무음) 보장
        if lv.isEmpty { lv = [0]; bb = [0] }
        self.levels = lv
        self.beatBoundaries = bb
        self.pulseCount = lv.count
        self.pulsesPerBeat = max(1, pulsesPerBeat)
    }

    static let `default` = PulsePlan(grid: [[3],[1],[2],[1]], pulsesPerBeat: 1)
}

/// 락프리 SPSC 더블 버퍼로 PulsePlan을 UI→오디오 전달합니다.
final class PulseGridChannel {
    private var slots: [PulsePlan]
    private let activeIndex = ManagedAtomic<Int>(0)

    init() {
        slots = [PulsePlan.default, PulsePlan.default]
    }

    /// UI 스레드에서 호출됩니다. 비활성 슬롯에 쓰고 인덱스를 스왑합니다.
    func publish(_ plan: PulsePlan) {
        let active = activeIndex.load(ordering: .relaxed)
        let inactive = 1 - active
        slots[inactive] = plan
        activeIndex.store(inactive, ordering: .releasing)
    }

    /// 오디오 스레드에서 호출됩니다. 현재 활성 슬롯을 반환합니다(할당 없음).
    func current() -> PulsePlan {
        let active = activeIndex.load(ordering: .acquiring)
        return slots[active]
    }
}
