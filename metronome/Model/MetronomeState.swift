import Foundation

/// UI 상태의 단일 소유자입니다. grid/subdivision/denom/BPM/재생 상태를 보유하며
/// 변경 시 `MetronomeEngine`에 배선을 전파합니다.
@MainActor
final class MetronomeState: ObservableObject {
    /// BPM 허용 범위입니다.
    static let bpmRange: ClosedRange<Double> = 30...300
    /// 분할 인덱스별 박자당 펄스 수입니다.
    static let subCounts = [1, 2, 4, 3, 6, 1]

    /// 박자별 펄스 강세 그리드. 기본 [[3],[1],[2],[1]]
    @Published var grid: [[AccentLevel]] = [[.strong], [.weak], [.medium], [.weak]] {
        didSet { propagateGrid() }
    }
    /// 분할 인덱스 0..5
    @Published var subIdx: Int = 0 {
        didSet { propagateGrid() }
    }
    /// 분모: "2"/"4"/"8"/"16"
    @Published var denom: String = "4"
    /// BPM (30...300 클램프)
    @Published var bpm: Double = 120 {
        didSet { engine.updateBPM(bpm) }
    }
    /// 재생 상태
    @Published private(set) var isPlaying: Bool = false

    let engine: MetronomeEngine

    private var tapTempo = TapTempo()

    var pulsesPerBeat: Int { Self.subCounts[subIdx] }

    init(engine: MetronomeEngine = MetronomeEngine()) {
        self.engine = engine
        propagateGrid()
        engine.updateBPM(bpm)
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
        grid = grid.map { row in
            var newRow = Array(row.prefix(count))
            while newRow.count < count { newRow.append(.weak) }
            return newRow
        }
        subIdx = i
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
            try? engine.start()
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
