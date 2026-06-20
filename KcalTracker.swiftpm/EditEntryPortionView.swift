import SwiftUI

struct EditEntryPortionView: View {
    @Environment(\.dismiss) private var dismiss

    let entry: CalorieEntry
    @State private var grams: String
    @State private var time: Date

    init(entry: CalorieEntry) {
        self.entry = entry

        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.groupingSeparator = ""
        _grams = State(initialValue: entry.grams.flatMap { formatter.string(from: NSNumber(value: $0)) } ?? "")
        _time = State(initialValue: entry.date)
    }

    private var parsedGrams: Double? {
        let normalized = grams.replacingOccurrences(of: Locale.current.decimalSeparator ?? ",", with: ".")
        return Double(normalized)
    }

    private var canRecalculate: Bool {
        guard let currentGrams = entry.grams, currentGrams > 0,
              let newGrams = parsedGrams, newGrams > 0 else { return false }
        return true
    }

    private var hasOriginalPortion: Bool {
        guard let currentGrams = entry.grams else { return false }
        return currentGrams > 0
    }

    private var isValid: Bool {
        !hasOriginalPortion || canRecalculate
    }

    private var calorieRate: Double? {
        guard let currentGrams = entry.grams, currentGrams > 0 else { return nil }
        return entry.caloriesPer100g ?? (Double(entry.calories) * 100 / currentGrams)
    }

    private func recalculated(_ currentValue: Double?, rate: Double?) -> Double? {
        guard currentValue != nil, let newGrams = parsedGrams else { return nil }
        let resolvedRate = rate ?? entry.grams.flatMap { currentGrams in
            currentGrams > 0 ? currentValue.map { $0 * 100 / currentGrams } : nil
        }
        return resolvedRate.map { $0 * newGrams / 100 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Entry") {
                    LabeledContent("Food", value: entry.name)
                    LabeledContent("Current calories", value: "\(entry.calories) kcal")
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }

                Section {
                    TextField("Grams", text: $grams)
                        .keyboardType(.decimalPad)
                        .disabled(!hasOriginalPortion)
                } header: {
                    Text("Portion")
                } footer: {
                    if entry.grams == nil || entry.grams == 0 {
                        Text("This entry has no original portion, so its nutritional values cannot be recalculated.")
                    } else {
                        Text("Calories and macros will be recalculated for the new portion.")
                    }
                }

                if canRecalculate, let newGrams = parsedGrams, let calorieRate {
                    Section("Calculated Totals") {
                        LabeledContent("Calories", value: "\(Int(calorieRate * newGrams / 100)) kcal")
                        if let protein = recalculated(entry.protein, rate: entry.proteinPer100g) {
                            LabeledContent("Protein", value: String(format: "%.1f g", protein))
                        }
                        if let carbs = recalculated(entry.carbs, rate: entry.carbsPer100g) {
                            LabeledContent("Carbs", value: String(format: "%.1f g", carbs))
                        }
                        if let fat = recalculated(entry.fat, rate: entry.fatPer100g) {
                            LabeledContent("Fat", value: String(format: "%.1f g", fat))
                        }
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if hasOriginalPortion, let newGrams = parsedGrams {
                            entry.updatePortion(to: newGrams)
                        }
                        updateEntryTime()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func updateEntryTime() {
        let calendar = Calendar.current
        let day = calendar.dateComponents([.year, .month, .day], from: entry.date)
        let selectedTime = calendar.dateComponents([.hour, .minute], from: time)

        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = selectedTime.hour
        components.minute = selectedTime.minute
        components.second = 0

        if let updatedDate = calendar.date(from: components) {
            entry.date = updatedDate
        }
    }
}
