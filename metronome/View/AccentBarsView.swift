// metronome/View/AccentBarsView.swift
import SwiftUI

/// 박자별 악센트 바 그룹을 렌더링합니다.
/// 각 그룹 = 메인 바 1개(width 28) + (pulses-1) 서브 바(width 11), 아래에 박자 번호.
/// 바를 클릭하면 `onCycle` 을 통해 모델이 해당 칸의 강세 레벨을 순환합니다.
/// 재생 중에는 `activeBeat` 그룹을 시각적으로 강조합니다.
struct AccentBarsView: View {
    /// 박자별 펄스 강세 그리드 (grid[beat][pulse]). 표시 전용(읽기)입니다.
    let grid: [[AccentLevel]]
    /// 현재 울리고 있는 박자 인덱스. 재생 중이 아니면 nil.
    var activeBeat: Int? = nil
    /// 바 탭을 모델(`cycleCell`)로 라우팅하는 클로저입니다.
    let onCycle: (Int, Int) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            ForEach(Array(grid.enumerated()), id: \.offset) { beatIndex, row in
                beatGroup(beatIndex: beatIndex, row: row)
            }
        }
        .frame(minHeight: 64)
    }

    private func beatGroup(beatIndex: Int, row: [AccentLevel]) -> some View {
        let isActive = activeBeat == beatIndex

        return VStack(spacing: 9) {
            // 바 컨테이너: 아래 정렬, 고정 높이 64
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(row.enumerated()), id: \.offset) { pulseIndex, level in
                    bar(level: level, isMain: pulseIndex == 0) {
                        onCycle(beatIndex, pulseIndex)
                    }
                }
            }
            .frame(height: 64, alignment: .bottom)

            Text("\(beatIndex + 1)")
                .font(.monoTabular(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? Theme.Colors.acc : Theme.Colors.mut)
        }
        // 활성 비트: 슬레이트 틴트 배경 + 미세한 확대로 담백하게 강조합니다.
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)
                .fill(isActive ? Theme.Colors.accSoft : .clear)
        }
        .scaleEffect(isActive ? 1.06 : 1.0, anchor: .bottom)
        .animation(Theme.Motion.chip, value: isActive)
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
