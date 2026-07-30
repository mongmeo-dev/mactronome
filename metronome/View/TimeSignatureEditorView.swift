// metronome/View/TimeSignatureEditorView.swift
import SwiftUI

/// 박자표 편집 패널.
/// 왼쪽 = 분자/막대/분모 스택, 오른쪽 = 분자 스테퍼(1~12) + 분모 칩 그리드(2/4/8/16).
struct TimeSignatureEditorView: View {
    let beatCount: Int
    @Binding var denom: String
    let onAddBeat: () -> Void
    let onRemoveBeat: () -> Void

    private let denomOptions = ["2", "4", "8", "16"]

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            fractionStack

            VStack(alignment: .trailing, spacing: 9) {
                numeratorStepper
                denomGrid
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.timeSigCard, style: .continuous)
                .fill(Theme.Colors.panel)
        }
    }

    // 분자 / 막대 / 분모 세로 스택
    private var fractionStack: some View {
        VStack(spacing: 3) {
            Text("\(beatCount)")
                .font(.monoTabular(size: 26, weight: .semibold))
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Theme.Colors.ink)
                .frame(width: 24, height: 2)
            Text(denom)
                .font(.monoTabular(size: 26, weight: .semibold))
        }
        .foregroundStyle(Theme.Colors.ink)
        .frame(minWidth: 34)
    }

    // 분자 스테퍼: − [n] +
    private var numeratorStepper: some View {
        HStack(spacing: 8) {
            RoundButton(symbol: "−", size: 28, fontSize: 16,
                        background: Theme.Colors.surfaceRaised, action: onRemoveBeat)
            Text("\(beatCount)")
                .font(.monoTabular(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Colors.ink)
                .frame(minWidth: 20)
            RoundButton(symbol: "+", size: 28, fontSize: 16,
                        background: Theme.Colors.surfaceRaised, action: onAddBeat)
        }
    }

    // 분모 칩 4개 그리드
    private var denomGrid: some View {
        HStack(spacing: 6) {
            ForEach(denomOptions, id: \.self) { value in
                DenomChip(value: value, isOn: denom == value) {
                    denom = value
                }
                .frame(width: 30)
            }
        }
    }
}
