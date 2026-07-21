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
