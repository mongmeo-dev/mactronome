# 분할 박자별 현재 재생 펄스 강조 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 재생 중 현재 울리는 개별 펄스(분할) 바 하나를 액센트 색으로 강조하고, 기존 박 그룹 전체 강조는 제거한다.

**Architecture:** 오디오 스레드가 UI로 보내는 락프리 스냅샷에 `pulseIndex`를 추가(64비트 팩킹 재배분)해, `MetronomeScreen`이 활성 (박,펄스)를 추적하고 `AccentBarsView`가 해당 바 하나만 강조한다. 박자 번호 강조는 유지, 그룹 배경 링/확대는 제거.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, swift-atomics, XCTest. 빌드/테스트는 `xcodebuild`(project.yml → XcodeGen).

## Global Constraints

- 오디오 스레드(`render` / `publish`)는 락프리·무할당 유지 — 단일 atomic store/load만 사용.
- 사용자 인터랙션·사고 과정 출력은 한국어 경어체.
- 커밋은 기능 단위로 분리, Co-Author 삽입 금지.
- 빌드 검증 명령:
  `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`

---

## File Structure

- `metronome/Audio/BeatEvent.swift` — `BeatSnapshot`에 `pulseIndex` 추가, 64비트 팩킹 재배분(`[sequence:39|beatIndex:16|pulseIndex:8|accent:1]`), `publish`/`latest` 시그니처 확장.
- `metronome/Audio/MetronomeEngine.swift` — 발화 지점에서 `tick.pulseIndex` 전달.
- `metronome/View/MetronomeScreen.swift` — `activeBeat: Int?` → `activePulse: (beat:Int, pulse:Int)?` 로 확장, 폴러에서 pulseIndex도 읽음.
- `metronome/View/AccentBarsView.swift` — 그룹 배경/확대 제거, 펄스 바 하나 강조, 번호 강조 유지.
- `metronomeTests/BeatEventTests.swift` — pulseIndex 왕복/경계 테스트 추가·기존 테스트 시그니처 갱신.

---

### Task 1: BeatEventChannel에 pulseIndex 추가

**Files:**
- Modify: `metronome/Audio/BeatEvent.swift`
- Test: `metronomeTests/BeatEventTests.swift`

**Interfaces:**
- Consumes: (없음 — 기반 타입)
- Produces:
  - `struct BeatSnapshot { let sequence: UInt64; let beatIndex: Int; let pulseIndex: Int; let isAccent: Bool }`
  - `func publish(beatIndex: Int, pulseIndex: Int, isAccent: Bool)`
  - `func latest() -> BeatSnapshot`

- [ ] **Step 1: 기존 테스트를 새 시그니처로 갱신하고 pulseIndex 테스트 추가 (실패 유도)**

`metronomeTests/BeatEventTests.swift` 전체를 아래로 교체:

