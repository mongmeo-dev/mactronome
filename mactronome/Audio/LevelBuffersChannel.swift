import Foundation
import Atomics

/// 강세 레벨별 클릭 버퍼 세트를 UI→오디오로 전달하는 락프리 SPSC 더블 버퍼입니다.
///
/// 사운드 음색이 재생 중에 바뀌어도, 메인 스레드가 비활성 슬롯에 새 버퍼를 쓰고
/// 인덱스를 스왑하므로 오디오 스레드는 다음 렌더 콜백에서 일관된 세트를 읽습니다.
/// (`PulseGridChannel`과 동일한 패턴)
final class LevelBuffersChannel {
    private var slots: [[[Float]]]
    private let activeIndex = ManagedAtomic<Int>(0)

    init(_ initial: [[Float]]) {
        slots = [initial, initial]
    }

    /// UI 스레드에서 호출됩니다. 비활성 슬롯에 쓰고 인덱스를 스왑합니다.
    func publish(_ buffers: [[Float]]) {
        let active = activeIndex.load(ordering: .relaxed)
        let inactive = 1 - active
        slots[inactive] = buffers
        activeIndex.store(inactive, ordering: .releasing)
    }

    /// 오디오 스레드에서 호출됩니다. 현재 활성 슬롯을 반환합니다(렌더 콜백당 1회 권장).
    func current() -> [[Float]] {
        let active = activeIndex.load(ordering: .acquiring)
        return slots[active]
    }
}
