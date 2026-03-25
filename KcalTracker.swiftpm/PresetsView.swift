import SwiftUI
import SwiftData

struct PresetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodPreset.name) private var presets: [FoodPreset]
    @State private var showingAddPreset = false
    
    var body: some View {
        List {
            if presets.isEmpty {
                Text("No presets yet. Add some reusable foods!")
                    .foregroundColor(.secondary)
            } else {
                ForEach(presets) { preset in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.name)
                            .font(.headline)
                        
                        Text("\(Int(preset.caloriesPer100g)) kcal / 100g")
                            .font(.subheadline)
                        
                        HStack(spacing: 12) {
                            MacroText(label: "P", value: preset.proteinPer100g)
                            MacroText(label: "C", value: preset.carbsPer100g)
                            MacroText(label: "F", value: preset.fatPer100g)
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteItems)
            }
        }
        .navigationTitle("Food Presets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddPreset = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPreset) {
            AddPresetView()
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(presets[index])
            }
        }
    }
}

struct MacroText: View {
    let label: String
    let value: Double
    
    var body: some View {
        HStack(spacing: 2) {
            Text("\(label):")
                .foregroundColor(.secondary)
            Text(String(format: "%.1fg", value))
                .fontWeight(.medium)
        }
    }
}
