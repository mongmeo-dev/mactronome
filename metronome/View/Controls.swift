// metronome/View/Controls.swift
import SwiftUI

/// 올라온 표면 위의 라운드 사각형 버튼(−/+ 등). 크기와 폰트 사이즈를 지정합니다.
struct RoundButton: View {
    let symbol: String
    var size: CGFloat = 38
    var fontSize: CGFloat = 20
    var background: Color = Theme.Colors.surfaceRaised
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
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "−" ? "감소" : (symbol == "+" ? "증가" : symbol))
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
        .buttonStyle(.plain)
        .animation(Theme.Motion.chip, value: isOn)
        .accessibilityLabel("분모 \(value)")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
