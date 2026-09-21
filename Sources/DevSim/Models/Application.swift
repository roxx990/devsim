//
//  Application.swift
//  DevSim
//

import AppKit

/// An app installed on a simulator: its data container plus the `.app` bundle backing it.
struct Application {
    let bundleIdentifier: String
    let name: String
    let version: String?

    /// The data container — Documents / Library / tmp. This is what the menu opens.
    let dataURL: URL

    /// The installed `.app` bundle, when it could be located.
    let bundleURL: URL?

    let icon: NSImage

    init?(dataContainer: FileSystem.Entry, bundleContainers: [String: URL]) {
        guard let identifier = FileSystem.containerIdentifier(at: dataContainer.url) else { return nil }

        self.bundleIdentifier = identifier
        self.dataURL = dataContainer.url

        let bundleURL = bundleContainers[identifier].flatMap { FileSystem.appBundle(in: $0) }
        self.bundleURL = bundleURL

        let info = bundleURL
            .map { $0.appendingPathComponent("Info.plist") }
            .flatMap { NSDictionary(contentsOf: $0) as? [String: Any] }

        let bundleName = (info?["CFBundleDisplayName"] as? String)
            ?? (info?["CFBundleName"] as? String)

        // Fall back to the bundle folder name (e.g. "MyApp.app") so a partially
        // installed app still shows up with something readable.
        self.name = bundleName?.isEmpty == false
            ? bundleName!
            : (bundleURL?.deletingPathExtension().lastPathComponent ?? identifier)

        self.version = (info?["CFBundleShortVersionString"] as? String)
            ?? (info?["CFBundleVersion"] as? String)

        self.icon = IconLoader.icon(forAppBundle: bundleURL, info: info, fallbackName: self.name)
    }

    var isAppleApplication: Bool { bundleIdentifier.hasPrefix("com.apple") }

    var menuTitle: String {
        guard let version, !version.isEmpty else { return name }
        return "\(name) (\(version))"
    }
}
