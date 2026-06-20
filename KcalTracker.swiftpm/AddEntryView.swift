import SwiftUI
import SwiftData

private func parseDouble(_ s: String) -> Double? {
    let normalized = s.replacingOccurrences(of: Locale.current.decimalSeparator ?? ",", with: ".")
    return Double(normalized)
}

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var date: Date
    
    @State private var time: Date
    @State private var selectedPreset: FoodPreset?
    @State private var showingPresetSelector = false
    
    // Manual or Preset values
    @State private var name: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var grams: String = ""
    @State private var servingCount = 1
    @State private var draftServingCount = 1
    @State private var showingServingPicker = false
    
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
        guard let cal100 = parseDouble(calories), let totalGrams else { return 0 }
        return Int((cal100 * totalGrams) / 100.0)
    }
    
    var computedProtein: Double {
        guard let p = parseDouble(protein), let totalGrams else { return 0 }
        return (p * totalGrams) / 100.0
    }
    var computedCarbs: Double {
        guard let c = parseDouble(carbs), let totalGrams else { return 0 }
        return (c * totalGrams) / 100.0
    }
    var computedFat: Double {
        guard let f = parseDouble(fat), let totalGrams else { return 0 }
        return (f * totalGrams) / 100.0
    }

    var totalGrams: Double? {
        guard let portionGrams = parseDouble(grams), portionGrams > 0 else { return nil }
        return portionGrams * Double(servingCount)
    }

    var finalEntryName: String {
        servingCount == 1 ? name : "\(name) ×\(servingCount)"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Food Preset (Optional)") {
                    Button {
                        showingPresetSelector = true
                    } label: {
                        HStack {
                            Text("Preset")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(selectedPreset?.name ?? "No Preset")
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: selectedPreset) { _, newValue in
                        applyPreset(newValue)
                    }
                }
                
                Section {
                    TextField("Food name", text: $name)
                    
                    TextField("Calories per 100g", text: $calories)
                        .keyboardType(.decimalPad)
                    
                    TextField("Protein (optional)", text: $protein)
                        .keyboardType(.decimalPad)
                    TextField("Carbs (optional)", text: $carbs)
                        .keyboardType(.decimalPad)
                    TextField("Fat (optional)", text: $fat)
                        .keyboardType(.decimalPad)
                    
                    TextField("Portion (grams)", text: $grams)
                        .keyboardType(.decimalPad)

                    Button {
                        draftServingCount = servingCount
                        showingServingPicker = true
                    } label: {
                        HStack {
                            Text("Number of Servings")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(servingCount)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Details (per 100g)")
                } footer: {
                    Text("Servings is a multiplier. For example, a 150 g portion with 2 servings adds 300 g and doubles calories and macros.")
                }
                
                Section(header: Text("Calculated Totals")) {
                    if let totalGrams {
                        HStack {
                            Text("Total Portion")
                            Spacer()
                            Text("\(totalGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                        }
                    }
                    HStack { Text("Calories"); Spacer(); Text("\(computedCalories) kcal") }
                    if parseDouble(protein) != nil {
                        HStack { Text("Protein"); Spacer(); Text(String(format: "%.1fg", computedProtein)) }
                    }
                    if parseDouble(carbs) != nil {
                        HStack { Text("Carbs"); Spacer(); Text(String(format: "%.1fg", computedCarbs)) }
                    }
                    if parseDouble(fat) != nil {
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
            .sheet(isPresented: $showingServingPicker) {
                NavigationStack {
                    Picker("Number of Servings", selection: $draftServingCount) {
                        ForEach(1...10, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .navigationTitle("Number of Servings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingServingPicker = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                servingCount = draftServingCount
                                showingServingPicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.height(300)])
            }
            .sheet(isPresented: $showingPresetSelector) {
                PresetSelectionView(selectedPreset: $selectedPreset)
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
            servingCount = 1
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
        return computedCalories > 0 && totalGrams != nil
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
        
        let newEntry = CalorieEntry(
            name: finalEntryName,
            calories: computedCalories,
            protein: parseDouble(protein) == nil ? nil : computedProtein,
            carbs: parseDouble(carbs) == nil ? nil : computedCarbs,
            fat: parseDouble(fat) == nil ? nil : computedFat,
            grams: totalGrams,
            caloriesPer100g: parseDouble(calories),
            proteinPer100g: parseDouble(protein),
            carbsPer100g: parseDouble(carbs),
            fatPer100g: parseDouble(fat),
            date: finalDate
        )
        
        modelContext.insert(newEntry)
        dismiss()
    }
}
