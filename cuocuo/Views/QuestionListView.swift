import SwiftData
import SwiftUI

enum MasteryFilter: Hashable, CaseIterable {
    case all
    case unmastered
    case mastered

    var title: String {
        switch self {
        case .all: "全部"
        case .unmastered: "未掌握"
        case .mastered: "已掌握"
        }
    }
}

enum SearchScope: String, CaseIterable, Identifiable {
    case current
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .current: "当前模块"
        case .all: "全部模块"
        }
    }
}

struct QuestionListView: View {
    let section: LibrarySection

    @Query(sort: \WrongQuestion.updatedAt, order: .reverse) private var questions: [WrongQuestion]
    @State private var query = ""
    @State private var scope: SearchScope = .current
    @State private var masteryFilter: MasteryFilter = .all
    @State private var selectedTags: [String] = []
    @State private var creating = false
    @State private var pendingDelete: WrongQuestion?

    var body: some View {
        Group {
            if libraryIsEmpty {
                ContentUnavailableView {
                    Label("还没有错题", systemImage: "document.viewfinder")
                } description: {
                    Text(section.module == nil ? "扫一道做错的题，放进对应模块。" : "这个模块还没有错题。")
                } actions: {
                    Button("扫描一道错题") { creating = true }
                }
            } else if displayed.isEmpty {
                if trimmedQuery.isEmpty {
                    ContentUnavailableView(
                        "没有符合条件的错题",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("换一个掌握状态或错因标签。")
                    )
                } else {
                    ContentUnavailableView.search(text: trimmedQuery)
                }
            } else {
                List {
                    ForEach(displayed) { question in
                        NavigationLink {
                            QuestionDetailView(question: question)
                        } label: {
                            QuestionRowLabel(question: question, showsModule: effectiveModule == nil)
                        }
                        .modifier(QuestionItemActions(question: question, onDeleteRequested: {
                            pendingDelete = question
                        }))
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !libraryIsEmpty {
                filterBar
            }
        }
        .navigationTitle(section.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creating = true
                } label: {
                    Label("新建错题", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .modifier(QuestionSearch(query: $query, scope: $scope, showsScope: section.module != nil))
        .deleteQuestionDialog(pending: $pendingDelete)
        .sheet(isPresented: $creating) {
            QuestionEditorView(existing: nil, defaultModule: section.module ?? .verbal)
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var effectiveModule: ExamModule? {
        guard let module = section.module else { return nil }
        return scope == .current ? module : nil
    }

    private var scopedQuestions: [WrongQuestion] {
        guard let module = effectiveModule else { return Array(questions) }
        return questions.filter { $0.module == module }
    }

    private var masteryMatched: [WrongQuestion] {
        switch masteryFilter {
        case .all: scopedQuestions
        case .unmastered: scopedQuestions.filter { $0.mastery == .unmastered }
        case .mastered: scopedQuestions.filter { $0.mastery == .mastered }
        }
    }

    private var searched: [WrongQuestion] {
        masteryMatched.filter { $0.matches(query: trimmedQuery) }
    }

    private var menuTags: [String] {
        Set(searched.flatMap(\.causeTags))
            .union(selectedTags)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var displayed: [WrongQuestion] {
        guard !selectedTags.isEmpty else { return searched }
        return searched.filter { question in
            selectedTags.allSatisfy { question.causeTags.contains($0) }
        }
    }

    private var libraryIsEmpty: Bool {
        scopedQuestions.isEmpty && trimmedQuery.isEmpty && selectedTags.isEmpty && masteryFilter == .all
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("掌握状态", selection: $masteryFilter) {
                ForEach(MasteryFilter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            if !menuTags.isEmpty {
                Menu {
                    Button("清除错因筛选") { selectedTags.removeAll() }
                        .disabled(selectedTags.isEmpty)
                    Divider()
                    ForEach(menuTags, id: \.self) { tag in
                        Toggle(tag, isOn: tagSelection(tag))
                    }
                } label: {
                    Label(
                        selectedTags.isEmpty ? "错因" : "错因 · \(selectedTags.count)",
                        systemImage: "tag"
                    )
                }
            }
            if !selectedTags.isEmpty {
                Text("同时包含所选错因。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private func tagSelection(_ tag: String) -> Binding<Bool> {
        Binding(
            get: { selectedTags.contains(tag) },
            set: { isOn in
                if isOn {
                    if !selectedTags.contains(tag) { selectedTags.append(tag) }
                } else {
                    selectedTags.removeAll { $0 == tag }
                }
            }
        )
    }
}

private struct QuestionSearch: ViewModifier {
    @Binding var query: String
    @Binding var scope: SearchScope
    var showsScope: Bool

    func body(content: Content) -> some View {
        if showsScope {
            content
                .searchable(text: $query, prompt: "搜索题目、错因或标签")
                .searchScopes($scope) {
                    ForEach(SearchScope.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
        } else {
            content.searchable(text: $query, prompt: "搜索题目、错因或标签")
        }
    }
}

struct QuestionRowLabel: View {
    let question: WrongQuestion
    var showsModule: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(question.summaryLine)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: question.mastery.symbol)
                .foregroundStyle(question.mastery == .mastered ? .primary : .tertiary)
                .accessibilityLabel(question.mastery.title)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if showsModule {
            parts.append(question.module.title)
        }
        if let subtype = question.subtype, !subtype.isEmpty {
            parts.append(subtype)
        }
        return parts.joined(separator: " · ")
    }

    private var thumbnail: some View {
        Group {
            if let path = question.questionPages.first?.relativePath {
                FileImage(relativePath: path, maxPixel: 160, contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 56, height: 56)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityHidden(true)
    }
}

struct QuestionItemActions: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    let question: WrongQuestion
    var onDeleteRequested: () -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive, action: onDeleteRequested) {
                    Label("删除", systemImage: "trash")
                }
                Button(action: toggleMastery) {
                    Label(question.mastery.toggledTitle, systemImage: question.mastery.toggledSymbol)
                }
                .tint(.accentColor)
            }
            .contextMenu {
                Button(action: toggleMastery) {
                    Label(question.mastery.toggledTitle, systemImage: question.mastery.toggledSymbol)
                }
                Button(role: .destructive, action: onDeleteRequested) {
                    Label("删除", systemImage: "trash")
                }
            }
    }

    private func toggleMastery() {
        let makeMastered = question.mastery == .unmastered
        try? QuestionStore.setMastered(makeMastered, question: question, in: modelContext)
    }
}

struct DeleteQuestionDialog: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Binding var pending: WrongQuestion?
    var onDeleted: () -> Void = {}
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "删除这道错题？",
                isPresented: Binding(
                    get: { pending != nil },
                    set: { if !$0 { pending = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    guard let question = pending else { return }
                    delete(question)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("题目和错因的图片会一起删除。")
            }
            .alert(
                "没有删掉",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private func delete(_ question: WrongQuestion) {
        do {
            try QuestionStore.delete(question, in: modelContext)
            pending = nil
            onDeleted()
        } catch {
            pending = nil
            errorMessage = "请再试一次。"
        }
    }
}

extension View {
    func deleteQuestionDialog(pending: Binding<WrongQuestion?>, onDeleted: @escaping () -> Void = {}) -> some View {
        modifier(DeleteQuestionDialog(pending: pending, onDeleted: onDeleted))
    }
}
