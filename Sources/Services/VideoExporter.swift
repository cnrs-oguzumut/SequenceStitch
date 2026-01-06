import Foundation

/// Service for exporting image sequences to video using FFmpeg
class VideoExporter: ObservableObject {
    
    enum ExporterError: LocalizedError {
        case ffmpegNotFound
        case noImages
        case exportFailed(String)
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .ffmpegNotFound:
                return "FFmpeg not found. Please install it via Homebrew: brew install ffmpeg"
            case .noImages:
                return "No images to export"
            case .exportFailed(let message):
                return "Export failed: \(message)"
            case .cancelled:
                return "Export was cancelled"
            }
        }
    }
    
    private var currentProcess: Process?
    private var isCancelled = false
    
    /// Finds FFmpeg binary in common locations
    private func findFFmpeg() -> URL? {
        let possiblePaths = [
            "/opt/homebrew/bin/ffmpeg",      // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",          // Intel Homebrew
            "/usr/bin/ffmpeg",                // System
        ]
        
        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        return nil
    }
    
    /// Generates the concat demuxer input file
    private func generateConcatFile(
        for items: [SequenceItem],
        duration: Double,
        tempDir: URL
    ) throws -> URL {
        let concatFileURL = tempDir.appendingPathComponent("input.txt")
        
        var content = ""
        for (index, item) in items.enumerated() {
            // Escape single quotes in paths
            let escapedPath = item.processedURL.path.replacingOccurrences(of: "'", with: "'\\''")
            content += "file '\(escapedPath)'\n"
            content += "duration \(duration)\n"
            
            // For the last image, add it again without duration (FFmpeg quirk for concat)
            if index == items.count - 1 {
                content += "file '\(escapedPath)'\n"
            }
        }
        
        try content.write(to: concatFileURL, atomically: true, encoding: .utf8)
        return concatFileURL
    }
    
    /// Builds FFmpeg arguments based on export settings
    private func buildFFmpegArguments(
        concatFile: URL,
        outputURL: URL,
        settings: ExportSettings
    ) -> [String] {
        var args: [String] = []
        
        // Input
        args += ["-f", "concat", "-safe", "0", "-i", concatFile.path]
        
        // Video filters
        var filters: [String] = []
        
        // Frame rate
        filters.append("fps=\(settings.frameRate.rawValue)")
        
        // Resolution scaling (if not original)
        if let scaleFilter = settings.resolution.scaleFilter(originalWidth: 1920, originalHeight: 1080) {
            filters.append(scaleFilter)
        }
        
        if !filters.isEmpty {
            args += ["-vf", filters.joined(separator: ",")]
        }
        
        // Codec selection based on format and hardware preference
        switch settings.format {
        case .mp4, .mov:
            if settings.useHardwareEncoding, let hwCodec = settings.format.hardwareCodec {
                args += ["-c:v", hwCodec]
            } else {
                args += ["-c:v", "libx264"]
                args += ["-preset", settings.quality.preset]
                args += ["-crf", "\(settings.quality.crf)"]
            }
            
        case .webm:
            args += ["-c:v", "libvpx-vp9"]
            // VP9 quality settings
            let crf = settings.quality.crf
            args += ["-crf", "\(crf)", "-b:v", "0"]
        }
        
        // Pixel format for compatibility
        args += ["-pix_fmt", "yuv420p"]
        
        // Fast start for MP4/MOV (enables streaming)
        if settings.format == .mp4 || settings.format == .mov {
            args += ["-movflags", "+faststart"]
        }
        
        // Overwrite output
        args += ["-y", outputURL.path]
        
        return args
    }
    
    /// Exports sequence to video
    func export(
        items: [SequenceItem],
        frameDuration: Double,
        settings: ExportSettings,
        outputURL: URL,
        progressHandler: @escaping (Double) -> Void
    ) async throws {
        guard !items.isEmpty else {
            throw ExporterError.noImages
        }
        
        guard let ffmpegURL = findFFmpeg() else {
            throw ExporterError.ffmpegNotFound
        }
        
        isCancelled = false
        
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SequenceStitch_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Generate concat file
        let concatFileURL = try generateConcatFile(for: items, duration: frameDuration, tempDir: tempDir)
        
        // Remove existing output file if it exists
        try? FileManager.default.removeItem(at: outputURL)
        
        // Build FFmpeg command
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = buildFFmpegArguments(
            concatFile: concatFileURL,
            outputURL: outputURL,
            settings: settings
        )
        
        // Redirect all output to /dev/null
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        
        currentProcess = process
        
        // Use async/await with termination handler
        let exitStatus: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus)
            }
            
            do {
                try process.run()
                
                // Start progress simulation in background
                Task {
                    let startTime = Date()
                    // Estimate time based on number of images and encoding type
                    let timePerFrame = settings.useHardwareEncoding ? 0.05 : 0.15
                    let estimatedTime = max(2.0, Double(items.count) * timePerFrame)
                    
                    while process.isRunning {
                        let elapsed = Date().timeIntervalSince(startTime)
                        let progress = min(elapsed / estimatedTime, 0.99)
                        
                        await MainActor.run {
                            progressHandler(progress)
                        }
                        
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    }
                    
                    await MainActor.run {
                        progressHandler(1.0)
                    }
                }
            } catch {
                continuation.resume(throwing: ExporterError.exportFailed(error.localizedDescription))
            }
        }
        
        // Cleanup temp directory
        try? FileManager.default.removeItem(at: tempDir)
        
        if isCancelled {
            throw ExporterError.cancelled
        }
        
        if exitStatus != 0 {
            throw ExporterError.exportFailed("FFmpeg exited with code \(exitStatus)")
        }
        
        // Verify output
        if !FileManager.default.fileExists(atPath: outputURL.path) {
            throw ExporterError.exportFailed("Output file was not created")
        }
        
        currentProcess = nil
    }
    
    /// Cancels the current export
    func cancel() {
        isCancelled = true
        currentProcess?.terminate()
    }
}
