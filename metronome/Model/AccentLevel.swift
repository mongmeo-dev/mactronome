import Foundation

/// 펄스의 강세 레벨입니다. 0=무음, 1=약박, 2=중강, 3=강박.
enum AccentLevel: Int, CaseIterable, Identifiable {
    case mute = 0
    case weak = 1
    case medium = 2
    case strong = 3

    var id: Int { rawValue }

    /// 접근성 레이블/컨텍스트 메뉴에 쓰는 표시 이름입니다.
    var displayName: String {
        switch self {
        case .mute: return "무음"
        case .weak: return "약박"
        case .medium: return "중강"
        case .strong: return "강박"
        }
    }

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

    /// 다음 강세 레벨로 순환합니다(강박 다음은 무음으로 랩어라운드).
    var next: AccentLevel {
        AccentLevel(rawValue: (rawValue + 1) % 4)!
    }
}
