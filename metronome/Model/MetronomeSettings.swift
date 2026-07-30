import Foundation

/// UserDefaults에 JSON으로 저장/복원하는 메트로놈 설정 스냅샷입니다.
///
/// 새 필드는 항상 옵셔널 또는 기본값 디코딩을 사용해 구버전 저장본과 호환됩니다.
struct MetronomeSettings: Codable, Equatable {
    var bpm: Double
    var denom: String
    var subIdx: Int
    var grid: [[Int]]
    var sound: ClickSound
    var volume: Double
    /// 템포 트레이너: 자동 가속 활성화 여부.
    var trainerEnabled: Bool
    /// 템포 트레이너: 몇 마디마다 올릴지.
    var trainerEveryBars: Int
    /// 템포 트레이너: 한 번에 올릴 BPM.
    var trainerBPMStep: Int
    /// 템포 트레이너: 도달 목표 BPM.
    var trainerTargetBPM: Int
    /// 시작 전 카운트인 마디 수(0=사용 안 함).
    var countInBars: Int
    /// 폴리리듬 마디당 펄스 수(0/1=사용 안 함).
    var polyPulses: Int
    /// 비주얼 플래시 사용 여부.
    var visualFlash: Bool
    /// 화면 모드(시스템/라이트/다크).
    var appearance: AppAppearance
    /// 창을 항상 위에 표시할지 여부.
    var floating: Bool
    /// 컴팩트(미니) 창 모드 사용 여부.
    var compact: Bool

    init(bpm: Double, denom: String, subIdx: Int, grid: [[Int]], sound: ClickSound, volume: Double,
         trainerEnabled: Bool = false, trainerEveryBars: Int = 2, trainerBPMStep: Int = 5,
         trainerTargetBPM: Int = 180, countInBars: Int = 0, polyPulses: Int = 0,
         visualFlash: Bool = false, appearance: AppAppearance = .system, floating: Bool = false,
         compact: Bool = false) {
        self.bpm = bpm
        self.denom = denom
        self.subIdx = subIdx
        self.grid = grid
        self.sound = sound
        self.volume = volume
        self.trainerEnabled = trainerEnabled
        self.trainerEveryBars = trainerEveryBars
        self.trainerBPMStep = trainerBPMStep
        self.trainerTargetBPM = trainerTargetBPM
        self.countInBars = countInBars
        self.polyPulses = polyPulses
        self.visualFlash = visualFlash
        self.appearance = appearance
        self.floating = floating
        self.compact = compact
    }

    // 구버전 저장본(신규 필드 부재)과 호환되도록 누락 키에 기본값을 채웁니다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bpm = try c.decode(Double.self, forKey: .bpm)
        denom = try c.decode(String.self, forKey: .denom)
        subIdx = try c.decode(Int.self, forKey: .subIdx)
        grid = try c.decode([[Int]].self, forKey: .grid)
        sound = try c.decodeIfPresent(ClickSound.self, forKey: .sound) ?? .woodBlock
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 0.8
        trainerEnabled = try c.decodeIfPresent(Bool.self, forKey: .trainerEnabled) ?? false
        trainerEveryBars = try c.decodeIfPresent(Int.self, forKey: .trainerEveryBars) ?? 2
        trainerBPMStep = try c.decodeIfPresent(Int.self, forKey: .trainerBPMStep) ?? 5
        trainerTargetBPM = try c.decodeIfPresent(Int.self, forKey: .trainerTargetBPM) ?? 180
        countInBars = try c.decodeIfPresent(Int.self, forKey: .countInBars) ?? 0
        polyPulses = try c.decodeIfPresent(Int.self, forKey: .polyPulses) ?? 0
        visualFlash = try c.decodeIfPresent(Bool.self, forKey: .visualFlash) ?? false
        appearance = try c.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
        floating = try c.decodeIfPresent(Bool.self, forKey: .floating) ?? false
        compact = try c.decodeIfPresent(Bool.self, forKey: .compact) ?? false
    }

    /// 프리셋 동일성 판정용 비교입니다.
    ///
    /// 프리셋이 저장/복원하는 범위는 "BPM·박자·강세·사운드·연습" 이므로,
    /// 표시/창 설정(플래시·화면 모드·항상 위에·컴팩트)은 비교에서 제외합니다.
    /// 다크 모드를 켰다고 적용 중인 프리셋 표시가 사라지면 안 됩니다.
    func musicallyEquals(_ other: MetronomeSettings) -> Bool {
        bpm == other.bpm
            && denom == other.denom
            && subIdx == other.subIdx
            && grid == other.grid
            && sound == other.sound
            && volume == other.volume
            && trainerEnabled == other.trainerEnabled
            && trainerEveryBars == other.trainerEveryBars
            && trainerBPMStep == other.trainerBPMStep
            && trainerTargetBPM == other.trainerTargetBPM
            && countInBars == other.countInBars
            && polyPulses == other.polyPulses
    }
}
