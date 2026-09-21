//
//  MenuDump.swift
//  DevSim
//

import AppKit

/// Renders a menu as indented text, for `DevSim --dump-menu`.
enum MenuDump {
    static func describe(_ menu: NSMenu, indent: Int = 0) -> String {
        menu.items.map { item in
            let padding = String(repeating: "  ", count: indent)

            if item.isSeparatorItem { return padding + "---" }

            var line = padding + item.title
            if !item.keyEquivalent.isEmpty {
                line += "  [\u{2318}\(item.keyEquivalent.uppercased())]"
            }
            if item.state == .on { line += "  \u{2713}" }
            if item.action == nil { line += "  (header)" }

            if let submenu = item.submenu {
                line += "\n" + describe(submenu, indent: indent + 1)
            }
            return line
        }
        .joined(separator: "\n")
    }
}
