import SwiftData
import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(AppStore.container)
    }
}

@MainActor
enum AppStore {
    static let container: ModelContainer = {
        do {
            let schema = Schema([WrongQuestion.self, ScanPage.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("无法打开错题库：\(error)")
        }
    }()
}
