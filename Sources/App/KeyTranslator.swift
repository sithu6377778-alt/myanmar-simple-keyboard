import Carbon
import Foundation

/// Modifier combinations stored in the fallback table.
enum Mods: Hashable {
    case plain, shift, caps, option, shiftOption
}

struct Key: Hashable {
    let code: UInt16
    let mods: Mods
    init(_ code: UInt16, _ mods: Mods) {
        self.code = code
        self.mods = mods
    }
}

/// Turns a physical key press into Myanmar text using Apple's own built-in
/// "Myanmar" keyboard layout, so every key sits exactly where it does on the
/// normal Mac Myanmar keyboard (normal, Shift, Option and Caps Lock layers).
final class KeyTranslator {
    static let appleLayoutIDs = ["com.apple.keylayout.Myanmar"]

    /// The Apple layout in use, or nil when the built-in fallback table is used.
    let sourceID: String?
    private let layoutData: Data?

    init() {
        var foundID: String?
        var foundData: Data?
        for id in Self.appleLayoutIDs {
            if let data = Self.layoutData(for: id) {
                foundID = id
                foundData = data
                break
            }
        }
        sourceID = foundID
        layoutData = foundData
        if foundData == nil {
            NSLog("MyanmarSimpleKeyboard: Apple Myanmar layout not found, using built-in table")
        }
    }

    static func layoutData(for id: String) -> Data? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        guard let unmanaged = TISCreateInputSourceList(filter, true) else { return nil }
        let sources = (unmanaged.takeRetainedValue() as NSArray) as! [TISInputSource]
        guard let source = sources.first,
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        return Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
    }

    func text(keyCode: UInt16, shift: Bool, option: Bool, capsLock: Bool) -> String? {
        if let data = layoutData {
            var state: UInt32 = 0
            if shift { state |= UInt32((shiftKey >> 8) & 0xFF) }
            if capsLock { state |= UInt32((alphaLock >> 8) & 0xFF) }
            if option { state |= UInt32((optionKey >> 8) & 0xFF) }
            let result: String? = data.withUnsafeBytes { buffer in
                guard let base = buffer.baseAddress else { return nil }
                let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
                var deadKeyState: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 16)
                let status = UCKeyTranslate(
                    layout, keyCode, UInt16(kUCKeyActionDown), state, UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState, chars.count, &length, &chars)
                guard status == noErr else { return nil }
                return String(utf16CodeUnits: chars, count: length)
            }
            return result
        }
        let mods: Mods
        switch (shift, option, capsLock) {
        case (true, true, _): mods = .shiftOption
        case (false, true, _): mods = .option
        case (true, false, _): mods = .shift
        case (false, false, true): mods = .caps
        default: mods = .plain
        }
        return FallbackLayout.table[Key(keyCode, mods)]
    }
}
