import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: render-icon.swift OUTPUT.png\n", stderr)
    exit(2)
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: false) { rect in
    let outer = NSBezierPath(
        roundedRect: rect.insetBy(dx: 56, dy: 56),
        xRadius: 226,
        yRadius: 226
    )
    NSGradient(colors: [
        NSColor(calibratedRed: 0.40, green: 0.34, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.28, green: 0.49, blue: 0.93, alpha: 1),
        NSColor(calibratedRed: 0.21, green: 0.73, blue: 0.92, alpha: 1)
    ])?.draw(in: outer, angle: -46)

    NSColor.white.withAlphaComponent(0.09).setFill()
    NSBezierPath(ovalIn: NSRect(x: 610, y: 610, width: 500, height: 500)).fill()
    NSColor(calibratedRed: 0.14, green: 0.23, blue: 0.78, alpha: 0.12).setFill()
    NSBezierPath(ovalIn: NSRect(x: -120, y: -40, width: 650, height: 650)).fill()

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedRed: 0.12, green: 0.17, blue: 0.38, alpha: 0.34)
    shadow.shadowBlurRadius = 44
    shadow.shadowOffset = NSSize(width: 0, height: -30)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    let sheetRect = NSRect(x: 258, y: 184, width: 528, height: 656)
    NSColor(calibratedRed: 0.98, green: 0.985, blue: 1, alpha: 1).setFill()
    NSBezierPath(roundedRect: sheetRect, xRadius: 52, yRadius: 52).fill()
    NSGraphicsContext.restoreGraphicsState()

    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: 643, y: 840))
    fold.line(to: NSPoint(x: 786, y: 697))
    fold.line(to: NSPoint(x: 695, y: 697))
    fold.curve(
        to: NSPoint(x: 643, y: 749),
        controlPoint1: NSPoint(x: 666, y: 697),
        controlPoint2: NSPoint(x: 643, y: 720)
    )
    fold.close()
    NSColor(calibratedRed: 0.84, green: 0.86, blue: 0.95, alpha: 1).setFill()
    fold.fill()

    let mark = NSBezierPath()
    mark.move(to: NSPoint(x: 348, y: 635))
    mark.line(to: NSPoint(x: 348, y: 438))
    mark.line(to: NSPoint(x: 421, y: 438))
    mark.line(to: NSPoint(x: 512, y: 542))
    mark.line(to: NSPoint(x: 603, y: 438))
    mark.line(to: NSPoint(x: 676, y: 438))
    mark.line(to: NSPoint(x: 676, y: 635))
    mark.line(to: NSPoint(x: 597, y: 635))
    mark.line(to: NSPoint(x: 597, y: 530))
    mark.line(to: NSPoint(x: 512, y: 620))
    mark.line(to: NSPoint(x: 427, y: 530))
    mark.line(to: NSPoint(x: 427, y: 635))
    mark.close()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.40, green: 0.34, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.24, green: 0.61, blue: 0.93, alpha: 1)
    ])?.draw(in: mark, angle: -25)

    NSColor(calibratedRed: 0.73, green: 0.76, blue: 0.88, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 348, y: 305, width: 328, height: 22), xRadius: 11, yRadius: 11).fill()
    NSColor(calibratedRed: 0.83, green: 0.85, blue: 0.92, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 348, y: 253, width: 218, height: 22), xRadius: 11, yRadius: 11).fill()
    return true
}

guard let tiff = image.tiffRepresentation,
      let representation = NSBitmapImageRep(data: tiff),
      let png = representation.representation(using: .png, properties: [:])
else {
    fputs("Could not encode app icon.\n", stderr)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
} catch {
    fputs("Could not write app icon: \(error.localizedDescription)\n", stderr)
    exit(1)
}
