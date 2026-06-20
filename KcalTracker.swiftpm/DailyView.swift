import SwiftUI
import SwiftData

struct DailyView: View {
    let date: Date
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entryClipboard: EntryClipboard
    @Query private var entries: [CalorieEntry]
    @State private var showingAddEntry = false
    @State private var editingEntry: CalorieEntry?
    @State private var entryToCreatePreset: CalorieEntry?
    
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
                                    HStack(spacing: 4) {
                                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                                        if let grams = entry.grams {
                                            Text("\u{2022}")
                                            Text("\(grams.formatted(.number.precision(.fractionLength(0...2)))) g")
                                        }
                                    }
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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingEntry = entry
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    copyToClipboard(entry)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)

                                Button {
                                    editingEntry = entry
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)

                                if let grams = entry.grams, grams > 0 {
                                    Button {
                                        entryToCreatePreset = entry
                                    } label: {
                                        Label("Make Preset", systemImage: "list.bullet.clipboard")
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            
            VStack {
                Spacer()
                HStack(spacing: 16) {
                    if entryClipboard.copiedEntry != nil {
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
        .animation(.spring(), value: entryClipboard.copiedEntry != nil)
        .sheet(isPresented: $showingAddEntry) {
            AddEntryView(date: date)
        }
        .sheet(item: $editingEntry) { entry in
            EditEntryPortionView(entry: entry)
        }
        .sheet(item: $entryToCreatePreset) { entry in
            AddPresetView(entryToCopy: entry)
        }
    }
    
    private func copyToClipboard(_ entry: CalorieEntry) {
        entryClipboard.copy(entry)
    }
    
    private func pasteEntry() {
        guard let copied = entryClipboard.copiedEntry else { return }
        
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
            caloriesPer100g: copied.caloriesPer100g,
            proteinPer100g: copied.proteinPer100g,
            carbsPer100g: copied.carbsPer100g,
            fatPer100g: copied.fatPer100g,
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
