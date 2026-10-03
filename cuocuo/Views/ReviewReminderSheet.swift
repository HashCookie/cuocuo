import SwiftData
import SwiftUI

struct ReviewReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var enabled = ReviewReminder.isEnabled
    @State private var time = ReviewReminder.storedTime
    @State private var denied = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("每天提醒", isOn: $enabled.animation())
                    if enabled {
                        DatePicker("时间", selection: $time, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("到点时如果还有题要看，会提醒一次。没有要看的那天不响。")
                }
                if denied {
                    Section {
                        Text("通知没有打开。可以到系统设置里允许通知，今天要看的题仍会留在首页。")
                        Button("前往设置") {
                            CaptureAvailability.openSystemSettings()
                        }
                    }
                }
            }
            .navigationTitle("复习提醒")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { Task { await save() } }
                        .disabled(isSaving)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        if enabled {
            let allowed = await ReviewReminder.ensureAuthorization()
            if !allowed {
                enabled = false
                denied = true
                ReviewReminder.isEnabled = false
                ReviewReminder.refresh(in: modelContext)
                return
            }
        }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
        ReviewReminder.isEnabled = enabled
        ReviewReminder.hour = parts.hour ?? 20
        ReviewReminder.minute = parts.minute ?? 0
        ReviewReminder.refresh(in: modelContext)
        dismiss()
    }
}

extension ReviewReminder {
    static var storedTime: Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }
}
