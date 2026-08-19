import Foundation
import Atomics

/// UI에 전달되는 박자 스냅샷입니다.
struct BeatSnapshot: Equatable {
    let sequence: UInt64
    let beatIndex: Int
    let pulseIndex: Int
    let isAccent: Bool
}

/// 오디오 스레드 → UI 스레드로 박자 정보를 전달하는 락프리 채널입니다.
///
/// 하나의 UInt64에 [sequence:39 | beatIndex:16 | pulseIndex:8 | accent:1]를 팩킹해
/// 단일 atomic store/load로 torn read 없이 전달합니다.
final class BeatEventChannel {
    private let packed = ManagedAtomic<UInt64>(0)

    private static let accentBits: UInt64 = 1
    private static let pulseIndexShift: UInt64 = 1
    private static let pulseIndexMask: UInt64 = 0xFF   // 8비트
    private static let beatIndexShift: UInt64 = 9
    private static let beatIndexMask: UInt64 = 0xFFFF  // 16비트
    private static let sequenceShift: UInt64 = 25

    /// 오디오 스레드에서 호출됩니다. 락프리 store만 수행합니다.
    func publish(beatIndex: Int, pulseIndex: Int, isAccent: Bool) {
        let current = packed.load(ordering: .relaxed)
        let sequence = (current >> Self.sequenceShift) &+ 1
        let accent: UInt64 = isAccent ? 1 : 0
        let beat = UInt64(beatIndex) & Self.beatIndexMask
        let pulse = UInt64(pulseIndex) & Self.pulseIndexMask
        let newValue = (sequence << Self.sequenceShift)
            | (beat << Self.beatIndexShift)
            | (pulse << Self.pulseIndexShift)
            | accent
        packed.store(newValue, ordering: .relaxed)
    }

    /// UI 스레드에서 호출됩니다. 락프리 load만 수행합니다.
    func latest() -> BeatSnapshot {
        let value = packed.load(ordering: .relaxed)
        let sequence = value >> Self.sequenceShift
        let beatIndex = Int((value >> Self.beatIndexShift) & Self.beatIndexMask)
        let pulseIndex = Int((value >> Self.pulseIndexShift) & Self.pulseIndexMask)
        let isAccent = (value & Self.accentBits) == 1
        return BeatSnapshot(sequence: sequence, beatIndex: beatIndex, pulseIndex: pulseIndex, isAccent: isAccent)
    }
}
