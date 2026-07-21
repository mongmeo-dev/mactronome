# 메트로놈 앱 기술 설계 (Tech Spec)

- 작성일: 2026-07-21
- 대상 플랫폼: macOS 14+
- 언어/프레임워크: Swift + SwiftUI
- 빌드: Xcode 프로젝트 (.xcodeproj)

## 1. 목적 및 요구사항

macOS 네이티브 메트로놈 앱을 구현한다. 핵심 요구사항은 **최소 지연(latency)** 으로,
사운드 재생과 화면 인터랙션이 사용자가 설정한 BPM에 매우 근접해야 한다.

### MVP 기능 범위
- BPM 조절 + 재생/정지
- 박자표(Time Signature) 강약박 (첫 박 강조)
- 시각적 비트 표시 (오디오에 동기화)
- 탭 템포 (Tap Tempo)

## 2. 핵심 아키텍처 원리

**오디오 렌더 콜백이 타이밍의 단일 진실 공급원(single source of truth)이다.**

`AVAudioEngine` + `AVAudioSourceNode`의 실시간 렌더 콜백 안에서 **샘플 카운트로
다음 박자 시점을 계산**한다. `Timer`/`DispatchQueue`는 수 ms의 지터가 발생하므로
사용하지 않는다. 샘플 기반 계산은 지터가 없어 저지연 요구를 만족한다.

```
박자 간격(샘플) = 샘플레이트 × 60 / BPM
예) 44100 × 60 / 120 = 22050 샘플마다 한 박자
```

화면 인터랙션도 이 오디오 타임스탬프에 동기화되어 "BPM에 매우 근접"한 요구를 만족한다.

## 3. 컴포넌트 구조

```
metronome/
├── App/
│   └── MetronomeApp.swift          # @main, 앱 진입점, 윈도우 구성
├── Audio/
│   ├── MetronomeEngine.swift       # AVAudioEngine 수명주기, 시작/정지
│   ├── BeatScheduler.swift         # 렌더 콜백 내 샘플 카운팅 (실시간 안전)
│   ├── ClickSynth.swift            # 클릭 파형 생성 (강박/약박)
│   └── BeatEvent.swift             # 락프리 박자 이벤트 (Audio→UI 전달)
├── Model/
│   ├── MetronomeState.swift        # BPM, 박자, 재생상태 (ObservableObject)
│   ├── TimeSignature.swift         # 박자표 값 타입 (4/4, 3/4 등)
│   └── TapTempo.swift              # 탭 간격 → BPM 계산 (순수 로직)
└── View/
    ├── ContentView.swift           # 전체 레이아웃 조립
    ├── BPMControlView.swift        # BPM 슬라이더/스텝퍼/입력
    ├── TransportView.swift         # 재생·정지, 탭 템포 버튼
    ├── TimeSignatureView.swift     # 박자표 선택 UI
    └── BeatIndicatorView.swift     # 시각적 비트 표시 (강박 강조)
```

### 레이어별 책임

**Audio 레이어 (실시간 도메인)**
- `MetronomeEngine`: `AVAudioEngine`·`AVAudioSourceNode` 설치, 시작/정지,
  샘플레이트 확보. UI가 접근하는 유일한 진입점.
- `BeatScheduler`: 콜백당 `framesUntilNextBeat`를 감소시키며 박자 시점 판정.
  타이밍의 심장. 순수 정수/부동소수 연산만 — 할당·락 없음.
- `ClickSynth`: 강박용/약박용 클릭 버퍼를 시작 전 미리 생성. 콜백은 재생 위치만 진행.
- `BeatEvent`: 오디오 스레드 → UI 스레드로 "몇 번째 박자가 언제 울렸는가"를
  넘기는 락프리 통로 (단일 atomic 스냅샷).

**Model 레이어 (상태·순수 로직)**
- `MetronomeState`: SwiftUI가 관찰하는 상태 소유자. BPM·박자표·재생여부 보유,
  변경 시 Audio 레이어에 atomic으로 전파.
- `TimeSignature`, `TapTempo`: 오디오·UI와 무관한 순수 값 타입/로직 → 단위 테스트 용이.

**View 레이어 (표현)**
- 각 뷰는 하나의 컨트롤만 담당. `BeatIndicatorView`는 `BeatEvent`를 구독해
  화면을 오디오 타임스탬프에 맞춰 갱신.