```swift
import XCTest
@testable import metronome

final class BeatEventTests: XCTestCase {
    func test_initialSnapshot_hasZeroSequence() {
        let channel = BeatEventChannel()
        XCTAssertEqual(channel.latest().sequence, 0)
    }

    func test_publish_incrementsSequence_andCarriesData() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 2, pulseIndex: 5, isAccent: false)
        let snap = channel.latest()
        XCTAssertEqual(snap.sequence, 1)
        XCTAssertEqual(snap.beatIndex, 2)
        XCTAssertEqual(snap.pulseIndex, 5)
        XCTAssertFalse(snap.isAccent)
    }

    func test_publish_accent_roundTrips() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 0, pulseIndex: 0, isAccent: true)
        let snap = channel.latest()
        XCTAssertEqual(snap.beatIndex, 0)
        XCTAssertEqual(snap.pulseIndex, 0)
        XCTAssertTrue(snap.isAccent)
    }

    func test_multiplePublishes_sequenceMonotonic() {
        let channel = BeatEventChannel()
        channel.publish(beatIndex: 0, pulseIndex: 0, isAccent: true)
        channel.publish(beatIndex: 1, pulseIndex: 2, isAccent: false)
        channel.publish(beatIndex: 2, pulseIndex: 7, isAccent: false)
        XCTAssertEqual(channel.latest().sequence, 3)
        XCTAssertEqual(channel.latest().beatIndex, 2)
        XCTAssertEqual(channel.latest().pulseIndex, 7)
    }

    func test_publish_maxBoundaryValues_roundTrip() {
        let channel = BeatEventChannel()
        // beatIndex 16비트 최대, pulseIndex 8비트 최대
        channel.publish(beatIndex: 0xFFFF, pulseIndex: 0xFF, isAccent: true)
        let snap = channel.latest()
        XCTAssertEqual(snap.beatIndex, 0xFFFF)
        XCTAssertEqual(snap.pulseIndex, 0xFF)
        XCTAssertTrue(snap.isAccent)
    }

    func test_fields_doNotBleed_acrossBitBoundaries() {
        let channel = BeatEventChannel()
        // beatIndex는 최대, pulseIndex는 0, accent false → 인접 필드 침범 없어야 함
        channel.publish(beatIndex: 0xFFFF, pulseIndex: 0, isAccent: false)
        let snap = channel.latest()
        XCTAssertEqual(snap.beatIndex, 0xFFFF)
        XCTAssertEqual(snap.pulseIndex, 0)
        XCTAssertFalse(snap.isAccent)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: 컴파일 실패 — `publish(beatIndex:pulseIndex:isAccent:)` 없음, `BeatSnapshot`에 `pulseIndex` 없음.

- [ ] **Step 3: BeatEvent.swift 구현**

`metronome/Audio/BeatEvent.swift` 전체를 아래로 교체:

```swift
import Foundation
import Atomics

/// UI에 전달되는 박자 스냅샷입니다.
struct BeatSnapshot: Equatable {
    let sequence: UInt64
    let beatIndex: Int
    let pulseIndex: Int
    let isAccent: Bool
}

/// 오디오 스레드 → UI 스레드로 박자 정보를 전달하는 락프리 채널입니다.
///
/// 하나의 UInt64에 [sequence:39 | beatIndex:16 | pulseIndex:8 | accent:1]를 팩킹해
/// 단일 atomic store/load로 torn read 없이 전달합니다.
final class BeatEventChannel {
    private let packed = ManagedAtomic<UInt64>(0)

    private static let accentBits: UInt64 = 1
    private static let pulseIndexShift: UInt64 = 1
    private static let pulseIndexMask: UInt64 = 0xFF   // 8비트
    private static let beatIndexShift: UInt64 = 9
    private static let beatIndexMask: UInt64 = 0xFFFF  // 16비트
    private static let sequenceShift: UInt64 = 25

    /// 오디오 스레드에서 호출됩니다. 락프리 store만 수행합니다.
    func publish(beatIndex: Int, pulseIndex: Int, isAccent: Bool) {
        let current = packed.load(ordering: .relaxed)
        let sequence = (current >> Self.sequenceShift) &+ 1
        let accent: UInt64 = isAccent ? 1 : 0
        let beat = UInt64(beatIndex) & Self.beatIndexMask
        let pulse = UInt64(pulseIndex) & Self.pulseIndexMask
        let newValue = (sequence << Self.sequenceShift)
            | (beat << Self.beatIndexShift)
            | (pulse << Self.pulseIndexShift)
            | accent
        packed.store(newValue, ordering: .relaxed)
    }

