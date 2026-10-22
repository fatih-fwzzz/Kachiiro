import SwiftUI
import KachiiroCore

struct CanDoListView: View {
    @State private var viewModel: CanDoViewModel
    @State private var book: String

    init(viewModel: CanDoViewModel) {
        _viewModel = State(initialValue: viewModel)
        _book = State(initialValue: viewModel.books.last ?? CanDo.book2)
    }

    var body: some View {
        let progress = viewModel.progress(book: book)
        List {
            Section {
                Picker("Book", selection: $book) {
                    ForEach(viewModel.books, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1))) {
                    Text("\(progress.done) / \(progress.total) Can-dos")
                        .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                }
            }
            ForEach(viewModel.groups(book: book)) { group in
                Section {
                    ForEach(group.items) { item in row(item) }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lesson \(group.lesson) · \(group.title)").font(.subheadline.weight(.semibold))
                        Text(group.topic).font(.caption)
                    }
                    .textCase(nil)
                }
            }
        }
        .navigationTitle("Can-do checklist")
    }

    private func row(_ item: CanDo) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { viewModel.toggle(item) } label: {
                Image(systemName: viewModel.isDone(item) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(viewModel.isDone(item) ? AppTheme.accent : AppTheme.tertiaryInk)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(viewModel.isDone(item) ? "Done" : "Not done")
            VStack(alignment: .leading, spacing: 6) {
                Text(item.text).font(.callout)
                if item.hasAudio, !viewModel.tracks(for: item).isEmpty {
                    NavigationLink {
                        LessonAudioView(lesson: item.lesson)
                    } label: {
                        Label("Listen", systemImage: "headphones").font(.footnote.weight(.semibold))
                    }
                }
            }
        }
    }
}

/// The audio library restricted to one lesson.
struct LessonAudioView: View {
    @Environment(AppEnvironment.self) private var environment
    let lesson: Int

    var body: some View {
        AudioLibraryView(viewModel: environment.makeAudioLibraryViewModel(), lesson: lesson)
    }
}
