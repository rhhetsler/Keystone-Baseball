import SwiftUI
import SwiftData

@main
struct MileageTrackerApp: App {
    private let container: ModelContainer = {
        let schema = Schema([MileageRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MileageRootView()
        }
        .modelContainer(container)
    }
}
