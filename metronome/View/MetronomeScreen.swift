// metronome/View/MetronomeScreen.swift
import SwiftUI

/// 메트로놈 메인 화면. 디자인 핸드오프(디자인 6a)를 SwiftUI로 옮긴 뷰입니다.
/// 모든 상태와 오디오 배선은 `MetronomeState`(단일 소유자)를 통해 흐릅니다.
struct MetronomeScreen: View {

    // MARK: - State (단일 소유자 주입)

    @EnvironmentObject private var state: MetronomeState

    /// 재생 중 현재 울리는 (박, 펄스) 인덱스입니다. 정지 상태에서는 nil.
    @State private var activePulse: (beat: Int, pulse: Int)?
    /// 마지막으로 관측한 박자 스냅샷의 sequence. 변경 감지에 사용합니다.
    @State private var lastSequence: UInt64 = 0
    /// 방향키 BPM 조절을 위한 키보드 포커스입니다. 창 활성 시 항상 잡아 둡니다.
    @FocusState private var keyboardFocused: Bool
    /// BPM 직접 입력 편집 모드 여부와 임시 입력 문자열입니다.
    @State private var editingBPM = false
    @State private var bpmText = ""
    /// BPM 입력 필드 포커스입니다.
    @FocusState private var bpmFieldFocused: Bool
    /// 비주얼 플래시 오버레이의 현재 불투명도입니다.
    @State private var flashOpacity: Double = 0

    /// 방향키 1회 입력당 BPM 증감량입니다. 상하 = 10, 좌우 = 1.
    private static let bpmStepCoarse: Double = 10
    private static let bpmStepFine: Double = 1

