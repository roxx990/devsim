//
//  MenuBuilder.swift
//  DevSim
//

import AppKit

/// Rebuilds the status bar menu each time it is opened.
enum MenuBuilder {
    static func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        let simulators = recentSimulatorsWithApps(limit: Constants.maxRecentSimulators)

        if simulators.isEmpty {
            menu.addItem(disabledItem(titled: Constants.Titles.noSimulators))
        }

        for (index, entry) in simulators.enumerated() {
            if index > 0 { menu.addItem(.separator()) }

            menu.addItem(header(for: entry.simulator))

            for application in entry.applications {
                menu.addItem(item(for: application, on: entry.simulator))
            }
            for group in SimulatorScanner.appGroups(on: entry.simulator) {
                menu.addItem(item(forContainer: group.menuTitle, url: group.url, on: entry.simulator))
            }
            for appExtension in SimulatorScanner.appExtensions(on: entry.simulator) {
                menu.addItem(item(forContainer: appExtension.menuTitle, url: appExtension.url, on: entry.simulator))
            }
        }

        menu.addItem(.separator())
        addServiceItems(to: menu)
    }

    // MARK: - Gathering

    private struct SimulatorEntry {
        let simulator: Simulator
        let applications: [Application]
    }

    /// Walks simulators newest-first and keeps the first `limit` that actually have
    /// apps installed, so empty devices never take up a slot.
    private static func recentSimulatorsWithApps(limit: Int) -> [SimulatorEntry] {
        var entries: [SimulatorEntry] = []

        for simulator in SimulatorScanner.allSimulators() {
            let applications = SimulatorScanner.applications(on: simulator)
            guard !applications.isEmpty else { continue }

            entries.append(SimulatorEntry(simulator: simulator, applications: applications))
            if entries.count == limit { break }
        }
        return entries
    }

    // MARK: - Rows

    private static func disabledItem(titled title: String) -> NSMenuItem {
        // A nil action leaves the item disabled, which is what greys out the header.
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private static func item(for application: Application, on simulator: Simulator) -> NSMenuItem {
        let context = ActionContext(folderURL: application.dataURL,
                                    displayName: application.name,
                                    bundleURL: application.bundleURL,
                                    bundleIdentifier: application.bundleIdentifier,
                                    simulator: simulator.reference)

        let item = NSMenuItem(title: application.menuTitle,
                              action: #selector(Actions.openContainer(_:)),
                              keyEquivalent: "")
        item.target = Actions.shared
        item.representedObject = context
        item.image = application.icon
        item.submenu = submenu(for: context, isApplication: true, simulator: simulator)
        return item
    }

    private static func item(forContainer title: String, url: URL, on simulator: Simulator) -> NSMenuItem {
        let context = ActionContext(folderURL: url,
                                    displayName: title,
                                    simulator: simulator.reference)

        let item = NSMenuItem(title: title,
                              action: #selector(Actions.openContainer(_:)),
                              keyEquivalent: "")
        item.target = Actions.shared
        item.representedObject = context
        item.submenu = submenu(for: context, isApplication: false, simulator: simulator)
        return item
    }

    // MARK: - Submenu

    private static func submenu(for context: ActionContext,
                                isApplication: Bool,
                                simulator: Simulator) -> NSMenu {
        let submenu = NSMenu()
        var hotkey = HotkeySequence()

        for app in ExternalApps.installed() {
            let item = NSMenuItem(title: app.name,
                                  action: #selector(Actions.openInExternalApp(_:)),
                                  keyEquivalent: hotkey.next())
            item.target = Actions.shared
            item.representedObject = context.opening(with: app)
            item.image = icon(forApplicationAt: app.url)
            submenu.addItem(item)
        }

        addDatabaseItems(to: submenu, context: context, hotkey: &hotkey)

        submenu.addItem(.separator())

        submenu.addItem(item(Constants.Titles.clipboard,
                             #selector(Actions.copyPath(_:)), context, &hotkey))

        if isApplication, context.bundleURL != nil {
            submenu.addItem(item(Constants.Titles.revealBundle,
                                 #selector(Actions.showAppBundle(_:)), context, &hotkey))
        }

        if isApplication, simulator.isBooted {
            submenu.addItem(item(Constants.Titles.screenshot,
                                 #selector(Actions.takeScreenshot(_:)),
                                 context, &hotkey))
        }

        if isApplication {
            submenu.addItem(item(Constants.Titles.reset,
                                 #selector(Actions.resetApplicationData(_:)),
                                 context, &hotkey))

            // Only offered when the app was matched to an installed bundle; without a
            // bundle identifier there is nothing for simctl to uninstall.
            if context.bundleIdentifier != nil {
                submenu.addItem(item(Constants.Titles.deleteApplication,
                                     #selector(Actions.deleteApplication(_:)),
                                     context, &hotkey))
            }
        }

        return submenu
    }

    // MARK: - Device section header

    /// The per-simulator row. It reads as a header but opens the device folder when
    /// clicked, and carries the device-level actions in its submenu.
    private static func header(for simulator: Simulator) -> NSMenuItem {
        let context = ActionContext(folderURL: simulator.url,
                                    displayName: simulator.name,
                                    simulator: simulator.reference)

        let headerItem = NSMenuItem(title: simulator.menuTitle,
                                    action: #selector(Actions.openContainer(_:)),
                                    keyEquivalent: "")
        headerItem.target = Actions.shared
        headerItem.representedObject = context
        headerItem.attributedTitle = NSAttributedString(
            string: simulator.menuTitle,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ])

        let submenu = NSMenu()
        var hotkey = HotkeySequence()

        submenu.addItem(item(Constants.Titles.openDeviceFolder,
                             #selector(Actions.openContainer(_:)), context, &hotkey))
        submenu.addItem(item(Constants.Titles.copyDeviceUDID,
                             #selector(Actions.copyDeviceUDID(_:)), context, &hotkey))

        if simulator.isBooted {
            submenu.addItem(item(Constants.Titles.screenshot,
                                 #selector(Actions.takeScreenshot(_:)), context, &hotkey))
        }

        submenu.addItem(.separator())

        if simulator.isBooted {
            submenu.addItem(item(Constants.Titles.shutDownDevice,
                                 #selector(Actions.shutDownSimulator(_:)), context, &hotkey))
        } else {
            submenu.addItem(item(Constants.Titles.bootDevice,
                                 #selector(Actions.bootSimulator(_:)), context, &hotkey))
        }

        submenu.addItem(item(Constants.Titles.eraseDevice,
                             #selector(Actions.eraseSimulator(_:)), context, &hotkey))

        headerItem.submenu = submenu
        return headerItem
    }

    /// A plain action row: next hotkey in the sequence, targeting `Actions.shared`.
    private static func item(_ title: String,
                             _ action: Selector,
                             _ context: ActionContext,
                             _ hotkey: inout HotkeySequence) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: hotkey.next())
        item.target = Actions.shared
        item.representedObject = context
        return item
    }

    private static func addDatabaseItems(to submenu: NSMenu,
                                         context: ActionContext,
                                         hotkey: inout HotkeySequence) {
        let databases = DatabaseFinder.databases(in: context.folderURL)
        guard !databases.isEmpty else { return }

        let viewer = DatabaseFinder.viewer()
        let externalApp = viewer.map { ExternalApp(name: $0.name, url: $0.url, opensParentFolder: false) }
        let title = viewer?.name ?? "Databases"
        let image = viewer.map { icon(forApplicationAt: $0.url) }

        if databases.count == 1, let database = databases.first {
            let item = NSMenuItem(title: title,
                                  action: #selector(Actions.openInExternalApp(_:)),
                                  keyEquivalent: hotkey.next())
            item.target = Actions.shared
            item.representedObject = context.opening(file: database, with: externalApp)
            item.image = image
            submenu.addItem(item)
            return
        }

        // AppKit drops the key equivalent of an item that owns a submenu, so this
        // one is left unnumbered rather than leaving a hole in the sequence.
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.image = image

        let databaseMenu = NSMenu()
        for database in databases {
            let item = NSMenuItem(title: database.lastPathComponent,
                                  action: #selector(Actions.openInExternalApp(_:)),
                                  keyEquivalent: "")
            item.target = Actions.shared
            item.representedObject = context.opening(file: database, with: externalApp)
            databaseMenu.addItem(item)
        }

        parent.submenu = databaseMenu
        submenu.addItem(parent)
    }

    // MARK: - Service items

    private static func addServiceItems(to menu: NSMenu) {
        let startAtLogin = NSMenuItem(title: Constants.Titles.login,
                                      action: #selector(Actions.toggleStartAtLogin(_:)),
                                      keyEquivalent: "")
        startAtLogin.target = Actions.shared
        startAtLogin.state = Settings.isStartAtLoginEnabled ? .on : .off
        menu.addItem(startAtLogin)

        let about = NSMenuItem(title: "About \(AppInfo.name) \(AppInfo.version)",
                               action: #selector(Actions.showAbout(_:)),
                               keyEquivalent: "i")
        about.keyEquivalentModifierMask = [.command, .shift]
        about.target = Actions.shared
        menu.addItem(about)

        let quit = NSMenuItem(title: Constants.Titles.quit,
                              action: #selector(Actions.quit(_:)),
                              keyEquivalent: "q")
        quit.keyEquivalentModifierMask = [.command, .shift]
        quit.target = Actions.shared
        menu.addItem(quit)
    }

    // MARK: - Helpers

    private static func icon(forApplicationAt url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = Constants.submenuIconSize
        return icon
    }

    /// Hands out ⌘1 … ⌘9 and then nothing, so submenu rows stay numbered.
    private struct HotkeySequence {
        private var index = 1

        mutating func next() -> String {
            guard index <= 9 else { return "" }
            defer { index += 1 }
            return String(index)
        }
    }
}
