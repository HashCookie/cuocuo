import SwiftData
import SwiftUI

private struct ReviewProgressTitle: ViewModifier {
    var title: String?

    func body(content: Content) -> some View {
        if let title {
            content.navigationSubtitle(title)
        } else {
            content
        }
    }
}

struct ReviewSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var questions: [WrongQuestion]

    @State private var order: [UUID]
    @State private var index = 0
    @State private var revealed = false
    @State private var selectedChoice: String?
    @State private var submittedChoice: String?
    @State private var knownTicks = 0
    @State private var againTicks = 0
    @State private var correctTicks = 0
    @State private var wrongTicks = 0
    @State private var viewer: PageViewerRoute?

    init(questionIDs: [UUID]) {
        _order = State(initialValue: questionIDs)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isFinished {
                    ContentUnavailableView {
                        Label("今天的都看完了", systemImage: "checkmark.circle")
                    } description: {
                        Text(finishedMessage)
                    } actions: {
                        Button("完成") { dismiss() }
                    }
                } else if let question = current {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(header(for: question))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            pageGallery(question.questionPages, title: "题目")
                            if question.questionPages.isEmpty, !question.questionText.isEmpty {
                                Text(question.questionText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            if hasChoiceImages(question) {
                                choiceBoard(for: question)
                            }
                            if let result = resultText(for: question) {
                                Text(result)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if revealed, hasAnalysis(question) {
                                Divider()
                                Text("错因")
                                    .font(.headline)
                                pageGallery(question.analysisPages, title: "错因")
                                if !question.analysisText.isEmpty {
                                    Text(question.analysisText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                                if !question.causeTags.isEmpty {
                                    Text(question.causeTags.joined(separator: "、"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                    }
                    .id(question.id)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        actionBar(for: question)
                    }
                }
            }
            .background(.background)
            .navigationTitle("今天要看")
            .modifier(ReviewProgressTitle(title: order.count > 1 ? progressTitle : nil))
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("结束") { dismiss() }
                }
                if canPostpone {
                    ToolbarItem(placement: .primaryAction) {
                        Button("稍后") { postpone() }
                    }
                }
            }
        }
        .adaptiveCover(item: $viewer) { route in
            PageViewer(title: route.title, paths: route.paths, index: route.index)
        }
        .task(id: index) {
            dropMissingCurrent()
        }
    }

    private var isFinished: Bool {
        index >= order.count
    }

    private var current: WrongQuestion? {
        guard order.indices.contains(index) else { return nil }
        let id = order[index]
        return questions.first { $0.id == id }
    }

    private var canPostpone: Bool {
        order.count > 1 && index < order.count - 1
    }

    private var progressTitle: String {
        if isFinished || order.isEmpty { return "看完了" }
        return "\(index + 1) / \(order.count)"
    }

    private var finishedMessage: String {
        if let next = ReviewSchedule.nextUpcoming(from: Array(questions)) {
            return "下一题在 \(ReviewSchedule.dayText(next))。"
        }
        return "未掌握的题都看过了。"
    }

    private func header(for question: WrongQuestion) -> String {
        if let subtype = question.subtype, !subtype.isEmpty {
            return "\(question.module.title) · \(subtype)"
        }
        return question.module.title
    }

    @ViewBuilder
    private func pageGallery(_ pages: [ScanPage], title: String) -> some View {
        if !pages.isEmpty {
            VStack(spacing: 12) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { offset, page in
                    Button {
                        viewer = PageViewerRoute(
                            title: title,
                            paths: pages.map(\.relativePath),
                            index: offset
                        )
                    } label: {
                        FileImage(relativePath: page.relativePath, maxPixel: 1600, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.quaternary)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title)第 \(offset + 1) 页，点按放大")
                }
            }
        }
    }

    private func actionBar(for question: WrongQuestion) -> some View {
        VStack(spacing: 12) {
            if revealed {
                HStack(spacing: 12) {
                    outcomeButton(title: "还会", caption: "\(ReviewSchedule.againDays) 天后再看", prominent: false) {
                        againTicks += 1
                        try? QuestionStore.scheduleAgain(question, in: modelContext)
                        advance()
                    }
                    outcomeButton(title: "已经会了", caption: "标成已掌握", prominent: true) {
                        knownTicks += 1
                        try? QuestionStore.setMastered(true, question: question, in: modelContext)
                        advance()
                    }
                }
            } else {
                if !hasChoiceImages(question) {
                    HStack(spacing: 8) {
                        ForEach(question.answerChoices.filter { $0 != "E" }, id: \.self) { letter in
                            choiceButton(letter, question: question)
                        }
                    }
                }
                if submittedChoice != nil, question.correctChoice == nil {
                    Text("点一个字母，记下正确答案。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if hasAnalysis(question), submittedChoice == nil {
                    Button {
                        withAnimation(.snappy) { revealed = true }
                    } label: {
                        Text("看错因")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                }
            }
        }
        .padding()
        .background(.bar)
        .sensoryFeedback(.success, trigger: knownTicks)
        .sensoryFeedback(.impact, trigger: againTicks)
        .sensoryFeedback(.success, trigger: correctTicks)
        .sensoryFeedback(.error, trigger: wrongTicks)
    }

    @ViewBuilder
    private func outcomeButton(
        title: String,
        caption: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let label = VStack(spacing: 2) {
            Text(title)
            Text(caption)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)

        if prominent {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        } else {
            Button(action: action) { label }
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }

    private func hasChoiceImages(_ question: WrongQuestion) -> Bool {
        question.answerChoices.contains { question.choiceClipPath(for: $0) != nil }
    }

    private func hasAnalysis(_ question: WrongQuestion) -> Bool {
        !question.analysisText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !question.analysisPages.isEmpty
    }

    private func choiceBoard(for question: WrongQuestion) -> some View {
        let hasClips = question.answerChoices.contains { question.choiceClipPath(for: $0) != nil }
        return VStack(alignment: .leading, spacing: 8) {
            Text(choiceTitle(for: question))
                .font(.headline)
            if hasClips {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(question.answerChoices, id: \.self) { letter in
                        choiceButton(letter, question: question)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(question.answerChoices.filter { $0 != "E" }, id: \.self) { letter in
                        choiceButton(letter, question: question)
                    }
                }
            }
        }
    }

    private func choiceTitle(for question: WrongQuestion) -> String {
        if submittedChoice != nil, question.correctChoice == nil, !revealed {
            return "正确答案是"
        }
        return "选择答案"
    }

    private func choiceButton(_ letter: String, question: WrongQuestion) -> some View {
        let role = choiceRole(letter, question: question)
        return Button {
            handleChoice(letter, question: question)
        } label: {
            VStack(spacing: 6) {
                if let path = question.choiceClipPath(for: letter) {
                    FileImage(relativePath: path, maxPixel: 600, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 88, maxHeight: 140)
                } else {
                    Text(letter)
                        .font(.title3.weight(.semibold))
                }
                if question.choiceClipPath(for: letter) != nil {
                    Text(letter)
                        .font(.headline)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .frame(height: question.choiceClipPath(for: letter) == nil ? 44 : nil)
            .foregroundStyle(role.foreground)
            .background(role.fill, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(role.border, lineWidth: role == .plain ? 1 : 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(isChoiceLocked(question))
        .accessibilityLabel(accessibilityLabel(letter, role: role))
    }

    private func handleChoice(_ letter: String, question: WrongQuestion) {
        if submittedChoice == nil {
            selectedChoice = letter
            submit(question)
            return
        }
        guard question.correctChoice == nil, !revealed else { return }
        try? QuestionStore.setCorrectChoice(letter, question: question, in: modelContext)
        grade(picked: submittedChoice ?? letter, key: letter)
    }

    private func submit(_ question: WrongQuestion) {
        guard let selectedChoice else { return }
        submittedChoice = selectedChoice
        if let key = question.correctChoice {
            grade(picked: selectedChoice, key: key)
        }
    }

    private func grade(picked: String, key: String) {
        if picked == key {
            correctTicks += 1
        } else {
            wrongTicks += 1
        }
        withAnimation(.snappy) { revealed = true }
    }

    private func resultText(for question: WrongQuestion) -> String? {
        guard revealed, let picked = submittedChoice, let key = question.correctChoice else { return nil }
        return picked == key ? "选对了" : "正确答案是 \(key)"
    }

    private func isChoiceLocked(_ question: WrongQuestion) -> Bool {
        if submittedChoice == nil { return false }
        if question.correctChoice == nil, !revealed { return false }
        return true
    }

    private func choiceRole(_ letter: String, question: WrongQuestion) -> ChoiceRole {
        if revealed, let picked = submittedChoice, let key = question.correctChoice {
            if letter == key { return .correct }
            if letter == picked { return .incorrect }
            return .dimmed
        }
        if let submittedChoice, letter == submittedChoice { return .selected }
        if letter == selectedChoice { return .selected }
        return .plain
    }

    private func accessibilityLabel(_ letter: String, role: ChoiceRole) -> String {
        switch role {
        case .plain: "选项 \(letter)"
        case .selected: "选项 \(letter)，已选择"
        case .correct: "选项 \(letter)，正确答案"
        case .incorrect: "选项 \(letter)，选错了"
        case .dimmed: "选项 \(letter)"
        }
    }

    private func advance() {
        withAnimation(.snappy) {
            clearAttempt()
            guard order.indices.contains(index) else { return }
            order.remove(at: index)
            if index > order.count {
                index = order.count
            }
        }
    }

    private func postpone() {
        guard canPostpone, order.indices.contains(index) else { return }
        let id = order.remove(at: index)
        order.append(id)
        clearAttempt()
    }

    private func clearAttempt() {
        selectedChoice = nil
        submittedChoice = nil
        revealed = false
    }

    private func dropMissingCurrent() {
        guard !questions.isEmpty else { return }
        while order.indices.contains(index), current == nil {
            order.remove(at: index)
        }
    }
}

private enum ChoiceRole: Equatable {
    case plain
    case selected
    case correct
    case incorrect
    case dimmed

    var foreground: Color {
        switch self {
        case .plain, .dimmed: .primary
        case .selected: .primary
        case .correct: .green
        case .incorrect: .red
        }
    }

    var fill: Color {
        switch self {
        case .plain: Color.secondary.opacity(0.08)
        case .dimmed: Color.secondary.opacity(0.05)
        case .selected: Color.accentColor.opacity(0.16)
        case .correct: Color.green.opacity(0.16)
        case .incorrect: Color.red.opacity(0.14)
        }
    }

    var border: Color {
        switch self {
        case .plain, .dimmed: Color.secondary.opacity(0.35)
        case .selected: .accentColor
        case .correct: .green
        case .incorrect: .red
        }
    }
}
