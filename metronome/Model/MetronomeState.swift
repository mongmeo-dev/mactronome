import Foundation

/// UI 상태의 단일 소유자입니다. grid/subdivision/denom/BPM/재생 상태를 보유하며
/// 변경 시 `MetronomeEngine`에 배선을 전파합니다.
@MainActor
final class MetronomeState: ObservableObject {
    /// BPM 허용 범위입니다.
    static let bpmRange: ClosedRange<Double> = 30...300
    /// 분할 인덱스별 박자당 펄스 수입니다.
    static let subCounts = [1, 2, 4, 3, 6, 5]

    /// 박자별 펄스 강세 그리드. 기본 [[3],[1],[2],[1]]
    @Published var grid: [[AccentLevel]] = [[.strong], [.weak], [.medium], [.weak]] {
        didSet { propagateGrid(); persist() }
    }
    /// 분할 인덱스 0..5
    @Published var subIdx: Int = 0 {
        didSet { propagateGrid(); persist() }
    }
    /// 분모: "2"/"4"/"8"/"16". 한 박에 해당하는 음표 값이며, 변경 시 실제 템포에 반영됩니다.
    @Published var denom: String = "4" {
        didSet { engine.updateNoteValue(noteValue); persist() }
    }
    /// BPM (30...300 클램프). 기본값은 디자인 목업과 동일한 132.
    @Published var bpm: Double = 132 {
        didSet { engine.updateBPM(bpm); persist() }
    }
    /// 클릭 음색입니다.
    @Published var sound: ClickSound = .woodBlock {
        didSet { engine.updateSound(sound); persist() }
    }
    /// 마스터 볼륨(0...1)입니다.
    @Published var volume: Double = 0.8 {
        didSet { engine.setVolume(Float(volume)); persist() }
    }
    /// 재생 상태
    @Published private(set) var isPlaying: Bool = false
    /// 마지막 오디오 시작 실패 메시지입니다(성공 시 nil).
    @Published var lastError: String?

    // MARK: - 연습 도구 (템포 트레이너 / 카운트인)

    /// 템포 트레이너: 마디마다 자동으로 BPM을 올릴지 여부.
    @Published var trainerEnabled: Bool = false { didSet { persist() } }
    /// 몇 마디마다 올릴지(≥1).
    @Published var trainerEveryBars: Int = 2 { didSet { persist() } }
    /// 한 번에 올릴 BPM(≥1).
    @Published var trainerBPMStep: Int = 5 { didSet { persist() } }
    /// 도달 목표 BPM.
    @Published var trainerTargetBPM: Int = 180 { didSet { persist() } }
    /// 시작 전 카운트인 마디 수(0=사용 안 함).
    @Published var countInBars: Int = 0 { didSet { persist() } }

    /// 재생 중 현재 마디 번호(1부터). 정지 시 0.
    @Published private(set) var currentBar: Int = 0
    /// 카운트인 진행 중 여부와 남은 마디 수.
    @Published private(set) var isCountingIn: Bool = false
    @Published private(set) var countInRemaining: Int = 0

    /// 트레이너 bump 판정을 위해 완료된 마디를 세는 내부 카운터입니다.
    private var barsSinceBump = 0

    /// 저장된 프리셋 목록입니다.
    @Published private(set) var presets: [Preset] = []

    /// 분모 문자열을 정수 음표값으로 변환합니다(파싱 실패 시 4).
    var noteValue: Int { Int(denom) ?? 4 }

    let engine: MetronomeEngine

    private var tapTempo = TapTempo()

    /// 설정 저장소입니다. nil이면 비영속(기본값 고정) — 단위 테스트 기본 모드입니다.
    private let store: UserDefaults?
    private static let settingsKey = "metronome.settings.v1"
    private static let presetsKey = "metronome.presets.v1"
    /// 초기 로드 완료 전에는 persist를 억제합니다(로드 중 didSet 폭주 방지).
    private var isLoaded = false

    var pulsesPerBeat: Int { Self.subCounts[subIdx] }

    init(engine: MetronomeEngine = MetronomeEngine(), store: UserDefaults? = nil) {
        self.engine = engine
        self.store = store
        if let store {
            loadSettings(from: store)
            presets = loadPresets(from: store)
        }
        isLoaded = true
        propagateGrid()
        engine.updateBPM(bpm)
        engine.updateNoteValue(noteValue)
        engine.updateSound(sound)
        engine.setVolume(Float(volume))
        engine.prewarm()
    }

    // MARK: - Persistence

    /// 현재 상태를 설정 스냅샷으로 만듭니다.
    func snapshot() -> MetronomeSettings {
        MetronomeSettings(
            bpm: bpm, denom: denom, subIdx: subIdx,
            grid: grid.map { $0.map(\.rawValue) },
            sound: sound, volume: volume,
            trainerEnabled: trainerEnabled, trainerEveryBars: trainerEveryBars,
            trainerBPMStep: trainerBPMStep, trainerTargetBPM: trainerTargetBPM,
            countInBars: countInBars
        )
    }

    /// 저장소에서 설정을 읽어 상태에 반영합니다(로드 중에는 persist가 억제됩니다).
    private func loadSettings(from store: UserDefaults) {
        guard let data = store.data(forKey: Self.settingsKey),
              let s = try? JSONDecoder().decode(MetronomeSettings.self, from: data) else { return }
        applySettings(s)
    }

