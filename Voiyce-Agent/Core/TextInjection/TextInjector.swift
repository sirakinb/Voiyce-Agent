import Cocoa
import ApplicationServices

final class TextInjector {

    /// Inject a chunk of text into the currently focused app using pasteboard + Cmd+V.
    /// This is the most reliable method on modern macOS.
    func injectText(_ text: String) {
        pasteText(text)
    }

    /// Inject a delta (partial result) during real-time dictation
    func injectDelta(_ delta: String) {
        guard !delta.isEmpty else { return }
        pasteText(delta)
    }

    /// Delete the last n characters (for correction handling)
    func deleteCharacters(_ count: Int) {
        let source = CGEventSource(stateID: .privateState)
        for _ in 0..<count {
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false)
            keyDown?.flags = []
            keyUp?.flags = []
            keyDown?.post(tap: .cgSessionEventTap)
            keyUp?.post(tap: .cgSessionEventTap)
            usleep(5000)
        }
    }

    // MARK: - Private

    private func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        // Save current clipboard
        let previousContents = pasteboard.string(forType: .string)

        // Set our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Post Cmd+V using a private event source so held keys don't interfere
        let source = CGEventSource(stateID: .privateState)
        let vKeyCode: CGKeyCode = 0x09

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)

        // Restore clipboard after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }
}
