import Foundation
import AVFoundation
import Atomics

/// AVAudioEngine 기반 메트로놈 엔진입니다. 펄스 스케줄러와 4단계 강세 버퍼를 통합합니다.
///
/// 저지연 전략: 앱 시작 시 엔진과 source node를 한 번만 구동하여 상시 가동합니다.
/// 재생/정지는 오디오 하드웨어를 콜드 스타트하지 않고 발화 게이트(`gateOpen`)만
/// 토글하므로, 재생 버튼을 누른 뒤 다음 렌더 버퍼(수 ms) 안에 첫 클릭이 납니다.
final class MetronomeEngine {
    let beatChannel = BeatEventChannel()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let scheduler: PulseScheduler
    private let sampleRate: Double

    private let levelChannel: LevelBuffersChannel   // 인덱스=강세 레벨, 락프리 교체 가능
    private var playbackIndex = -1
    private var playingLevel = 0

    /// 폴리리듬 보조 보이스와 그 클릭 버퍼(고정 음색), 재생 인덱스입니다.
    private let polyVoice = PolyVoice()
    private let polyBuffer: [Float]
    private var polyPlaybackIndex = -1
    /// 주 보이스의 마디당 박 수(폴리 마디 길이 계산에 사용).
    private var primaryBeatCount = 4

    /// 발화 게이트. 오디오 스레드와 메인 스레드가 공유하므로 원자적으로 다룹니다.
    /// true일 때만 스케줄러가 전진하며 클릭을 발화합니다.
    private let gateOpen = ManagedAtomic<Bool>(false)

    /// 게이트가 닫힌 동안에도 출력하는 극미세 킵얼라이브 신호의 진폭입니다.
    /// 약 -140 dBFS로 정상 볼륨에서 들리지 않으며, 대부분의 출력에서 양자화되면
    /// 0에 수렴합니다. 완전 무음(0)이 이어지면 일부 macOS 출력 장치가 아날로그
    /// 단(DAC/앰프)을 절전시켰다가 첫 클릭에서 깨어나며 지연을 유발하는데,
    /// 이 신호로 하드웨어를 항상 "따뜻하게" 유지해 첫 클릭 지연을 제거합니다.
    private static let keepAliveAmplitude: Float = 1e-7
    private var keepAlivePhase: Float = 1

    /// 재생(발화) 중인지 여부입니다. 엔진 자체의 구동 상태와 분리되어 있습니다.
    var isRunning: Bool { gateOpen.load(ordering: .relaxed) }

    private var currentBPM: Double = 120
    private var currentNoteValue: Int = 4
    private var configObserver: NSObjectProtocol?

    init() {
        let format = engine.outputNode.outputFormat(forBus: 0)
        self.sampleRate = format.sampleRate > 0 ? format.sampleRate : 44100
        self.scheduler = PulseScheduler(sampleRate: sampleRate)
        self.levelChannel = LevelBuffersChannel(ClickSynth.makeLevelBuffers(sampleRate: sampleRate))
        // 폴리 보이스는 주 보이스와 구분되도록 clave 강박 음색을 고정 사용합니다.
        self.polyBuffer = ClickSynth.makeLevelBuffers(sampleRate: sampleRate, sound: .clave)[AccentLevel.strong.rawValue]
        recomputeFramesPerBeat()
        registerConfigObserver()
    }

    func updateBPM(_ bpm: Double) {
        currentBPM = bpm
        recomputeFramesPerBeat()
    }

    /// 박(beat)에 해당하는 음표 분모를 갱신합니다(2/4/8/16). 다음 박 경계부터 반영됩니다.
    func updateNoteValue(_ noteValue: Int) {
        currentNoteValue = max(1, noteValue)
        recomputeFramesPerBeat()
    }

    /// 마스터 출력 볼륨을 설정합니다(0...1). 메인 믹서에 적용되어 실시간 안전합니다.
    func setVolume(_ volume: Float) {
        engine.mainMixerNode.outputVolume = min(max(volume, 0), 1)
    }
    /// 클릭 음색을 교체합니다. 새 레벨 버퍼를 만들어 락프리로 게시하므로 재생 중에도 안전합니다.
    func updateSound(_ sound: ClickSound) {
        levelChannel.publish(ClickSynth.makeLevelBuffers(sampleRate: sampleRate, sound: sound))
    }

    /// 폴리리듬 마디당 펄스 수를 설정합니다(0/1=끔, 2이상=켬).
    func updatePolyrhythm(_ pulses: Int) {
        polyVoice.setPulseCount(pulses)
    }

    private func recomputeFramesPerBeat() {
        scheduler.setFramesPerBeat(framesPerBeat(bpm: currentBPM, sampleRate: sampleRate, noteValue: currentNoteValue))
        recomputePolyBar()
    }

    /// 폴리 보이스 마디 길이 = 주 보이스 박 수 × 박당 프레임.
    private func recomputePolyBar() {
        let fpBeat = framesPerBeat(bpm: currentBPM, sampleRate: sampleRate, noteValue: currentNoteValue)
        polyVoice.setFramesPerBar(max(1, primaryBeatCount) * fpBeat)
    }

