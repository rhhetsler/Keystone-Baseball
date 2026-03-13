import SwiftUI
import SwiftData

@main
struct BaseballStatTrackerApp: App {

    // ✅ Explicit persistent container (NOT in-memory)
    private let container: ModelContainer = {
        let schema = Schema([SavedGame.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
