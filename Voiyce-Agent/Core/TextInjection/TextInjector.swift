import Cocoa
import ApplicationServices

/// Result of a text-injection attempt. The paste path relies on macOS
/// Accessibility trust; without it the ⌘V CGEvent silently no-ops, so we report
/// that back to the caller instead of pretending the words landed.
enum TextInjectionOutcome: Equatable {
    /// Accessibility trusted, transcript verified on the clipboard, and the field
    /// value/range matched the selection-aware post-paste expectation.
    case injected
    /// Accessibility off; the ⌘V would no-op, but the transcript is verifiably on
    /// the clipboard for a manual paste.
    case accessibilityDenied
    /// The transcript could not be published to the clipboard at all (write or
    /// readback failed). The words are neither inserted nor on the clipboard, so
    /// the caller must fall back to persisted history and a retry-copy path.
    case clipboardUnavailable
    /// The HID paste was posted but the field could not be confirmed (non-introspectable
    /// or readable value did not match expectation). The verified transcript stays on
    /// the clipboard for a manual paste.
    case pasteUnconfirmed
}

struct PasteTargetContext: Equatable {
    let processID: pid_t
    let bundleIdentifier: String?
    let appName: String
}

struct TextSelectionRange: Equatable {
    let location: Int
    let length: Int

    var nsRange: NSRange {
        NSRange(location: location, length: length)
    }
}

struct FocusedFieldState: Equatable {
    let value: String?
    let selectedRange: TextSelectionRange?
    let role: String?
    let processID: pid_t?
    let isIntrospectable: Bool
}

enum PasteExpectation {
    static func expectedValue(
        currentValue: String,
        selectedRange: TextSelectionRange,
        inserting transcript: String
    ) -> String {
        let value = currentValue as NSString
        let safeRange = clampedRange(selectedRange, in: value.length)
        return value.replacingCharacters(in: safeRange, with: transcript)
    }

    static func expectedSelectedRange(
        afterInserting transcript: String,
        replacing selectedRange: TextSelectionRange
    ) -> TextSelectionRange {
        TextSelectionRange(
            location: selectedRange.location + (transcript as NSString).length,
            length: 0
        )
    }

    static func matches(
        observed: FocusedFieldState,
        expectedValue: String,
        expectedSelection: TextSelectionRange
    ) -> Bool {
        guard observed.isIntrospectable, let observedValue = observed.value else {
            return false
        }
        guard observedValue == expectedValue else { return false }
        guard let observedSelection = observed.selectedRange else { return false }
        return observedSelection == expectedSelection
    }

    private static func clampedRange(_ range: TextSelectionRange, in length: Int) -> NSRange {
        let location = max(0, min(range.location, length))
        let maxLength = max(0, length - location)
        let safeLength = max(0, min(range.length, maxLength))
        return NSRange(location: location, length: safeLength)
    }
}

@MainActor
final class TextInjector {
    private var lastInjection: (text: String, appName: String, timestamp: Date)?
    private let duplicateSuppressionWindow: TimeInterval = 0.75
    private let pasteboardPropagationDelay: TimeInterval = 0.08
    private let targetReactivationDelay: TimeInterval = 0.18
    private let clipboardRestoreDelay: TimeInterval = 1.0
    private let focusRestoreBudget: Duration = .milliseconds(250)
    private let confirmationBudget: Duration = .milliseconds(250)
    private let confirmationPollInterval: Duration = .milliseconds(25)
    private let focusPollInterval: Duration = .milliseconds(25)
    private var activeInjectionID: UUID?
    private var clipboardRestoreTask: Task<Void, Never>?

    private let isAccessibilityTrusted: () -> Bool
    private let publishToClipboard: (String) -> Bool
    private let readClipboard: () -> String?
    private let frontmostProcessID: () -> pid_t?
    private let readFocusedFieldState: () -> FocusedFieldState?
    private let activateTargetProcess: (pid_t) -> Bool
    private let postPasteChord: () -> Void
    private let sleep: (Duration) async -> Void

