// metronome/View/AccentBarsView.swift
import SwiftUI

/// 박자별 악센트 바 그룹을 렌더링합니다.
/// 각 그룹 = 메인 바 1개(width 28) + (pulses-1) 서브 바(width 11), 아래에 박자 번호.
/// 바를 클릭하면 `onCycle` 을 통해 모델이 해당 칸의 강세 레벨을 순환하고,
/// 우클릭 컨텍스트 메뉴에서는 `onSet` 으로 레벨을 직접 지정합니다.
/// 재생 중에는 `activeBeat` 그룹을 시각적으로 강조합니다.
struct AccentBarsView: View {
    /// 박자별 펄스 강세 그리드 (grid[beat][pulse]). 표시 전용(읽기)입니다.
    let grid: [[AccentLevel]]
    /// 현재 울리고 있는 (박, 펄스) 인덱스. 재생 중이 아니면 nil.
    var activePulse: (beat: Int, pulse: Int)? = nil
    /// 바 탭을 모델(`cycleCell`)로 라우팅하는 클로저입니다.
    let onCycle: (Int, Int) -> Void
    /// 컨텍스트 메뉴에서 강세를 직접 지정할 때 호출합니다(beat, pulse, level).
    let onSet: (Int, Int, AccentLevel) -> Void

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

    /// 가용 폭 안에 한 줄로 놓을 수 있는 박자 그룹 개수를 계산합니다.
    /// 이전에는 상수 2로 고정돼 있어서, 4분음표 8박(한 줄에 7개가 들어감)이
    /// 2개씩 4줄로 쪼개지며 창이 불필요하게 세로로 길어졌습니다.
    /// 뷰 상태와 무관한 순수 계산이라 단위 테스트로 검증할 수 있습니다.
    static func groupsPerRow(pulses: Int) -> Int {
        let width = groupWidth(pulses: pulses)
        guard width > 0 else { return 1 }
        // n개를 놓으려면 width*n + groupSpacing*(n-1) ≤ availableWidth 여야 합니다.
        let fit = (availableWidth + groupSpacing) / (width + groupSpacing)
        return max(1, Int(fit.rounded(.down)))
    }

    /// 박자 수/펄스 수만으로, 모든 박자 그룹을 한 줄에 놓으면 가용 폭을 넘는지 판단합니다.
    /// 뷰 상태와 무관한 순수 계산이라 단위 테스트로 검증할 수 있습니다.
    static func overflowsSingleRow(beatCount: Int, pulses: Int) -> Bool {
        guard beatCount > 0 else { return false }
        return beatCount > groupsPerRow(pulses: pulses)
    }

    /// 현재 grid 기준으로 한 줄 배치가 넘치는지 판단합니다.
    private var overflowsSingleRow: Bool {
        Self.overflowsSingleRow(beatCount: grid.count, pulses: grid.first?.count ?? 0)
    }

