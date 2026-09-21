//
//  SimulatorScanner.swift
//  DevSim
//

import Foundation

/// Discovers simulators and their containers by walking `~/Library/Developer/CoreSimulator`.
///
/// Older versions of this app read the device list out of
/// `com.apple.iphonesimulator.plist`, which only lists devices that have been opened in
/// Simulator.app — devices booted by `xcodebuild` or `simctl` were invisible. Walking the
/// device folders directly finds everything and needs no shelling out to `simctl`.
enum SimulatorScanner {
    static var devicesURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(Constants.Simulator.devicesPath)
    }

    /// All devices on disk, booted ones first, then most recently used.
    static func allSimulators() -> [Simulator] {
        FileSystem.childDirectories(of: devicesURL)
            .compactMap { Simulator(deviceURL: $0.url) }
            .sorted { lhs, rhs in
                if lhs.isBooted != rhs.isBooted { return lhs.isBooted }
                return lhs.lastModified > rhs.lastModified
            }
    }

    /// Non-Apple apps installed on `simulator`, most recently installed first.
    static func applications(on simulator: Simulator) -> [Application] {
        let bundleContainers = bundleContainerIndex(for: simulator)

        return FileSystem.childDirectories(of: simulator.applicationDataURL)
            .compactMap { Application(dataContainer: $0, bundleContainers: bundleContainers) }
            .filter { !$0.isAppleApplication }
    }

    static func appGroups(on simulator: Simulator) -> [AppGroup] {
        FileSystem.childDirectories(of: simulator.appGroupURL)
            .compactMap(AppGroup.init(container:))
            .filter { !$0.isSystemGroup }
    }

    static func appExtensions(on simulator: Simulator) -> [AppExtension] {
        FileSystem.childDirectories(of: simulator.appExtensionURL)
            .compactMap(AppExtension.init(container:))
            .filter { !$0.isSystemExtension }
    }

    /// Maps bundle identifier to bundle container folder, so each app is a dictionary
    /// lookup rather than a rescan of every bundle on the device.
    private static func bundleContainerIndex(for simulator: Simulator) -> [String: URL] {
        var index: [String: URL] = [:]

        for container in FileSystem.childDirectories(of: simulator.applicationBundleURL) {
            guard let identifier = FileSystem.containerIdentifier(at: container.url) else { continue }
            index[identifier] = container.url
        }
        return index
    }
}
