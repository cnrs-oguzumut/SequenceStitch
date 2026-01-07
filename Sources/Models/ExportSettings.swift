import Foundation

/// Available output video formats
enum OutputFormat: String, CaseIterable, Identifiable {
    case mp4 = "MP4"
    case mov = "MOV"
    case webm = "WebM"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .mov: return "mov"
        case .webm: return "webm"
        }
    }
    
    var codec: String {
        switch self {
        case .mp4, .mov: return "libx264"
        case .webm: return "libvpx-vp9"
        }
    }
    
    var hardwareCodec: String? {
        switch self {
        case .mp4, .mov: return "h264_videotoolbox"
        case .webm: return nil  // No hardware encoder for VP9 on Mac
        }
    }
}

/// Resolution scale options
enum ResolutionScale: String, CaseIterable, Identifiable {
    case original = "Original"
    case scale2x = "2x"
    case scale4x = "4x"
    case hd720 = "720p"
    case hd1080 = "1080p"
    case uhd4k = "4K"
    
    var id: String { rawValue }
    
    /// Returns the FFmpeg scale filter or nil for original
    func scaleFilter(originalWidth: Int, originalHeight: Int) -> String? {
        switch self {
        case .original:
            return nil
        case .scale2x:
            return "scale=\(originalWidth * 2):\(originalHeight * 2)"
        case .scale4x:
            return "scale=\(originalWidth * 4):\(originalHeight * 4)"
        case .hd720:
            return "scale=-2:720"
        case .hd1080:
            return "scale=-2:1080"
        case .uhd4k:
            return "scale=-2:2160"
        }
    }
}

/// Quality presets
enum QualityPreset: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case lossless = "Lossless"
    
    var id: String { rawValue }
    
    /// CRF value for libx264 (lower = better quality, larger file)
    var crf: Int {
        switch self {
        case .low: return 28
        case .medium: return 23
        case .high: return 18
        case .lossless: return 0
        }
    }
    
    /// Preset speed for libx264
    var preset: String {
        switch self {
        case .low: return "faster"
        case .medium: return "medium"
        case .high: return "slow"
        case .lossless: return "veryslow"
        }
    }
}

/// Frame rate options
enum FrameRateOption: Int, CaseIterable, Identifiable {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60
    
    var id: Int { rawValue }
    
    var displayName: String {
        "\(rawValue) fps"
    }
}

/// Video stacking mode for comparison
enum StackingMode: String, CaseIterable, Identifiable {
    case none = "None (Single)"
    case horizontal = "Side-by-Side"
    case vertical = "Top-Bottom"

    var id: String { rawValue }
}

/// Normalization resolution for comparison mode
enum NormalizationResolution: String, CaseIterable, Identifiable {
    case original = "Original (No Letterbox)"
    case hd720 = "720p (1280x720)"
    case hd1080 = "1080p (1920x1080)"
    case uhd4k = "4K (3840x2160)"

    var id: String { rawValue }

    var dimensions: (width: Int, height: Int)? {
        switch self {
        case .original:
            return nil
        case .hd720:
            return (1280, 720)
        case .hd1080:
            return (1920, 1080)
        case .uhd4k:
            return (3840, 2160)
        }
    }
}

/// Complete export settings
class ExportSettings: ObservableObject {
    @Published var format: OutputFormat = .mp4
    @Published var resolution: ResolutionScale = .original
    @Published var quality: QualityPreset = .high
    @Published var frameRate: FrameRateOption = .fps30
    @Published var useHardwareEncoding: Bool = false
    @Published var stackingMode: StackingMode = .none
    @Published var stackingSpacing: Int = 0  // Spacing between stacked sequences in pixels (-200 to 200, negative = overlap)
    @Published var normalizationResolution: NormalizationResolution = .hd720 {  // Target resolution for comparison mode normalization
        didSet {
            previewRefreshTrigger += 1
        }
    }
    @Published var previewRefreshTrigger: Int = 0  // Increments to force preview refresh
}
