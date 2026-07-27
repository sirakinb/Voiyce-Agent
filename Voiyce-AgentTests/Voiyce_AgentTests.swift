//
//  Voiyce_AgentTests.swift
//  Voiyce-AgentTests
//

import AppKit
import Foundation
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
