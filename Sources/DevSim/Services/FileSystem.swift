//
//  FileSystem.swift
//  DevSim
//

import Foundation

/// Thin, non-throwing wrappers around `FileManager` used while walking simulator folders.
nonisolated enum FileSystem {
    /// A direct child folder of a container directory, with the metadata needed to sort it.
    struct Entry {
        let url: URL
        let name: String
        let modificationDate: Date
    }

    static func modificationDate(of url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate
    }

    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Immediate sub-directories of `url`, most recently modified first.
    static func childDirectories(of url: URL) -> [Entry] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey, .nameKey]

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        return contents
            .compactMap { child -> Entry? in
                let values = try? child.resourceValues(forKeys: Set(keys))
                guard values?.isDirectory == true else { return nil }
                guard child.lastPathComponent != Constants.dsStore else { return nil }

                return Entry(url: child,
                             name: values?.name ?? child.lastPathComponent,
                             modificationDate: values?.contentModificationDate ?? .distantPast)
            }
            .sorted { $0.modificationDate > $1.modificationDate }
    }

    /// Files directly inside `url` whose extension is one of `extensions` (case-insensitive).
    static func files(in url: URL, withExtensions extensions: Set<String>) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// The `MCMMetadataIdentifier` CoreSimulator writes next to every container.
    static func containerIdentifier(at url: URL) -> String? {
        let metadataURL = url.appendingPathComponent(Constants.Simulator.containerMetadataFile)
        guard let plist = NSDictionary(contentsOf: metadataURL) else { return nil }
        return plist[Constants.Simulator.containerIdentifierKey] as? String
    }

    /// The `.app` bundle inside a bundle container folder.
    static func appBundle(in containerURL: URL) -> URL? {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: containerURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents.first { $0.pathExtension == "app" }
    }

    /// Deletes `folder` if it exists. Returns `false` when the delete failed.
    @discardableResult
    static func remove(_ url: URL) -> Bool {
        guard exists(url) else { return true }
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            NSLog("DevSim: failed to remove \(url.path): \(error.localizedDescription)")
            return false
        }
    }
}
