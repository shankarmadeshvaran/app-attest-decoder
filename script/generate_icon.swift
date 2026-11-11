// Regenerate the original vector-drawn app icon: swift script/generate_icon.swift <output.iconset>
import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let factor = CGFloat(pixels) / 1024
        let transform = AffineTransform(scale: factor)
        (transform as NSAffineTransform).concat()
        let background = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 192, yRadius: 192)
        NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.26, blue: 0.68, alpha: 1),
                   ending: NSColor(srgbRed: 0.08, green: 0.10, blue: 0.27, alpha: 1))!.draw(in: background, angle: -75)
        let shield = NSBezierPath()
        shield.move(to: NSPoint(x: 512, y: 800))
        shield.curve(to: NSPoint(x: 760, y: 700), controlPoint1: NSPoint(x: 610, y: 740), controlPoint2: NSPoint(x: 690, y: 720))
        shield.line(to: NSPoint(x: 748, y: 495))
        shield.curve(to: NSPoint(x: 512, y: 238), controlPoint1: NSPoint(x: 742, y: 375), controlPoint2: NSPoint(x: 610, y: 278))
        shield.curve(to: NSPoint(x: 276, y: 495), controlPoint1: NSPoint(x: 414, y: 278), controlPoint2: NSPoint(x: 282, y: 375))
        shield.line(to: NSPoint(x: 264, y: 700))
        shield.curve(to: NSPoint(x: 512, y: 800), controlPoint1: NSPoint(x: 334, y: 720), controlPoint2: NSPoint(x: 414, y: 740))
        NSColor.white.withAlphaComponent(0.92).setStroke()
        shield.lineWidth = 36
        shield.lineJoinStyle = .round
        shield.stroke()
        let check = NSBezierPath()
        check.move(to: NSPoint(x: 389, y: 529))
        check.line(to: NSPoint(x: 478, y: 443))
        check.line(to: NSPoint(x: 645, y: 617))
        check.lineWidth = 52
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        NSColor(srgbRed: 0.41, green: 0.94, blue: 0.77, alpha: 1).setStroke()
        check.stroke()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not render icon") }
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try png.write(to: directory.appendingPathComponent(name))
    }
}
