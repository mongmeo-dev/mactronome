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
        gateOpen.store(true, ordering: .relaxed)
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

        // 게이트가 닫혀 있으면 스케줄러를 전진시키지 않고 무음을 출력합니다.
        // 엔진은 계속 돌지만 소리는 나지 않습니다.
        if !gateOpen.load(ordering: .relaxed) {
            for frame in 0..<Int(frameCount) { out[frame] = 0 }
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
