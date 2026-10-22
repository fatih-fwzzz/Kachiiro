import SwiftUI
import KachiiroCore

struct ReviewView: View {
    @State private var viewModel: ReviewViewModel
    @State private var session: QuizSessionViewModel?
    @State private var isReviewing = false

    init(viewModel: ReviewViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                Button {
                    session = viewModel.makeSession()
                    isReviewing = session != nil
                } label: {
                    Label("Start review (\(viewModel.totalCount))", systemImage: "play.fill")
                }
                .disabled(viewModel.totalCount == 0)
            }
            section("Due", items: viewModel.due)
            section("Weak", items: viewModel.weak)
            if viewModel.totalCount == 0 {
                ContentUnavailableView(
                    "Nothing to review",
                    systemImage: "checkmark.seal",
                    description: Text("Answered questions show up here when they are due or weak.")
                )
            }
        }
        .navigationTitle("Review")
        .navigationDestination(isPresented: $isReviewing) {
            if let session { QuizView(model: session) }
        }
        .onAppear { viewModel.refresh() }
    }

    @ViewBuilder
    private func section(_ title: String, items: [ReviewViewModel.Item]) -> some View {
        if !items.isEmpty {
            Section("\(title) (\(items.count))") {
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.headline).lineLimit(2)
                            if !item.subtitle.isEmpty {
                                Text(item.subtitle).font(.caption).foregroundStyle(AppTheme.secondaryInk)
                            }
                        }
                        Spacer()
                        Button {
                            viewModel.toggleBookmark(item.key)
                        } label: {
                            Image(systemName: item.isBookmarked ? "star.fill" : "star")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Bookmark")
                    }
                }
            }
        }
    }
}
