//
//  AppExtension.swift
//  DevSim
//

import Foundation

/// A PluginKit container — widgets, share extensions, keyboards and friends.
struct AppExtension {
    let identifier: String
    let url: URL

    init?(container: FileSystem.Entry) {
        guard let identifier = FileSystem.containerIdentifier(at: container.url),
              !identifier.isEmpty
        else { return nil }

        self.identifier = identifier
        self.url = container.url
    }

    var isSystemExtension: Bool { identifier.hasPrefix("com.apple") }

    var menuTitle: String { identifier }
}
