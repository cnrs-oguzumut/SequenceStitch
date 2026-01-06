import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var sequenceManager: SequenceManager
    @StateObject private var exporter = VideoExporter()
    @State private var showingSavePanel = false
    @State private var showingPreview = false
    @State private var draggedItem: SequenceItem?
    @State private var isImportingFolder = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(exporter: exporter, showingExportPanel: $showingSavePanel)
                .frame(minWidth: 280)
        } detail: {
            ImageGridView(draggedItem: $draggedItem)
                .frame(minWidth: 600)
        }
        .navigationSplitViewStyle(.prominentDetail)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            // Left side - Import actions
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    openFolder()
                } label: {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .help("Import all images from a folder")
            }
            
            // Center - Playback
            ToolbarItem(placement: .principal) {
                Button {
                    showingPreview = true
                } label: {
                    Label("Preview", systemImage: "play.fill")
                }
                .help("Preview sequence")
                .disabled(sequenceManager.items.isEmpty)
            }
            
            // Right side - Project and sorting
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button {
                        saveProject()
                    } label: {
                        Label("Save Project...", systemImage: "square.and.arrow.down")
                    }
                    .disabled(sequenceManager.items.isEmpty)
                    
                    Button {
                        loadProject()
                    } label: {
                        Label("Open Project...", systemImage: "doc.badge.arrow.up")
                    }
                } label: {
                    Label("Project", systemImage: "doc.fill")
                }
                .help("Save or load project")
                
                Menu {
                    Button {
                        sequenceManager.sort(by: .dateCreated)
                    } label: {
                        Label("Date Created", systemImage: "calendar")
                    }
                    
                    Button {
                        sequenceManager.sort(by: .filename)
                    } label: {
                        Label("Filename", systemImage: "textformat.abc")
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort images")
                
                Button(role: .destructive) {
                    sequenceManager.clearAll()
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .help("Remove all images")
                .disabled(sequenceManager.items.isEmpty)
            }
        }
        .onChange(of: showingSavePanel) { _, newValue in
            if newValue {
                showExportSavePanel()
            }
        }
        .sheet(isPresented: $showingPreview) {
            PreviewView()
                .environmentObject(sequenceManager)
        }
        .alert("Export Error", isPresented: .init(
            get: { sequenceManager.exportError != nil },
            set: { if !$0 { sequenceManager.exportError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(sequenceManager.exportError ?? "Unknown error")
        }
    }
    
    // MARK: - Open Folder
    
    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing images"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            importFolder(at: url)
        }
    }
    
    private func importFolder(at folderURL: URL) {
        Task {
            let fileManager = FileManager.default
            let supportedExtensions = ["png", "jpg", "jpeg", "pdf", "heic", "tiff", "gif"]
            
            guard let enumerator = fileManager.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else { return }
            
            var files: [(url: URL, date: Date)] = []
            
            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()
                if supportedExtensions.contains(ext) {
                    let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path)
                    let date = attrs?[.creationDate] as? Date ?? Date()
                    files.append((fileURL, date))
                }
            }
            
            // Sort by name
            files.sort { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
            
            // Process each file
            for file in files {
                await processFile(at: file.url, createdAt: file.date)
            }
        }
    }
    
    private func processFile(at url: URL, createdAt: Date) async {
        let ext = url.pathExtension.lowercased()
        
        if ext == "pdf" {
            await processPDF(at: url, createdAt: createdAt)
        } else {
            await processImage(at: url, createdAt: createdAt)
        }
    }
    
    private func processPDF(at url: URL, createdAt: Date) async {
        do {
            let processedURL = try PDFProcessor.renderFirstPage(of: url, dpi: 300)
            
            guard let thumbnail = PDFProcessor.createThumbnail(from: processedURL) else { return }
            
            let item = SequenceItem(
                originalURL: url,
                processedURL: processedURL,
                thumbnail: thumbnail,
                dateCreated: createdAt,
                originalFilename: url.lastPathComponent,
                isFromPDF: true
            )
            
            await MainActor.run {
                sequenceManager.addItem(item)
            }
        } catch {
            print("PDF processing error: \(error)")
        }
    }
    
    private func processImage(at url: URL, createdAt: Date) async {
        guard let thumbnail = PDFProcessor.createThumbnail(from: url) else { return }
        
        let item = SequenceItem(
            originalURL: url,
            processedURL: url,
            thumbnail: thumbnail,
            dateCreated: createdAt,
            originalFilename: url.lastPathComponent,
            isFromPDF: false
        )
        
        await MainActor.run {
            sequenceManager.addItem(item)
        }
    }
    
    // MARK: - Export
    
    private func showExportSavePanel() {
        let format = sequenceManager.exportSettings.format
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [contentType(for: format)]
        savePanel.nameFieldStringValue = "SequenceStitch_Output.\(format.fileExtension)"
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        
        savePanel.begin { response in
            showingSavePanel = false
            
            if response == .OK, let url = savePanel.url {
                exportVideo(to: url)
            }
        }
    }
    
    private func contentType(for format: OutputFormat) -> UTType {
        switch format {
        case .mp4: return .mpeg4Movie
        case .mov: return .quickTimeMovie
        case .webm: return UTType(filenameExtension: "webm") ?? .movie
        }
    }
    
    private func exportVideo(to url: URL) {
        sequenceManager.isExporting = true
        sequenceManager.exportProgress = 0
        
        Task {
            do {
                try await exporter.export(
                    items: sequenceManager.items,
                    frameDuration: sequenceManager.frameDuration,
                    settings: sequenceManager.exportSettings,
                    outputURL: url
                ) { progress in
                    Task { @MainActor in
                        sequenceManager.exportProgress = progress
                    }
                }
                
                await MainActor.run {
                    sequenceManager.isExporting = false
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } catch {
                await MainActor.run {
                    sequenceManager.isExporting = false
                    sequenceManager.exportError = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Project Save/Load
    
    private func saveProject() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: ProjectManager.fileExtension) ?? .json]
        savePanel.nameFieldStringValue = "MyProject.\(ProjectManager.fileExtension)"
        savePanel.canCreateDirectories = true
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            
            do {
                try ProjectManager.save(sequenceManager, to: url)
            } catch {
                sequenceManager.exportError = "Failed to save project: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadProject() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [UTType(filenameExtension: ProjectManager.fileExtension) ?? .json]
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else { return }
            
            Task {
                do {
                    try await ProjectManager.load(from: url, into: sequenceManager)
                } catch {
                    await MainActor.run {
                        sequenceManager.exportError = "Failed to load project: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SequenceManager())
        .frame(width: 1000, height: 700)
}
