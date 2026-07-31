import Cocoa
import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class TextInjector {
    private var lastInjection: (text: String, appName: String, timestamp: Date)?
    private let duplicateSuppressionWindow: TimeInterval = 0.75
    private let pasteboardPropagationDelay: TimeInterval = 0.08
    private let targetReactivationDelay: TimeInterval = 0.18
    private let clipboardRestoreDelay: TimeInterval = 1.0
    /// The dictation hotkey is hold-Control, so the user's finger is often still on a
    /// modifier when the transcript arrives. A synthetic Cmd+V posted while a physical
    /// modifier is down reads as Ctrl+Cmd+V in modifier-tracking apps and is dropped.
    private let modifierReleaseTimeout: TimeInterval = 2.0
    private let focusSettleTimeout: TimeInterval = 1.0
    private let pollInterval: TimeInterval = 0.02
    private var activeInjectionID: UUID?

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
        let injectionID = UUID()
        activeInjectionID = injectionID

        pasteboard.declareTypes([.string], owner: nil)
        let didWriteTranscript = pasteboard.setString(text, forType: .string)
        guard didWriteTranscript, pasteboard.string(forType: .string) == text else {
            print("[TextInjector] Failed to publish transcript to pasteboard")
            return
        }

        let shouldReactivateTarget = {
            guard let targetApplication, let targetBundleIdentifier else { return false }
            guard let currentBundleIdentifier = frontmostBeforePaste?.bundleIdentifier else { return true }
            return currentBundleIdentifier != targetBundleIdentifier && !targetApplication.isTerminated
        }()

        if shouldReactivateTarget, let targetApplication {
            let activated = targetApplication.activate(options: [])
            print("[TextInjector] Restored focus to \(destinationAppName): \(activated)")
        }

        let pasteDelay = shouldReactivateTarget ? targetReactivationDelay : pasteboardPropagationDelay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(pasteDelay * 1_000_000_000))
            guard self.activeInjectionID == injectionID else { return }

            if IsSecureEventInputEnabled() {
                print("[TextInjector] Secure input is enabled; synthetic paste may be blocked. Transcript remains on the clipboard.")
            }

            await self.waitForPhysicalModifierRelease()
            await self.waitForTargetFocus(
                bundleIdentifier: targetBundleIdentifier,
                targetApplication: targetApplication
            )
            guard self.activeInjectionID == injectionID else { return }
            self.postPasteCommand()

            try? await Task.sleep(nanoseconds: UInt64(self.clipboardRestoreDelay * 1_000_000_000))
            guard self.activeInjectionID == injectionID else { return }
            guard pasteboard.string(forType: .string) == text else {
                // The user or another app changed the clipboard after paste; do not overwrite it.
                self.activeInjectionID = nil
                return
            }

            if let previous = previousContents {
                pasteboard.declareTypes([.string], owner: nil)
                pasteboard.setString(previous, forType: .string)
            }
            self.activeInjectionID = nil
        }
    }

    /// Wait until Control/Option/Shift are physically released so the synthetic Cmd+V
    /// isn't contaminated into a different chord. Times out rather than stalling forever.
    private func waitForPhysicalModifierRelease() async {
        let deadline = Date().addingTimeInterval(modifierReleaseTimeout)
        while Date() < deadline {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            let blockingModifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskShift]
            if flags.intersection(blockingModifiers).isEmpty {
                return
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        print("[TextInjector] Proceeding with paste despite held modifier keys (timeout)")
    }

    /// Wait until the target app is actually frontmost before posting the keystroke,
    /// re-activating it if needed. A fixed delay is not enough for slower apps.
    private func waitForTargetFocus(
        bundleIdentifier: String?,
        targetApplication: NSRunningApplication?
    ) async {
        guard let bundleIdentifier else { return }
        let deadline = Date().addingTimeInterval(focusSettleTimeout)
        while Date() < deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier {
                return
            }
            if let targetApplication, !targetApplication.isTerminated {
                targetApplication.activate(options: [])
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        print("[TextInjector] Target app never became frontmost; pasting into current app")
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
        let commandKeyCode: CGKeyCode = 0x37

        // Post an explicit Command press around the V keystroke. Some apps
        // (notably Electron/Chromium) track modifier state from flagsChanged
        // events and ignore a bare V keyDown that only carries the Command flag.
        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: commandKeyCode, keyDown: true)
        commandDown?.flags = .maskCommand

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: commandKeyCode, keyDown: false)
        commandUp?.flags = []

        commandDown?.post(tap: .cgSessionEventTap)
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
        commandUp?.post(tap: .cgSessionEventTap)
    }
}
