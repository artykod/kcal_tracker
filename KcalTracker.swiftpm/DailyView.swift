import SwiftUI
import SwiftData

struct DailyView: View {
    let date: Date
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [CalorieEntry]
    @State private var showingAddEntry = false
    
    init(date: Date) {
        self.date = date
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<CalorieEntry> { entry in
            entry.date >= startOfDay && entry.date < endOfDay
        }
        
        _entries = Query(filter: predicate, sort: \.date, order: .reverse)
    }
    
    var totalCalories: Int { entries.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { entries.reduce(0) { $0 + ($1.protein ?? 0) } }
    var totalCarbs: Double { entries.reduce(0) { $0 + ($1.carbs ?? 0) } }
    var totalFat: Double { entries.reduce(0) { $0 + ($1.fat ?? 0) } }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            if entries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    Text("No entries for this day")
                        .foregroundColor(.gray)
                }
            } else {
                List {
                    Section {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Total:")
                                    .font(.title3).fontWeight(.medium)
                                Spacer()
                                Text("\(totalCalories) kcal")
                                    .font(.title2).fontWeight(.bold)
                                    .foregroundColor(totalCalories > 2000 ? .orange : .green)
                            }
                            HStack(spacing: 16) {
                                MacroText(label: "P", value: totalProtein)
                                MacroText(label: "C", value: totalCarbs)
                                MacroText(label: "F", value: totalFat)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section(header: Text("Entries")) {
                        ForEach(entries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.name)
                                        .font(.headline)
                                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if entry.protein != nil || entry.carbs != nil || entry.fat != nil {
                                        HStack(spacing: 8) {
                                            if let p = entry.protein { MacroText(label: "P", value: p) }
                                            if let c = entry.carbs { MacroText(label: "C", value: c) }
                                            if let f = entry.fat { MacroText(label: "F", value: f) }
                                        }
                                        .font(.caption2)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("\(entry.calories) kcal")
                                    .fontWeight(.semibold)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            
            VStack {
                Spacer()
                Button(action: {
                    showingAddEntry = true
                }) {
                    Image(systemName: "plus")
                        .font(.title.weight(.semibold))
                        .padding(16)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4, x: 0, y: 4)
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showingAddEntry) {
            AddEntryView(date: date)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(entries[index])
            }
        }
    }
}
