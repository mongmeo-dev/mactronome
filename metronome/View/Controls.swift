// metronome/View/Controls.swift
import SwiftUI
import AppKit

/// 눌림 상태를 시각적으로 알려주는 공용 버튼 스타일입니다.
///
/// `.buttonStyle(.plain)` 은 눌림 렌더링까지 제거하기 때문에,
/// 앱의 모든 커스텀 버튼이 눌러도 아무 변화가 없었습니다.
/// 특히 리듬에 맞춰 연타하는 TAP 버튼에서는 입력이 먹었는지 확인할 방법이
/// 소리밖에 없었습니다.
struct PressableButtonStyle: ButtonStyle {
    /// 눌렀을 때 축소 배율입니다.
    var pressedScale: CGFloat = 0.96
    /// 눌렀을 때 불투명도입니다.
    var pressedOpacity: Double = 0.7

    func makeBody(configuration: Configuration) -> some View {
        PressedLabel(configuration: configuration,
             pressedScale: pressedScale,
             pressedOpacity: pressedOpacity)
    }

    /// 환경값(`accessibilityReduceMotion`)을 구독하려면 실제 View 여야 하므로 분리합니다.
    /// (`Body` 는 ButtonStyle 의 associatedtype 이름이라 사용할 수 없습니다.)
    private struct PressedLabel: View {
        let configuration: PressableButtonStyle.Configuration
        let pressedScale: CGFloat
        let pressedOpacity: Double
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                // 모션 감소 시에는 크기 변화 없이 불투명도만으로 피드백합니다.
                .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1)
                .opacity(configuration.isPressed ? pressedOpacity : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

/// 올라온 표면 위의 라운드 사각형 버튼(−/+ 등). 크기와 폰트 사이즈를 지정합니다.
struct RoundButton: View {
    let symbol: String
    var size: CGFloat = 38
    var fontSize: CGFloat = 20
    var background: Color = Theme.Colors.surfaceRaised
    /// 접근성 레이블입니다. 기호만으로는 "무엇을" 증감하는지 알 수 없으므로
    /// 호출부에서 반드시 맥락을 담은 문구를 넘깁니다.
    let label: String
    /// 마우스 오버 툴팁입니다. 단축키가 있으면 함께 적습니다.
    var hint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                .fill(background)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .strokeBorder(Theme.Colors.bd, lineWidth: 0.5)
                }
                .overlay {
                    Text(symbol)
                        .font(.system(size: fontSize, weight: .regular))
                        .foregroundStyle(Theme.Colors.ink)
                }
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(PressableButtonStyle())
        // 길게 누르고 있으면 반복 실행합니다. BPM 132 → 180 을 48번 클릭하던 것을
        // 누르고 있는 것으로 대체합니다.
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
        .help(hint ?? label)
    }
}

/// 포인터가 뷰 위에 있을 때 스크롤 휠 입력을 값 변화로 전달합니다.
///
/// macOS SwiftUI 에는 스크롤 휠을 받는 수정자가 없고, NSView 를 겹쳐 놓으면
/// 클릭 히트 테스트까지 가로챕니다. 그래서 호버 여부만 추적하고
/// 실제 처리는 로컬 이벤트 모니터로 합니다(다른 입력 경로는 그대로 둡니다).
struct ScrollWheelAdjust: ViewModifier {
    /// 스크롤 델타(위로 굴리면 양수)를 전달받는 클로저입니다.
    let onScroll: (Double) -> Void

    @State private var hovering = false
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onHover { hovering = $0 }
            .onAppear {
                guard monitor == nil else { return }
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                    guard hovering else { return event }
                    onScroll(Double(event.scrollingDeltaY))
                    return nil // 소비했으므로 하위로 흘리지 않습니다.
                }
            }
            .onDisappear {
                if let monitor { NSEvent.removeMonitor(monitor) }
                monitor = nil
            }
    }
}

extension View {
    /// 포인터가 올라가 있을 때 스크롤 휠로 값을 조절할 수 있게 합니다.
    func scrollWheelAdjust(_ onScroll: @escaping (Double) -> Void) -> some View {
        modifier(ScrollWheelAdjust(onScroll: onScroll))
    }
}

/// 분모(2/4/8/16) 선택용 텍스트 칩.
struct DenomChip: View {
    let value: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(value)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(isOn ? Theme.Colors.ink : Theme.Colors.mut)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .fill(isOn ? Theme.Colors.surfaceRaised : Theme.Colors.panel)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                        .strokeBorder(isOn ? Theme.Colors.acc : .clear, lineWidth: 1)
                }
                .shadow(color: .black.opacity(isOn ? 0.09 : 0), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(PressableButtonStyle())
        .animation(Theme.Motion.chip, value: isOn)
        .accessibilityLabel("분모 \(value)")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
