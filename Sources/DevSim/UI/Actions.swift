//
//  Actions.swift
//  DevSim
//

import AppKit

/// Target for every menu item. One shared instance owns all the selectors.
final class Actions: NSObject {
    static let shared = Actions()

    /// Set by `AppDelegate`, so long-running work can dim the menu bar icon.
    weak var statusButton: NSStatusBarButton?

    /// Number of `simctl` operations in flight.
    private var busyCount = 0

    private override init() { super.init() }

    private func context(of sender: Any?) -> ActionContext? {
        (sender as? NSMenuItem)?.representedObject as? ActionContext
    }

    // MARK: - Opening folders

    /// Clicking a row itself. Modifiers pick an alternative app:
    /// ⌥ opens a terminal, ⌃ opens the alternative file manager.
    @objc func openContainer(_ sender: NSMenuItem) {
        guard let context = context(of: sender) else { return }
        let modifiers = NSApp.currentEvent?.modifierFlags ?? []

        let installed = ExternalApps.installed()
        let finder = installed.first { $0.name == "Finder" }
        let preferred: ExternalApp?

        if modifiers.contains(.option) {
            preferred = installed.first { $0.name == "Terminal" } ?? finder
        } else if modifiers.contains(.control) {
            // Commander One is the only alternative file manager with a modifier.
            preferred = installed.first(where: \.opensParentFolder) ?? finder
        } else {
            preferred = finder
        }

        if let preferred {
            open(context.folderURL, with: preferred)
        } else {
            NSWorkspace.shared.open(context.folderURL)
        }
    }

    @objc func openInExternalApp(_ sender: NSMenuItem) {
        guard let context = context(of: sender) else { return }

        guard let app = context.externalApp else {
            NSWorkspace.shared.open(context.fileURL ?? context.folderURL)
            return
        }

        open(context.fileURL ?? context.folderURL, with: app)
    }

    @objc func showAppBundle(_ sender: NSMenuItem) {
        guard let bundleURL = context(of: sender)?.bundleURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    }

    @objc func copyPath(_ sender: NSMenuItem) {
        guard let context = context(of: sender) else { return }
        copyToPasteboard(context.folderURL.path)
    }

    @objc func copyDeviceUDID(_ sender: NSMenuItem) {
        guard let udid = context(of: sender)?.simulator?.udid else { return }
        copyToPasteboard(udid)
    }

    // MARK: - Application data

    @objc func resetApplicationData(_ sender: NSMenuItem) {
        guard let context = context(of: sender) else { return }

        let confirmed = confirm(
            title: "Reset data for “\(context.displayName)”?",
            message: """
                This permanently deletes the Documents, Library and tmp folders in the \
                app's container. The app will start as if freshly installed.
                """,
            buttonTitle: "Reset")
        guard confirmed else { return }

        var failures: [String] = []
        for folder in Constants.resettableFolders {
            let target = context.folderURL.appendingPathComponent(folder)
            if !FileSystem.remove(target) { failures.append(folder) }
        }

        if !failures.isEmpty {
            presentError(title: "Could not fully reset “\(context.displayName)”",
                         message: "These folders could not be deleted: \(failures.joined(separator: ", ")).")
        }
    }

    /// Uninstalls the app from the simulator, removing the binary along with its data.
    @objc func deleteApplication(_ sender: NSMenuItem) {
        guard let context = context(of: sender),
              let identifier = context.bundleIdentifier,
              let device = context.simulator
        else { return }

        // simctl can only uninstall from a booted device, so a shut down one is booted
        // for the duration. Say so up front rather than surprising anyone.
        let bootNote = device.isBooted
            ? ""
            : "\n\n\(device.name) is shut down, so it will be booted briefly and then shut down again."

        let confirmed = confirm(
            title: "Delete “\(context.displayName)” from \(device.name)?",
            message: "This uninstalls the app and deletes all of its data on that simulator."
                + bootNote,
            buttonTitle: "Delete")
        guard confirmed else { return }

        perform(failureTitle: "Could not delete “\(context.displayName)”") {
            SimulatorControl.uninstall(bundleIdentifier: identifier, from: device)
        }
    }

