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
    @Published var secondaryItems: [SequenceItem] = []  // For comparison mode
    @Published var isComparisonMode: Bool = false {
        didSet {
            // Auto-set stacking mode
            if isComparisonMode && exportSettings.stackingMode == .none {
                exportSettings.stackingMode = .horizontal
            } else if !isComparisonMode {
                exportSettings.stackingMode = .none
            }
        }
    }
    @Published var frameDuration: Double = 2.0 // seconds per frame
    @Published var isTimeLapseMode: Bool = false // Time-lapse calculator mode
    @Published var targetDuration: Double = 30.0 // Target total video duration in seconds
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var exportError: String?
    @Published var exportSettings = ExportSettings()
    
    // Computed frame duration for time-lapse mode
    var effectiveFrameDuration: Double {
        if isTimeLapseMode && items.count > 0 {
            return targetDuration / Double(items.count)
        }
        return frameDuration
    }
    
    // Import State
    @Published var isImportingVideo: Bool = false
    @Published var importProgress: Double = 0.0
    @Published var importTask: Task<Void, Never>?
    
    enum SortOption {
        case dateCreated
        case filename
    }
    
    func addItem(_ item: SequenceItem, toSecondary: Bool = false) {
        if toSecondary && isComparisonMode {
            secondaryItems.append(item)
        } else {
            items.append(item)
        }
    }
    
    func addItems(_ newItems: [SequenceItem], toSecondary: Bool = false) {
        if toSecondary && isComparisonMode {
            secondaryItems.append(contentsOf: newItems)
        } else {
            items.append(contentsOf: newItems)
        }
    }

    func removeItem(at index: Int, fromSecondary: Bool = false) {
        if fromSecondary {
            guard index >= 0 && index < secondaryItems.count else { return }
            let item = secondaryItems.remove(at: index)
            if item.isFromPDF {
                try? FileManager.default.removeItem(at: item.processedURL)
            }
        } else {
            guard index >= 0 && index < items.count else { return }
            let item = items.remove(at: index)
            if item.isFromPDF {
                try? FileManager.default.removeItem(at: item.processedURL)
            }
        }
    }

    func removeItem(withId id: UUID, fromSecondary: Bool = false) {
        if fromSecondary {
            if let index = secondaryItems.firstIndex(where: { $0.id == id }) {
                removeItem(at: index, fromSecondary: true)
            }
        } else {
            if let index = items.firstIndex(where: { $0.id == id }) {
                removeItem(at: index, fromSecondary: false)
            }
        }
    }

    func moveItem(from source: IndexSet, to destination: Int, inSecondary: Bool = false) {
        if inSecondary {
            secondaryItems.move(fromOffsets: source, toOffset: destination)
        } else {
            items.move(fromOffsets: source, toOffset: destination)
        }
    }

    func sort(by option: SortOption) {
        switch option {
        case .dateCreated:
            items.sort { $0.dateCreated < $1.dateCreated }
            secondaryItems.sort { $0.dateCreated < $1.dateCreated }
        case .filename:
            items.sort { $0.originalFilename.localizedStandardCompare($1.originalFilename) == .orderedAscending }
            secondaryItems.sort { $0.originalFilename.localizedStandardCompare($1.originalFilename) == .orderedAscending }
        }
    }

    func clearAll() {
        for item in items where item.isFromPDF {
            try? FileManager.default.removeItem(at: item.processedURL)
        }
        items.removeAll()

        for item in secondaryItems where item.isFromPDF {
            try? FileManager.default.removeItem(at: item.processedURL)
        }
        secondaryItems.removeAll()
    }
}
