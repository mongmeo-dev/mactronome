// metronome/View/SubdivisionGridView.swift
import SwiftUI

/// 분할(subdivision) 옵션 하나를 나타내는 값.
struct SubdivisionOption {
    let symbol: String
    let name: String
    let pulses: Int
}

extension SubdivisionOption {
    /// subIdx 0..5 에 대응하는 분할 옵션 목록. pulses = subCounts [1,2,4,3,6,5].
    static let all: [SubdivisionOption] = [
        SubdivisionOption(symbol: "♩", name: "4분음표", pulses: 1),
        SubdivisionOption(symbol: "♪", name: "8분음표", pulses: 2),
        SubdivisionOption(symbol: "♬", name: "16분음표", pulses: 4),
        SubdivisionOption(symbol: "3", name: "셋잇단", pulses: 3),
        SubdivisionOption(symbol: "6", name: "6잇단", pulses: 6),
        SubdivisionOption(symbol: "5", name: "5잇단", pulses: 5),
    ]
}

/// 분할 선택 1행 그리드(6타일).
///
/// 3열 2행이던 것을 6열 1행으로 바꿨습니다. 옵션이 6개뿐이라 한 줄에
/// 다 들어가고, 두 줄을 오가며 훑을 필요가 없어집니다.
/// 본 창 세로 공간도 약 56pt 절약됩니다(창 높이 상한 확보).
struct SubdivisionGridView: View {
    @Binding var subIdx: Int

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 7),
        count: SubdivisionOption.all.count
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 7) {
            ForEach(Array(SubdivisionOption.all.enumerated()), id: \.offset) { index, option in
                tile(option: option, isOn: subIdx == index) {
                    subIdx = index
                }
            }
        }
    }

    private func tile(option: SubdivisionOption, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(option.symbol)
                    .font(.system(size: 19))
                    .foregroundStyle(Theme.Colors.ink)
                Text(option.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isOn ? Theme.Colors.ink : Theme.Colors.mut2)
                    // 6열에서도 "16분음표" 가 줄바꿈/축약되지 않도록 한 줄로 고정합니다.
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 9)
            .padding(.bottom, 8)
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
        .accessibilityLabel(option.name)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
