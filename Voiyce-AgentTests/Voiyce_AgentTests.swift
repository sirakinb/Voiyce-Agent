//
//  Voiyce_AgentTests.swift
//  Voiyce-AgentTests
//

import AppKit
import Foundation
import ServiceManagement
import Speech
import Testing
@testable import Voiyce

struct Voiyce_AgentTests {
    @Test func permissionReturnRestoresSettingsPermissionsTab() throws {
        UserDefaults.standard.removeObject(forKey: "permissionReturnTab")
        UserDefaults.standard.removeObject(forKey: "permissionReturnSettingsTab")

        let appState = AppState()
        appState.selectedTab = .dashboard
        appState.selectedSettingsTab = 0

        appState.rememberPermissionReturnTarget(tab: .settings, settingsTab: 3)
        appState.selectedTab = .dashboard
        appState.selectedSettingsTab = 0
        appState.restorePermissionReturnTargetIfNeeded()

        #expect(appState.selectedTab == .settings)
        #expect(appState.selectedSettingsTab == 3)
        #expect(UserDefaults.standard.string(forKey: "permissionReturnTab") == nil)
        #expect(UserDefaults.standard.object(forKey: "permissionReturnSettingsTab") == nil)

        appState.selectedTab = .dashboard
        appState.selectedSettingsTab = 0
        appState.restorePermissionReturnTargetIfNeeded()

        #expect(appState.selectedTab == .dashboard)
        #expect(appState.selectedSettingsTab == 0)
    }