    /// 설정 스냅샷을 상태에 반영합니다(범위 클램프 포함). 프리셋 적용/복원에서 공유합니다.
    private func applySettings(_ s: MetronomeSettings) {
        bpm = min(max(s.bpm, Self.bpmRange.lowerBound), Self.bpmRange.upperBound)
        denom = s.denom
        subIdx = min(max(s.subIdx, 0), Self.subCounts.count - 1)
        let restored = s.grid.map { row in row.map { AccentLevel(rawValue: $0) ?? .weak } }
        if !restored.isEmpty { grid = restored }
        sound = s.sound
        volume = min(max(s.volume, 0), 1)
        trainerEnabled = s.trainerEnabled
        trainerEveryBars = max(1, s.trainerEveryBars)
        trainerBPMStep = max(1, s.trainerBPMStep)
        trainerTargetBPM = s.trainerTargetBPM
        countInBars = max(0, s.countInBars)
    }

    /// 현재 상태를 저장소에 기록합니다. store가 없거나 로드 전이면 무시합니다.
    private func persist() {
        guard isLoaded, let store else { return }
        if let data = try? JSONEncoder().encode(snapshot()) {
            store.set(data, forKey: Self.settingsKey)
        }
    }

    // MARK: - Presets

    /// 현재 설정을 이름을 붙여 프리셋으로 저장합니다. 같은 이름이 있으면 덮어씁니다.
    @discardableResult
    func saveCurrentAsPreset(named name: String) -> Preset {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let preset = Preset(name: trimmed.isEmpty ? "프리셋 \(presets.count + 1)" : trimmed,
                            settings: snapshot())
        if let idx = presets.firstIndex(where: { $0.name == preset.name }) {
            presets[idx].settings = preset.settings
        } else {
            presets.append(preset)
        }
        persistPresets()
        return preset
    }

    /// 프리셋을 현재 상태에 적용합니다(현재 설정 영속화도 트리거됩니다).
    func applyPreset(_ preset: Preset) {
        applySettings(preset.settings)
    }

    /// 프리셋을 삭제합니다.
    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        persistPresets()
    }

    private func loadPresets(from store: UserDefaults) -> [Preset] {
        guard let data = store.data(forKey: Self.presetsKey),
              let list = try? JSONDecoder().decode([Preset].self, from: data) else { return [] }
        return list
    }

    private func persistPresets() {
        guard let store else { return }
        if let data = try? JSONEncoder().encode(presets) {
            store.set(data, forKey: Self.presetsKey)
        }
    }

    /// 셀 강세를 다음 레벨로 순환합니다.
    func cycleCell(beat: Int, pulse: Int) {
        grid[beat][pulse] = grid[beat][pulse].next
    }

    /// 박자 추가: 현재 분할 펄스 수만큼 약박으로 채운 행을 추가(최대 12).
    func addBeat() {
        guard grid.count < 12 else { return }
        grid.append(Array(repeating: .weak, count: pulsesPerBeat))
    }

    /// 박자 제거: 마지막 행 삭제(최소 1).
    func removeBeat() {
        guard grid.count > 1 else { return }
        grid.removeLast()
    }

    /// 분할 변경 시 모든 행을 새 펄스 수로 리사이즈(slice / pad with weak).
    func setSubdivision(_ i: Int) {
        let count = Self.subCounts[i]
        subIdx = i
        grid = grid.map { row in
            var newRow = Array(row.prefix(count))
            while newRow.count < count { newRow.append(.weak) }
            return newRow
        }
    }

    func setDenom(_ d: String) {
        denom = d
    }

    /// BPM을 설정합니다(30...300 클램프).
    func setBPM(_ v: Double) {
        bpm = min(max(v, Self.bpmRange.lowerBound), Self.bpmRange.upperBound)
    }

    /// 재생을 시작/정지합니다.
    func togglePlay() {
        if engine.isRunning {
            engine.stop()
        } else {
            resetBarTracking()
            do {
                try engine.start()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
        isPlaying = engine.isRunning
        if !isPlaying { resetBarTracking() }
    }

    /// 재생 시작 시 마디/카운트인/트레이너 카운터를 초기화합니다.
    private func resetBarTracking() {
        barsSinceBump = 0
        currentBar = 0
        countInRemaining = countInBars
        isCountingIn = countInBars > 0
    }

    /// 마디 시작(다운비트) 시점에 UI 폴러가 호출합니다.
    /// 카운트인 소진 → 마디 카운터 증가 → (완료 마디 기준) 템포 트레이너 bump 순으로 처리합니다.
    func registerBarStart() {
        guard isPlaying else { return }
        if countInRemaining > 0 {
            countInRemaining -= 1
            isCountingIn = countInRemaining > 0
            return
        }
        if currentBar >= 1 {
            // 직전 마디가 하나 완료됨 → 트레이너 판정.
            barsSinceBump += 1
            if trainerEnabled, barsSinceBump >= max(1, trainerEveryBars) {
                barsSinceBump = 0
                advanceTrainer()
            }
        }
        currentBar += 1
    }

    /// 목표 BPM을 넘지 않도록 한 스텝 올립니다.
    private func advanceTrainer() {
        let target = Double(trainerTargetBPM)
        guard bpm < target else { return }
        setBPM(min(bpm + Double(trainerBPMStep), target))
    }

    /// 현재 시각으로 탭 템포를 기록합니다.
    func tap() {
        _ = tapForTesting(at: Date().timeIntervalSinceReferenceDate)
    }

    /// 테스트에서 임의 시각을 주입할 수 있는 탭 템포 진입점입니다.
    @discardableResult
    func tapForTesting(at time: TimeInterval) -> Double? {
        guard let newBPM = tapTempo.tap(at: time) else { return nil }
        setBPM(newBPM)
        return newBPM
    }

    private func propagateGrid() {
        let gridAsInts = grid.map { $0.map(\.rawValue) }
        engine.updateGrid(gridAsInts, pulsesPerBeat: pulsesPerBeat)
    }
}
