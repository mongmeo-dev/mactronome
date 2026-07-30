import Foundation

/// 전체 화면 비주얼 플래시의 점멸률을 제한하는 순수 정책입니다.
///
/// 이전에는 펄스마다 창 전체를 액센트 색으로 덮었기 때문에
/// 300 BPM × 6잇단에서 초당 30회 전체 화면 점멸이 발생했습니다.
/// 이는 WCAG 2.3.1(초당 3회 이하)을 크게 벗어나는 광과민성 발작 위험 구간입니다.
///
/// 정책은 두 단계로 점멸률을 낮춥니다.
/// 1. 분할 펄스는 무시하고 박(beat) 시작에서만 점멸합니다.
/// 2. 그래도 빠른 구간(고 BPM)에서는 최소 간격을 강제합니다.
///
/// 분할 단위 피드백은 악센트 바의 국소 하이라이트가 계속 담당하므로,
/// 전체 화면 점멸만 제한해도 시각적 정보량은 유지됩니다.
struct FlashPolicy {

    /// WCAG 2.3.1 을 만족하기 위한 점멸 간 최소 간격입니다(초당 3회).
    static let minimumInterval: TimeInterval = 1.0 / 3.0

    /// 마지막으로 점멸을 허용한 시각입니다. 아직 없으면 nil.
    private(set) var lastFlashTime: TimeInterval?

    init() {}

    /// 이번 펄스에서 전체 화면 점멸을 허용할지 판단합니다.
    /// 허용하는 경우에만 내부 시각을 갱신합니다.
    ///
    /// - Parameters:
    ///   - time: 현재 시각(단조 증가 가정).
    ///   - isBeatStart: 박의 첫 펄스인지 여부. false면 항상 거부합니다.
    mutating func shouldFlash(at time: TimeInterval, isBeatStart: Bool) -> Bool {
        guard isBeatStart else { return false }
        if let last = lastFlashTime, time - last < Self.minimumInterval {
            return false
        }
        lastFlashTime = time
        return true
    }

    /// 재생 시작/정지 시 호출해 다음 점멸이 즉시 나가도록 합니다.
    mutating func reset() {
        lastFlashTime = nil
    }

    /// 점멸 피크 불투명도입니다.
    /// 모션 감소가 켜져 있으면 강한 명멸 대신 은은한 단일 값으로 낮춥니다.
    static func peakOpacity(isAccent: Bool, reduceMotion: Bool) -> Double {
        if reduceMotion { return 0.10 }
        return isAccent ? 0.32 : 0.16
    }

    /// 점멸이 사라지는 데 걸리는 시간입니다.
    /// 모션 감소 시에는 급격한 명멸을 피하기 위해 더 완만하게 사라집니다.
    static func fadeDuration(reduceMotion: Bool) -> Double {
        reduceMotion ? 0.28 : 0.16
    }
}
