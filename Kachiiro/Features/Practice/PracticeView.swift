import SwiftUI
import KachiiroCore

struct PracticeView: View {
    @State private var viewModel: PracticeViewModel
    @State private var session: QuizSessionViewModel?
    @State private var isQuizActive = false
    @State private var routeConsumed = false
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
        List {
            if let message = viewModel.message {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
            ForEach(viewModel.sections) { section in
                Section(section.pillar.title) {
                    if section.pillar == .kaiwa, let notice = viewModel.kaiwaNotice {
                        Label(notice, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    ForEach(section.drills, id: \.self) { drill in
                        Button { start(drill) } label: {
                            HStack {
                                Text(drill.title)
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(AppTheme.tertiaryInk)
                            }
                        }
                        .foregroundStyle(AppTheme.primaryInk)
                    }
                    if section.pillar == .katsuyou {
                        NavigationLink("Conjugation reference") {
                            ConjugationReferenceView()
                                .navigationTitle("Reference")
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    }
                    if section.pillar == .choukai {
                        NavigationLink("Audio library") {
                            AudioLibraryView(viewModel: environment.makeAudioLibraryViewModel())
                        }
                    }
                    if section.pillar == .kaiwa {
                        NavigationLink("Roleplay") { RoleplayListView(scenarios: RoleplayScenario.bundled) }
                        NavigationLink("Shadowing") { ShadowingView(viewModel: environment.makeShadowingViewModel()) }
                        NavigationLink("Can-do checklist") { CanDoListView(viewModel: environment.makeCanDoViewModel()) }
                        NavigationLink("Audio library") { AudioLibraryView(viewModel: environment.makeAudioLibraryViewModel()) }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isGenerating {
                ProgressView("Generating with \(viewModel.kaiwaEngineLabel)…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .navigationTitle("Practice")
        .navigationDestination(isPresented: $isQuizActive) {
            if let session { QuizView(model: session) }
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

    private func start(_ drill: DrillKind) {
        if viewModel.usesGeneratedContent(for: drill) {
            Task {
                session = await viewModel.makeGeneratedSession(for: drill)
                isQuizActive = session != nil
            }
            return
        }
        session = viewModel.makeSession(for: drill)
        isQuizActive = session != nil
    }
}
