import SwiftUI

@main
struct SequenceStitchApp: App {
    @StateObject private var sequenceManager = SequenceManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sequenceManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .appInfo) {
                Button("About SequenceStitch") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "SequenceStitch",
                        .applicationVersion: "1.0.0",
                        .credits: NSAttributedString(
                            string: "This software uses FFmpeg under the GPL v2 license.\n\nCombined work licensed under GPL v2.\nSource code available at https://ffmpeg.org",
                            attributes: [.font: NSFont.systemFont(ofSize: 11)]
                        )
                    ])
                }
            }
        }
        
        Settings {
            AboutView()
        }
    }
}
