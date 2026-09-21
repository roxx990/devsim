//
//  AppDelegate.swift
//  DevSim
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    /// LaunchServices lookups are cached; this is how stale that cache may get.
    private static let lookupCacheLifetime: TimeInterval = 60
    private var lastCacheReset = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        item.button?.image = Self.statusBarImage()
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "\(AppInfo.name) \(AppInfo.version)"

        let menu = NSMenu()
        menu.autoenablesItems = true
        menu.delegate = self
        item.menu = menu

        Actions.shared.statusButton = item.button
        statusItem = item
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// The menu bar glyph. SF Symbols keeps it matching the rest of the menu bar at any
    /// size and in both appearances; the drawn fallback is only for odd installs.
    private static func statusBarImage() -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)

        for symbol in ["apps.iphone", "iphone.gen3", "iphone"] {
            if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: AppInfo.name) {
                return image.withSymbolConfiguration(configuration) ?? image
            }
        }

        return NSImage(size: NSSize(width: 14, height: 18), flipped: false) { rect in
            let body = rect.insetBy(dx: 1, dy: 1)
            let path = NSBezierPath(roundedRect: body, xRadius: 3, yRadius: 3)
            path.lineWidth = 1.5
            NSColor.black.setStroke()
            path.stroke()
            return true
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if Date().timeIntervalSince(lastCacheReset) > Self.lookupCacheLifetime {
            ExternalApps.reset()
            DatabaseFinder.reset()
            lastCacheReset = Date()
        }

        MenuBuilder.rebuild(menu)
    }
}
