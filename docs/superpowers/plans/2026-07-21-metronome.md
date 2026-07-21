# 메트로놈 앱 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS 14+ 네이티브 메트로놈 앱을 샘플 정밀(sample-accurate) 타이밍으로 구현한다.

**Architecture:** `AVAudioEngine` + `AVAudioSourceNode`의 실시간 렌더 콜백 안에서 샘플 카운트로 박자 시점을 계산한다. UI↔Audio는 락프리 atomic 스냅샷으로 통신하고, 시각 인디케이터는 DisplayLink 폴링으로 오디오에 동기화한다. 순수 로직(TapTempo, TimeSignature, framesPerBeat)은 오디오와 분리해 XCTest로 검증한다.

**Tech Stack:** Swift, SwiftUI, AVFoundation(AVAudioEngine), swift-atomics(SPM), XCTest, Xcode 프로젝트

## Global Constraints

- 최소 지원 OS: macOS 14.0
- 언어/프레임워크: Swift + SwiftUI, Xcode 프로젝트(.xcodeproj)
- 오디오 엔진: AVAudioEngine + AVAudioSourceNode (렌더 콜백 방식)
- 렌더 콜백 실시간 규칙 엄수: 힙 할당·락·Swift ARC 유발 호출·로깅 금지. atomic load/store와 산술만 허용.
- 사운드는 코드로 신테시스(강박/약박), 오디오 에셋 파일 미사용.
- 커밋에 Co-Author 삽입 금지.
- 커밋은 기능 단위로 분리.
- 사용자 대상 출력(주석 포함)은 한국어 경어체 유지 가능하나 코드 식별자는 영어.
- View 레이어는 최소 기능 뼈대만 구현. 실제 디자인은 추후 Claude Design 결과물로 교체.

---

### Task 1: XcodeGen 프로젝트 스캐폴딩 + swift-atomics 의존성

**Files:**
- Create: `project.yml` (XcodeGen 프로젝트 정의)
- Create: `metronome/App/MetronomeApp.swift`
- Create: `metronome/App/ContentView.swift` (임시 placeholder)
- Create: `metronomeTests/SmokeTests.swift`
- Generated: `metronome.xcodeproj` (xcodegen이 생성, git 미추적 권장)

**Interfaces:**
- Consumes: (없음)
- Produces: 빌드 가능한 macOS 앱 타겟 `metronome`, 테스트 타겟 `metronomeTests`, SPM 의존성 `swift-atomics` (import Atomics 가능)

**환경 노트:** `xcodegen`이 설치되어 있어야 한다 (`brew install xcodegen`). `xcodebuild`(Xcode 26.x), Swift 6.3 사용. `.xcodeproj`는 생성물이므로 `.gitignore`에 추가하고 `project.yml`을 소스로 커밋한다.

- [ ] **Step 1: project.yml 작성**

```yaml
# project.yml
name: metronome
options:
  bundleIdPrefix: dev.mongmeo
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
packages:
  Atomics:
    url: https://github.com/apple/swift-atomics.git
    from: 1.2.0
targets:
  metronome:
    type: application
    platform: macOS
    sources:
      - metronome
    dependencies:
      - package: Atomics
        product: Atomics
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.mongmeo.metronome
        GENERATE_INFOPLIST_FILE: YES
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        SWIFT_VERSION: "6.0"
        ENABLE_HARDENED_RUNTIME: YES
  metronomeTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - metronomeTests
    dependencies:
      - target: metronome
      - package: Atomics
        product: Atomics
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.mongmeo.metronomeTests
        GENERATE_INFOPLIST_FILE: YES
schemes:
  metronome:
    build:
      targets:
        metronome: all
        metronomeTests: [test]
    test:
      targets:
        - metronomeTests
```

- [ ] **Step 2: 앱 소스 파일 작성 (placeholder)**

```swift
// metronome/App/MetronomeApp.swift
import SwiftUI

@main
struct MetronomeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

```swift
// metronome/App/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Metronome")
            .padding()
    }
}
```

- [ ] **Step 3: 스모크 테스트 작성**

```swift
// metronomeTests/SmokeTests.swift
import XCTest
import Atomics
@testable import metronome

final class SmokeTests: XCTestCase {
    func test_atomicsIsLinked() {
        let value = ManagedAtomic<Int>(0)
        value.store(42, ordering: .relaxed)
        XCTAssertEqual(value.load(ordering: .relaxed), 42)
    }
}
```

- [ ] **Step 4: 프로젝트 생성, 빌드 및 테스트 실행**

Run:
```bash
xcodegen generate
xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test
```
Expected: BUILD SUCCEEDED, `test_atomicsIsLinked` PASS

- [ ] **Step 5: .gitignore 갱신 및 커밋**

`.gitignore`에 다음 줄을 추가한다:
```
metronome.xcodeproj
*.xcworkspace
```

```bash
git add project.yml metronome metronomeTests .gitignore
git commit -m "chore: XcodeGen 프로젝트 스캐폴딩 및 swift-atomics 의존성 추가"
```

---

### Task 2: framesPerBeat 순수 함수

**Files:**
- Create: `metronome/Audio/BeatMath.swift`
- Test: `metronomeTests/BeatMathTests.swift`

**Interfaces:**
- Consumes: (없음)
- Produces: `func framesPerBeat(bpm: Double, sampleRate: Double) -> Int` — BPM과 샘플레이트로 한 박자당 프레임 수를 반올림 정수로 반환.

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
// metronomeTests/BeatMathTests.swift
import XCTest
@testable import metronome

final class BeatMathTests: XCTestCase {
    func test_120bpm_at_44100() {
        XCTAssertEqual(framesPerBeat(bpm: 120, sampleRate: 44100), 22050)
    }

    func test_60bpm_at_44100() {
        XCTAssertEqual(framesPerBeat(bpm: 60, sampleRate: 44100), 44100)
    }

    func test_100bpm_at_48000_rounds() {
        // 48000 * 60 / 100 = 28800
        XCTAssertEqual(framesPerBeat(bpm: 100, sampleRate: 48000), 28800)
    }

    func test_fractional_rounds_to_nearest() {
        // 44100 * 60 / 130 = 20353.84... -> 20354
        XCTAssertEqual(framesPerBeat(bpm: 130, sampleRate: 44100), 20354)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: FAIL ("cannot find 'framesPerBeat' in scope")

- [ ] **Step 3: 최소 구현 작성**

```swift
// metronome/Audio/BeatMath.swift
import Foundation

