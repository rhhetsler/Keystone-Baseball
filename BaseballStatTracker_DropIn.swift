import SwiftUI
import SwiftData

@main
struct BaseballStatTrackerApp: App {

    private let container: ModelContainer = {
        let schema = Schema([SavedGame.self, MileageRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Baseball", systemImage: "baseball.fill") }
                MileageRootView()
                    .tabItem { Label("Mileage", systemImage: "car.fill") }
            }
        }
        .modelContainer(container)
    }
}
