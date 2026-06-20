import SwiftUI
import SwiftData

struct PresetsView: View {
    private static let pageSize = 20

    @Environment(\.modelContext) private var modelContext
    @State private var presets: [FoodPreset] = []
    @State private var showingAddPreset = false
    @State private var presetToEdit: FoodPreset?
    @State private var presetToCopy: FoodPreset?
    @State private var searchText = ""
    @State private var hasMorePresets = false
    @State private var isLoading = false
    @State private var fetchError: String?

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        List {
            if presets.isEmpty && isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if let fetchError {
                ContentUnavailableView(
                    "Could Not Load Presets",
                    systemImage: "exclamationmark.triangle",
                    description: Text(fetchError)
                )
            } else if presets.isEmpty && searchQuery.isEmpty {
                Text("No presets yet. Add some reusable foods!")
                    .foregroundColor(.secondary)
            } else if presets.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(presets) { preset in
                    Button(action: {
                        presetToEdit = preset
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("\(Int(preset.caloriesPer100g)) kcal / 100g")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                MacroText(label: "P", value: preset.proteinPer100g)
                                MacroText(label: "C", value: preset.carbsPer100g)
                                MacroText(label: "F", value: preset.fatPer100g)
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .swipeActions(edge: .leading) {
                        Button {
                            presetToEdit = preset
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)

                        Button {
                            presetToCopy = preset
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete(perform: deleteItems)

                if hasMorePresets {
                    Button {
                        loadNextPage()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Load More")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .navigationTitle("Food Presets")
        .searchable(text: $searchText, prompt: "Preset name")
        .task(id: searchQuery) {
            do {
                try await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                loadFirstPage()
            } catch {
                // A new search query cancelled this pending fetch.
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingAddPreset = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPreset, onDismiss: loadFirstPage) {
            AddPresetView(presetToEdit: nil)
        }
        .sheet(item: $presetToEdit, onDismiss: loadFirstPage) { preset in
            AddPresetView(presetToEdit: preset)
        }
        .sheet(item: $presetToCopy, onDismiss: loadFirstPage) { preset in
            AddPresetView(presetToCopy: preset)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(presets[index])
            }
        }
        try? modelContext.save()
        loadFirstPage()
    }

    private func loadFirstPage() {
        presets = []
        fetchPage(offset: 0)
    }

    private func loadNextPage() {
        fetchPage(offset: presets.count)
    }

    private func fetchPage(offset: Int) {
        guard !isLoading else { return }

        isLoading = true
        fetchError = nil
        let query = searchQuery

        do {
            var descriptor = FetchDescriptor<FoodPreset>(
                predicate: #Predicate { preset in
                    query.isEmpty || preset.name.localizedStandardContains(query)
                },
                sortBy: [SortDescriptor(\FoodPreset.name)]
            )
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = Self.pageSize + 1

            var page = try modelContext.fetch(descriptor)
            hasMorePresets = page.count > Self.pageSize
            if hasMorePresets {
                page.removeLast()
            }
            presets.append(contentsOf: page)
        } catch {
            fetchError = error.localizedDescription
            hasMorePresets = false
        }

        isLoading = false
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
