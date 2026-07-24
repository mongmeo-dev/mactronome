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

    /// 분모 문자열을 정수 음표값으로 변환합니다(파싱 실패 시 4).
    var noteValue: Int { Int(denom) ?? 4 }

    let engine: MetronomeEngine

    private var tapTempo = TapTempo()

    /// 설정 저장소입니다. nil이면 비영속(기본값 고정) — 단위 테스트 기본 모드입니다.
    private let store: UserDefaults?
    private static let settingsKey = "metronome.settings.v1"
    /// 초기 로드 완료 전에는 persist를 억제합니다(로드 중 didSet 폭주 방지).
    private var isLoaded = false

    var pulsesPerBeat: Int { Self.subCounts[subIdx] }

    init(engine: MetronomeEngine = MetronomeEngine(), store: UserDefaults? = nil) {
        self.engine = engine
        self.store = store
        if let store { loadSettings(from: store) }
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
            sound: sound, volume: volume
        )
    }

    /// 저장소에서 설정을 읽어 상태에 반영합니다(로드 중에는 persist가 억제됩니다).
    private func loadSettings(from store: UserDefaults) {
        guard let data = store.data(forKey: Self.settingsKey),
              let s = try? JSONDecoder().decode(MetronomeSettings.self, from: data) else { return }
        bpm = min(max(s.bpm, Self.bpmRange.lowerBound), Self.bpmRange.upperBound)
        denom = s.denom
        subIdx = min(max(s.subIdx, 0), Self.subCounts.count - 1)
        let restored = s.grid.map { row in row.map { AccentLevel(rawValue: $0) ?? .weak } }
        if !restored.isEmpty { grid = restored }
        sound = s.sound
        volume = min(max(s.volume, 0), 1)
    }

    /// 현재 상태를 저장소에 기록합니다. store가 없거나 로드 전이면 무시합니다.
    private func persist() {
        guard isLoaded, let store else { return }
        if let data = try? JSONEncoder().encode(snapshot()) {
            store.set(data, forKey: Self.settingsKey)
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
            do {
                try engine.start()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
        isPlaying = engine.isRunning
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
