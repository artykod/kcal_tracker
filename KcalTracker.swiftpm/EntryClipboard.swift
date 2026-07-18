import Foundation

struct CopiedEntry: Identifiable {
    let id: UUID
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
    let copiedAt: Date
}

@MainActor
final class EntryClipboard: ObservableObject {
    private static let entryLifetime: TimeInterval = 600

    @Published private(set) var entries: [CopiedEntry] = []
    private var expirationTask: Task<Void, Never>?

    var copiedEntry: CopiedEntry? {
        entries.first
    }

    func copy(_ entry: CalorieEntry) {
        removeExpiredEntries()

        entries.insert(CopiedEntry(
            id: UUID(),
            name: entry.name,
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
            grams: entry.grams,
            caloriesPer100g: entry.caloriesPer100g,
            proteinPer100g: entry.proteinPer100g,
            carbsPer100g: entry.carbsPer100g,
            fatPer100g: entry.fatPer100g,
            copiedAt: Date()
        ), at: 0)

        scheduleExpiration()
    }

    func remove(_ copiedEntry: CopiedEntry) {
        entries.removeAll { $0.id == copiedEntry.id }
        scheduleExpiration()
    }

    func clear() {
        expirationTask?.cancel()
        expirationTask = nil
        entries.removeAll()
    }

    private func removeExpiredEntries(now: Date = Date()) {
        entries.removeAll { copiedEntry in
            now.timeIntervalSince(copiedEntry.copiedAt) >= Self.entryLifetime
        }
    }

    private func scheduleExpiration() {
        expirationTask?.cancel()
        guard let oldestEntry = entries.last else { return }

        let expirationDate = oldestEntry.copiedAt.addingTimeInterval(Self.entryLifetime)
        let delay = max(expirationDate.timeIntervalSinceNow, 0)

        expirationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.removeExpiredEntries()
                self?.scheduleExpiration()
            } catch {
                // Copying a newer food rescheduled the expiration timer.
            }
        }
    }
}
