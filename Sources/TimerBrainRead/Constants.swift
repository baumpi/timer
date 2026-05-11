import Foundation
import CoreGraphics

enum Layout {
    static let cornerRadiusSm: CGFloat = 8     // small icon-only buttons
    static let cornerRadiusMd: CGFloat = 10    // pill toggles with label
    static let cornerRadiusLg: CGFloat = 12    // cards (per design kit)

    static let toggleIconSize: CGFloat = 30
    static let toggleLabelPaddingX: CGFloat = 12
    static let toggleLabelPaddingY: CGFloat = 10
    static let iconFontSize: CGFloat = 12

    static let buttonHeight: CGFloat = 64

    static let normalMinSize = CGSize(width: 720, height: 420)
    static let normalDefaultSize = CGSize(width: 1280, height: 800)
    static let miniMinSize = CGSize(width: 320, height: 120)
    static let miniDefaultSize = CGSize(width: 420, height: 150)

    static let hoverAnimDuration: Double = 0.15
    static let themeAnimDuration: Double = 0.25
}

enum Tick {
    /// How often the engine recomputes the displayed time.
    /// Display only changes once per second, but a sub-second interval keeps
    /// it from looking laggy at the second-boundary.
    static let interval: TimeInterval = 0.25
}

enum Countdown {
    static let minSeconds: TimeInterval = 1
    static let maxSeconds: TimeInterval = 99 * 60 + 59  // 99:59
    static let stepSeconds: TimeInterval = 60           // ±1 MIN button
    static let defaultSeconds: TimeInterval = 600       // 10:00
    static let warningSeconds: TimeInterval = 30   // strong urgency
    static let cautionSeconds: TimeInterval = 60   // soft heads-up
    static let flashWindowSeconds: TimeInterval = 3 // pulse the bar in the final seconds
    static let presetsMinutesDefault = [5, 10, 25]

    /// User-configurable preset buttons. Reads from UserDefaults if the user
    /// edited them in Settings, otherwise returns the built-in defaults.
    static func currentPresetMinutes() -> [Int] {
        let saved = UserDefaults.standard.array(forKey: Defaults.customPresetMinutes) as? [Int]
        let cleaned = (saved ?? []).map { max(1, min(999, $0)) }
        return cleaned.isEmpty ? presetsMinutesDefault : cleaned
    }
}

/// Single source of truth for every UserDefaults key the app reads or writes.
/// Pass these to `@AppStorage(...)` and to direct `UserDefaults` calls so that
/// a typo at one call site can never silently create a parallel key.
enum Defaults {
    static let themeMode         = "themeMode"
    static let showShortcuts     = "showShortcuts"
    static let alwaysOnTop       = "alwaysOnTop"
    static let miniMode          = "miniMode"
    static let soundEnabled      = "soundEnabled"
    static let completionSound   = "completionSoundName"
    static let completionVolume  = "completionVolume"             // Float 0...1
    static let customSoundFilename = "customSoundFilename"        // String, filename inside Application Support
    static let timerMode         = "timerMode"
    static let countdownRepeats  = "countdownRepeats"
    static let countdownDuration       = "countdownDurationSecs"
    static let defaultCountdownDuration = "defaultCountdownDurationSecs"  // user-defined reset value
    static let customPresetMinutes     = "customPresetMinutes"    // [Int]
    static let menuBarTintActiveSlot   = "menuBarTintActiveSlot"
    static let menuBarOverlayEnabled   = "menuBarOverlayEnabled"
    static let menuBarTintOpacity      = "menuBarTintOpacity"     // Double 0...1, multiplier
    static let menuBarLabelFormat      = "menuBarLabelFormat"
    static let disablePulse            = "disablePulse"
    static let accentHex               = "accentHex"              // Int — overrides brand accent
    static let fontFamily              = "fontFamily"             // "sans" / "mono" / "system"
    static let launchAtLogin           = "launchAtLogin"

    /// Per-slot color storage key. Each slot is a 24-bit sRGB hex stored as an Int.
    static func menuBarTintSlot(_ index: Int) -> String {
        "menuBarTintSlot\(index)"
    }

    /// Every key the app writes — used by Settings export / import / reset.
    static let exportable: [String] = [
        themeMode, showShortcuts, alwaysOnTop, miniMode,
        soundEnabled, completionSound, completionVolume, customSoundFilename,
        timerMode, countdownRepeats, countdownDuration, defaultCountdownDuration,
        customPresetMinutes,
        menuBarTintActiveSlot, menuBarOverlayEnabled, menuBarTintOpacity,
        menuBarLabelFormat, disablePulse, accentHex, fontFamily, launchAtLogin,
        menuBarTintSlot(0), menuBarTintSlot(1), menuBarTintSlot(2), menuBarTintSlot(3),
    ]
}

enum AppInfo {
    static let mainWindowTitle = "Wura Timer"
    static let githubURL = URL(string: "https://github.com/baumpi/timer")!
    static let bugReportURL = URL(string: "https://github.com/baumpi/timer/issues/new")!

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}
