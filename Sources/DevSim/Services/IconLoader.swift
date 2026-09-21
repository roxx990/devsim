//
//  IconLoader.swift
//  DevSim
//

import AppKit

/// Finds an app icon inside a simulator `.app` bundle and renders it for the menu.
///
/// Xcode writes the icon variants listed in `CFBundleIcons` next to the binary, so the
/// loose PNGs are usually there. Apps whose icon only lives in `Assets.car` (and apps
/// with no icon at all) fall back to a generated letter tile.
enum IconLoader {
    private static var cache: [URL: NSImage] = [:]

    static func icon(forAppBundle bundleURL: URL?, info: [String: Any]?, fallbackName: String) -> NSImage {
        if let bundleURL, let cached = cache[bundleURL] { return cached }

        let image = loadIconFile(bundleURL: bundleURL, info: info)
            .map { rounded($0, size: Constants.applicationIconSize) }
            ?? letterTile(for: fallbackName, size: Constants.applicationIconSize)

        if let bundleURL { cache[bundleURL] = image }
        return image
    }

    // MARK: - Locating the file

    private static func loadIconFile(bundleURL: URL?, info: [String: Any]?) -> NSImage? {
        guard let bundleURL else { return nil }

        for candidate in iconCandidates(bundleURL: bundleURL, info: info) {
            if let image = NSImage(contentsOf: candidate), image.isValid {
                return image
            }
        }
        return nil
    }

    private static func iconCandidates(bundleURL: URL, info: [String: Any]?) -> [URL] {
        var names: [String] = []

        // Old-style single icon file.
        if let iconFile = info?["CFBundleIconFile"] as? String {
            names.append(iconFile)
        }

        // Asset-catalog icons, whose rendered variants Xcode copies to the bundle root.
        for (key, suffix) in [("CFBundleIcons", ""), ("CFBundleIcons~ipad", "~ipad")] {
            guard let icons = info?[key] as? [String: Any],
                  let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
                  let files = primary["CFBundleIconFiles"] as? [String]
            else { continue }

            // Last entry is the largest variant.
            for base in files.reversed() {
                names.append(contentsOf: ["\(base)@3x\(suffix)", "\(base)@2x\(suffix)",
                                          "\(base)\(suffix)", base])
            }
        }

        var candidates = names.flatMap { name -> [URL] in
            let url = bundleURL.appendingPathComponent(name)
            // Names in Info.plist usually omit the extension.
            return url.pathExtension.isEmpty
                ? [url.appendingPathExtension("png"), url]
                : [url]
        }

        // Last resort: any AppIcon*.png sitting in the bundle root, largest first.
        let looseIcons = FileSystem.files(in: bundleURL, withExtensions: ["png"])
            .filter { $0.lastPathComponent.lowercased().hasPrefix("appicon") }
            .sorted { lhs, rhs in
                (fileSize(of: lhs) ?? 0) > (fileSize(of: rhs) ?? 0)
            }
        candidates.append(contentsOf: looseIcons)

        return candidates
    }

    private static func fileSize(of url: URL) -> Int? {
        try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
    }

    // MARK: - Rendering

    /// Redraws `image` at menu size with the rounded-square mask iOS icons use.
    private static func rounded(_ image: NSImage, size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current else { return false }
            context.imageInterpolation = .high

            let radius = rect.width * 0.2237
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            path.addClip()

            image.draw(in: rect,
                       from: .zero,
                       operation: .sourceOver,
                       fraction: 1,
                       respectFlipped: true,
                       hints: [.interpolation: NSImageInterpolation.high.rawValue])
            return true
        }
    }

    /// A coloured tile with the app's initial, for apps that ship no loose icon file.
    private static func letterTile(for name: String, size: CGSize) -> NSImage {
        let letter = String(name.first.map(String.init)?.uppercased() ?? "?")
        let hue = CGFloat(abs(name.hashValue % 256)) / 256.0
        let color = NSColor(hue: hue, saturation: 0.45, brightness: 0.78, alpha: 1)

        return NSImage(size: size, flipped: false) { rect in
            let radius = rect.width * 0.2237
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            color.setFill()
            path.fill()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: rect.height * 0.58, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let text = NSAttributedString(string: letter, attributes: attributes)
            let textSize = text.size()
            text.draw(at: NSPoint(x: rect.midX - textSize.width / 2,
                                  y: rect.midY - textSize.height / 2))
            return true
        }
    }
}
