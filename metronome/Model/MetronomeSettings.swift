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

    init(bpm: Double, denom: String, subIdx: Int, grid: [[Int]], sound: ClickSound, volume: Double,
         trainerEnabled: Bool = false, trainerEveryBars: Int = 2, trainerBPMStep: Int = 5,
         trainerTargetBPM: Int = 180, countInBars: Int = 0) {
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
    }
}
