// Unit tests for EComposer. Build & run:  scripts/test.sh
//
// Every test types keys in iPhone order (ေ first) and checks that the text
// stored in the document is in correct Unicode order. Characters are written
// as named code points so the expected order is unambiguous.

// Consonants
let KA: UInt32 = 0x1000, KHA: UInt32 = 0x1001, GA: UInt32 = 0x1002, NGA: UInt32 = 0x1004
let CA: UInt32 = 0x1005, CHA: UInt32 = 0x1006, JA: UInt32 = 0x1007, NYA: UInt32 = 0x100A
let TA: UInt32 = 0x1010, THA: UInt32 = 0x1011, DA: UInt32 = 0x1012, NA: UInt32 = 0x1014
let PA: UInt32 = 0x1015, PHA: UInt32 = 0x1016, BA: UInt32 = 0x1017, BHA: UInt32 = 0x1018
let MA: UInt32 = 0x1019, YA: UInt32 = 0x101A, RA: UInt32 = 0x101B, LA: UInt32 = 0x101C
let WA: UInt32 = 0x101D, SA: UInt32 = 0x101E, A: UInt32 = 0x1021
// Signs
let TALL_AA: UInt32 = 0x102B, AA: UInt32 = 0x102C, I: UInt32 = 0x102D, II: UInt32 = 0x102E
let U: UInt32 = 0x102F, UU: UInt32 = 0x1030, E: UInt32 = 0x1031, ANUSVARA: UInt32 = 0x1036
let DOT: UInt32 = 0x1037, VISARGA: UInt32 = 0x1038, VIRAMA: UInt32 = 0x1039, ASAT: UInt32 = 0x103A
let Y_M: UInt32 = 0x103B, R_M: UInt32 = 0x103C, W_M: UInt32 = 0x103D, H_M: UInt32 = 0x103E
let ONE: UInt32 = 0x1041, SPACE: UInt32 = 0x20

enum Ev {
    case key(UInt32)       // one key producing one character
    case chunk([UInt32])   // one key producing several characters
    case backspace
    case focusLost         // e.g. clicking elsewhere
}

func keys(_ values: UInt32...) -> [Ev] { values.map { .key($0) } }

func text(_ values: [UInt32]) -> String {
    var s = ""
    s.unicodeScalars.append(contentsOf: values.map { Unicode.Scalar($0)! })
    return s
}

func hex(_ s: String) -> String {
    s.unicodeScalars.map { String($0.value, radix: 16, uppercase: true) }.joined(separator: " ")
}

/// Simulates a text field: committed text + whatever the composer is holding.
func type(_ events: [Ev]) -> (document: String, marked: String) {
    var composer = EComposer()
    var doc = ""
    var marked = ""
    for ev in events {
        switch ev {
        case .key(let v):
            let r = composer.input(text([v]))
            doc += r.commit
            marked = r.marked
        case .chunk(let vs):
            let r = composer.input(text(vs))
            doc += r.commit
            marked = r.marked
        case .backspace:
            if let r = composer.backspace() {
                marked = r.marked
            } else if !doc.isEmpty {
                doc.unicodeScalars.removeLast()   // the app deletes one character
            }
        case .focusLost:
            doc += composer.commitAll()
            marked = ""
        }
    }
    return (doc, marked)
}

var passed = 0
var failed = 0

/// Types `events`, then loses focus, and compares the final document.
func check(_ name: String, _ events: [Ev], _ expected: [UInt32]) {
    let result = type(events + [.focusLost]).document
    let want = text(expected)
    if result == want {
        passed += 1
        print("  ok   \(name)")
    } else {
        failed += 1
        print("  FAIL \(name)\n       got:  \(result)  [\(hex(result))]\n       want: \(want)  [\(hex(want))]")
    }
}

func checkMarked(_ name: String, _ events: [Ev], _ expected: [UInt32]) {
    let result = type(events).marked
    let want = text(expected)
    if result == want {
        passed += 1
        print("  ok   \(name)")
    } else {
        failed += 1
        print("  FAIL \(name)\n       got:  [\(hex(result))]\n       want: [\(hex(want))]")
    }
}

print("EComposer tests")

// Words the user checked on their own Mac (Mac order = expected Unicode order).
check("နေ", keys(E, NA), [NA, E])
check("တောင်း", keys(E, TA, AA, NGA, ASAT, VISARGA), [TA, E, AA, NGA, ASAT, VISARGA])
check("ကြေ", keys(E, KA, R_M), [KA, R_M, E])
check("ကျွေး", keys(E, KA, Y_M, W_M, VISARGA), [KA, Y_M, W_M, E, VISARGA])
check("ငွေ", keys(E, NGA, W_M), [NGA, W_M, E])
check("နှေး", keys(E, NA, H_M, VISARGA), [NA, H_M, E, VISARGA])
check("ပြော", keys(E, PA, R_M, AA), [PA, R_M, E, AA])

