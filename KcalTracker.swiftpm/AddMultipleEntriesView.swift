import SwiftUI
import SwiftData

struct AddMultipleEntriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodPreset.name) private var presets: [FoodPreset]

    let date: Date
    let onEntriesAdded: (() -> Void)?

    @State private var searchText = ""
    @State private var selectedPresetIDs: Set<UUID> = []
    @State private var portionTextByPresetID: [UUID: String] = [:]
    @State private var time: Date
    @State private var focusedPresetID: UUID?

    init(date: Date, onEntriesAdded: (() -> Void)? = nil) {
        self.date = date
        self.onEntriesAdded = onEntriesAdded

        if Calendar.current.isDateInToday(date) {
            _time = State(initialValue: Date())
        } else {
            let startOfDay = Calendar.current.startOfDay(for: date)
            let midday = Calendar.current.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay
            _time = State(initialValue: midday)
        }
    }

    private var filteredPresets: [FoodPreset] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return presets }
        return presets.filter { $0.name.localizedStandardContains(query) }
    }

    private var selectedPresets: [FoodPreset] {
        presets.filter { selectedPresetIDs.contains($0.id) }
    }

    private var allSelectedPortionsAreValid: Bool {
        !selectedPresets.isEmpty && selectedPresets.allSatisfy { portion(for: $0) != nil }
    }

    private var totalCalories: Int {
        selectedPresets.reduce(0) { total, preset in
            guard let grams = portion(for: preset) else { return total }
            return total + Int(preset.caloriesPer100g * grams / 100)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if presets.isEmpty {
                    ContentUnavailableView(
                        "No Food Presets Yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Create food presets before adding multiple foods.")
                    )
                } else {
                    List {
                        Section {
                            if filteredPresets.isEmpty {
                                ContentUnavailableView.search(text: searchText)
                            } else {
                                ForEach(filteredPresets) { preset in
                                    presetRow(preset)
                                }
                            }
                        } header: {
                            HStack {
                                Text("Food Presets")
                                Spacer()
                                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            }
                        } footer: {
                            if !selectedPresets.isEmpty {
                                if allSelectedPortionsAreValid {
                                    Text("\(selectedPresets.count) \(selectedPresets.count == 1 ? "food" : "foods") · \(totalCalories) kcal")
                                } else {
                                    Text("Enter a portion for every selected food")
                                }
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Add Multiple Foods")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Food preset name")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedPresets.count)", action: addSelectedEntries)
                        .disabled(!allSelectedPortionsAreValid)
                        .accessibilityLabel(
                            "Add \(selectedPresets.count) \(selectedPresets.count == 1 ? "Food" : "Foods")"
                        )
                }
            }
        }
    }

    private func presetRow(_ preset: FoodPreset) -> some View {
        let isSelected = selectedPresetIDs.contains(preset.id)

        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    toggleSelection(of: preset)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(preset.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text("\(preset.caloriesPer100g.formatted(.number.precision(.fractionLength(0...1)))) kcal")
                            .fontWeight(.semibold)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    Button {
                        toggleSelection(of: preset)
                    } label: {
                        HStack(spacing: 12) {
                            MacroText(label: "Protein", value: preset.proteinPer100g)
                            MacroText(label: "Fat", value: preset.fatPer100g)
                            MacroText(label: "Carbs", value: preset.carbsPer100g)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 8)

                    ZStack(alignment: .trailing) {
                        if isSelected {
                            HStack(spacing: 4) {
                                DecimalKeypadTextField(
                                    "Required",
                                    text: portionBinding(for: preset),
                                    focus: focusBinding(for: preset.id),
                                    textAlignment: .right,
                                    textStyle: .caption1,
                                    onDone: { focusedPresetID = nil }
                                )
                                .multilineTextAlignment(.trailing)
                                .frame(width: 68, height: 18)

                                Text("g")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let grams = preset.defaultGrams, grams > 0 {
                            Text("\(grams.formatted(.number.precision(.fractionLength(0...2)))) g")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 88, height: 18, alignment: .trailing)
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                toggleSelection(of: preset)
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.orange : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(preset.name), \(isSelected ? "selected" : "not selected")")
        }
        .padding(.vertical, 4)
    }

    private func toggleSelection(of preset: FoodPreset) {
        if selectedPresetIDs.remove(preset.id) != nil {
            portionTextByPresetID[preset.id] = nil
            if focusedPresetID == preset.id {
                focusedPresetID = nil
            }
        } else {
            selectedPresetIDs.insert(preset.id)
            if let defaultGrams = preset.defaultGrams, defaultGrams > 0 {
                portionTextByPresetID[preset.id] = formatted(defaultGrams)
            } else {
                DispatchQueue.main.async {
                    guard selectedPresetIDs.contains(preset.id) else { return }
                    focusedPresetID = preset.id
                }
            }
        }
    }

    private func portionBinding(for preset: FoodPreset) -> Binding<String> {
        Binding(
            get: { portionTextByPresetID[preset.id, default: ""] },
            set: { portionTextByPresetID[preset.id] = DecimalInput.sanitize($0) }
        )
    }

    private func focusBinding(for presetID: UUID) -> Binding<Bool> {
        Binding(
            get: { focusedPresetID == presetID },
            set: { isFocused in
                if isFocused {
                    focusedPresetID = presetID
                } else if focusedPresetID == presetID {
                    focusedPresetID = nil
                }
            }
        )
    }

    private func portion(for preset: FoodPreset) -> Double? {
        guard let text = portionTextByPresetID[preset.id] else { return nil }
        guard let grams = DecimalInput.parse(text), grams > 0 else { return nil }
        return grams
    }

    private func formatted(_ value: Double) -> String {
        DecimalInput.format(value)
    }

    private func addSelectedEntries() {
        guard allSelectedPortionsAreValid else { return }

        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        var finalComponents = DateComponents()
        finalComponents.year = dayComponents.year
        finalComponents.month = dayComponents.month
        finalComponents.day = dayComponents.day
        finalComponents.hour = timeComponents.hour
        finalComponents.minute = timeComponents.minute
        finalComponents.second = timeComponents.second
        let entryDate = calendar.date(from: finalComponents) ?? date

        for preset in selectedPresets {
            guard let grams = portion(for: preset) else { continue }
            modelContext.insert(
                CalorieEntry(
                    name: preset.name,
                    calories: Int(preset.caloriesPer100g * grams / 100),
                    protein: preset.proteinPer100g * grams / 100,
                    carbs: preset.carbsPer100g * grams / 100,
                    fat: preset.fatPer100g * grams / 100,
                    grams: grams,
                    caloriesPer100g: preset.caloriesPer100g,
                    proteinPer100g: preset.proteinPer100g,
                    carbsPer100g: preset.carbsPer100g,
                    fatPer100g: preset.fatPer100g,
                    date: entryDate
                )
            )
        }

        onEntriesAdded?()
        dismiss()
    }
}
