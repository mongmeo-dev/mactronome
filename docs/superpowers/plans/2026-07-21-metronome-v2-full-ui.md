# 메트로놈 앱 구현 계획 v2 — UI 전체 기능 구현 (개정)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`).

**개정 배경:** 사용자 지시 — "UI에 있는 기능은 전체 구현해야 한다." 디자인 핸드오프(design_handoff_metronome/Metronome.dc.html)는 원래 로직 계획(v1)보다 풍부한 상태 모델을 요구한다. v1의 Task 1~7(스캐폴딩~박자 스케줄러)은 완료·리뷰 통과 상태이며, 이 v2는 **Task 8부터 재설계**해 UI의 전체 기능을 오디오로 재생한다.

**Goal:** 디자인 UI의 전체 기능(펄스별 4단계 강세, subdivision 분할, 박자표 분자/분모)을 저지연 오디오로 재생한다.

**Architecture:** BeatScheduler를 박자 단위에서 **펄스 단위**로 확장한다. grid(박자별 펄스별 강세 레벨)를 오디오 스레드로 락프리 전달(더블 버퍼 + atomic 포인터 스왑)한다. ClickSynth는 4단계 강세를 음색+게인으로 구분한다.

## 사용자 확정 결정
- **4단계 강세 재생:** 음색(주파수)로 구분. 레벨 0=무음, 1=약박, 2=중강, 3=강박을 서로 다른 주파수+게인으로. (무음은 실제 무음)
- **사운드 선택(Wood Block 등):** UI만 표시, 오디오 로직은 이번 범위 제외 (현재 신테시스 클릭 하나만 사용).

## Global Constraints (v1에서 승계 + 추가)
- 최소 지원 OS: macOS 14.0, Swift + SwiftUI, XcodeGen
- 렌더 콜백 실시간 규칙 엄수: 힙 할당·락·ARC 유발 호출·로깅 금지. atomic load/store + 산술만.
- 사운드는 코드 신테시스, 오디오 에셋 미사용.
- 커밋에 Co-Author 삽입 금지. 커밋은 기능 단위.
- 코드 식별자 영어, 주석 한국어 경어체.
- **[신규] 상태 모델:** `grid: [[Int]]`(박자별 펄스별 강세 0~3), `subIdx`(0~5, pulsesPerBeat=[1,2,4,3,6,1]), `denom`(2/4/8/16), `bpm`. UI(feat/metronome-ui)의 상태 모델과 동일해야 함.
- **[신규] AccentLevel:** 로직·UI 공통으로 강세 레벨 0=mute,1=weak,2=medium,3=strong.

---

## 완료된 태스크 (v1, 리뷰 통과)
- Task 1: XcodeGen 스캐폴딩 + swift-atomics ✅
- Task 2: framesPerBeat ✅
- Task 3: TimeSignature (분자/isAccent) ✅ — v2에서 분모(denom) 추가 필요
- Task 4: TapTempo ✅
- Task 5: ClickSynth (2종) ✅ — v2에서 4단계로 확장
- Task 6: BeatEventChannel ✅ — v2에서 펄스/레벨 전달 확장 검토
- Task 7: BeatScheduler (박자 단위) ✅ — v2에서 펄스 단위로 확장

---

### Task 8 (v2): AccentLevel + ClickSynth 4단계 확장

**Files:**
- Create: `metronome/Model/AccentLevel.swift`
- Modify: `metronome/Audio/ClickSynth.swift`
- Test: `metronomeTests/AccentLevelTests.swift`, `metronomeTests/ClickSynthTests.swift`(추가)

**Interfaces:**
- Produces:
  - `enum AccentLevel: Int { case mute=0, weak=1, medium=2, strong=3 }` with `var gain: Float` and `var frequency: Double` (mute→gain 0).
  - `ClickSynth.makeLevelBuffers(sampleRate:) -> [[Float]]` — 인덱스 0~3의 강세별 클릭 버퍼 배열. 레벨 0(mute)은 무음(빈 배열 또는 0 버퍼).

