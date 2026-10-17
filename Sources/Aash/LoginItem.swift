import ServiceManagement

/// Opening Aash at login, through SMAppService.
@MainActor
enum LoginItem {
    /// True when Aash is registered to open at login.
    static var isEnabled: Bool {
        // Asked from the system every time: the user can change it in System Settings.
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters Aash as a login item.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
