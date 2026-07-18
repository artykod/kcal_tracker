import SwiftUI
import SwiftData

private enum PresetField: Hashable {
    case name
    case defaultGrams
    case calories
    case protein
    case fat
    case carbs
}

struct AddPresetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var presetToEdit: FoodPreset?
    var presetToCopy: FoodPreset?
    
    @State private var name: String
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var defaultGrams: String
    @State private var focusedField: PresetField?
    @FocusState private var nameFocused: Bool
    
    init(presetToEdit: FoodPreset? = nil, presetToCopy: FoodPreset? = nil, entryToCopy: CalorieEntry? = nil) {
        self.presetToEdit = presetToEdit
        self.presetToCopy = presetToCopy
        let source = presetToEdit ?? presetToCopy
        let initialName = presetToEdit?.name ?? entryToCopy?.name ?? ""
        _name = State(initialValue: initialName)

        if let entry = entryToCopy, let grams = entry.grams, grams > 0 {
            let caloriesPer100g = entry.caloriesPer100g ?? (Double(entry.calories) * 100 / grams)
            let proteinPer100g = entry.proteinPer100g ?? entry.protein.map { $0 * 100 / grams } ?? 0
            let carbsPer100g = entry.carbsPer100g ?? entry.carbs.map { $0 * 100 / grams } ?? 0
            let fatPer100g = entry.fatPer100g ?? entry.fat.map { $0 * 100 / grams } ?? 0

            _calories = State(initialValue: DecimalInput.format(caloriesPer100g))
            _protein = State(initialValue: DecimalInput.format(proteinPer100g))
            _carbs = State(initialValue: DecimalInput.format(carbsPer100g))
            _fat = State(initialValue: DecimalInput.format(fatPer100g))
            _defaultGrams = State(initialValue: DecimalInput.format(grams))
        } else {
            _calories = State(initialValue: source.map { DecimalInput.format($0.caloriesPer100g) } ?? "")
            _protein = State(initialValue: source.map { DecimalInput.format($0.proteinPer100g) } ?? "")
            _carbs = State(initialValue: source.map { DecimalInput.format($0.carbsPer100g) } ?? "")
            _fat = State(initialValue: source.map { DecimalInput.format($0.fatPer100g) } ?? "")
            _defaultGrams = State(initialValue: source?.defaultGrams.map { DecimalInput.format($0) } ?? "")
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    HStack(spacing: 12) {
                        TextField("Food name", text: $name)
                            .focused($nameFocused)
                            .submitLabel(.next)
                            .onSubmit {
                                nameFocused = false
                                focusedField = .defaultGrams
                            }

                        Divider()
                            .frame(height: 24)

                        HStack(spacing: 4) {
                            DecimalKeypadTextField(
                                "default",
                                text: $defaultGrams,
                                focus: focusBinding(for: .defaultGrams),
                                showsNext: true,
                                textAlignment: .right,
                                onNext: {
                                    focusedField = .calories
                                },
                                onDone: {
                                    focusedField = nil
                                }
                            )
                                .multilineTextAlignment(.trailing)
                                .frame(width: 58)
                                .accessibilityLabel("Default portion in grams, optional")
                            Text("g")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                        dimensions[.leading]
                    }

                    VStack(spacing: 7) {
                        HStack(alignment: .top, spacing: 8) {
                            nutritionField("kcal", text: $calories, field: .calories)
                            nutritionField("Protein", text: $protein, field: .protein)
                            nutritionField("Fat", text: $fat, field: .fat)
                            nutritionField("Carbs", text: $carbs, field: .carbs)
                        }

                        Text("Per 100g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                if let calculatedDetails {
                    Section("Calculated Totals") {
                        HStack {
                            Text("Default Portion")
                            Spacer()
                            Text("\(calculatedDetails.grams.formatted(.number.precision(.fractionLength(0...2)))) g")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            totalField("kcal", value: "\(calculatedDetails.calories)")
                            totalField("Protein", value: formattedMacro(calculatedDetails.protein))
                            totalField("Fat", value: formattedMacro(calculatedDetails.fat))
                            totalField("Carbs", value: formattedMacro(calculatedDetails.carbs))
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(presetToEdit != nil ? "Edit Food Preset" : "New Food Preset")
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

    private func nutritionField(
        _ title: String,
        text: Binding<String>,
        field: PresetField
    ) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            DecimalKeypadTextField(
                "0",
                text: text,
                focus: focusBinding(for: field),
                showsNext: field != .carbs,
                isBordered: true,
                textAlignment: .center,
                onNext: {
                    advanceFocus(after: field)
                },
                onDone: {
                    focusedField = nil
                }
            )
                .accessibilityLabel("\(title) per 100 grams")
        }
        .frame(maxWidth: .infinity)
    }

    private var calculatedDetails: (
        grams: Double,
        calories: Int,
        protein: Double,
        fat: Double,
        carbs: Double
    )? {
        guard let grams = DecimalInput.parse(defaultGrams), grams > 0,
              let calories = DecimalInput.parse(self.calories),
              let protein = DecimalInput.parse(self.protein),
              let fat = DecimalInput.parse(self.fat),
              let carbs = DecimalInput.parse(self.carbs) else { return nil }

        return (
            grams,
            Int(calories * grams / 100),
            protein * grams / 100,
            fat * grams / 100,
            carbs * grams / 100
        )
    }

    private func totalField(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedMacro(_ value: Double) -> String {
        String(format: "%.1fg", value)
    }

    private func focusBinding(for field: PresetField) -> Binding<Bool> {
        Binding(
            get: { focusedField == field },
            set: { isFocused in
                if isFocused {
                    focusedField = field
                } else if focusedField == field {
                    focusedField = nil
                }
            }
        )
    }

    private func advanceFocus(after field: PresetField) {
        switch field {
        case .name:
            focusedField = .defaultGrams
        case .defaultGrams:
            focusedField = .calories
        case .calories:
            focusedField = .protein
        case .protein:
            focusedField = .fat
        case .fat:
            focusedField = .carbs
        case .carbs:
            focusedField = nil
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty
            && DecimalInput.parse(calories) != nil
            && DecimalInput.parse(protein) != nil
            && DecimalInput.parse(carbs) != nil
            && DecimalInput.parse(fat) != nil
    }
    
    private func save() {
        guard let cal = DecimalInput.parse(calories),
              let p = DecimalInput.parse(protein),
              let c = DecimalInput.parse(carbs),
              let f = DecimalInput.parse(fat) else { return }
        
        let grams = DecimalInput.parse(defaultGrams)
        
        if let existing = presetToEdit {
            existing.name = name
            existing.caloriesPer100g = cal
            existing.proteinPer100g = p
            existing.carbsPer100g = c
            existing.fatPer100g = f
            existing.defaultGrams = grams
        } else {
            let preset = FoodPreset(name: name, caloriesPer100g: cal, proteinPer100g: p, carbsPer100g: c, fatPer100g: f, defaultGrams: grams)
            modelContext.insert(preset)
        }
        
        dismiss()
    }
}
