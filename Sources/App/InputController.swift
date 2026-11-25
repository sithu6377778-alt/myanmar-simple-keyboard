import Carbon.HIToolbox
import Cocoa
import InputMethodKit

/// One instance per text field. Receives key presses from macOS, types the
/// Myanmar character for the key, and holds ေ back until the consonant
/// cluster after it is complete.
@objc(MSKInputController)
final class MSKInputController: IMKInputController {
    private static let translator = KeyTranslator()

    /// Keys that are never typed by the keyboard: finish composing and let the
    /// app handle them (Return, Tab, Escape, arrows, F-keys…).
    private static let passThroughKeyCodes: Set<Int> = [
        kVK_Return, kVK_ANSI_KeypadEnter, kVK_Tab, kVK_Escape, kVK_ForwardDelete,
        kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown, kVK_Help,
        kVK_LeftArrow, kVK_RightArrow, kVK_DownArrow, kVK_UpArrow,
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
        kVK_JIS_Eisu, kVK_JIS_Kana,
        0x6E,   // contextual-menu key on PC keyboards
    ]

    private var composer = EComposer()
    private var showingMarkedText = false

    override func recognizedEvents(_ sender: Any!) -> Int {
        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        return Int(mask.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, let client = sender as? IMKTextInput else { return false }

        // A click moves the cursor: finish the word first.
        guard event.type == .keyDown else {
            finish(client)
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Shortcuts (⌘C, ⌃A…) belong to the app.
        if flags.contains(.command) || flags.contains(.control) {
            finish(client)
            return false
        }

        let keyCode = Int(event.keyCode)

        if keyCode == kVK_Delete {
            if let result = composer.backspace() {
                apply(result, to: client)
                return true
            }
            return false
        }

        if Self.passThroughKeyCodes.contains(keyCode) {
            finish(client)
            return false
        }

        let text = Self.translator.text(
            keyCode: event.keyCode,
            shift: flags.contains(.shift),
            option: flags.contains(.option),
            capsLock: flags.contains(.capsLock)) ?? ""

        // Keys that type nothing on Apple's Myanmar layout (e.g. Option+a)
        // also type nothing here, instead of falling through to Latin letters.
        if text.isEmpty {
            return true
        }

        // Control characters (keypad Clear etc.) are for the app.
        if text.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) {
            finish(client)
            return false
        }

        apply(composer.input(text), to: client)
        return true
    }

    override func commitComposition(_ sender: Any!) {
        let target: IMKTextInput? = (sender as? IMKTextInput) ?? (client() as IMKTextInput?)
        guard let target = target else { return }
        finish(target)
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
        super.deactivateServer(sender)
    }

    // MARK: - Helpers

    private func finish(_ client: IMKTextInput) {
        guard composer.isComposing else { return }
        apply(EComposer.Result(commit: composer.commitAll(), marked: ""), to: client)
    }

    private func apply(_ result: EComposer.Result, to client: IMKTextInput) {
        let notFound = NSRange(location: NSNotFound, length: NSNotFound)
        if !result.commit.isEmpty {
            // Replaces any marked text with the final text.
            client.insertText(result.commit, replacementRange: notFound)
            showingMarkedText = false
        }
        if !result.marked.isEmpty {
            let length = (result.marked as NSString).length
            client.setMarkedText(result.marked,
                                 selectionRange: NSRange(location: length, length: 0),
                                 replacementRange: notFound)
            showingMarkedText = true
        } else if showingMarkedText {
            client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0),
                                 replacementRange: notFound)
            showingMarkedText = false
        }
    }
}
