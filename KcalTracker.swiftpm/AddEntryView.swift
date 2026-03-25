import SwiftUI
import SwiftData

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
            guard let cal100 = Double(calories), let g = Double(grams) else { return 0 }
            return Int((cal100 * g) / 100.0)
        }
        return Int(calories) ?? 0
    }
    
    var computedProtein: Double {
        guard let p = Double(protein), let g = Double(grams) else { return 0 }
        return (p * g) / 100.0
    }
    var computedCarbs: Double {
        guard let c = Double(carbs), let g = Double(grams) else { return 0 }
        return (c * g) / 100.0
    }
    var computedFat: Double {
        guard let f = Double(fat), let g = Double(grams) else { return 0 }
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
        name = p.name
        calories = String(format: "%g", p.caloriesPer100g)
        protein = String(format: "%g", p.proteinPer100g)
        carbs = String(format: "%g", p.carbsPer100g)
        fat = String(format: "%g", p.fatPer100g)
        if let defaultG = p.defaultGrams {
            grams = String(format: "%g", defaultG)
        }
    }
    
    private var isValid: Bool {
        if name.isEmpty { return false }
        return computedCalories > 0 && Double(grams) != nil
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
                grams: Double(grams),
                date: finalDate
            )
        } else {
            newEntry = CalorieEntry(
                name: name,
                calories: computedCalories,
                grams: Double(grams),
                date: finalDate
            )
        }
        
        modelContext.insert(newEntry)
        dismiss()
    }
}