**의존 방향:** View → Model → Audio (단방향). Audio→UI 피드백만 락프리 이벤트 채널로 역류.

## 4. Audio ↔ UI 동기화

### ① UI → Audio (파라미터 변경)
- BPM·박자당 프레임 수 등을 atomic(swift-atomics `ManagedAtomic` 또는 원시 atomic)에 store.
- 렌더 콜백은 매 렌더 시작 시 최신 값을 load하되, **다음 박자 경계에서만 반영**해
  진행 중인 박자가 튀지 않게 한다.

### ② Audio → UI (박자 발생 알림)
- 콜백은 **단일 atomic 스냅샷**에 `(beatIndex, isAccent, hostTime)`을 store만 함
  (할당·시그널 없음).
- UI 측은 DisplayLink(macOS `CVDisplayLink`/`CADisplayLink`)로 매 프레임 스냅샷을
  폴링해 값이 바뀌면 인디케이터를 갱신 → 화면과 오디오가 자연 동기화.
- 콜백에서 UI로 직접 노티피케이션을 쏘는 것은 실시간 위반이므로 금지.

### ③ 렌더 콜백 실시간 규칙 (엄수)
- 금지: 힙 할당, 락 획득, Swift ARC 유발 호출, 로깅/print
- 허용: 미리 할당된 버퍼 읽기, atomic load/store, 정수·부동소수 산술
- 클릭 버퍼는 시작 전 미리 생성, 콜백은 인덱스만 진행.

### ④ 탭 템포 로직
- 최근 탭 타임스탬프(`mach_absolute_time` 기반) N개를 슬라이딩 윈도우로 보관 →
  간격 평균으로 BPM 산출.
- 일정 시간(예: 2초) 이상 공백이면 윈도우 리셋. `TapTempo` 순수 함수라 테스트 용이.

## 5. 에러 처리

- **엔진 시작 실패**(오디오 디바이스 없음 등): UI에 에러 상태 표시, 재생 버튼 비활성화.
- **디바이스/샘플레이트 변경**(이어폰 연결 등): `AVAudioEngineConfigurationChange`
  노티피케이션 구독 → 엔진 재구성 후 박자당 프레임 수 재계산.
- **인터럽션**: 재생 중 라우트가 끊기면 상태를 정지로 되돌리고 UI 반영.

## 6. 테스트 전략

### 단위 테스트 (자동화 — XCTest)
- `TapTempo`: 탭 간격 시퀀스 → 기대 BPM, 공백 리셋, 이상치 처리.
- `TimeSignature`: 박자표별 강박/약박 패턴 생성 검증.
- `framesPerBeat(bpm:sampleRate:)` 순수 함수: 여러 조합에서 기대값 검증
  (예: 120 BPM @ 44.1kHz = 22050).
- `BeatScheduler` 카운팅 로직: 오디오 없이 프레임 수 시뮬레이션으로 박자 발생 프레임 검증.

### 통합 검증 (반자동)
- `MetronomeEngine` 시작/정지 상태 전이 확인.
- 디바이스 변경 노티피케이션 처리 후 프레임 수 재계산 검증.

### 타이밍 정확도 측정 (수동/도구)
- 박자 호스트타임 로그 수집 → 박자 간격 표준편차(지터) 측정. 목표: 1ms 미만.
- 기준 메트로놈과 병행 청취해 드리프트 확인.

### 완료 정의
- BPM 변경이 다음 박자에 즉시 반영되고 진행 중 박자가 튀지 않음.
- 시각 인디케이터가 오디오 클릭과 지각적으로 동시(디스플레이 리프레시 오차 이내).
- 박자 간격 지터가 샘플 단위(수십 μs) 수준.

## 7. 기술 결정 요약

| 결정 | 선택 |
|------|------|
| 기술 스택 | Swift + SwiftUI, macOS 14+, Xcode 프로젝트 |
| 오디오 엔진 | AVAudioEngine + AVAudioSourceNode |
| 타이밍 | 렌더 콜백 내 샘플 정밀 카운팅 |
| 사운드 | 코드로 클릭 신테시스 (강박/약박) |
| Audio→UI | 락프리 atomic 스냅샷 + DisplayLink 폴링 |
| MVP 기능 | BPM 조절/재생·정지, 박자표 강약박, 시각 비트 표시, 탭 템포 |
