// EComposer — lets you type ေ (U+1031) BEFORE the consonant, like the iPhone
// Myanmar keyboard, while storing text in correct Unicode order.
//
// iPhone order:  ေ → က → ြ      (what you see, left to right)
// Unicode order: က → ြ → ေ      (what gets stored)
//
// How it works: when ေ is typed it is held back. The consonant that follows,
// any stacked consonants (္ + consonant), kinzi (င်္) and medials (ျ ြ ွ ှ)
// are collected. As soon as any other character arrives, ေ is written right
// after that cluster and typing continues normally.
//
// Pure Swift (no AppKit) so it can be unit-tested anywhere.

public enum Myanmar {
    public static let vowelE: Unicode.Scalar = "\u{1031}"   // ေ
    public static let virama: Unicode.Scalar = "\u{1039}"   // ္ (stacking)
    public static let asat: Unicode.Scalar = "\u{103A}"     // ်
    public static let nga: Unicode.Scalar = "\u{1004}"      // င

    /// Letters that can start a syllable and carry ေ.
    public static func isConsonant(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x1000...0x1022,          // က … အ, Shan A
             0x103F,                   // ဿ
             0x1050...0x1051,          // ၐ ၑ (Pali/Sanskrit)
             0x105A...0x105D,          // Mon
             0x1061, 0x1065...0x1066,  // Sgaw Karen / Western Pwo Karen
             0x106E...0x1070,          // Eastern Pwo Karen
             0x1075...0x1081,          // Shan
             0x108E:                   // Rumai Palaung
            return true
        default:
            return false
        }
    }

    /// Medial consonant signs: ျ ြ ွ ှ (plus Mon/Shan medials).
    public static func isMedial(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x103B...0x103E, 0x105E...0x1060, 0x1082:
            return true
        default:
            return false
        }
    }
}

public struct EComposer {
    /// What the text field should do after one input.
    public struct Result: Equatable {
        /// Text to insert permanently (replaces any marked text).
        public var commit: String
        /// Text to show as temporary, underlined "marked text" (empty = none).
        public var marked: String

        public init(commit: String = "", marked: String = "") {
            self.commit = commit
            self.marked = marked
        }
    }

    private var active = false            // ေ is waiting
    private var prefix: [Unicode.Scalar] = []  // kinzi (င ် ္) typed while ေ was waiting
    private var head: [Unicode.Scalar] = []    // consonant, stacks, medials
    private var pendingAsat = false       // head == [င] and ် arrived: maybe kinzi

    public init() {}

    /// True while ေ is being held back.
    public var isComposing: Bool { active }

    /// What to show while composing: the cluster with ေ already in place.
    public var markedText: String {
        guard active else { return "" }
        var scalars = prefix + head
        if pendingAsat { scalars.append(Myanmar.asat) }
        scalars.append(Myanmar.vowelE)
        return Self.string(scalars)
    }

    /// Feed the text produced by one key press (usually one character).
    public mutating func input(_ text: String) -> Result {
        var commit = ""
        for scalar in text.unicodeScalars {
            commit += feed(scalar)
        }
        return Result(commit: commit, marked: markedText)
    }

    /// Backspace. Returns nil when nothing is being composed, meaning the key
    /// should go to the app as a normal delete.
    public mutating func backspace() -> Result? {
        guard active else { return nil }
        if pendingAsat {
            pendingAsat = false
        } else if !head.isEmpty {
            head.removeLast()
        } else if !prefix.isEmpty {
            prefix.removeAll()
        } else {
            reset()   // cancel the waiting ေ
        }
        return Result(commit: "", marked: markedText)
    }

    /// Finish composing (focus change, Return, arrows, switching keyboards…).
    public mutating func commitAll() -> String {
        guard active else { return "" }
        var scalars = prefix + head
        scalars.append(Myanmar.vowelE)
        if pendingAsat { scalars.append(Myanmar.asat) }
        reset()
        return Self.string(scalars)
    }

    // MARK: - Core rules

    private mutating func feed(_ c: Unicode.Scalar) -> String {
        guard active else {
            if c == Myanmar.vowelE {
                active = true
                return ""
            }
            return String(Character(c))
        }

        if pendingAsat {
            pendingAsat = false
            if c == Myanmar.virama {
                // င ် ္ = kinzi. It sits before the next consonant; ေ keeps waiting.
                prefix += head + [Myanmar.asat, Myanmar.virama]
                head.removeAll()
                return ""
            }
            // Not kinzi after all.
            let out = Self.string(prefix + head + [Myanmar.vowelE, Myanmar.asat])
            reset()
            return out + feed(c)
        }

        if c == Myanmar.vowelE {
            // A new ေ: finish the current one and start waiting again.
            let out = Self.string(prefix + head + [Myanmar.vowelE])
            reset()
            active = true
            return out
        }

        if Myanmar.isConsonant(c) {
            if head.isEmpty || head.last == Myanmar.virama {
                head.append(c)          // main consonant, or stacked consonant
                return ""
            }
            return flush(then: c)       // a new syllable starts
        }

        if c == Myanmar.virama {
            if let last = head.last, Myanmar.isConsonant(last) {
                head.append(c)          // stacking: wait for the lower consonant
                return ""
            }
            return flush(then: c)
        }

        if c == Myanmar.asat, head == [Myanmar.nga] {
            pendingAsat = true          // might become kinzi (င်္)
            return ""
        }

        if Myanmar.isMedial(c) {
            if let last = head.last, last != Myanmar.virama {
                head.append(c)          // ျ ြ ွ ှ belong before ေ
                return ""
            }
            return flush(then: c)
        }

        // Vowel signs, tones, asat, space, punctuation, digits…: ေ goes here.
        return flush(then: c)
    }

    private mutating func flush(then c: Unicode.Scalar) -> String {
        let out = Self.string(prefix + head + [Myanmar.vowelE])
        reset()
        return out + feed(c)
    }

    private mutating func reset() {
        active = false
        prefix.removeAll()
        head.removeAll()
        pendingAsat = false
    }

    private static func string(_ scalars: [Unicode.Scalar]) -> String {
        var s = ""
        s.unicodeScalars.append(contentsOf: scalars)
        return s
    }
}
