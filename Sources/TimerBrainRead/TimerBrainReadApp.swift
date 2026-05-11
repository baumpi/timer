import SwiftUI
import AppKit

@main
struct TimerBrainReadApp: App {
    @StateObject private var engine = TimerEngine()
    @StateObject private var tintStore = TintStore()
    @AppStorage(Defaults.themeMode) private var theme: ThemeMode = .dark

    @State private var overlayController: MenuBarOverlayController?

    init() {
        BundledFonts.register()
    }

    var body: some Scene {
        WindowGroup(AppInfo.mainWindowTitle) {
            ContentView()
                .environmentObject(engine)
                .environmentObject(tintStore)
                .frame(minWidth: 720, minHeight: 420)
                .onAppear { ensureOverlayController() }
        }
        .defaultSize(width: 1280, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra {
            MenuBarTimerPopover()
                .environmentObject(engine)
                .environmentObject(tintStore)
                .environment(\.palette, Palette.from(theme))
                .preferredColorScheme(theme == .dark ? .dark : .light)
                .onAppear { ensureOverlayController() }
        } label: {
            MenuBarTimerLabel(engine: engine)
        }
        .menuBarExtraStyle(.window)
    }

    private func ensureOverlayController() {
        guard overlayController == nil else { return }
        overlayController = MenuBarOverlayController(engine: engine, tintStore: tintStore)
    }
}
