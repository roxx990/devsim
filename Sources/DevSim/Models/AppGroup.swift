//
//  AppGroup.swift
//  DevSim
//

import Foundation

/// A shared App Group container.
struct AppGroup {
    let identifier: String
    let url: URL

    init?(container: FileSystem.Entry) {
        guard let identifier = FileSystem.containerIdentifier(at: container.url),
              !identifier.isEmpty
        else { return nil }

        self.identifier = identifier
        self.url = container.url
    }

    var isSystemGroup: Bool {
        // Groups the simulator creates for its own built-in apps. They show up on
        // every device and are never what the developer is looking for.
        let systemPrefixes = ["com.apple", "group.com.apple", "group.is.workflow",
                              "group.tvappservices", "systemgroup.",
                              "243LU875E5.groups.com.apple"]
        return systemPrefixes.contains { identifier.hasPrefix($0) }
    }

    var menuTitle: String { identifier }
}
