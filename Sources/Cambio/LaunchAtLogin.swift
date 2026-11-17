import Observation
import ServiceManagement

/// "Open at login", backed by the system's login items. Starts off; the person opts in.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled: Bool
    @ObservationIgnored private let forced: Bool?

    /// `forced` pins the value for screenshots.
    init(forced: Bool? = nil) {
        self.forced = forced
        self.isEnabled = forced ?? (SMAppService.mainApp.status == .enabled)
    }

    func refresh() {
        guard forced == nil else { return }
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        guard forced == nil else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // The status read below is the source of truth either way.
        }
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        refresh()
    }
}
