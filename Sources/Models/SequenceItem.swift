import AppKit
import Foundation

/// Represents a single image in the sequence
struct SequenceItem: Identifiable, Equatable {
    let id: UUID
    let originalURL: URL
    let processedURL: URL
    let thumbnail: NSImage
    let dateCreated: Date
    let originalFilename: String
    let isFromPDF: Bool
    
    init(
        id: UUID = UUID(),
        originalURL: URL,
        processedURL: URL? = nil,
        thumbnail: NSImage,
        dateCreated: Date,
        originalFilename: String,
        isFromPDF: Bool = false
    ) {
        self.id = id
        self.originalURL = originalURL
        self.processedURL = processedURL ?? originalURL
        self.thumbnail = thumbnail
        self.dateCreated = dateCreated
        self.originalFilename = originalFilename
        self.isFromPDF = isFromPDF
    }
    
    static func == (lhs: SequenceItem, rhs: SequenceItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages the sequence of items and provides sorting/reordering
@MainActor
class SequenceManager: ObservableObject {
    @Published var items: [SequenceItem] = []
    @Published var frameDuration: Double = 2.0 // seconds per frame
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var exportError: String?
    @Published var exportSettings = ExportSettings()
    
    enum SortOption {
        case dateCreated
        case filename
    }
    
    func addItem(_ item: SequenceItem) {
        items.append(item)
    }
    
    func removeItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        let item = items.remove(at: index)
        
        // Clean up temporary files from PDF conversion
        if item.isFromPDF {
            try? FileManager.default.removeItem(at: item.processedURL)
        }
    }
    
    func removeItem(withId id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            removeItem(at: index)
        }
    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }
    
    func sort(by option: SortOption) {
        switch option {
        case .dateCreated:
            items.sort { $0.dateCreated < $1.dateCreated }
        case .filename:
            items.sort { $0.originalFilename.localizedStandardCompare($1.originalFilename) == .orderedAscending }
        }
    }
    
    func clearAll() {
        // Clean up any temporary PDF conversions
        for item in items where item.isFromPDF {
            try? FileManager.default.removeItem(at: item.processedURL)
        }
        items.removeAll()
    }
}