    private var beatCount: Int { state.grid.count }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            content
        }
        .frame(width: Theme.Layout.windowWidth)
        .background(Theme.Colors.bg)
        .overlay {
            // 비주얼 플래시: 강박은 더 밝게, 약박은 은은하게.
            Theme.Colors.acc
                .opacity(flashOpacity)
                .allowsHitTesting(false)
        }
        .preferredColorScheme(state.appearance.colorScheme)
        .background(FloatingWindowConfigurator(floating: state.floating))
        .background(beatPoller)
        .onChange(of: state.isPlaying) { _, playing in
            // 정지 시 활성 강조를 즉시 해제합니다.
            if !playing { activePulse = nil }
        }
        // 방향키로 BPM을 조절합니다(상하 ±10, 좌우 ±1).
        // 루트를 focusable로 만들고 등장 시 자동 포커스해, 창이 활성인 한 어디를 클릭했든 방향키가 먹습니다.
        .focusable()
        .focusEffectDisabled()
        .focused($keyboardFocused)
        .onAppear { keyboardFocused = true }
        .onKeyPress(.upArrow) { adjustBPM(by: Self.bpmStepCoarse) }
        .onKeyPress(.downArrow) { adjustBPM(by: -Self.bpmStepCoarse) }
        .onKeyPress(.rightArrow) { adjustBPM(by: Self.bpmStepFine) }
        .onKeyPress(.leftArrow) { adjustBPM(by: -Self.bpmStepFine) }
        // 스페이스바로 재생/정지를 토글합니다.
        .onKeyPress(.space) {
            state.togglePlay()
            return .handled
        }
    }

    /// BPM을 delta만큼 조절합니다. 클램프는 state.setBPM이 담당합니다.
    /// 방향키 입력을 소비했음을 알리기 위해 `.handled`를 반환합니다.
    private func adjustBPM(by delta: Double) -> KeyPress.Result {
        state.setBPM(state.bpm + delta)
        return .handled
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
                        activePulse = (beat: snapshot.beatIndex, pulse: snapshot.pulseIndex)
                        // 다운비트(0박·0펄스)에서 마디 시작을 알림(마디 카운터/트레이너/카운트인 구동).
                        if snapshot.beatIndex == 0 && snapshot.pulseIndex == 0 {
                            state.registerBarStart()
                        }
                        // 비주얼 플래시: 매 펄스마다 피크값 세팅 후 빠르게 페이드.
                        if state.visualFlash {
                            flashOpacity = snapshot.isAccent ? 0.32 : 0.16
                            withAnimation(.easeOut(duration: 0.16)) { flashOpacity = 0 }
                        }
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
                colors: [Theme.Colors.titleBarTop, Theme.Colors.titleBarBottom],
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
            // 0. 프리셋 바
            PresetBarView(state: state)
                .padding(.bottom, 18)

            // 1. 악센트 바 — 탭은 state.cycleCell 로 라우팅, 재생 중 활성 비트를 강조합니다.
            AccentBarsView(
                grid: state.grid,
                activePulse: activePulse,
                onCycle: { beat, pulse in state.cycleCell(beat: beat, pulse: pulse) }
            )
            .frame(maxWidth: .infinity)
            .padding(.bottom, 22)

            // 2. BPM 리드아웃
            bpmReadout
                .padding(.bottom, 6)

            // 3. 템포 캡션 + 마디/카운트인 인디케이터
            VStack(spacing: 4) {
                Text("\(tempoWord) · BPM")
                    .font(.system(size: 12))
                    .tracking(1.68) // .14em @ 12px
                    .foregroundStyle(Theme.Colors.mut2)
                barIndicator
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)

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
                .padding(.bottom, 10)

            // 7. 볼륨
            volumeRow
                .padding(.bottom, 18)

            // 8. 연습(트레이너/카운트인)
            sectionLabel("연습")
                .padding(.bottom, 10)
            TrainerSectionView(state: state)
                .padding(.bottom, 18)

            // 9. 표시/창
            sectionLabel("표시")
                .padding(.bottom, 10)
            DisplaySettingsView(state: state)
                .padding(.bottom, 18)

            // 10. 시작 + TAP
            transportRow
        }
        .padding(Theme.Layout.contentPadding)
    }

    /// 재생 중 마디 번호(또는 카운트인 잔여)를 표시합니다. 정지 시에도 높이를 유지해 레이아웃 흔들림을 막습니다.
    @ViewBuilder
    private var barIndicator: some View {
        Group {
            if state.isPlaying, state.isCountingIn {
                Text("카운트인 \(state.countInRemaining)")
                    .font(.monoTabular(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.acc)
            } else if state.isPlaying {
                Text("마디 \(state.currentBar)")
                    .font(.monoTabular(size: 11))
                    .foregroundStyle(Theme.Colors.mut)
            } else {
                Text(" ")
                    .font(.monoTabular(size: 11))
            }
        }
        .frame(height: 14)
    }

    // MARK: - BPM readout

    private var bpmReadout: some View {
        HStack(alignment: .bottom, spacing: 20) {
            RoundButton(symbol: "−", size: 34, fontSize: 20) {
                state.setBPM(state.bpm - 1)
            }
            if editingBPM {
                TextField("", text: $bpmText)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.monoTabular(size: 66, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink)
                    .focused($bpmFieldFocused)
                    .frame(width: 160)
                    .onSubmit(commitBPM)
                    .onChange(of: bpmFieldFocused) { _, focused in
                        if !focused { commitBPM() }
                    }
                    .accessibilityLabel("BPM 입력")
            } else {
                Text("\(Int(state.bpm))")
                    .font(.monoTabular(size: 66, weight: .semibold))
                    .tracking(-1.98) // -.03em @ 66px
                    .foregroundStyle(Theme.Colors.ink)
                    .fixedSize()
                    .contentShape(Rectangle())
                    .onTapGesture { beginEditingBPM() }
                    .accessibilityLabel("BPM \(Int(state.bpm)), 탭하여 직접 입력")
            }
            RoundButton(symbol: "+", size: 34, fontSize: 20) {
                state.setBPM(state.bpm + 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 큰 BPM 숫자를 탭하면 직접 입력 모드로 전환합니다.
    private func beginEditingBPM() {
        bpmText = "\(Int(state.bpm))"
        editingBPM = true
        bpmFieldFocused = true
    }

    /// 입력값을 파싱해 BPM에 반영하고(클램프는 setBPM), 편집 모드를 종료합니다.
    private func commitBPM() {
        guard editingBPM else { return }
        if let value = Double(bpmText.trimmingCharacters(in: .whitespaces)) {
            state.setBPM(value)
        }
        editingBPM = false
        keyboardFocused = true // 방향키/스페이스 포커스 복귀
    }

    // MARK: - Sound row

    private var soundRow: some View {
        HStack {
            Text("사운드")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Theme.Colors.mut)
            Spacer()
            Menu {
                ForEach(ClickSound.allCases) { option in
                    Button {
                        state.sound = option
                    } label: {
                        if state.sound == option {
                            Label(option.displayName, systemImage: "checkmark")
                        } else {
                            Text(option.displayName)
                        }
                    }
                }
            } label: {
                Text("\(state.sound.displayName) ⌄")
                    .font(.monoTabular(size: 12))
                    .foregroundStyle(Theme.Colors.ink)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("사운드 선택")
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.Colors.panel)
        }
    }

    // MARK: - Volume row

    private var volumeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: state.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.mut)
                .frame(width: 18, alignment: .leading)
            Slider(value: $state.volume, in: 0...1)
                .controlSize(.small)
                .tint(Theme.Colors.acc)
            Text("\(Int(state.volume * 100))")
                .font(.monoTabular(size: 11))
                .foregroundStyle(Theme.Colors.mut)
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.Colors.panel)
        }
        .accessibilityLabel("볼륨")
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
