//
//  DatabaseFinder.swift
//  DevSim
//

import AppKit

/// Locates database files inside an app's data container and the viewer to open them with.
///
/// Core Data and SwiftData both write SQLite, so those are covered alongside Realm, and
/// whichever viewer is installed gets used.
enum DatabaseFinder {
    struct Viewer {
        let name: String
        let url: URL
    }

    /// Extensions worth surfacing: Realm, plus the SQLite files Core Data and
    /// SwiftData write.
    private static let databaseExtensions: Set<String> = ["realm", "sqlite", "sqlite3", "db", "store"]

    private static let viewerCandidates: [(name: String, identifiers: [String], path: String)] = [
        ("TablePlus", ["com.tinyapp.TablePlus", "com.tinyapp.TablePlus-setapp"], "/Applications/TablePlus.app"),
        ("DB Browser for SQLite", ["net.sourceforge.sqlitebrowser"], "/Applications/DB Browser for SQLite.app"),
        ("Realm Studio", ["io.realm.realmbrowser"], "/Applications/Realm Studio.app"),
        ("Base", ["com.menial.Base"], "/Applications/Base.app")
    ]

    private static var cachedViewer: Viewer??

    /// The first installed database viewer, if any.
    static func viewer() -> Viewer? {
        if let cachedViewer { return cachedViewer }

        let found = viewerCandidates.lazy.compactMap { candidate -> Viewer? in
            for identifier in candidate.identifiers {
                if let url = ExternalApps.url(forBundleIdentifier: identifier) {
                    return Viewer(name: candidate.name, url: url)
                }
            }
            let url = URL(fileURLWithPath: candidate.path)
            return FileSystem.exists(url) ? Viewer(name: candidate.name, url: url) : nil
        }.first

        cachedViewer = .some(found)
        return found
    }

    static func reset() { cachedViewer = nil }

    /// Database files directly inside the usual container sub-folders.
    static func databases(in containerURL: URL) -> [URL] {
        Constants.databaseSearchPaths.flatMap { relativePath in
            FileSystem.files(in: containerURL.appendingPathComponent(relativePath),
                             withExtensions: databaseExtensions)
        }
    }
}
