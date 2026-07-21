// metronome/View/AccentLevel.swift
import SwiftUI

/// 악센트 바 한 칸의 강세 레벨입니다. (0=무음, 1=약박, 2=중강, 3=강박)
/// 클릭 시 (level + 1) % 4 로 순환합니다.
enum AccentLevel: Int {
    case mute = 0    // 무음
    case weak = 1    // 약박
    case medium = 2  // 중강
    case strong = 3  // 강박

    /// 다음 강세 레벨(순환).
    var next: AccentLevel { AccentLevel(rawValue: (rawValue + 1) % 4) ?? .mute }

    /// 메인 바(첫 펄스, width 28) 높이.
    var mainHeight: CGFloat {
        switch self {
        case .mute: return 12
        case .weak: return 26
        case .medium: return 44
        case .strong: return 60
        }
    }

    /// 서브 바(분할 펄스, width 11) 높이.
    var subHeight: CGFloat {
        switch self {
        case .mute: return 10
        case .weak: return 18
        case .medium: return 30
        case .strong: return 40
        }
    }

    /// 채움 색.
    var fill: Color {
        switch self {
        case .mute, .weak: return .clear
        case .medium: return Theme.Colors.accSoft
        case .strong: return Theme.Colors.ink
        }
    }

    /// 테두리 색.
    var borderColor: Color {
        switch self {
        case .mute: return Theme.Colors.mut2
        case .weak: return Theme.Colors.barWeakBorder
        case .medium: return Theme.Colors.acc
        case .strong: return Theme.Colors.ink
        }
    }

    /// 무음은 점선, 나머지는 실선.
    var isDashed: Bool { self == .mute }

    static let borderWidth: CGFloat = 1.5
}
