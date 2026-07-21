// metronome/View/MetronomeScreen.swift
import SwiftUI

/// 메트로놈 메인 화면. 디자인 핸드오프(디자인 6a)를 SwiftUI로 옮긴 뷰입니다.
/// 오디오 로직은 별도 브랜치에서 병합될 예정이며, 여기서는 로컬 @State 만 다룹니다.
struct MetronomeScreen: View {

    // MARK: - State (핸드오프 <script> 상태 모델을 미러링)

    /// 분모: "2"/"4"/"8"/"16"
    @State private var denom: String = "4"
    /// 분할 인덱스 0..5
    @State private var subIdx: Int = 0
    /// 박자별 펄스 강세 그리드. 기본 [[3],[1],[2],[1]]
    @State private var grid: [[AccentLevel]] = [[.strong], [.weak], [.medium], [.weak]]
    /// BPM (기본 132, 30...300 클램프)
    @State private var bpm: Int = 132
    /// 재생 상태(현재는 버튼 라벨/비주얼만 토글)
    @State private var isPlaying: Bool = false

    private var beatCount: Int { grid.count }
    private var pulsesPerBeat: Int { SubdivisionOption.all[subIdx].pulses }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            content
        }
        .frame(width: Theme.Layout.windowWidth)
        .background(Theme.Colors.bg)
    }

    // MARK: - Title bar (신호등 + 제목)

    private var titleBar: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xF3F2EF), Color(hex: 0xECEAE6)],
                startPoint: .top, endPoint: .bottom
            )
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    trafficLight(Theme.Colors.trafficRed)
                    trafficLight(Theme.Colors.trafficYellow)
                    trafficLight(Theme.Colors.trafficGreen)
                }
                Spacer()
            }
            .padding(.horizontal, 15)

            Text("Metronome")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Colors.mut)
        }
        .frame(height: Theme.Layout.titleBarHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Colors.bd).frame(height: 0.5)
        }
    }

    private func trafficLight(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 12, height: 12)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. 악센트 바
            AccentBarsView(grid: $grid)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 22)

            // 2. BPM 리드아웃
            bpmReadout
                .padding(.bottom, 6)

            // 3. 템포 캡션
            Text("\(tempoWord) · BPM")
                .font(.system(size: 12))
                .tracking(1.68) // .14em @ 12px
                .foregroundStyle(Theme.Colors.mut2)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)

            // 4. 박자표
            sectionLabel("박자표")
                .padding(.bottom, 10)
            TimeSignatureEditorView(
                beatCount: beatCount,
                denom: $denom,
                onAddBeat: addBeat,
                onRemoveBeat: removeBeat
            )
            .padding(.bottom, 22)

            // 5. 분할
            sectionLabel("분할")
                .padding(.bottom, 10)
            SubdivisionGridView(subIdx: subIdxBinding)
                .padding(.bottom, 22)

            // 6. 사운드
            soundRow
                .padding(.bottom, 18)

            // 7. 시작 + TAP
            transportRow
        }
        .padding(Theme.Layout.contentPadding)
    }

    // MARK: - BPM readout

    private var bpmReadout: some View {
        HStack(alignment: .bottom, spacing: 20) {
            RoundButton(symbol: "−", size: 34, fontSize: 20) {
                bpm = max(30, bpm - 1)
            }
            Text("\(bpm)")
                .font(.monoTabular(size: 66, weight: .semibold))
                .tracking(-1.98) // -.03em @ 66px
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize()
            RoundButton(symbol: "+", size: 34, fontSize: 20) {
                bpm = min(300, bpm + 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sound row

    private var soundRow: some View {
        HStack {
            Text("사운드")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.Colors.mut)
            Spacer()
            Text("Wood Block ⌄")
                .font(.monoTabular(size: 12))
                .foregroundStyle(Theme.Colors.ink)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.Colors.panel)
        }
    }

    // MARK: - Transport row (시작 / TAP)

    private var transportRow: some View {
        HStack(spacing: 12) {
            // 시작 버튼: 액센트 채움, 재생 삼각형 + "시작"
            Button {
                isPlaying.toggle()
                // TODO: 오디오 로직 배선 (MetronomeState 병합 시)
            } label: {
                HStack(spacing: 9) {
                    if isPlaying {
                        // 정지 사각형
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(.white)
                            .frame(width: 13, height: 13)
                    } else {
                        PlayTriangle()
                            .fill(.white)
                            .frame(width: 15, height: 17)
                    }
                    Text(isPlaying ? "정지" : "시작")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.39)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(Theme.Colors.acc)
                }
                .shadow(color: Theme.Colors.accSoft, radius: 8, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "정지" : "시작")

            // TAP 버튼: 흰 배경 + 액센트 테두리
            Button {
                // TODO: 오디오 로직 배선 (MetronomeState 병합 시)
            } label: {
                Text("TAP")
                    .font(.monoTabular(size: 12.5, weight: .bold))
                    .tracking(0.75)
                    .foregroundStyle(Theme.Colors.acc)
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                            .fill(.white)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                            .strokeBorder(Theme.Colors.acc, lineWidth: 1.5)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 1.5, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("탬포 탭")
        }
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.24)
            .foregroundStyle(Theme.Colors.mut)
    }

    // MARK: - Derived: tempo word

    /// BPM 으로부터 템포 용어를 도출합니다.
    private var tempoWord: String {
        switch bpm {
        case ..<60: return "Largo"
        case 60..<76: return "Adagio"
        case 76..<108: return "Andante"
        case 108..<120: return "Moderato"
        case 120..<168: return "Allegro"
        default: return "Presto"
        }
    }

    // MARK: - Interactions (핸드오프 로직 미러링)

    /// 박자 추가: 현재 분할 펄스 수만큼 1(약박)로 채운 행을 추가(최대 12).
    private func addBeat() {
        guard grid.count < 12 else { return }
        grid.append(Array(repeating: .weak, count: pulsesPerBeat))
    }

    /// 박자 제거: 마지막 행 삭제(최소 1).
    private func removeBeat() {
        guard grid.count > 1 else { return }
        grid.removeLast()
    }

    /// 분할 변경 시 모든 행을 새 펄스 수로 리사이즈(slice / pad with weak).
    private var subIdxBinding: Binding<Int> {
        Binding(
            get: { subIdx },
            set: { newIndex in
                let count = SubdivisionOption.all[newIndex].pulses
                grid = grid.map { row in
                    var newRow = Array(row.prefix(count))
                    while newRow.count < count { newRow.append(.weak) }
                    return newRow
                }
                subIdx = newIndex
            }
        )
    }
}

/// 재생 삼각형 (0,0)-(20,11)-(0,22) 을 뷰 크기에 맞춰 그립니다.
struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    MetronomeScreen()
        .padding(40)
        .background(Theme.Colors.desk)
}
