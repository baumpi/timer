import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` (macOS 13+) so the rest of the
/// app can treat launch-at-login as a single Bool. `SMAppService` reflects
/// system state directly — there's no separate persistence to manage.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Tries to register or unregister. Returns true on success. On failure
    /// (e.g. user-blocked in System Settings) we log and return false so the
    /// UI toggle can revert.
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
            return true
        } catch {
            NSLog("[LaunchAtLogin] toggle failed: \(error)")
            return false
        }
    }
}
