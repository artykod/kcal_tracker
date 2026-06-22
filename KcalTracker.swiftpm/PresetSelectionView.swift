import SwiftUI
import SwiftData

struct PresetSelectionView: View {
    private static let pageSize = 20

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPreset: FoodPreset?

    @State private var presets: [FoodPreset] = []
    @State private var searchText = ""
    @State private var hasMorePresets = false
    @State private var isLoading = false
    @State private var fetchError: String?

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedPreset = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("No Preset")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedPreset == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }

                Section("Presets") {
                    if presets.isEmpty && isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if let fetchError {
                        ContentUnavailableView(
                            "Could Not Load Presets",
                            systemImage: "exclamationmark.triangle",
                            description: Text(fetchError)
                        )
                    } else if presets.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(presets) { preset in
                            Button {
                                selectedPreset = preset
                                dismiss()
                            } label: {
                                HStack(alignment: .top) {
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

                                    Spacer()

                                    if selectedPreset?.id == preset.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.vertical, 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if preset.id == presets.last?.id && hasMorePresets {
                                    loadNextPage()
                                }
                            }
                        }

                        if hasMorePresets && isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Select Preset")
            .navigationBarTitleDisplayMode(.inline)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
