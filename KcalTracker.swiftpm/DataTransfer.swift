import Foundation
import SwiftData
import SwiftUI

// MARK: - Data Transfer Objects (DTO)

struct ExportData: Codable {
    var entries: [CalorieEntryDTO]
    var presets: [FoodPresetDTO]
    var calculatorSettings: CalculatorSettingsDTO? = nil
}

struct CalculatorSettingsDTO: Codable {
    var dailyCalorieTarget: Int?
    var age: Int?
    var heightCm: Double?
    var weightKg: Double?
    var estimateType: String?
    var activity: String?
    var units: String?

    static func current(defaults: UserDefaults = .standard) -> CalculatorSettingsDTO {
        CalculatorSettingsDTO(
            dailyCalorieTarget: defaults.object(forKey: "dailyCalorieTarget") as? Int ?? 2000,
            age: defaults.object(forKey: "calculatorAge") as? Int ?? 0,
            heightCm: defaults.object(forKey: "calculatorHeightCm") as? Double ?? 0,
            weightKg: defaults.object(forKey: "calculatorWeightKg") as? Double ?? 0,
            estimateType: defaults.string(forKey: "calculatorEstimateType") ?? "range",
            activity: defaults.string(forKey: "calculatorActivity") ?? "notSelected",
            units: defaults.string(forKey: "calculatorUnits") ?? "metric"
        )
    }

    func restore(defaults: UserDefaults = .standard) {
        if let dailyCalorieTarget {
            defaults.set(min(max(dailyCalorieTarget, 500), 10_000), forKey: "dailyCalorieTarget")
        }
        if let age {
            defaults.set(age == 0 ? 0 : min(max(age, 1), 120), forKey: "calculatorAge")
        }
        if let heightCm, heightCm >= 0 {
            defaults.set(heightCm, forKey: "calculatorHeightCm")
        }
        if let weightKg, weightKg >= 0 {
            defaults.set(weightKg, forKey: "calculatorWeightKg")
        }
        if let estimateType, ["range", "femaleBased", "maleBased"].contains(estimateType) {
            defaults.set(estimateType, forKey: "calculatorEstimateType")
        }
        if let activity, ["notSelected", "sedentary", "light", "moderate", "active", "veryActive"].contains(activity) {
            defaults.set(activity, forKey: "calculatorActivity")
        }
        if let units, ["metric", "imperial"].contains(units) {
            defaults.set(units, forKey: "calculatorUnits")
        }
    }
}

struct CalorieEntryDTO: Codable {
    var id: UUID
    var name: String
    var calories: Int
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var grams: Double?
    var caloriesPer100g: Double?
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var date: Date
    
    init(from model: CalorieEntry) {
        self.id = model.id
        self.name = model.name
        self.calories = model.calories
        self.protein = model.protein
        self.carbs = model.carbs
        self.fat = model.fat
        self.grams = model.grams
        self.caloriesPer100g = model.caloriesPer100g
        self.proteinPer100g = model.proteinPer100g
        self.carbsPer100g = model.carbsPer100g
        self.fatPer100g = model.fatPer100g
        self.date = model.date
    }
}

struct FoodPresetDTO: Codable {
    var id: UUID
    var name: String
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var defaultGrams: Double?
    
    init(from model: FoodPreset) {
        self.id = model.id
        self.name = model.name
        self.caloriesPer100g = model.caloriesPer100g
        self.proteinPer100g = model.proteinPer100g
        self.carbsPer100g = model.carbsPer100g
        self.fatPer100g = model.fatPer100g
        self.defaultGrams = model.defaultGrams
    }
}

// MARK: - JSON File Document for Exporting

struct AppDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: ExportData
    
    init(data: ExportData) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        if let dataInfo = configuration.file.regularFileContents {
            self.data = try JSONDecoder().decode(ExportData.self, from: dataInfo)
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let dataInfo = try encoder.encode(data)
        return FileWrapper(regularFileWithContents: dataInfo)
    }
}

import UniformTypeIdentifiers

// MARK: - Data Transfer Manager

@MainActor
class DataTransferManager: ObservableObject {
    
    func generateExportData(context: ModelContext) throws -> AppDataDocument {
        let entryDescriptor = FetchDescriptor<CalorieEntry>()
        let entries = try context.fetch(entryDescriptor)
        
        let presetDescriptor = FetchDescriptor<FoodPreset>()
        let presets = try context.fetch(presetDescriptor)
        
        let exportData = ExportData(
            entries: entries.map(CalorieEntryDTO.init),
            presets: presets.map(FoodPresetDTO.init),
            calculatorSettings: .current()
        )
        
        return AppDataDocument(data: exportData)
    }
    
    func importData(from url: URL, context: ModelContext) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer {
            if access {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let data = try Data(contentsOf: url)
        let decodedData = try JSONDecoder().decode(ExportData.self, from: data)
        
        // Fetch existing logic to merge / prevent full duplication
        let existingEntries = try context.fetch(FetchDescriptor<CalorieEntry>())
        let existingPresets = try context.fetch(FetchDescriptor<FoodPreset>())
        
        let existingEntryIDs = Set(existingEntries.map { $0.id })
        let existingPresetIDs = Set(existingPresets.map { $0.id })
        
        // Merge Entries
        for entryDTO in decodedData.entries {
            if !existingEntryIDs.contains(entryDTO.id) {
                let newEntry = CalorieEntry(
                    name: entryDTO.name,
                    calories: entryDTO.calories,
                    protein: entryDTO.protein,
                    carbs: entryDTO.carbs,
                    fat: entryDTO.fat,
                    grams: entryDTO.grams,
                    caloriesPer100g: entryDTO.caloriesPer100g,
                    proteinPer100g: entryDTO.proteinPer100g,
                    carbsPer100g: entryDTO.carbsPer100g,
                    fatPer100g: entryDTO.fatPer100g,
                    date: entryDTO.date
                )
                // Use the original id from the backup
                newEntry.id = entryDTO.id
                context.insert(newEntry)
            }
        }
        
        // Merge Presets
        for presetDTO in decodedData.presets {
            if !existingPresetIDs.contains(presetDTO.id) {
                let newPreset = FoodPreset(
                    name: presetDTO.name,
                    caloriesPer100g: presetDTO.caloriesPer100g,
                    proteinPer100g: presetDTO.proteinPer100g,
                    carbsPer100g: presetDTO.carbsPer100g,
                    fatPer100g: presetDTO.fatPer100g,
                    defaultGrams: presetDTO.defaultGrams
                )
                newPreset.id = presetDTO.id
                context.insert(newPreset)
            }
        }

        try context.save()
        decodedData.calculatorSettings?.restore()
    }
}
