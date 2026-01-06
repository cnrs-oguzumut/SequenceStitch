import SwiftUI
import UniformTypeIdentifiers

struct ImageGridView: View {
    @EnvironmentObject var sequenceManager: SequenceManager
    @Binding var draggedItem: SequenceItem?
    @State private var isDropTargeted = false
    @State private var isEditMode = true
    
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]
    
    private let supportedTypes: [UTType] = [
        .png, .jpeg, .pdf, .image
    ]
    
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
            
            if sequenceManager.items.isEmpty {
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
                Text("Drop Images Here")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text("PNG, JPEG, or PDF files")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                ForEach(["PNG", "JPEG", "PDF"], id: \.self) { format in
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
            ForEach(Array(sequenceManager.items.enumerated()), id: \.element.id) { index, item in
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
                            sequenceManager.removeItem(withId: item.id)
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
                sequenceManager.items.move(fromOffsets: source, toOffset: destination)
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
            // Then images
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                    guard let url = url else { return }
                    processImage(at: url)
                }
            }
        }
    }
    
    private func processPDF(at tempURL: URL) {
        let permanentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        
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
                sequenceManager.addItem(item)
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
                sequenceManager.addItem(item)
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
