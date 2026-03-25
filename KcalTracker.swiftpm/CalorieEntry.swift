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
    var date: Date
    
    init(name: String, calories: Int, protein: Double? = nil, carbs: Double? = nil, fat: Double? = nil, grams: Double? = nil, date: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.grams = grams
        self.date = date
    }
}