    /// 실제 렌더될 박자 그룹 "줄" 수를 계산합니다.
    /// 한 줄에 들어가면 1, 넘치면 `groupsPerRow(pulses:)`개씩 끊어 올림 계산합니다.
    /// 뷰 상태와 무관한 순수 계산이라 단위 테스트로 검증할 수 있습니다.
    static func rowCount(beatCount: Int, pulses: Int) -> Int {
        guard beatCount > 0 else { return 0 }
        let perRow = groupsPerRow(pulses: pulses)
        return (beatCount + perRow - 1) / perRow
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

    /// 화면에 한 번에 보여 주는 최대 줄 수입니다. 이를 넘는 줄은 스크롤로 처리합니다.
    ///
    /// 창은 `.windowResizability(.contentSize)` 라 콘텐츠 높이가 곧 창 높이입니다.
    /// 12박 × 6잇단(4줄)을 전부 펼치면 창이 1,100pt 가 되어 13" 노트북에서
    /// 하단 트랜스포트가 화면 밖으로 밀려납니다. 줄 수를 제한해 창 높이 상한을 만듭니다.
    static let maxVisibleRows: Int = 2

    /// 악센트 바 영역이 실제로 차지하는 높이입니다(초과 줄은 스크롤).
    static func visibleHeight(beatCount: Int, pulses: Int) -> CGFloat {
        let rows = min(rowCount(beatCount: beatCount, pulses: pulses), maxVisibleRows)
        guard rows > 0 else { return singleGroupRowHeight }
        return singleGroupRowHeight * CGFloat(rows)
            + groupSpacing * CGFloat(rows - 1)
    }

    /// 현재 grid 기준 콘텐츠 높이입니다.
    private var contentHeight: CGFloat {
        Self.contentHeight(beatCount: grid.count, pulses: grid.first?.count ?? 0)
    }

    /// 현재 grid 기준 실제 표시 높이입니다.
    private var visibleHeight: CGFloat {
        Self.visibleHeight(beatCount: grid.count, pulses: grid.first?.count ?? 0)
    }

    var body: some View {
        Group {
            if overflowsSingleRow {
                ScrollView(.vertical) {
                    wrappedRows
                }
                // 상한 안에 다 들어오면 스크롤 제스처를 막아 오작동을 없앱니다.
                .scrollDisabled(contentHeight <= visibleHeight)
            } else {
                singleRow
            }
        }
        // 표시 높이를 계산값으로 고정해, .contentSize 창이 정확한 높이를
        // 갖도록 합니다(줄바꿈 시 잘림/겹침 방지 + 창 높이 상한 확보).
        .frame(height: visibleHeight)
    }

    /// 한 줄 배치(기존 동작). 모든 그룹이 가용 폭 안에 들어갈 때 사용합니다.
    private var singleRow: some View {
        HStack(alignment: .bottom, spacing: Self.groupSpacing) {
            ForEach(Array(grid.enumerated()), id: \.offset) { beatIndex, row in
                beatGroup(beatIndex: beatIndex, row: row)
            }
        }
    }

    /// 넘칠 때: 가용 폭이 허용하는 만큼(`groupsPerRow`)씩 끊어 여러 줄로 배치합니다.
    private var wrappedRows: some View {
        let indexedRows = Array(grid.enumerated())
        let perRow = Self.groupsPerRow(pulses: grid.first?.count ?? 0)
        let chunks = stride(from: 0, to: indexedRows.count, by: perRow).map { start in
            Array(indexedRows[start..<min(start + perRow, indexedRows.count)])
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
                    bar(beatIndex: beatIndex, pulseIndex: pulseIndex,
                        level: level, isMain: pulseIndex == 0, isActive: isActive)
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

    /// 바 하나를 그립니다.
    ///
    /// 히트 영역은 바 모양이 아니라 컨테이너 높이(64) 전체를 덮습니다.
    /// 예전에는 `contentShape(shape)` 때문에 무음 서브바의 클릭 대상이
    /// 11×10pt 밖에 되지 않아 사실상 조준이 불가능했습니다.
    private func bar(beatIndex: Int, pulseIndex: Int,
                     level: AccentLevel, isMain: Bool, isActive: Bool) -> some View {
        let width: CGFloat = isMain ? Self.mainBarWidth : Self.subBarWidth
        let height = isMain ? level.mainHeight : level.subHeight
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)
        // 활성 바: 액센트 색으로 채우고 부드러운 글로우를 더해 밝게 강조합니다.
        let fill = isActive ? Theme.Colors.acc : level.fill
        let border = isActive ? Theme.Colors.acc : level.borderColor

        return Button {
            onCycle(beatIndex, pulseIndex)
        } label: {
            // 바닥 정렬된 실제 바 + 컨테이너 전체를 덮는 투명 히트 영역.
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
                .frame(width: width, height: Self.barContainerHeight, alignment: .bottom)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .animation(Theme.Motion.bar, value: level)
        .animation(Theme.Motion.chip, value: isActive)
        .contextMenu {
            // 순환만 가능하면 한 단계 되돌리는 데 세 번 눌러야 하므로 직접 지정을 제공합니다.
            ForEach(AccentLevel.allCases) { option in
                Button {
                    onSet(beatIndex, pulseIndex, option)
                } label: {
                    if option == level {
                        Label(option.displayName, systemImage: "checkmark")
                    } else {
                        Text(option.displayName)
                    }
                }
            }
        }
        .accessibilityLabel("\(beatIndex + 1)박 \(pulseIndex + 1)번째 펄스")
        .accessibilityValue(level.displayName)
        .accessibilityHint("누르면 다음 강세로 바뀝니다")
    }
}
