// Layout inspection tool (runs on macOS only).
//
//   swift Tools/layout-tool.swift list
//       Lists every installed input source that looks Myanmar-related.
//
//   swift Tools/layout-tool.swift dump <InputSourceID> [outputDir]
//       Prints the full key table of a keyboard layout (normal, Shift, Caps Lock,
//       Option, Shift+Option) using Apple's own layout data, and writes
//       layout.tsv + FallbackLayout.swift to outputDir (default: build/layout).

import Carbon
import Foundation

func prop<T>(_ source: TISInputSource, _ key: CFString) -> T? {
    guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue() as? T
}

func installedSources() -> [TISInputSource] {
    guard let list = TISCreateInputSourceList(nil, true)?.takeRetainedValue() else { return [] }
    return (list as NSArray) as! [TISInputSource]
}

func describe(_ s: String) -> String {
    s.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
}

// Physical key order (ANSI) so the output can be compared with Keyboard Viewer.
let rows: [(String, [UInt16])] = [
    ("row1 ` 1..0 - =", [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24]),
    ("row2 q..p [ ] \\", [12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 42]),
    ("row3 a..l ; '", [0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39]),
    ("row4 z..m , . /", [6, 7, 8, 9, 11, 45, 46, 43, 47, 44]),
]

// Carbon modifier state passed to UCKeyTranslate is (modifiers >> 8) & 0xFF.
let modifierSets: [(String, UInt32)] = [
    ("none", 0),
    ("shift", UInt32((shiftKey >> 8) & 0xFF)),
    ("caps", UInt32((alphaLock >> 8) & 0xFF)),
    ("option", UInt32((optionKey >> 8) & 0xFF)),
    ("shift+option", UInt32(((shiftKey | optionKey) >> 8) & 0xFF)),
]

func translate(_ layout: UnsafePointer<UCKeyboardLayout>, _ keyCode: UInt16, _ mods: UInt32) -> String {
    var deadKeyState: UInt32 = 0
    var length = 0
    var chars = [UniChar](repeating: 0, count: 16)
    let status = UCKeyTranslate(
        layout, keyCode, UInt16(kUCKeyActionDown), mods, UInt32(LMGetKbdType()),
        OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, chars.count, &length, &chars)
    guard status == noErr else { return "" }
    return String(utf16CodeUnits: chars, count: length)
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: layout-tool.swift list | dump <InputSourceID> [outputDir]")
    exit(2)
}

switch args[1] {
case "list":
    var found = 0
    for source in installedSources() {
        let id: String = prop(source, kTISPropertyInputSourceID) ?? "?"
        let langs: [String] = prop(source, kTISPropertyInputSourceLanguages) ?? []
        guard id.localizedCaseInsensitiveContains("myanmar") || id.localizedCaseInsensitiveContains("burmese")
            || langs.contains("my") else { continue }
        found += 1
        let type: String = prop(source, kTISPropertyInputSourceType) ?? "?"
        let name: String = prop(source, kTISPropertyLocalizedName) ?? "?"
        let enabled: Bool = (prop(source, kTISPropertyInputSourceIsEnabled) as NSNumber?)?.boolValue ?? false
        let hasLayout = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) != nil
        print("\(id)\ttype=\(type)\tname=\(name)\tlangs=\(langs)\tenabled=\(enabled)\tlayoutData=\(hasLayout)")
    }
    print("found \(found) Myanmar-related input source(s)")

case "dump":
    guard args.count >= 3 else { print("missing InputSourceID"); exit(2) }
    let wanted = args[2]
    let outDir = args.count >= 4 ? args[3] : "build/layout"
    guard let source = installedSources().first(where: { (prop($0, kTISPropertyInputSourceID) as String?) == wanted }) else {
        print("input source not found: \(wanted)")
        exit(1)
    }
    guard let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
        print("no layout data for \(wanted)")
        exit(1)
    }
    let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
    var tsv = "keyCode\tmodifiers\tcodepoints\ttext\n"
    var swiftEntries: [String] = []
    data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
        let layout = buffer.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self)
        for (label, keys) in rows {
            print("== \(label)")
            for (modName, mods) in modifierSets {
                let cells = keys.map { key -> String in
                    let t = translate(layout, key, mods)
                    return t.isEmpty ? "·" : t
                }
                print("  \(modName.padding(toLength: 13, withPad: " ", startingAt: 0)) \(cells.joined(separator: "  "))")
            }
        }
        for key in UInt16(0)..<UInt16(128) {
            for (modName, mods) in modifierSets {
                let t = translate(layout, key, mods)
                guard !t.isEmpty else { continue }
                tsv += "\(key)\t\(modName)\t\(describe(t))\t\(t)\n"
                let escaped = t.unicodeScalars.map { String(format: "\\u{%04X}", $0.value) }.joined()
                swiftEntries.append("        Key(\(key), .\(modName == "shift+option" ? "shiftOption" : modName)): \"\(escaped)\",")
            }
        }
    }
    try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    try tsv.write(toFile: outDir + "/layout.tsv", atomically: true, encoding: .utf8)
    let swiftSource = """
    // Generated by Tools/layout-tool.swift from \(wanted) on a macOS runner.
    // Used only when Apple's own Myanmar layout data cannot be loaded at runtime.
    enum FallbackLayout {
        static let table: [Key: String] = [
    \(swiftEntries.joined(separator: "\n"))
        ]
    }
    """
    try swiftSource.write(toFile: outDir + "/FallbackLayout.swift", atomically: true, encoding: .utf8)
    print("\nTSV:\n" + tsv)
    print("wrote \(outDir)/layout.tsv and \(outDir)/FallbackLayout.swift (\(swiftEntries.count) entries)")

default:
    print("unknown command \(args[1])")
    exit(2)
}
