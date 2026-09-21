//
//  Settings.swift
//  DevSim
//

import Foundation
import ServiceManagement

/// Login-item state, backed by `SMAppService`.
///
/// Since macOS 13 an app can register itself as a login item, so there is no separate
/// helper bundle to keep in sync.
enum Settings {
    static var isStartAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns `nil` on success, or a message describing why it failed.
    static func setStartAtLogin(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
