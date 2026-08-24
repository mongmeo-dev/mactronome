// metronome/View/TimeSignatureEditorView.swift
import SwiftUI

/// 박자표 편집 패널.
/// 분자/막대/분모 스택 자체를 스테퍼의 값으로 사용하고,
/// 오른쪽 분모 칩으로 분모를 바로 선택합니다.
struct TimeSignatureEditorView: View {
    let beatCount: Int
    @Binding var denom: String
    let onAddBeat: () -> Void
    let onRemoveBeat: () -> Void

    private let denomOptions = ["2", "4", "8", "16"]

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            RoundButton(symbol: "−", size: 28, fontSize: 16,
                        background: Theme.Colors.surfaceRaised,
                        label: "박자 1 줄이기", hint: "한 마디의 박자 수를 줄입니다",
                        action: onRemoveBeat)

            fractionStack

            RoundButton(symbol: "+", size: 28, fontSize: 16,
                        background: Theme.Colors.surfaceRaised,
                        label: "박자 1 늘리기", hint: "한 마디의 박자 수를 늘립니다",
                        action: onAddBeat)

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("분모")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.Colors.mut2)
                denomGrid
            }
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
