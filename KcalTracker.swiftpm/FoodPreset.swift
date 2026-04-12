import Foundation
import SwiftData

@Model
final class FoodPreset {
    var id: UUID = UUID()
    var name: String = ""
    var caloriesPer100g: Double = 0.0
    var proteinPer100g: Double = 0.0
    var carbsPer100g: Double = 0.0
    var fatPer100g: Double = 0.0
    var defaultGrams: Double?
    
    init(name: String, caloriesPer100g: Double, proteinPer100g: Double, carbsPer100g: Double, fatPer100g: Double, defaultGrams: Double? = nil) {
        self.id = UUID()
        self.name = name
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.defaultGrams = defaultGrams
    }
}
