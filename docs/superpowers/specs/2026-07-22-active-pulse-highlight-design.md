# 분할 박자별 현재 재생 펄스 강조 — 설계

작성일: 2026-07-22

## 목표

재생 중 **현재 울리는 개별 펄스(분할) 바 하나**를 시각적으로 강조한다.
기존의 박(beat) 그룹 배경 링 + 1.06배 확대 강조는 제거하고, 강조 대상을 펄스 바
하나로 좁힌다. 현재 박의 **박자 번호 색상 강조는 유지**한다.

## 배경 (현재 동작)

- 오디오 스레드(`MetronomeEngine.render`)는 펄스 발화 시점에
  `beatChannel.publish(beatIndex:isAccent:)` 로 **박 인덱스**만 UI에 전달한다.
- `PulseScheduler.advanceOneFrame()` 이 반환하는 `Tick` 에는 이미 `pulseIndex`가
  들어 있으나, 현재 UI로는 전달되지 않는다.
- `MetronomeScreen` 은 `activeBeat: Int?` 를 폴링해 추적하고,
  `AccentBarsView` 는 해당 박 그룹 전체를 슬레이트 틴트 배경 + 1.06배 확대로 강조한다.

## 변경 사항

### 1. 데이터 전달: 펄스 인덱스 추가

`BeatEventChannel` 은 하나의 `UInt64` 에 박자 스냅샷을 팩킹해 단일 atomic
store/load 로 torn read 없이 전달한다. 현재 레이아웃:

```
[sequence:47 | beatIndex:16 | accent:1]
```

여기에 `pulseIndex`(마디 내 펄스 인덱스)를 추가한다. 마디 전체 펄스 수는
최대 12박 × 6분할 = 72 이므로 8비트(0..255)면 충분하다. 새 레이아웃:

```
[sequence:39 | beatIndex:16 | pulseIndex:8 | accent:1]
```

- sequence 39비트 → 약 5,490억 틱까지 안전(단조 증가 카운터, 실사용에 무한).
- 단일 store/load 유지 → torn read 없음.
- `BeatSnapshot` 에 `pulseIndex: Int` 필드 추가.
- `publish(beatIndex:pulseIndex:isAccent:)` 시그니처로 변경.
- `latest()` 는 `pulseIndex` 를 언팩해 반환.

### 2. 엔진: 펄스 인덱스 전달

`MetronomeEngine.render` 의 발화 지점에서
`beatChannel.publish(beatIndex: tick.beatIndex, pulseIndex: tick.pulseIndex, isAccent: tick.level == 3)`
로 `tick.pulseIndex` 를 함께 전달한다.

### 3. 화면: 활성 펄스 추적

`MetronomeScreen` 의 `activeBeat: Int?` 를 `activePulse: (beat: Int, pulse: Int)?`
로 확장한다(정지 시 nil). 폴러에서 스냅샷의 `beatIndex` / `pulseIndex` 를 함께 읽어
갱신한다. `isPlaying` 이 false 가 되면 `activePulse = nil`.

### 4. 뷰: 펄스 바 강조 (`AccentBarsView`)

- 파라미터 `activeBeat: Int?` → `activePulse: (beat: Int, pulse: Int)?` 로 교체.
- `beatGroup`:
  - **그룹 배경 링 제거**(`.background { RoundedRectangle ... accSoft }` 삭제).
  - **1.06배 확대 제거**(`.scaleEffect` 삭제).
  - 박자 번호 색상 강조는 **유지** — 기준을 `activePulse?.beat == beatIndex` 로.
- `bar(...)` 에 `isActive: Bool` 파라미터 추가
  (`activePulse?.beat == beatIndex && activePulse?.pulse == pulseIndex`).
  - 활성 바: 채움색을 `Theme.Colors.acc`(액센트 슬레이트 블루)로 오버라이드,
    테두리도 액센트 톤, 부드러운 글로우 `.shadow(color: accSoft, radius: 6)`.
  - 비활성 바: 기존 `level.fill` / `level.borderColor` 그대로.
  - 높이(`mainHeight`/`subHeight`)는 불변 → 레이아웃 흔들림 없음, 색만 전환.
  - 전환 애니메이션은 짧게(`Theme.Motion.chip`).

## 테스트

- `BeatEventTests` — `pulseIndex` 포함 pack/unpack 왕복 검증, 경계값
  (pulseIndex 0 / 최대, beatIndex 최대, accent on/off) 정확성.
- 기존 `AccentBarsLayoutTests` 의 순수 폭 계산 로직은 불변 → 영향 없음.

## 비목표 (YAGNI)

- 펄스 강조의 페이드/트레일(잔상) 효과는 넣지 않는다(현재 요구는 "현재 바 하나").
- 사운드/색상 테마 변경 없음.
