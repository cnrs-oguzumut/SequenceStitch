import SwiftUI

struct ThumbnailView: View {
    @EnvironmentObject var sequenceManager: SequenceManager
    let item: SequenceItem
    let index: Int
    
    @State private var isHovered = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main thumbnail
            VStack(spacing: 8) {
                // Image container
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    
                    Image(nsImage: item.thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(8)
                }
                .frame(height: 140)
                .overlay(alignment: .bottomLeading) {
                    // Sequence number badge
                    Text("\(index)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .padding(8)
                }
                
                // Filename
                Text(item.originalFilename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            
            // Delete button
            if isHovered {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        sequenceManager.removeItem(withId: item.id)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    let item = SequenceItem(
        originalURL: URL(fileURLWithPath: "/tmp/test.png"),
        thumbnail: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!,
        dateCreated: Date(),
        originalFilename: "test_image.png"
    )
    
    return ThumbnailView(item: item, index: 1)
        .environmentObject(SequenceManager())
        .frame(width: 180, height: 180)
        .padding()
}
