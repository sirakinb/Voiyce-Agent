//
//  TextInjectorAutopasteTests.swift
//  Voiyce-AgentTests
//

import Foundation
import Testing
@testable import Voiyce

@MainActor
private final class TextInjectorTestHarness {
    var axTrusted = true
    var clipboard: String?
    var frontmostPID: pid_t = 100
    var targetPID: pid_t = 100
    var fieldValue = ""
    var selectedRange = TextSelectionRange(location: 0, length: 0)
    var hasSelectedRange = true
    var fieldRole = "AXTextField"
    var introspectable = true
    var focusedProcessID: pid_t = 100
    var windowIdentity = "AXWindow|0,0,800,600"
    var focusedElementIdentity = "AXTextField|10,20,300,24"
    var pastePostCount = 0
    var recordedChordSteps: [HIDPasteChordStep] = []
    var activateCallCount = 0
    var activateSucceeds = true
    var simulatePasteOnPost = true
    var activationRestoresFocus = true
    var publishSucceeds = true
    var sleeps: [Duration] = []

    func targetContext(bundleIdentifier: String? = "com.test", appName: String = "Test") -> PasteTargetContext {
        PasteTargetContext(
            processID: targetPID,
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            windowIdentity: windowIdentity,
            focusedElementIdentity: focusedElementIdentity
        )
    }

    func makeInjector(recordChord: Bool = false) -> TextInjector {
        TextInjector(
            isAccessibilityTrusted: { [self] in axTrusted },
            publishToClipboard: { [self] text in
                guard publishSucceeds else { return false }
                clipboard = text
                return true
            },
            readClipboard: { [self] in clipboard },
            frontmostProcessID: { [self] in frontmostPID },
            readFocusedFieldState: { [self] in
                let range = hasSelectedRange ? selectedRange : nil
                let canConfirm = introspectable && hasSelectedRange
                return FocusedFieldState(
                    value: introspectable ? fieldValue : nil,
                    selectedRange: range,
                    role: fieldRole,
                    processID: focusedProcessID,
                    windowIdentity: windowIdentity,
                    focusedElementIdentity: focusedElementIdentity,
                    isIntrospectable: canConfirm
                )
            },
            activateTargetProcess: { [self] pid in
                activateCallCount += 1
                guard activateSucceeds else { return false }
                if activationRestoresFocus {
                    frontmostPID = pid
                    focusedProcessID = pid
                }
                return true
            },
            postPasteChord: { [self] in
                pastePostCount += 1
                if recordChord {
                    recordedChordSteps = TextInjector.hidPasteChordSteps()
                }
                guard simulatePasteOnPost, introspectable, hasSelectedRange else { return }
                let replacement = PasteExpectation.expectedValue(
                    currentValue: fieldValue,
                    selectedRange: selectedRange,
                    inserting: clipboard ?? ""
                )
                fieldValue = replacement
                selectedRange = PasteExpectation.expectedSelectedRange(
                    afterInserting: clipboard ?? "",
                    replacing: selectedRange
                )
            },
            sleep: { [self] duration in
                sleeps.append(duration)
            }
        )
    }
}

