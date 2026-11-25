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
    // Draw into a plain bitmap context with an explicit scale: 16×16 points.
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(pixels) / 16
    ctx.scaleBy(x: scale, y: scale)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

    NSColor.black.set()
    let box = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.5, width: 13, height: 13), xRadius: 3, yRadius: 3)
    box.lineWidth = 1.2
    box.stroke()

    let font = NSFont(name: "Myanmar Sangam MN", size: 10) ?? NSFont.systemFont(ofSize: 10)
    let glyph = NSAttributedString(string: "မ", attributes: [.font: font])
    // Center using the glyph's real ink bounds (Myanmar fonts have tall line heights).
    let line = CTLineCreateWithAttributedString(glyph)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textMatrix = .identity
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.textPosition = CGPoint(x: (16 - bounds.width) / 2 - bounds.minX,
                               y: (16 - bounds.height) / 2 - bounds.minY)
    CTLineDraw(line, ctx)

    NSGraphicsContext.restoreGraphicsState()

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    rep.size = NSSize(width: 16, height: 16)   // points; pixels may be 2x
    return rep
}

// Guard against a blank icon: count visible pixels at menu-bar size.
let check = drawIcon(pixels: 32)
var inked = 0
for y in 0..<check.pixelsHigh {
    for x in 0..<check.pixelsWide where (check.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.3 {
        inked += 1
    }
}
print("icon: \(inked) of \(check.pixelsWide * check.pixelsHigh) pixels inked")
guard inked > 60 else {
    print("icon looks blank")
    exit(1)
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
    // Previews for checking the design: large, and the real 32 px menu-bar size.
    for (pixels, path) in [(256, args[2]), (32, args[2].replacingOccurrences(of: ".png", with: "-32.png"))] {
        if let png = drawIcon(pixels: pixels).representation(using: .png, properties: [:]) {
            try png.write(to: URL(fileURLWithPath: path))
            print("wrote \(path)")
        }
    }
}
