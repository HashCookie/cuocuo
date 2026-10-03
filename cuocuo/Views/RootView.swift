import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WrongQuestion.updatedAt, order: .reverse) private var questions: [WrongQuestion]
    @State private var selection: LibrarySection?
    @State private var query = ""
    @State private var pendingDelete: WrongQuestion?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            NavigationStack {
                if let selection {
                    if selection == .today {
                        TodayQueueView()
                    } else {
                        QuestionListView(section: selection)
                    }
                } else {
                    ContentUnavailableView(
                        "选择一个模块",
                        systemImage: "sidebar.left",
                        description: Text("从侧边栏查看错题。")
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            selectTodayIfRegular()
            ReviewReminder.refresh(in: modelContext)
        }
        .onChange(of: horizontalSizeClass) { _, _ in
            selectTodayIfRegular()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ReviewReminder.refresh(in: modelContext)
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            if isCompact && !trimmedQuery.isEmpty {
                if searchResults.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                } else {
                    ForEach(searchResults) { question in
                        NavigationLink {
                            QuestionDetailView(question: question)
                        } label: {
                            QuestionRowLabel(question: question, showsModule: true)
                        }
                        .modifier(QuestionItemActions(question: question, onDeleteRequested: {
                            pendingDelete = question
                        }))
                    }
                }
            } else {
                ForEach(LibrarySection.sidebar) { section in
                    let count = sidebarCount(section)
                    HStack(alignment: .center, spacing: 12) {
                        LibrarySectionLabel(section: section)
                        Spacer(minLength: 8)
                        Text(count, format: .number)
                            .monospacedDigit()
                            .foregroundStyle(section == .today && count > 0 ? .primary : .secondary)
                            .accessibilityLabel(countLabel(section, count: count))
                    }
                    .tag(section)
                }
            }
        }
        .navigationTitle("错错")
        .modifier(CompactSearch(isCompact: isCompact, query: $query))
        .deleteQuestionDialog(pending: $pendingDelete)
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [WrongQuestion] {
        questions.filter { $0.matches(query: trimmedQuery) }
    }

    private func sidebarCount(_ section: LibrarySection) -> Int {
        switch section {
        case .today:
            ReviewSchedule.dueQuestions(from: Array(questions)).count
        case .all:
            questions.filter { $0.mastery == .unmastered }.count
        case .module(let module):
            questions.filter { $0.mastery == .unmastered && $0.module == module }.count
        }
    }

    private func countLabel(_ section: LibrarySection, count: Int) -> String {
        switch section {
        case .today: "今天要看 \(count)"
        case .all, .module: "未掌握 \(count)"
        }
    }

    private func selectTodayIfRegular() {
        if horizontalSizeClass != .compact, selection == nil {
            selection = .today
        }
    }
}

private struct CompactSearch: ViewModifier {
    var isCompact: Bool
    @Binding var query: String

    func body(content: Content) -> some View {
        if isCompact {
            content.searchable(text: $query, prompt: "搜索全部错题")
        } else {
            content
        }
    }
}

struct LibrarySectionLabel: View {
    let section: LibrarySection

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                Text(section.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: section.symbol)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewStore.container)
}

@MainActor
enum PreviewStore {
    static let container: ModelContainer = {
        do {
            let schema = Schema([WrongQuestion.self, ScanPage.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("无法创建预览数据：\(error)")
        }
    }()
}
