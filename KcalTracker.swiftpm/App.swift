import SwiftUI
import SwiftData

@main
struct KcalTrackerApp: App {
    @StateObject private var entryClipboard = EntryClipboard()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CalorieEntry.self,
            FoodPreset.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(entryClipboard)
        }
        .modelContainer(sharedModelContainer)
    }
}
