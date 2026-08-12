import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: render-dmg-background.swift OUTPUT.png OUTPUT@2x.png\n", stderr)
    exit(2)
}

let canvasSize = NSSize(width: 800, height: 540)

func drawText(
    _ string: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .center
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    string.draw(
        in: rect,
        withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
    )
}

func drawBackground() {
    let bounds = NSRect(origin: .zero, size: canvasSize)
    let background = NSBezierPath(rect: bounds)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.975, green: 0.977, blue: 0.992, alpha: 1),
        NSColor(calibratedRed: 0.944, green: 0.958, blue: 0.992, alpha: 1),
    ])?.draw(in: background, angle: -90)

    NSColor(calibratedRed: 0.38, green: 0.33, blue: 0.94, alpha: 0.07).setFill()
    NSBezierPath(ovalIn: NSRect(x: 540, y: 325, width: 350, height: 280)).fill()
    NSColor(calibratedRed: 0.18, green: 0.66, blue: 0.91, alpha: 0.06).setFill()
    NSBezierPath(ovalIn: NSRect(x: -120, y: -95, width: 390, height: 290)).fill()

    drawText(
        "Install ReaderMD",
        in: NSRect(x: 100, y: 465, width: 600, height: 42),
        font: .systemFont(ofSize: 30, weight: .semibold),
        color: NSColor(calibratedWhite: 0.12, alpha: 1)
    )
    drawText(
        "Drag ReaderMD to Applications",
        in: NSRect(x: 100, y: 427, width: 600, height: 25),
        font: .systemFont(ofSize: 16, weight: .regular),
        color: NSColor(calibratedWhite: 0.35, alpha: 1)
    )

    let cardColor = NSColor.white.withAlphaComponent(0.72)
    let borderColor = NSColor(calibratedRed: 0.52, green: 0.55, blue: 0.74, alpha: 0.14)
    for x in [65.0, 425.0] {
        let card = NSBezierPath(
            roundedRect: NSRect(x: x, y: 135, width: 310, height: 250),
            xRadius: 34,
            yRadius: 34
        )
        cardColor.setFill()
        card.fill()
        borderColor.setStroke()
        card.lineWidth = 1
        card.stroke()
    }

    NSColor(calibratedRed: 0.38, green: 0.35, blue: 0.93, alpha: 0.08).setFill()
    NSBezierPath(ovalIn: NSRect(x: 105, y: 155, width: 230, height: 230)).fill()

    let ring = NSBezierPath(ovalIn: NSRect(x: 477, y: 167, width: 206, height: 206))
    let dashPattern: [CGFloat] = [7, 8]
    ring.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
    ring.lineWidth = 2
    NSColor(calibratedRed: 0.36, green: 0.34, blue: 0.88, alpha: 0.22).setStroke()
    ring.stroke()

    drawText(
        "DRAG TO INSTALL",
        in: NSRect(x: 315, y: 322, width: 170, height: 18),
        font: .systemFont(ofSize: 11, weight: .semibold),
        color: NSColor(calibratedRed: 0.36, green: 0.34, blue: 0.82, alpha: 0.82)
    )

    let arrowColor = NSColor(calibratedRed: 0.36, green: 0.34, blue: 0.88, alpha: 0.94)
    let arrow = NSBezierPath()
    arrow.lineWidth = 9
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 323, y: 270))
    arrow.curve(
        to: NSPoint(x: 472, y: 270),
        controlPoint1: NSPoint(x: 360, y: 299),
        controlPoint2: NSPoint(x: 429, y: 299)
    )
    NSColor(calibratedRed: 0.36, green: 0.34, blue: 0.88, alpha: 0.13).setStroke()
    let glow = arrow.copy() as! NSBezierPath
    glow.lineWidth = 19
    glow.stroke()
    arrowColor.setStroke()
    arrow.stroke()

    let arrowHead = NSBezierPath()
    arrowHead.move(to: NSPoint(x: 455, y: 293))
    arrowHead.line(to: NSPoint(x: 493, y: 268))
    arrowHead.line(to: NSPoint(x: 455, y: 247))
    arrowHead.close()
    arrowColor.setFill()
    arrowHead.fill()

    drawText(
        "After copying, open ReaderMD once to finish setup.",
        in: NSRect(x: 100, y: 83, width: 600, height: 25),
        font: .systemFont(ofSize: 14, weight: .medium),
        color: NSColor(calibratedWhite: 0.30, alpha: 1)
    )
    drawText(
        "macOS 14 or newer  ·  Apple Silicon and Intel",
        in: NSRect(x: 100, y: 55, width: 600, height: 20),
        font: .monospacedSystemFont(ofSize: 11, weight: .regular),
        color: NSColor(calibratedWhite: 0.48, alpha: 1)
    )
}

func writePNG(to outputPath: String, scale: CGFloat) throws {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width * scale),
        pixelsHigh: Int(canvasSize.height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: representation) else {
        throw CocoaError(.fileWriteUnknown)
    }

    representation.size = canvasSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: scale, y: scale)
    drawBackground()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
}

do {
    try writePNG(to: CommandLine.arguments[1], scale: 1)
    try writePNG(to: CommandLine.arguments[2], scale: 2)
} catch {
    fputs("Could not render DMG background: \(error.localizedDescription)\n", stderr)
    exit(1)
}
