import SwiftUI

struct ClipboardHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entryClipboard: EntryClipboard

    let onPaste: ([CopiedEntry]) -> Void

    @State private var selectedEntryIDs: Set<UUID> = []

    private var selectedEntries: [CopiedEntry] {
        entryClipboard.entries.filter { selectedEntryIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(entryClipboard.entries) { entry in
                    Button {
                        toggleSelection(of: entry)
                    } label: {
                        clipboardRow(entry)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            selectedEntryIDs.remove(entry.id)
                            entryClipboard.remove(entry)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    entryClipboard.clear()
                    dismiss()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(radius: 4, x: 0, y: 3)
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Clipboard History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Paste \(selectedEntries.count)") {
                        onPaste(selectedEntries)
                        dismiss()
                    }
                    .disabled(selectedEntries.isEmpty)
                    .accessibilityLabel(
                        "Paste \(selectedEntries.count) \(selectedEntries.count == 1 ? "Food" : "Foods")"
                    )
                }
            }
        }
    }

    private func clipboardRow(_ entry: CopiedEntry) -> some View {
        let isSelected = selectedEntryIDs.contains(entry.id)

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("\(entry.calories) kcal")
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                if entry.protein != nil || entry.carbs != nil || entry.fat != nil || entry.grams != nil {
                    HStack(spacing: 8) {
                        if let protein = entry.protein { MacroText(label: "Protein", value: protein) }
                        if let fat = entry.fat { MacroText(label: "Fat", value: fat) }
                        if let carbs = entry.carbs { MacroText(label: "Carbs", value: carbs) }

                        Spacer(minLength: 8)

                        if let grams = entry.grams {
                            Text("\(grams.formatted(.number.precision(.fractionLength(0...2)))) g")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.orange : Color.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func toggleSelection(of entry: CopiedEntry) {
        if !selectedEntryIDs.insert(entry.id).inserted {
            selectedEntryIDs.remove(entry.id)
        }
    }
}
