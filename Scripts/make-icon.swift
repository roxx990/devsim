#!/usr/bin/env swift

//
//  make-icon.swift
//  DevSim
//
//  Renders AppIcon.icns. Run via Scripts/build-app.sh; kept as source rather than a
//  checked-in binary so the icon can be tweaked without a design tool.
//
//  Usage: swift Scripts/make-icon.swift <output.iconset-directory>
//

import AppKit

func printError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    printError("usage: make-icon.swift <output.iconset>")
    exit(1)
}

let iconsetURL = URL(fileURLWithPath: arguments[1])
try? FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

/// Draws the icon into a bitmap of the given pixel size.
func renderIcon(pixels: Int) -> Data? {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                        pixelsWide: pixels,
                                        pixelsHigh: pixels,
                                        bitsPerSample: 8,
                                        samplesPerPixel: 4,
                                        hasAlpha: true,
                                        isPlanar: false,
                                        colorSpaceName: .deviceRGB,
                                        bytesPerRow: 0,
                                        bitsPerPixel: 0)
    else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let size = CGFloat(pixels)
    let margin = size * 0.09
    let body = CGRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
    let radius = body.width * 0.2237

    // Blue-to-violet plate, the same rounded square macOS app icons use.
    let plate = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.35, green: 0.56, blue: 0.98, alpha: 1),
        NSColor(srgbRed: 0.55, green: 0.35, blue: 0.93, alpha: 1)
    ])
    gradient?.draw(in: plate, angle: -90)

    // Phone glyph, drawn rather than pulled from SF Symbols so the shape is stable
    // across macOS releases.
    let phoneHeight = body.height * 0.56
    let phoneWidth = phoneHeight * 0.52
    let phone = CGRect(x: body.midX - phoneWidth / 2,
                       y: body.midY - phoneHeight / 2,
                       width: phoneWidth,
                       height: phoneHeight)

    let stroke = max(size * 0.018, 1)
    let phonePath = NSBezierPath(roundedRect: phone,
                                 xRadius: phoneWidth * 0.18,
                                 yRadius: phoneWidth * 0.18)
    phonePath.lineWidth = stroke
    NSColor.white.setStroke()
    phonePath.stroke()

    // Speaker slot.
    let slotWidth = phoneWidth * 0.3
    let slot = NSBezierPath(roundedRect: CGRect(x: phone.midX - slotWidth / 2,
                                                y: phone.maxY - phone.height * 0.085,
                                                width: slotWidth,
                                                height: stroke * 1.2),
                            xRadius: stroke, yRadius: stroke)
    NSColor.white.setFill()
    slot.fill()

    // Folder inside the screen — the thing the app is actually for.
    let folderWidth = phoneWidth * 0.56
    let folderHeight = folderWidth * 0.78
    let folderOrigin = CGPoint(x: phone.midX - folderWidth / 2, y: phone.midY - folderHeight / 2)
    let tabWidth = folderWidth * 0.42
    let tabHeight = folderHeight * 0.16

    let folder = NSBezierPath()
    let corner = folderWidth * 0.1
    folder.move(to: CGPoint(x: folderOrigin.x, y: folderOrigin.y))
    folder.line(to: CGPoint(x: folderOrigin.x + folderWidth, y: folderOrigin.y))
    folder.line(to: CGPoint(x: folderOrigin.x + folderWidth, y: folderOrigin.y + folderHeight))
    folder.line(to: CGPoint(x: folderOrigin.x + tabWidth, y: folderOrigin.y + folderHeight))
    folder.line(to: CGPoint(x: folderOrigin.x + tabWidth - corner, y: folderOrigin.y + folderHeight + tabHeight))
    folder.line(to: CGPoint(x: folderOrigin.x, y: folderOrigin.y + folderHeight + tabHeight))
    folder.close()

    NSColor.white.setFill()
    folder.fill()

    return bitmap.representation(using: .png, properties: [:])
}

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for variant in variants {
    guard let data = renderIcon(pixels: variant.pixels) else {
        printError("failed to render \(variant.name)")
        exit(1)
    }
    let url = iconsetURL.appendingPathComponent("\(variant.name).png")
    try data.write(to: url)
}
