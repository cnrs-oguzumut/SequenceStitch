import SwiftUI
import UniformTypeIdentifiers

struct ImageGridView: View {
    @EnvironmentObject var sequenceManager: SequenceManager
    @Binding var draggedItem: SequenceItem?
    var isSecondary: Bool = false
    @State private var isDropTargeted = false
    @State private var isEditMode = true
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]
    
    private let supportedTypes: [UTType] = [
        .png, .jpeg, .pdf, .image, .movie, .mpeg4Movie, .quickTimeMovie
    ]

    private var currentItems: [SequenceItem] {
        isSecondary ? sequenceManager.secondaryItems : sequenceManager.items
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if currentItems.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
        .onDrop(of: supportedTypes, isTargeted: $isDropTargeted) { providers in
            handleExternalDrop(providers: providers)
            return true
        }
        .overlay {
            if isDropTargeted {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.2, green: 0.5, blue: 0.9).opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            Color(red: 0.3, green: 0.6, blue: 1.0),
                            style: StrokeStyle(lineWidth: 3, dash: [10, 5])
                        )
                }
                .padding(8)
                .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.3), Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "photo.stack")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.3, green: 0.6, blue: 1.0), Color(red: 0.5, green: 0.7, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Drop Images or Video Here")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text("PNG, JPEG, PDF, MP4, MOV")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                ForEach(["Images", "PDF", "Video"], id: \.self) { format in
                    Text(format)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(40)
    }
    
    // MARK: - List View with Reordering
    
    private var listView: some View {
        List {
            ForEach(Array(currentItems.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 16) {
                    // Sequence number
                    Text("\(index + 1)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 40)
                    
                    // Thumbnail
                    Image(nsImage: item.thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.originalFilename)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(item.dateCreated.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if item.isFromPDF {
                            Label("Converted from PDF", systemImage: "doc.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    // Delete button
                    Button {
                        withAnimation {
                            sequenceManager.removeItem(withId: item.id, fromSecondary: isSecondary)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
            }
            .onMove { source, destination in
                sequenceManager.moveItem(from: source, to: destination, inSecondary: isSecondary)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
    
    // MARK: - Drop Handling for External Files
    
    private func handleExternalDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // Try PDF first
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, error in
                    guard let url = url else { return }
                    processPDF(at: url)
                }
            }
            // Then videos
            else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    guard let url = url else { return }
                    processVideo(at: url)
                }
            }
            // Then images
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                    guard let url = url else { return }
                    processImage(at: url)
                }
            }
        }
    }
    
    private func processVideo(at tempURL: URL) {
        // Create permanent copy of video to extract from
        // Actually VideoImportService can read from any URL, but loadFileRepresentation gives a temporary URL that might expire?
        // It's safer to copy if we needed it later, but for extraction we just need it now.
        // However, loadFileRepresentation docs say the file is deleted when the completion handler returns?
        // "This file is deleted when the completion handler returns." -> YES.
        // So we MUST copy it.
        
        let ext = tempURL.pathExtension.lowercased()
        
        // Strict Validation: Silent ignore for unsupported containers (like MKV)
        // Only accept MP4, MOV, M4V
        let supportedVideoExtensions = ["mp4", "mov", "m4v"]
        guard supportedVideoExtensions.contains(ext) else {
            return // Do nothing, just like dropping a python file
        }
        
        let permanentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
            
        let toSecondary = isSecondary
        
        do {
            try FileManager.default.copyItem(at: tempURL, to: permanentURL)
            
            // Check file size (limit to 500MB)
            if let resources = try? permanentURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resources.fileSize, fileSize > 500 * 1024 * 1024 {
                
                try? FileManager.default.removeItem(at: permanentURL) // Cleanup
                
                Task { @MainActor in
                    sequenceManager.exportError = "Whoa, that's a huge file! 🐘\nPlease use videos under 500MB."
                }
                return
            }
            
            // Trigger import UI state
            // Trigger import UI state and start task on MainActor
            Task { @MainActor in
                sequenceManager.isImportingVideo = true
                sequenceManager.importProgress = 0
                
                sequenceManager.importTask = Task {
                    do {
                        // 1. Extract Frames (Background Process)
                        // This task now inherits MainActor, but extractFrames uses Process so it doesn't block.
                        
                        let frameURLs = try await VideoImportService.extractFrames(from: permanentURL) { progress in
                            // Scaling extraction to 0.0 - 0.5 of total progress
                            Task { @MainActor in
                                self.sequenceManager.importProgress = progress * 0.5
                            }
                        }
                        
                        // 2. Process Frames (Thumbnail Gen) - HEAVY WORK
                        // Run explicitly in background to avoid Main Actor blocking (Spinning Wheel)
                        let items = await Task.detached(priority: .userInitiated) { () -> [SequenceItem] in
                            var newItems: [SequenceItem] = []
                            let sourceName = permanentURL.lastPathComponent
                            let totalFrames = Double(frameURLs.count)
                            
                            for (index, url) in frameURLs.enumerated() {
                                // Helper to generate thumbnail (Processor is likely thread safe if standard PDFKit/CG)
                                if let thumbnail = PDFProcessor.createThumbnail(from: url) {
                                    let item = SequenceItem(
                                        originalURL: url,
                                        processedURL: url,
                                        thumbnail: thumbnail,
                                        dateCreated: Date(),
                                        originalFilename: "\(sourceName)_frame_\(String(format: "%04d", index + 1))",
                                        isFromPDF: false
                                    )
                                    newItems.append(item)
                                }
                                
                                // Update progress periodically (e.g. every 10 frames)
                                if index % 10 == 0 {
                                    // We can't easily capture 'sequenceManager' here safely if it's MainActor isolated
                                    // So we skip granular progress updates for now to avoid complexity/crashes
                                }
                            }
                            return newItems
                        }.value
                        
                        // Update Progress to 100% just before showing
                        // We are already on MainActor in this outer Task (inherited), but explicit check doesn't hurt.
                        sequenceManager.importProgress = 1.0
                        sequenceManager.addItems(items, toSecondary: toSecondary)
                        sequenceManager.isImportingVideo = false
                        
                        // Cleanup video file
                        try? FileManager.default.removeItem(at: permanentURL)
                        
                    } catch {
                        print("Video processing error: \(error)")
                        if !Task.isCancelled {
                            sequenceManager.isImportingVideo = false
                            sequenceManager.exportError = "Import Failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
                    

        } catch {
            print("Video copy error: \(error)")
        }
    }
    
    private func processPDF(at tempURL: URL) {
        let permanentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        let toSecondary = isSecondary

        do {
            try FileManager.default.copyItem(at: tempURL, to: permanentURL)

            let processedURL = try PDFProcessor.renderFirstPage(of: permanentURL, dpi: 300)

            guard let thumbnail = PDFProcessor.createThumbnail(from: processedURL) else {
                return
            }

            let dateCreated = PDFProcessor.getCreationDate(of: permanentURL)

            let item = SequenceItem(
                originalURL: permanentURL,
                processedURL: processedURL,
                thumbnail: thumbnail,
                dateCreated: dateCreated,
                originalFilename: tempURL.lastPathComponent,
                isFromPDF: true
            )

            Task { @MainActor in
                sequenceManager.addItem(item, toSecondary: toSecondary)
            }

            try? FileManager.default.removeItem(at: permanentURL)

        } catch {
            print("PDF processing error: \(error)")
        }
    }
    
    private func processImage(at tempURL: URL) {
        let ext = tempURL.pathExtension.isEmpty ? "png" : tempURL.pathExtension
        let permanentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)

        let toSecondary = isSecondary

        do {
            try FileManager.default.copyItem(at: tempURL, to: permanentURL)

            guard let thumbnail = PDFProcessor.createThumbnail(from: permanentURL) else {
                return
            }

            let dateCreated = PDFProcessor.getCreationDate(of: permanentURL)

            let item = SequenceItem(
                originalURL: permanentURL,
                processedURL: permanentURL,
                thumbnail: thumbnail,
                dateCreated: dateCreated,
                originalFilename: tempURL.lastPathComponent,
                isFromPDF: false
            )

            Task { @MainActor in
                sequenceManager.addItem(item, toSecondary: toSecondary)
            }
        } catch {
            print("Image processing error: \(error)")
        }
    }
}

#Preview {
    ImageGridView(draggedItem: .constant(nil))
        .environmentObject(SequenceManager())
        .frame(width: 800, height: 600)
}
