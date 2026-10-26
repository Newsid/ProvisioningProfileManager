#!/usr/bin/env swift
// Renders the app icon and writes the AppIcon asset catalog.
// Usage: swift scripts/make_icon.swift <path to AppIcon.appiconset>

import AppKit

let canvas: CGFloat = 1024

func renderMaster() -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: 824pt rounded square centred on a 1024 canvas.
    let shapeRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: shapeRect, xRadius: 185, yRadius: 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    NSColor.black.setFill()
    shape.fill()
    ctx.restoreGState()

    ctx.saveGState()
    shape.addClip()
    NSGradient(colors: [
        NSColor(srgbRed: 0.22, green: 0.56, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.31, green: 0.22, blue: 0.82, alpha: 1),
    ])!.draw(in: shapeRect, angle: -90)

    // Stacked profile cards.
    let card = CGRect(x: 272, y: 250, width: 420, height: 530)
    let center = CGPoint(x: card.midX, y: card.midY)
    for (angle, alpha) in [(CGFloat(11), 0.30), (CGFloat(5.5), 0.55)] {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: angle * .pi / 180)
        ctx.translateBy(x: -center.x, y: -center.y)
        NSColor.white.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: card, xRadius: 44, yRadius: 44).fill()
        ctx.restoreGState()
    }

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: card, xRadius: 44, yRadius: 44).fill()
    ctx.restoreGState()

    // Card header: type icon + title/subtitle bars.
    let typeIcon = CGRect(x: card.minX + 44, y: card.maxY - 44 - 96, width: 96, height: 96)
    NSGradient(colors: [
        NSColor(srgbRed: 0.25, green: 0.60, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.12, green: 0.42, blue: 0.95, alpha: 1),
    ])!.draw(in: NSBezierPath(roundedRect: typeIcon, xRadius: 24, yRadius: 24), angle: -90)
    drawSymbol("hammer.fill", in: typeIcon.insetBy(dx: 22, dy: 22), color: .white)

    func bar(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, gray: CGFloat) {
        NSColor(white: gray, alpha: 1).setFill()
        NSBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: height),
                     xRadius: height / 2, yRadius: height / 2).fill()
    }
    bar(x: typeIcon.maxX + 30, y: typeIcon.maxY - 38, width: 200, height: 30, gray: 0.25)
    bar(x: typeIcon.maxX + 30, y: typeIcon.minY + 14, width: 150, height: 22, gray: 0.72)

    // Detail rows.
    var y = typeIcon.minY - 76
    for width in [CGFloat(300), 240, 270, 180] {
        bar(x: card.minX + 44, y: y, width: width, height: 20, gray: 0.84)
        y -= 52
    }

    // Validity badge.
    let badgeCenter = CGPoint(x: card.maxX - 6, y: card.minY + 46)
    let badge = CGRect(x: badgeCenter.x - 128, y: badgeCenter.y - 128, width: 256, height: 256)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: badge).fill()
    ctx.restoreGState()
    NSGradient(colors: [
        NSColor(srgbRed: 0.30, green: 0.85, blue: 0.45, alpha: 1),
        NSColor(srgbRed: 0.10, green: 0.65, blue: 0.30, alpha: 1),
    ])!.draw(in: NSBezierPath(ovalIn: badge.insetBy(dx: 14, dy: 14)), angle: -90)
    drawSymbol("checkmark", in: badge.insetBy(dx: 66, dy: 66), color: .white, weight: .black)

    ctx.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func drawSymbol(_ name: String, in rect: CGRect, color: NSColor, weight: NSFont.Weight = .bold) {
    let config = NSImage.SymbolConfiguration(pointSize: rect.height, weight: weight)
        .applying(.init(paletteColors: [color]))
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return }
    // Fit while preserving the symbol's aspect ratio.
    let scale = min(rect.width / image.size.width, rect.height / image.size.height)
    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                          width: size.width, height: size.height))
}

func resized(_ master: NSBitmapImageRep, to pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    master.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let master = renderMaster()
var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let file = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try resized(master, to: points * scale).write(to: output.appending(path: file))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": file])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appending(path: "Contents.json"))
print("Wrote \(images.count) icons to \(output.path)")
