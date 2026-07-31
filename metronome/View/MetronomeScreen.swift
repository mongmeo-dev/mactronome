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
    /// 전체 화면 점멸의 점멸률을 WCAG 2.3.1 범위로 제한하는 정책입니다.
    @State private var flashPolicy = FlashPolicy()
    /// 시스템 "동작 줄이기" 설정입니다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// BPM 드래그 시작 시점의 값입니다. 드래그 중이 아니면 nil.
    @State private var bpmDragStart: Double?
    /// 스크롤 휠 델타를 1 BPM 단위 스텝으로 바꾸는 누적기입니다.
    @State private var bpmScrollAccumulator = StepAccumulator(pointsPerStep: 4)

    /// 방향키 1회 입력당 BPM 증감량입니다. 상하 = 10, 좌우 = 1.
    private static let bpmStepCoarse: Double = 10
    private static let bpmStepFine: Double = 1
    /// BPM 드래그 민감도: 이 포인트만큼 끌 때 1 BPM 변합니다.
    private static let bpmDragPointsPerStep: Double = 3

    private var beatCount: Int { state.grid.count }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            if state.compact {
                compactContent
            } else {
                content
            }
        }
        .frame(width: state.compact ? Theme.Layout.compactWindowWidth : Theme.Layout.windowWidth)
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
        // 키보드 입력은 보이지 않는 전용 수신부가 받습니다.
        .background(keyboardCatcher)
        .onChange(of: state.isPlaying) { _, playing in
            // 정지 시 활성 강조와 잔여 플래시를 즉시 해제합니다.
            if !playing {
                activePulse = nil
                flashOpacity = 0
            }
            // 재생 전환마다 점멸 간격을 초기화해 첫 박이 바로 보이도록 합니다.
            flashPolicy.reset()
        }
    }

    /// 창 전체의 키보드 입력을 받는 보이지 않는 수신부입니다.
    ///
    /// 예전에는 루트 뷰 자체에 `.focusable().focusEffectDisabled()` 를 걸었는데,
    /// `focusEffectDisabled` 는 하위 뷰까지 전파되는 환경 수정자라
    /// 창 안의 모든 버튼·칩·타일에서 포커스 링이 사라졌습니다.
    /// 키보드 사용자는 지금 어디에 포커스가 있는지 알 수 없었습니다.
    /// 수신부를 배경의 별도 뷰로 떼어 내 포커스 링 억제 범위를 여기로 한정합니다.
    private var keyboardCatcher: some View {
        Color.clear
            .focusable()
            .focusEffectDisabled()
            .focused($keyboardFocused)
            .onAppear { keyboardFocused = true }
            // 방향키로 BPM을 조절합니다(상하 ±10, 좌우 ±1).
            .onKeyPress(.upArrow) { adjustBPM(by: Self.bpmStepCoarse) }
            .onKeyPress(.downArrow) { adjustBPM(by: -Self.bpmStepCoarse) }
            .onKeyPress(.rightArrow) { adjustBPM(by: Self.bpmStepFine) }
            .onKeyPress(.leftArrow) { adjustBPM(by: -Self.bpmStepFine) }
            // 스페이스바로 재생/정지를 토글합니다.
            .onKeyPress(.space) {
                state.togglePlay()
                return .handled
            }
            .accessibilityHidden(true)
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
                        // 비주얼 플래시: 박 단위 + 최소 간격으로 점멸률을 제한합니다.
                        // (제한 없이 매 펄스 점멸하면 고 BPM·잘게 쪼갠 분할에서
                        //  초당 수십 회 전체 화면 명멸이 발생합니다.)
                        if state.visualFlash {
                            let now = Date().timeIntervalSinceReferenceDate
                            let isBeatStart = snapshot.pulseIndex == 0
                            if flashPolicy.shouldFlash(at: now, isBeatStart: isBeatStart) {
                                flashOpacity = FlashPolicy.peakOpacity(
                                    isAccent: snapshot.isAccent, reduceMotion: reduceMotion
                                )
                                let fade = FlashPolicy.fadeDuration(reduceMotion: reduceMotion)
                                withAnimation(.easeOut(duration: fade)) { flashOpacity = 0 }
                            }
                        }
                    }
            }
        }
    }

    /// 타임라인 틱마다 최신 sequence 를 읽어 반환합니다(onChange 트리거용).
    private func pollSequence() -> UInt64 {
        state.engine.beatChannel.latest().sequence
    }

    // MARK: - Title bar (제목)

    private var titleBar: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Colors.titleBarTop, Theme.Colors.titleBarBottom],
                startPoint: .top, endPoint: .bottom
            )
            // 좌상단은 시스템 신호등 버튼이 겹쳐 그려지는 영역이라 비워 둡니다.
            HStack(spacing: 0) {
                Color.clear.frame(width: Theme.Layout.trafficLightInset)
                Spacer()
                Button {
                    state.compact.toggle()
                } label: {
                    Image(systemName: state.compact
                          ? "arrow.up.left.and.arrow.down.right"
                          : "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.mut)
                        .frame(width: 26, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .help(state.compact ? "일반 모드 (⌘⇧C)" : "컴팩트 모드 (⌘⇧C)")
                .accessibilityLabel(state.compact ? "일반 모드로 전환" : "컴팩트 모드로 전환")
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.mut)
                        .frame(width: 26, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .help("설정 (⌘,)")
                .accessibilityLabel("설정 열기")
            }
            .padding(.trailing, 8)

            Text(state.compact ? "" : "Metronome")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Colors.mut)
        }
        .frame(height: Theme.Layout.titleBarHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Colors.bd).frame(height: 0.5)
        }
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
                onCycle: { beat, pulse in state.cycleCell(beat: beat, pulse: pulse) },
                onSet: { beat, pulse, level in
                    state.setCell(beat: beat, pulse: pulse, level: level)
                }
            )
            .frame(maxWidth: .infinity)
            .padding(.bottom, 22)

            // 2. BPM 리드아웃
            bpmReadout
                .padding(.bottom, 6)

            // 3. 템포 캡션 + 마디/카운트인 + 자동 가속 인디케이터
            VStack(spacing: 4) {
                Text("\(tempoWord) · BPM")
                    .font(.system(size: 12))
                    .tracking(1.68) // .14em @ 12px
                    .foregroundStyle(Theme.Colors.mut2)
                barIndicator
                trainerIndicator
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

            // 6. 볼륨 (자주 만지는 값이라 본 창에 남깁니다)
            volumeRow
                .padding(.bottom, 18)

            // 사운드 음색 / 연습 도구 / 표시·창 설정은 Settings 씬(⌘,)으로 옮겼습니다.
            // 상시 노출 시 창 높이가 1,100pt 를 넘어 13" 화면에서 시작 버튼이
            // 화면 밖으로 밀려났습니다.

            // 7. 오디오 실패 배너 + 시작/TAP
            if let message = state.lastError {
                errorBanner(message)
                    .padding(.bottom, 10)
            }
            transportRow
        }
        .padding(Theme.Layout.contentPadding)
    }

    // MARK: - Compact content

    /// 컴팩트(미니) 모드 본문입니다.
    ///
    /// "항상 위에" 로 띄워 놓고 연주할 때 필요한 것만 남깁니다.
    /// 박자 점 / BPM / 트랜스포트. 편집은 일반 모드에서 합니다.
    private var compactContent: some View {
        VStack(spacing: 14) {
            compactBeatDots

            HStack(alignment: .center, spacing: 14) {
                RoundButton(symbol: "−", size: 28, fontSize: 17,
                            label: "BPM 1 감소", hint: "BPM −1 (← 또는 ⌘←)") {
                    state.setBPM(state.bpm - 1)
                }
                VStack(spacing: 1) {
                    Text("\(Int(state.bpm))")
                        .font(.monoTabular(size: 40, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                        .fixedSize()
                    barIndicator
                    trainerIndicator
                }
                .frame(minWidth: 92)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("BPM \(Int(state.bpm))")
                RoundButton(symbol: "+", size: 28, fontSize: 17,
                            label: "BPM 1 증가", hint: "BPM +1 (→ 또는 ⌘→)") {
                    state.setBPM(state.bpm + 1)
                }
            }

            if let message = state.lastError {
                errorBanner(message)
            }

            transportRow
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    /// 컴팩트 모드의 박자 점 표시입니다. 현재 울리는 박만 액센트로 채웁니다.
    /// 분할 펄스는 표시하지 않습니다(점이 너무 촘촘해져 오히려 읽기 어려워집니다).
    private var compactBeatDots: some View {
        HStack(spacing: 6) {
            ForEach(Array(state.grid.enumerated()), id: \.offset) { beatIndex, row in
                let isActive = activePulse?.beat == beatIndex
                // 박의 첫 펄스 강세로 점의 채움 여부를 정합니다.
                let isAccent = (row.first ?? .weak) == .strong
                Circle()
                    .fill(isActive ? Theme.Colors.acc : Color.clear)
                    .overlay {
                        Circle().strokeBorder(
                            isActive ? Theme.Colors.acc : Theme.Colors.barWeakBorder,
                            lineWidth: isAccent ? 2 : 1
                        )
                    }
                    .frame(width: isAccent ? 10 : 7, height: isAccent ? 10 : 7)
                    .animation(Theme.Motion.chip, value: isActive)
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    // MARK: - Error banner

    /// 오디오 엔진 시작 실패를 사용자에게 알립니다.
    /// 이 배너가 없던 시절에는 시작 버튼을 눌러도 아무 반응 없이 조용히 실패했습니다.
    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("사운드를 시작하지 못했습니다")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.Colors.ink)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.mut)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                state.lastError = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Colors.mut)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("오류 메시지 닫기")
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .fill(Theme.Colors.dangerSoft)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Theme.Colors.danger.opacity(0.4), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("사운드를 시작하지 못했습니다. \(message)")
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

    /// 자동 가속(트레이너) 진행 상황입니다.
    ///
    /// 트레이너가 켜져 있으면 BPM 이 저절로 올라가는데, 이전에는 그 사실도
    /// 목표까지 얼마나 남았는지도 화면에 전혀 드러나지 않았습니다.
    @ViewBuilder
    private var trainerIndicator: some View {
        if state.trainerEnabled {
            HStack(spacing: 5) {
                Image(systemName: "chevron.up.circle")
                    .font(.system(size: 9, weight: .semibold))
                Text(trainerStatusText)
                    .font(.monoTabular(size: 10))
            }
            .foregroundStyle(state.trainerReachedTarget ? Theme.Colors.mut2 : Theme.Colors.acc)
            .frame(height: 13)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("자동 가속. \(trainerStatusText)")
        }
    }

    /// 트레이너 상태 문구입니다.
    private var trainerStatusText: String {
        if state.trainerReachedTarget {
            return "목표 \(state.trainerTargetBPM) 도달"
        }
        let remaining = state.trainerTargetBPM - Int(state.bpm)
        guard state.isPlaying, let bars = state.barsUntilNextBump else {
            // 정지 중에는 다음 bump 까지 남은 마디가 의미 없으므로 목표만 알립니다.
            return "목표 \(state.trainerTargetBPM) (남은 \(remaining))"
        }
        return "\(bars)마디 후 +\(state.trainerBPMStep) · 목표 \(state.trainerTargetBPM)"
    }

    // MARK: - BPM readout

    private var bpmReadout: some View {
        HStack(alignment: .bottom, spacing: 20) {
            RoundButton(symbol: "−", size: 34, fontSize: 20,
                        label: "BPM 1 감소", hint: "BPM −1 (← 또는 ⌘←)") {
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
                    // 위아래로 끌어 빠르게 이동합니다. ±1 버튼만으로는
                    // 132 → 180 에 48번 클릭이 필요했습니다.
                    .gesture(bpmDragGesture)
                    // 포인터를 올린 채 스크롤해도 조절됩니다(macOS 수치 필드 관행).
                    .scrollWheelAdjust(adjustBPMByScroll)
                    .help("드래그·스크롤로 조절 · 클릭해 직접 입력 · ↑↓ ±10 · ←→ ±1")
                    .accessibilityLabel("BPM \(Int(state.bpm)), 탭하여 직접 입력")
            }
            RoundButton(symbol: "+", size: 34, fontSize: 20,
                        label: "BPM 1 증가", hint: "BPM +1 (→ 또는 ⌘→)") {
                state.setBPM(state.bpm + 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 큰 BPM 숫자를 위아래로 끌어 조절하는 제스처입니다.
    /// 위로 끌면 증가하며, 3pt 당 1 BPM 입니다.
    private var bpmDragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                // 드래그 시작 시점의 BPM 을 기준으로 누적 이동량을 적용합니다.
                // 매 프레임 상대 증분을 더하면 반올림 오차가 쌓입니다.
                let base = bpmDragStart ?? state.bpm
                if bpmDragStart == nil { bpmDragStart = base }
                state.setBPM((base - Double(value.translation.height) / Self.bpmDragPointsPerStep).rounded())
            }
            .onEnded { _ in bpmDragStart = nil }
    }

    /// 스크롤 델타를 누적해 1 BPM 단위로 반영합니다.
    /// 잔여 델타는 누적기가 들고 있으므로 천천히 굴려도 반응이 사라지지 않습니다.
    private func adjustBPMByScroll(_ delta: Double) {
        let steps = bpmScrollAccumulator.consume(delta)
        guard steps != 0 else { return }
        state.setBPM(state.bpm + steps)
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

    // MARK: - Volume row

    private var volumeRow: some View {
        HStack(spacing: 12) {
            // 스피커 아이콘은 장식이 아니라 음소거 토글입니다.
            // (이전에는 볼륨을 0까지 끌었다 되돌리는 방법밖에 없었습니다.)
            Button {
                state.toggleMute()
            } label: {
                Image(systemName: state.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(state.isMuted ? Theme.Colors.acc : Theme.Colors.mut)
                    .frame(width: 18, height: 18, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(state.isMuted ? "음소거 해제" : "음소거")
            .help(state.isMuted ? "음소거 해제" : "음소거")
            Slider(value: $state.volume, in: 0...1)
                .controlSize(.small)
                .tint(Theme.Colors.acc)
                .accessibilityLabel("볼륨")
                .accessibilityValue("\(Int(state.volume * 100))퍼센트")
                .help("볼륨")
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
        .accessibilityElement(children: .contain)
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
                            .fill(Theme.Colors.onAccent)
                            .frame(width: 13, height: 13)
                    } else {
                        PlayTriangle()
                            .fill(Theme.Colors.onAccent)
                            .frame(width: 15, height: 17)
                    }
                    Text(state.isPlaying ? "정지" : "시작")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(0.39)
                        .foregroundStyle(Theme.Colors.onAccent)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background {
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(Theme.Colors.acc)
                }
                .shadow(color: Theme.Colors.accSoft, radius: 8, x: 0, y: 6)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(state.isPlaying ? "정지" : "시작")
            .help(state.isPlaying ? "정지 (Space 또는 ⌘P)" : "시작 (Space 또는 ⌘P)")

            // TAP 버튼: 올라온 표면 + 액센트 테두리. state.tap() 으로 탭 템포 기록.
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
                            .fill(Theme.Colors.surfaceRaised)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                            .strokeBorder(Theme.Colors.acc, lineWidth: 1.5)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 1.5, x: 0, y: 1)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("템포 탭")
            .accessibilityHint("원하는 템포에 맞춰 반복해서 누르면 BPM 이 맞춰집니다")
            .help("템포 탭 (⌘T) — 원하는 박자에 맞춰 두드리세요")
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