    // MARK: - Devices

    @objc func eraseSimulator(_ sender: NSMenuItem) {
        guard let device = context(of: sender)?.simulator else { return }

        let bootNote = device.isBooted
            ? "\n\n\(device.name) will be shut down, erased, and booted again."
            : ""

        let confirmed = confirm(
            title: "Erase \(device.name)?",
            message: """
                This erases all content and settings on the simulator. Every app installed \
                on it, and all of their data, is deleted.
                """ + bootNote,
            buttonTitle: "Erase")
        guard confirmed else { return }

        perform(failureTitle: "Could not erase \(device.name)") {
            SimulatorControl.erase(device)
        }
    }

    @objc func bootSimulator(_ sender: NSMenuItem) {
        guard let device = context(of: sender)?.simulator else { return }

        perform(failureTitle: "Could not boot \(device.name)") {
            SimulatorControl.boot(device)
        }
    }

    @objc func shutDownSimulator(_ sender: NSMenuItem) {
        guard let device = context(of: sender)?.simulator else { return }

        perform(failureTitle: "Could not shut down \(device.name)") {
            SimulatorControl.shutDown(device)
        }
    }

    @objc func takeScreenshot(_ sender: NSMenuItem) {
        guard let device = context(of: sender)?.simulator else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let filename = "\(device.name) \(formatter.string(from: Date())).png"

        guard let destination = FileManager.default
            .urls(for: .desktopDirectory, in: .userDomainMask).first?
            .appendingPathComponent(filename)
        else { return }

        perform(failureTitle: "Screenshot failed") {
            let outcome = SimulatorControl.screenshot(device, to: destination)
            if outcome.succeeded {
                Task { @MainActor in
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                }
            }
            return outcome
        }
    }

    // MARK: - Service items

    @objc func toggleStartAtLogin(_ sender: NSMenuItem) {
        let shouldEnable = !Settings.isStartAtLoginEnabled

        if let message = Settings.setStartAtLogin(shouldEnable) {
            presentError(title: "Could not \(shouldEnable ? "enable" : "disable") Start at Login",
                         message: message)
            return
        }

        sender.state = Settings.isStartAtLoginEnabled ? .on : .off
    }

    @objc func showAbout(_ sender: NSMenuItem) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .credits: NSAttributedString(
                string: "Quick access to simulator app containers.",
                attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)])
        ])
    }

    @objc func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func open(_ url: URL, with app: ExternalApp) {
        // Commander One opens the parent of whatever it is given, so point it one
        // level deeper to land in the folder the user picked.
        let target = app.opensParentFolder ? url.appendingPathComponent("Library") : url

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open([target], withApplicationAt: app.url, configuration: configuration) { _, error in
            guard let error else { return }
            NSLog("DevSim: failed to open \(target.path) in \(app.name): \(error.localizedDescription)")
        }
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    /// Runs a `simctl` operation off the main thread and reports failures.
    ///
    /// Booting and erasing take the better part of a minute, so nothing blocks the menu;
    /// the icon dims while work is in flight and the menu, rebuilt from disk each time it
    /// opens, shows the result.
    private func perform(failureTitle: String,
                         _ work: @escaping @Sendable () -> SimulatorControl.Outcome) {
        setBusy(true)

        Task.detached {
            let outcome = work()

            await MainActor.run {
                Actions.shared.setBusy(false)
                guard !outcome.succeeded else { return }
                Actions.shared.presentError(title: failureTitle, message: outcome.message)
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        busyCount = max(0, busyCount + (busy ? 1 : -1))

        let working = busyCount > 0
        statusButton?.appearsDisabled = working
        statusButton?.toolTip = working
            ? "\(AppInfo.name) — working\u{2026}"
            : "\(AppInfo.name) \(AppInfo.version)"
    }

    private func confirm(title: String, message: String, buttonTitle: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: buttonTitle)
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true

        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    fileprivate func presentError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
