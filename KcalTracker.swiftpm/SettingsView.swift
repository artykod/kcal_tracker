import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private enum CalculatorEstimateType: String, CaseIterable, Identifiable {
    case range
    case femaleBased
    case maleBased

    var id: String { rawValue }

    var title: String {
        switch self {
        case .range: "Range (Recommended)"
        case .femaleBased: "Female-based Formula"
        case .maleBased: "Male-based Formula"
        }
    }
}

private enum CalculatorActivity: String, CaseIterable, Identifiable {
    case notSelected
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notSelected: "Not selected"
        case .sedentary: "Sedentary"
        case .light: "Lightly active"
        case .moderate: "Moderately active"
        case .active: "Very active"
        case .veryActive: "Extra active"
        }
    }

    var multiplier: Double? {
        switch self {
        case .notSelected: nil
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}

private enum CalculatorUnits: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var transferManager = DataTransferManager()

    @AppStorage("dailyCalorieTarget") private var dailyCalorieTarget = 2000
    @AppStorage("calculatorAge") private var calculatorAge = 0
    @AppStorage("calculatorHeightCm") private var calculatorHeightCm = 0.0
    @AppStorage("calculatorWeightKg") private var calculatorWeightKg = 0.0
    @AppStorage("calculatorEstimateType") private var calculatorEstimateType = CalculatorEstimateType.range.rawValue
    @AppStorage("calculatorActivity") private var calculatorActivity = CalculatorActivity.notSelected.rawValue
    @AppStorage("calculatorUnits") private var calculatorUnits = CalculatorUnits.metric.rawValue
    
    @State private var showingExportError = false
    @State private var exportError: Error?
    
    @State private var showingImportPicker = false
    @State private var showingImportError = false
    @State private var importError: Error?
    @State private var importSuccess = false
    
    @State private var exportDocument: AppDataDocument?
    @State private var showingFileExporter = false

    private func estimatedMaintenanceCalories(sexAdjustment: Double) -> Int {
        let activity = CalculatorActivity(rawValue: calculatorActivity) ?? .notSelected
        let restingCalories = (10 * calculatorWeightKg)
            + (6.25 * calculatorHeightCm)
            - (5 * Double(calculatorAge))
            + sexAdjustment
        let maintenanceCalories = max(restingCalories, 0) * (activity.multiplier ?? 0)

        return Int((maintenanceCalories / 50).rounded() * 50)
    }

    private var femaleBasedEstimate: Int {
        estimatedMaintenanceCalories(sexAdjustment: -161)
    }

    private var maleBasedEstimate: Int {
        estimatedMaintenanceCalories(sexAdjustment: 5)
    }

    private var selectedEstimateType: CalculatorEstimateType {
        CalculatorEstimateType(rawValue: calculatorEstimateType) ?? .range
    }

    private var calculatorInputsValid: Bool {
        calculatorAge >= 18
            && calculatorHeightCm > 0
            && calculatorWeightKg > 0
            && selectedActivity.multiplier != nil
    }

    private var selectedActivity: CalculatorActivity {
        CalculatorActivity(rawValue: calculatorActivity) ?? .notSelected
    }

    private var selectedUnits: CalculatorUnits {
        CalculatorUnits(rawValue: calculatorUnits) ?? .metric
    }

    private var optionalCalculatorHeightCm: Binding<Double?> {
        optionalPositiveBinding(for: $calculatorHeightCm)
    }

    private var optionalCalculatorWeightKg: Binding<Double?> {
        optionalPositiveBinding(for: $calculatorWeightKg)
    }

    private var calculatorHeightFeet: Binding<Int?> {
        Binding(
            get: {
                calculatorHeightCm > 0
                    ? Int(floor((calculatorHeightCm / 2.54) / 12))
                    : nil
            },
            set: { feet in
                guard let feet else {
                    calculatorHeightCm = 0
                    return
                }
                let currentInches = (calculatorHeightCm / 2.54)
                    .truncatingRemainder(dividingBy: 12)
                calculatorHeightCm = (Double(feet * 12) + currentInches) * 2.54
            }
        )
    }

    private var calculatorHeightInches: Binding<Double?> {
        Binding(
            get: {
                calculatorHeightCm > 0
                    ? (calculatorHeightCm / 2.54).truncatingRemainder(dividingBy: 12)
                    : nil
            },
            set: { inches in
                guard let inches else {
                    calculatorHeightCm = 0
                    return
                }
                let feet = floor((calculatorHeightCm / 2.54) / 12)
                calculatorHeightCm = ((feet * 12) + inches) * 2.54
            }
        )
    }

    private var calculatorWeightPounds: Binding<Double?> {
        Binding(
            get: {
                calculatorWeightKg > 0
                    ? calculatorWeightKg * 2.204_622_621_8
                    : nil
            },
            set: {
                calculatorWeightKg = ($0 ?? 0) / 2.204_622_621_8
            }
        )
    }
    
    var body: some View {
        Form {
            Section("Daily Calorie Target") {
                Stepper(
                    value: $dailyCalorieTarget,
                    in: 500...10_000,
                    step: 50
                ) {
                    LabeledContent("Target", value: "\(dailyCalorieTarget) kcal")
                }
            }

            Section {
                Picker("Units", selection: $calculatorUnits) {
                    ForEach(CalculatorUnits.allCases) { units in
                        Text(units.title).tag(units.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Age")

                    Spacer()

                    Button {
                        calculatorAge = max(calculatorAge - 1, 1)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(calculatorAge <= 1)
                    .accessibilityLabel("Decrease age")

                    Menu(calculatorAge == 0 ? "Select age" : "\(calculatorAge) years") {
                        Button("Not selected") {
                            calculatorAge = 0
                        }

                        Divider()

                        Picker("Age", selection: $calculatorAge) {
                            ForEach(10...80, id: \.self) { age in
                                Text("\(age) years").tag(age)
                            }
                        }
                    }

                    Button {
                        calculatorAge = calculatorAge == 0
                            ? 10
                            : min(calculatorAge + 1, 120)
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(calculatorAge >= 120)
                    .accessibilityLabel("Increase age")
                }

                if selectedUnits == .metric {
                    LabeledContent("Height (cm)") {
                        decimalField("cm", value: optionalCalculatorHeightCm)
                    }

                    LabeledContent("Weight (kg)") {
                        decimalField("kg", value: optionalCalculatorWeightKg)
                    }
                } else {
                    LabeledContent("Height") {
                        HStack(spacing: 4) {
                            TextField("ft", value: calculatorHeightFeet, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 36)
                            Text("ft")
                                .foregroundStyle(.secondary)

                            TextField(
                                "in",
                                value: calculatorHeightInches,
                                format: .number.precision(.fractionLength(0...1))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 44)
                            Text("in")
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Weight (lb)") {
                        decimalField("lb", value: calculatorWeightPounds)
                    }
                }

                Picker("Estimate type", selection: $calculatorEstimateType) {
                    ForEach(CalculatorEstimateType.allCases) { type in
                        Text(type.title).tag(type.rawValue)
                    }
                }

                Picker("Activity", selection: $calculatorActivity) {
                    ForEach(CalculatorActivity.allCases) { activity in
                        Text(activity.title).tag(activity.rawValue)
                    }
                }

                if calculatorAge == 0 {
                    Label("Select an age to calculate", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                } else if calculatorAge < 18 {
                    Label("Estimate available for ages 18 and older", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                } else if !calculatorInputsValid {
                    Label("Complete height, weight, and activity", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                } else {
                    switch selectedEstimateType {
                    case .range:
                        LabeledContent(
                            "Estimated maintenance",
                            value: "\(femaleBasedEstimate)–\(maleBasedEstimate) kcal"
                        )

                        Button("Use Lower Estimate") {
                            setDailyTarget(to: femaleBasedEstimate)
                        }
                        .disabled(!calculatorInputsValid)

                        Button("Use Upper Estimate") {
                            setDailyTarget(to: maleBasedEstimate)
                        }
                        .disabled(!calculatorInputsValid)

                    case .femaleBased:
                        estimateResult(calories: femaleBasedEstimate)

                    case .maleBased:
                        estimateResult(calories: maleBasedEstimate)
                    }
                }

            } header: {
                Text("Target Calculator")
            } footer: {
                Text("Adult estimate based on the Mifflin–St Jeor resting-energy equation and activity level. Treat it as a starting point, not medical advice.")
            }

            Section(header: Text("Data Management")) {
                Button(action: prepareExport) {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }
                
                Button(action: { showingImportPicker = true }) {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                }
            }
            
            Section(footer: Text("Export your entries, foods, calorie target, and calculator settings to a JSON file. Import merges entries and foods, then restores backed-up settings. Duplicates identified by ID are ignored.")) {
                EmptyView()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if calculatorAge != 0 {
                calculatorAge = min(max(calculatorAge, 1), 120)
            }
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "KcalTrackerBackup"
        ) { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
            case .failure(let error):
                exportError = error
                showingExportError = true
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                performImport(from: url)
            case .failure(let error):
                importError = error
                showingImportError = true
            }
        }
        .alert("Export Failed", isPresented: $showingExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError?.localizedDescription ?? "Unknown error occurred.")
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError?.localizedDescription ?? "Unknown error occurred.")
        }
        .alert("Import Successful", isPresented: $importSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your data and backed-up settings have been restored successfully.")
        }
    }

    private func decimalField(
        _ prompt: String,
        value: Binding<Double?>
    ) -> some View {
        TextField(
            prompt,
            value: value,
            format: .number.precision(.fractionLength(0...1))
        )
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 100)
    }

    private func optionalPositiveBinding(for value: Binding<Double>) -> Binding<Double?> {
        Binding(
            get: { value.wrappedValue > 0 ? value.wrappedValue : nil },
            set: { value.wrappedValue = $0 ?? 0 }
        )
    }

    @ViewBuilder
    private func estimateResult(calories: Int) -> some View {
        LabeledContent("Estimated maintenance", value: "\(calories) kcal")

        Button("Use Estimate as Target") {
            setDailyTarget(to: calories)
        }
        .disabled(!calculatorInputsValid)
    }

    private func setDailyTarget(to calories: Int) {
        dailyCalorieTarget = min(max(calories, 500), 10_000)
    }
    
    private func prepareExport() {
        do {
            let doc = try transferManager.generateExportData(context: modelContext)
            exportDocument = doc
            showingFileExporter = true
        } catch {
            exportError = error
            showingExportError = true
        }
    }
    
    private func performImport(from url: URL) {
        do {
            try transferManager.importData(from: url, context: modelContext)
            importSuccess = true
        } catch {
            importError = error
            showingImportError = true
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
