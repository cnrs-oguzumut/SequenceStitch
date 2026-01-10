import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var sequenceManager: SequenceManager
    @ObservedObject var exporter: VideoExporter
    @Binding var showingExportPanel: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "film.stack")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.4, blue: 0.8), Color(red: 0.4, green: 0.3, blue: 0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("SequenceStitch")
                            .font(.title2.weight(.semibold))
                    }
                    
                    Text("Image Sequence to Video")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider()
                    .padding(.horizontal, 16)
                
                // Stats
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(label: "Images", value: "\(sequenceManager.items.count)")
                    
                    let totalDuration = Double(sequenceManager.items.count) * sequenceManager.effectiveFrameDuration
                    StatRow(label: "Duration", value: formatDuration(totalDuration))
                }
                .padding(20)
                
                Divider()
                    .padding(.horizontal, 16)

                // Comparison Mode Settings (only show when in comparison mode)
                if sequenceManager.isComparisonMode {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Comparison Mode")
                            .font(.headline)

                        // Normalization Resolution
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Normalize To")
                                    .font(.subheadline)
                                Spacer()
                            }

                            Picker("", selection: $sequenceManager.exportSettings.normalizationResolution) {
                                ForEach(NormalizationResolution.allCases) { res in
                                    Text(res.rawValue).tag(res)
                                }
                            }
                            .pickerStyle(.menu)

                            Text("Controls output aspect ratio")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(20)

                    Divider()
                        .padding(.horizontal, 16)
                }

                // Export Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Export Settings")
                        .font(.headline)
                    
                    // Time-lapse Calculator Toggle
                    Toggle(isOn: $sequenceManager.isTimeLapseMode) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Time-lapse Calculator")
                                .font(.subheadline)
                            Text("Set target duration, auto-calculate timing")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(Color(red: 0.2, green: 0.6, blue: 0.4))
                    
                    if sequenceManager.isTimeLapseMode {
                        // Target Duration (Time-lapse mode)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Target Duration")
                                    .font(.subheadline)
                                Spacer()
                                Text(formatDuration(sequenceManager.targetDuration))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(
                                value: $sequenceManager.targetDuration,
                                in: 1...300,
                                step: 1
                            )
                            .tint(Color(red: 0.2, green: 0.6, blue: 0.4))
                            
                            // Show calculated frame duration
                            if sequenceManager.items.count > 0 {
                                HStack {
                                    Image(systemName: "function")
                                        .foregroundStyle(.green)
                                    Text("Frame: \(String(format: "%.3fs", sequenceManager.effectiveFrameDuration))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(sequenceManager.items.count) frames")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        // Manual Frame Duration
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Frame Duration")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.1fs", sequenceManager.frameDuration))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            
                            Slider(
                                value: $sequenceManager.frameDuration,
                                in: 0.1...10.0,
                                step: 0.1
                            )
                            .tint(Color(red: 0.2, green: 0.4, blue: 0.8))
                        }
                    }
                    
                    // Output Format
                    HStack {
                        Text("Format")
                            .font(.subheadline)
                        Spacer()
                        Picker("", selection: $sequenceManager.exportSettings.format) {
                            ForEach(OutputFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    
                    // Resolution
                    HStack {
                        Text("Resolution")
                            .font(.subheadline)
                        Spacer()
                        Picker("", selection: $sequenceManager.exportSettings.resolution) {
                            ForEach(ResolutionScale.allCases) { res in
                                Text(res.rawValue).tag(res)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    
                    // Quality
                    HStack {
                        Text("Quality")
                            .font(.subheadline)
                        Spacer()
                        Picker("", selection: $sequenceManager.exportSettings.quality) {
                            ForEach(QualityPreset.allCases) { quality in
                                Text(quality.rawValue).tag(quality)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    
                    // Frame Rate
                    HStack {
                        Text("Frame Rate")
                            .font(.subheadline)
                        Spacer()
                        Picker("", selection: $sequenceManager.exportSettings.frameRate) {
                            ForEach(FrameRateOption.allCases) { fps in
                                Text(fps.displayName).tag(fps)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    
                    // Hardware Encoding Toggle
                    Toggle(isOn: $sequenceManager.exportSettings.useHardwareEncoding) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hardware Encoding")
                                .font(.subheadline)
                            Text("Faster, may have compatibility issues")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(sequenceManager.exportSettings.format == .webm)
                    
                    // Codec info
                    HStack(spacing: 4) {
                        Image(systemName: sequenceManager.exportSettings.useHardwareEncoding ? "cpu" : "memorychip")
                            .foregroundStyle(.secondary)
                        Text(sequenceManager.exportSettings.useHardwareEncoding ? "VideoToolbox H.264" : "Software libx264")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                
                Spacer(minLength: 20)
                
                // Export section
                VStack(spacing: 12) {
                    if sequenceManager.isExporting {
                        VStack(spacing: 8) {
                            ProgressView(value: sequenceManager.exportProgress)
                                .progressViewStyle(.linear)
                                .tint(.blue)
                            
                            HStack {
                                Text("Exporting...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("\(Int(sequenceManager.exportProgress * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button {
                            showingExportPanel = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Video")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: sequenceManager.items.isEmpty 
                                        ? [.gray, .gray]
                                        : [Color(red: 0.15, green: 0.35, blue: 0.7), Color(red: 0.35, green: 0.25, blue: 0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(sequenceManager.items.isEmpty)
                    }
                }
                .padding(20)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.1, blue: 0.18), Color(red: 0.1, green: 0.12, blue: 0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .preferredColorScheme(.dark)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.1f sec", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium).monospacedDigit())
        }
    }
}

#Preview {
    SidebarView(exporter: VideoExporter(), showingExportPanel: .constant(false))
        .environmentObject(SequenceManager())
        .frame(width: 280, height: 700)
}
