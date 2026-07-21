// metronome/View/AccentBarsView.swift
import SwiftUI

/// 박자별 악센트 바 그룹을 렌더링합니다.
/// 각 그룹 = 메인 바 1개(width 28) + (pulses-1) 서브 바(width 11), 아래에 박자 번호.
/// 바를 클릭하면 해당 칸의 강세 레벨이 순환합니다.
struct AccentBarsView: View {
    /// 박자별 펄스 강세 그리드 (grid[beat][pulse]).
    @Binding var grid: [[AccentLevel]]

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            ForEach(Array(grid.enumerated()), id: \.offset) { beatIndex, row in
                beatGroup(beatIndex: beatIndex, row: row)
            }
        }
        .frame(minHeight: 64)
    }

    private func beatGroup(beatIndex: Int, row: [AccentLevel]) -> some View {
        VStack(spacing: 9) {
            // 바 컨테이너: 아래 정렬, 고정 높이 64
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(row.enumerated()), id: \.offset) { pulseIndex, level in
                    bar(level: level, isMain: pulseIndex == 0) {
                        grid[beatIndex][pulseIndex] = grid[beatIndex][pulseIndex].next
                    }
                }
            }
            .frame(height: 64, alignment: .bottom)

            Text("\(beatIndex + 1)")
                .font(.monoTabular(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Colors.mut)
        }
    }

    @ViewBuilder
    private func bar(level: AccentLevel, isMain: Bool, onTap: @escaping () -> Void) -> some View {
        let width: CGFloat = isMain ? 28 : 11
        let height = isMain ? level.mainHeight : level.subHeight
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)

        shape
            .fill(level.fill)
            .overlay {
                shape.strokeBorder(
                    level.borderColor,
                    style: StrokeStyle(
                        lineWidth: AccentLevel.borderWidth,
                        dash: level.isDashed ? [3, 2.5] : []
                    )
                )
            }
            .frame(width: width, height: height)
            .contentShape(shape)
            .onTapGesture(perform: onTap)
            .animation(Theme.Motion.bar, value: level)
    }
}
