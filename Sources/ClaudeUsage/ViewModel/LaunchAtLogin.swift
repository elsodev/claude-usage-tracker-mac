import Foundation
import ServiceManagement

/// Wrapper around SMAppService for the launch-at-login toggle.
/// Works only when running from the assembled .app bundle; from a bare
/// `swift run` binary it reports unsupported instead of failing silently.
@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published var isEnabled: Bool
    @Published var lastError: String?

    var isSupported: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    init() {
        self.isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        guard isSupported else {
            lastError = "Launch at login requires running the built .app bundle."
            isEnabled = false
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = enabled
            lastError = nil
        } catch {
            lastError = "Could not update login item: \(error.localizedDescription)"
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}
