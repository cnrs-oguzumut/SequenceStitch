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
                Text("License Information")
                    .font(.headline)
                
                Text("""
                    This application bundles FFmpeg, which is licensed under the GNU General Public License (GPL) version 2.
                    
                    Consequently, this combined work is distributed under the GPL v2 license.
                    You have the right to access the source code of this application and modify it.
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Link("View GPL v2 License", destination: URL(string: "https://www.gnu.org/licenses/old-licenses/gpl-2.0.html")!)
                    .font(.caption)
                
                Link("FFmpeg Source Code", destination: URL(string: "https://ffmpeg.org/download.html")!)
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