    @Test func permissionRefreshPollingStopsOnceDictationGranted() throws {
        #expect(!PermissionRefreshPolicy.shouldStopPolling(
            dictationPermissionsGranted: false
        ))
        #expect(PermissionRefreshPolicy.shouldStopPolling(
            dictationPermissionsGranted: true
        ))
    }

    @Test func dictationDoesNotReportSuccessWhenInsertionBlocked() throws {
        // Injection requested but blocked by Accessibility trust → recovery state,
        // never a silent success.
        #expect(DictationCoordinator.postTranscriptionState(
            injectText: true,
            injectionOutcome: .accessibilityDenied
        ) == .accessibilityInsertionBlocked)
        // Injection requested and performed → success (no error).
        #expect(DictationCoordinator.postTranscriptionState(
            injectText: true,
            injectionOutcome: .injected
        ) == nil)
        // Preview path keeps text inside Voiyce (inject disabled) → legitimate
        // success with no insertion attempt.
        #expect(DictationCoordinator.postTranscriptionState(
            injectText: false,
            injectionOutcome: nil
        ) == nil)
        // Clipboard publication failed entirely → distinct recovery state, not a
        // silent success and not the "words are on the clipboard" state.
        #expect(DictationCoordinator.postTranscriptionState(
            injectText: true,
            injectionOutcome: .clipboardUnavailable
        ) == .textInsertionFailed)
    }

    @MainActor
    @Test func textInjectorReportsClipboardUnavailableWhenTrustedButWriteFails() async throws {
        // Accessibility trusted, but the pasteboard write/readback fails: never
        // claim the paste happened — report the failed publication instead.
        let injector = TextInjector(
            isAccessibilityTrusted: { true },
            publishToClipboard: { _ in false }
        )
        #expect(await injector.injectText("trusted but clipboard broke") == .clipboardUnavailable)
    }

    @MainActor
    @Test func textInjectorReportsClipboardUnavailableWhenUntrustedAndWriteFails() async throws {
        // Accessibility off AND the clipboard fallback write fails: the words are
        // neither inserted nor on the clipboard, so do not claim they are.
        let injector = TextInjector(
            isAccessibilityTrusted: { false },
            publishToClipboard: { _ in false }
        )
        #expect(await injector.injectText("untrusted and clipboard broke") == .clipboardUnavailable)
    }

    @MainActor
    @Test func duplicateSuppressionCannotMaskAFailedPublication() async throws {
        // A failed publish must not be recorded for duplicate suppression;
        // repeating the identical paste must fail again, never replay as success.
        let injector = TextInjector(
            isAccessibilityTrusted: { true },
            publishToClipboard: { _ in false }
        )
        #expect(await injector.injectText("same words") == .clipboardUnavailable)
        #expect(await injector.injectText("same words") == .clipboardUnavailable)
    }

    @MainActor
    @Test func copyLastTranscriptRecoversFromInsertionFailure() throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let coordinator = DictationCoordinator()
        coordinator.latestTranscript = "recover these dictated words"
        coordinator.errorState = .textInsertionFailed

        let didCopy = coordinator.copyLastTranscriptToClipboard()
        #expect(didCopy)
        // Verified write clears the failure state and the words are on the clipboard.
        #expect(coordinator.errorState == nil)
        #expect(pasteboard.string(forType: .string) == "recover these dictated words")

        // Nothing to recover when there is no transcript.
        let empty = DictationCoordinator()
        empty.latestTranscript = ""
        #expect(!empty.copyLastTranscriptToClipboard())
    }

    @Test func textInsertionFailedCopyDoesNotClaimClipboardAndOffersRecovery() throws {
        let detail = DictationErrorState.textInsertionFailed.errorDescription ?? ""
        // Must NOT claim the words are on the clipboard — they aren't in this state.
        #expect(!detail.localizedCaseInsensitiveContains("on the clipboard"))
        // Words are preserved and a retry-copy path is offered.
        #expect(detail.localizedCaseInsensitiveContains("History"))
        #expect(DictationRecoveryCopy.textInsertionFailedNextStep
            .localizedCaseInsensitiveContains("Copy Transcript"))
        #expect(DictationRecoveryCopy.textInsertionFailedNextStep
            .localizedCaseInsensitiveContains("Command-V"))
    }

    @MainActor
    @Test func textInjectorReportsAccessibilityDeniedAndKeepsWordsOnClipboard() async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("prior-clipboard", forType: .string)

        let injector = TextInjector(isAccessibilityTrusted: { false })
        let outcome = await injector.injectText("keep these dictated words")

        #expect(outcome == .accessibilityDenied)
        // The transcript stays on the clipboard so the user can paste it manually.
        #expect(pasteboard.string(forType: .string) == "keep these dictated words")
    }

    @MainActor
    @Test func textInjectorReportsInjectedWhenAccessibilityTrustedAndConfirmed() async throws {
        var clipboardContents: String?
        var fieldValue = ""
        let injector = TextInjector(
            isAccessibilityTrusted: { true },
            publishToClipboard: { text in
                clipboardContents = text
                return true
            },
            readClipboard: { clipboardContents },
            frontmostProcessID: { 100 },
            readFocusedFieldState: {
                FocusedFieldState(
                    value: fieldValue,
                    selectedRange: TextSelectionRange(location: fieldValue.count, length: 0),
                    role: "AXTextField",
                    processID: 100,
                    windowIdentity: "AXWindow|0,0,800,600",
                    focusedElementIdentity: "AXTextField|10,20,300,24",
                    isIntrospectable: true
                )
            },
            activateTargetProcess: { _ in true },
            postPasteChord: {
                fieldValue = "trusted insertion path"
            },
            sleep: { _ in }
        )

        #expect(await injector.injectText("trusted insertion path") == .injected)
        #expect(clipboardContents == "trusted insertion path")
        #expect(fieldValue == "trusted insertion path")
    }

    @Test func accessibilityInsertionBlockedCopyPreservesWordsAndRoutesToSettings() throws {
        let detail = DictationErrorState.accessibilityInsertionBlocked.errorDescription ?? ""
        #expect(detail.localizedCaseInsensitiveContains("clipboard"))
        #expect(detail.localizedCaseInsensitiveContains("Command-V"))
        #expect(DictationRecoveryCopy.accessibilityInsertionBlockedNextStep
            .localizedCaseInsensitiveContains("Accessibility"))
        #expect(DictationErrorState.accessibilityInsertionBlocked.title
            .localizedCaseInsensitiveContains("Accessibility"))
    }

    @Test func speechRecognitionRoutingPromptsOnlyWhenUndetermined() throws {
        // notDetermined is the only state where the system will show its dialog.
        #expect(SpeechRecognitionRequestPolicy.action(for: .notDetermined) == .prompt)
        // Already granted: no dialog, no Settings trip.
        #expect(SpeechRecognitionRequestPolicy.action(for: .authorized) == .alreadyAuthorized)
        // Determined-but-not-granted: re-requesting is a silent no-op, so route
        // the user to System Settings instead of appearing to "do nothing".
        #expect(SpeechRecognitionRequestPolicy.action(for: .denied) == .openSettings)
        #expect(SpeechRecognitionRequestPolicy.action(for: .restricted) == .openSettings)
    }

    @Test func launchAtLoginStateMapsFromServiceStatus() throws {
        // A registered login item reads as on — both `.enabled` and
        // `.requiresApproval` (registered, pending user approval) count.
        #expect(LaunchAtLoginStatePolicy.isEnabled(for: .enabled))
        #expect(LaunchAtLoginStatePolicy.isEnabled(for: .requiresApproval))
        // Not-registered states read as off.
        #expect(!LaunchAtLoginStatePolicy.isEnabled(for: .notRegistered))
        #expect(!LaunchAtLoginStatePolicy.isEnabled(for: .notFound))

        // `.requiresApproval` is the one state that must surface the approval hint.
        #expect(LaunchAtLoginStatePolicy.needsApproval(for: .requiresApproval))
        #expect(!LaunchAtLoginStatePolicy.needsApproval(for: .enabled))
        #expect(!LaunchAtLoginStatePolicy.needsApproval(for: .notRegistered))
        #expect(!LaunchAtLoginStatePolicy.needsApproval(for: .notFound))
    }

    @Test func launchAtLoginTogglesRegisterWithoutDoubleRegistering() throws {
        // Enabling from an unregistered state registers once; the fake lands in
        // `.requiresApproval` (the common real-world outcome), which reads on.
        let service = FakeLoginItemService(status: .notRegistered, registerResult: .requiresApproval)
        let manager = LaunchAtLoginManager(service: service)
        #expect(!manager.isEnabled)

        manager.setEnabled(true)
        #expect(service.registerCount == 1)
        #expect(manager.isEnabled)        // registered → on
        #expect(manager.needsApproval)    // pending approval → subtitle hint
        #expect(manager.errorMessage == nil)

        // Tapping on again while `.requiresApproval` must NOT re-register (that
        // is what previously threw kSMErrorAlreadyRegistered).
        manager.setEnabled(true)
        #expect(service.registerCount == 1)
        #expect(manager.isEnabled)

        // Turning off from `.requiresApproval` must unregister.
        manager.setEnabled(false)
        #expect(service.unregisterCount == 1)
        #expect(!manager.isEnabled)
        #expect(!manager.needsApproval)
    }

    @Test func launchAtLoginSurfacesRegistrationErrors() throws {
        let service = FakeLoginItemService(status: .notRegistered, registerError: FakeLoginItemError.boom)
        let manager = LaunchAtLoginManager(service: service)

        manager.setEnabled(true)
        #expect(service.registerCount == 1)
        #expect(manager.errorMessage != nil)
        #expect(!manager.isEnabled) // stayed unregistered after the failed register
    }

    @Test func accessStateRecoveryCopyTellsUsersWhatToDoNext() throws {
        #expect(AccessState.signedOut.recoveryStep.contains("Sign in again"))
        #expect(AccessState.paymentRequired.recoveryStep.contains("Pentridge Labs"))
        #expect(AccessState.signedOut.recoveryStep.contains("restart"))
        #expect(AccessState.paymentRequired.recoveryStep.contains("restart"))
        #expect(!AccessState.signedOut.recoveryStep.localizedCaseInsensitiveContains("backend"))
        #expect(!AccessState.paymentRequired.recoveryStep.localizedCaseInsensitiveContains("server"))
    }

    @Test func onboardingPermissionCopyExplainsAccessInPlainLanguage() throws {
        let forbiddenTerms = [
            "Open" + "AI",
            "OPEN" + "AI_API_KEY",
            "backend",
            "Computer Use",
            "provider",
            "API",
            "model",
            "TCC",
            "SFSpeech",
            "AXIsProcessTrusted",
            "entitlement",
            "server-side",
            "authorization"
        ]

        for copy in OnboardingPermissionCopy.allPlainLanguageStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(OnboardingPermissionCopy.microphoneDescription.localizedCaseInsensitiveContains("hear your voice"))
        #expect(OnboardingPermissionCopy.speechRecognitionDescription.localizedCaseInsensitiveContains("turn speech into text"))
        #expect(OnboardingPermissionCopy.speechRecognitionMissingDetail.localizedCaseInsensitiveContains("Speech Recognition access"))
        #expect(OnboardingPermissionCopy.accessibilityGrantedDescription.localizedCaseInsensitiveContains("place finished text"))
        #expect(OnboardingPermissionCopy.requiredAccessNextStep.localizedCaseInsensitiveContains("Continue unlocks"))
    }

    @Test func onboardingLaunchCopyStaysDictationPositioned() throws {
        let forbiddenTerms = [
            "boost productivity",
            "revolutionize",
            "unlock your potential",
            "AI-powered",
            "seamless experience",
            "backend",
            "provider",
            "API",
            "tool call",
            "Computer Use",
            "SDP",
            "VideoDB",
            "Realtime",
            // Voiyce is a dictation-only Pentridge product: no agent-era positioning.
            "Context, Talk",
            "handoff",
            "Agent Log",
            "memory layer",
            "screen context",
            "Codex",
            "Claude Code",
            "agent"
        ]

        for copy in OnboardingLaunchCopy.visibleStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        // Positioned around dictation: speak, and text lands in your app.
        #expect(OnboardingLaunchCopy.overviewHeadline.localizedCaseInsensitiveContains("speech"))
        #expect(OnboardingLaunchCopy.overviewBody.localizedCaseInsensitiveContains("text"))
        #expect(OnboardingLaunchCopy.previewBody.localizedCaseInsensitiveContains("Voiyce"))
        #expect(OnboardingLaunchCopy.learnBodyWithPreview.localizedCaseInsensitiveContains("words"))
    }

    @MainActor
    @Test func pentridgeSuiteCopyIsAccurate() throws {
        // Voiyce ships as part of the Pentridge product suite — not an independent platform.
        #expect(SettingsLaunchCopy.productSuiteAttribution.localizedCaseInsensitiveContains("Pentridge"))
        #expect(!SettingsLaunchCopy.productSuiteAttribution.localizedCaseInsensitiveContains("Independent"))

        // The purchase prompt must route to Pentridge Labs without promising "unlimited"
        // usage — the Pentridge Standard tier is capped at 10,000 words/month.
        let paymentDetail = BillingManager().paymentRequiredDetail
        #expect(paymentDetail.localizedCaseInsensitiveContains("Pentridge"))
        #expect(!paymentDetail.localizedCaseInsensitiveContains("unlimited"))
    }

    @Test func menuBarLaunchCopyStaysUserFacing() throws {
        let forbiddenTerms = [
            "Open" + "AI",
            "backend",
            "Computer Use",
            "VideoDB",
            "Realtime",
            "SDP",
            "tool call"
        ]

        for copy in MenuBarLaunchCopy.visibleStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(MenuBarLaunchCopy.signedOutPrompt == "Open Voiyce to sign in")
        #expect(MenuBarLaunchCopy.dashboard == "Dashboard")
        #expect(MenuBarLaunchCopy.settings == "Settings")
        #expect(MenuBarLaunchCopy.focusTools == "Focus Tools")
        #expect(MenuBarLaunchCopy.quit == "Quit Voiyce")
    }

    @Test func demoVideoLaunchCopyStaysProductFacing() throws {
        let forbiddenTerms = [
            "Open" + "AI",
            "backend",
            "Computer Use",
            "VideoDB",
            "Realtime",
            "SDP",
            "tool call",
            "start dictating"
        ]

        for copy in DemoVideoLaunchCopy.visibleStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(DemoVideoLaunchCopy.title == "How to Use Voiyce")
        #expect(DemoVideoLaunchCopy.subtitle == "Watch this quick walkthrough before you start using Voiyce.")
        #expect(DemoVideoLaunchCopy.loadingFailure == "The walkthrough video could not be loaded. Close this window and try again.")
        #expect(DemoVideoLaunchCopy.loadingFailure.localizedCaseInsensitiveContains("try again"))
        #expect(DemoVideoLaunchCopy.done == "Done")
    }

    @Test func settingsLaunchCopyStaysSupportFacing() throws {
        let forbiddenTerms = [
            "Open" + "AI",
            "backend",
            "Computer Use",
            "VideoDB",
            "Realtime",
            "SDP",
            "tool call",
            "debugging",
            "debug"
        ]

        for copy in SettingsLaunchCopy.visibleStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(SettingsLaunchCopy.supportExportSubtitle.localizedCaseInsensitiveContains("support"))
        #expect(SettingsLaunchCopy.supportExportSubtitle.localizedCaseInsensitiveContains("redacted"))
        #expect(SettingsLaunchCopy.supportExportFailed.localizedCaseInsensitiveContains("redacted"))
        #expect(SettingsLaunchCopy.supportExportFailed.localizedCaseInsensitiveContains("support log"))
        #expect(SettingsLaunchCopy.supportExportedPrefix.localizedCaseInsensitiveContains("redacted"))
        #expect(SettingsLaunchCopy.supportExportedPrefix.localizedCaseInsensitiveContains("support log"))
    }

    @Test func launchSupportEmailStaysConsistentAcrossAppCopy() throws {
        #expect(AppConstants.supportEmail == "aki.b@pentridgemedia.com")
        #expect(BackendUsageLimitCopy.supportEmail == AppConstants.supportEmail)
        #expect(DictationRecoveryCopy.supportEmail == AppConstants.supportEmail)

        #expect(BackendUsageLimitCopy.nextStep.contains(AppConstants.supportEmail))
        #expect(DictationRecoveryCopy.serviceLimitNextStep.contains(AppConstants.supportEmail))
        #expect(DictationRecoveryCopy.serviceUnavailableNextStep.contains(AppConstants.supportEmail))
        #expect(DictationRecoveryCopy.serviceFailureNextStep.contains(AppConstants.supportEmail))
        #expect(DictationRecoveryCopy.previewTranscriptionFailedNextStep.contains(AppConstants.supportEmail))
        #expect(DictationRecoveryCopy.dashboardTranscriptionFailedNextStep.contains(AppConstants.supportEmail))
    }

    @Test func permissionStatusCopyReflectsGrantedAndDeniedStates() throws {
        #expect(SystemPermissionStatusCopy.description(
            for: .microphone,
            isGranted: false,
            surface: .settings
        ) == "Required for voice dictation.")
        #expect(SystemPermissionStatusCopy.description(
            for: .speechRecognition,
            isGranted: true,
            surface: .onboarding
        ) == OnboardingPermissionCopy.speechRecognitionDescription)

        #expect(SystemPermissionStatusCopy.description(
            for: .accessibility,
            isGranted: true,
            surface: .settings
        ).localizedCaseInsensitiveContains("On"))
        #expect(SystemPermissionStatusCopy.description(
            for: .accessibility,
            isGranted: false,
            surface: .settings
        ).contains("Privacy & Security > Accessibility"))
        #expect(SystemPermissionStatusCopy.description(
            for: .accessibility,
            isGranted: false,
            surface: .onboarding
        ) == OnboardingPermissionCopy.accessibilityMissingDescription)
    }

    @Test func backendUsageLimitDetectionIsNarrowAndUserFacing() throws {
        #expect(BackendUsageLimitCopy.isUsageLimit(statusCode: 402))
        #expect(BackendUsageLimitCopy.isUsageLimit(statusCode: 500, code: "usage_limit_reached"))
        #expect(BackendUsageLimitCopy.isUsageLimit(statusCode: 429, message: "Daily realtime usage cap reached for default tier"))
        #expect(BackendUsageLimitCopy.isUsageLimit(statusCode: nil, message: "This account has reached its current usage limit."))
        #expect(!BackendUsageLimitCopy.isUsageLimit(statusCode: 429, message: "database connection limit reached"))
        #expect(!BackendUsageLimitCopy.isUsageLimit(statusCode: 403, message: "Authorization denied"))
        #expect(!BackendUsageLimitCopy.detail.localizedCaseInsensitiveContains("backend"))
        #expect(!BackendUsageLimitCopy.detail.localizedCaseInsensitiveContains("server-side"))
        #expect(!BackendUsageLimitCopy.nextStep.localizedCaseInsensitiveContains("billing credits"))
    }

    @Test func dictationRecoveryCopyStaysUserFacing() throws {
        let userFacingStrings = [
            DictationRecoveryCopy.transcriptionServiceName,
            DictationErrorState.serviceQuotaExceeded("backend limit").title,
            DictationErrorState.serviceQuotaExceeded("backend limit").errorDescription ?? "",
            DictationRecoveryCopy.accountUsageLimitDetail,
            BackendUsageLimitCopy.nextStep,
            DictationRecoveryCopy.serviceLimitNextStep,
            DictationRecoveryCopy.serviceUnavailableDetail,
            DictationRecoveryCopy.serviceUnavailableNextStep,
            DictationErrorState.transcriptionFailed("raw provider failure").errorDescription ?? "",
            WhisperError.requestFailed("HTTP backend OPENAI_API_KEY token").errorDescription ?? "",
            WhisperError.apiError(500, "HTTP backend OPENAI_API_KEY token").errorDescription ?? "",
            DictationRecoveryCopy.networkUnavailableDetail,
            DictationRecoveryCopy.networkUnavailableNextStep,
            DictationRecoveryCopy.serviceFailureNextStep,
            DictationRecoveryCopy.previewTranscriptionFailedNextStep,
            DictationRecoveryCopy.dashboardTranscriptionFailedNextStep,
            DashboardRecoveryCopy.offlineDetail
        ]
        let forbiddenTerms = [
            "Open" + "AI",
            "OPEN" + "AI_API_KEY",
            "backend",
            "server transcription",
            "server-side",
            "transcribe-audio",
            "secret",
            "billing credits",
            "monthly budget",
            "model limits"
        ]

        for copy in userFacingStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }
        #expect(DictationRecoveryCopy.serviceLimitNextStep.contains(DictationRecoveryCopy.supportEmail))
        #expect(DictationRecoveryCopy.dashboardTranscriptionFailedNextStep.contains("hold Control again"))
    }

    @Test func dictationDebugLogsDoNotIncludeRawTranscriptText() throws {
        let transcript = "Ship the launch notes after reviewing the private customer thread"
        let wordCount = DictationDebugLogCopy.wordCount(in: transcript)
        let serviceLog = DictationDebugLogCopy.transcriptionCompleted(wordCount: wordCount)
        let insertionLog = DictationDebugLogCopy.transcriptReadyForInsertion(wordCount: wordCount)
        let failureLog = DictationDebugLogCopy.operationFailed("transcription")

        #expect(serviceLog.contains("10 words"))
        #expect(insertionLog.contains("10 words"))

        for log in [serviceLog, insertionLog, failureLog] {
            #expect(!log.contains(transcript))
            #expect(!log.localizedCaseInsensitiveContains("private customer thread"))
            #expect(!log.localizedCaseInsensitiveContains("Ship the launch notes"))
        }
    }

    @Test func offlineDictationFailureLogsSupportUsefulRecoveryEvent() throws {
        var loggedFailures: [(statusCode: Int?, message: String, nextStep: String?)] = []
        let mappedError = WhisperService.mappedError(for: URLError(.networkConnectionLost)) { statusCode, message, nextStep in
            loggedFailures.append((statusCode, message, nextStep))
        }

        guard case .noInternet = mappedError else {
            #expect(Bool(false), "Expected network loss to map to noInternet.")
            return
        }

        let loggedFailure = try #require(loggedFailures.first)
        #expect(loggedFailure.statusCode == nil)
        #expect(loggedFailure.message == DictationRecoveryCopy.networkUnavailableDetail)
        #expect(loggedFailure.nextStep == DictationRecoveryCopy.networkUnavailableNextStep)
    }

    @Test func dictationFallbackErrorsDoNotRetainProviderDetails() throws {
        let mappedError = WhisperService.mappedError(
            for: NSError(
                domain: "backend.OPENAI_API_KEY",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "HTTP 500 backend OPENAI_API_KEY token"]
            )
        )

        guard case .requestFailed(let message) = mappedError else {
            #expect(Bool(false), "Expected generic request failure.")
            return
        }

        let forbiddenTerms = [
            "Open" + "AI",
            "OPEN" + "AI_API_KEY",
            "backend",
            "server-side",
            "secret",
            "token",
            "localizedDescription"
        ]

        #expect(message == DictationRecoveryCopy.transcriptionFailedDetail)
        for forbiddenTerm in forbiddenTerms {
            #expect(!message.localizedCaseInsensitiveContains(forbiddenTerm))
            #expect(!(mappedError.errorDescription ?? "").localizedCaseInsensitiveContains(forbiddenTerm))
        }
    }

    @Test func authAndBillingRecoveryCopyDoNotExposeRawErrors() throws {
        let rawError = NSError(
            domain: "backend.OPENAI_API_KEY",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "HTTP 500 backend secret token"]
        )
        let userFacingStrings = [
            AuthenticationRecoveryCopy.message(for: rawError),
            AuthenticationRecoveryCopy.message(for: URLError(.networkConnectionLost)),
            SignInNetworkRecoveryCopy.loadingTitle,
            SignInNetworkRecoveryCopy.loadingDetail,
            SignInNetworkRecoveryCopy.authTitle,
            SignInNetworkRecoveryCopy.authDetail,
            SignInNetworkRecoveryCopy.authNextStep,
            BillingRecoveryCopy.message(for: rawError),
            BillingRecoveryCopy.message(for: URLError(.notConnectedToInternet)),
            BillingRecoveryCopy.checkoutLinkInvalid
        ]
        let forbiddenTerms = [
            "Open" + "AI",
            "OPEN" + "AI_API_KEY",
            "HTTP",
            "backend",
            "server",
            "InsForge",
            "token",
            "secret",
            "function",
            "database",
            "API"
        ]

        for copy in userFacingStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(AuthenticationRecoveryCopy.message(for: rawError).contains("try again"))
        #expect(SignInNetworkRecoveryCopy.authNextStep.contains("Reconnect"))
        #expect(BillingRecoveryCopy.message(for: rawError).contains("Try again"))
    }
}

private enum FakeLoginItemError: Error { case boom }

/// In-memory `LoginItemService` for exercising `LaunchAtLoginManager` state
/// transitions without touching the real login-item registration.
private final class FakeLoginItemService: LoginItemService {
    private(set) var status: SMAppService.Status
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    /// Status the fake moves to after a successful `register()`.
    private let registerResult: SMAppService.Status
    private let registerError: Error?

    init(
        status: SMAppService.Status,
        registerResult: SMAppService.Status = .enabled,
        registerError: Error? = nil
    ) {
        self.status = status
        self.registerResult = registerResult
        self.registerError = registerError
    }

    func register() throws {
        registerCount += 1
        if let registerError { throw registerError }
        status = registerResult
    }

    func unregister() throws {
        unregisterCount += 1
        status = .notRegistered
    }
}
