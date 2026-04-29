import Cocoa
import ApplicationServices

@MainActor
final class TextInjector {
    private var lastInjection: (text: String, appName: String, timestamp: Date)?
    private let duplicateSuppressionWindow: TimeInterval = 0.75

    /// Inject a chunk of text into the currently focused app using pasteboard + Cmd+V.
    /// This is the most reliable method on modern macOS.
    func injectText(
        _ text: String,
        targetBundleIdentifier: String? = nil,
        targetAppName: String? = nil
    ) {
        pasteText(
            text,
            targetBundleIdentifier: targetBundleIdentifier,
            targetAppName: targetAppName
        )
    }

    /// Inject a delta (partial result) during real-time dictation
    func injectDelta(_ delta: String) {
        guard !delta.isEmpty else { return }
        pasteText(delta, targetBundleIdentifier: nil, targetAppName: nil)
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

    private func pasteText(
        _ text: String,
        targetBundleIdentifier: String?,
        targetAppName: String?
    ) {
        let targetApplication = resolveTargetApplication(bundleIdentifier: targetBundleIdentifier)
        let frontmostBeforePaste = NSWorkspace.shared.frontmostApplication
        let destinationAppName = targetApplication?.localizedName
            ?? frontmostBeforePaste?.localizedName
            ?? targetAppName
            ?? "Unknown"
        let now = Date()

        if let lastInjection,
           lastInjection.text == text,
           lastInjection.appName == destinationAppName,
           now.timeIntervalSince(lastInjection.timestamp) < duplicateSuppressionWindow {
            print("[TextInjector] Suppressed duplicate paste into \(destinationAppName)")
            return
        }

        lastInjection = (text: text, appName: destinationAppName, timestamp: now)
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let shouldReactivateTarget = {
            guard let targetApplication, let targetBundleIdentifier else { return false }
            guard let currentBundleIdentifier = frontmostBeforePaste?.bundleIdentifier else { return true }
            return currentBundleIdentifier != targetBundleIdentifier && !targetApplication.isTerminated
        }()

        if shouldReactivateTarget, let targetApplication {
            let activated = targetApplication.activate(options: [.activateIgnoringOtherApps])
            print("[TextInjector] Restored focus to \(destinationAppName): \(activated)")
        }

        let pasteDelay = shouldReactivateTarget ? 0.12 : 0.02
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) {
            self.postPasteCommand()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay + 0.18) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private func resolveTargetApplication(bundleIdentifier: String?) -> NSRunningApplication? {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
            return nil
        }

        return NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { !$0.isTerminated })
    }

    private func postPasteCommand() {
        let source = CGEventSource(stateID: .privateState)
        let vKeyCode: CGKeyCode = 0x09

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
