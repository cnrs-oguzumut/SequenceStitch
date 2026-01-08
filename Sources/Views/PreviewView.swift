import SwiftUI

struct PreviewView: View {
    @EnvironmentObject var sequenceManager: SequenceManager
    @State private var currentIndex = 0
    @State private var isPlaying = false
    @State private var timer: Timer?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Image display
            if !sequenceManager.items.isEmpty {
                Image(nsImage: sequenceManager.items[currentIndex].thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .id(currentIndex)
                    .transition(.opacity)
            } else {
                Text("No images to preview")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
            
            // Controls
            VStack(spacing: 12) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 4)
                .clipShape(Capsule())
                
                HStack(spacing: 20) {
                    // Previous
                    Button {
                        if currentIndex > 0 {
                            currentIndex -= 1
                        }
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentIndex == 0)
                    
                    // Play/Pause
                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                    }
                    .buttonStyle(.plain)
                    
                    // Next
                    Button {
                        if currentIndex < sequenceManager.items.count - 1 {
                            currentIndex += 1
                        }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentIndex >= sequenceManager.items.count - 1)
                    
                    Spacer()
                    
                    // Frame info
                    Text("\(currentIndex + 1) / \(sequenceManager.items.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    
                    // Close button
                    Button("Done") {
                        stopPlayback()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 640, minHeight: 480)
        .onDisappear {
            stopPlayback()
        }
        .onKeyPress(.space) {
            togglePlayback()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            if currentIndex > 0 { currentIndex -= 1 }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if currentIndex < sequenceManager.items.count - 1 { currentIndex += 1 }
            return .handled
        }
    }
    
    private var progress: Double {
        guard sequenceManager.items.count > 1 else { return 0 }
        return Double(currentIndex) / Double(sequenceManager.items.count - 1)
    }
    
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        isPlaying = true
        let itemCount = sequenceManager.items.count
        let duration = sequenceManager.effectiveFrameDuration
        
        timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: true) { [self] _ in
            Task { @MainActor in
                if currentIndex < itemCount - 1 {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        currentIndex += 1
                    }
                } else {
                    // Loop back to start
                    currentIndex = 0
                }
            }
        }
    }
    
    private func stopPlayback() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    PreviewView()
        .environmentObject(SequenceManager())
}
