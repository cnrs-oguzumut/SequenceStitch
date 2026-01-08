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

            VStack(spacing: 0) {
                // Comparison mode toolbar
                HStack {
                    Toggle(isOn: $sequenceManager.isComparisonMode) {
                        Label("Comparison Mode", systemImage: "square.split.2x1")
                    }
                    .toggleStyle(.switch)

                    Spacer()

                    if sequenceManager.isComparisonMode {
                        Picker("Stacking", selection: $sequenceManager.exportSettings.stackingMode) {
                            ForEach(StackingMode.allCases.filter { $0 != .none }) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .frame(width: 150)

                        if sequenceManager.exportSettings.stackingMode != .none {
                            Text("Spacing:")
                                .foregroundColor(.secondary)

                            Slider(value: Binding(
                                get: { Double(sequenceManager.exportSettings.stackingSpacing) },
                                set: { sequenceManager.exportSettings.stackingSpacing = Int($0) }
                            ), in: 0...200, step: 1)
                            .frame(width: 120)

                            Text("\(sequenceManager.exportSettings.stackingSpacing)px")
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))

                // Main content area
                if sequenceManager.isComparisonMode {
                    VStack(spacing: 0) {
                        // Preview section
                        if sequenceManager.exportSettings.stackingMode != .none {
                            VStack(spacing: 4) {
                                Text("Stacking Preview")
                                    .font(.headline)
                                    .padding(.top, 8)

                                ComparisonPreviewView(exportSettings: sequenceManager.exportSettings)
                                    .frame(height: 200)
                                    .background(Color.black)
                                    .cornerRadius(4)
                                    .padding(.horizontal, 8)
                                    .padding(.bottom, 8)
                                    .id(sequenceManager.exportSettings.previewRefreshTrigger)
                            }
                            .background(Color(nsColor: .controlBackgroundColor))
                        }

                        // Sequence grids
                        HStack(spacing: 2) {
                            VStack {
                                Text("Sequence A (Control)")
                                    .font(.headline)
                                    .padding(.top, 8)
                                ImageGridView(draggedItem: $draggedItem, isSecondary: false)
                            }

                            Divider()

                            VStack {
                                Text("Sequence B (Experiment)")
                                    .font(.headline)
                                    .padding(.top, 8)
                                ImageGridView(draggedItem: $draggedItem, isSecondary: true)
                            }
                        }
                    }
                } else {
                    ImageGridView(draggedItem: $draggedItem, isSecondary: false)
                }
            }
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
                
                if sequenceManager.isComparisonMode {
                    Menu {
                        Button {
                            importVideo(toSecondary: false)
                        } label: {
                            Label("Import to Sequence A", systemImage: "a.square")
                        }
                        
                        Button {
                            importVideo(toSecondary: true)
                        } label: {
                            Label("Import to Sequence B", systemImage: "b.square")
                        }
                    } label: {
                        Label("Import Video", systemImage: "video.badge.plus")
                    }
                    .help("Import frames from video")
                } else {
                    Button {
                        importVideo(toSecondary: false)
                    } label: {
                        Label("Import Video", systemImage: "video.badge.plus")
                    }
                    .help("Import frames from video")
                }
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
        .alert("Notice", isPresented: .init(
            get: { sequenceManager.exportError != nil },
            set: { if !$0 { sequenceManager.exportError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(sequenceManager.exportError ?? "Unknown error")
        }
        .overlay {
            if sequenceManager.isImportingVideo {
                ZStack {
                    Color.black.opacity(0.4)
                    VStack(spacing: 16) {
                        ProgressView(value: sequenceManager.importProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                        
                        Text("Extracting frames... \(Int(sequenceManager.importProgress * 100))%")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button {
                            sequenceManager.importTask?.cancel()
                            sequenceManager.isImportingVideo = false
                        } label: {
                            Text("Stop Import")
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                    .background(Material.regular)
                    .cornerRadius(12)
                }
            }
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
    
    // MARK: - Import Video
    
    private func importVideo(toSecondary: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.movie, UTType.mpeg4Movie, UTType.quickTimeMovie]
        panel.message = "Select a video file to import frames from"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            sequenceManager.isImportingVideo = true
            sequenceManager.importProgress = 0
            
            // Check file size (limit to 500MB)
            if let resources = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resources.fileSize, fileSize > 500 * 1024 * 1024 {
                
                sequenceManager.exportError = "Video is too large (>500MB). Please use a shorter clip."
                sequenceManager.isImportingVideo = false
                return
            }
            
            sequenceManager.importTask = Task {
                do {
                    // Extract frames
                    let frameURLs = try await VideoImportService.extractFrames(from: url) { progress in
                        Task { @MainActor in
                            self.sequenceManager.importProgress = progress
                        }
                    }
                    
                    if frameURLs.isEmpty {
                        throw VideoImportService.ImportError.extractionFailed("No frames were extracted")
                    }
                    
                    await processExtractedFrames(urls: frameURLs, toSecondary: toSecondary, sourceName: url.lastPathComponent)
                    
                    await MainActor.run {
                        sequenceManager.isImportingVideo = false
                    }
                    
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            sequenceManager.isImportingVideo = false
                            sequenceManager.exportError = "Video Import Failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
    
    private func processExtractedFrames(urls: [URL], toSecondary: Bool, sourceName: String) async {
        // Run heavy processing in background to avoid blocking Main Thread
        let newItems = await Task.detached(priority: .userInitiated) { () -> [SequenceItem] in
            var items: [SequenceItem] = []
            
            for (index, url) in urls.enumerated() {
                if let thumbnail = PDFProcessor.createThumbnail(from: url) {
                    let item = SequenceItem(
                        originalURL: url,
                        processedURL: url,
                        thumbnail: thumbnail,
                        dateCreated: Date(),
                        originalFilename: "\(sourceName)_frame_\(String(format: "%04d", index + 1))",
                        isFromPDF: false
                    )
                    items.append(item)
                }
            }
            return items
        }.value
        
        await MainActor.run {
            sequenceManager.importProgress = 1.0
            sequenceManager.addItems(newItems, toSecondary: toSecondary)
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
                    secondaryItems: sequenceManager.secondaryItems,
                    frameDuration: sequenceManager.effectiveFrameDuration,
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
