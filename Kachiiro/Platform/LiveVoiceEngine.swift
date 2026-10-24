import AVFoundation
import KachiiroCore
import os

/// Call audio for Gemini Live: capture and playback share one `AVAudioEngine` so voice processing can cancel the
/// partner's voice from the microphone, which keeps barge-in from triggering on the partner itself.
final class LiveVoiceEngine: LiveAudioIO {
    private static let log = Logger(subsystem: "com.muhammadfawwaz.Kachiiro", category: "LiveAudio")

    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 24_000, channels: 1, interleaved: false
    )!
    /// Set while a call is running; `nil` when the microphone is off.
    private var onChunk: (@MainActor @Sendable (Data) -> Void)?
    private var isActive = false
    private var isTapInstalled = false
    private var configurationObserver: NSObjectProtocol?

    init() {
        engine.attach(node)
    }

    func start(onChunk: @escaping @MainActor @Sendable (Data) -> Void) async throws {
        let granted = await AVAudioApplication.requestRecordPermission()
        try await Self.activateSession(record: granted)
        if granted {
            do {
                try engine.inputNode.setVoiceProcessingEnabled(true)
            } catch {
                Self.log.error("voice processing unavailable: \(error.localizedDescription)")
            }
        }
        self.onChunk = granted ? onChunk : nil
        isActive = true
        observeConfigurationChanges()
        do {
            try startGraph()
        } catch {
            Self.log.error("AVAudioEngine start failed: \(error.localizedDescription)")
            stop()
            throw error
        }
        if !granted { throw LiveAudioError.microphoneDenied }
    }

    func play(_ pcm16: Data) {
        let frames = pcm16.count / 2
        guard engine.isRunning, frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat, frameCapacity: AVAudioFrameCount(frames)),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(frames)
        pcm16.withUnsafeBytes { raw in
            for index in 0..<frames {
                let sample = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: index * 2, as: Int16.self))
                channel[index] = Float(sample) / 32768
            }
        }
        node.scheduleBuffer(buffer)
        if !node.isPlaying { node.play() }
    }

    func flushPlayback() {
        node.stop()
    }

    func stop() {
        isActive = false
        onChunk = nil
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = nil
        node.stop()
        removeTapIfNeeded()
        engine.stop()
        try? engine.inputNode.setVoiceProcessingEnabled(false)
        Task.detached {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// Connects playback, installs the microphone tap for the current input format and starts the engine.
    /// The audio session must be active first, or the output node reports no format.
    private func startGraph() throws {
        removeTapIfNeeded()
        engine.connect(node, to: engine.mainMixerNode, format: playbackFormat)
        if let onChunk {
            // Read the format after enabling voice processing: it changes the input format.
            let format = engine.inputNode.outputFormat(forBus: 0)
            if format.sampleRate > 0, format.channelCount > 0, let converter = MicrophoneConverter(input: format) {
                engine.inputNode.installTap(
                    onBus: 0, bufferSize: 4096, format: format, block: Self.tapBlock(converter, onChunk)
                )
                isTapInstalled = true
            } else {
                Self.log.error("microphone format unusable: \(format.description)")
            }
        }
        engine.prepare()
        try engine.start()
    }

    /// Enabling voice processing reconfigures the audio I/O, and the engine stops itself right after starting.
    /// The graph is rebuilt and restarted whenever that happens during a call.
    private func observeConfigurationChanges() {
        guard configurationObserver == nil else { return }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.restartAfterConfigurationChange() }
        }
    }

    private func restartAfterConfigurationChange() {
        guard isActive, !engine.isRunning else { return }
        do {
            try startGraph()
        } catch {
            Self.log.error("AVAudioEngine restart failed: \(error.localizedDescription)")
        }
    }

    private func removeTapIfNeeded() {
        guard isTapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        isTapInstalled = false
    }

    /// Off the main thread: `setCategory`/`setActive` block on the audio daemon and trigger UI-unresponsiveness warnings.
    nonisolated private static func activateSession(record: Bool) async throws {
        try await Task.detached {
            let session = AVAudioSession.sharedInstance()
            if record {
                try session.setCategory(
                    .playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP]
                )
            } else {
                try session.setCategory(.playback, mode: .spokenAudio)
            }
            try session.setActive(true)
        }.value
    }

    /// `nonisolated`: the tap runs on a realtime audio thread, not the main actor.
    nonisolated private static func tapBlock(
        _ converter: MicrophoneConverter, _ onChunk: @escaping @MainActor @Sendable (Data) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let data = converter.convert(buffer) else { return }
            Task { @MainActor in onChunk(data) }
        }
    }
}

/// Converts microphone buffers to the 16 kHz 16-bit mono PCM that Gemini Live expects.
nonisolated final class MicrophoneConverter: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let output: AVAudioFormat

    init?(input: AVAudioFormat) {
        guard let output = AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true
        ), let converter = AVAudioConverter(from: input, to: output) else { return nil }
        // Voice-processed input can carry more than one channel.
        converter.downmix = true
        self.output = output
        self.converter = converter
    }

    func convert(_ buffer: AVAudioPCMBuffer) -> Data? {
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * output.sampleRate / buffer.format.sampleRate) + 1
        guard let out = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else { return nil }
        var supplied = false
        var failure: NSError?
        let status = converter.convert(to: out, error: &failure) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, failure == nil, out.frameLength > 0, let samples = out.int16ChannelData else {
            return nil
        }
        return Data(bytes: samples[0], count: Int(out.frameLength) * 2)
    }
}
