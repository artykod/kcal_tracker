import Foundation
import SwiftData

@Model
final class CalorieEntry {
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
    
    init(name: String, calories: Int, protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil, grams: Double? = nil, caloriesPer100g: Double? = nil, proteinPer100g: Double? = nil, carbsPer100g: Double? = nil, fatPer100g: Double? = nil, date: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.grams = grams
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.date = date
    }

    func updatePortion(to newGrams: Double) {
        guard let currentGrams = grams, currentGrams > 0, newGrams > 0 else { return }

        let calorieRate = caloriesPer100g ?? (Double(calories) * 100 / currentGrams)
        let proteinRate = proteinPer100g ?? protein.map { $0 * 100 / currentGrams }
        let carbsRate = carbsPer100g ?? carbs.map { $0 * 100 / currentGrams }
        let fatRate = fatPer100g ?? fat.map { $0 * 100 / currentGrams }

        caloriesPer100g = calorieRate
        proteinPer100g = proteinRate
        carbsPer100g = carbsRate
        fatPer100g = fatRate

        grams = newGrams
        calories = Int(calorieRate * newGrams / 100)
        protein = proteinRate.map { $0 * newGrams / 100 }
        carbs = carbsRate.map { $0 * newGrams / 100 }
        fat = fatRate.map { $0 * newGrams / 100 }
    }
}
