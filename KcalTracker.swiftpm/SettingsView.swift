import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var transferManager = DataTransferManager()
    
    @State private var showingExportError = false
    @State private var exportError: Error?
    
    @State private var showingImportPicker = false
    @State private var showingImportError = false
    @State private var importError: Error?
    @State private var importSuccess = false
    
    @State private var exportDocument: AppDataDocument?
    @State private var showingFileExporter = false
    
    var body: some View {
        Form {
            Section(header: Text("Data Management")) {
                Button(action: prepareExport) {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }
                
                Button(action: { showingImportPicker = true }) {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                }
            }
            
            Section(footer: Text("Export your entries and foods to a JSON file. Import allows merging backed up JSON files. Duplicates identified by ID are ignored.")) {
                EmptyView()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showingFileExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "KcalTrackerBackup"
        ) { result in
            switch result {
            case .success(let url):
                print("Saved to \(url)")
            case .failure(let error):
                exportError = error
                showingExportError = true
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                performImport(from: url)
            case .failure(let error):
                importError = error
                showingImportError = true
            }
        }
        .alert("Export Failed", isPresented: $showingExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError?.localizedDescription ?? "Unknown error occurred.")
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError?.localizedDescription ?? "Unknown error occurred.")
        }
        .alert("Import Successful", isPresented: $importSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your data has been merged successfully.")
        }
    }
    
    private func prepareExport() {
        do {
            let doc = try transferManager.generateExportData(context: modelContext)
            exportDocument = doc
            showingFileExporter = true
        } catch {
            exportError = error
            showingExportError = true
        }
    }
    
    private func performImport(from url: URL) {
        do {
            try transferManager.importData(from: url, context: modelContext)
            importSuccess = true
        } catch {
            importError = error
            showingImportError = true
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