    init(
        isAccessibilityTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        publishToClipboard: @escaping (String) -> Bool = TextInjector.defaultPublishToClipboard,
        readClipboard: @escaping () -> String? = { NSPasteboard.general.string(forType: .string) },
        frontmostProcessID: @escaping () -> pid_t? = {
            NSWorkspace.shared.frontmostApplication?.processIdentifier
        },
        readFocusedFieldState: @escaping () -> FocusedFieldState? = TextInjector.defaultReadFocusedFieldState,
        activateTargetProcess: @escaping (pid_t) -> Bool = TextInjector.defaultActivateTargetProcess,
        postPasteChord: @escaping () -> Void = TextInjector.defaultPostPasteChord,
        sleep: @escaping (Duration) async -> Void = { duration in
            try? await Task.sleep(for: duration)
        }
    ) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.publishToClipboard = publishToClipboard
        self.readClipboard = readClipboard
        self.frontmostProcessID = frontmostProcessID
        self.readFocusedFieldState = readFocusedFieldState
        self.activateTargetProcess = activateTargetProcess
        self.postPasteChord = postPasteChord
        self.sleep = sleep
    }

    static func defaultPublishToClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        let didWrite = pasteboard.setString(text, forType: .string)
        return didWrite && pasteboard.string(forType: .string) == text
    }

    static func defaultActivateTargetProcess(_ processID: pid_t) -> Bool {
        NSRunningApplication(processIdentifier: processID)?.activate(options: []) ?? false
    }

    static func defaultPostPasteChord() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 0x09
        let commandKeyCode: CGKeyCode = 0x37

        if let commandDown = CGEvent(keyboardEventSource: source, virtualKey: commandKeyCode, keyDown: true) {
            commandDown.flags = .maskCommand
            commandDown.post(tap: .cghidEventTap)
        }

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }

        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }

        if let commandUp = CGEvent(keyboardEventSource: source, virtualKey: commandKeyCode, keyDown: false) {
            commandUp.flags = []
            commandUp.post(tap: .cghidEventTap)
        }
    }

    static func defaultReadFocusedFieldState() -> FocusedFieldState? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success,
            let focusedRef else {
            return nil
        }

        let element = focusedRef as! AXUIElement
        var processID: pid_t = 0
        AXUIElementGetPid(element, &processID)

        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String

        var selectedRange: TextSelectionRange?
        var selectedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRef
        ) == .success,
            let axValue = selectedRef,
            CFGetTypeID(axValue) == AXValueGetTypeID() {
            var range = CFRange()
            if AXValueGetValue(axValue as! AXValue, .cfRange, &range) {
                selectedRange = TextSelectionRange(location: range.location, length: range.length)
            }
        }

        var valueRef: CFTypeRef?
        let valueStatus = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
        if valueStatus == .success, let value = valueRef as? String {
            return FocusedFieldState(
                value: value,
                selectedRange: selectedRange ?? TextSelectionRange(location: value.count, length: 0),
                role: role,
                processID: processID == 0 ? nil : processID,
                isIntrospectable: true
            )
        }

        return FocusedFieldState(
            value: nil,
            selectedRange: nil,
            role: role,
            processID: processID == 0 ? nil : processID,
            isIntrospectable: false
        )
    }

    @discardableResult
    func copyToClipboard(_ text: String) -> Bool {
        publishToClipboard(text)
    }

    func injectText(
        _ text: String,
        targetContext: PasteTargetContext? = nil,
        targetBundleIdentifier: String? = nil,
        targetAppName: String? = nil
    ) async -> TextInjectionOutcome {
        await pasteText(
            text,
            targetContext: targetContext,
            targetBundleIdentifier: targetBundleIdentifier,
            targetAppName: targetAppName
        )
    }

    func injectDelta(_ delta: String) {
        guard !delta.isEmpty else { return }
        Task {
            _ = await pasteText(
                delta,
                targetContext: nil,
                targetBundleIdentifier: nil,
                targetAppName: nil
            )
        }
    }

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
        targetContext: PasteTargetContext?,
        targetBundleIdentifier: String?,
        targetAppName: String?
    ) async -> TextInjectionOutcome {
        let resolvedTarget = targetContext ?? resolveTargetContext(
            bundleIdentifier: targetBundleIdentifier,
            appName: targetAppName
        )
        let destinationAppName = resolvedTarget?.appName
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

        let axTrusted = isAccessibilityTrusted()
        guard axTrusted else {
            guard publishToClipboard(text) else {
                print("[TextInjector] Accessibility not trusted and clipboard publish failed")
                return .clipboardUnavailable
            }
            print("[TextInjector] Accessibility not trusted; left transcript on clipboard for manual paste")
            return .accessibilityDenied
        }

        let previousContents = readClipboard()

        guard publishToClipboard(text) else {
            print("[TextInjector] Failed to publish transcript to pasteboard")
            return .clipboardUnavailable
        }

        clipboardRestoreTask?.cancel()
        let injectionID = UUID()
        activeInjectionID = injectionID

        let frontmostMatchesTarget = frontmostMatchesTargetProcess(resolvedTarget)
        let focusRestore = await restoreTargetFocusIfNeeded(resolvedTarget)
        let focusReresolvedMatchesTarget = focusRestore.focusMatchesTarget

        guard focusRestore.didRestore else {
            logPasteDiagnostic(
                axTrusted: axTrusted,
                frontmostMatchesTarget: frontmostMatchesTarget,
                focusReresolvedMatchesTarget: focusReresolvedMatchesTarget,
                postTap: "none",
                focusedField: readFocusedFieldState(),
                selectionLengthDelta: nil,
                outcome: "pasteUnconfirmed"
            )
            return .pasteUnconfirmed
        }

        if resolvedTarget != nil {
            await sleep(.milliseconds(Int(pasteboardPropagationDelay * 1000)))
        } else {
            await sleep(.milliseconds(Int(pasteboardPropagationDelay * 1000)))
        }

        guard activeInjectionID == injectionID else {
            return .pasteUnconfirmed
        }

        let prePasteField = readFocusedFieldState()
        guard prePasteField != nil else {
            return finishUnconfirmedPaste(
                text: text,
                destinationAppName: destinationAppName,
                injectionID: injectionID,
                previousContents: previousContents,
                timestamp: now,
                axTrusted: axTrusted,
                frontmostMatchesTarget: frontmostMatchesTarget,
                focusReresolvedMatchesTarget: focusReresolvedMatchesTarget,
                prePasteField: nil
            )
        }

        let prePasteSelection = prePasteField?.selectedRange ?? TextSelectionRange(location: 0, length: 0)
        let prePasteValue = prePasteField?.value ?? ""
        let expectedValue: String?
        let expectedSelection: TextSelectionRange?

        if let prePasteField, prePasteField.isIntrospectable, let selectedRange = prePasteField.selectedRange {
            expectedValue = PasteExpectation.expectedValue(
                currentValue: prePasteValue,
                selectedRange: selectedRange,
                inserting: text
            )
            expectedSelection = PasteExpectation.expectedSelectedRange(
                afterInserting: text,
                replacing: selectedRange
            )
        } else if let prePasteField, !prePasteField.isIntrospectable {
            expectedValue = nil
            expectedSelection = nil
        } else {
            expectedValue = PasteExpectation.expectedValue(
                currentValue: prePasteValue,
                selectedRange: prePasteSelection,
                inserting: text
            )
            expectedSelection = PasteExpectation.expectedSelectedRange(
                afterInserting: text,
                replacing: prePasteSelection
            )
        }

        postPasteChord()
        logPasteDiagnostic(
            axTrusted: axTrusted,
            frontmostMatchesTarget: frontmostMatchesTarget,
            focusReresolvedMatchesTarget: focusReresolvedMatchesTarget,
            postTap: "cghidEventTap",
            focusedField: prePasteField,
            selectionLengthDelta: prePasteSelection.length,
            outcome: "posted"
        )

        if expectedValue == nil {
            return finishUnconfirmedPaste(
                text: text,
                destinationAppName: destinationAppName,
                injectionID: injectionID,
                previousContents: previousContents,
                timestamp: now,
                axTrusted: axTrusted,
                frontmostMatchesTarget: frontmostMatchesTarget,
                focusReresolvedMatchesTarget: focusReresolvedMatchesTarget,
                prePasteField: prePasteField
            )
        }

        let confirmed = await waitForConfirmation(
            expectedValue: expectedValue!,
            expectedSelection: expectedSelection!
        )

        guard activeInjectionID == injectionID else {
            return .pasteUnconfirmed
        }

        if confirmed {
            lastInjection = (text: text, appName: destinationAppName, timestamp: now)
            scheduleClipboardRestore(
                text: text,
                previousContents: previousContents,
                injectionID: injectionID
            )
            logPasteDiagnostic(
                axTrusted: axTrusted,
                frontmostMatchesTarget: frontmostMatchesTarget,
                focusReresolvedMatchesTarget: focusReresolvedMatchesTarget,
                postTap: "cghidEventTap",
                focusedField: readFocusedFieldState(),
                selectionLengthDelta: prePasteSelection.length,
                outcome: "injected"
            )
            return .injected
        }

        return finishUnconfirmedPaste(
            text: text,
            destinationAppName: destinationAppName,
            injectionID: injectionID,
            previousContents: previousContents,
            timestamp: now,
            axTrusted: axTrusted,
            frontmostMatchesTarget: frontmostMatchesTarget,
            focusReresolvedMatchesTarget: focusReresolvedMatchesTarget,
            prePasteField: prePasteField
        )
    }

    private struct FocusRestoreResult {
        let didRestore: Bool
        let focusMatchesTarget: Bool
    }

    private func restoreTargetFocusIfNeeded(_ target: PasteTargetContext?) async -> FocusRestoreResult {
        guard let target else {
            return FocusRestoreResult(didRestore: true, focusMatchesTarget: true)
        }

        if focusBelongsToTarget(readFocusedFieldState(), target: target),
           frontmostMatchesTargetProcess(target) {
            return FocusRestoreResult(didRestore: true, focusMatchesTarget: true)
        }

        if !frontmostMatchesTargetProcess(target) {
            _ = activateTargetProcess(target.processID)
            await sleep(.milliseconds(Int(targetReactivationDelay * 1000)))
        }

        let deadline = ContinuousClock.now + focusRestoreBudget
        while ContinuousClock.now < deadline {
            if focusBelongsToTarget(readFocusedFieldState(), target: target),
               frontmostMatchesTargetProcess(target) {
                return FocusRestoreResult(didRestore: true, focusMatchesTarget: true)
            }
            await sleep(focusPollInterval)
        }

        return FocusRestoreResult(
            didRestore: false,
            focusMatchesTarget: focusBelongsToTarget(readFocusedFieldState(), target: target)
        )
    }

    private func waitForConfirmation(
        expectedValue: String,
        expectedSelection: TextSelectionRange
    ) async -> Bool {
        let deadline = ContinuousClock.now + confirmationBudget
        while ContinuousClock.now < deadline {
            if let observed = readFocusedFieldState(),
               PasteExpectation.matches(
                observed: observed,
                expectedValue: expectedValue,
                expectedSelection: expectedSelection
               ) {
                return true
            }
            await sleep(confirmationPollInterval)
        }
        return false
    }

    private func finishUnconfirmedPaste(
        text: String,
        destinationAppName: String,
        injectionID: UUID,
        previousContents: String?,
        timestamp: Date,
        axTrusted: Bool,
        frontmostMatchesTarget: Bool,
        focusReresolvedMatchesTarget: Bool,
        prePasteField: FocusedFieldState?
    ) -> TextInjectionOutcome {
        activeInjectionID = nil
        clipboardRestoreTask?.cancel()
        _ = publishToClipboard(text)
        logPasteDiagnostic(
            axTrusted: axTrusted,
            frontmostMatchesTarget: frontmostMatchesTarget,
            focusReresolvedMatchesTarget: focusReresolvedMatchesTarget,
            postTap: "cghidEventTap",
            focusedField: prePasteField,
            selectionLengthDelta: prePasteField?.selectedRange?.length,
            outcome: "pasteUnconfirmed"
        )
        _ = destinationAppName
        _ = previousContents
        _ = timestamp
        return .pasteUnconfirmed
    }

    private func scheduleClipboardRestore(
        text: String,
        previousContents: String?,
        injectionID: UUID
    ) {
        clipboardRestoreTask?.cancel()
        clipboardRestoreTask = Task { @MainActor in
            await sleep(.milliseconds(Int((pasteboardPropagationDelay + clipboardRestoreDelay) * 1000)))
            guard self.activeInjectionID == injectionID else { return }
            guard self.readClipboard() == text else {
                self.activeInjectionID = nil
                return
            }
            if let previousContents {
                self.publishToClipboard(previousContents)
            }
            self.activeInjectionID = nil
        }
    }

    private func frontmostMatchesTargetProcess(_ target: PasteTargetContext?) -> Bool {
        guard let target else { return true }
        return frontmostProcessID() == target.processID
    }

    private func focusBelongsToTarget(_ field: FocusedFieldState?, target: PasteTargetContext) -> Bool {
        guard let field, let processID = field.processID else { return false }
        return processID == target.processID
    }

    private func resolveTargetContext(
        bundleIdentifier: String?,
        appName: String?
    ) -> PasteTargetContext? {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty,
              let application = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleIdentifier)
                .first(where: { !$0.isTerminated }) else {
            return nil
        }

        return PasteTargetContext(
            processID: application.processIdentifier,
            bundleIdentifier: bundleIdentifier,
            appName: application.localizedName ?? appName ?? "Unknown"
        )
    }

    private func logPasteDiagnostic(
        axTrusted: Bool,
        frontmostMatchesTarget: Bool,
        focusReresolvedMatchesTarget: Bool,
        postTap: String,
        focusedField: FocusedFieldState?,
        selectionLengthDelta: Int?,
        outcome: String
    ) {
        print(
            DictationDebugLogCopy.pasteDeliveryDiagnostic(
                axTrusted: axTrusted,
                frontmostMatchesTarget: frontmostMatchesTarget,
                focusReresolvedMatchesTarget: focusReresolvedMatchesTarget,
                postTap: postTap,
                axRole: focusedField?.role,
                selectionLengthDelta: selectionLengthDelta,
                outcome: outcome
            )
        )
    }
}
