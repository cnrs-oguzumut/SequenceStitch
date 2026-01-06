import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            // App Icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "film.stack")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            
            // App Info
            VStack(spacing: 4) {
                Text("SequenceStitch")
                    .font(.title.weight(.bold))
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text("Convert image sequences into high-quality videos using hardware-accelerated encoding.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Divider()
                .frame(width: 200)
            
            // Credits
            VStack(alignment: .leading, spacing: 12) {
                Text("Open Source Acknowledgment")
                    .font(.headline)
                
                Text("""
                    This application uses FFmpeg, a complete, cross-platform solution to record, convert and stream audio and video.
                    
                    FFmpeg is licensed under the GNU Lesser General Public License (LGPL) version 2.1 or later.
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Link("https://ffmpeg.org/legal.html", destination: URL(string: "https://ffmpeg.org/legal.html")!)
                    .font(.caption)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            Text("© 2026 Your Company")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .frame(width: 400, height: 500)
    }
}

#Preview {
    AboutView()
}