    /// UI 스레드에서 호출됩니다. 락프리 load만 수행합니다.
    func latest() -> BeatSnapshot {
        let value = packed.load(ordering: .relaxed)
        let sequence = value >> Self.sequenceShift
        let beatIndex = Int((value >> Self.beatIndexShift) & Self.beatIndexMask)
        let pulseIndex = Int((value >> Self.pulseIndexShift) & Self.pulseIndexMask)
        let isAccent = (value & Self.accentBits) == 1
        return BeatSnapshot(sequence: sequence, beatIndex: beatIndex, pulseIndex: pulseIndex, isAccent: isAccent)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: 컴파일 실패 — `MetronomeEngine.swift`가 아직 옛 `publish` 시그니처를 호출. (Task 2에서 해소.) BeatEventTests 자체 로직은 맞으므로, 이 단계에서 통과를 보려면 Task 2를 함께 진행. 순서상 다음 Task로 진행.

- [ ] **Step 5: 커밋 (Task 2와 함께 컴파일되므로 Task 2 완료 후 커밋)**

이 Task는 단독 컴파일이 안 되므로 Task 2 완료 후 함께 커밋합니다. Step은 Task 2의 커밋으로 이어집니다.

---

### Task 2: MetronomeEngine에서 pulseIndex 전달

**Files:**
- Modify: `metronome/Audio/MetronomeEngine.swift:120`

**Interfaces:**
- Consumes: `publish(beatIndex:pulseIndex:isAccent:)` (Task 1), `PulseScheduler.Tick.pulseIndex`
- Produces: (없음 — 엔진 내부 배선)

- [ ] **Step 1: 발화 지점 publish 호출 갱신**

`metronome/Audio/MetronomeEngine.swift`의 `render` 내부 발화 지점(현재 120행)을 교체:

찾을 코드:
```swift
                beatChannel.publish(beatIndex: tick.beatIndex, isAccent: tick.level == 3)
```

교체:
```swift
                beatChannel.publish(beatIndex: tick.beatIndex, pulseIndex: tick.pulseIndex, isAccent: tick.level == 3)
```

- [ ] **Step 2: 테스트 통과 확인 (Task 1 + 2 합산)**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: 전체 컴파일 성공, BeatEventTests 6개 PASS 포함 기존 테스트 전부 PASS.

- [ ] **Step 3: 커밋**

```bash
git add metronome/Audio/BeatEvent.swift metronome/Audio/MetronomeEngine.swift metronomeTests/BeatEventTests.swift
git commit -m "feat: 박자 스냅샷에 pulseIndex 추가 및 엔진 배선"
```

---

### Task 3: AccentBarsView — 펄스 바 단위 강조

**Files:**
- Modify: `metronome/View/AccentBarsView.swift`

**Interfaces:**
- Consumes: (없음 — 뷰 파라미터로 활성 펄스 수신)
- Produces:
  - `AccentBarsView` 의 초기화 파라미터 `activePulse: (beat: Int, pulse: Int)?`
    (기존 `activeBeat: Int?` 대체)

- [ ] **Step 1: activeBeat → activePulse 교체 및 강조 로직 변경**

`metronome/View/AccentBarsView.swift`에서 다음을 변경합니다.

(a) 프로퍼티 교체 — 찾을 코드:
```swift
    /// 현재 울리고 있는 박자 인덱스. 재생 중이 아니면 nil.
    var activeBeat: Int? = nil
```
교체:
```swift
    /// 현재 울리고 있는 (박, 펄스) 인덱스. 재생 중이 아니면 nil.
    var activePulse: (beat: Int, pulse: Int)? = nil
```

(b) `beatGroup` 전체를 교체 — 찾을 코드:
```swift
    private func beatGroup(beatIndex: Int, row: [AccentLevel]) -> some View {
        let isActive = activeBeat == beatIndex

        return VStack(spacing: 9) {
            // 바 컨테이너: 아래 정렬, 고정 높이 64
            HStack(alignment: .bottom, spacing: Self.barSpacing) {
                ForEach(Array(row.enumerated()), id: \.offset) { pulseIndex, level in
                    bar(level: level, isMain: pulseIndex == 0) {
                        onCycle(beatIndex, pulseIndex)
                    }
                }
            }
            .frame(height: 64, alignment: .bottom)

            Text("\(beatIndex + 1)")
                .font(.monoTabular(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? Theme.Colors.acc : Theme.Colors.mut)
        }
        // 활성 비트: 슬레이트 틴트 배경 + 미세한 확대로 담백하게 강조합니다.
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)
                .fill(isActive ? Theme.Colors.accSoft : .clear)
        }
        .scaleEffect(isActive ? 1.06 : 1.0, anchor: .bottom)
        .animation(Theme.Motion.chip, value: isActive)
    }
```
교체:
```swift
    private func beatGroup(beatIndex: Int, row: [AccentLevel]) -> some View {
        // 박자 번호 강조는 현재 울리는 박 기준으로 유지합니다.
        let isActiveBeat = activePulse?.beat == beatIndex

        return VStack(spacing: 9) {
            // 바 컨테이너: 아래 정렬, 고정 높이 64
            HStack(alignment: .bottom, spacing: Self.barSpacing) {
                ForEach(Array(row.enumerated()), id: \.offset) { pulseIndex, level in
                    // 활성 펄스: 현재 울리는 (박, 펄스)와 정확히 일치하는 바 하나.
                    let isActive = activePulse?.beat == beatIndex
                        && activePulse?.pulse == pulseIndex
                    bar(level: level, isMain: pulseIndex == 0, isActive: isActive) {
                        onCycle(beatIndex, pulseIndex)
                    }
                }
            }
            .frame(height: 64, alignment: .bottom)

            Text("\(beatIndex + 1)")
                .font(.monoTabular(size: 11, weight: .semibold))
                .foregroundStyle(isActiveBeat ? Theme.Colors.acc : Theme.Colors.mut)
        }
        // 그룹 좌우 여백만 유지(폭 계산 groupHorizontalPadding=12과 일치). 배경/확대 없음.
        .padding(.horizontal, 6)
    }
```

(c) `bar(...)` 시그니처에 `isActive` 추가 및 활성 스타일 적용 — 찾을 코드:
```swift
    @ViewBuilder
    private func bar(level: AccentLevel, isMain: Bool, onTap: @escaping () -> Void) -> some View {
        let width: CGFloat = isMain ? Self.mainBarWidth : Self.subBarWidth
        let height = isMain ? level.mainHeight : level.subHeight
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)

        shape
            .fill(level.fill)
            .overlay {
                shape.strokeBorder(
                    level.borderColor,
                    style: StrokeStyle(
                        lineWidth: AccentLevel.borderWidth,
                        dash: level.isDashed ? [3, 2.5] : []
                    )
                )
            }
            .frame(width: width, height: height)
            .contentShape(shape)
            .onTapGesture(perform: onTap)
            .animation(Theme.Motion.bar, value: level)
    }
```
교체:
```swift
    @ViewBuilder
    private func bar(level: AccentLevel, isMain: Bool, isActive: Bool, onTap: @escaping () -> Void) -> some View {
        let width: CGFloat = isMain ? Self.mainBarWidth : Self.subBarWidth
        let height = isMain ? level.mainHeight : level.subHeight
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.bar, style: .continuous)
        // 활성 바: 액센트 색으로 채우고 부드러운 글로우를 더해 밝게 강조합니다.
        let fill = isActive ? Theme.Colors.acc : level.fill
        let border = isActive ? Theme.Colors.acc : level.borderColor

        shape
            .fill(fill)
            .overlay {
                shape.strokeBorder(
                    border,
                    style: StrokeStyle(
                        lineWidth: AccentLevel.borderWidth,
                        dash: level.isDashed ? [3, 2.5] : []
                    )
                )
            }
            .frame(width: width, height: height)
            .shadow(color: isActive ? Theme.Colors.accSoft : .clear, radius: isActive ? 6 : 0)
            .contentShape(shape)
            .onTapGesture(perform: onTap)
            .animation(Theme.Motion.bar, value: level)
            .animation(Theme.Motion.chip, value: isActive)
    }
```

- [ ] **Step 2: 컴파일 실패 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: 컴파일 실패 — `MetronomeScreen.swift`가 아직 `activeBeat:` 로 `AccentBarsView`를 생성. (Task 4에서 해소.)

- [ ] **Step 3: 커밋 (Task 4와 함께 컴파일되므로 Task 4 완료 후)**

이 Task 단독으로는 컴파일이 안 되므로 Task 4 완료 후 함께 커밋합니다.

---

### Task 4: MetronomeScreen — 활성 펄스 폴링/배선

**Files:**
- Modify: `metronome/View/MetronomeScreen.swift`

**Interfaces:**
- Consumes: `AccentBarsView(grid:activePulse:onCycle:)` (Task 3), `BeatSnapshot.pulseIndex` (Task 1)
- Produces: (없음 — 최상위 화면 배선)

- [ ] **Step 1: activeBeat 상태를 activePulse로 교체**

`metronome/View/MetronomeScreen.swift`에서 다음을 변경합니다.

(a) 상태 프로퍼티 — 찾을 코드:
```swift
    /// 재생 중 현재 울리는 박자 인덱스입니다. 정지 상태에서는 nil.
    @State private var activeBeat: Int?
```
교체:
```swift
    /// 재생 중 현재 울리는 (박, 펄스) 인덱스입니다. 정지 상태에서는 nil.
    @State private var activePulse: (beat: Int, pulse: Int)?
```

(b) 정지 시 해제 — 찾을 코드:
```swift
        .onChange(of: state.isPlaying) { _, playing in
            // 정지 시 활성 강조를 즉시 해제합니다.
            if !playing { activeBeat = nil }
        }
```
교체:
```swift
        .onChange(of: state.isPlaying) { _, playing in
            // 정지 시 활성 강조를 즉시 해제합니다.
            if !playing { activePulse = nil }
        }
```

(c) 폴러에서 pulseIndex도 읽기 — 찾을 코드:
```swift
                    .onChange(of: pollSequence()) { _, _ in
                        let snapshot = state.engine.beatChannel.latest()
                        lastSequence = snapshot.sequence
                        activeBeat = snapshot.beatIndex
                    }
```
교체:
```swift
                    .onChange(of: pollSequence()) { _, _ in
                        let snapshot = state.engine.beatChannel.latest()
                        lastSequence = snapshot.sequence
                        activePulse = (beat: snapshot.beatIndex, pulse: snapshot.pulseIndex)
                    }
```

(d) AccentBarsView 생성부 — 찾을 코드:
```swift
            AccentBarsView(
                grid: state.grid,
                activeBeat: activeBeat,
                onCycle: { beat, pulse in state.cycleCell(beat: beat, pulse: pulse) }
            )
```
교체:
```swift
            AccentBarsView(
                grid: state.grid,
                activePulse: activePulse,
                onCycle: { beat, pulse in state.cycleCell(beat: beat, pulse: pulse) }
            )
```

- [ ] **Step 2: 전체 빌드·테스트 통과 확인**

Run: `xcodebuild -project metronome.xcodeproj -scheme metronome -destination 'platform=macOS' test`
Expected: 컴파일 성공, 전체 테스트 PASS.

- [ ] **Step 3: 커밋**

```bash
git add metronome/View/AccentBarsView.swift metronome/View/MetronomeScreen.swift
git commit -m "feat: 분할 박자별 현재 재생 펄스 바 강조"
```

---

## Self-Review

**1. Spec coverage:**
- 스냅샷에 pulseIndex 추가(64비트 재배분) → Task 1 ✓
- 엔진 pulseIndex 전달 → Task 2 ✓
- activeBeat → activePulse 확장, 폴러 배선 → Task 4 ✓
- 그룹 배경 링/확대 제거, 펄스 바 하나 강조, 번호 강조 유지 → Task 3 ✓
- BeatEventTests pulseIndex/경계 검증 → Task 1 ✓
- AccentBarsLayoutTests 불변 → 폭 계산 로직·groupHorizontalPadding(=12) 유지 확인 ✓

**2. Placeholder scan:** 모든 스텝에 실제 코드/명령 포함, 플레이스홀더 없음.

**3. Type consistency:**
- `publish(beatIndex:pulseIndex:isAccent:)` — Task 1 정의, Task 2 호출 일치 ✓
- `BeatSnapshot.pulseIndex: Int` — Task 1 정의, Task 4 사용 일치 ✓
- `AccentBarsView.activePulse: (beat:Int, pulse:Int)?` — Task 3 정의, Task 4 사용 일치 ✓
- `bar(level:isMain:isActive:onTap:)` — Task 3 내부 정의·호출 일치 ✓

**주의(레이아웃 불변성):** Task 3에서 `beatGroup`의 `.padding(.horizontal, 6)`(좌우 합 12)은 유지하고 `.padding(.vertical, 4)`·배경·`scaleEffect`만 제거한다. 폭 계산 상수 `groupHorizontalPadding = 12`와 일치하므로 `overflowsSingleRow` 로직 및 `AccentBarsLayoutTests`에 영향 없음.
