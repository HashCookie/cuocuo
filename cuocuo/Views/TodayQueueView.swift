import SwiftData
import SwiftUI

struct ReviewLaunch: Identifiable {
    let id = UUID()
    let questionIDs: [UUID]
}

struct TodayQueueView: View {
    @Query private var questions: [WrongQuestion]
    @State private var reviewLaunch: ReviewLaunch?
    @State private var showingReminder = false
    @State private var pendingDelete: WrongQuestion?
    @AppStorage(ReviewReminder.enabledKey) private var reminderEnabled = false

    var body: some View {
        Group {
            if due.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: emptySymbol)
                } description: {
                    Text(emptyMessage)
                }
            } else {
                List {
                    Section {
                        ForEach(due) { question in
                            NavigationLink {
                                QuestionDetailView(question: question)
                            } label: {
                                QuestionRowLabel(question: question, showsModule: true)
                            }
                            .modifier(QuestionItemActions(question: question, onDeleteRequested: {
                                pendingDelete = question
                            }))
                        }
                    } footer: {
                        Text("点「开始看」。做完再决定还会还是已经会了。")
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    startBar
                }
            }
        }
        .navigationTitle("今天要看")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingReminder = true
                } label: {
                    Label("提醒", systemImage: reminderEnabled ? "bell.fill" : "bell")
                }
            }
        }
        .sheet(isPresented: $showingReminder) {
            ReviewReminderSheet()
        }
        .adaptiveCover(item: $reviewLaunch) { launch in
            ReviewSessionView(questionIDs: launch.questionIDs)
        }
        .deleteQuestionDialog(pending: $pendingDelete)
    }

    private var due: [WrongQuestion] {
        ReviewSchedule.dueQuestions(from: Array(questions))
    }

    private var emptyTitle: String {
        questions.isEmpty ? "还没有要看的题" : "今天没有要看的题"
    }

    private var emptySymbol: String {
        questions.isEmpty ? "calendar" : "checkmark.circle"
    }

    private var emptyMessage: String {
        if questions.isEmpty {
            return "收录一道错题后，它会排进今天要看。"
        }
        if let next = ReviewSchedule.nextUpcoming(from: Array(questions)) {
            return "下一题在 \(ReviewSchedule.dayText(next))。"
        }
        return "未掌握的题都看过了。"
    }

    private var startBar: some View {
        Button {
            reviewLaunch = ReviewLaunch(questionIDs: due.map(\.id))
        } label: {
            Text("开始看")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding()
        .background(.bar)
    }
}