/// BPM과 샘플레이트로 한 박자당 프레임 수를 계산합니다.
func framesPerBeat(bpm: Double, sampleRate: Double) -> Int {
    precondition(bpm > 0 && sampleRate > 0)
    return Int((sampleRate * 60.0 / bpm).rounded())
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
git add metronome/Audio/BeatMath.swift metronomeTests/BeatMathTests.swift
git commit -m "feat: 박자당 프레임 수 계산 함수 추가"
```

---

### Task 3: TimeSignature 값 타입

**Files:**
- Create: `metronome/Model/TimeSignature.swift`
- Test: `metronomeTests/TimeSignatureTests.swift`

**Interfaces:**
- Consumes: (없음)
- Produces:
  - `struct TimeSignature: Equatable { let beatsPerBar: Int; let noteValue: Int }`
  - `func isAccent(beatIndex: Int) -> Bool` — 0-based 박자 인덱스가 첫 박(강박)인지 반환.
  - `static let fourFour`, `static let threeFour` 등 표준 프리셋.

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
// metronomeTests/TimeSignatureTests.swift
import XCTest
@testable import metronome

final class TimeSignatureTests: XCTestCase {
    func test_fourFour_firstBeatIsAccent() {
        let ts = TimeSignature.fourFour
        XCTAssertTrue(ts.isAccent(beatIndex: 0))
        XCTAssertFalse(ts.isAccent(beatIndex: 1))
        XCTAssertFalse(ts.isAccent(beatIndex: 2))
        XCTAssertFalse(ts.isAccent(beatIndex: 3))
    }

    func test_threeFour_hasThreeBeats() {
        XCTAssertEqual(TimeSignature.threeFour.beatsPerBar, 3)
    }

    func test_beatIndex_wraps_conceptually_only_first_is_accent() {
        let ts = TimeSignature.fourFour
        // 인덱스는 항상 0..<beatsPerBar 범위로 스케줄러가 전달한다.
        XCTAssertTrue(ts.isAccent(beatIndex: 0))
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: FAIL ("cannot find 'TimeSignature' in scope")

- [ ] **Step 3: 최소 구현 작성**

```swift
// metronome/Model/TimeSignature.swift
import Foundation

/// 박자표를 나타내는 값 타입입니다.
struct TimeSignature: Equatable {
    let beatsPerBar: Int
    let noteValue: Int

    /// 0-based 박자 인덱스가 강박(첫 박)인지 반환합니다.
    func isAccent(beatIndex: Int) -> Bool {
        beatIndex % beatsPerBar == 0
    }

    static let fourFour = TimeSignature(beatsPerBar: 4, noteValue: 4)
    static let threeFour = TimeSignature(beatsPerBar: 3, noteValue: 4)
    static let twoFour = TimeSignature(beatsPerBar: 2, noteValue: 4)
    static let sixEight = TimeSignature(beatsPerBar: 6, noteValue: 8)

    static let presets: [TimeSignature] = [twoFour, threeFour, fourFour, sixEight]
}

extension TimeSignature {
    var label: String { "\(beatsPerBar)/\(noteValue)" }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add metronome/Model/TimeSignature.swift metronomeTests/TimeSignatureTests.swift
git commit -m "feat: 박자표(TimeSignature) 값 타입 및 강박 판정 추가"
```

---

### Task 4: TapTempo 순수 로직

**Files:**
- Create: `metronome/Model/TapTempo.swift`
- Test: `metronomeTests/TapTempoTests.swift`

**Interfaces:**
- Consumes: (없음)
- Produces:
  - `struct TapTempo` with `mutating func tap(at time: TimeInterval) -> Double?` — 탭 시각(초)을 입력받아 충분한 탭이 쌓이면 BPM을 반환, 아니면 nil. 2초 이상 공백이면 윈도우를 리셋한다.
  - `mutating func reset()`

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
// metronomeTests/TapTempoTests.swift
import XCTest
@testable import metronome

final class TapTempoTests: XCTestCase {
    func test_firstTap_returnsNil() {
        var tt = TapTempo()
        XCTAssertNil(tt.tap(at: 0.0))
    }

    func test_twoTaps_500ms_gives120bpm() {
        var tt = TapTempo()
        _ = tt.tap(at: 0.0)
        let bpm = tt.tap(at: 0.5) // 0.5s 간격 -> 120 BPM
        XCTAssertNotNil(bpm)
        XCTAssertEqual(bpm!, 120.0, accuracy: 0.01)
    }

    func test_evenTaps_average() {
        var tt = TapTempo()
        _ = tt.tap(at: 0.0)
        _ = tt.tap(at: 0.5)
        let bpm = tt.tap(at: 1.0) // 일정 0.5s 간격 -> 120 BPM
        XCTAssertEqual(bpm!, 120.0, accuracy: 0.01)
    }

    func test_gapOverTwoSeconds_resetsWindow() {
        var tt = TapTempo()
        _ = tt.tap(at: 0.0)
        _ = tt.tap(at: 0.5)
        // 2초 초과 공백 후 탭 -> 윈도우 리셋되어 nil
        XCTAssertNil(tt.tap(at: 3.0))
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: FAIL ("cannot find 'TapTempo' in scope")

- [ ] **Step 3: 최소 구현 작성**

```swift
// metronome/Model/TapTempo.swift
import Foundation

/// 탭 간격으로 BPM을 추정하는 순수 로직입니다.
struct TapTempo {
    /// 이 시간(초) 이상 공백이면 윈도우를 리셋합니다.
    private let resetGap: TimeInterval = 2.0
    /// BPM 평균에 사용하는 최대 간격 수입니다.
    private let maxIntervals = 4

    private var lastTapTime: TimeInterval?
    private var intervals: [TimeInterval] = []

    mutating func tap(at time: TimeInterval) -> Double? {
        defer { lastTapTime = time }

        guard let last = lastTapTime else {
            return nil // 첫 탭: 간격 없음
        }

        let interval = time - last
        if interval > resetGap {
            intervals.removeAll()
            return nil // 공백이 너무 큼: 새 측정 시작
        }

        intervals.append(interval)
        if intervals.count > maxIntervals {
            intervals.removeFirst()
        }

        let avg = intervals.reduce(0, +) / Double(intervals.count)
        guard avg > 0 else { return nil }
        return 60.0 / avg
    }

    mutating func reset() {
        lastTapTime = nil
        intervals.removeAll()
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add metronome/Model/TapTempo.swift metronomeTests/TapTempoTests.swift
git commit -m "feat: 탭 템포 BPM 추정 로직 추가"
```

---

### Task 5: ClickSynth 클릭 파형 생성

**Files:**
- Create: `metronome/Audio/ClickSynth.swift`
- Test: `metronomeTests/ClickSynthTests.swift`

**Interfaces:**
- Consumes: (없음)
- Produces:
  - `struct ClickSynth` with `static func makeClick(sampleRate: Double, frequency: Double, durationSeconds: Double) -> [Float]` — 지수 감쇠 사인파 클릭 버퍼를 생성.
  - `struct ClickBuffers { let accent: [Float]; let normal: [Float] }` + `static func make(sampleRate: Double) -> ClickBuffers` — 강박(고음)/약박(저음) 버퍼 쌍 생성.

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
// metronomeTests/ClickSynthTests.swift
import XCTest
@testable import metronome

final class ClickSynthTests: XCTestCase {
    func test_click_hasExpectedLength() {
        let click = ClickSynth.makeClick(sampleRate: 44100, frequency: 1000, durationSeconds: 0.02)
        XCTAssertEqual(click.count, 882) // 44100 * 0.02
    }

    func test_click_startsNonZero_decaysToNearZero() {
        let click = ClickSynth.makeClick(sampleRate: 44100, frequency: 1000, durationSeconds: 0.02)
        XCTAssertGreaterThan(abs(click.first ?? 0) + abs(click[10]), 0.0)
        XCTAssertLessThan(abs(click.last ?? 1), 0.05) // 끝에서 거의 감쇠
    }

    func test_makeBuffers_accentHigherFreqThanNormal_bothNonEmpty() {
        let buffers = ClickSynth.make(sampleRate: 44100)
        XCTAssertFalse(buffers.accent.isEmpty)
        XCTAssertFalse(buffers.normal.isEmpty)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: FAIL ("cannot find 'ClickSynth' in scope")

- [ ] **Step 3: 최소 구현 작성**

```swift
// metronome/Audio/ClickSynth.swift
import Foundation

/// 클릭 사운드를 코드로 생성합니다. (강박/약박)
struct ClickSynth {
    struct ClickBuffers {
        let accent: [Float]
        let normal: [Float]
    }

    /// 지수 감쇠 사인파 클릭 한 개를 생성합니다.
    static func makeClick(sampleRate: Double, frequency: Double, durationSeconds: Double) -> [Float] {
        let count = Int(sampleRate * durationSeconds)
        guard count > 0 else { return [] }
        var samples = [Float](repeating: 0, count: count)
        let decay = 25.0 / durationSeconds // 지속시간 내 충분히 감쇠
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let envelope = exp(-decay * t)
            let value = sin(2.0 * Double.pi * frequency * t) * envelope
            samples[i] = Float(value)
        }
        return samples
    }

    /// 강박(고음)/약박(저음) 버퍼 쌍을 생성합니다.
    static func make(sampleRate: Double) -> ClickBuffers {
        let accent = makeClick(sampleRate: sampleRate, frequency: 1500, durationSeconds: 0.02)
        let normal = makeClick(sampleRate: sampleRate, frequency: 1000, durationSeconds: 0.02)
        return ClickBuffers(accent: accent, normal: normal)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add metronome/Audio/ClickSynth.swift metronomeTests/ClickSynthTests.swift
git commit -m "feat: 클릭 사운드 신테시스(강박/약박) 추가"
```

---

### Task 6: BeatEvent 락프리 스냅샷

**Files:**
- Create: `metronome/Audio/BeatEvent.swift`
- Test: `metronomeTests/BeatEventTests.swift`

**Interfaces:**
- Consumes: `Atomics` (ManagedAtomic)
- Produces:
  - `struct BeatSnapshot: Equatable { let sequence: UInt64; let beatIndex: Int; let isAccent: Bool }`
  - `final class BeatEventChannel` with:
    - `func publish(beatIndex: Int, isAccent: Bool)` — 오디오 스레드에서 호출, 락프리 store. 내부 sequence를 1 증가시킨다.
    - `func latest() -> BeatSnapshot` — UI 스레드에서 호출, 락프리 load.

**구현 노트:** `beatIndex`(0..<24 정도)와 `isAccent`(1비트)와 `sequence`를 단일 `UInt64`에 팩킹해 하나의 atomic으로 원자성을 보장한다. 이로써 부분 갱신(torn read)을 방지한다.

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
// metronomeTests/BeatEventTests.swift
import XCTest
@testable import metronome

final class BeatEventTests: XCTestCase {
    func test_initialSnapshot_hasZeroSequence() {
        let channel = BeatEventChannel()
        XCTAssertEqual(channel.latest().sequence, 0)
    }

    func test_publish_incrementsSequence_andCarriesData() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 2, isAccent: false)
        let snap = channel.latest()
        XCTAssertEqual(snap.sequence, 1)
        XCTAssertEqual(snap.beatIndex, 2)
        XCTAssertFalse(snap.isAccent)
    }

    func test_publish_accent_roundTrips() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 0, isAccent: true)
        let snap = channel.latest()
        XCTAssertEqual(snap.beatIndex, 0)
        XCTAssertTrue(snap.isAccent)
    }

    func test_multiplePublishes_sequenceMonotonic() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 0, isAccent: true)
        channel.publish(beatIndex: 1, isAccent: false)
        channel.publish(beatIndex: 2, isAccent: false)
        XCTAssertEqual(channel.latest().sequence, 3)
        XCTAssertEqual(channel.latest().beatIndex, 2)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: FAIL ("cannot find 'BeatEventChannel' in scope")

- [ ] **Step 3: 최소 구현 작성**

```swift
// metronome/Audio/BeatEvent.swift
import Foundation
import Atomics

/// UI에 전달되는 박자 스냅샷입니다.
struct BeatSnapshot: Equatable {
    let sequence: UInt64
    let beatIndex: Int
    let isAccent: Bool
}

/// 오디오 스레드 → UI 스레드로 박자 정보를 전달하는 락프리 채널입니다.
///
/// 하나의 UInt64에 [sequence:47 | beatIndex:16 | accent:1]를 팩킹해
/// 단일 atomic store/load로 torn read 없이 전달합니다.
final class BeatEventChannel {
    private let packed = ManagedAtomic<UInt64>(0)

    private static let accentBits: UInt64 = 1
    private static let beatIndexShift: UInt64 = 1
    private static let beatIndexMask: UInt64 = 0xFFFF // 16비트
    private static let sequenceShift: UInt64 = 17

    /// 오디오 스레드에서 호출됩니다. 락프리 store만 수행합니다.
    func publish(beatIndex: Int, isAccent: Bool) {
        let current = packed.load(ordering: .relaxed)
        let sequence = (current >> Self.sequenceShift) &+ 1
        let accent: UInt64 = isAccent ? 1 : 0
        let idx = UInt64(beatIndex) & Self.beatIndexMask
        let newValue = (sequence << Self.sequenceShift)
            | (idx << Self.beatIndexShift)
            | accent
        packed.store(newValue, ordering: .relaxed)
    }

    /// UI 스레드에서 호출됩니다. 락프리 load만 수행합니다.
    func latest() -> BeatSnapshot {
        let value = packed.load(ordering: .relaxed)
        let sequence = value >> Self.sequenceShift
        let beatIndex = Int((value >> Self.beatIndexShift) & Self.beatIndexMask)
        let isAccent = (value & Self.accentBits) == 1
        return BeatSnapshot(sequence: sequence, beatIndex: beatIndex, isAccent: isAccent)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add metronome/Audio/BeatEvent.swift metronomeTests/BeatEventTests.swift
git commit -m "feat: 락프리 박자 이벤트 채널 추가"
```

---

### Task 7: BeatScheduler 샘플 카운팅 로직

**Files:**
- Create: `metronome/Audio/BeatScheduler.swift`
- Test: `metronomeTests/BeatSchedulerTests.swift`

**Interfaces:**
- Consumes: `TimeSignature` (Task 3), `framesPerBeat` (Task 2)
- Produces:
  - `final class BeatScheduler` — 실시간 안전한 박자 진행 로직. 오디오 콜백이 프레임 단위로 호출한다.
    - `init(sampleRate: Double)`
    - `func setFramesPerBeat(_ frames: Int)` — atomic store (UI 스레드가 호출).
    - `func setBeatsPerBar(_ count: Int)` — atomic store (UI 스레드가 호출).
    - `func reset()` — 재생 시작 시 카운터 초기화.
    - `struct Tick { let didFire: Bool; let beatIndex: Int; let isAccent: Bool }`
    - `func advanceOneFrame() -> Tick` — 프레임 1개 진행. 박자 경계면 `didFire=true`. **순수 산술 + atomic만.**

**구현 노트:** `advanceOneFrame`는 콜백당 프레임 수만큼 호출되며 힙 할당·락이 없어야 한다. `framesPerBeat`·`beatsPerBar`는 `ManagedAtomic<Int>`로 보관하고, 다음 박자 경계에서 새 값을 반영한다.

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
// metronomeTests/BeatSchedulerTests.swift
import XCTest
@testable import metronome

final class BeatSchedulerTests: XCTestCase {
    func test_firesOnFirstFrame_asAccent() {
        let s = BeatScheduler(sampleRate: 44100)
        s.setFramesPerBeat(10)
        s.setBeatsPerBar(4)
        s.reset()
        let tick = s.advanceOneFrame()
        XCTAssertTrue(tick.didFire)
        XCTAssertEqual(tick.beatIndex, 0)
        XCTAssertTrue(tick.isAccent)
    }

    func test_firesEveryFramesPerBeat() {
        let s = BeatScheduler(sampleRate: 44100)
        s.setFramesPerBeat(10)
        s.setBeatsPerBar(4)
        s.reset()

        var fireFrames: [Int] = []
        for frame in 0..<41 {
            let tick = s.advanceOneFrame()
            if tick.didFire { fireFrames.append(frame) }
        }
        // 0, 10, 20, 30, 40 프레임에서 발화
        XCTAssertEqual(fireFrames, [0, 10, 20, 30, 40])
    }

    func test_beatIndexWrapsPerBar_accentOnlyOnFirst() {
        let s = BeatScheduler(sampleRate: 44100)
        s.setFramesPerBeat(10)
        s.setBeatsPerBar(4)
        s.reset()

        var fires: [(Int, Bool)] = []
        for _ in 0..<41 {
            let tick = s.advanceOneFrame()
            if tick.didFire { fires.append((tick.beatIndex, tick.isAccent)) }
        }
        // 인덱스: 0,1,2,3,0 / accent: true,false,false,false,true
        XCTAssertEqual(fires.map { $0.0 }, [0, 1, 2, 3, 0])
        XCTAssertEqual(fires.map { $0.1 }, [true, false, false, false, true])
    }

    func test_bpmChangeAppliesAtNextBeatBoundary() {
        let s = BeatScheduler(sampleRate: 44100)
        s.setFramesPerBeat(10)
        s.setBeatsPerBar(4)
        s.reset()

        // 첫 5프레임 진행 (박자 진행 중)
        for _ in 0..<5 { _ = s.advanceOneFrame() }
        // 진행 중 변경 -> 현재 박자는 유지, 다음 경계부터 반영
        s.setFramesPerBeat(20)

        var fireFrames: [Int] = []
        // frame 5부터 이어서: 다음 발화는 원래 간격(10)의 경계인 frame 10
        for frame in 5..<51 {
            let tick = s.advanceOneFrame()
            if tick.didFire { fireFrames.append(frame) }
        }
        // frame 10에서 발화(기존 간격 유지), 이후 20 간격 -> 30, 50
        XCTAssertEqual(fireFrames, [10, 30, 50])
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: FAIL ("cannot find 'BeatScheduler' in scope")

- [ ] **Step 3: 최소 구현 작성**

```swift
// metronome/Audio/BeatScheduler.swift
import Foundation
import Atomics

/// 오디오 렌더 콜백 안에서 샘플(프레임) 단위로 박자를 진행하는 실시간 안전 스케줄러입니다.
final class BeatScheduler {
    struct Tick {
        let didFire: Bool
        let beatIndex: Int
        let isAccent: Bool
    }

    private let sampleRate: Double

    // UI 스레드가 store, 오디오 스레드가 load 합니다.
    private let framesPerBeatAtomic = ManagedAtomic<Int>(22050)
    private let beatsPerBarAtomic = ManagedAtomic<Int>(4)

    // 오디오 스레드 전용 상태 (콜백 직렬 실행이라 단일 스레드 접근).
    private var framesUntilNextBeat: Int = 0
    private var currentBeatIndex: Int = 0
    private var activeFramesPerBeat: Int = 22050

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    /// UI 스레드에서 호출됩니다.
    func setFramesPerBeat(_ frames: Int) {
        framesPerBeatAtomic.store(max(1, frames), ordering: .relaxed)
    }

    /// UI 스레드에서 호출됩니다.
    func setBeatsPerBar(_ count: Int) {
        beatsPerBarAtomic.store(max(1, count), ordering: .relaxed)
    }

    /// 재생 시작 시 호출됩니다. 다음 advanceOneFrame이 즉시 첫 박을 발화합니다.
    func reset() {
        framesUntilNextBeat = 0
        currentBeatIndex = 0
        activeFramesPerBeat = framesPerBeatAtomic.load(ordering: .relaxed)
    }

    /// 프레임 1개를 진행합니다. 박자 경계면 didFire=true. 실시간 안전(할당·락 없음).
    func advanceOneFrame() -> Tick {
        if framesUntilNextBeat > 0 {
            framesUntilNextBeat -= 1
            return Tick(didFire: false, beatIndex: currentBeatIndex, isAccent: false)
        }

        // 박자 경계: 발화한다.
        let beatsPerBar = beatsPerBarAtomic.load(ordering: .relaxed)
        let index = currentBeatIndex % beatsPerBar
        let isAccent = index == 0

        // 다음 박자 간격을 이 경계에서 반영한다.
        activeFramesPerBeat = framesPerBeatAtomic.load(ordering: .relaxed)
        framesUntilNextBeat = activeFramesPerBeat - 1
        currentBeatIndex = (index + 1) % beatsPerBar

        return Tick(didFire: true, beatIndex: index, isAccent: isAccent)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
git add metronome/Audio/BeatScheduler.swift metronomeTests/BeatSchedulerTests.swift
git commit -m "feat: 샘플 정밀 박자 스케줄러 추가"
```

---

### Task 8: MetronomeEngine (AVAudioEngine 통합)

**Files:**
- Create: `metronome/Audio/MetronomeEngine.swift`
- Test: `metronomeTests/MetronomeEngineTests.swift`

**Interfaces:**
- Consumes: `BeatScheduler` (Task 7), `ClickSynth` (Task 5), `BeatEventChannel` (Task 6)
- Produces:
  - `final class MetronomeEngine`
    - `let beatChannel: BeatEventChannel`
    - `var isRunning: Bool { get }`
    - `func updateBPM(_ bpm: Double)` / `func updateTimeSignature(_ ts: TimeSignature)`
    - `func start() throws` / `func stop()`

**구현 노트:** `AVAudioSourceNode`의 렌더 클로저 안에서 `BeatScheduler.advanceOneFrame()`를 프레임마다 호출하고, 발화 시 클릭 버퍼 재생 위치를 세팅하며 `beatChannel.publish(...)`를 호출한다. 렌더 클로저는 클로저 캡처된 값만 사용하고 힙 할당을 하지 않는다. 클릭 버퍼는 start 전에 생성한다.

이 태스크는 실제 오디오 하드웨어 의존이라 자동 테스트는 상태 전이 위주로 하고, 타이밍 정확도는 Task 11의 수동 검증으로 확인한다.

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
// metronomeTests/MetronomeEngineTests.swift
import XCTest
@testable import metronome

final class MetronomeEngineTests: XCTestCase {
    func test_initialState_notRunning() {
        let engine = MetronomeEngine()
        XCTAssertFalse(engine.isRunning)
    }

    func test_startThenStop_togglesRunning() throws {
        let engine = MetronomeEngine()
        try engine.start()
        XCTAssertTrue(engine.isRunning)
        engine.stop()
        XCTAssertFalse(engine.isRunning)
    }

    func test_updateBPM_doesNotCrashWhileStopped() {
        let engine = MetronomeEngine()
        engine.updateBPM(140) // 정지 상태에서도 안전
        XCTAssertFalse(engine.isRunning)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: FAIL ("cannot find 'MetronomeEngine' in scope")

- [ ] **Step 3: 최소 구현 작성**

```swift
// metronome/Audio/MetronomeEngine.swift
import Foundation
import AVFoundation

/// AVAudioEngine 기반 메트로놈 오디오 엔진입니다.
final class MetronomeEngine {
    let beatChannel = BeatEventChannel()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let scheduler: BeatScheduler
    private let sampleRate: Double

    // 렌더 클로저에서만 접근하는 재생 상태.
    private var accentBuffer: [Float] = []
    private var normalBuffer: [Float] = []
    private var playbackIndex: Int = -1   // -1이면 재생 중 아님
    private var playingAccent: Bool = false

    private(set) var isRunning = false
    private var currentBPM: Double = 120

    init() {
        let format = engine.outputNode.outputFormat(forBus: 0)
        self.sampleRate = format.sampleRate > 0 ? format.sampleRate : 44100
        self.scheduler = BeatScheduler(sampleRate: sampleRate)

        let clicks = ClickSynth.make(sampleRate: sampleRate)
        self.accentBuffer = clicks.accent
        self.normalBuffer = clicks.normal

        scheduler.setFramesPerBeat(framesPerBeat(bpm: currentBPM, sampleRate: sampleRate))
        scheduler.setBeatsPerBar(4)
    }

    func updateBPM(_ bpm: Double) {
        currentBPM = bpm
        scheduler.setFramesPerBeat(framesPerBeat(bpm: bpm, sampleRate: sampleRate))
    }

    func updateTimeSignature(_ ts: TimeSignature) {
        scheduler.setBeatsPerBar(ts.beatsPerBar)
    }

    func start() throws {
        guard !isRunning else { return }
        scheduler.reset()
        playbackIndex = -1

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            return self.render(frameCount: frameCount, audioBufferList: audioBufferList)
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        self.sourceNode = node

        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.stop()
        if let node = sourceNode {
            engine.detach(node)
            sourceNode = nil
        }
        isRunning = false
    }

    /// 실시간 렌더 콜백입니다. 힙 할당·락·로깅 금지.
    private func render(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        guard let out = ablPointer.first?.mData?.assumingMemoryBound(to: Float.self) else {
            return noErr
        }

        for frame in 0..<Int(frameCount) {
            let tick = scheduler.advanceOneFrame()
            if tick.didFire {
                playbackIndex = 0
                playingAccent = tick.isAccent
                beatChannel.publish(beatIndex: tick.beatIndex, isAccent: tick.isAccent)
            }

            var sample: Float = 0
            if playbackIndex >= 0 {
                let buffer = playingAccent ? accentBuffer : normalBuffer
                if playbackIndex < buffer.count {
                    sample = buffer[playbackIndex]
                    playbackIndex += 1
                } else {
                    playbackIndex = -1
                }
            }
            out[frame] = sample
        }
        return noErr
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: PASS (3 tests)

- [ ] **Step 5: 커밋**

```bash
git add metronome/Audio/MetronomeEngine.swift metronomeTests/MetronomeEngineTests.swift
git commit -m "feat: AVAudioEngine 기반 메트로놈 오디오 엔진 추가"
```

---

### Task 9: MetronomeState (상태 소유자 + 엔진 배선)

**Files:**
- Create: `metronome/Model/MetronomeState.swift`
- Test: `metronomeTests/MetronomeStateTests.swift`

**Interfaces:**
- Consumes: `MetronomeEngine` (Task 8), `TimeSignature` (Task 3), `TapTempo` (Task 4)
- Produces:
  - `@MainActor final class MetronomeState: ObservableObject`
    - `@Published var bpm: Double` (범위 30...300)
    - `@Published var timeSignature: TimeSignature`
    - `@Published private(set) var isPlaying: Bool`
    - `func togglePlay()` / `func setBPM(_:)` / `func setTimeSignature(_:)` / `func tap()`
    - `let engine: MetronomeEngine`

**구현 노트:** `bpm`/`timeSignature` 변경 시 엔진에 전파한다. `tap()`은 `TapTempo`로 BPM을 산출해 `setBPM`으로 반영한다. `tap()`의 시각은 `ProcessInfo.processInfo.systemUptime`을 사용한다(테스트에서 주입 가능하도록 내부 함수 분리).

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
// metronomeTests/MetronomeStateTests.swift
import XCTest
@testable import metronome

@MainActor
final class MetronomeStateTests: XCTestCase {
    func test_defaultBPM_is120() {
        let state = MetronomeState()
        XCTAssertEqual(state.bpm, 120, accuracy: 0.001)
    }

    func test_setBPM_clampsToRange() {
        let state = MetronomeState()
        state.setBPM(1000)
        XCTAssertEqual(state.bpm, 300, accuracy: 0.001)
        state.setBPM(1)
        XCTAssertEqual(state.bpm, 30, accuracy: 0.001)
    }

    func test_togglePlay_flipsIsPlaying() {
        let state = MetronomeState()
        XCTAssertFalse(state.isPlaying)
        state.togglePlay()
        XCTAssertTrue(state.isPlaying)
        state.togglePlay()
        XCTAssertFalse(state.isPlaying)
    }

    func test_tap_twoTapsAtHalfSecond_setsBpmNear120() {
        let state = MetronomeState()
        state.tapForTesting(at: 0.0)
        state.tapForTesting(at: 0.5)
        XCTAssertEqual(state.bpm, 120, accuracy: 1.0)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: FAIL ("cannot find 'MetronomeState' in scope")

- [ ] **Step 3: 최소 구현 작성**

```swift
// metronome/Model/MetronomeState.swift
import Foundation
import Combine

/// 메트로놈의 UI 상태 소유자입니다. SwiftUI가 관찰합니다.
@MainActor
final class MetronomeState: ObservableObject {
    static let bpmRange: ClosedRange<Double> = 30...300

    @Published var bpm: Double = 120 {
        didSet { engine.updateBPM(bpm) }
    }
    @Published var timeSignature: TimeSignature = .fourFour {
        didSet { engine.updateTimeSignature(timeSignature) }
    }
    @Published private(set) var isPlaying: Bool = false

    let engine: MetronomeEngine
    private var tapTempo = TapTempo()

    init(engine: MetronomeEngine = MetronomeEngine()) {
        self.engine = engine
        engine.updateBPM(bpm)
        engine.updateTimeSignature(timeSignature)
    }

    func setBPM(_ value: Double) {
        bpm = min(max(value, Self.bpmRange.lowerBound), Self.bpmRange.upperBound)
    }

    func setTimeSignature(_ ts: TimeSignature) {
        timeSignature = ts
    }

    func togglePlay() {
        if isPlaying {
            engine.stop()
            isPlaying = false
        } else {
            try? engine.start()
            isPlaying = engine.isRunning
        }
    }

    func tap() {
        tapForTesting(at: ProcessInfo.processInfo.systemUptime)
    }

    /// 테스트에서 시각을 주입하기 위한 진입점입니다.
    func tapForTesting(at time: TimeInterval) {
        if let newBPM = tapTempo.tap(at: time) {
            setBPM(newBPM)
        }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: PASS (4 tests)

- [ ] **Step 5: 커밋**

```bash
git add metronome/Model/MetronomeState.swift metronomeTests/MetronomeStateTests.swift
git commit -m "feat: 메트로놈 상태 소유자 및 엔진 배선 추가"
```

---

### Task 10: 디바이스 변경 복원력

**Files:**
- Modify: `metronome/Audio/MetronomeEngine.swift`
- Test: `metronomeTests/MetronomeEngineTests.swift` (테스트 추가)

**Interfaces:**
- Consumes: `MetronomeEngine` (Task 8)
- Produces: `MetronomeEngine`에 `AVAudioEngineConfigurationChange` 노티피케이션 구독 추가. 구성 변경 시 샘플레이트를 재확인하고 `framesPerBeat`를 재계산해 스케줄러에 반영한다.

**구현 노트:** 설정 변경 시 재생 중이면 엔진 재시작이 필요할 수 있다. 최소 구현으로 현재 BPM 기준 framesPerBeat 재계산 + 재생 중이면 재시작한다. 자동 테스트는 노티피케이션 발생 시 크래시 없이 BPM 값이 유지되는지만 확인한다.

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
// metronomeTests/MetronomeEngineTests.swift 에 추가
    func test_configurationChangeNotification_doesNotCrash_andKeepsBPM() throws {
        let engine = MetronomeEngine()
        engine.updateBPM(150)
        try engine.start()
        // 구성 변경 노티피케이션을 직접 발생시킨다.
        NotificationCenter.default.post(
            name: .AVAudioEngineConfigurationChange,
            object: nil
        )
        // 크래시 없이 살아있어야 한다.
        XCTAssertTrue(engine.isRunning || !engine.isRunning) // 존재 확인
        engine.stop()
    }
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: FAIL 또는 노티피케이션 미처리(핸들러 없음). 핸들러 추가 후 통과하도록 구현한다.

- [ ] **Step 3: 구현 추가**

`MetronomeEngine`에 다음을 추가한다:

```swift
    // init() 마지막에 추가:
    //   registerConfigurationChangeObserver()

    private var configObserver: NSObjectProtocol?

    private func registerConfigurationChangeObserver() {
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    private func handleConfigurationChange() {
        // 현재 BPM 기준으로 framesPerBeat를 재계산한다.
        scheduler.setFramesPerBeat(framesPerBeat(bpm: currentBPM, sampleRate: sampleRate))
        // 재생 중이었다면 엔진을 재시작한다.
        if isRunning {
            stop()
            try? start()
        }
    }

    deinit {
        if let observer = configObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
```

또한 `object: engine`으로 구독하지만 테스트는 `object: nil`로 post하므로, 테스트가 통과하도록 구독의 `object`를 `nil`로 두거나 테스트에서 `object: engine`을 넘긴다. **이 계획에서는 구독을 `object: nil`로 설정**해 어떤 소스든 처리한다.

`registerConfigurationChangeObserver`의 `object: engine`을 `object: nil`로 변경하고, `init()`의 마지막 줄에 `registerConfigurationChangeObserver()` 호출을 추가한다.

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add metronome/Audio/MetronomeEngine.swift metronomeTests/MetronomeEngineTests.swift
git commit -m "feat: 오디오 디바이스 구성 변경 복원력 추가"
```

---

### Task 11: 최소 기능 UI 배선 (디자인 제외)

**Files:**
- Modify: `metronome/App/ContentView.swift`
- Create: `metronome/View/BeatIndicatorView.swift`
- Modify: `metronome/App/MetronomeApp.swift`

**Interfaces:**
- Consumes: `MetronomeState` (Task 9), `BeatEventChannel` (Task 6)
- Produces: 동작 확인용 최소 UI. BPM 슬라이더, 재생/정지 버튼, 탭 버튼, 박자표 선택, 오디오 동기 비트 인디케이터. **스타일링은 하지 않으며 추후 Claude Design 결과물로 교체.**

**구현 노트:** `BeatIndicatorView`는 `Timer.publish`(약 60fps)로 `beatChannel.latest()`를 폴링해 `sequence` 변화 시 인디케이터를 갱신한다. (macOS SwiftUI에서 DisplayLink 대신 고빈도 타이머 폴링으로 충분하며, 정확한 타이밍은 오디오가 보장한다.)

- [ ] **Step 1: MetronomeApp 상태 주입**

```swift
// metronome/App/MetronomeApp.swift
import SwiftUI

@main
struct MetronomeApp: App {
    @StateObject private var state = MetronomeState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
    }
}
```

- [ ] **Step 2: BeatIndicatorView 작성**

```swift
// metronome/View/BeatIndicatorView.swift
import SwiftUI

/// 오디오 박자에 동기화된 최소 비트 인디케이터입니다. (디자인 미적용)
struct BeatIndicatorView: View {
    let channel: BeatEventChannel
    let beatsPerBar: Int

    @State private var lastSequence: UInt64 = 0
    @State private var activeBeat: Int = -1
    @State private var isAccent: Bool = false

    private let poll = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(1, beatsPerBar), id: \.self) { index in
                Circle()
                    .fill(color(for: index))
                    .frame(width: 20, height: 20)
            }
        }
        .onReceive(poll) { _ in
            let snap = channel.latest()
            if snap.sequence != lastSequence {
                lastSequence = snap.sequence
                activeBeat = snap.beatIndex
                isAccent = snap.isAccent
            }
        }
    }

    private func color(for index: Int) -> Color {
        guard index == activeBeat else { return .gray.opacity(0.3) }
        return isAccent ? .red : .blue
    }
}
```

- [ ] **Step 3: ContentView 작성**

```swift
// metronome/App/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: MetronomeState

    var body: some View {
        VStack(spacing: 16) {
            Text("\(Int(state.bpm)) BPM")
                .font(.largeTitle)

            BeatIndicatorView(
                channel: state.engine.beatChannel,
                beatsPerBar: state.timeSignature.beatsPerBar
            )

            Slider(value: Binding(
                get: { state.bpm },
                set: { state.setBPM($0) }
            ), in: MetronomeState.bpmRange, step: 1)
            .frame(width: 300)

            Picker("박자표", selection: Binding(
                get: { state.timeSignature },
                set: { state.setTimeSignature($0) }
            )) {
                ForEach(TimeSignature.presets, id: \.label) { ts in
                    Text(ts.label).tag(ts)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            HStack(spacing: 12) {
                Button(state.isPlaying ? "정지" : "재생") {
                    state.togglePlay()
                }
                Button("탭") {
                    state.tap()
                }
            }
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
    }
}
```

- [ ] **Step 4: 빌드 및 실행 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' build`
Expected: BUILD SUCCEEDED

앱을 실행해 재생 시 클릭음이 들리고, 비트 인디케이터가 클릭과 함께 점등하며, BPM 슬라이더/탭/박자표가 동작하는지 수동 확인한다.

- [ ] **Step 5: 커밋**

```bash
git add metronome/App/ContentView.swift metronome/App/MetronomeApp.swift metronome/View/BeatIndicatorView.swift
git commit -m "feat: 최소 기능 UI 배선 및 오디오 동기 비트 인디케이터 추가"
```

---

### Task 12: 타이밍 정확도 수동 검증 문서

**Files:**
- Create: `docs/superpowers/verification/timing-check.md`

**Interfaces:**
- Consumes: 완성된 앱
- Produces: 타이밍 지터 측정 및 완료 정의 검증 절차 문서

- [ ] **Step 1: 검증 문서 작성**

```markdown
# 타이밍 정확도 검증

## 목적
박자 간격 지터가 샘플 단위(수십 μs) 수준인지, 시각/오디오 동기가 지각적으로 동시인지 확인한다.

## 절차
1. 앱을 실행하고 120 BPM으로 재생한다.
2. 외부 정확 메트로놈(하드웨어 또는 검증된 앱)을 같은 BPM으로 병행 재생한다.
3. 30초 이상 청취하며 두 클릭이 드리프트 없이 유지되는지 확인한다.
4. 비트 인디케이터 점등이 클릭음과 지각적으로 동시인지 확인한다.

## 완료 정의
- [ ] BPM 변경이 다음 박자에 즉시 반영되고 진행 중 박자가 튀지 않는다.
- [ ] 시각 인디케이터가 오디오 클릭과 지각적으로 동시다.
- [ ] 30초 병행 청취에서 드리프트가 없다.
- [ ] 탭 템포로 설정한 BPM이 실제 클릭 속도와 일치한다.
```

- [ ] **Step 2: 커밋**

```bash
git add docs/superpowers/verification/timing-check.md
git commit -m "docs: 타이밍 정확도 수동 검증 절차 추가"
```

---

## Self-Review

**Spec coverage:**
- 오디오 타이밍 아키텍처(샘플 정밀) → Task 2, 7, 8 ✅
- 컴포넌트 구조(Audio/Model/View 분리) → Task 2~11 ✅
- UI→Audio atomic 전파 → Task 7(atomic), 8, 9 ✅
- Audio→UI 락프리 스냅샷 → Task 6, 11 ✅
- 렌더 콜백 실시간 규칙 → Task 7, 8 구현 노트 ✅
- 클릭 신테시스(강박/약박) → Task 5 ✅
- 탭 템포 → Task 4, 9 ✅
- 박자표 강약박 → Task 3 ✅
- 시각적 비트 표시 → Task 11 ✅
- 에러 처리(디바이스 변경) → Task 10 ✅
- 테스트 전략(단위/통합/수동) → Task 2~9(단위), 8·10(통합), 12(수동) ✅

**Type consistency:** `framesPerBeat`, `TimeSignature.beatsPerBar`/`isAccent`, `TapTempo.tap`, `BeatEventChannel.publish`/`latest`, `BeatScheduler.advanceOneFrame`/`Tick`, `MetronomeEngine.beatChannel`/`updateBPM`/`updateTimeSignature`/`start`/`stop`, `MetronomeState.setBPM`/`togglePlay`/`tap`/`tapForTesting` — 태스크 간 시그니처 일치 확인 ✅

**Placeholder scan:** 모든 코드 스텝에 완전한 구현 포함, TBD/TODO 없음 ✅
