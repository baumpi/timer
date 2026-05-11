import AppKit
import UniformTypeIdentifiers

/// Owns the lifecycle of a user-provided sound file. The user's original file
/// can move, rename, or be deleted — we keep a private copy inside our
/// Application Support directory and load `NSSound` from there.
///
/// Storing the copy (vs. a security-scoped bookmark to the original) trades
/// a few MB of disk for predictable behavior across reboots, dropbox-moved
/// originals, and clean ad-hoc builds. The previous file is replaced every
/// time the user picks a new one.
@MainActor
enum CustomSoundStore {
    static let allowedExtensions: Set<String> = ["aif", "aiff", "wav", "mp3", "m4a", "caf"]

    /// Resolved once at first access. `createDirectory` with
    /// `withIntermediateDirectories: true` is a no-op if the path already
    /// exists, so no separate existence check is needed.
    static let directory: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Wura Timer", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// URL of the current user-imported sound, or nil if none set.
    /// Callers should handle the read failing (file may have been deleted
    /// externally) — we don't pre-check existence to avoid a TOCTOU race.
    static func currentFileURL() -> URL? {
        guard let name = UserDefaults.standard.string(forKey: Defaults.customSoundFilename) else { return nil }
        return directory.appendingPathComponent(name)
    }

    /// Display name for the UI — just the filename, or "None" placeholder.
    static func currentDisplayName() -> String {
        currentFileURL()?.lastPathComponent ?? "No custom sound"
    }

    /// Returns a playable NSSound for the current custom file, or nil if none.
    static func loadSound() -> NSSound? {
        guard let url = currentFileURL() else { return nil }
        return NSSound(contentsOf: url, byReference: false)
    }

    /// Show an Open panel and, on selection, copy the chosen file into our
    /// directory. Replaces any previous custom sound. The completion handler
    /// is called on the main thread with `true` if a file was imported.
    static func chooseFile(completion: @escaping (Bool) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Choose a sound file"
        panel.message = "AIFF, WAV, MP3, M4A or CAF up to ~10 MB."
        panel.allowedContentTypes = [
            UTType.audio, UTType.aiff, UTType.wav, UTType.mp3, UTType.mpeg4Audio,
        ]

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let src = panel.url else {
                completion(false); return
            }
            let ok = importFile(at: src)
            completion(ok)
        }
    }

    /// Copy `src` into our directory under a stable name. Replaces any prior
    /// import. Returns true on success.
    @discardableResult
    static func importFile(at src: URL) -> Bool {
        let ext = src.pathExtension.lowercased()
        guard allowedExtensions.contains(ext) else { return false }
        let dst = directory.appendingPathComponent("custom-completion.\(ext)")
        // Drop any previous import (it may have a different extension).
        clearStoredFile()
        do {
            try FileManager.default.copyItem(at: src, to: dst)
        } catch {
            NSLog("[CustomSoundStore] copy failed: \(error)")
            return false
        }
        UserDefaults.standard.set(dst.lastPathComponent, forKey: Defaults.customSoundFilename)
        return true
    }

    /// Remove the currently stored custom sound (file + UserDefaults entry).
    static func clear() {
        clearStoredFile()
        UserDefaults.standard.removeObject(forKey: Defaults.customSoundFilename)
    }

    private static func clearStoredFile() {
        guard let url = currentFileURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
