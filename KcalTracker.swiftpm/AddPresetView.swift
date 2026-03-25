import SwiftUI
import SwiftData

struct AddPresetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var defaultGrams: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Food Name", text: $name)
                }
                
                Section(header: Text("Nutritional Values (per 100g)")) {
                    TextField("Calories (kcal)", text: $calories)
                        .keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $protein)
                        .keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbs)
                        .keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat)
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Defaults (Optional)"), footer: Text("Default portion size in grams when adding this preset.")) {
                    TextField("Default Grams", text: $defaultGrams)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("New Preset")
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
    
    private var isValid: Bool {
        !name.isEmpty && Double(calories) != nil && Double(protein) != nil && Double(carbs) != nil && Double(fat) != nil
    }
    
    private func save() {
        guard let cal = Double(calories),
              let p = Double(protein),
              let c = Double(carbs),
              let f = Double(fat) else { return }
        
        let grams = Double(defaultGrams)
        let preset = FoodPreset(name: name, caloriesPer100g: cal, proteinPer100g: p, carbsPer100g: c, fatPer100g: f, defaultGrams: grams)
        modelContext.insert(preset)
        dismiss()
    }
}
