import SwiftUI
import KachiiroCore

/// Five pillar cards with this week's accuracy, one recommended drill, and the study tools.
struct PracticeView: View {
    @State private var viewModel: PracticeViewModel
    @State private var session: QuizSessionViewModel?
    @State private var routeConsumed = false
    @State private var openPillar: Pillar?
    @State private var showAudio = false
    @State private var showCanDo = false
    @State private var showRoleplayList = false
    @State private var roleplayScenario: RoleplayScenario?
    @State private var showShadowing = false
    @Environment(AppEnvironment.self) private var environment
    private let launchRoute: LaunchRoute?

    init(viewModel: PracticeViewModel, launchRoute: LaunchRoute? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.launchRoute = launchRoute
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                if let message = viewModel.message {
                    Banner(kind: .warning, title: message,
                           message: "Change the books or lessons in Settings to widen it.",
                           action: .init(title: "OK") { viewModel.clearMessage() })
                }
                if let recommendation = viewModel.recommendation {
                    recommendedCard(recommendation)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.sections) { section in
                        Button { openPillar = section.pillar } label: { pillarCard(section) }
                            .buttonStyle(PressableStyle())
                    }
                }
                tools
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas)
        .navigationTitle("Practice")
        .overlay { if viewModel.isGenerating { GeneratingCard(engine: viewModel.kaiwaEngineLabel) } }
        .drillSession($session)
        .navigationDestination(item: $openPillar) { pillar in
            PillarView(pillar: pillar, viewModel: viewModel)
        }
        .navigationDestination(isPresented: $showCanDo) {
            CanDoListView(viewModel: environment.makeCanDoViewModel())
        }
        .navigationDestination(isPresented: $showAudio) {
            AudioLibraryView(viewModel: environment.makeAudioLibraryViewModel())
        }
        .navigationDestination(isPresented: $showRoleplayList) {
            RoleplayListView(scenarios: RoleplayScenario.bundled)
        }
        .navigationDestination(isPresented: Binding(
            get: { roleplayScenario != nil }, set: { if !$0 { roleplayScenario = nil } }
        )) {
            if let scenario = roleplayScenario { RoleplayView(viewModel: environment.makeRoleplayViewModel(scenario)) }
        }
        .navigationDestination(isPresented: $showShadowing) {
            ShadowingView(viewModel: environment.makeShadowingViewModel())
        }
        .onAppear { viewModel.refresh() }
        .task {
            guard !routeConsumed else { return }
            routeConsumed = true
            switch launchRoute {
            case .drill(let drill): start(drill)
            case .audio: showAudio = true
            case .cando: showCanDo = true
            case .roleplay(let id):
                if let id, let scenario = RoleplayScenario.bundled.first(where: { $0.id == id }) {
                    roleplayScenario = scenario
                } else {
                    showRoleplayList = true
                }
            case .shadowing: showShadowing = true
            default: break
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Study scope").font(AppTheme.Fonts.ui(.subheadline, weight: .semibold)).foregroundStyle(AppTheme.secondaryInk)
            Spacer()
            Text(viewModel.scopeLabel)
                .font(AppTheme.Fonts.ui(.subheadline, weight: .bold))
                .foregroundStyle(AppTheme.accentText)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(AppTheme.accentSoftFill, in: Capsule())
                .accessibilityLabel("Study scope \(viewModel.scopeLabel). Change it in Settings.")
        }
    }

    private func recommendedCard(_ recommendation: PracticeViewModel.Recommendation) -> some View {
        Button { start(recommendation.drill) } label: {
            HStack(spacing: 14) {
                GlyphTile(glyph: recommendation.drill.pillar.glyph, style: .accent, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    SectionCaps(text: "Recommended now", color: AppTheme.accentText)
                    Text(recommendation.drill.title)
                        .font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                        .foregroundStyle(AppTheme.primaryInk)
                    Text(recommendation.reason.text)
                        .font(AppTheme.Fonts.ui(.footnote))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                Spacer(minLength: 8)
                Text("Go")
                    .font(AppTheme.Fonts.ui(.callout, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(16)
            .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous).strokeBorder(AppTheme.accent, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private func pillarCard(_ section: PracticeViewModel.PillarSection) -> some View {
        let percent = viewModel.percent(for: section.pillar)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                GlyphTile(glyph: section.pillar.glyph)
                Spacer()
                PercentLabel(percent: percent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(section.pillar.shortName)
                    .font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                    .foregroundStyle(AppTheme.primaryInk)
                Text(section.drills.map(\.title).joined(separator: " · "))
                    .font(AppTheme.Fonts.ui(.caption))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            LinearProgress(value: Double(percent ?? 0) / 100, tint: (percent ?? 100) < 50 ? AppTheme.ember : AppTheme.accent, height: 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the \(section.pillar.shortName) drills")
    }

    private var tools: some View {
        VStack(spacing: 8) {
            SectionCaps(text: "Tools").padding(.leading, 4)
            HStack(spacing: 8) {
                NavigationLink {
                    ConjugationReferenceView().navigationTitle("Reference").navigationBarTitleDisplayMode(.inline)
                } label: { ToolLabel(title: "Reference", icon: "book.closed") }
                Button { showAudio = true } label: { ToolLabel(title: "Audio", icon: "headphones") }
                Button { showCanDo = true } label: { ToolLabel(title: "Can-do", icon: "checkmark.circle") }
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func start(_ drill: DrillKind) {
        Task { session = await viewModel.makeAnySession(for: drill) }
    }
}

/// One pillar's drills and tools. Kaiwa groups them by what you do: speak, drill, track.
struct PillarView: View {
    let pillar: Pillar
    let viewModel: PracticeViewModel
    @State private var session: QuizSessionViewModel?
    @Environment(AppEnvironment.self) private var environment

    private var drills: [DrillKind] {
        viewModel.sections.first { $0.pillar == pillar }?.drills ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    GlyphTile(glyph: pillar.glyph, size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pillar.title).font(AppTheme.Fonts.ui(.title2, weight: .heavy))
                        Text(viewModel.percent(for: pillar).map { "\($0)% correct this week" } ?? "Not practised this week")
                            .font(AppTheme.Fonts.ui(.subheadline))
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                }
                if pillar == .kaiwa, let notice = viewModel.kaiwaNotice {
                    Banner(kind: .info, title: "Using offline checks", message: notice)
                }
                if let message = viewModel.message {
                    Banner(kind: .warning, title: message, action: .init(title: "OK") { viewModel.clearMessage() })
                }
                if pillar == .kaiwa { speakCards }
                SectionCaps(text: pillar == .kaiwa ? "Drill" : "Drills").padding(.leading, 4)
                VStack(spacing: 0) {
                    ForEach(Array(drills.enumerated()), id: \.element) { index, drill in
                        Button { Task { session = await viewModel.makeAnySession(for: drill) } } label: { drillRow(drill) }
                            .buttonStyle(PressableStyle())
                        if index < drills.count - 1 { Divider().overlay(AppTheme.hairlineBorder) }
                    }
                }
                .padding(.horizontal, 16)
                .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                pillarTools
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas)
        .navigationTitle(pillar.shortName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if viewModel.isGenerating { GeneratingCard(engine: viewModel.kaiwaEngineLabel) } }
        .drillSession($session)
    }

    private func drillRow(_ drill: DrillKind) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(drill.title).font(AppTheme.Fonts.ui(.callout, weight: .bold)).foregroundStyle(AppTheme.primaryInk)
                Text(drill.blurb).font(AppTheme.Fonts.ui(.footnote)).foregroundStyle(AppTheme.secondaryInk)
            }
            Spacer(minLength: 8)
            Image(systemName: "play.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.accentSoftFill, in: Circle())
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Starts a \(PracticeViewModel.sessionLength)-question drill")
    }

    private var speakCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionCaps(text: "Speak").padding(.leading, 4)
            HStack(spacing: 12) {
                NavigationLink {
                    RoleplayListView(scenarios: RoleplayScenario.bundled)
                } label: {
                    SpeakCard(title: "Roleplay", subtitle: "\(RoleplayScenario.bundled.count) scenarios", icon: "phone.fill", hero: true)
                }
                NavigationLink {
                    ShadowingView(viewModel: environment.makeShadowingViewModel())
                } label: {
                    SpeakCard(title: "Shadowing", subtitle: "Repeat set phrases", icon: "waveform", hero: false)
                }
            }
            .buttonStyle(PressableStyle())
        }
    }

    @ViewBuilder
    private var pillarTools: some View {
        switch pillar {
        case .katsuyou:
            NavigationLink {
                ConjugationReferenceView().navigationTitle("Reference").navigationBarTitleDisplayMode(.inline)
            } label: { ToolLabel(title: "Conjugation reference", icon: "book.closed") }
                .buttonStyle(PressableStyle())
        case .choukai:
            NavigationLink {
                AudioLibraryView(viewModel: environment.makeAudioLibraryViewModel())
            } label: { ToolLabel(title: "Lesson audio", icon: "headphones") }
                .buttonStyle(PressableStyle())
        case .kaiwa:
            SectionCaps(text: "Track").padding(.leading, 4)
            HStack(spacing: 8) {
                NavigationLink {
                    CanDoListView(viewModel: environment.makeCanDoViewModel())
                } label: { ToolLabel(title: "Can-do", icon: "checkmark.circle") }
                NavigationLink {
                    AudioLibraryView(viewModel: environment.makeAudioLibraryViewModel())
                } label: { ToolLabel(title: "Lesson audio", icon: "headphones") }
            }
            .buttonStyle(PressableStyle())
        case .goi, .bunpou:
            EmptyView()
        }
    }
}

// MARK: Shared pieces

extension View {
    /// Pushes `QuizView` while `session` is set.
    func drillSession(_ session: Binding<QuizSessionViewModel?>) -> some View {
        navigationDestination(isPresented: Binding(
            get: { session.wrappedValue != nil }, set: { if !$0 { session.wrappedValue = nil } }
        )) {
            if let model = session.wrappedValue { QuizView(model: model) }
        }
    }
}

extension PracticeViewModel {
    /// A bundled session, or an AI-generated one when Kaiwa uses generated content.
    func makeAnySession(for drill: DrillKind) async -> QuizSessionViewModel? {
        usesGeneratedContent(for: drill) ? await makeGeneratedSession(for: drill) : makeSession(for: drill)
    }
}

extension DashboardViewModel.PlanStep.Reason {
    var text: String {
        switch self {
        case .weakest(let percent): "Your weakest this week · \(percent)%"
        case .notPractised: "Not practised this week"
        case .keepSharp(let percent): "Keep it sharp · \(percent)%"
        }
    }
}

extension DrillKind {
    /// One line on what the drill trains.
    var blurb: String {
        switch self {
        case .verbForms: "て, た, ない and 8 more forms"
        case .inflectionMatrix: "Plain and polite, past and negative"
        case .vocab: "Meaning ↔ word"
        case .kanji: "Read and write kanji"
        case .pitch: "Hear the accent shape"
        case .patternRecognition: "Spot the grammar pattern"
        case .registerShift: "Switch between だ and です"
        case .dictation: "Write what you hear"
        case .sentenceListening: "Hear a sentence, pick its meaning"
        case .keigo: "Raise or lower with keigo"
        case .uchiSoto: "Inside and outside speech"
        }
    }
}

private struct PercentLabel: View {
    let percent: Int?

    var body: some View {
        Text(percent.map { "\($0)%" } ?? "New")
            .font(AppTheme.Fonts.ui(.subheadline, weight: .heavy))
            .foregroundStyle(percent.map { $0 < 50 ? AppTheme.emberText : AppTheme.accentText } ?? AppTheme.accentText)
            .monospacedDigit()
    }
}

private struct ToolLabel: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(AppTheme.Fonts.ui(.subheadline, weight: .bold))
            .foregroundStyle(AppTheme.primaryInk)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SpeakCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let hero: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(hero ? Color.white : AppTheme.accentText)
                .frame(width: 44, height: 44)
                .background(hero ? AppTheme.accent : AppTheme.accentSoftFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                Text(subtitle).font(AppTheme.Fonts.ui(.footnote))
                    .foregroundStyle(hero ? AppTheme.onKachiiroSecondary : AppTheme.secondaryInk)
            }
        }
        .foregroundStyle(hero ? Color.white : AppTheme.primaryInk)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(hero ? AppTheme.kachiiro : AppTheme.cardSurface,
                    in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

/// Shown while the AI builds a drill: what is happening, on a calm card.
private struct GeneratingCard: View {
    let engine: String

    var body: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.white).controlSize(.large)
            Text("Building your drill").font(AppTheme.Fonts.ui(.headline, weight: .heavy))
            Text("\(engine) is writing fresh questions…")
                .font(AppTheme.Fonts.ui(.footnote))
                .foregroundStyle(AppTheme.onKachiiroSecondary)
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(AppTheme.kachiiro, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
