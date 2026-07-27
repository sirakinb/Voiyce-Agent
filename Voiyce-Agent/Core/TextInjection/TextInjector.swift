import Cocoa
import ApplicationServices

/// Result of a text-injection attempt. The paste path relies on macOS
/// Accessibility trust; without it the ⌘V CGEvent silently no-ops, so we report
/// that back to the caller instead of pretending the words landed.
enum TextInjectionOutcome: Equatable {
    case injected
    case accessibilityDenied
}

@MainActor
final class TextInjector {
    private var lastInjection: (text: String, appName: String, timestamp: Date)?
    private let duplicateSuppressionWindow: TimeInterval = 0.75
    private let pasteboardPropagationDelay: TimeInterval = 0.08
    private let targetReactivationDelay: TimeInterval = 0.18
    private let clipboardRestoreDelay: TimeInterval = 1.0
    private var activeInjectionID: UUID?

    /// Injected so the Accessibility-trust gate can be exercised in tests without
    /// touching real system state. Defaults to the live `AXIsProcessTrusted()`.
    private let isAccessibilityTrusted: () -> Bool

    init(isAccessibilityTrusted: @escaping () -> Bool = { AXIsProcessTrusted() }) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
    }

    /// Inject a chunk of text into the currently focused app using pasteboard + Cmd+V.
    /// This is the most reliable method on modern macOS. Returns whether the paste
    /// could actually be performed (Accessibility trusted) or was blocked.
    @discardableResult
    func injectText(
        _ text: String,
        targetBundleIdentifier: String? = nil,
        targetAppName: String? = nil
    ) -> TextInjectionOutcome {
        pasteText(
            text,
            targetBundleIdentifier: targetBundleIdentifier,
            targetAppName: targetAppName
        )
    }

    /// Inject a delta (partial result) during real-time dictation
    func injectDelta(_ delta: String) {
        guard !delta.isEmpty else { return }
        _ = pasteText(delta, targetBundleIdentifier: nil, targetAppName: nil)
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

    @discardableResult
    private func pasteText(
        _ text: String,
        targetBundleIdentifier: String?,
        targetAppName: String?
    ) -> TextInjectionOutcome {
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
            return .injected
        }

        // Without Accessibility trust the ⌘V CGEvent posts but is silently
        // dropped by the window server. Detect that up front, keep the transcript
        // on the clipboard so the user can paste it manually, and report the
        // blocked outcome instead of faking a successful insertion.
        guard isAccessibilityTrusted() else {
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(text, forType: .string)
            print("[TextInjector] Accessibility not trusted; left transcript on clipboard for manual paste")
            return .accessibilityDenied
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
            return .injected
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
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) {
            guard self.activeInjectionID == injectionID else { return }
            self.postPasteCommand()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay + clipboardRestoreDelay) {
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

        return .injected
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
