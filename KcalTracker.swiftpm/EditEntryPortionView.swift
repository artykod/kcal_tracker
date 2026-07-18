import SwiftUI

private enum EditEntryField: Hashable {
    case grams
    case calories
    case protein
    case fat
    case carbs
}

struct EditEntryPortionView: View {
    @Environment(\.dismiss) private var dismiss

    let entry: CalorieEntry

    @State private var grams: String
    @State private var time: Date
    @State private var calories: String
    @State private var protein: String
    @State private var fat: String
    @State private var carbs: String
    @State private var focusedField: EditEntryField?

    init(entry: CalorieEntry) {
        self.entry = entry
        _grams = State(initialValue: entry.grams.map { DecimalInput.format($0) } ?? "")
        _time = State(initialValue: entry.date)

        if let grams = entry.grams, grams > 0 {
            let caloriesPer100g = entry.caloriesPer100g ?? (Double(entry.calories) * 100 / grams)
            let proteinPer100g = entry.proteinPer100g ?? entry.protein.map { $0 * 100 / grams }
            let fatPer100g = entry.fatPer100g ?? entry.fat.map { $0 * 100 / grams }
            let carbsPer100g = entry.carbsPer100g ?? entry.carbs.map { $0 * 100 / grams }

            _calories = State(initialValue: DecimalInput.format(caloriesPer100g))
            _protein = State(initialValue: proteinPer100g.map { DecimalInput.format($0) } ?? "")
            _fat = State(initialValue: fatPer100g.map { DecimalInput.format($0) } ?? "")
            _carbs = State(initialValue: carbsPer100g.map { DecimalInput.format($0) } ?? "")
        } else {
            _calories = State(initialValue: DecimalInput.format(Double(entry.calories)))
            _protein = State(initialValue: entry.protein.map { DecimalInput.format($0) } ?? "")
            _fat = State(initialValue: entry.fat.map { DecimalInput.format($0) } ?? "")
            _carbs = State(initialValue: entry.carbs.map { DecimalInput.format($0) } ?? "")
        }
    }

    private var hasOriginalPortion: Bool {
        guard let grams = entry.grams else { return false }
        return grams > 0
    }

    private var parsedGrams: Double? {
        DecimalInput.parse(grams)
    }

    private var nutritionIsValid: Bool {
        guard let calories = DecimalInput.parse(self.calories), calories > 0 else { return false }
        return [self.protein, self.fat, self.carbs].allSatisfy { value in
            value.isEmpty || DecimalInput.parse(value) != nil
        }
    }

    private var isValid: Bool {
        guard nutritionIsValid else { return false }
        if hasOriginalPortion {
            guard let grams = parsedGrams else { return false }
            return grams > 0
        }
        return true
    }

    private var calculatedTotals: (
        calories: Int,
        protein: Double?,
        fat: Double?,
        carbs: Double?
    )? {
        guard let calories = DecimalInput.parse(self.calories), calories > 0 else { return nil }
        let protein = DecimalInput.parse(self.protein)
        let fat = DecimalInput.parse(self.fat)
        let carbs = DecimalInput.parse(self.carbs)

        if hasOriginalPortion {
            guard let grams = parsedGrams, grams > 0 else { return nil }
            let multiplier = grams / 100
            return (
                Int(calories * multiplier),
                protein.map { $0 * multiplier },
                fat.map { $0 * multiplier },
                carbs.map { $0 * multiplier }
            )
        }

        return (Int(calories), protein, fat, carbs)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Text(entry.name)
                            .lineLimit(1)

                        Spacer()

                        Divider()
                            .frame(height: 24)

                        HStack(spacing: 4) {
                            DecimalKeypadTextField(
                                "grams",
                                text: $grams,
                                focus: focusBinding(for: .grams),
                                showsNext: hasOriginalPortion,
                                textAlignment: .right,
                                onNext: {
                                    focusedField = .calories
                                },
                                onDone: {
                                    focusedField = nil
                                }
                            )
                                .frame(width: 64)
                                .disabled(!hasOriginalPortion)
                                .accessibilityLabel("Portion in grams")
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
                            nutritionField("kcal", text: $calories, field: .calories, isRequired: true)
                            nutritionField("Protein", text: $protein, field: .protein)
                            nutritionField("Fat", text: $fat, field: .fat)
                            nutritionField("Carbs", text: $carbs, field: .carbs)
                        }

                        Text(hasOriginalPortion ? "Per 100g" : "Food totals")
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
                } footer: {
                    if !hasOriginalPortion {
                        Text("This food has no original portion, so nutrition values are edited as food totals.")
                    }
                }

                if let calculatedTotals {
                    Section(hasOriginalPortion ? "Calculated Totals" : "Food Totals") {
                        HStack(alignment: .top, spacing: 8) {
                            totalField("kcal", value: "\(calculatedTotals.calories)")
                            totalField("Protein", value: formattedMacro(calculatedTotals.protein))
                            totalField("Fat", value: formattedMacro(calculatedTotals.fat))
                            totalField("Carbs", value: formattedMacro(calculatedTotals.carbs))
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func nutritionField(
        _ title: String,
        text: Binding<String>,
        field: EditEntryField,
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
                .accessibilityLabel("\(title)\(hasOriginalPortion ? " per 100 grams" : " food total")")
        }
        .frame(maxWidth: .infinity)
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

    private func formattedMacro(_ value: Double?) -> String {
        value.map { String(format: "%.1fg", $0) } ?? "—"
    }

    private func focusBinding(for field: EditEntryField) -> Binding<Bool> {
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

    private func advanceFocus(after field: EditEntryField) {
        switch field {
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

    private func save() {
        guard isValid, let calories = DecimalInput.parse(self.calories) else { return }
        let protein = DecimalInput.parse(self.protein)
        let fat = DecimalInput.parse(self.fat)
        let carbs = DecimalInput.parse(self.carbs)

        if hasOriginalPortion, let grams = parsedGrams {
            let multiplier = grams / 100
            entry.grams = grams
            entry.caloriesPer100g = calories
            entry.proteinPer100g = protein
            entry.fatPer100g = fat
            entry.carbsPer100g = carbs
            entry.calories = Int(calories * multiplier)
            entry.protein = protein.map { $0 * multiplier }
            entry.fat = fat.map { $0 * multiplier }
            entry.carbs = carbs.map { $0 * multiplier }
        } else {
            entry.calories = Int(calories)
            entry.protein = protein
            entry.fat = fat
            entry.carbs = carbs
            entry.caloriesPer100g = nil
            entry.proteinPer100g = nil
            entry.fatPer100g = nil
            entry.carbsPer100g = nil
        }

        updateEntryTime()
        dismiss()
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
