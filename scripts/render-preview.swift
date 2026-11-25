// Renders how macOS draws the text the keyboard shows while ေ is waiting,
// using the system's own text engine and Myanmar fonts.
//
//   swift scripts/render-preview.swift out.png

import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "marked-preview.png"
let circle = "\u{25CC}", e = "\u{1031}"

// (label, committed text, marked text shown by the keyboard)
let samples: [(String, String, String)] = [
    ("old: LA NYA ASAT + E", "\u{101C}\u{100A}\u{103A}", e),
    ("new: LA NYA ASAT + CIRCLE E", "\u{101C}\u{100A}\u{103A}", circle + e),
    ("after typing KHA", "\u{101C}\u{100A}\u{103A}", "\u{1001}" + e),
    ("alone: CIRCLE E", "", circle + e),
    ("stack waiting: KA + NA VIRAMA CIRCLE E", "\u{1000}", "\u{1014}\u{1039}" + circle + e),
    ("kinzi waiting: SA + NGA ASAT VIRAMA CIRCLE E", "\u{101E}", "\u{1004}\u{103A}\u{1039}" + circle + e),
]
let fonts: [(String, NSFont?)] = [
    ("System font", NSFont.systemFont(ofSize: 30)),
    ("Myanmar Sangam MN", NSFont(name: "Myanmar Sangam MN", size: 30)),
    ("Noto Sans Myanmar", NSFont(name: "NotoSansMyanmar-Regular", size: 30) ?? NSFont(name: "Noto Sans Myanmar", size: 30)),
    ("Myanmar MN", NSFont(name: "Myanmar MN", size: 30)),
]

let columnWidth: CGFloat = 330
let rowHeight: CGFloat = 70
let width = Int(CGFloat(fonts.count) * columnWidth + 20)
let height = Int(CGFloat(samples.count) * rowHeight + 60)

let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setFillColor(NSColor.white.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

let small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.gray]
for (column, (fontName, font)) in fonts.enumerated() {
    let x = 10 + CGFloat(column) * columnWidth
    NSAttributedString(string: fontName + (font == nil ? " (missing)" : ""), attributes: small)
        .draw(at: NSPoint(x: x, y: CGFloat(height) - 30))
    guard let font = font else { continue }
    for (row, (label, committed, marked)) in samples.enumerated() {
        let y = CGFloat(height) - 60 - CGFloat(row + 1) * rowHeight + 20
        NSAttributedString(string: label, attributes: small).draw(at: NSPoint(x: x, y: y + 48))
        let attributed = NSMutableAttributedString(string: committed + marked,
                                                   attributes: [.font: font, .foregroundColor: NSColor.black])
        // Underline the marked part, like apps do while ေ is waiting.
        attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue,
                                range: NSRange(location: committed.utf16.count, length: marked.utf16.count))
        attributed.draw(at: NSPoint(x: x, y: y))
    }
}
NSGraphicsContext.restoreGraphicsState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
