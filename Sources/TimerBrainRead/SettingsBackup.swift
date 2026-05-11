import AppKit
import UniformTypeIdentifiers

/// Serialize/deserialize the subset of UserDefaults that the user can
/// configure from the Settings window. JSON-based so files are diffable and
/// shareable. Custom sound files are NOT exported — only the filename
/// reference; the user re-imports them on the new machine.
@MainActor
enum SettingsBackup {
    private static let fileType = UTType.json

    static func exportToFile() {
        let panel = NSSavePanel()
        panel.title = "Export Wura Timer settings"
        panel.allowedContentTypes = [fileType]
        panel.nameFieldStringValue = "WuraTimer-settings.json"

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try snapshotAsJSON()
                try data.write(to: url, options: .atomic)
            } catch {
                presentError("Couldn't export settings", error: error)
            }
        }
    }

    static func importFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Wura Timer settings"
        panel.allowedContentTypes = [fileType]
        panel.allowsMultipleSelection = false

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                try applyJSON(data)
            } catch {
                presentError("Couldn't import settings", error: error)
            }
        }
    }

    /// Remove every exportable key. Next read returns code defaults.
    static func resetAll() {
        let alert = NSAlert()
        alert.messageText = "Reset all settings?"
        alert.informativeText = "Every preference returns to its default. Imported custom sounds are also removed. This can't be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let defaults = UserDefaults.standard
        for key in Defaults.exportable {
            defaults.removeObject(forKey: key)
        }
        CustomSoundStore.clear()
    }

    // MARK: - Internals

    private static func snapshotAsJSON() throws -> Data {
        let defaults = UserDefaults.standard
        var dict: [String: Any] = [:]
        for key in Defaults.exportable {
            if let v = defaults.object(forKey: key) {
                dict[key] = v
            }
        }
        return try JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private static func applyJSON(_ data: Data) throws {
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "WuraTimer", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "File doesn't contain a settings object."
            ])
        }
        let defaults = UserDefaults.standard
        for key in Defaults.exportable {
            if let v = dict[key] {
                defaults.set(v, forKey: key)
            }
        }
    }

    private static func presentError(_ message: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
