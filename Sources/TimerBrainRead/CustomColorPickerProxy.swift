import AppKit
import SwiftUI

/// Lightweight wrapper around `NSColorPanel` that writes the picked color
/// into a `TintStore` slot. We can't use SwiftUI's `ColorPicker` inside a
/// `.menuBarExtraStyle(.window)` popover because opening the system color
/// panel transfers key-window focus, which auto-dismisses the popover and
/// tears down the SwiftUI binding before any color is saved.
///
/// This singleton sidesteps that by owning the panel callback itself. The
/// store reference is set on every `present(...)` call, and the singleton
/// retains the store via a strong ref while the panel is interactive.
/// Writes flow through `TintStore` (which publishes via `@Published` AND
/// persists to UserDefaults), so the overlay updates live as the user drags
/// the picker — even after the popover has been dismissed.
@MainActor
final class CustomColorPickerProxy: NSObject {
    static let shared = CustomColorPickerProxy()

    private var store: TintStore?
    private var currentSlot: Int = 0

    private override init() {
        super.init()
    }

    func present(slot: Int, store: TintStore) {
        self.currentSlot = slot
        self.store = store

        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.isContinuous = true
        panel.showsAlpha = false
        // Keep the panel above the menu bar popover and any other windows so
        // it can't be auto-hidden by the popover's key-loss dismissal.
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let startingHex = store.hex(for: slot)
        panel.color = NSColor(
            srgbRed: CGFloat((startingHex >> 16) & 0xFF) / 255,
            green:   CGFloat((startingHex >>  8) & 0xFF) / 255,
            blue:    CGFloat( startingHex        & 0xFF) / 255,
            alpha: 1
        )

        // The menu bar popover (`.menuBarExtraStyle(.window)`) is a
        // nonactivating NSPanel that auto-dismisses on key loss. A short
        // delay lets the popover fully tear down before we activate the app
        // and order the color panel front, otherwise focus races back to the
        // menu bar and the picker disappears. We use NSRunningApplication
        // because `NSApp.activate` is unreliable for accessory-style menu
        // bar interactions.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            NSApp.activate(ignoringOtherApps: true)
            panel.orderFrontRegardless()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func colorChanged(_ sender: Any?) {
        guard let panel = sender as? NSColorPanel else { return }
        guard let ns = panel.color.usingColorSpace(.sRGB) else { return }
        let clamp: (CGFloat) -> UInt32 = { UInt32(max(0, min(255, Int($0 * 255)))) }
        let hex = (clamp(ns.redComponent)   << 16)
                | (clamp(ns.greenComponent) <<  8)
                |  clamp(ns.blueComponent)

        store?.setSlotColor(currentSlot, hex: hex)
    }
}
