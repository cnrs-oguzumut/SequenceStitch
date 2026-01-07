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
    
    /// Finds FFmpeg binary - checks bundled version first, then Homebrew/System
    private func findFFmpeg() -> URL? {
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
            print("Checking FFmpeg at \(path): \(isExecutable)")
            if isExecutable {
                return URL(fileURLWithPath: path)
            }
        }
        
        print("FFmpeg not found in standard locations.")
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
    
    /// Normalizes a sequence to fixed dimensions to prevent filter graph reconfiguration
    private func normalizeSequence(
        ffmpegURL: URL,
        concatFile: URL,
        outputURL: URL,
        framerate: Double
    ) async throws {
        // Read concat file to get list of images WITHOUT duration lines
        let concatContent = try String(contentsOf: concatFile, encoding: .utf8)
        let lines = concatContent.components(separatedBy: .newlines)
        var imagePaths: [String] = []

        for line in lines {
            if line.hasPrefix("file '") {
                let path = line
                    .replacingOccurrences(of: "file '", with: "")
                    .replacingOccurrences(of: "'", with: "")
                if !path.isEmpty {
                    imagePaths.append(path)
                }
            }
        }

        // Remove duplicate last image
        if imagePaths.count > 1 && imagePaths.last == imagePaths[imagePaths.count - 2] {
            imagePaths.removeLast()
        }

        // Create a simple concat file without duration - let -r handle framerate
        let simpleConcatFile = concatFile.deletingLastPathComponent().appendingPathComponent("simple_\(concatFile.lastPathComponent)")
        let simpleContent = imagePaths.map { "file '\($0)'" }.joined(separator: "\n")
        try simpleContent.write(to: simpleConcatFile, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-r", "\(framerate)",
            "-f", "concat",
            "-safe", "0",
            "-i", simpleConcatFile.path,
            "-vf", "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,setsar=1",
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-crf", "18",
            "-pix_fmt", "yuv420p",
            "-r", "\(framerate)",
            "-y",
            outputURL.path
        ]

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ExporterError.exportFailed("Normalization failed with code \(proc.terminationStatus)"))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Builds FFmpeg arguments based on export settings
    private func buildFFmpegArguments(
        concatFile: URL,
        secondaryConcatFile: URL? = nil,
        outputURL: URL,
        settings: ExportSettings,
        framerate: Int = 30
    ) -> [String] {
        var args: [String] = []

        // Check if inputs are normalized videos (*.mp4) or concat files (*.txt)
        let isNormalizedVideo = concatFile.pathExtension == "mp4"

        if isNormalizedVideo {
            // Inputs are already normalized videos - just stack them
            args += ["-i", concatFile.path]
            if let secondaryVideo = secondaryConcatFile {
                args += ["-i", secondaryVideo.path]
            }

            if secondaryConcatFile != nil, settings.stackingMode != .none {
                // Simple stacking of normalized videos
                let stackFilter = settings.stackingMode == .horizontal ? "hstack=inputs=2" : "vstack=inputs=2"
                args += ["-filter_complex", "[0:v][1:v]\(stackFilter)[stacked]", "-map", "[stacked]"]
            }
        } else {
            // Original concat file approach for single sequence mode
            // Do NOT specify -r here; let the concat file's 'duration' directives control timing.
            // The output -r will handle frame duplication/dropping to match target FPS.
            args += ["-f", "concat", "-safe", "0", "-i", concatFile.path]
        }

        if !isNormalizedVideo {
            // Single sequence mode
            var filters: [String] = []

            // Resolution scaling (if not original)
            if let scaleFilter = settings.resolution.scaleFilter(originalWidth: 1920, originalHeight: 1080) {
                filters.append(scaleFilter)
            } else {
                // "Original" resolution: Add safety filter to ensure dimensions are divisible by 2
                // libx264 requires even dimensions; failure to do so results in "Invalid argument" (error -22)
                filters.append("scale=trunc(iw/2)*2:trunc(ih/2)*2")
            }

            if !filters.isEmpty {
                args += ["-vf", filters.joined(separator: ",")]
            }
        }
        
        // Codec selection based on format and hardware preference
        switch settings.format {
        case .mp4, .mov:
            if settings.useHardwareEncoding, let hwCodec = settings.format.hardwareCodec {
                args += ["-c:v", hwCodec]
                args += ["-allow_sw", "1"]
            } else {
                args += ["-c:v", "libx264"]
                args += ["-preset", settings.quality.preset]
                args += ["-crf", "\(settings.quality.crf)"]
                args += ["-profile:v", "main"]
                // Removed level constraint to support arbitrary resolutions
            }
            // Explicit output frame rate for timing
            args += ["-r", "\(settings.frameRate.rawValue)"]
            
        case .webm:
            args += ["-c:v", "libvpx-vp9"]
            let crf = settings.quality.crf
            args += ["-crf", "\(crf)", "-b:v", "0"]
            args += ["-r", "\(settings.frameRate.rawValue)"]
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
        secondaryItems: [SequenceItem] = [],
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

        // Generate concat file(s)
        let concatFileURL = try generateConcatFile(for: items, duration: frameDuration, tempDir: tempDir)

        var secondaryConcatURL: URL? = nil
        if !secondaryItems.isEmpty && settings.stackingMode != .none {
            secondaryConcatURL = tempDir.appendingPathComponent("input_secondary.txt")
            var content = ""
            for (index, item) in secondaryItems.enumerated() {
                let escapedPath = item.processedURL.path.replacingOccurrences(of: "'", with: "'\\''")
                content += "file '\(escapedPath)'\n"
                content += "duration \(frameDuration)\n"
                if index == secondaryItems.count - 1 {
                    content += "file '\(escapedPath)'\n"
                }
            }
            try content.write(to: secondaryConcatURL!, atomically: true, encoding: .utf8)
        }

        // Remove existing output file if it exists
        try? FileManager.default.removeItem(at: outputURL)

        // For comparison mode, pre-normalize each sequence to avoid filter graph reconfiguration
        var primaryVideoURL = concatFileURL
        var secondaryVideoURL = secondaryConcatURL

        if let secConcat = secondaryConcatURL, settings.stackingMode != .none {
            // Calculate correct framerate from frame duration
            let actualFramerate = 1.0 / frameDuration

            // Step 1: Normalize primary sequence
            let normalizedPrimary = tempDir.appendingPathComponent("primary_normalized.mp4")
            try await normalizeSequence(
                ffmpegURL: ffmpegURL,
                concatFile: concatFileURL,
                outputURL: normalizedPrimary,
                framerate: actualFramerate
            )
            primaryVideoURL = normalizedPrimary

            // Step 2: Normalize secondary sequence
            let normalizedSecondary = tempDir.appendingPathComponent("secondary_normalized.mp4")
            try await normalizeSequence(
                ffmpegURL: ffmpegURL,
                concatFile: secConcat,
                outputURL: normalizedSecondary,
                framerate: actualFramerate
            )
            secondaryVideoURL = normalizedSecondary
        }

        // Build FFmpeg command
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = buildFFmpegArguments(
            concatFile: primaryVideoURL,
            secondaryConcatFile: secondaryVideoURL,
            outputURL: outputURL,
            settings: settings,
            framerate: settings.frameRate.rawValue
        )

        // Debug: Write command to file
        let debugPath = "/tmp/ffmpeg_debug.txt"
        let commandString = ([ffmpegURL.path] + process.arguments!).joined(separator: " ")
        try? commandString.write(toFile: debugPath, atomically: true, encoding: .utf8)
        print("FFmpeg command written to: \(debugPath)")
        print("Command: \(commandString)")

        // Capture error output for debugging
        let errorPipe = Pipe()
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
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
        
        // Read error output
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let stdOutput = String(data: outputData, encoding: .utf8) ?? ""

        // Write debug info to file
        var debugInfo = "=== FFmpeg Full Output ===\n"
        debugInfo += errorOutput + "\n"
        debugInfo += stdOutput + "\n"
        debugInfo += "=== Temp Directory ===\n"
        debugInfo += "Path: \(tempDir.path)\n"
        if let secURL = secondaryConcatURL {
            debugInfo += "Primary concat: \(concatFileURL.path)\n"
            debugInfo += "Secondary concat: \(secURL.path)\n"
            if let content = try? String(contentsOf: concatFileURL) {
                debugInfo += "Primary concat content:\n\(content)\n"
            }
            if let content2 = try? String(contentsOf: secURL) {
                debugInfo += "Secondary concat content:\n\(content2)\n"
            }
        }
        try? debugInfo.write(toFile: "/tmp/ffmpeg_output.txt", atomically: true, encoding: .utf8)
        print(debugInfo)

        // Cleanup temp directory (commented for debugging)
        // try? FileManager.default.removeItem(at: tempDir)

        if isCancelled {
            throw ExporterError.cancelled
        }

        if exitStatus != 0 {
            // Extract useful error info from FFmpeg output
            let errorLines = errorOutput.components(separatedBy: .newlines)
                .filter { $0.contains("Error") || $0.contains("Invalid") || $0.contains("failed") }
                .suffix(3)
                .joined(separator: "; ")

            let errorMessage = errorLines.isEmpty ? "FFmpeg exited with code \(exitStatus)" : errorLines
            throw ExporterError.exportFailed(errorMessage)
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
