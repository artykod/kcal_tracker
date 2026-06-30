import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedDate = Date()
    @Environment(\.modelContext) private var modelContext

    private let swipeThreshold: CGFloat = 75
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date selector
                HStack {
                    Button(action: {
                        moveSelectedDate(by: -1)
                    }) {
                        Image(systemName: "chevron.left")
                            .padding()
                    }
                    
                    Spacer()
                    
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    
                    Spacer()
                    
                    Button(action: {
                        moveSelectedDate(by: 1)
                    }) {
                        Image(systemName: "chevron.right")
                            .padding()
                    }
                }
                .padding(.horizontal)
                .background(Color(uiColor: .systemGroupedBackground))
                
                DailyView(date: selectedDate)
                    .simultaneousGesture(daySwipeGesture)
            }
            .navigationTitle("Calories Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    NavigationLink(destination: SearchEntriesView()) {
                        Image(systemName: "magnifyingglass")
                    }
                    NavigationLink(destination: PresetsView()) {
                        Image(systemName: "list.bullet.clipboard")
                    }
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") {
                        selectedDate = Date()
                    }
                }
            }
        }
    }

    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height

                guard abs(horizontalDistance) >= swipeThreshold,
                      abs(horizontalDistance) > abs(verticalDistance) * 1.5 else {
                    return
                }

                moveSelectedDate(by: horizontalDistance < 0 ? 1 : -1)
            }
    }

    private func moveSelectedDate(by dayOffset: Int) {
        guard let newDate = Calendar.current.date(
            byAdding: .day,
            value: dayOffset,
            to: selectedDate
        ) else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            selectedDate = newDate
        }
    }
}