- [ ] **Step 1: 실패 테스트 작성**

```swift
// metronomeTests/AccentLevelTests.swift
import XCTest
@testable import metronome

final class AccentLevelTests: XCTestCase {
    func test_mute_hasZeroGain() {
        XCTAssertEqual(AccentLevel.mute.gain, 0)
    }
    func test_strong_louderThanWeak() {
        XCTAssertGreaterThan(AccentLevel.strong.gain, AccentLevel.weak.gain)
    }
    func test_rawValuesMatchDesign() {
        XCTAssertEqual(AccentLevel.mute.rawValue, 0)
        XCTAssertEqual(AccentLevel.weak.rawValue, 1)
        XCTAssertEqual(AccentLevel.medium.rawValue, 2)
        XCTAssertEqual(AccentLevel.strong.rawValue, 3)
    }
}
```

```swift
// metronomeTests/ClickSynthTests.swift 에 추가
    func test_makeLevelBuffers_hasFourEntries_muteIsSilent() {
        let buffers = ClickSynth.makeLevelBuffers(sampleRate: 44100)
        XCTAssertEqual(buffers.count, 4)
        // 레벨 0(mute)은 모든 샘플이 0 이어야 함
        let mute = buffers[0]
        XCTAssertTrue(mute.allSatisfy { $0 == 0 })
        // 레벨 3(strong)은 비어있지 않고 0이 아닌 샘플 포함
        XCTAssertFalse(buffers[3].isEmpty)
        XCTAssertTrue(buffers[3].contains { $0 != 0 })
    }
```

- [ ] **Step 2: 테스트 실패 확인** — `xcodegen generate` 후 test. FAIL 예상.

- [ ] **Step 3: 구현**

```swift
// metronome/Model/AccentLevel.swift
import Foundation

/// 펄스의 강세 레벨입니다. 0=무음, 1=약박, 2=중강, 3=강박.
enum AccentLevel: Int, CaseIterable {
    case mute = 0
    case weak = 1
    case medium = 2
    case strong = 3

    /// 레벨별 재생 게인입니다. 무음은 0.
    var gain: Float {
        switch self {
        case .mute: return 0
        case .weak: return 0.35
        case .medium: return 0.6
        case .strong: return 1.0
        }
    }

    /// 레벨별 클릭 주파수입니다. 강박일수록 높은 음.
    var frequency: Double {
        switch self {
        case .mute: return 1000   // 사용 안 함(gain 0)
        case .weak: return 1000
        case .medium: return 1250
        case .strong: return 1600
        }
    }
}
```

`ClickSynth`에 추가:

```swift
    /// 강세 레벨 0~3의 클릭 버퍼 배열을 생성합니다. 레벨 0(mute)은 무음입니다.
    static func makeLevelBuffers(sampleRate: Double) -> [[Float]] {
        return AccentLevel.allCases.map { level in
            guard level.gain > 0 else {
                // 무음: duration만큼 0으로 채운 버퍼
                let count = Int(sampleRate * 0.02)
                return [Float](repeating: 0, count: count)
            }
            let base = makeClick(sampleRate: sampleRate, frequency: level.frequency, durationSeconds: 0.02)
            return base.map { $0 * level.gain }
        }
    }
```

- [ ] **Step 4: 테스트 통과 확인** — `xcodegen generate` 후 test PASS.

- [ ] **Step 5: 커밋** — `feat: 4단계 강세 레벨 및 클릭 버퍼 확장`

---

### Task 9 (v2): TimeSignature에 분모(denom) 추가

**Files:**
- Modify: `metronome/Model/TimeSignature.swift`
- Test: `metronomeTests/TimeSignatureTests.swift`(추가)

