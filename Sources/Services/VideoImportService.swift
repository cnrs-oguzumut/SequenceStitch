import Foundation

/// Service for importing video frames using FFmpeg
class VideoImportService {
    
    enum ImportError: LocalizedError {
        case ffmpegNotFound
        case extractionFailed(String)
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .ffmpegNotFound:
                return "FFmpeg not found. Please install it via Homebrew: brew install ffmpeg"
            case .extractionFailed(let message):
                return "Frame extraction failed: \(message)"
            case .cancelled:
                return "Import was cancelled"
            }
        }
    }
    
    /// Finds FFmpeg binary - checks bundled version first, then Homebrew/System
    private static func findFFmpeg() -> URL? {
        // 1. Check for bundled FFmpeg in app Resources
        if let resourcePath = Bundle.main.resourcePath {
            let bundledFFmpeg = URL(fileURLWithPath: resourcePath).appendingPathComponent("ffmpeg")
            if FileManager.default.isExecutableFile(atPath: bundledFFmpeg.path) {
                print("Found bundled FFmpeg at: \(bundledFFmpeg.path)")
                return bundledFFmpeg
            }
        }
        
        // 2. Fall back to Homebrew/system paths
        var possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",       // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",          // Intel Homebrew
            "/usr/bin/ffmpeg",                // System
            "/opt/local/bin/ffmpeg"           // MacPorts
        ]
        
        // Add paths from PATH environment variable
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let envPaths = pathEnv.components(separatedBy: ":")
            possiblePaths.append(contentsOf: envPaths.map { $0 + "/ffmpeg" })
        }
        
        // Remove duplicates
        let uniquePaths = Array(Set(possiblePaths))
        
        for path in uniquePaths {
            let isExecutable = FileManager.default.isExecutableFile(atPath: path)
            if isExecutable {
                return URL(fileURLWithPath: path)
            }
        }
        
        return nil
    }
    
    /// Extracts all frames from a video file to a destination directory
    /// Returns: List of extracted image URLs sorted by name
    static func extractFrames(
        from videoURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let ffmpegURL = findFFmpeg() else {
            throw ImportError.ffmpegNotFound
        }
        
        // Create a unique temp directory for this extraction
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Import_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Output pattern: frame_0001.png
        let outputPattern = tempDir.appendingPathComponent("frame_%05d.png").path
        
        // Use mpdecimate to remove duplicates, then resample to target FPS
        // Balanced Approach:
        // 1. fps=10: Higher sampling to catch more motion
        // 2. mpdecimate: Drops frames that are duplicates or very similar (default threshold)
        // 3. -vsync 0: Essential! prevents FFmpeg from re-adding duplicates to match framerate
        let targetFPS = 10
        let filterChain = "fps=\(targetFPS),mpdecimate"
        
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-i", videoURL.path,
            "-vf", filterChain,
            "-vsync", "0",
            outputPattern
        ]
        
        // Capture output
        let pipe = Pipe()
        process.standardError = pipe
        
        try await withTaskCancellationHandler {
            try process.run()
            process.waitUntilExit()
        } onCancel: {
            process.terminate()
        }
        
        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let fullOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            // Parse the output to find the actual error message
            // Look for lines starting with "Error" or containing "Invalid"
            let lines = fullOutput.components(separatedBy: .newlines)
            let errorLines = lines.filter { line in
                line.contains("Error") || line.contains("Invalid") || line.contains("failed")
            }
            
            // Take the last relevant error line, or the last line if nothing specific found
            let cleanMessage = errorLines.last ?? lines.last ?? "Unknown FFmpeg error"
            
            // Remove the file path to make it cleaner if present
            let userMessage = cleanMessage.replacingOccurrences(of: videoURL.path, with: "video file")
            
            throw ImportError.extractionFailed(userMessage)
        }
        
        // Collect results
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        return files
    }
}
