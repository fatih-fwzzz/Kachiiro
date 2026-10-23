import SwiftUI
import KachiiroCore

/// Mic toggle for `VoiceInputModel`: first tap starts listening, second tap stops and hands the transcript to `onStop`.
struct MicButton: View {
    let voice: VoiceInputModel
    var diameter: CGFloat = 36
    var onStart: () -> Void = {}
    let onStop: (String) -> Void

    var body: some View {
        Button {
            if voice.state == .listening {
                onStop(voice.stop())
            } else {
                onStart()
                Task { await voice.start() }
            }
        } label: {
            Image(systemName: voice.state == .listening ? "stop.circle.fill" : "mic.fill")
                .font(.system(size: diameter * 0.55, weight: .semibold))
                .foregroundStyle(voice.state == .listening ? Color.red : AppTheme.accent)
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voice.state == .listening ? "Stop listening" : "Speak your answer")
    }
}

/// Caption for the denied and failed states of `VoiceInputModel`.
struct VoiceStatusCaption: View {
    let voice: VoiceInputModel

    var body: some View {
        switch voice.state {
        case .denied:
            caption(VoiceInputModel.deniedMessage)
        case .failed(let message):
            caption(message)
        case .idle, .listening:
            EmptyView()
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryInk)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
