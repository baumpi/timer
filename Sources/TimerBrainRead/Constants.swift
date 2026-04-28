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
    static let warningSeconds: TimeInterval = 60
    static let presetsMinutes = [5, 10, 25]
}
