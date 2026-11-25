import Carbon
import Foundation

/// Registers and enables the keyboard so it shows up in the menu bar right
/// after installing (called by the installer's postinstall script).
enum Registration {
    static let bundleID = "com.linnlabs.inputmethod.MyanmarSimple"
    static let modeID = "com.linnlabs.inputmethod.MyanmarSimple.Myanmar"

    static func ourSources() -> [TISInputSource] {
        let filter = [kTISPropertyBundleID as String: bundleID] as CFDictionary
        guard let unmanaged = TISCreateInputSourceList(filter, true) else { return [] }
        return (unmanaged.takeRetainedValue() as NSArray) as! [TISInputSource]
    }

    static func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue() as? T
    }

    static func flag(_ source: TISInputSource, _ key: CFString) -> Bool {
        (property(source, key) as NSNumber?)?.boolValue ?? false
    }

    /// `--install`: register this bundle with the system and enable it.
    static func install(bundleURL: URL) -> Int32 {
        let status = TISRegisterInputSource(bundleURL as CFURL)
        print("TISRegisterInputSource(\(bundleURL.path)) = \(status)")
        var enabledSomething = false
        for source in ourSources() {
            let id: String = property(source, kTISPropertyInputSourceID) ?? "?"
            if flag(source, kTISPropertyInputSourceIsEnableCapable) && !flag(source, kTISPropertyInputSourceIsEnabled) {
                let result = TISEnableInputSource(source)
                print("enable \(id) = \(result)")
            }
            enabledSomething = enabledSomething || flag(source, kTISPropertyInputSourceIsEnabled)
        }
        return (status == noErr || enabledSomething) ? 0 : 1
    }

    /// `--status`: print what the system knows about this keyboard.
    /// Exit code 0 only if the Myanmar (Simple) mode is registered and enabled.
    static func printStatus() -> Int32 {
        var modeEnabled = false
        let sources = ourSources()
        for source in sources {
            let id: String = property(source, kTISPropertyInputSourceID) ?? "?"
            let name: String = property(source, kTISPropertyLocalizedName) ?? "?"
            let type: String = property(source, kTISPropertyInputSourceType) ?? "?"
            let enabled = flag(source, kTISPropertyInputSourceIsEnabled)
            let selectable = flag(source, kTISPropertyInputSourceIsSelectCapable)
            print("\(id)\tname=\(name)\ttype=\(type)\tenabled=\(enabled)\tselectable=\(selectable)")
            if id == modeID && enabled { modeEnabled = true }
        }
        if sources.isEmpty { print("not registered") }
        print(modeEnabled ? "STATUS: OK" : "STATUS: mode not enabled")
        return modeEnabled ? 0 : 1
    }

    /// `--select`: switch to this keyboard (used by the CI smoke test).
    static func select() -> Int32 {
        guard let mode = ourSources().first(where: { (property($0, kTISPropertyInputSourceID) as String?) == modeID }) else {
            print("mode not found")
            return 1
        }
        let status = TISSelectInputSource(mode)
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let currentID: String = property(current, kTISPropertyInputSourceID) ?? "?"
        print("TISSelectInputSource = \(status), current = \(currentID)")
        return currentID == modeID ? 0 : 1
    }
}
