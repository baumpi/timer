import SwiftUI
import AppKit

@main
struct TimerBrainReadApp: App {
    init() {
        BundledFonts.register()
    }

    var body: some Scene {
        WindowGroup("Wura Timer") {
            ContentView()
                .frame(minWidth: 720, minHeight: 420)
        }
        .defaultSize(width: 1280, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