struct TextInjectorAutopasteTests {
    @MainActor
    @Test func hidPasteChordUsesFlagsChangedSequence() {
        #expect(TextInjector.hidPasteChordSteps() == [
            .commandFlagsChanged(down: true),
            .keyDown(0x09),
            .keyUp(0x09),
            .commandFlagsChanged(down: false)
        ])
    }

    @MainActor
    @Test func confirmedAppendDelivery() async {
        let harness = TextInjectorTestHarness()
        harness.fieldValue = "Hello "
        harness.selectedRange = TextSelectionRange(location: 6, length: 0)

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("world", targetContext: harness.targetContext())

        #expect(outcome == .injected)
        #expect(harness.fieldValue == "Hello world")
        #expect(harness.pastePostCount == 1)
        #expect(harness.clipboard == "world")
    }

    @MainActor
    @Test func selectionReplacementSameLengthConfirms() async {
        let harness = TextInjectorTestHarness()
        harness.fieldValue = "abcdef"
        harness.selectedRange = TextSelectionRange(location: 1, length: 3)

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("XYZ", targetContext: harness.targetContext())

        #expect(outcome == .injected)
        #expect(harness.fieldValue == "aXYZef")
    }

    @MainActor
    @Test func selectionReplacementShrinkingLengthConfirms() async {
        let harness = TextInjectorTestHarness()
        harness.fieldValue = "abcdef"
        harness.selectedRange = TextSelectionRange(location: 0, length: 4)

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("z", targetContext: harness.targetContext())

        #expect(outcome == .injected)
        #expect(harness.fieldValue == "zef")
    }

    @MainActor
    @Test func missingSelectedRangeReturnsPasteUnconfirmed() async {
        let harness = TextInjectorTestHarness()
        harness.fieldValue = "abcdef"
        harness.hasSelectedRange = false

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("hello", targetContext: harness.targetContext())

        #expect(outcome == .pasteUnconfirmed)
        #expect(harness.clipboard == "hello")
        #expect(harness.pastePostCount == 1)
    }

    @MainActor
    @Test func nonIntrospectableReturnsPasteUnconfirmedAndKeepsClipboard() async {
        let harness = TextInjectorTestHarness()
        harness.introspectable = false

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("hello", targetContext: harness.targetContext())

        #expect(outcome == .pasteUnconfirmed)
        #expect(harness.clipboard == "hello")
        #expect(harness.pastePostCount == 1)
    }

    @MainActor
    @Test func staleFocusTriggersReactivationPath() async {
        let harness = TextInjectorTestHarness()
        harness.frontmostPID = 200
        harness.focusedProcessID = 200

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("hello", targetContext: harness.targetContext())

        #expect(outcome == .injected)
        #expect(harness.activateCallCount >= 1)
        #expect(harness.frontmostPID == 100)
    }

    @MainActor
    @Test func mismatchedFocusedElementIdentityBlocksPaste() async {
        let harness = TextInjectorTestHarness()
        let target = harness.targetContext()
        harness.focusedElementIdentity = "AXTextField|99,99,300,24"

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("hello", targetContext: target)

        #expect(outcome == .pasteUnconfirmed)
        #expect(harness.clipboard == "hello")
        #expect(harness.pastePostCount == 0)
    }

    @MainActor
    @Test func missingCapturedIdentityDegradesWithoutPosting() async {
        let harness = TextInjectorTestHarness()
        let target = PasteTargetContext(
            processID: 100,
            bundleIdentifier: "com.test",
            appName: "Test",
            windowIdentity: nil,
            focusedElementIdentity: "AXTextField|10,20,300,24"
        )

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("hello", targetContext: target)

        #expect(outcome == .pasteUnconfirmed)
        #expect(harness.clipboard == "hello")
        #expect(harness.pastePostCount == 0)
    }

    @MainActor
    @Test func reactivationTimeoutReturnsPasteUnconfirmed() async {
        let harness = TextInjectorTestHarness()
        harness.frontmostPID = 200
        harness.focusedProcessID = 200
        harness.activationRestoresFocus = false

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("hello", targetContext: harness.targetContext())

        #expect(outcome == .pasteUnconfirmed)
        #expect(harness.clipboard == "hello")
        #expect(harness.pastePostCount == 0)
    }

    @MainActor
    @Test func reactivationTimeoutRecoveryPublishFailureReturnsClipboardUnavailable() async {
        let harness = TextInjectorTestHarness()
        harness.frontmostPID = 200
        harness.focusedProcessID = 200
        harness.activationRestoresFocus = false
        var publishAttempts = 0
        let injector = TextInjector(
            isAccessibilityTrusted: { true },
            publishToClipboard: { text in
                publishAttempts += 1
                guard publishAttempts == 1 else { return false }
                harness.clipboard = text
                return true
            },
            readClipboard: { harness.clipboard },
            frontmostProcessID: { harness.frontmostPID },
            readFocusedFieldState: {
                FocusedFieldState(
                    value: harness.fieldValue,
                    selectedRange: harness.selectedRange,
                    role: harness.fieldRole,
                    processID: harness.focusedProcessID,
                    windowIdentity: harness.windowIdentity,
                    focusedElementIdentity: harness.focusedElementIdentity,
                    isIntrospectable: true
                )
            },
            activateTargetProcess: { _ in false },
            postPasteChord: {},
            sleep: { duration in harness.sleeps.append(duration) }
        )

        let outcome = await injector.injectText("hello", targetContext: harness.targetContext())

        #expect(outcome == .clipboardUnavailable)
    }

    @MainActor
    @Test func readableMismatchReturnsPasteUnconfirmed() async {
        let harness = TextInjectorTestHarness()
        harness.simulatePasteOnPost = false

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("hello", targetContext: harness.targetContext())

        #expect(outcome == .pasteUnconfirmed)
        #expect(harness.clipboard == "hello")
    }

    @MainActor
    @Test func postMismatchRecoveryPublishFailureReturnsClipboardUnavailable() async {
        let harness = TextInjectorTestHarness()
        harness.simulatePasteOnPost = false
        var publishAttempts = 0
        let injector = TextInjector(
            isAccessibilityTrusted: { true },
            publishToClipboard: { text in
                publishAttempts += 1
                guard publishAttempts == 1 else { return false }
                harness.clipboard = text
                return true
            },
            readClipboard: { harness.clipboard },
            frontmostProcessID: { harness.frontmostPID },
            readFocusedFieldState: {
                FocusedFieldState(
                    value: harness.fieldValue,
                    selectedRange: harness.selectedRange,
                    role: harness.fieldRole,
                    processID: harness.focusedProcessID,
                    windowIdentity: harness.windowIdentity,
                    focusedElementIdentity: harness.focusedElementIdentity,
                    isIntrospectable: true
                )
            },
            activateTargetProcess: { _ in true },
            postPasteChord: { harness.pastePostCount += 1 },
            sleep: { _ in }
        )

        let outcome = await injector.injectText("hello", targetContext: harness.targetContext())

        #expect(outcome == .clipboardUnavailable)
    }

    @MainActor
    @Test func postTranscriptionStateMapsPasteUnconfirmed() {
        #expect(DictationCoordinator.postTranscriptionState(
            injectText: true,
            injectionOutcome: .pasteUnconfirmed
        ) == .pasteUnconfirmed)
    }

    @Test func pasteUnconfirmedCopyIsDuplicateSafeAndHonest() {
        let detail = DictationErrorState.pasteUnconfirmed.errorDescription ?? ""
        #expect(detail.localizedCaseInsensitiveContains("if the words are not visible"))
        #expect(detail.localizedCaseInsensitiveContains("Command-V"))
        #expect(detail.localizedCaseInsensitiveContains("clipboard"))
        #expect(!detail.localizedCaseInsensitiveContains("Accessibility access is off"))
        #expect(DictationRecoveryCopy.pasteUnconfirmedNextStep
            .localizedCaseInsensitiveContains("if the words are not visible"))
    }

    @Test func pasteDeliveryDiagnosticOmitsUserContent() {
        let log = DictationDebugLogCopy.pasteDeliveryDiagnostic(
            axTrusted: true,
            frontmostMatchesTarget: true,
            focusReresolvedMatchesTarget: true,
            postTap: "cghidEventTap",
            axRole: "AXTextArea",
            selectionLengthDelta: 3,
            outcome: "injected"
        )

        #expect(log.contains("ax_trusted=true"))
        #expect(log.contains("post_tap=cghidEventTap"))
        #expect(log.contains("outcome=injected"))
        #expect(!log.contains("secret transcript"))
    }
}
