//
//  main.swift
//  DevSim
//
//  A menu bar app: no Dock icon, no main window, no nib.
//

import AppKit

let application = NSApplication.shared

// `--dump-menu` prints the menu that would be shown and exits. Handy for checking
// simulator discovery from a terminal without clicking through the menu bar.
if CommandLine.arguments.contains("--dump-menu") {
    let menu = NSMenu()
    MenuBuilder.rebuild(menu)
    print(MenuDump.describe(menu))
    exit(0)
}

let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
