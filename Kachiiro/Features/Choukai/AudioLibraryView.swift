import Combine
import SwiftUI
import KachiiroCore

/// Lesson tracks grouped as cards, a kind filter, and a navy player sheet with visible speed choices.
struct AudioLibraryView: View {
    @State private var viewModel: AudioLibraryViewModel
    @State private var kind: AudioTrack.Kind?
    private let lesson: Int?
    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    /// - Parameter lesson: shows only this lesson when set.
    init(viewModel: AudioLibraryViewModel, lesson: Int? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.lesson = lesson
    }

    private var visibleLessons: [(lesson: Int, tracks: [AudioTrack])] {
        viewModel.lessons
            .filter { lesson == nil || $0.lesson == lesson }
            .map { (lesson: $0.lesson, tracks: $0.tracks.filter { kind == nil || $0.kind == kind }) }
            .filter { !$0.tracks.isEmpty }
    }

    var body: some View {
        Group {
            if viewModel.isEmpty {
                ContentUnavailableView(
                    "Lesson audio isn’t on this device", systemImage: "headphones",
                    description: Text("The 初級2 recordings aren’t installed. Dictation and shadowing still work with the iPhone voice.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        if let error = viewModel.errorMessage {
                            Banner(kind: .warning, title: "Couldn’t play that track", message: error)
                        }
                        kindChips
                        ForEach(visibleLessons, id: \.lesson) { entry in lessonCard(lesson: entry.lesson, tracks: entry.tracks) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .background(AppTheme.canvas)
                .safeAreaInset(edge: .bottom) { if viewModel.currentTrack != nil { playerSheet } }
            }
        }
        .navigationTitle(lesson.map { "Lesson \($0) audio" } ?? "Lesson audio")
        .onReceive(ticker) { _ in viewModel.refresh() }
        .onAppear {
            #if DEBUG
            applyDebugAutoplay()
            #endif
        }
    }

    private var kindChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", selected: kind == nil) { kind = nil }
                ForEach(AudioTrack.Kind.allCases, id: \.self) { k in
                    chip(k.label, selected: kind == k) { kind = k }
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Fonts.ui(.subheadline, weight: .bold))
                .foregroundStyle(selected ? Color.white : AppTheme.primaryInk)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(selected ? AppTheme.kachiiro : AppTheme.cardSurface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func lessonCard(lesson: Int, tracks: [AudioTrack]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Lesson \(lesson)")
                .font(AppTheme.Fonts.ui(.callout, weight: .heavy))
                .padding(.vertical, 10)
                .accessibilityAddTraits(.isHeader)
            ForEach(tracks) { track in
                Divider().overlay(AppTheme.hairlineBorder)
                Button { viewModel.select(track) } label: { trackRow(track) }
                    .buttonStyle(PressableStyle())
            }
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private func trackRow(_ track: AudioTrack) -> some View {
        let isCurrent = viewModel.currentTrack == track
        return HStack(spacing: 12) {
            Group {
                if isCurrent {
                    Image(systemName: viewModel.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.system(size: 13, weight: .bold))
                } else {
                    Text("\(track.sequence)").font(AppTheme.Fonts.ui(.footnote, weight: .heavy)).monospacedDigit()
                }
            }
            .foregroundStyle(isCurrent ? Color.white : AppTheme.secondaryInk)
            .frame(width: 32, height: 32)
            .background(isCurrent ? AppTheme.accent : AppTheme.elevatedField, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(track.label)
                .font(AppTheme.Fonts.ui(.callout, weight: isCurrent ? .heavy : .semibold))
                .foregroundStyle(isCurrent ? AppTheme.accentText : AppTheme.primaryInk)
            Spacer()
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var playerSheet: some View {
        VStack(spacing: 12) {
            if let track = viewModel.currentTrack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionCaps(text: "Lesson \(track.lesson) · track \(track.sequence)", color: AppTheme.onKachiiroLabel)
                        Text(track.label).font(AppTheme.Fonts.ui(.title3, weight: .heavy))
                    }
                    Spacer()
                    Button { viewModel.stop() } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(AppTheme.Fonts.ui(.subheadline, weight: .heavy))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(.white.opacity(0.12), in: Capsule())
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Stops playback and closes the player")
                }
            }
            VStack(spacing: 2) {
                Slider(
                    value: Binding(get: { viewModel.currentTime }, set: { viewModel.seek(to: $0) }),
                    in: 0...max(viewModel.duration, 1)
                )
                .tint(Color(hex: 0x0A84FF))
                HStack {
                    Text(time(viewModel.currentTime))
                    Spacer()
                    Text(time(viewModel.duration))
                }
                .font(AppTheme.Fonts.ui(.caption, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.onKachiiroSecondary)
            }
            HStack(spacing: 28) {
                Button { viewModel.skip(by: -10) } label: { Image(systemName: "gobackward.10").font(.title2) }
                    .accessibilityLabel("Back 10 seconds")
                Button { viewModel.togglePlay() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.kachiiro)
                        .frame(width: 64, height: 64)
                        .background(.white, in: Circle())
                }
                .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
                Button { viewModel.skip(by: 10) } label: { Image(systemName: "goforward.10").font(.title2) }
                    .accessibilityLabel("Forward 10 seconds")
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                ForEach(AudioLibraryViewModel.rates, id: \.self) { rate in
                    let selected = viewModel.rate == rate
                    Button { viewModel.setRate(rate) } label: {
                        Text("\(rateText(rate))×")
                            .font(AppTheme.Fonts.ui(.subheadline, weight: .heavy))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(selected ? Color(hex: 0x0A84FF) : .white.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Speed \(rateText(rate)) times")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: AppTheme.Radius.hero, topTrailingRadius: AppTheme.Radius.hero, style: .continuous)
                .fill(AppTheme.kachiiro)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    /// 0.75, 1, 1.25 with up to two decimals.
    private func rateText(_ rate: Float) -> String {
        Double(rate).formatted(.number.precision(.fractionLength(0...2)))
    }

    private func time(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
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

extension AudioTrack.Kind {
    /// Matches the track labels: Listen, Speak, Form, Vocab, Dialogue.
    var label: String {
        switch self {
        case .kiku: "Listen"
        case .hanasu: "Speak"
        case .katachi: "Form"
        case .kotoba: "Vocab"
        case .kaiwa: "Dialogue"
        }
    }
}
