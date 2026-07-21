import Foundation
import Atomics

/// UI에 전달되는 박자 스냅샷입니다.
struct BeatSnapshot: Equatable {
    let sequence: UInt64
    let beatIndex: Int
    let isAccent: Bool
}

/// 오디오 스레드 → UI 스레드로 박자 정보를 전달하는 락프리 채널입니다.
///
/// 하나의 UInt64에 [sequence:47 | beatIndex:16 | accent:1]를 팩킹해
/// 단일 atomic store/load로 torn read 없이 전달합니다.
final class BeatEventChannel {
    private let packed = ManagedAtomic<UInt64>(0)

    private static let accentBits: UInt64 = 1
    private static let beatIndexShift: UInt64 = 1
    private static let beatIndexMask: UInt64 = 0xFFFF // 16비트
    private static let sequenceShift: UInt64 = 17

    /// 오디오 스레드에서 호출됩니다. 락프리 store만 수행합니다.
    func publish(beatIndex: Int, isAccent: Bool) {
        let current = packed.load(ordering: .relaxed)
        let sequence = (current >> Self.sequenceShift) &+ 1
        let accent: UInt64 = isAccent ? 1 : 0
        let idx = UInt64(beatIndex) & Self.beatIndexMask
        let newValue = (sequence << Self.sequenceShift)
            | (idx << Self.beatIndexShift)
            | accent
        packed.store(newValue, ordering: .relaxed)
    }

    /// UI 스레드에서 호출됩니다. 락프리 load만 수행합니다.
    func latest() -> BeatSnapshot {
        let value = packed.load(ordering: .relaxed)
        let sequence = value >> Self.sequenceShift
        let beatIndex = Int((value >> Self.beatIndexShift) & Self.beatIndexMask)
        let isAccent = (value & Self.accentBits) == 1
        return BeatSnapshot(sequence: sequence, beatIndex: beatIndex, isAccent: isAccent)
    }
}
