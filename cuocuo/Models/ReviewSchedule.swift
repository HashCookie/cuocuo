import Foundation

enum ReviewSchedule {
    /// 「还会」之后，隔这么多天再出现在「今天要看」里。
    static let againDays = 3

    static func isDue(mastery: Mastery, nextReviewAt: Date?, on day: Date = .now, calendar: Calendar = .current) -> Bool {
        guard mastery == .unmastered else { return false }
        guard let nextReviewAt else { return true }
        let startOfNextDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: day) ?? day)
        return nextReviewAt < startOfNextDay
    }

    static func dueQuestions(from questions: [WrongQuestion], on day: Date = .now, calendar: Calendar = .current) -> [WrongQuestion] {
        questions
            .filter { isDue(mastery: $0.mastery, nextReviewAt: $0.nextReviewAt, on: day, calendar: calendar) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static func nextUpcoming(from questions: [WrongQuestion], after day: Date = .now, calendar: Calendar = .current) -> Date? {
        let startOfNextDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: day) ?? day)
        return questions
            .filter { $0.mastery == .unmastered }
            .compactMap(\.nextReviewAt)
            .filter { $0 >= startOfNextDay }
            .min()
    }

    static func nextDate(after date: Date = .now, calendar: Calendar = .current) -> Date {
        let shifted = calendar.date(byAdding: .day, value: againDays, to: date) ?? date
        return calendar.startOfDay(for: shifted)
    }

    static func dayText(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .year()
                .month(.defaultDigits)
                .day()
                .locale(Locale(identifier: "zh_CN"))
        )
    }
}
