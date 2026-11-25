import Foundation

/// `--self-test`: checks the real key translation (Apple's Myanmar layout) and
/// the composer together, the way they run inside the keyboard.
enum SelfTest {
    static func run() -> Int32 {
        var failures = 0
        let translator = KeyTranslator()
        print("Apple layout: \(translator.sourceID ?? "NOT FOUND - using built-in table")")
        if translator.sourceID == nil { failures += 1 }

        // Spot checks against the user's Keyboard Viewer screenshots.
        let spots: [(UInt16, Bool, String, String)] = [
            (0, false, "\u{1031}", "a → ေ"),
            (1, false, "\u{103B}", "s → ျ"),
            (38, false, "\u{103C}", "j → ြ"),
            (32, false, "\u{1000}", "u → က"),
            (46, false, "\u{102C}", "m → ာ"),
            (41, false, "\u{1038}", "; → း"),
            (3, true, "\u{1039}", "Shift+f → ္"),
            (5, true, "\u{103D}", "Shift+g → ွ"),
        ]
        for (code, shift, expected, label) in spots {
            let got = translator.text(keyCode: code, shift: shift, option: false, capsLock: false) ?? ""
            let ok = got == expected
            if !ok { failures += 1 }
            print("\(ok ? "ok  " : "FAIL") \(label)  got \(hex(got))")
        }

        // Compare Apple's layout with the built-in fallback table.
        if translator.sourceID != nil && !FallbackLayout.table.isEmpty {
            var differences = 0
            for (key, value) in FallbackLayout.table {
                let got = translator.text(
                    keyCode: key.code,
                    shift: key.mods == .shift || key.mods == .shiftOption,
                    option: key.mods == .option || key.mods == .shiftOption,
                    capsLock: key.mods == .caps) ?? ""
                if got != value {
                    differences += 1
                    print("note: key \(key.code) \(key.mods): Apple=\(hex(got)) table=\(hex(value))")
                }
            }
            print("fallback table differences: \(differences) of \(FallbackLayout.table.count)")
        }

        // Type "နေကောင်းလား" the iPhone way with real key codes:
        // a(ေ) e(န) a(ေ) u(က) m(ာ) i(င) f(်) ;(း) v(လ) m(ာ) ;(း)
        let keyCodes: [UInt16] = [0, 14, 0, 32, 46, 34, 3, 41, 9, 46, 41]
        var composer = EComposer()
        var document = ""
        for code in keyCodes {
            let typed = translator.text(keyCode: code, shift: false, option: false, capsLock: false) ?? ""
            document += composer.input(typed).commit
        }
        document += composer.commitAll()
        let expectedCodes: [UInt32] = [
            0x1014, 0x1031, 0x1000, 0x1031, 0x102C, 0x1004, 0x103A, 0x1038, 0x101C, 0x102C, 0x1038,
        ]
        var expected = ""
        expected.unicodeScalars.append(contentsOf: expectedCodes.map { Unicode.Scalar($0)! })
        let sentenceOK = document == expected
        if !sentenceOK { failures += 1 }
        print("\(sentenceOK ? "ok  " : "FAIL") typed နေကောင်းလား → \(document)  [\(hex(document))]")

        print(failures == 0 ? "SELF-TEST PASSED" : "SELF-TEST FAILED (\(failures))")
        return failures == 0 ? 0 : 1
    }

    static func hex(_ s: String) -> String {
        s.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
    }
}
