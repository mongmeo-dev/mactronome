import Foundation

/// 연속 입력(스크롤 델타 등)을 정수 스텝으로 바꾸는 누적기입니다.
///
/// 스크롤 휠은 한 번 굴릴 때 1pt 미만부터 수십 pt 까지 제각각인 델타를 보냅니다.
/// 매 이벤트를 반올림해 버리면 천천히 굴릴 때 아무 반응이 없거나
/// 빠르게 굴릴 때 값이 튀므로, 스텝에 못 미치는 잔여분을 남겨 둡니다.
struct StepAccumulator {

    /// 한 스텝에 해당하는 입력량입니다.
    let pointsPerStep: Double

    /// 아직 스텝으로 환산되지 않고 남은 입력량입니다.
    private(set) var remainder: Double = 0

    init(pointsPerStep: Double) {
        // 0 이하가 들어오면 나눗셈이 발산하므로 하한을 둡니다.
        self.pointsPerStep = max(0.0001, pointsPerStep)
    }

    /// 델타를 누적하고, 이번에 발생한 정수 스텝 수를 반환합니다.
    /// 스텝에 못 미치는 잔여분은 다음 호출로 이월됩니다.
    mutating func consume(_ delta: Double) -> Double {
        guard delta.isFinite else { return 0 }
        remainder += delta
        let steps = (remainder / pointsPerStep).rounded(.towardZero)
        guard steps != 0 else { return 0 }
        remainder -= steps * pointsPerStep
        return steps
    }

    /// 누적치를 비웁니다(제스처 종료 등).
    mutating func reset() {
        remainder = 0
    }
}
