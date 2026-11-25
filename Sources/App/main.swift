import Cocoa
import InputMethodKit

// Myanmar Simple Keyboard for Mac — by Linn Labs
// Type ေ first like the iPhone Myanmar keyboard.

let connectionName = "com.linnlabs.inputmethod.MyanmarSimple_Connection"
let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

// Command-line helpers (used by the installer and by CI). The system starts
// the keyboard without arguments.
if CommandLine.arguments.count > 1 {
    switch CommandLine.arguments[1] {
    case "--install":
        exit(Registration.install(bundleURL: Bundle.main.bundleURL))
    case "--status":
        exit(Registration.printStatus())
    case "--select":
        exit(Registration.select())
    case "--self-test":
        exit(SelfTest.run())
    case "--version":
        print("Myanmar Simple Keyboard \(version)")
        exit(0)
    default:
        break
    }
}

// Make sure the controller class is linked and visible to InputMethodKit.
_ = MSKInputController.self

guard let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier) else {
    NSLog("MyanmarSimpleKeyboard: could not start the input method server")
    exit(1)
}

NSLog("MyanmarSimpleKeyboard \(version) started")
withExtendedLifetime(server) {
    NSApplication.shared.run()
}