**Interfaces:**
- Produces: `TimeSignature`에 이미 `noteValue`가 있음. denom UI는 2/4/8/16. 프리셋과 `noteValue` 유효값 확인용 정적 배열 `noteValues: [Int] = [2,4,8,16]` 추가. (분모는 순수 표시 상태이며 박자 수·타이밍에 영향 없음 — 설계 확인)

- [ ] **Step 1: 실패 테스트 추가**

```swift
// metronomeTests/TimeSignatureTests.swift 에 추가
    func test_noteValues_areStandardDenominators() {
        XCTAssertEqual(TimeSignature.noteValues, [2, 4, 8, 16])
    }
    func test_withNoteValue_changesDenominatorOnly() {
        let ts = TimeSignature(beatsPerBar: 4, noteValue: 4).withNoteValue(8)
        XCTAssertEqual(ts.beatsPerBar, 4)
        XCTAssertEqual(ts.noteValue, 8)
    }
```

- [ ] **Step 2: 실패 확인**

- [ ] **Step 3: 구현** — `TimeSignature`에 추가:

```swift
    static let noteValues: [Int] = [2, 4, 8, 16]

    /// 분모만 바꾼 새 값을 반환합니다.
    func withNoteValue(_ value: Int) -> TimeSignature {
        TimeSignature(beatsPerBar: beatsPerBar, noteValue: value)
    }
```

- [ ] **Step 4: 통과 확인**
- [ ] **Step 5: 커밋** — `feat: 박자표 분모(denom) 지원 추가`

---

### Task 10 (v2): PulseGrid 락프리 전달 (더블 버퍼)

**Files:**
- Create: `metronome/Audio/PulseGrid.swift`
- Test: `metronomeTests/PulseGridTests.swift`

**Interfaces:**
- Produces:
  - `struct PulsePlan` — 평탄화된 펄스 시퀀스: `levels: [Int]`(전체 펄스의 강세, 박자 경계 무관 일렬), `beatBoundaries: [Int]`(각 펄스가 몇 번째 박자인지), `pulseCount: Int`, `pulsesPerBeat: Int`. UI의 grid를 오디오가 읽기 쉬운 평탄 형태로 변환.
  - `final class PulseGridChannel` — 락프리 더블 버퍼. UI 스레드가 `publish(_ plan: PulsePlan)`로 새 계획을 넣고, 오디오 스레드가 `current() -> PulsePlan`로 읽음. atomic 인덱스 스왑으로 torn read 방지. **주의:** publish는 UI 스레드에서 배열 할당 OK, current()는 오디오 스레드에서 참조만 반환(할당 없음).

**구현 노트:** 두 개의 슬롯 배열 `[PulsePlan?]`(size 2)과 `ManagedAtomic<Int> activeIndex`. publish는 비활성 슬롯에 쓰고 activeIndex를 스왑. current()는 activeIndex를 load해 해당 슬롯 반환. PulsePlan은 불변 값이므로 오디오가 읽는 동안 UI가 반대 슬롯을 갱신해도 안전. (완전한 무할당 실시간 안전을 원하면 향후 개선; MVP는 이 SPSC 스왑으로 충분.)

- [ ] **Step 1: 실패 테스트 작성**

```swift
// metronomeTests/PulseGridTests.swift
import XCTest
@testable import metronome

final class PulseGridTests: XCTestCase {
    func test_pulsePlan_flattensGrid() {
        // grid [[3],[1],[2],[1]], pulsesPerBeat 1
        let plan = PulsePlan(grid: [[3],[1],[2],[1]], pulsesPerBeat: 1)
        XCTAssertEqual(plan.levels, [3,1,2,1])
        XCTAssertEqual(plan.beatBoundaries, [0,1,2,3])
        XCTAssertEqual(plan.pulseCount, 4)
    }

    func test_pulsePlan_subdivided() {
        // 2 beats, pulsesPerBeat 2
        let plan = PulsePlan(grid: [[3,1],[2,1]], pulsesPerBeat: 2)
        XCTAssertEqual(plan.levels, [3,1,2,1])
        XCTAssertEqual(plan.beatBoundaries, [0,0,1,1])
        XCTAssertEqual(plan.pulseCount, 4)
    }

    func test_channel_publishThenCurrent() {
        let ch = PulseGridChannel()
        let plan = PulsePlan(grid: [[3],[1]], pulsesPerBeat: 1)
        ch.publish(plan)
        let got = ch.current()
        XCTAssertEqual(got.levels, [3,1])
    }

    func test_channel_defaultIsNonEmpty() {
        let ch = PulseGridChannel()
        // 기본값은 최소 1펄스(무음 아님) 이어야 크래시 없음
        XCTAssertGreaterThan(ch.current().pulseCount, 0)
    }
}
```