// More common words
check("ကြော့", keys(E, KA, R_M, AA, DOT), [KA, R_M, E, AA, DOT])
check("ကျော်", keys(E, KA, Y_M, AA, ASAT), [KA, Y_M, E, AA, ASAT])
check("မွေး", keys(E, MA, W_M, VISARGA), [MA, W_M, E, VISARGA])
check("မြွေ", keys(E, MA, R_M, W_M), [MA, R_M, W_M, E])
check("ချော", keys(E, KHA, Y_M, AA), [KHA, Y_M, E, AA])
check("လှေ", keys(E, LA, H_M), [LA, H_M, E])
check("သွေး", keys(E, SA, W_M, VISARGA), [SA, W_M, E, VISARGA])
check("ကြွေ", keys(E, KA, R_M, W_M), [KA, R_M, W_M, E])
check("ရေ", keys(E, RA), [RA, E])
check("ဝေ", keys(E, WA), [WA, E])
check("အေး", keys(E, A, VISARGA), [A, E, VISARGA])
check("ဗေဒ", keys(E, BA, DA), [BA, E, DA])
check("ပေါ်", keys(E, PA, TALL_AA, ASAT), [PA, E, TALL_AA, ASAT])
check("ဆေးရုံ", keys(E, CHA, VISARGA, RA, U, ANUSVARA), [CHA, E, VISARGA, RA, U, ANUSVARA])
check("ကော်ဖီ", keys(E, KA, AA, ASAT, PHA, II), [KA, E, AA, ASAT, PHA, II])
check("မေမေ", keys(E, MA, E, MA), [MA, E, MA, E])

// Sentences
check("နေကောင်းလား",
      keys(E, NA, E, KA, AA, NGA, ASAT, VISARGA, LA, AA, VISARGA),
      [NA, E, KA, E, AA, NGA, ASAT, VISARGA, LA, AA, VISARGA])
check("ကျေးဇူးတင်ပါတယ်",
      keys(E, KA, Y_M, VISARGA, JA, UU, VISARGA, TA, NGA, ASAT, PA, TALL_AA, TA, YA, ASAT),
      [KA, Y_M, E, VISARGA, JA, UU, VISARGA, TA, NGA, ASAT, PA, TALL_AA, TA, YA, ASAT])
check("ပြည်ထောင်စု",
      keys(PA, R_M, NYA, ASAT, E, THA, AA, NGA, ASAT, CA, U),
      [PA, R_M, NYA, ASAT, THA, E, AA, NGA, ASAT, CA, U])
check("ငှက်ပျော",
      keys(NGA, H_M, KA, ASAT, E, PA, Y_M, AA),
      [NGA, H_M, KA, ASAT, PA, Y_M, E, AA])

// Stacked consonants (္) and kinzi (င်္)
check("မေတ္တာ (ေ on the first consonant)",
      keys(E, MA, TA, VIRAMA, TA, AA),
      [MA, E, TA, VIRAMA, TA, AA])
check("ကန္တော့ (ေ after the stack)",
      keys(KA, E, NA, VIRAMA, TA, AA, DOT),
      [KA, NA, VIRAMA, TA, E, AA, DOT])
check("သင်္ဘော (ေ typed before kinzi)",
      keys(SA, E, NGA, ASAT, VIRAMA, BHA, AA),
      [SA, NGA, ASAT, VIRAMA, BHA, E, AA])
check("သင်္ဘော (kinzi typed before ေ)",
      keys(SA, NGA, ASAT, VIRAMA, E, BHA, AA),
      [SA, NGA, ASAT, VIRAMA, BHA, E, AA])
check("သင်္ဘော (kinzi from one key)",
      [.key(SA), .key(E), .chunk([NGA, ASAT, VIRAMA]), .key(BHA), .key(AA)],
      [SA, NGA, ASAT, VIRAMA, BHA, E, AA])
check("မင်္ဂလာပါ (no ေ, unchanged)",
      keys(MA, NGA, ASAT, VIRAMA, GA, LA, AA, PA, TALL_AA),
      [MA, NGA, ASAT, VIRAMA, GA, LA, AA, PA, TALL_AA])
check("ကြည့် (no ေ, unchanged)", keys(KA, R_M, NYA, DOT, ASAT), [KA, R_M, NYA, DOT, ASAT])

// Editing behaviour
check("ေ + space", keys(E, SPACE), [E, SPACE])
check("ေ + digit", keys(E, ONE), [E, ONE])
check("ေ ေ က", keys(E, E, KA), [E, KA, E])
check("ေ then backspace cancels it", [.key(E), .backspace], [])
check("ေ က backspace မ", [.key(E), .key(KA), .backspace, .key(MA)], [MA, E])
check("ေ က ြ backspace backspace backspace", [.key(E), .key(KA), .key(R_M), .backspace, .backspace, .backspace], [])
check("backspace after commit goes to the app", [.key(E), .key(NA), .key(AA), .backspace], [NA, E])
check("focus lost mid-word", [.key(E), .key(KA), .key(R_M), .focusLost, .key(NA)], [KA, R_M, E, NA])
check("ေ င ် then space (not kinzi)", keys(E, NGA, ASAT, SPACE), [NGA, E, ASAT, SPACE])

// What the user sees while composing
checkMarked("marked: ေ alone", keys(E), [E])
checkMarked("marked: ေ က ြ shows ကြေ", keys(E, KA, R_M), [KA, R_M, E])
checkMarked("marked: cleared after a vowel", keys(E, KA, AA), [])

print("\n\(passed) passed, \(failed) failed")
if failed > 0 {
    fatalError("\(failed) test(s) failed")
}
