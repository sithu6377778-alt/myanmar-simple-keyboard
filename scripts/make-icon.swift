// Draws the menu-bar icon: "မ" inside a rounded square, black on transparent
// (a template image, so macOS tints it for light/dark menu bars).
//
//   swift scripts/make-icon.swift <out.tiff> [preview.png]

import AppKit
import CoreText

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: make-icon.swift out.tiff [preview.png]")
    exit(2)
}

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 16, height: 16)   // points; pixels may be 2x

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let scale = CGFloat(pixels) / 16
    context.cgContext.scaleBy(x: scale, y: scale)

    NSColor.black.set()
    let box = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.5, width: 13, height: 13), xRadius: 3, yRadius: 3)
    box.lineWidth = 1.2
    box.stroke()

    let font = NSFont(name: "Myanmar Sangam MN", size: 10) ?? NSFont.systemFont(ofSize: 10)
    let glyph = NSAttributedString(string: "မ", attributes: [.font: font, .foregroundColor: NSColor.black])
    // Center using the glyph's real ink bounds (Myanmar fonts have tall line heights).
    let line = CTLineCreateWithAttributedString(glyph)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let x = (16 - bounds.width) / 2 - bounds.minX
    let y = (16 - bounds.height) / 2 - bounds.minY
    context.cgContext.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, context.cgContext)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let image = NSImage(size: NSSize(width: 16, height: 16))
image.addRepresentation(drawIcon(pixels: 16))
image.addRepresentation(drawIcon(pixels: 32))
guard let tiff = image.tiffRepresentation else {
    print("could not create TIFF")
    exit(1)
}
try tiff.write(to: URL(fileURLWithPath: args[1]))
print("wrote \(args[1])")

if args.count >= 3 {
    // Large preview (black icon on white) for checking the design.
    let preview = drawIcon(pixels: 256)
    if let png = preview.representation(using: .png, properties: [:]) {
        try png.write(to: URL(fileURLWithPath: args[2]))
        print("wrote \(args[2])")
    }
}
