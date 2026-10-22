import SwiftUI
import KachiiroCore

struct PracticeView: View {
    @State private var viewModel: PracticeViewModel
    @State private var session: QuizSessionViewModel?
    @State private var isQuizActive = false
    @State private var routeConsumed = false
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
                        NavigationLink("Conjugation reference") { ConjugationReferenceView() }
                    }
                }
            }
        }
        .navigationTitle("Practice")
        .navigationDestination(isPresented: $isQuizActive) {
            if let session { QuizView(model: session) }
        }
        .task {
            guard !routeConsumed else { return }
            routeConsumed = true
            if case .drill(let drill) = launchRoute { start(drill) }
        }
    }

    private func start(_ drill: DrillKind) {
        session = viewModel.makeSession(for: drill)
        isQuizActive = session != nil
    }
}
