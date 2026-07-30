// metronome/View/Theme.swift
import SwiftUI

/// 디자인 핸드오프(디자인 6a)의 컬러/타이포/스페이싱/라운드 토큰을 담습니다.
/// 뷰 코드에서는 매직 리터럴 대신 이 토큰을 참조합니다.
enum Theme {

    // MARK: - Colors

    enum Colors {
        /// 윈도우 배경
        static let bg = Color.dynamicHex(0xFAFAF9, 0x1E1D1B)
        /// 패널 배경
        static let panel = Color.dynamicHex(0xF1F0ED, 0x2A2825)
        /// 잉크(주 텍스트/강박)
        static let ink = Color.dynamicHex(0x1C1B19, 0xEDECE8)
        /// 보조 텍스트. 라이트/다크 모두 panel 배경 기준 WCAG AA(4.5:1)를 넘도록 잡았습니다.
        /// (라이트 약 7.5:1, 다크 약 5.8:1)
        static let mut = Color.dynamicHex(0x1C1B19, 0xEDECE8, lightOpacity: 0.78, darkOpacity: 0.62)
        /// 약보조 텍스트. 10~12pt 캡션에도 쓰이므로 AA 하한을 지킵니다.
        /// (라이트 약 5.0:1, 다크 약 4.8:1)
        static let mut2 = Color.dynamicHex(0x1C1B19, 0xEDECE8, lightOpacity: 0.66, darkOpacity: 0.54)
        /// 경계선
        static let bd = Color.dynamicHex(0x1C1B19, 0xFFFFFF, lightOpacity: 0.14, darkOpacity: 0.18)

        /// 액센트(슬레이트 블루). 다크에서는 대비를 위해 밝게.
        static let acc = Color.dynamicHex(0x677689, 0x93A2B5)
        /// 액센트 소프트(알파)
        static let accSoft = Color.dynamicHex(0x677689, 0x93A2B5, lightOpacity: 0.12, darkOpacity: 0.24)

        /// 약박 실선 경계. 조작 대상 윤곽이라 비텍스트 대비 3:1 이상을 확보합니다.
        static let barWeakBorder = Color.dynamicHex(0x1C1B19, 0xFFFFFF, lightOpacity: 0.5, darkOpacity: 0.4)

        /// 데스크(윈도우 바깥)
        static let desk = Color.dynamicHex(0xE9E7E2, 0x141311)

        /// 타이틀바 그라디언트 상/하
        static let titleBarTop = Color.dynamicHex(0xF3F2EF, 0x2C2A27)
        static let titleBarBottom = Color.dynamicHex(0xECEAE6, 0x242320)

        /// 올라온 표면(선택된 칩/타일, 라운드 버튼). 다크에서 흰색을 그대로 쓰면
        /// 그 위의 ink 텍스트가 1.2:1 로 사라지므로 반드시 이 토큰을 사용합니다.
        static let surfaceRaised = Color.dynamicHex(0xFFFFFF, 0x3A3733)
        /// acc 를 배경으로 깔았을 때의 전경색. 다크의 acc 는 밝은 슬레이트라
        /// 흰 글자(2.6:1)가 아니라 어두운 글자(약 7:1)를 올려야 합니다.
        static let onAccent = Color.dynamicHex(0xFFFFFF, 0x141311)

        /// 오류 강조색. 배경(bg/dangerSoft) 위에서 AA 를 만족하도록 명도를 잡았습니다.
        static let danger = Color.dynamicHex(0xB3261E, 0xF2B8B5)
        /// 오류 배너 배경.
        static let dangerSoft = Color.dynamicHex(0xFCEEEE, 0x3B2523)

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
        /// 컴팩트(미니) 모드 창 폭입니다.
        static let compactWindowWidth: CGFloat = 260
        static let contentPadding = EdgeInsets(top: 24, leading: 30, bottom: 28, trailing: 30)
        /// 시스템 타이틀바(hiddenTitleBar)와 같은 높이로 맞춥니다.
        static let titleBarHeight: CGFloat = 28
        /// 시스템 신호등 버튼이 차지하는 좌측 영역 폭입니다.
        static let trafficLightInset: CGFloat = 78
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

    /// 라이트/다크 외관에 따라 다른 hex를 해석하는 다이내믹 컬러입니다.
    /// NSColor 다이내믹 프로바이더로 만들어 시스템/앱 외관 전환에 자동 반응합니다.
    static func dynamicHex(_ light: UInt32, _ dark: UInt32,
                           lightOpacity: Double = 1, darkOpacity: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let color = Color(hex: isDark ? dark : light, opacity: isDark ? darkOpacity : lightOpacity)
            return NSColor(color)
        })
    }
}

extension Font {
    /// 탭ular figures 를 쓰는 모노스페이스 폰트(SF Mono / .monospaced).
    static func monoTabular(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
