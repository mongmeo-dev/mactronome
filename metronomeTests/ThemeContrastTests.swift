import XCTest
import SwiftUI
import AppKit
@testable import metronome

/// Theme 색상 토큰의 WCAG 대비를 라이트/다크 양쪽에서 검증합니다.
///
/// 배경: 다크 모드에서 `Color.white` 를 그대로 배경으로 쓰던 시절
/// `ink`(#EDECE8) 텍스트가 1.2:1 로 사실상 보이지 않았고,
/// 라이트 모드 보조 텍스트(`mut`/`mut2`)도 2~3:1 로 AA 미달이었습니다.
/// 토큰을 되돌리면 이 테스트가 깨지도록 고정합니다.
@MainActor
final class ThemeContrastTests: XCTestCase {

    // MARK: - WCAG 계산 도우미

    /// 지정한 외관에서 SwiftUI Color 를 sRGB NSColor 로 해석합니다.
    private func resolve(_ color: Color, dark: Bool) -> NSColor {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        var resolved = NSColor.black
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(color).usingColorSpace(.sRGB) ?? .black
        }
        return resolved
    }

    /// 알파를 가진 전경색을 불투명 배경 위에 합성합니다.
    private func composite(_ fg: NSColor, over bg: NSColor) -> (Double, Double, Double) {
        let a = Double(fg.alphaComponent)
        return (Double(fg.redComponent) * a + Double(bg.redComponent) * (1 - a),
                Double(fg.greenComponent) * a + Double(bg.greenComponent) * (1 - a),
                Double(fg.blueComponent) * a + Double(bg.blueComponent) * (1 - a))
    }

    /// WCAG 상대 휘도입니다.
    private func luminance(_ rgb: (Double, Double, Double)) -> Double {
        func lin(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(rgb.0) + 0.7152 * lin(rgb.1) + 0.0722 * lin(rgb.2)
    }

    /// 전경/배경 토큰의 대비비를 계산합니다(전경 알파는 배경 위에 합성).
    private func contrast(_ fg: Color, on bg: Color, dark: Bool) -> Double {
        let bgColor = resolve(bg, dark: dark)
        let bgRGB = (Double(bgColor.redComponent), Double(bgColor.greenComponent), Double(bgColor.blueComponent))
        let fgRGB = composite(resolve(fg, dark: dark), over: bgColor)
        let l1 = luminance(fgRGB), l2 = luminance(bgRGB)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// 대비가 하한 이상인지 단언합니다(실패 시 실제 수치를 남깁니다).
    private func assertContrast(_ fg: Color, on bg: Color, dark: Bool,
                                atLeast minimum: Double, _ label: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        let ratio = contrast(fg, on: bg, dark: dark)
        XCTAssertGreaterThanOrEqual(
            ratio, minimum,
            "\(label) [\(dark ? "dark" : "light")] 대비 \(String(format: "%.2f", ratio)):1 < \(minimum):1",
            file: file, line: line
        )
    }

    // MARK: - 본문/보조 텍스트 (AA 4.5:1)

    // MARK: - 해석기 자체 검증

    /// 아래 대비 단언들이 의미를 가지려면 `resolve` 가 외관별로 다른 색을 돌려줘야 합니다.
    /// (다이내믹 컬러가 해석되지 않으면 dark 케이스가 전부 무의미해집니다.)
    func test_resolve_honorsAppearance() {
        let light = resolve(Theme.Colors.bg, dark: false)
        let dark = resolve(Theme.Colors.bg, dark: true)
        XCTAssertGreaterThan(Double(light.redComponent), 0.9, "라이트 배경은 밝아야 합니다")
        XCTAssertLessThan(Double(dark.redComponent), 0.2, "다크 배경은 어두워야 합니다")
    }

    /// 알파 합성이 실제로 동작하는지 확인합니다(mut 은 ink 보다 배경에 가까워야 함).
    func test_composite_appliesAlpha() {
        let panel = resolve(Theme.Colors.panel, dark: false)
        let mut = composite(resolve(Theme.Colors.mut, dark: false), over: panel)
        let ink = composite(resolve(Theme.Colors.ink, dark: false), over: panel)
        XCTAssertGreaterThan(luminance(mut), luminance(ink),
                             "라이트에서 mut 은 ink 보다 밝아야(연해야) 합니다")
    }

    func test_ink_onBackgrounds_meetsAA() {
        for dark in [false, true] {
            assertContrast(Theme.Colors.ink, on: Theme.Colors.bg, dark: dark, atLeast: 4.5, "ink on bg")
            assertContrast(Theme.Colors.ink, on: Theme.Colors.panel, dark: dark, atLeast: 4.5, "ink on panel")
        }
    }

    func test_mutedText_onPanel_meetsAA() {
        for dark in [false, true] {
            assertContrast(Theme.Colors.mut, on: Theme.Colors.panel, dark: dark, atLeast: 4.5, "mut on panel")
            assertContrast(Theme.Colors.mut, on: Theme.Colors.bg, dark: dark, atLeast: 4.5, "mut on bg")
        }
    }

    /// mut2 는 10~12pt 캡션(분할 타일 이름, 템포 캡션)에 쓰이므로 동일하게 AA 를 요구합니다.
    func test_weakMutedText_meetsAA() {
        for dark in [false, true] {
            assertContrast(Theme.Colors.mut2, on: Theme.Colors.panel, dark: dark, atLeast: 4.5, "mut2 on panel")
            assertContrast(Theme.Colors.mut2, on: Theme.Colors.bg, dark: dark, atLeast: 4.5, "mut2 on bg")
        }
    }

    /// 텍스트 계층이 뒤집히지 않아야 합니다(ink > mut > mut2 순으로 또렷).
    func test_textHierarchy_isPreserved() {
        for dark in [false, true] {
            let ink = contrast(Theme.Colors.ink, on: Theme.Colors.panel, dark: dark)
            let mut = contrast(Theme.Colors.mut, on: Theme.Colors.panel, dark: dark)
            let mut2 = contrast(Theme.Colors.mut2, on: Theme.Colors.panel, dark: dark)
            XCTAssertGreaterThan(ink, mut, "ink 는 mut 보다 또렷해야 합니다 [\(dark ? "dark" : "light")]")
            XCTAssertGreaterThan(mut, mut2, "mut 은 mut2 보다 또렷해야 합니다 [\(dark ? "dark" : "light")]")
        }
    }

    // MARK: - 올라온 표면 위 (선택 칩/타일, ± 버튼)

    func test_inkOnRaisedSurface_meetsAA() {
        for dark in [false, true] {
            assertContrast(Theme.Colors.ink, on: Theme.Colors.surfaceRaised, dark: dark,
                           atLeast: 4.5, "ink on surfaceRaised")
        }
    }

    /// TAP 버튼: 올라온 표면 위의 액센트 텍스트.
    func test_accentOnRaisedSurface_meetsAA() {
        for dark in [false, true] {
            assertContrast(Theme.Colors.acc, on: Theme.Colors.surfaceRaised, dark: dark,
                           atLeast: 4.5, "acc on surfaceRaised")
        }
    }

    // MARK: - 오류 배너

    /// 오류 배너의 아이콘/본문 텍스트도 배너 배경 위에서 읽혀야 합니다.
    func test_errorBanner_meetsAA() {
        for dark in [false, true] {
            assertContrast(Theme.Colors.danger, on: Theme.Colors.dangerSoft, dark: dark,
                           atLeast: 4.5, "danger on dangerSoft")
            assertContrast(Theme.Colors.ink, on: Theme.Colors.dangerSoft, dark: dark,
                           atLeast: 4.5, "ink on dangerSoft")
            assertContrast(Theme.Colors.mut, on: Theme.Colors.dangerSoft, dark: dark,
                           atLeast: 4.5, "mut on dangerSoft")
        }
    }

    // MARK: - 액센트 배경 (시작 버튼)

    func test_onAccent_meetsAA() {
        for dark in [false, true] {
            assertContrast(Theme.Colors.onAccent, on: Theme.Colors.acc, dark: dark,
                           atLeast: 4.5, "onAccent on acc")
        }
    }

    // MARK: - 비텍스트 컨트롤 윤곽 (3:1)

    /// 약박 바의 테두리는 조작 대상의 유일한 시각 경계라 3:1 이상이어야 합니다.
    func test_barWeakBorder_meetsNonTextMinimum() {
        for dark in [false, true] {
            assertContrast(Theme.Colors.barWeakBorder, on: Theme.Colors.bg, dark: dark,
                           atLeast: 3.0, "barWeakBorder on bg")
        }
    }
}