- [ ] **Step 2: 실패 확인**

- [ ] **Step 3: 구현**

```swift
// metronome/Audio/PulseGrid.swift
import Foundation
import Atomics

/// UI의 grid를 오디오가 읽기 쉬운 평탄 펄스 시퀀스로 변환한 불변 계획입니다.
struct PulsePlan {
    let levels: [Int]          // 전체 펄스의 강세 레벨(일렬)
    let beatBoundaries: [Int]  // 각 펄스의 소속 박자 인덱스
    let pulseCount: Int
    let pulsesPerBeat: Int

    init(grid: [[Int]], pulsesPerBeat: Int) {
        var lv: [Int] = []
        var bb: [Int] = []
        for (b, row) in grid.enumerated() {
            for level in row {
                lv.append(level)
                bb.append(b)
            }
        }
        // 빈 grid 방어: 최소 1펄스(무음) 보장
        if lv.isEmpty { lv = [0]; bb = [0] }
        self.levels = lv
        self.beatBoundaries = bb
        self.pulseCount = lv.count
        self.pulsesPerBeat = max(1, pulsesPerBeat)
    }

    static let `default` = PulsePlan(grid: [[3],[1],[2],[1]], pulsesPerBeat: 1)
}

/// 락프리 SPSC 더블 버퍼로 PulsePlan을 UI→오디오 전달합니다.
final class PulseGridChannel {
    private var slots: [PulsePlan]
    private let activeIndex = ManagedAtomic<Int>(0)

    init() {
        slots = [PulsePlan.default, PulsePlan.default]
    }

    /// UI 스레드에서 호출됩니다. 비활성 슬롯에 쓰고 인덱스를 스왑합니다.
    /// 주의: swift-atomics의 ordering 멤버는 .releasing/.acquiring 입니다(.release/.acquire 아님).
    func publish(_ plan: PulsePlan) {
        let active = activeIndex.load(ordering: .relaxed)
        let inactive = 1 - active
        slots[inactive] = plan
        activeIndex.store(inactive, ordering: .releasing)
    }

    /// 오디오 스레드에서 호출됩니다. 현재 활성 슬롯을 반환합니다(할당 없음).
    func current() -> PulsePlan {
        let active = activeIndex.load(ordering: .acquiring)
        return slots[active]
    }
}
```

- [ ] **Step 4: 통과 확인**
- [ ] **Step 5: 커밋** — `feat: 펄스 그리드 락프리 전달 채널 추가`

---

### Task 11 (v2): PulseScheduler (펄스 단위 스케줄러)

**Files:**
- Create: `metronome/Audio/PulseScheduler.swift`
- Test: `metronomeTests/PulseSchedulerTests.swift`

**Interfaces:**
- Consumes: `PulseGridChannel`/`PulsePlan` (Task 10), `framesPerBeat` (Task 2)
- Produces:
  - `final class PulseScheduler` — 펄스 단위로 발화하는 실시간 안전 스케줄러.
    - `init(sampleRate:)`
    - `func setFramesPerBeat(_:)` (atomic)
    - `let grid: PulseGridChannel`
    - `func reset()`
    - `struct Tick { let didFire: Bool; let pulseIndex: Int; let beatIndex: Int; let level: Int }`
    - `func advanceOneFrame() -> Tick` — framesPerPulse = framesPerBeat / pulsesPerBeat. 펄스 경계에서 발화하고 현재 PulsePlan에서 레벨 조회. 순수 산술 + atomic만.

