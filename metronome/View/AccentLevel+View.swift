// metronome/View/AccentLevel+View.swift
import SwiftUI

/// 악센트 바 렌더링에 필요한 시각 속성입니다.
/// `AccentLevel` 열거형 선언 자체는 Model/AccentLevel.swift 에 있으며(오디오 게인/주파수/next),
/// 여기서는 뷰 전용 계산 속성만 확장으로 덧붙입니다.
extension AccentLevel {

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
