//
//  Simulator.swift
//  DevSim
//

import Foundation

/// A CoreSimulator device, read straight off disk from its `device.plist`.
struct Simulator: Sendable {
    /// CoreSimulator's `SimDeviceState` values.
    enum State: Int, Sendable {
        case creating = 0
        case shutdown = 1
        case booting = 2
        case booted = 3
        case shuttingDown = 4
    }

    let udid: String
    let name: String
    let runtimeIdentifier: String
    let state: State

    /// Root folder of the device, e.g. `~/Library/Developer/CoreSimulator/Devices/<udid>`.
    let url: URL

    /// Best available "when did I last touch this device" signal, used for ordering.
    let lastModified: Date

    init?(deviceURL: URL) {
        let propertiesURL = deviceURL.appendingPathComponent(Constants.Simulator.devicePropertiesFile)

        guard let properties = NSDictionary(contentsOf: propertiesURL) as? [String: Any],
              let name = properties["name"] as? String,
              let runtime = properties["runtime"] as? String
        else { return nil }

        // A deleted device keeps its folder around until CoreSimulator garbage-collects it.
        if properties["isDeleted"] as? Bool == true { return nil }

        self.udid = properties["UDID"] as? String ?? deviceURL.lastPathComponent
        self.name = name
        self.runtimeIdentifier = runtime
        self.state = State(rawValue: properties["state"] as? Int ?? 1) ?? .shutdown
        self.url = deviceURL

        let deviceDate = FileSystem.modificationDate(of: propertiesURL) ?? .distantPast
        let containersDate = FileSystem.modificationDate(of: Simulator.applicationDataURL(in: deviceURL)) ?? .distantPast
        self.lastModified = max(deviceDate, containersDate)
    }

    var isBooted: Bool { state == .booted || state == .booting }

    /// The subset of a device menu actions need to carry around.
    struct Reference: Sendable {
        let udid: String
        let name: String
        let isBooted: Bool
        let url: URL
    }

    var reference: Reference {
        Reference(udid: udid, name: name, isBooted: isBooted, url: url)
    }

    /// `com.apple.CoreSimulator.SimRuntime.iOS-26-5` becomes `iOS 26.5`.
    var os: String {
        let prefix = "com.apple.CoreSimulator.SimRuntime."
        guard runtimeIdentifier.hasPrefix(prefix) else { return runtimeIdentifier }

        let components = runtimeIdentifier.dropFirst(prefix.count).split(separator: "-")
        guard let platform = components.first else { return runtimeIdentifier }

        let version = components.dropFirst().joined(separator: ".")
        return version.isEmpty ? String(platform) : "\(platform) \(version)"
    }

    /// The title shown as the (disabled) section header for this device.
    var menuTitle: String {
        isBooted ? "\(name) (\(os)) — Booted" : "\(name) (\(os))"
    }

    var applicationDataURL: URL { Simulator.applicationDataURL(in: url) }
    var applicationBundleURL: URL { url.appendingPathComponent(Constants.Simulator.applicationBundlePath) }
    var appGroupURL: URL { url.appendingPathComponent(Constants.Simulator.appGroupPath) }
    var appExtensionURL: URL { url.appendingPathComponent(Constants.Simulator.appExtensionPath) }

    private static func applicationDataURL(in deviceURL: URL) -> URL {
        deviceURL.appendingPathComponent(Constants.Simulator.applicationDataPath)
    }
}
