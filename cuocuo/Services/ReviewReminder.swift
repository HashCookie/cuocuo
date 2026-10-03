import Foundation
import SwiftData
import UserNotifications

enum ReviewReminder {
    static let enabledKey = "reviewReminderEnabled"
    static let hourKey = "reviewReminderHour"
    static let minuteKey = "reviewReminderMinute"
    private static let identifierPrefix = "cuocuo.review."

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var hour: Int {
        get {
            guard UserDefaults.standard.object(forKey: hourKey) != nil else { return 20 }
            return UserDefaults.standard.integer(forKey: hourKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: hourKey) }
    }

    static var minute: Int {
        get {
            guard UserDefaults.standard.object(forKey: minuteKey) != nil else { return 0 }
            return UserDefaults.standard.integer(forKey: minuteKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: minuteKey) }
    }

    static func refresh(in context: ModelContext) {
        let questions = (try? context.fetch(FetchDescriptor<WrongQuestion>())) ?? []
        let snapshots = questions.map {
            ReviewSnapshot(isUnmastered: $0.mastery == .unmastered, nextReviewAt: $0.nextReviewAt)
        }
        let enabled = isEnabled
        let hour = hour
        let minute = minute
        Task {
            await reschedule(snapshots, enabled: enabled, hour: hour, minute: minute)
        }
    }

    static func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if isAllowed(settings.authorizationStatus) { return true }
        guard settings.authorizationStatus == .notDetermined else { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    private static func isAllowed(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional:
            return true
        #if os(iOS)
        case .ephemeral:
            return true
        #endif
        default:
            return false
        }
    }

    private static func reschedule(
        _ snapshots: [ReviewSnapshot],
        enabled: Bool,
        hour: Int,
        minute: Int
    ) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let existing = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        let todayCount = dueCount(in: snapshots, on: .now)
        if enabled {
            try? await center.setBadgeCount(todayCount)
        } else {
            try? await center.setBadgeCount(0)
            return
        }

        let settings = await center.notificationSettings()
        guard isAllowed(settings.authorizationStatus) else { return }

        let calendar = Calendar.current
        let now = Date()
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            guard let fire = calendar.date(from: components), fire > now else { continue }
            let count = dueCount(in: snapshots, on: fire, calendar: calendar)
            guard count > 0 else { continue }
            let content = UNMutableNotificationContent()
            content.title = "错错"
            content.body = "还有 \(count) 道题要看"
            content.sound = .default
            content.badge = NSNumber(value: count)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + stamp(fire, calendar: calendar),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private static func dueCount(in snapshots: [ReviewSnapshot], on day: Date, calendar: Calendar = .current) -> Int {
        snapshots.filter {
            ReviewSchedule.isDue(
                mastery: $0.isUnmastered ? .unmastered : .mastered,
                nextReviewAt: $0.nextReviewAt,
                on: day,
                calendar: calendar
            )
        }.count
    }

    private static func stamp(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

private struct ReviewSnapshot: Sendable {
    var isUnmastered: Bool
    var nextReviewAt: Date?
}
