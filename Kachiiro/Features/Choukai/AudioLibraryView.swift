import Combine
import SwiftUI
import KachiiroCore

struct AudioLibraryView: View {
    @State private var viewModel: AudioLibraryViewModel
    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    init(viewModel: AudioLibraryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isEmpty {
                ContentUnavailableView(
                    "No audio bundled", systemImage: "waveform.slash",
                    description: Text(AudioLibraryViewModel.missingAudioMessage)
                )
            } else {
                List {
                    if let error = viewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                    ForEach(viewModel.lessons) { lesson in
                        Section("Lesson \(lesson.lesson)") {
                            ForEach(lesson.tracks) { track in
                                trackRow(track)
                            }
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) { if viewModel.currentTrack != nil { playerBar } }
            }
        }
        .navigationTitle("Audio library")
        .onReceive(ticker) { _ in viewModel.refresh() }
        .onAppear {
            #if DEBUG
            applyDebugAutoplay()
            #endif
        }
    }

    private func trackRow(_ track: AudioTrack) -> some View {
        Button { viewModel.select(track) } label: {
            HStack {
                Text("\(track.sequence)").font(.caption.monospacedDigit()).foregroundStyle(AppTheme.tertiaryInk).frame(width: 24)
                Text(track.label)
                Spacer()
                if viewModel.currentTrack == track {
                    Image(systemName: viewModel.isPlaying ? "speaker.wave.2.fill" : "pause.fill").foregroundStyle(AppTheme.accent)
                }
            }
        }
        .foregroundStyle(AppTheme.primaryInk)
    }

    private var playerBar: some View {
        VStack(spacing: 8) {
            if let track = viewModel.currentTrack {
                Text("Lesson \(track.lesson) · \(track.sequence). \(track.label)").font(.footnote).foregroundStyle(AppTheme.secondaryInk)
            }
            Slider(
                value: Binding(get: { viewModel.currentTime }, set: { viewModel.seek(to: $0) }),
                in: 0...max(viewModel.duration, 1)
            )
            HStack(spacing: 28) {
                Button { viewModel.skip(by: -10) } label: { Image(systemName: "gobackward.10") }
                Button { viewModel.togglePlay() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 40))
                }
                Button { viewModel.skip(by: 10) } label: { Image(systemName: "goforward.10") }
                Picker("Speed", selection: Binding(get: { viewModel.rate }, set: { viewModel.setRate($0) })) {
                    ForEach(AudioLibraryViewModel.rates, id: \.self) { Text("\($0, specifier: "%.2g")×").tag($0) }
                }
                .pickerStyle(.menu)
            }
            .font(.title2)
        }
        .padding()
        .background(.regularMaterial)
    }

    #if DEBUG
    /// `-ui-autoplay <fileName>` starts a track at launch so playback can be verified from the unified log.
    private func applyDebugAutoplay() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-ui-autoplay"), args.indices.contains(i + 1),
              let track = viewModel.lessons.flatMap(\.tracks).first(where: { $0.fileName == args[i + 1] }) else { return }
        viewModel.select(track)
    }
    #endif
}
