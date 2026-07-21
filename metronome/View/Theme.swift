// metronome/View/Theme.swift
import SwiftUI

/// 디자인 핸드오프(디자인 6a)의 컬러/타이포/스페이싱/라운드 토큰을 담습니다.
/// 뷰 코드에서는 매직 리터럴 대신 이 토큰을 참조합니다.
enum Theme {

    // MARK: - Colors

    enum Colors {
        /// 윈도우 배경 #fafaf9
        static let bg = Color(hex: 0xFAFAF9)
        /// 패널 배경 #f1f0ed
        static let panel = Color(hex: 0xF1F0ED)
        /// 잉크(주 텍스트/강박) #1c1b19
        static let ink = Color(hex: 0x1C1B19)
        /// 보조 텍스트 rgba(28,27,25,.5)
        static let mut = Color(hex: 0x1C1B19, opacity: 0.5)
        /// 약보조 텍스트 rgba(28,27,25,.35)
        static let mut2 = Color(hex: 0x1C1B19, opacity: 0.35)
        /// 경계선 rgba(28,27,25,.09)
        static let bd = Color(hex: 0x1C1B19, opacity: 0.09)

        /// 액센트 oklch(0.56 0.035 255) → sRGB #677689 (슬레이트 블루)
        static let acc = Color(hex: 0x677689)
        /// 액센트 12% 알파 (acc-soft)
        static let accSoft = Color(hex: 0x677689, opacity: 0.12)

        /// 약박 실선 경계 rgba(28,27,25,.28)
        static let barWeakBorder = Color(hex: 0x1C1B19, opacity: 0.28)

        /// 데스크(윈도우 바깥) #e9e7e2
        static let desk = Color(hex: 0xE9E7E2)

        /// 신호등
        static let trafficRed = Color(hex: 0xFF5F57)
        static let trafficYellow = Color(hex: 0xFEBC2E)
        static let trafficGreen = Color(hex: 0x28C840)
    }

    // MARK: - Radius

    enum Radius {
        static let bar: CGFloat = 6
        static let chip: CGFloat = 9        // 칩 / 라운드 버튼
        static let control: CGFloat = 10    // 사운드 / 시작 / TAP
        static let timeSigCard: CGFloat = 11
        static let window: CGFloat = 12
    }

    // MARK: - Layout

    enum Layout {
        static let windowWidth: CGFloat = 452
        static let contentPadding = EdgeInsets(top: 24, leading: 30, bottom: 28, trailing: 30)
        static let titleBarHeight: CGFloat = 40
    }

    // MARK: - Motion

    enum Motion {
        static let bar = Animation.easeInOut(duration: 0.18)
        static let chip = Animation.easeInOut(duration: 0.15)
    }
}

extension Color {
    /// 0xRRGGBB 형태의 정수 리터럴로 sRGB 컬러를 생성합니다.
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

extension Font {
    /// 탭ular figures 를 쓰는 모노스페이스 폰트(SF Mono / .monospaced).
    static func monoTabular(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