**구현 노트:** 기존 BeatScheduler(Task 7)를 대체하는 확장판. 펄스 경계마다 pulseIndex를 진행(0..<pulseCount 순환), 발화 시 `plan.levels[pulseIndex]`와 `plan.beatBoundaries[pulseIndex]` 반환. framesPerPulse는 펄스 경계에서 최신 값 반영. plan은 `grid.current()`로 매 발화 시 읽되, 시퀀스 경계(pulseIndex 0으로 돌아올 때) plan을 재로드해 펄스 수 변경을 안전 반영.

- [ ] **Step 1: 실패 테스트 작성**

```swift
// metronomeTests/PulseSchedulerTests.swift
import XCTest
@testable import metronome

final class PulseSchedulerTests: XCTestCase {
    private func makeScheduler(grid: [[Int]], pulsesPerBeat: Int, framesPerBeat: Int) -> PulseScheduler {
        let s = PulseScheduler(sampleRate: 44100)
        s.grid.publish(PulsePlan(grid: grid, pulsesPerBeat: pulsesPerBeat))
        s.setFramesPerBeat(framesPerBeat)
        s.reset()
        return s
    }

    func test_firesOnFirstFrame_withFirstLevel() {
        let s = makeScheduler(grid: [[3],[1],[2],[1]], pulsesPerBeat: 1, framesPerBeat: 10)
        let tick = s.advanceOneFrame()
        XCTAssertTrue(tick.didFire)
        XCTAssertEqual(tick.pulseIndex, 0)
        XCTAssertEqual(tick.beatIndex, 0)
        XCTAssertEqual(tick.level, 3)
    }

    func test_pulsesPerBeat1_firesEveryFramesPerBeat() {
        let s = makeScheduler(grid: [[3],[1],[2],[1]], pulsesPerBeat: 1, framesPerBeat: 10)
        var fires: [Int] = []
        for f in 0..<41 {
            if s.advanceOneFrame().didFire { fires.append(f) }
        }
        XCTAssertEqual(fires, [0,10,20,30,40])
    }

    func test_subdivision2_firesEveryHalfBeat_withLevels() {
        // 2박자, 박자당 2펄스, framesPerBeat 10 -> framesPerPulse 5
        let s = makeScheduler(grid: [[3,1],[2,1]], pulsesPerBeat: 2, framesPerBeat: 10)
        var events: [(Int, Int, Int)] = [] // (frame, pulseIndex, level)
        for f in 0..<21 {
            let t = s.advanceOneFrame()
            if t.didFire { events.append((f, t.pulseIndex, t.level)) }
        }
        // frames 0,5,10,15,20 에서 발화; 펄스 인덱스 0,1,2,3,0; 레벨 3,1,2,1,3
        XCTAssertEqual(events.map { $0.0 }, [0,5,10,15,20])
        XCTAssertEqual(events.map { $0.1 }, [0,1,2,3,0])
        XCTAssertEqual(events.map { $0.2 }, [3,1,2,1,3])
    }

    func test_beatIndexTracksBoundaries() {
        let s = makeScheduler(grid: [[3,1],[2,1]], pulsesPerBeat: 2, framesPerBeat: 10)
        var beats: [Int] = []
        for _ in 0..<20 {
            let t = s.advanceOneFrame()
            if t.didFire { beats.append(t.beatIndex) }
        }
        // 펄스 0,1 -> beat 0; 펄스 2,3 -> beat 1
        XCTAssertEqual(beats, [0,0,1,1])
    }
}
```

- [ ] **Step 2: 실패 확인**

- [ ] **Step 3: 구현**

