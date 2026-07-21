// metronome/View/MetronomeScreen.swift
import SwiftUI

/// 메트로놈 메인 화면. 디자인 핸드오프(디자인 6a)를 SwiftUI로 옮긴 뷰입니다.
/// 모든 상태와 오디오 배선은 `MetronomeState`(단일 소유자)를 통해 흐릅니다.
struct MetronomeScreen: View {

    // MARK: - State (단일 소유자 주입)

    @EnvironmentObject private var state: MetronomeState

    /// 재생 중 현재 울리는 박자 인덱스입니다. 정지 상태에서는 nil.
    @State private var activeBeat: Int?
    /// 마지막으로 관측한 박자 스냅샷의 sequence. 변경 감지에 사용합니다.
    @State private var lastSequence: UInt64 = 0

    private var beatCount: Int { state.grid.count }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            content
        }
        .frame(width: Theme.Layout.windowWidth)
        .background(Theme.Colors.bg)
        .background(beatPoller)
        .onChange(of: state.isPlaying) { _, playing in
            // 정지 시 활성 강조를 즉시 해제합니다.
            if !playing { activeBeat = nil }
        }
    }

    // MARK: - Beat poller (오디오 스레드 → UI 활성 비트 배선)

    /// 재생 중 ~60Hz 로 락프리 `beatChannel.latest()` 를 폴링해 활성 비트를 갱신합니다.
    /// 렌더 콜백/오디오 스레드로는 절대 진입하지 않고, 메인 스레드에서 atomic load만 읽습니다.
    /// 보이지 않는 배경 뷰로 배치해 레이아웃에 영향을 주지 않습니다.
    @ViewBuilder
    private var beatPoller: some View {
        if state.isPlaying {
            TimelineView(.animation) { _ in
                Color.clear
                    .onChange(of: pollSequence()) { _, _ in
                        let snapshot = state.engine.beatChannel.latest()
                        lastSequence = snapshot.sequence
                        activeBeat = snapshot.beatIndex
                    }
            }
        }
    }

    /// 타임라인 틱마다 최신 sequence 를 읽어 반환합니다(onChange 트리거용).
    private func pollSequence() -> UInt64 {
        state.engine.beatChannel.latest().sequence
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
            // 1. 악센트 바 — 탭은 state.cycleCell 로 라우팅, 재생 중 활성 비트를 강조합니다.
            AccentBarsView(
                grid: state.grid,
                activeBeat: activeBeat,
                onCycle: { beat, pulse in state.cycleCell(beat: beat, pulse: pulse) }
            )
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
                denom: denomBinding,
                onAddBeat: state.addBeat,
                onRemoveBeat: state.removeBeat
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
                state.setBPM(state.bpm - 1)
            }
            Text("\(Int(state.bpm))")
                .font(.monoTabular(size: 66, weight: .semibold))
                .tracking(-1.98) // -.03em @ 66px
                .foregroundStyle(Theme.Colors.ink)
                .fixedSize()
            RoundButton(symbol: "+", size: 34, fontSize: 20) {
                state.setBPM(state.bpm + 1)
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
            // 시작 버튼: 액센트 채움, 재생 삼각형 + "시작". state.togglePlay() 로 오디오 시작/정지.
            Button {
                state.togglePlay()
            } label: {
                HStack(spacing: 9) {
                    if state.isPlaying {
                        // 정지 사각형
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(.white)
                            .frame(width: 13, height: 13)
                    } else {
                        PlayTriangle()
                            .fill(.white)
                            .frame(width: 15, height: 17)
                    }
                    Text(state.isPlaying ? "정지" : "시작")
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
            .accessibilityLabel(state.isPlaying ? "정지" : "시작")

            // TAP 버튼: 흰 배경 + 액센트 테두리. state.tap() 으로 탭 템포 기록.
            Button {
                state.tap()
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
        switch Int(state.bpm) {
        case ..<60: return "Largo"
        case 60..<76: return "Adagio"
        case 76..<108: return "Andante"
        case 108..<120: return "Moderato"
        case 120..<168: return "Allegro"
        default: return "Presto"
        }
    }

    // MARK: - Bindings (하위 뷰 → state 배선)

    /// 분모 칩 선택을 state.setDenom 으로 라우팅합니다.
    private var denomBinding: Binding<String> {
        Binding(
            get: { state.denom },
            set: { state.setDenom($0) }
        )
    }

    /// 분할 타일 선택을 state.setSubdivision 으로 라우팅합니다(행 리사이즈 포함).
    private var subIdxBinding: Binding<Int> {
        Binding(
            get: { state.subIdx },
            set: { state.setSubdivision($0) }
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
        .environmentObject(MetronomeState())
        .padding(40)
        .background(Theme.Colors.desk)
}
