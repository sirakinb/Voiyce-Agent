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
    var fieldRole = "AXTextField"
    var introspectable = true
    var focusedProcessID: pid_t = 100
    var pastePostCount = 0
    var activateCallCount = 0
    var activateSucceeds = true
    var simulatePasteOnPost = true
    var activationRestoresFocus = true
    var sleeps: [Duration] = []

    func makeInjector() -> TextInjector {
        TextInjector(
            isAccessibilityTrusted: { [self] in axTrusted },
            publishToClipboard: { [self] text in
                clipboard = text
                return true
            },
            readClipboard: { [self] in clipboard },
            frontmostProcessID: { [self] in frontmostPID },
            readFocusedFieldState: { [self] in
                FocusedFieldState(
                    value: introspectable ? fieldValue : nil,
                    selectedRange: introspectable ? selectedRange : nil,
                    role: fieldRole,
                    processID: focusedProcessID,
                    isIntrospectable: introspectable
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
                guard simulatePasteOnPost, introspectable else { return }
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
    @Test func confirmedAppendDelivery() async {
        let harness = TextInjectorTestHarness()
        harness.fieldValue = "Hello "
        harness.selectedRange = TextSelectionRange(location: 6, length: 0)

        let injector = harness.makeInjector()
        let target = PasteTargetContext(processID: 100, bundleIdentifier: "com.test", appName: "Test")
        let outcome = await injector.injectText("world", targetContext: target)

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
        let outcome = await injector.injectText("XYZ", targetContext: PasteTargetContext(processID: 100, bundleIdentifier: nil, appName: "Test"))

        #expect(outcome == .injected)
        #expect(harness.fieldValue == "aXYZef")
    }

    @MainActor
    @Test func selectionReplacementShrinkingLengthConfirms() async {
        let harness = TextInjectorTestHarness()
        harness.fieldValue = "abcdef"
        harness.selectedRange = TextSelectionRange(location: 0, length: 4)

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("z", targetContext: PasteTargetContext(processID: 100, bundleIdentifier: nil, appName: "Test"))

        #expect(outcome == .injected)
        #expect(harness.fieldValue == "zef")
    }

    @MainActor
    @Test func nonIntrospectableReturnsPasteUnconfirmedAndKeepsClipboard() async {
        let harness = TextInjectorTestHarness()
        harness.introspectable = false

        let injector = harness.makeInjector()
        let outcome = await injector.injectText("hello", targetContext: PasteTargetContext(processID: 100, bundleIdentifier: nil, appName: "Test"))

        #expect(outcome == .pasteUnconfirmed)
        #expect(harness.clipboard == "hello")
        #expect(harness.pastePostCount == 1)
    }

    @MainActor
    @Test func staleFocusTriggersReactivationPath() async {
        let harness = TextInjectorTestHarness()
        harness.frontmostPID = 200
        harness.focusedProcessID = 200
        harness.targetPID = 100

        let injector = harness.makeInjector()
        let outcome = await injector.injectText(
            "hello",
            targetContext: PasteTargetContext(processID: 100, bundleIdentifier: nil, appName: "Test")
        )

        #expect(outcome == .injected)
        #expect(harness.activateCallCount >= 1)
        #expect(harness.frontmostPID == 100)
    }

    @MainActor
    @Test func reactivationTimeoutReturnsPasteUnconfirmed() async {
        let harness = TextInjectorTestHarness()
        harness.frontmostPID = 200
        harness.focusedProcessID = 200
        harness.activationRestoresFocus = false

        let injector = harness.makeInjector()
        let outcome = await injector.injectText(
            "hello",
            targetContext: PasteTargetContext(processID: 100, bundleIdentifier: nil, appName: "Test")
        )

        #expect(outcome == .pasteUnconfirmed)
        #expect(harness.clipboard == "hello")
        #expect(harness.pastePostCount == 0)
    }

    @MainActor
    @Test func readableMismatchReturnsPasteUnconfirmed() async {
        let harness = TextInjectorTestHarness()
        harness.simulatePasteOnPost = false

        let injector = harness.makeInjector()
        let outcome = await injector.injectText(
            "hello",
            targetContext: PasteTargetContext(processID: 100, bundleIdentifier: nil, appName: "Test")
        )

        #expect(outcome == .pasteUnconfirmed)
        #expect(harness.clipboard == "hello")
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
