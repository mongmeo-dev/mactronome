import Foundation

/// 탭 간격으로 BPM을 추정하는 순수 로직입니다.
struct TapTempo {
    /// 이 시간(초) 이상 공백이면 윈도우를 리셋합니다.
    private let resetGap: TimeInterval = 2.0
    /// BPM 평균에 사용하는 최대 간격 수입니다.
    private let maxIntervals = 4

    private var lastTapTime: TimeInterval?
    private var intervals: [TimeInterval] = []

    mutating func tap(at time: TimeInterval) -> Double? {
        defer { lastTapTime = time }

        guard let last = lastTapTime else {
            return nil // 첫 탭: 간격 없음
        }

        let interval = time - last
        if interval > resetGap {
            intervals.removeAll()
            return nil // 공백이 너무 큼: 새 측정 시작
        }

        intervals.append(interval)
        if intervals.count > maxIntervals {
            intervals.removeFirst()
        }

        let avg = intervals.reduce(0, +) / Double(intervals.count)
        guard avg > 0 else { return nil }
        return 60.0 / avg
    }

    mutating func reset() {
        lastTapTime = nil
        intervals.removeAll()
    }
}
