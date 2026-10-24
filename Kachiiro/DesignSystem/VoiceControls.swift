import SwiftUI
import KachiiroCore

/// Mic toggle for `VoiceInputModel`: first tap starts listening, second tap stops and hands the transcript to `onStop`.
/// Before iOS has ever asked for access, the first tap explains why first (a primer sheet), then iOS asks.
struct MicButton: View {
    let voice: VoiceInputModel
    var diameter: CGFloat = 36
    var onStart: () -> Void = {}
    let onStop: (String) -> Void
    @State private var showPrimer = false

    var body: some View {
        Button {
            if voice.state == .listening {
                onStop(voice.stop())
            } else if voice.needsPermissionPrimer {
                showPrimer = true
            } else {
                begin()
            }
        } label: {
            Image(systemName: voice.state == .listening ? "stop.fill" : "mic.fill")
                .font(.system(size: diameter * (voice.state == .listening ? 0.4 : 0.5), weight: .semibold))
                .foregroundStyle(voice.state == .listening ? Color.white : AppTheme.accent)
                .frame(width: diameter, height: diameter)
                .background(voice.state == .listening ? AppTheme.accent : .clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voice.state == .listening ? "Stop listening" : "Speak your answer")
        .sheet(isPresented: $showPrimer) {
            MicPrimerSheet(
                onAllow: {
                    showPrimer = false
                    begin()
                },
                onDecline: { showPrimer = false }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func begin() {
        onStart()
        Task { await voice.start() }
    }
}

/// Explains why the microphone helps before the iOS alert, with typing as a first-class way out.
private struct MicPrimerSheet: View {
    let onAllow: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)
            Text("Say it out loud,\nremember it longer")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 10) {
                point("Answer keigo and roleplay turns by speaking, like the real exam.")
                point("Kachiiro listens only while the mic button is on.")
                point("Typing always works too.")
            }
            Text("iOS asks next. You can change this any time in Settings.")
                .font(AppTheme.Fonts.ui(.footnote))
                .foregroundStyle(AppTheme.secondaryInk)
            Spacer(minLength: 0)
            Button("Allow microphone", action: onAllow).buttonStyle(.primary)
            Button("Type my answers instead", action: onDecline).buttonStyle(.quiet)
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(24)
        .background(AppTheme.cardSurface)
    }

    private func point(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark").font(.footnote.weight(.black)).foregroundStyle(AppTheme.accent)
            Text(text).font(AppTheme.Fonts.ui(.subheadline))
        }
    }
}

/// The denied and failed states of `VoiceInputModel`, with a way to fix access.
struct VoiceStatusCaption: View {
    let voice: VoiceInputModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch voice.state {
        case .denied:
            Banner(kind: .warning, title: "Microphone is off for Kachiiro",
                   message: "Turn it on in Settings, or type your answer.",
                   action: .init(title: "Open Settings") {
                       if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                   })
        case .failed(let message):
            Banner(kind: .warning, title: "Couldn’t start listening", message: message)
        case .idle, .listening:
            EmptyView()
        }
    }
}
