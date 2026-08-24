import Foundation

/// 클릭 합성에 쓰는 파형 종류입니다.
enum Waveform {
    case sine
    case square
}

/// 코드로 합성 가능한 클릭 음색 프리셋입니다.
/// 각 음색은 파형/지속시간/감쇠와 강세 레벨별 기준 주파수를 정의합니다.
enum ClickSound: String, CaseIterable, Identifiable, Codable {
    case beep
    case digital
    case clave

    var id: String { rawValue }

    /// 사운드 피커에 표시하는 이름입니다.
    var displayName: String {
        switch self {
        case .beep: return "Beep"
        case .digital: return "Digital"
        case .clave: return "Clave"
        }
    }

    var waveform: Waveform {
        switch self {
        case .beep: return .sine
        case .digital: return .square
        case .clave: return .sine
        }
    }

    /// 클릭 한 개의 지속시간(초)입니다.
    var duration: Double {
        switch self {
        case .beep: return 0.05
        case .digital: return 0.03
        case .clave: return 0.03
        }
    }

    /// 지속시간 내 지수 감쇠 강도입니다(클수록 빠르게 사라짐).
    var decay: Double {
        switch self {
        case .beep: return 12
        case .digital: return 16
        case .clave: return 22
        }
    }

    /// 강세 레벨별 기준 주파수입니다. 강박일수록 높은 음이 되도록 배치합니다.
    func frequency(for level: AccentLevel) -> Double {
        switch self {
        case .beep:
            switch level { case .strong: return 1320; case .medium: return 1100; default: return 880 }
        case .digital:
            switch level { case .strong: return 2000; case .medium: return 1500; default: return 1000 }
        case .clave:
            switch level { case .strong: return 2500; case .medium: return 2200; default: return 1900 }
        }
    }
}
