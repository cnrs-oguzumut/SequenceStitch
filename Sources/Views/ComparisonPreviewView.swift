import SwiftUI

/// Preview showing how stacked sequences will appear in final export
struct ComparisonPreviewView: View {
    @EnvironmentObject var sequenceManager: SequenceManager
    @ObservedObject var exportSettings: ExportSettings

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                if let primaryImage = sequenceManager.items.first?.thumbnail,
                   let secondaryImage = sequenceManager.secondaryItems.first?.thumbnail {
                    
                    let stackingMode = exportSettings.stackingMode
                    let spacing = CGFloat(exportSettings.stackingSpacing)
                    let useLetterboxing = exportSettings.normalizationResolution != .original
                    
                    // Calculate target aspect ratio from resolution (default to 16:9 if unknown)
                    let targetDims = exportSettings.normalizationResolution.dimensions ?? (1920, 1080)
                    let singleAspectRatio = CGFloat(targetDims.width) / CGFloat(targetDims.height)
                    
                    let previewContainer = ZStack {
                        if stackingMode == .horizontal {
                            // Target dimensions
                            let totalWidth = CGFloat(targetDims.width * 2) + CGFloat(spacing)
                            let totalHeight = CGFloat(targetDims.height)
                            let totalAspectRatio = totalWidth / totalHeight
                            
                            GeometryReader { innerGeo in
                                let scale = innerGeo.size.width / totalWidth
                                let scaledImageWidth = CGFloat(targetDims.width) * scale
                                let scaledSpacing = CGFloat(spacing) * scale
                                
                                HStack(spacing: 0) {
                                    renderImageBox(image: primaryImage, size: CGSize(width: scaledImageWidth, height: innerGeo.size.height), isHorizontal: true, spacing: 0, aspectRatio: singleAspectRatio, useLetterboxing: useLetterboxing)
                                        .frame(width: scaledImageWidth)
                                    
                                    if spacing > 0 {
                                        Color.black.frame(width: scaledSpacing)
                                    } else if spacing < 0 {
                                        // For negative spacing (overlap), HStack doesn't support negative spacing well for layout
                                        // We handle overlap via ZStack or Offset if strictly needed, but simple negative spacing visual:
                                        // Just assume 0 for preview simplicity or handle simple overlap:
                                        Color.clear.frame(width: 0) 
                                    }
                                    
                                    renderImageBox(image: secondaryImage, size: CGSize(width: scaledImageWidth, height: innerGeo.size.height), isHorizontal: true, spacing: 0, aspectRatio: singleAspectRatio, useLetterboxing: useLetterboxing)
                                        .frame(width: scaledImageWidth)
                                }
                                // Handle negative overlap adjustment manually if needed, but for now simple HStack
                                // If spacing is negative, logical width reduces.
                            }
                            .aspectRatio(useLetterboxing ? totalAspectRatio : nil, contentMode: .fit)
                            
                        } else if stackingMode == .vertical {
                            let totalWidth = CGFloat(targetDims.width)
                            let totalHeight = CGFloat(targetDims.height * 2) + CGFloat(spacing)
                            let totalAspectRatio = totalWidth / totalHeight
                            
                            GeometryReader { innerGeo in
                                let scale = innerGeo.size.height / totalHeight
                                let scaledImageHeight = CGFloat(targetDims.height) * scale
                                let scaledSpacing = CGFloat(spacing) * scale
                                
                                VStack(spacing: 0) {
                                    renderImageBox(image: primaryImage, size: CGSize(width: innerGeo.size.width, height: scaledImageHeight), isHorizontal: false, spacing: 0, aspectRatio: singleAspectRatio, useLetterboxing: useLetterboxing)
                                        .frame(height: scaledImageHeight)
                                    
                                    if spacing > 0 {
                                        Color.black.frame(height: scaledSpacing)
                                    }
                                    
                                    renderImageBox(image: secondaryImage, size: CGSize(width: innerGeo.size.width, height: scaledImageHeight), isHorizontal: false, spacing: 0, aspectRatio: singleAspectRatio, useLetterboxing: useLetterboxing)
                                        .frame(height: scaledImageHeight)
                                }
                            }
                            .aspectRatio(useLetterboxing ? totalAspectRatio : nil, contentMode: .fit)
                        } else {
                            // None - just show primary
                            Image(nsImage: primaryImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    
                    previewContainer
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Add images to both sequences to preview")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderImageBox(image: NSImage, size: CGSize, isHorizontal: Bool, spacing: CGFloat, aspectRatio: CGFloat, useLetterboxing: Bool) -> some View {
        ZStack {
            Color.black
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill the split container
        // If letterboxing is enforced, the aspect ratio is handled by the parent container's aspect ratio constraint
    }
}

#Preview {
    let manager = SequenceManager()
    return ComparisonPreviewView(exportSettings: manager.exportSettings)
        .environmentObject(manager)
        .frame(width: 600, height: 300)
}
