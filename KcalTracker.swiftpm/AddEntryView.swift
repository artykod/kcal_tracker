import SwiftUI
import SwiftData

private func parseDouble(_ s: String) -> Double? {
    let normalized = s.replacingOccurrences(of: Locale.current.decimalSeparator ?? ",", with: ".")
    return Double(normalized)
}

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodPreset.name) private var presets: [FoodPreset]
    
    var date: Date
    
    @State private var time: Date
    @State private var usePreset = true
    @State private var selectedPreset: FoodPreset?
    
    // Manual or Preset values
    @State private var name: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var grams: String = ""
    
    init(date: Date) {
        self.date = date
        if Calendar.current.isDateInToday(date) {
            _time = State(initialValue: Date())
        } else {
            let startOfDay = Calendar.current.startOfDay(for: date)
            let midday = Calendar.current.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay
            _time = State(initialValue: midday)
        }
    }
    
    var computedCalories: Int {
        if !grams.isEmpty {
            guard let cal100 = parseDouble(calories), let g = parseDouble(grams) else { return 0 }
            return Int((cal100 * g) / 100.0)
        }
        return Int(parseDouble(calories) ?? 0)
    }
    
    var computedProtein: Double {
        guard let p = parseDouble(protein), let g = parseDouble(grams) else { return 0 }
        return (p * g) / 100.0
    }
    var computedCarbs: Double {
        guard let c = parseDouble(carbs), let g = parseDouble(grams) else { return 0 }
        return (c * g) / 100.0
    }
    var computedFat: Double {
        guard let f = parseDouble(fat), let g = parseDouble(grams) else { return 0 }
        return (f * g) / 100.0
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use Food Preset", isOn: $usePreset)
                    
                    if usePreset {
                        Picker("Preset", selection: $selectedPreset) {
                            Text("Select Preset").tag(FoodPreset?.none)
                            ForEach(presets) { preset in
                                Text(preset.name).tag(preset as FoodPreset?)
                            }
                        }
                        .onChange(of: selectedPreset) { _, newValue in
                            applyPreset(newValue)
                        }
                    }
                }
                
                Section(header: Text(usePreset ? "Preset Details (per 100g)" : "Details")) {
                    TextField("Food name", text: $name)
                    
                    TextField("Calories per 100g", text: $calories)
                        .keyboardType(.decimalPad)
                    
                    if usePreset {
                        TextField("Protein per 100g", text: $protein)
                            .keyboardType(.decimalPad)
                        TextField("Carbs per 100g", text: $carbs)
                            .keyboardType(.decimalPad)
                        TextField("Fat per 100g", text: $fat)
                            .keyboardType(.decimalPad)
                    }
                    
                    TextField("Portion (grams)", text: $grams)
                        .keyboardType(.decimalPad)
                    
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }
                
                Section(header: Text("Calculated Totals")) {
                    HStack { Text("Calories"); Spacer(); Text("\(computedCalories) kcal") }
                    if usePreset {
                        HStack { Text("Protein"); Spacer(); Text(String(format: "%.1fg", computedProtein)) }
                        HStack { Text("Carbs"); Spacer(); Text(String(format: "%.1fg", computedCarbs)) }
                        HStack { Text("Fat"); Spacer(); Text(String(format: "%.1fg", computedFat)) }
                    }
                }
            }
            .navigationTitle("Add Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }
    
    private func applyPreset(_ preset: FoodPreset?) {
        guard let p = preset else {
            name = ""
            calories = ""
            protein = ""
            carbs = ""
            fat = ""
            grams = ""
            return
        }
        let fmt = NumberFormatter()
        fmt.locale = Locale.current
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 10
        fmt.groupingSeparator = ""
        func str(_ v: Double) -> String { fmt.string(from: NSNumber(value: v)) ?? "\(v)" }
        name = p.name
        calories = str(p.caloriesPer100g)
        protein = str(p.proteinPer100g)
        carbs = str(p.carbsPer100g)
        fat = str(p.fatPer100g)
        if let defaultG = p.defaultGrams {
            grams = str(defaultG)
        }
    }
    
    private var isValid: Bool {
        if name.isEmpty { return false }
        return computedCalories > 0 && parseDouble(grams) != nil
    }
    
    private func save() {
        if !isValid { return }
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        
        var finalComponents = DateComponents()
        finalComponents.year = dateComponents.year
        finalComponents.month = dateComponents.month
        finalComponents.day = dateComponents.day
        finalComponents.hour = timeComponents.hour
        finalComponents.minute = timeComponents.minute
        finalComponents.second = timeComponents.second
        
        let finalDate = calendar.date(from: finalComponents) ?? Date()
        
        let newEntry: CalorieEntry
        if usePreset {
            newEntry = CalorieEntry(
                name: name,
                calories: computedCalories,
                protein: computedProtein,
                carbs: computedCarbs,
                fat: computedFat,
                grams: parseDouble(grams),
                date: finalDate
            )
        } else {
            newEntry = CalorieEntry(
                name: name,
                calories: computedCalories,
                grams: parseDouble(grams),
                date: finalDate
            )
        }
        
        modelContext.insert(newEntry)
        dismiss()
    }
}
