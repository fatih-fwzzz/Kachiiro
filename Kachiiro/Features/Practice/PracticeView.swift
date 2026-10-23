import SwiftUI
import KachiiroCore

struct PracticeView: View {
    @State private var viewModel: PracticeViewModel
    @State private var session: QuizSessionViewModel?
    @State private var isQuizActive = false
    @State private var routeConsumed = false
    @State private var showAudio = false
    @State private var showCanDo = false
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
                        NavigationLink("Can-do checklist") { CanDoListView(viewModel: environment.makeCanDoViewModel()) }
                        NavigationLink("Audio library") { AudioLibraryView(viewModel: environment.makeAudioLibraryViewModel()) }
                    }
                }
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
        .task {
            guard !routeConsumed else { return }
            routeConsumed = true
            switch launchRoute {
            case .drill(let drill): start(drill)
            case .audio: showAudio = true
            case .cando: showCanDo = true
            default: break
            }
        }
    }

    private func start(_ drill: DrillKind) {
        session = viewModel.makeSession(for: drill)
        isQuizActive = session != nil
    }
}
