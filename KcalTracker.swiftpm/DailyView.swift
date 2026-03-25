import SwiftUI
import SwiftData

struct CopiedEntry: Codable {
    var name: String
    var calories: Int
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var grams: Double?
}

struct DailyView: View {
    let date: Date
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [CalorieEntry]
    @State private var showingAddEntry = false
    @AppStorage("copiedEntryData") private var copiedEntryData: Data = Data()
    
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
    
    private var copiedEntry: CopiedEntry? {
        guard !copiedEntryData.isEmpty else { return nil }
        return try? JSONDecoder().decode(CopiedEntry.self, from: copiedEntryData)
    }
    
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
                            .swipeActions(edge: .leading) {
                                Button {
                                    copyToClipboard(entry)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            
            VStack {
                Spacer()
                HStack(spacing: 16) {
                    if copiedEntry != nil {
                        Button(action: pasteEntry) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.title.weight(.semibold))
                                .padding(16)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4, x: 0, y: 4)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
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
                }
                .padding(.bottom, 24)
            }
        }
        .animation(.spring(), value: copiedEntryData)
        .sheet(isPresented: $showingAddEntry) {
            AddEntryView(date: date)
        }
    }
    
    private func copyToClipboard(_ entry: CalorieEntry) {
        let copied = CopiedEntry(name: entry.name, calories: entry.calories, protein: entry.protein, carbs: entry.carbs, fat: entry.fat, grams: entry.grams)
        if let data = try? JSONEncoder().encode(copied) {
            copiedEntryData = data
        }
    }
    
    private func pasteEntry() {
        guard let copied = copiedEntry else { return }
        
        // Pasting entry should default to midday or current time if it's today
        let pasteTime: Date
        if Calendar.current.isDateInToday(date) {
            pasteTime = Date()
        } else {
            let startOfDay = Calendar.current.startOfDay(for: date)
            pasteTime = Calendar.current.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay
        }
        
        let newEntry = CalorieEntry(
            name: copied.name,
            calories: copied.calories,
            protein: copied.protein,
            carbs: copied.carbs,
            fat: copied.fat,
            grams: copied.grams,
            date: pasteTime
        )
        modelContext.insert(newEntry)
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(entries[index])
            }
        }
    }
}
