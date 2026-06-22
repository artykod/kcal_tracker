import SwiftUI
import SwiftData

struct SearchEntriesView: View {
    private static let pageSize = 20

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entryClipboard: EntryClipboard

    @State private var searchText = ""
    @State private var filtersSinceDate = false
    @State private var sinceDate = Date()
    @State private var entries: [CalorieEntry] = []
    @State private var hasMoreResults = false
    @State private var isLoading = false
    @State private var fetchError: String?
    @State private var entryToCreatePreset: CalorieEntry?

    private struct SearchCriteria: Hashable {
        let query: String
        let filtersSinceDate: Bool
        let sinceDate: Date
    }

    private var searchCriteria: SearchCriteria {
        SearchCriteria(
            query: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            filtersSinceDate: filtersSinceDate,
            sinceDate: Calendar.current.startOfDay(for: sinceDate)
        )
    }

    var body: some View {
        List {
            Section {
                Toggle("Since Date", isOn: $filtersSinceDate)

                if filtersSinceDate {
                    DatePicker("Starting", selection: $sinceDate, in: ...Date(), displayedComponents: .date)
                }
            } footer: {
                Text(filtersSinceDate ? "Showing entries on or after the selected date." : "Showing entries from all time.")
            }

            Section("Results") {
                if entries.isEmpty && isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let fetchError {
                    ContentUnavailableView(
                        "Search Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(fetchError)
                    )
                } else if entries.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(entries) { entry in
                        entryRow(entry)
                            .swipeActions(edge: .leading) {
                                Button {
                                    copyEntry(entry)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)

                                if let grams = entry.grams, grams > 0 {
                                    Button {
                                        entryToCreatePreset = entry
                                    } label: {
                                        Label("Make Preset", systemImage: "list.bullet.clipboard")
                                    }
                                    .tint(.green)
                                }
                            }
                            .onAppear {
                                if entry.id == entries.last?.id && hasMoreResults {
                                    loadNextPage()
                                }
                            }
                    }

                    if hasMoreResults && isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Search Entries")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Food name")
        .task(id: searchCriteria) {
            do {
                try await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                loadFirstPage()
            } catch {
                // A new search criterion cancelled this pending fetch.
            }
        }
        .sheet(item: $entryToCreatePreset) { entry in
            AddPresetView(entryToCopy: entry)
        }
    }

    private func entryRow(_ entry: CalorieEntry) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.headline)

                HStack(spacing: 4) {
                    Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    if let grams = entry.grams {
                        Text("\u{2022}")
                        Text("\(grams.formatted(.number.precision(.fractionLength(0...2)))) g")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if entry.protein != nil || entry.carbs != nil || entry.fat != nil {
                    HStack(spacing: 8) {
                        if let protein = entry.protein { MacroText(label: "P", value: protein) }
                        if let carbs = entry.carbs { MacroText(label: "C", value: carbs) }
                        if let fat = entry.fat { MacroText(label: "F", value: fat) }
                    }
                    .font(.caption2)
                }
            }

            Spacer()

            Text("\(entry.calories) kcal")
                .fontWeight(.semibold)
        }
    }

    private func copyEntry(_ entry: CalorieEntry) {
        entryClipboard.copy(entry)
    }

    private func loadFirstPage() {
        entries = []
        fetchPage(offset: 0)
    }

    private func loadNextPage() {
        fetchPage(offset: entries.count)
    }

    private func fetchPage(offset: Int) {
        guard !isLoading else { return }

        isLoading = true
        fetchError = nil
        let criteria = searchCriteria

        do {
            var descriptor: FetchDescriptor<CalorieEntry>

            if criteria.filtersSinceDate {
                let query = criteria.query
                let startDate = criteria.sinceDate
                descriptor = FetchDescriptor(
                    predicate: #Predicate { entry in
                        (query.isEmpty || entry.name.localizedStandardContains(query)) && entry.date >= startDate
                    },
                    sortBy: [SortDescriptor(\CalorieEntry.date, order: .reverse)]
                )
            } else {
                let query = criteria.query
                descriptor = FetchDescriptor(
                    predicate: #Predicate { entry in
                        query.isEmpty || entry.name.localizedStandardContains(query)
                    },
                    sortBy: [SortDescriptor(\CalorieEntry.date, order: .reverse)]
                )
            }

            descriptor.fetchOffset = offset
            descriptor.fetchLimit = Self.pageSize + 1

            var page = try modelContext.fetch(descriptor)
            hasMoreResults = page.count > Self.pageSize
            if hasMoreResults {
                page.removeLast()
            }
            entries.append(contentsOf: page)
        } catch {
            fetchError = error.localizedDescription
            hasMoreResults = false
        }

        isLoading = false
    }
}
