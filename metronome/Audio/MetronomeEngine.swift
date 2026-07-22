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

    private var levelBuffers: [[Float]] = []   // 인덱스=강세 레벨
    private var playbackIndex = -1
    private var playingLevel = 0

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
        playbackIndex = -1
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
            // 구성 변경으로 엔진이 멈췄을 수 있으므로, 재생 중이었다면 엔진만 다시 구동합니다.
            // 게이트는 그대로 유지되어 발화가 끊기지 않습니다.
            if self.isRunning { try? self.ensureEngineRunning() }
        }
    }

    deinit {
        if let o = configObserver { NotificationCenter.default.removeObserver(o) }
    }
}
