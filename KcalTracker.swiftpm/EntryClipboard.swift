import Foundation

struct CopiedEntry {
    var name: String
    var calories: Int
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var grams: Double?
    var caloriesPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
}

@MainActor
final class EntryClipboard: ObservableObject {
    @Published private(set) var copiedEntry: CopiedEntry?
    private var expirationTask: Task<Void, Never>?

    func copy(_ entry: CalorieEntry) {
        copiedEntry = CopiedEntry(
            name: entry.name,
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
            grams: entry.grams,
            caloriesPer100g: entry.caloriesPer100g,
            proteinPer100g: entry.proteinPer100g,
            carbsPer100g: entry.carbsPer100g,
            fatPer100g: entry.fatPer100g
        )

        expirationTask?.cancel()
        expirationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(600))
                guard !Task.isCancelled else { return }
                self?.copiedEntry = nil
            } catch {
                // A newer copied entry replaced this expiration timer.
            }
        }
    }
}
