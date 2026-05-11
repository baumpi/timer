import AppKit

/// Sounds the timer plays when a countdown reaches zero. The built-in cases
/// map directly to AIFFs in `/System/Library/Sounds/`, so no audio assets
/// need bundling. The `.custom` case loads from a file the user imported,
/// managed by `CustomSoundStore`.
///
/// `NSSound(...).play()` plays through normal audio output and is NOT gated
/// by the system "Alert volume" slider — important, because that slider is
/// at zero on a lot of machines and is what was masking the old
/// `NSSound.beep()` so the timer felt silent.
enum CompletionSound: String, CaseIterable, Identifiable {
    case hero       = "Hero"
    case glass      = "Glass"
    case ping       = "Ping"
    case tink       = "Tink"
    case submarine  = "Submarine"
    case custom     = "Custom"

    var id: String { rawValue }

    var displayName: String {
        self == .custom ? "Custom…" : rawValue
    }

    static let `default`: CompletionSound = .hero

    static func current() -> CompletionSound {
        let raw = UserDefaults.standard.string(forKey: Defaults.completionSound)
        return raw.flatMap(CompletionSound.init(rawValue:)) ?? .default
    }

    /// Volume in 0...1. Defaults to 1.0 if never set.
    static func currentVolume() -> Float {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Defaults.completionVolume) != nil else { return 1.0 }
        return max(0, min(1, defaults.float(forKey: Defaults.completionVolume)))
    }

    @MainActor
    func play() {
        guard let sound = makeSound() else { return }
        sound.volume = Self.currentVolume()
        // Stop any prior play so back-to-back previews don't queue/overlap.
        sound.stop()
        sound.play()
    }

    @MainActor
    private func makeSound() -> NSSound? {
        switch self {
        case .custom:
            return CustomSoundStore.loadSound()
        default:
            return NSSound(named: NSSound.Name(rawValue))
        }
    }
}
