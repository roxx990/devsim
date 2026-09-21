//
//  ExternalApps.swift
//  DevSim
//

import AppKit

/// A third-party app that can open a folder, resolved through LaunchServices.
struct ExternalApp {
    let name: String
    let url: URL

    /// Commander One opens the parent of the path it is handed, so it needs a
    /// trailing component to land in the right folder.
    let opensParentFolder: Bool
}

/// Looks up the file managers, terminals and editors installed on this Mac.
///
/// Lookups go through `NSWorkspace` rather than the deprecated
/// `LSCopyApplicationURLsForBundleIdentifier`, with a path check as a backstop for apps
/// that are not registered with LaunchServices yet.
enum ExternalApps {
    private struct Candidate {
        let name: String
        let bundleIdentifiers: [String]
        let paths: [String]
        var opensParentFolder = false
    }

    private static let candidates: [Candidate] = [
        Candidate(name: "Finder", bundleIdentifiers: ["com.apple.finder"],
                  paths: ["/System/Library/CoreServices/Finder.app"]),
        Candidate(name: "Terminal", bundleIdentifiers: ["com.apple.Terminal"],
                  paths: ["/System/Applications/Utilities/Terminal.app"]),
        Candidate(name: "iTerm", bundleIdentifiers: ["com.googlecode.iterm2"],
                  paths: ["/Applications/iTerm.app"]),
        Candidate(name: "Ghostty", bundleIdentifiers: ["com.mitchellh.ghostty"],
                  paths: ["/Applications/Ghostty.app"]),
        Candidate(name: "Warp", bundleIdentifiers: ["dev.warp.Warp-Stable", "dev.warp.Warp"],
                  paths: ["/Applications/Warp.app"]),
        Candidate(name: "WezTerm", bundleIdentifiers: ["com.github.wez.wezterm"],
                  paths: ["/Applications/WezTerm.app"]),
        Candidate(name: "Kitty", bundleIdentifiers: ["net.kovidgoyal.kitty"],
                  paths: ["/Applications/kitty.app"]),
        Candidate(name: "Alacritty", bundleIdentifiers: ["org.alacritty"],
                  paths: ["/Applications/Alacritty.app"]),
        Candidate(name: "Visual Studio Code", bundleIdentifiers: ["com.microsoft.VSCode"],
                  paths: ["/Applications/Visual Studio Code.app"]),
        Candidate(name: "Cursor", bundleIdentifiers: ["com.todesktop.230313mzl4w4u92"],
                  paths: ["/Applications/Cursor.app"]),
        Candidate(name: "Commander One", bundleIdentifiers: ["com.eltima.cmd1", "com.eltima.cmd1.pro"],
                  paths: ["/Applications/Commander One.app", "/Applications/Commander One PRO.app"],
                  opensParentFolder: true),
        Candidate(name: "ForkLift", bundleIdentifiers: ["com.binarynights.ForkLift", "com.binarynights.ForkLift-3"],
                  paths: ["/Applications/ForkLift.app"]),
        Candidate(name: "Path Finder", bundleIdentifiers: ["com.cocoatech.PathFinder"],
                  paths: ["/Applications/Path Finder.app"])
    ]

    /// Cached because LaunchServices lookups are not free and the menu is rebuilt on
    /// every click. `reset()` clears it if the user installs something mid-session.
    private static var cached: [ExternalApp]?

    /// Every supported folder-opening app that is actually installed, in menu order.
    static func installed() -> [ExternalApp] {
        if let cached { return cached }

        let apps = candidates.compactMap { candidate -> ExternalApp? in
            guard let url = resolve(candidate) else { return nil }
            return ExternalApp(name: candidate.name, url: url,
                               opensParentFolder: candidate.opensParentFolder)
        }

        cached = apps
        return apps
    }

    static func reset() { cached = nil }

    static func url(forBundleIdentifier identifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
    }

    private static func resolve(_ candidate: Candidate) -> URL? {
        for identifier in candidate.bundleIdentifiers {
            if let url = url(forBundleIdentifier: identifier) { return url }
        }
        for path in candidate.paths {
            let url = URL(fileURLWithPath: path)
            if FileSystem.exists(url) { return url }
        }
        return nil
    }
}
