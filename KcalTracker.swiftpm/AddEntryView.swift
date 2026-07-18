import SwiftUI
import SwiftData

private enum AddEntryField: Hashable {
    case name
    case grams
    case calories
    case protein
    case fat
    case carbs
}

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var date: Date
    
    @State private var time: Date
    @State private var selectedPreset: FoodPreset?
    @State private var showingPresetSelector = false
    @State private var showingMultipleSelector = false
    @State private var multipleEntriesWereAdded = false
    
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
    @State private var focusedField: AddEntryField?
    @FocusState private var nameFocused: Bool
    
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
        guard let cal100 = DecimalInput.parse(calories), let totalGrams else { return 0 }
        return Int((cal100 * totalGrams) / 100.0)
    }
    
    var computedProtein: Double {
        guard let p = DecimalInput.parse(protein), let totalGrams else { return 0 }
        return (p * totalGrams) / 100.0
    }
    var computedCarbs: Double {
        guard let c = DecimalInput.parse(carbs), let totalGrams else { return 0 }
        return (c * totalGrams) / 100.0
    }
    var computedFat: Double {
        guard let f = DecimalInput.parse(fat), let totalGrams else { return 0 }
        return (f * totalGrams) / 100.0
    }

    var totalGrams: Double? {
        guard let portionGrams = DecimalInput.parse(grams), portionGrams > 0 else { return nil }
        return portionGrams * Double(servingCount)
    }

    var finalEntryName: String {
        servingCount == 1 ? name : "\(name) ×\(servingCount)"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingPresetSelector = true
                    } label: {
                        HStack {
                            Text("Food preset (optional)")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(selectedPreset?.name ?? "None")
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                }
                .onChange(of: selectedPreset) { _, newValue in
                    applyPreset(newValue)
                }
                
                Section {
                    HStack(spacing: 12) {
                        TextField("Food name", text: $name)
                            .focused($nameFocused)
                            .submitLabel(.next)
                            .onSubmit {
                                nameFocused = false
                                focusedField = .grams
                            }

                        Divider()
                            .frame(height: 24)

                        HStack(spacing: 4) {
                            DecimalKeypadTextField(
                                "grams",
                                text: $grams,
                                focus: focusBinding(for: .grams),
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
                                .accessibilityLabel("Portion in grams")
                            Text("g")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }

                        Divider()
                            .frame(height: 24)

                        Button {
                            draftServingCount = servingCount
                            showingServingPicker = true
                        } label: {
                            HStack(spacing: 5) {
                                Text("×\(servingCount)")
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(minWidth: 44, minHeight: 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Number of servings")
                        .accessibilityValue("\(servingCount)")
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                        dimensions[.leading]
                    }

                    VStack(spacing: 7) {
                        HStack(alignment: .top, spacing: 8) {
                            nutritionField("kcal", text: $calories, field: .calories, isRequired: true)
                            nutritionField("Protein", text: $protein, field: .protein)
                            nutritionField("Fat", text: $fat, field: .fat)
                            nutritionField("Carbs", text: $carbs, field: .carbs)
                        }

                        Text("Per 100g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } header: {
                    HStack {
                        Text("Details")
                        Spacer()
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                }
                
                Section(header: Text("Calculated Totals")) {
                    if let totalGrams {
                        HStack {
                            Text("Total Portion")
                            Spacer()
                            Text("\(totalGrams.formatted(.number.precision(.fractionLength(0...2)))) g")
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        totalField("kcal", value: "\(computedCalories)")
                        totalField("Protein", value: formattedMacro(computedProtein, source: protein))
                        totalField("Fat", value: formattedMacro(computedFat, source: fat))
                        totalField("Carbs", value: formattedMacro(computedCarbs, source: carbs))
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Button {
                    multipleEntriesWereAdded = false
                    showingMultipleSelector = true
                } label: {
                    Label("Add Multiple Foods", systemImage: "checklist")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(.separator.opacity(0.35), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
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
            .sheet(isPresented: $showingMultipleSelector, onDismiss: {
                if multipleEntriesWereAdded {
                    dismiss()
                }
            }) {
                AddMultipleEntriesView(date: date) {
                    multipleEntriesWereAdded = true
                }
            }
        }
    }

    private func nutritionField(
        _ title: String,
        text: Binding<String>,
        field: AddEntryField,
        isRequired: Bool = false
    ) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            DecimalKeypadTextField(
                isRequired ? "0" : "—",
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
                .accessibilityLabel("\(title) per 100 grams\(isRequired ? "" : ", optional")")
        }
        .frame(maxWidth: .infinity)
    }

    private func focusBinding(for field: AddEntryField) -> Binding<Bool> {
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

    private func advanceFocus(after field: AddEntryField) {
        switch field {
        case .name:
            focusedField = .grams
        case .grams:
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

    private func formattedMacro(_ value: Double, source: String) -> String {
        DecimalInput.parse(source) == nil ? "—" : String(format: "%.1fg", value)
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
            protein: DecimalInput.parse(protein) == nil ? nil : computedProtein,
            carbs: DecimalInput.parse(carbs) == nil ? nil : computedCarbs,
            fat: DecimalInput.parse(fat) == nil ? nil : computedFat,
            grams: totalGrams,
            caloriesPer100g: DecimalInput.parse(calories),
            proteinPer100g: DecimalInput.parse(protein),
            carbsPer100g: DecimalInput.parse(carbs),
            fatPer100g: DecimalInput.parse(fat),
            date: finalDate
        )
        
        modelContext.insert(newEntry)
        dismiss()
    }
}
