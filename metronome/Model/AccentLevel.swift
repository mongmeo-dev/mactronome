import Foundation

/// 펄스의 강세 레벨입니다. 0=무음, 1=약박, 2=중강, 3=강박.
enum AccentLevel: Int, CaseIterable {
    case mute = 0
    case weak = 1
    case medium = 2
    case strong = 3

    /// 레벨별 재생 게인입니다. 무음은 0.
    var gain: Float {
        switch self {
        case .mute: return 0
        case .weak: return 0.35
        case .medium: return 0.6
        case .strong: return 1.0
        }
    }

    /// 레벨별 클릭 주파수입니다. 강박일수록 높은 음.
    var frequency: Double {
        switch self {
        case .mute: return 1000   // 사용 안 함(gain 0)
        case .weak: return 1000
        case .medium: return 1250
        case .strong: return 1600
        }
    }
}
