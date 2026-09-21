//
//  ActionContext.swift
//  DevSim
//

import Foundation

/// What a menu item should act on. Attached to `NSMenuItem.representedObject`.
final class ActionContext: NSObject {
    /// The folder the item operates on — a data container, app group or extension
    /// container, or the device folder for device-level items.
    let folderURL: URL

    /// Shown in confirmation dialogs.
    let displayName: String

    /// The installed `.app` bundle, when the item belongs to an application.
    let bundleURL: URL?

    /// The app's bundle identifier, needed to uninstall it.
    let bundleIdentifier: String?

    /// The device this item sits under.
    let simulator: Simulator.Reference?

    /// The app to open with, for "open in …" items.
    let externalApp: ExternalApp?

    /// A specific file to open, for database items.
    let fileURL: URL?

    init(folderURL: URL,
         displayName: String,
         bundleURL: URL? = nil,
         bundleIdentifier: String? = nil,
         simulator: Simulator.Reference? = nil,
         externalApp: ExternalApp? = nil,
         fileURL: URL? = nil) {
        self.folderURL = folderURL
        self.displayName = displayName
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.simulator = simulator
        self.externalApp = externalApp
        self.fileURL = fileURL
    }

    /// A copy of the receiver bound to a different app, used when building submenus.
    func opening(with app: ExternalApp) -> ActionContext {
        copy(externalApp: app, fileURL: fileURL)
    }

    func opening(file url: URL, with app: ExternalApp?) -> ActionContext {
        copy(externalApp: app, fileURL: url)
    }

    private func copy(externalApp: ExternalApp?, fileURL: URL?) -> ActionContext {
        ActionContext(folderURL: folderURL,
                      displayName: displayName,
                      bundleURL: bundleURL,
                      bundleIdentifier: bundleIdentifier,
                      simulator: simulator,
                      externalApp: externalApp,
                      fileURL: fileURL)
    }
}