```swift
// metronome/Audio/PulseScheduler.swift
import Foundation
import Atomics

/// 펄스(박자의 하위 분할) 단위로 발화하는 실시간 안전 스케줄러입니다.
final class PulseScheduler {
    struct Tick {
        let didFire: Bool
        let pulseIndex: Int
        let beatIndex: Int
        let level: Int
    }

    let grid = PulseGridChannel()
    private let sampleRate: Double
    private let framesPerBeatAtomic = ManagedAtomic<Int>(22050)

    // 오디오 스레드 전용 상태.
    private var framesUntilNextPulse = 0
    private var pulseIndex = 0
    private var activePlan = PulsePlan.default

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func setFramesPerBeat(_ frames: Int) {
        framesPerBeatAtomic.store(max(1, frames), ordering: .relaxed)
    }

    func reset() {
        framesUntilNextPulse = 0
        pulseIndex = 0
        activePlan = grid.current()
    }

    private func framesPerPulse(for plan: PulsePlan) -> Int {
        let fpb = framesPerBeatAtomic.load(ordering: .relaxed)
        return max(1, fpb / max(1, plan.pulsesPerBeat))
    }

    /// 프레임 1개 진행. 펄스 경계면 didFire=true. 실시간 안전(할당·락 없음).
    func advanceOneFrame() -> Tick {
        if framesUntilNextPulse > 0 {
            framesUntilNextPulse -= 1
            return Tick(didFire: false, pulseIndex: pulseIndex, beatIndex: 0, level: 0)
        }

        // 시퀀스 시작(pulseIndex 0)에서 최신 plan 반영.
        if pulseIndex == 0 {
            activePlan = grid.current()
        }
        let plan = activePlan
        let idx = pulseIndex % plan.pulseCount
        let level = plan.levels[idx]
        let beatIndex = plan.beatBoundaries[idx]

        framesUntilNextPulse = framesPerPulse(for: plan) - 1
        pulseIndex = (idx + 1) % plan.pulseCount

        return Tick(didFire: true, pulseIndex: idx, beatIndex: beatIndex, level: level)
    }
}
```

- [ ] **Step 4: 통과 확인 (4 tests)**
- [ ] **Step 5: 커밋** — `feat: 펄스 단위 스케줄러 추가`

---

### Task 12 (v2): MetronomeEngine (펄스 스케줄러 + 4단계 버퍼 통합)

**Files:**
- Create: `metronome/Audio/MetronomeEngine.swift`
- Test: `metronomeTests/MetronomeEngineTests.swift`

**Interfaces:**
- Consumes: `PulseScheduler` (Task 11), `ClickSynth.makeLevelBuffers` (Task 8), `BeatEventChannel` (Task 6), `PulsePlan` (Task 10)
- Produces:
  - `final class MetronomeEngine`
    - `let beatChannel: BeatEventChannel`
    - `var isRunning: Bool`
    - `func updateBPM(_:)` / `func updateGrid(_ grid: [[Int]], pulsesPerBeat: Int)`
    - `func start() throws` / `func stop()`

**구현 노트:** v1 Task 8과 유사하나 PulseScheduler를 쓰고, 발화 시 `levelBuffers[tick.level]`을 재생(레벨 0은 무음 버퍼라 자동 무음). `beatChannel.publish(beatIndex: tick.beatIndex, isAccent: tick.level == 3)`로 UI에 강박 신호 전달. 렌더 콜백 실시간 규칙 엄수. AVAudioEngineConfigurationChange 구독으로 framesPerBeat 재계산.

- [ ] **Step 1: 실패 테스트 작성**

