import AVFoundation
import KachiiroCore
import os

/// Plays the 16-bit little-endian mono PCM that Gemini Live streams, as each chunk arrives.
final class LiveAudioPlayer: PCMAudioStreaming {
    private static let log = Logger(subsystem: "com.muhammadfawwaz.Kachiiro", category: "LiveAudio")

    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private var format: AVAudioFormat?

    init() {
        engine.attach(node)
    }

    func enqueue(_ pcm16: Data, sampleRate: Double) {
        let frames = pcm16.count / 2
        guard frames > 0, startEngineIfNeeded(sampleRate: sampleRate), let format,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
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

    func stop() {
        node.stop()
        engine.stop()
    }

    /// The audio session must be active before the engine's mixer is touched, or the output node reports no format.
    private func startEngineIfNeeded(sampleRate: Double) -> Bool {
        if engine.isRunning, format?.sampleRate == sampleRate { return true }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            if format?.sampleRate != sampleRate {
                guard let new = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false
                ) else { return false }
                engine.disconnectNodeOutput(node)
                engine.connect(node, to: engine.mainMixerNode, format: new)
                format = new
            }
            engine.prepare()
            try engine.start()
            return true
        } catch {
            Self.log.error("AVAudioEngine start failed: \(error.localizedDescription)")
            return false
        }
    }
}
