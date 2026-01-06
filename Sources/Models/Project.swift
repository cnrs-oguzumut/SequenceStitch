import Foundation

/// Represents a saved project that can be serialized
struct SequenceProject: Codable {
    var version: Int = 1
    var frameDuration: Double
    var exportSettings: ExportSettingsCodable
    var items: [ProjectItem]
    
    @MainActor
    init(from manager: SequenceManager) {
        self.frameDuration = manager.frameDuration
        self.exportSettings = ExportSettingsCodable(from: manager.exportSettings)
        self.items = manager.items.map { ProjectItem(from: $0) }
    }
}

/// Codable wrapper for ExportSettings
struct ExportSettingsCodable: Codable {
    var format: String
    var resolution: String
    var quality: String
    var frameRate: Int
    var useHardwareEncoding: Bool
    
    init(from settings: ExportSettings) {
        self.format = settings.format.rawValue
        self.resolution = settings.resolution.rawValue
        self.quality = settings.quality.rawValue
        self.frameRate = settings.frameRate.rawValue
        self.useHardwareEncoding = settings.useHardwareEncoding
    }
    
    func toExportSettings() -> ExportSettings {
        var settings = ExportSettings()
        settings.format = OutputFormat(rawValue: format) ?? .mp4
        settings.resolution = ResolutionScale(rawValue: resolution) ?? .original
        settings.quality = QualityPreset(rawValue: quality) ?? .high
        settings.frameRate = FrameRateOption(rawValue: frameRate) ?? .fps30
        settings.useHardwareEncoding = useHardwareEncoding
        return settings
    }
}

/// Codable representation of a sequence item
struct ProjectItem: Codable {
    let originalPath: String
    let processedPath: String
    let originalFilename: String
    let dateCreated: Date
    let isFromPDF: Bool
    
    init(from item: SequenceItem) {
        self.originalPath = item.originalURL.path
        self.processedPath = item.processedURL.path
        self.originalFilename = item.originalFilename
        self.dateCreated = item.dateCreated
        self.isFromPDF = item.isFromPDF
    }
}

/// Manages project file operations
enum ProjectManager {
    static let fileExtension = "seqstitch"
    
    /// Saves the current project to a file
    @MainActor
    static func save(_ manager: SequenceManager, to url: URL) throws {
        let project = SequenceProject(from: manager)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(project)
        try data.write(to: url)
    }
    
    /// Loads a project from a file
    static func load(from url: URL, into manager: SequenceManager) async throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let project = try decoder.decode(SequenceProject.self, from: data)
        
        await MainActor.run {
            manager.clearAll()
            manager.frameDuration = project.frameDuration
            manager.exportSettings = project.exportSettings.toExportSettings()
        }
        
        // Reload images
        for item in project.items {
            let processedURL = URL(fileURLWithPath: item.processedPath)
            
            guard FileManager.default.fileExists(atPath: processedURL.path),
                  let thumbnail = PDFProcessor.createThumbnail(from: processedURL) else {
                continue
            }
            
            let sequenceItem = SequenceItem(
                originalURL: URL(fileURLWithPath: item.originalPath),
                processedURL: processedURL,
                thumbnail: thumbnail,
                dateCreated: item.dateCreated,
                originalFilename: item.originalFilename,
                isFromPDF: item.isFromPDF
            )
            
            await MainActor.run {
                manager.addItem(sequenceItem)
            }
        }
    }
}