```swift
// metronomeTests/MetronomeEngineTests.swift
import XCTest
@testable import metronome

final class MetronomeEngineTests: XCTestCase {
    func test_initialState_notRunning() {
        XCTAssertFalse(MetronomeEngine().isRunning)
    }
    func test_startThenStop_togglesRunning() throws {
        let e = MetronomeEngine()
        try e.start()
        XCTAssertTrue(e.isRunning)
        e.stop()
        XCTAssertFalse(e.isRunning)
    }
    func test_updateGrid_whileStopped_doesNotCrash() {
        let e = MetronomeEngine()
        e.updateGrid([[3],[1],[2],[1]], pulsesPerBeat: 1)
        XCTAssertFalse(e.isRunning)
    }
    func test_configurationChange_keepsAlive() throws {
        let e = MetronomeEngine()
        e.updateBPM(150)
        try e.start()
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: nil)
        e.stop()
        XCTAssertFalse(e.isRunning)
    }
}
```

- [ ] **Step 2: 실패 확인**

- [ ] **Step 3: 구현** — (v1 Task 8/10의 MetronomeEngine 패턴을 PulseScheduler + levelBuffers로 작성. 렌더 콜백에서 tick.level로 버퍼 선택, framesPerBeat는 updateBPM에서 framesPerBeat(bpm:sampleRate:)로 계산해 scheduler.setFramesPerBeat. updateGrid는 scheduler.grid.publish(PulsePlan(grid:pulsesPerBeat:)). 콜백은 미리 생성한 levelBuffers만 읽음.)

```swift
// metronome/Audio/MetronomeEngine.swift
import Foundation
import AVFoundation

/// AVAudioEngine 기반 메트로놈 엔진입니다. 펄스 스케줄러와 4단계 강세 버퍼를 통합합니다.
final class MetronomeEngine {
    let beatChannel = BeatEventChannel()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let scheduler: PulseScheduler
    private let sampleRate: Double

    private var levelBuffers: [[Float]] = []   // 인덱스=강세 레벨
    private var playbackIndex = -1
    private var playingLevel = 0

    private(set) var isRunning = false
    private var currentBPM: Double = 120
    private var configObserver: NSObjectProtocol?

    init() {
        let format = engine.outputNode.outputFormat(forBus: 0)
        self.sampleRate = format.sampleRate > 0 ? format.sampleRate : 44100
        self.scheduler = PulseScheduler(sampleRate: sampleRate)
        self.levelBuffers = ClickSynth.makeLevelBuffers(sampleRate: sampleRate)
        scheduler.setFramesPerBeat(framesPerBeat(bpm: currentBPM, sampleRate: sampleRate))
        registerConfigObserver()
    }

    func updateBPM(_ bpm: Double) {
        currentBPM = bpm
        scheduler.setFramesPerBeat(framesPerBeat(bpm: bpm, sampleRate: sampleRate))
    }

    func updateGrid(_ grid: [[Int]], pulsesPerBeat: Int) {
        scheduler.grid.publish(PulsePlan(grid: grid, pulsesPerBeat: pulsesPerBeat))
    }

    func start() throws {
        guard !isRunning else { return }
        scheduler.reset()
        playbackIndex = -1
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
            guard let self = self else { return noErr }
            return self.render(frameCount: frameCount, abl: abl)
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.stop()
        if let node = sourceNode { engine.detach(node); sourceNode = nil }
        isRunning = false
    }

    private func render(frameCount: AVAudioFrameCount, abl: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(abl)
        guard let out = ablPointer.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
        for frame in 0..<Int(frameCount) {
            let tick = scheduler.advanceOneFrame()
            if tick.didFire {
                playbackIndex = 0
                playingLevel = tick.level
                beatChannel.publish(beatIndex: tick.beatIndex, isAccent: tick.level == 3)
            }
            var sample: Float = 0
            if playbackIndex >= 0, playingLevel >= 0, playingLevel < levelBuffers.count {
                let buf = levelBuffers[playingLevel]
                if playbackIndex < buf.count {
                    sample = buf[playbackIndex]
                    playbackIndex += 1
                } else {
                    playbackIndex = -1
                }
            }
            out[frame] = sample
        }
        return noErr
    }

    private func registerConfigObserver() {
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.scheduler.setFramesPerBeat(framesPerBeat(bpm: self.currentBPM, sampleRate: self.sampleRate))
            if self.isRunning { self.stop(); try? self.start() }
        }
    }

    deinit {
        if let o = configObserver { NotificationCenter.default.removeObserver(o) }
    }
}
```

