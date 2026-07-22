// metronome/View/AccentBarsView.swift
import SwiftUI

/// 박자별 악센트 바 그룹을 렌더링합니다.
/// 각 그룹 = 메인 바 1개(width 28) + (pulses-1) 서브 바(width 11), 아래에 박자 번호.
/// 바를 클릭하면 `onCycle` 을 통해 모델이 해당 칸의 강세 레벨을 순환합니다.
/// 재생 중에는 `activeBeat` 그룹을 시각적으로 강조합니다.
struct AccentBarsView: View {
    /// 박자별 펄스 강세 그리드 (grid[beat][pulse]). 표시 전용(읽기)입니다.
    let grid: [[AccentLevel]]
    /// 현재 울리고 있는 (박, 펄스) 인덱스. 재생 중이 아니면 nil.
    var activePulse: (beat: Int, pulse: Int)? = nil
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
    /// 줄바꿈 시 한 줄에 놓는 박자 그룹 개수.
    static let groupsPerWrappedRow: Int = 2

    // MARK: - 높이 계산 상수 (한 줄이 실제로 차지하는 세로 크기)

    /// 바 컨테이너 고정 높이(beatGroup 내부 `.frame(height: 64)`와 일치).
    static let barContainerHeight: CGFloat = 64
    /// 바 컨테이너와 박자 번호 텍스트 사이 간격(beatGroup VStack spacing 9와 일치).
    static let beatGroupSpacing: CGFloat = 9
    /// 박자 번호 텍스트 높이(11pt semibold 한 줄, line height 근사).
    static let beatLabelHeight: CGFloat = 14

    /// 박자 그룹 한 줄(바 컨테이너 + 간격 + 번호)의 세로 높이.
    static let singleGroupRowHeight: CGFloat =
        barContainerHeight + beatGroupSpacing + beatLabelHeight

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

    /// 실제 렌더될 박자 그룹 "줄" 수를 계산합니다.
    /// 한 줄에 들어가면 1, 넘치면 그룹을 `groupsPerWrappedRow`개씩 끊어 올림 계산합니다.
    /// 뷰 상태와 무관한 순수 계산이라 단위 테스트로 검증할 수 있습니다.
    static func rowCount(beatCount: Int, pulses: Int) -> Int {
        guard beatCount > 0 else { return 0 }
        guard overflowsSingleRow(beatCount: beatCount, pulses: pulses) else { return 1 }
        return (beatCount + groupsPerWrappedRow - 1) / groupsPerWrappedRow
    }

    /// 악센트 바 영역이 실제로 필요로 하는 세로 높이입니다.
    /// `.windowResizability(.contentSize)` 환경에서 창이 여러 줄 높이를 정확히
    /// 반영하도록, 이상적 높이를 명시하는 데 사용합니다.
    static func contentHeight(beatCount: Int, pulses: Int) -> CGFloat {
        let rows = rowCount(beatCount: beatCount, pulses: pulses)
        guard rows > 0 else { return singleGroupRowHeight }
        return singleGroupRowHeight * CGFloat(rows)
            + groupSpacing * CGFloat(rows - 1)
    }

    /// 현재 grid 기준 콘텐츠 높이입니다.
    private var contentHeight: CGFloat {
        Self.contentHeight(beatCount: grid.count, pulses: grid.first?.count ?? 0)
    }

    var body: some View {
        Group {
            if overflowsSingleRow {
                wrappedRows
            } else {
                singleRow
            }
        }
        // 이상적 높이를 계산값으로 고정해, .contentSize 창이 여러 줄 높이를
        // 정확히 반영하도록 합니다(줄바꿈 시 잘림/겹침 방지).
        .frame(height: contentHeight)
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
        // 박자 번호 강조는 현재 울리는 박 기준으로 유지합니다.
        let isActiveBeat = activePulse?.beat == beatIndex

        return VStack(spacing: 9) {
            // 바 컨테이너: 아래 정렬, 고정 높이 64
            HStack(alignment: .bottom, spacing: Self.barSpacing) {
                ForEach(Array(row.enumerated()), id: \.offset) { pulseIndex, level in
                    // 활성 펄스: 현재 울리는 (박, 펄스)와 정확히 일치하는 바 하나.
                    let isActive = activePulse?.beat == beatIndex
                        && activePulse?.pulse == pulseIndex
                    bar(level: level, isMain: pulseIndex == 0, isActive: isActive) {
                        onCycle(beatIndex, pulseIndex)
                    }
                }
            }
            .frame(height: 64, alignment: .bottom)

            Text("\(beatIndex + 1)")
                .font(.monoTabular(size: 11, weight: .semibold))
                .foregroundStyle(isActiveBeat ? Theme.Colors.acc : Theme.Colors.mut)
        }
        // 그룹 좌우 여백만 유지(폭 계산 groupHorizontalPadding=12과 일치). 배경/확대 없음.
        .padding(.horizontal, 6)
    }

    @ViewBuilder
    private func bar(level: AccentLevel, isMain: Bool, isActive: Bool, onTap: @escaping () -> Void) -> some View {
        let width: CGFloat = isMain ? Self.mainBarWidth : Self.subBarWidth
        let height = isMain ? level.mainHeight : level.subHeight
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)
        // 활성 바: 액센트 색으로 채우고 부드러운 글로우를 더해 밝게 강조합니다.
        let fill = isActive ? Theme.Colors.acc : level.fill
        let border = isActive ? Theme.Colors.acc : level.borderColor

        shape
            .fill(fill)
            .overlay {
                shape.strokeBorder(
                    border,
                    style: StrokeStyle(
                        lineWidth: AccentLevel.borderWidth,
                        dash: level.isDashed ? [3, 2.5] : []
                    )
                )
            }
            .frame(width: width, height: height)
            .shadow(color: isActive ? Theme.Colors.accSoft : .clear, radius: isActive ? 6 : 0)
            .contentShape(shape)
            .onTapGesture(perform: onTap)
            .animation(Theme.Motion.bar, value: level)
            .animation(Theme.Motion.chip, value: isActive)
    }
}