    func updateGrid(_ grid: [[Int]], pulsesPerBeat: Int) {
        scheduler.grid.publish(PulsePlan(grid: grid, pulsesPerBeat: pulsesPerBeat))
        primaryBeatCount = max(1, grid.count)
        recomputePolyBar()
    }

    /// 앱 시작 시 엔진을 미리 구동해 첫 재생의 콜드 스타트 지연을 제거합니다.
    /// 실패해도 첫 `start()`에서 다시 시도하므로 조용히 무시합니다.
    func prewarm() {
        try? ensureEngineRunning()
    }

    /// 재생을 시작합니다. 엔진이 아직 구동되지 않았다면 여기서 한 번만 콜드 스타트하고,
    /// 이후에는 게이트만 열어 다음 렌더 버퍼 안에 즉시 발화합니다.
    func start() throws {
        guard !isRunning else { return }
        try ensureEngineRunning()
        scheduler.reset()
        polyVoice.reset()
        playbackIndex = -1
        polyPlaybackIndex = -1
        // `.releasing`으로 저장하여 위의 reset()·playbackIndex 쓰기가 게이트 오픈보다
        // 먼저 오디오 스레드에 가시화되도록 합니다(render의 `.acquiring` 로드와 짝).
        // 정지→재생 반복 시 첫 발화가 이전 재생의 잔여 상태로 밀리는 것을 방지합니다.
        gateOpen.store(true, ordering: .releasing)
    }

    /// 재생을 정지합니다. 엔진은 계속 상시 가동하며 발화 게이트만 닫습니다.
    func stop() {
        guard isRunning else { return }
        gateOpen.store(false, ordering: .relaxed)
    }

    /// 엔진과 source node를 한 번만 구성·구동합니다(이미 실행 중이면 no-op).
    private func ensureEngineRunning() throws {
        if engine.isRunning { return }
        if sourceNode == nil {
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            let node = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
                guard let self = self else { return noErr }
                return self.render(frameCount: frameCount, abl: abl)
            }
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            sourceNode = node
        }
        try engine.start()
    }

    private func render(frameCount: AVAudioFrameCount, abl: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(abl)
        guard let out = ablPointer.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }

        // 게이트가 닫혀 있으면 스케줄러를 전진시키지 않고 극미세 킵얼라이브 신호만
        // 출력합니다(들리지 않음). 하드웨어 아날로그 단을 계속 깨어있게 유지해
        // 첫 클릭 지연을 막습니다. `.acquiring`으로 로드하여, 게이트를 연 스레드의
        // reset() 쓰기가 첫 발화 전에 반드시 가시화되도록 보장합니다.
        if !gateOpen.load(ordering: .acquiring) {
            for frame in 0..<Int(frameCount) {
                keepAlivePhase = -keepAlivePhase
                out[frame] = Self.keepAliveAmplitude * keepAlivePhase
            }
            return noErr
        }

        let buffers = levelChannel.current()   // 렌더 콜백당 1회만 로드(락프리)
        for frame in 0..<Int(frameCount) {
            let tick = scheduler.advanceOneFrame()
            if tick.didFire {
                playbackIndex = 0
                playingLevel = tick.level
                beatChannel.publish(beatIndex: tick.beatIndex, pulseIndex: tick.pulseIndex, isAccent: tick.level == 3)
            }
            var sample: Float = 0
            if playbackIndex >= 0, playingLevel >= 0, playingLevel < buffers.count {
                let buf = buffers[playingLevel]
                if playbackIndex < buf.count {
                    sample = buf[playbackIndex]
                    playbackIndex += 1
                } else {
                    playbackIndex = -1
                }
            }
            // 폴리리듬 보조 보이스 믹싱.
            if polyVoice.advanceOneFrame() {
                polyPlaybackIndex = 0
            }
            if polyPlaybackIndex >= 0 {
                if polyPlaybackIndex < polyBuffer.count {
                    sample += polyBuffer[polyPlaybackIndex] * 0.7
                    polyPlaybackIndex += 1
                } else {
                    polyPlaybackIndex = -1
                }
            }
            // 두 보이스 합산이 풀스케일을 넘지 않도록 클램프.
            out[frame] = min(max(sample, -1), 1)
        }
        return noErr
    }

    private func registerConfigObserver() {
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // noteValue·폴리 마디 길이까지 일관되게 다시 계산합니다.
            self.recomputeFramesPerBeat()
            // 구성 변경으로 엔진이 멈췄을 수 있으므로, 재생 중이었다면 엔진만 다시 구동합니다.
            // 게이트는 그대로 유지되어 발화가 끊기지 않습니다.
            if self.isRunning { try? self.ensureEngineRunning() }
        }
    }

    /// 여기서 `engine.stop()` 을 호출하면 안 됩니다.
    ///
    /// `prewarm()` 이 AVAudioEngine 을 상시 가동 상태로 만들기 때문에 정리하고
    /// 싶어지지만, 렌더 콜백이 도는 도중 `deinit` 에서 정지를 기다리면 교착합니다.
    /// 프로세스 종료 시 하드웨어는 어차피 반환되므로 관찰자만 해제합니다.

    deinit {
        if let o = configObserver { NotificationCenter.default.removeObserver(o) }
    }
}
