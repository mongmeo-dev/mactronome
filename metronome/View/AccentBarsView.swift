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

    // MARK: - Layout 상수 (폭 계산과 바 렌더가 공유하는 단일 소스)

    /// 메인 바 폭.
    static let mainBarWidth: CGFloat = 28
    /// 서브 바 폭.
    static let subBarWidth: CGFloat = 11
    /// 박자 그룹 내 바 사이 간격.
    static let barSpacing: CGFloat = 4
    /// 박자 그룹 좌우 padding 합(각 6).
    static let groupHorizontalPadding: CGFloat = 12
    /// 박자 그룹 사이 간격.
    static let groupSpacing: CGFloat = 16
    /// 콘텐츠 가용 폭 = windowWidth(452) − contentPadding 좌우(30×2).
    static let availableWidth: CGFloat = 392

    /// 펄스 수(= 한 박자 그룹의 바 개수)로부터 그룹 하나의 실제 폭을 계산합니다.
    static func groupWidth(pulses: Int) -> CGFloat {
        guard pulses > 0 else { return groupHorizontalPadding }
        let bars = mainBarWidth + subBarWidth * CGFloat(pulses - 1)
        let gaps = barSpacing * CGFloat(pulses - 1)
        return bars + gaps + groupHorizontalPadding
    }

    /// 박자 수/펄스 수만으로, 모든 박자 그룹을 한 줄에 놓으면 가용 폭을 넘는지 판단합니다.
    /// 뷰 상태와 무관한 순수 계산이라 단위 테스트로 검증할 수 있습니다.
    static func overflowsSingleRow(beatCount: Int, pulses: Int) -> Bool {
        guard beatCount > 0 else { return false }
        let total = groupWidth(pulses: pulses) * CGFloat(beatCount)
            + groupSpacing * CGFloat(beatCount - 1)
        return total > availableWidth
    }

    /// 현재 grid 기준으로 한 줄 배치가 넘치는지 판단합니다.
    private var overflowsSingleRow: Bool {
        Self.overflowsSingleRow(beatCount: grid.count, pulses: grid.first?.count ?? 0)
    }

    var body: some View {
        Group {
            if overflowsSingleRow {
                wrappedRows
            } else {
                singleRow
            }
        }
        .frame(minHeight: 64)
    }

    /// 한 줄 배치(기존 동작). 모든 그룹이 가용 폭 안에 들어갈 때 사용합니다.
    private var singleRow: some View {
        HStack(alignment: .bottom, spacing: Self.groupSpacing) {
            ForEach(Array(grid.enumerated()), id: \.offset) { beatIndex, row in
                beatGroup(beatIndex: beatIndex, row: row)
            }
        }
    }

    /// 넘칠 때: 박자 그룹을 한 줄에 2개씩 끊어 여러 줄로 배치합니다.
    private var wrappedRows: some View {
        let indexedRows = Array(grid.enumerated())
        let chunks = stride(from: 0, to: indexedRows.count, by: 2).map { start in
            Array(indexedRows[start..<min(start + 2, indexedRows.count)])
        }
        return VStack(alignment: .center, spacing: Self.groupSpacing) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                HStack(alignment: .bottom, spacing: Self.groupSpacing) {
                    ForEach(chunk, id: \.offset) { beatIndex, row in
                        beatGroup(beatIndex: beatIndex, row: row)
                    }
                }
            }
        }
    }

    private func beatGroup(beatIndex: Int, row: [AccentLevel]) -> some View {
        let isActive = activeBeat == beatIndex

        return VStack(spacing: 9) {
            // 바 컨테이너: 아래 정렬, 고정 높이 64
            HStack(alignment: .bottom, spacing: Self.barSpacing) {
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
        let width: CGFloat = isMain ? Self.mainBarWidth : Self.subBarWidth
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
