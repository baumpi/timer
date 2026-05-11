import SwiftUI
import Combine
import Foundation

/// Single source of truth for the menu bar overlay tint.
///
/// Every slot is fully user-customizable: there are `slotCount` slots, each
/// stores its own sRGB hex in UserDefaults, and one slot is "active". Picking
/// a color in `NSColorPanel` writes directly through this store so changes are
/// observed by the overlay view immediately — no reliance on `@AppStorage`
/// propagating external `UserDefaults` writes (which proved unreliable inside
/// `MenuBarExtra(.window)` popovers).
@MainActor
final class TintStore: ObservableObject {
    static let slotCount = 4

    /// Sensible defaults for fresh installs. Users overwrite any of these by
    /// clicking a chip and picking a color.
    static let defaultHexes: [UInt32] = [
        0xF59E0B,  // amber
        0xFFFFFF,  // white
        0xC41E3A,  // brand red
        0x4F46E5,  // indigo
    ]

    @Published private(set) var activeSlot: Int = 0
    @Published private(set) var slotHexes: [UInt32] = TintStore.defaultHexes

    private var importObserver: NSObjectProtocol?

    init() {
        reloadFromDefaults()
        // Settings import / Reset writes the persistence layer directly,
        // bypassing setActiveSlot / setSlotColor — pick those changes up
        // so the menu bar overlay refreshes without an app restart.
        importObserver = NotificationCenter.default.addObserver(
            forName: .wuraTimerSettingsApplied,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reloadFromDefaults() }
        }
    }

    deinit {
        if let importObserver { NotificationCenter.default.removeObserver(importObserver) }
    }

    private func reloadFromDefaults() {
        let defaults = UserDefaults.standard
        var hexes: [UInt32] = []
        for i in 0..<Self.slotCount {
            let key = Defaults.menuBarTintSlot(i)
            if defaults.object(forKey: key) != nil {
                hexes.append(UInt32(truncatingIfNeeded: defaults.integer(forKey: key)))
            } else {
                hexes.append(Self.defaultHexes[i])
            }
        }
        if hexes != slotHexes { slotHexes = hexes }

        let rawActive = defaults.integer(forKey: Defaults.menuBarTintActiveSlot)
        let clamped = max(0, min(Self.slotCount - 1, rawActive))
        if clamped != activeSlot { activeSlot = clamped }
    }

    var activeColor: Color {
        Color(hex: slotHexes[activeSlot])
    }

    func color(for slot: Int) -> Color {
        Color(hex: slotHexes[max(0, min(Self.slotCount - 1, slot))])
    }

    func hex(for slot: Int) -> UInt32 {
        slotHexes[max(0, min(Self.slotCount - 1, slot))]
    }

    func setActiveSlot(_ slot: Int) {
        guard slot >= 0, slot < Self.slotCount, slot != activeSlot else { return }
        activeSlot = slot
        UserDefaults.standard.set(slot, forKey: Defaults.menuBarTintActiveSlot)
    }

    /// Update the color for a slot AND make that slot active. Called from the
    /// `NSColorPanel` callback whenever the user picks a color.
    func setSlotColor(_ slot: Int, hex: UInt32) {
        guard slot >= 0, slot < Self.slotCount else { return }
        if slotHexes[slot] != hex {
            slotHexes[slot] = hex
            UserDefaults.standard.set(Int(hex), forKey: Defaults.menuBarTintSlot(slot))
        }
        if activeSlot != slot {
            activeSlot = slot
            UserDefaults.standard.set(slot, forKey: Defaults.menuBarTintActiveSlot)
        }
    }
}
