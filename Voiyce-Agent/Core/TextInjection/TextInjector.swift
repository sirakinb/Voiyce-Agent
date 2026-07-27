import Cocoa
import ApplicationServices

/// Result of a text-injection attempt. The paste path relies on macOS
/// Accessibility trust; without it the ⌘V CGEvent silently no-ops, so we report
/// that back to the caller instead of pretending the words landed.
enum TextInjectionOutcome: Equatable {
    /// Accessibility trusted, transcript verified on the clipboard, ⌘V scheduled.
    case injected
    /// Accessibility off; the ⌘V would no-op, but the transcript is verifiably on
    /// the clipboard for a manual paste.
    case accessibilityDenied
    /// The transcript could not be published to the clipboard at all (write or
    /// readback failed). The words are neither inserted nor on the clipboard, so
    /// the caller must fall back to persisted history and a retry-copy path.
    case clipboardUnavailable
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

    /// Publishes text to the clipboard and verifies it via readback. Injected so
    /// tests can force a publication failure deterministically without depending
    /// on real pasteboard state. Returns whether the transcript is verifiably on
    /// the clipboard.
    private let publishToClipboard: (String) -> Bool

    init(
        isAccessibilityTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        publishToClipboard: @escaping (String) -> Bool = TextInjector.defaultPublishToClipboard
    ) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.publishToClipboard = publishToClipboard
    }

    /// Default clipboard publication: write the string and confirm it landed by
    /// reading it straight back. A failed write or a mismatched readback means the
    /// words are not on the clipboard, so we must not report success.
    static func defaultPublishToClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        let didWrite = pasteboard.setString(text, forType: .string)
        return didWrite && pasteboard.string(forType: .string) == text
    }

    /// User-initiated recovery: place `text` back on the clipboard through the
    /// same verified seam. Returns whether the write was confirmed so callers
    /// never imply the words are on the clipboard when they aren't.
    @discardableResult
    func copyToClipboard(_ text: String) -> Bool {
        publishToClipboard(text)
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

        // Duplicate suppression only fires for a paste that already landed
        // successfully: `lastInjection` is recorded solely after a verified
        // publish below, so a prior failed publication can never be replayed here
        // as a fake success.
        if let lastInjection,
           lastInjection.text == text,
           lastInjection.appName == destinationAppName,
           now.timeIntervalSince(lastInjection.timestamp) < duplicateSuppressionWindow {
            print("[TextInjector] Suppressed duplicate paste into \(destinationAppName)")
            return .injected
        }

        // Without Accessibility trust the ⌘V CGEvent posts but is silently
        // dropped by the window server. Detect that up front and fall back to a
        // manual paste — but only claim the transcript is on the clipboard when
        // the write is actually verified. If even that fails, report it so the
        // caller can surface history + a retry-copy path instead of losing words.
        guard isAccessibilityTrusted() else {
            guard publishToClipboard(text) else {
                print("[TextInjector] Accessibility not trusted and clipboard publish failed")
                return .clipboardUnavailable
            }
            print("[TextInjector] Accessibility not trusted; left transcript on clipboard for manual paste")
            return .accessibilityDenied
        }

        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Publish + verify before scheduling the paste. A failed publication must
        // never be reported as an insertion — the ⌘V would paste stale or empty
        // clipboard contents.
        guard publishToClipboard(text) else {
            print("[TextInjector] Failed to publish transcript to pasteboard")
            return .clipboardUnavailable
        }

        // The transcript is verifiably on the clipboard and the paste is about to
        // be queued, so it is now safe to record for duplicate suppression.
        lastInjection = (text: text, appName: destinationAppName, timestamp: now)
        let injectionID = UUID()
        activeInjectionID = injectionID

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
