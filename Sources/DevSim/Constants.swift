//
//  Constants.swift
//  DevSim
//

import Foundation

nonisolated enum Constants {
    /// Size, in points, of the small app icons used in submenu rows.
    static let submenuIconSize = CGSize(width: 16, height: 16)

    /// Size, in points, of the app icons shown next to each installed application.
    static let applicationIconSize = CGSize(width: 24, height: 24)

    /// How many simulators are listed in the menu, most recently used first.
    static let maxRecentSimulators = 5

    enum Simulator {
        /// Relative to the user's home directory.
        static let devicesPath = "Library/Developer/CoreSimulator/Devices"
        static let devicePropertiesFile = "device.plist"

        /// Relative to a device's root folder.
        static let applicationDataPath = "data/Containers/Data/Application"
        static let applicationBundlePath = "data/Containers/Bundle/Application"
        static let appGroupPath = "data/Containers/Shared/AppGroup"
        static let appExtensionPath = "data/Containers/Data/PluginKitPlugin"

        /// Written by CoreSimulator into every container folder.
        static let containerMetadataFile = ".com.apple.mobile_container_manager.metadata.plist"
        static let containerIdentifierKey = "MCMMetadataIdentifier"
    }

    enum Titles {
        static let clipboard = "Copy Path to Clipboard"
        static let revealBundle = "Show App Bundle"
        static let screenshot = "Take Screenshot"
        static let reset = "Reset Application Data"
        static let deleteApplication = "Delete Application\u{2026}"
        static let openDeviceFolder = "Open Device Folder"
        static let copyDeviceUDID = "Copy Device UDID"
        static let bootDevice = "Boot Simulator"
        static let shutDownDevice = "Shut Down Simulator"
        static let eraseDevice = "Erase Simulator\u{2026}"
        static let login = "Start at Login"
        static let quit = "Quit"
        static let noSimulators = "No Simulators with Apps"
    }

    /// Folders wiped by "Reset Application Data", relative to an app's data container.
    static let resettableFolders = ["Documents", "Library", "tmp"]

    /// Folders searched for database files, relative to an app's data container.
    static let databaseSearchPaths = ["Documents", "Library", "Library/Caches",
                                      "Library/Application Support"]

    static let dsStore = ".DS_Store"
}
