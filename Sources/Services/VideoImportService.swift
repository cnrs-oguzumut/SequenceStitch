import Foundation
import AVFoundation

/// Service for importing video frames using FFmpeg
class VideoImportService {
    
    /// Helper to get video duration in seconds
    private static func getVideoDuration(from url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return duration.seconds
        } catch {
            print("Failed to get duration: \(error)")
            return nil
        }
    }
    
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
        
        // Get duration for progress calculation
        let totalDuration = await getVideoDuration(from: videoURL) ?? 0
        
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
            "-progress", "pipe:2", // Output progress info to stderr
            "-nostats", // Reduce noise
            outputPattern
        ]
        
        // Capture output
        let pipe = Pipe()
        process.standardError = pipe
        
        // Accumulate output for error reporting
        var fullOutput = ""
        
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            
            fullOutput += output
            
            if totalDuration > 0 {
                // Look for time=HH:MM:SS.ss (standard FFmpeg progress format)
                let pattern = "time=(\\d{2}):(\\d{2}):(\\d{2}\\.\\d+)"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)) {
                    
                    let nsString = output as NSString
                    let h = Double(nsString.substring(with: match.range(at: 1))) ?? 0
                    let m = Double(nsString.substring(with: match.range(at: 2))) ?? 0
                    let s = Double(nsString.substring(with: match.range(at: 3))) ?? 0
                    
                    let currentSeconds = (h * 3600) + (m * 60) + s
                    let progress = min(max(currentSeconds / totalDuration, 0.0), 1.0)
                    
                    progressHandler(progress)
                }
            }
        }
        
        try await withTaskCancellationHandler {
            try process.run()
            process.waitUntilExit()
            // Cleanup handler
            pipe.fileHandleForReading.readabilityHandler = nil
        } onCancel: {
            process.terminate()
            pipe.fileHandleForReading.readabilityHandler = nil
        }
        
        if process.terminationStatus != 0 {
            // Parse the output to find the actual error message
            let lines = fullOutput.components(separatedBy: .newlines)
            let errorLines = lines.filter { line in
                line.contains("Error") || line.contains("Invalid") || line.contains("failed")
            }
            
            let cleanMessage = errorLines.last ?? lines.last ?? "Unknown FFmpeg error"
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
