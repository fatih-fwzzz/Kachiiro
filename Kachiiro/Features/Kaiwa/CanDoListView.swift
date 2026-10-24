import SwiftUI
import KachiiroCore

/// "I can…" statements are motivation, so ticking one is a moment: a progress hero, a ring per lesson,
/// and Listen beside items that have lesson audio.
struct CanDoListView: View {
    @State private var viewModel: CanDoViewModel
    @State private var book: String

    init(viewModel: CanDoViewModel) {
        _viewModel = State(initialValue: viewModel)
        _book = State(initialValue: viewModel.books.last ?? CanDo.book2)
    }

    var body: some View {
        let progress = viewModel.progress(book: book)
        ScrollView {
            VStack(spacing: 14) {
                Picker("Book", selection: $book) {
                    ForEach(viewModel.books, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                hero(done: progress.done, total: progress.total)
                ForEach(viewModel.groups(book: book)) { group in lessonCard(group) }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas)
        .navigationTitle("I can…")
    }

    private func hero(done: Int, total: Int) -> some View {
        HStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(done)").font(.system(size: 34, weight: .heavy, design: .rounded))
                Text("/ \(total)").font(AppTheme.Fonts.ui(.title3, weight: .bold)).opacity(0.8)
            }
            .monospacedDigit()
            VStack(alignment: .leading, spacing: 6) {
                Text("things you can do in Japanese").font(AppTheme.Fonts.ui(.footnote, weight: .bold))
                LinearProgress(value: Double(done) / Double(max(total, 1)), tint: .white, track: .white.opacity(0.25), height: 6)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) can-do statements done")
    }

    private func lessonCard(_ group: CanDoViewModel.LessonGroup) -> some View {
        let done = group.items.filter(viewModel.isDone).count
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ProgressRing(value: Double(done) / Double(max(group.items.count, 1)), lineWidth: 5) {
                    Text("\(group.lesson)").font(AppTheme.Fonts.ui(.caption, weight: .heavy)).monospacedDigit()
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Lesson \(group.lesson) · \(group.title)").font(AppTheme.Fonts.ui(.callout, weight: .heavy))
                    Text("\(group.topic) · \(done) of \(group.items.count) done")
                        .font(AppTheme.Fonts.ui(.caption))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            ForEach(group.items) { item in
                Divider().overlay(AppTheme.hairlineBorder)
                row(item)
            }
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private func row(_ item: CanDo) -> some View {
        let isDone = viewModel.isDone(item)
        return HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.snappy) { viewModel.toggle(item) }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(isDone ? Color.white : .clear)
                    .frame(width: 30, height: 30)
                    .background(isDone ? AppTheme.accent : .clear, in: Circle())
                    .overlay(Circle().strokeBorder(isDone ? .clear : AppTheme.tertiaryInk, lineWidth: 2))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: isDone) { _, new in new }
            .accessibilityLabel(isDone ? "Done" : "Mark as done")
            VStack(alignment: .leading, spacing: 6) {
                Text(item.text)
                    .font(AppTheme.Fonts.ui(.subheadline))
                    .foregroundStyle(isDone ? AppTheme.secondaryInk : AppTheme.primaryInk)
                if item.hasAudio, !viewModel.tracks(for: item).isEmpty {
                    NavigationLink {
                        LessonAudioView(lesson: item.lesson)
                    } label: {
                        Label("Listen to the lesson", systemImage: "headphones")
                            .font(AppTheme.Fonts.ui(.footnote, weight: .bold))
                            .foregroundStyle(AppTheme.accentText)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .background(AppTheme.accentSoftFill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10)
        }
        .padding(.vertical, 4)
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
