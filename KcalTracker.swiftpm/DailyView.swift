import SwiftUI
import SwiftData

struct DailyView: View {
    let date: Date
    let dateSelection: Binding<Date>
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void
    let onToday: () -> Void
    let onDaySwipeChanged: (DragGesture.Value) -> Void
    let onDaySwipeEnded: (DragGesture.Value) -> Void
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entryClipboard: EntryClipboard
    @AppStorage("dailyCalorieTarget") private var dailyCalorieTarget = 2000
    @Query private var entries: [CalorieEntry]
    @State private var showingAddEntry = false
    @State private var showingAddMultipleEntries = false
    @State private var editingEntry: CalorieEntry?
    @State private var entryToCreatePreset: CalorieEntry?
    
    init(
        date: Date,
        dateSelection: Binding<Date>? = nil,
        onPreviousDay: @escaping () -> Void = {},
        onNextDay: @escaping () -> Void = {},
        onToday: @escaping () -> Void = {},
        onDaySwipeChanged: @escaping (DragGesture.Value) -> Void = { _ in },
        onDaySwipeEnded: @escaping (DragGesture.Value) -> Void = { _ in }
    ) {
        self.date = date
        self.dateSelection = dateSelection ?? .constant(date)
        self.onPreviousDay = onPreviousDay
        self.onNextDay = onNextDay
        self.onToday = onToday
        self.onDaySwipeChanged = onDaySwipeChanged
        self.onDaySwipeEnded = onDaySwipeEnded
        
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

    private var calorieSummaryColor: Color {
        let target = Double(max(dailyCalorieTarget, 1))
        let ratio = Double(totalCalories) / target

        if ratio <= 1 {
            return Color(
                hue: 0.33 - (0.23 * min(ratio, 1)),
                saturation: 0.8,
                brightness: 0.82
            )
        }

        return Color(
            hue: max(0, 0.1 - (0.1 * min((ratio - 1) / 0.25, 1))),
            saturation: 0.85,
            brightness: 0.88
        )
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                if entries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("No foods for this day")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .simultaneousGesture(daySwipeGesture)
                } else {
                    List {
                        Section {
                            ForEach(entries) { entry in
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(entry.name)
                                            .font(.headline)
                                            .lineLimit(1)

                                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer(minLength: 8)

                                        Text("\(entry.calories) kcal")
                                            .fontWeight(.semibold)
                                    }

                                    if entry.protein != nil || entry.carbs != nil || entry.fat != nil || entry.grams != nil {
                                        HStack(spacing: 8) {
                                            if let p = entry.protein { MacroText(label: "Protein", value: p) }
                                            if let f = entry.fat { MacroText(label: "Fat", value: f) }
                                            if let c = entry.carbs { MacroText(label: "Carbs", value: c) }

                                            Spacer(minLength: 8)

                                            if let grams = entry.grams {
                                                Text("\(grams.formatted(.number.precision(.fractionLength(0...2)))) g")
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .font(.caption2)
                                    }
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
                                            Label("Make Food Preset", systemImage: "list.bullet.clipboard")
                                        }
                                        .tint(.green)
                                    }
                                }
                            }
                            .onDelete(perform: deleteItems)
                        }
                    }
                    .mask {
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 24)
                            Color.black
                            LinearGradient(
                                colors: [.black, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 24)
                        }
                    }
                }

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: onPreviousDay) {
                                Image(systemName: "chevron.left")
                                    .frame(width: 44, height: 40)
                                    .contentShape(Rectangle())
                            }

                            Spacer()

                            DatePicker(
                                "",
                                selection: dateSelection,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)

                            Spacer()

                            Button(action: onNextDay) {
                                Image(systemName: "chevron.right")
                                    .frame(width: 44, height: 40)
                                    .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal, 8)

                        VStack(spacing: 6) {
                            HStack(spacing: 16) {
                                MacroText(label: "Protein", value: totalProtein)
                                MacroText(label: "Fat", value: totalFat)
                                MacroText(label: "Carbs", value: totalCarbs)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)

                            HStack {
                                Spacer()
                                HStack(spacing: 6) {
                                    Text("\(totalCalories) kcal")
                                        .font(.title2).fontWeight(.bold)
                                        .foregroundColor(calorieSummaryColor)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)

                                    if totalCalories > dailyCalorieTarget {
                                        NavigationLink(destination: SettingsView()) {
                                            Image(systemName: "info.circle")
                                                .font(.title3)
                                                .foregroundColor(calorieSummaryColor)
                                        }
                                        .accessibilityLabel("Adjust calorie target")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    bottomActionsPanel
                }
                .padding(.vertical, 16)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .simultaneousGesture(daySwipeGesture)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .animation(.spring(), value: entryClipboard.copiedEntry != nil)
        .sheet(isPresented: $showingAddEntry) {
            AddEntryView(date: date)
        }
        .sheet(isPresented: $showingAddMultipleEntries) {
            AddMultipleEntriesView(date: date)
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

    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .global)
            .onChanged(onDaySwipeChanged)
            .onEnded(onDaySwipeEnded)
    }

    private var bottomActionsPanel: some View {
        ZStack {
            HStack {
                NavigationLink(destination: PresetsView()) {
                    Image(systemName: "list.bullet.clipboard")
                        .bottomUtilityButtonStyle()
                }
                
                NavigationLink(destination: SearchEntriesView()) {
                    Image(systemName: "magnifyingglass")
                        .bottomUtilityButtonStyle()
                }

                Spacer()

                Button("Today", action: onToday)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 3, x: 0, y: 2)
            }

            Button(action: {
                showingAddEntry = true
            }) {
                Image(systemName: "plus")
                    .font(.title.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 4, x: 0, y: 4)
            }
            .contextMenu {
                Button {
                    showingAddEntry = true
                } label: {
                    Label("Add Food", systemImage: "plus")
                }

                Button {
                    showingAddMultipleEntries = true
                } label: {
                    Label("Add Multiple Foods", systemImage: "checklist")
                }
            }
            .accessibilityHint("Double-tap to add one food, or touch and hold to add multiple foods")
            .offset(x: entryClipboard.copiedEntry == nil ? 0 : 32)

            if entryClipboard.copiedEntry != nil {
                Button(action: pasteEntry) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title.weight(.semibold))
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4, x: 0, y: 4)
                }
                .offset(x: -32)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

private extension View {
    func bottomUtilityButtonStyle() -> some View {
        self
            .font(.title3.weight(.semibold))
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .shadow(radius: 3, x: 0, y: 2)
    }
}