- [ ] **Step 4: 통과 확인**
- [ ] **Step 5: 커밋** — `feat: 펄스 스케줄러·4단계 강세 통합 오디오 엔진 추가`

---

### Task 13 (v2): MetronomeState (grid/subdivision/denom 상태 + 엔진 배선)

**Files:**
- Create: `metronome/Model/MetronomeState.swift`
- Test: `metronomeTests/MetronomeStateTests.swift`

**Interfaces:**
- Consumes: `MetronomeEngine` (Task 12), `TimeSignature` (Task 9), `TapTempo` (Task 4), `AccentLevel` (Task 8)
- Produces: `@MainActor final class MetronomeState: ObservableObject` — UI(feat/metronome-ui)의 상태 모델과 동일. `grid: [[Int]]`, `subIdx: Int`, `denom: String`, `bpm: Double`, `isPlaying`. 액션: `cycleCell(beat:pulse:)`, `addBeat()`, `removeBeat()`, `setSubdivision(_:)`, `setDenom(_:)`, `setBPM(_:)`, `togglePlay()`, `tap()`. 변경 시 엔진에 `updateGrid`/`updateBPM` 전파. subCounts=[1,2,4,3,6,1].

**구현 노트:** 이 상태 클래스가 UI 브랜치의 로컬 @State 로직을 대체하는 단일 소유자가 된다. 병합 시 UI 뷰들이 이 MetronomeState를 @EnvironmentObject로 참조하도록 배선. grid 변경 로직(cycle/add/remove/resize)은 UI 브랜치의 검증된 로직과 동일해야 함.

- [ ] **Step 1~5:** grid 조작 액션별 단위 테스트(기본 grid, cycle (level+1)%4, addBeat max 12, removeBeat min 1, setSubdivision resize slice/pad-1, setBPM clamp 30~300, tap) 작성 → 구현 → 통과 → 커밋 `feat: 메트로놈 통합 상태 소유자 추가`. (테스트·구현 상세는 UI 브랜치의 grid 로직과 1:1 대응하도록 작성.)

---

### Task 14 (v2): UI 브랜치 병합 + 배선 + 시각 검증

**Files:**
- Merge: feat/metronome-ui → feat/metronome-mvp
- Modify: UI 뷰들이 `MetronomeState`(@EnvironmentObject) 참조하도록 배선; Start→togglePlay, TAP→tap, 바 클릭→cycleCell 연결
- Doc: `docs/superpowers/verification/timing-check.md`, 시각 검증 절차

**구현 노트:** 병합 후 UI의 로컬 @State를 MetronomeState로 치환. 바 클릭이 grid를 바꾸면 `updateGrid`가 엔진에 전파되고, 재생 중 소리가 즉시 반영되는지 확인. BeatIndicator/바 하이라이트를 beatChannel에 동기화(선택). 마지막으로 앱 실행 후 시각 검증(스크린샷) — 이는 사용자 육안 확인 하드 게이트.

- [ ] Step: 병합, 배선, 빌드+테스트, 실제 앱 실행 소리·인터랙션 확인, 커밋. 시각/청취 검증 문서화.

---

## Self-Review
- 4단계 강세 재생(음색+게인) → Task 8 ✅
- subdivision 분할 재생 → Task 10, 11 ✅
- 박자표 분자(박자 수)/분모 → Task 9, 13 ✅
- 펄스별 grid 강세 → Task 10~13 ✅
- 락프리 grid 전달 → Task 10 ✅
- UI 전체 기능 배선 → Task 14 ✅
- 사운드 선택: UI만(사용자 결정) — 로직 제외, 명시됨 ✅
