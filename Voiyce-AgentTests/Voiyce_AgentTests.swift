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

    @Test func permissionReturnRestoresAgentScreen() throws {
        UserDefaults.standard.removeObject(forKey: "permissionReturnTab")
        UserDefaults.standard.removeObject(forKey: "permissionReturnSettingsTab")

        let appState = AppState()
        appState.selectedTab = .dashboard

        appState.rememberPermissionReturnTarget(tab: .agent)
        appState.selectedTab = .settings
        appState.restorePermissionReturnTargetIfNeeded()

        #expect(appState.selectedTab == .agent)
        #expect(UserDefaults.standard.string(forKey: "permissionReturnTab") == nil)

        appState.selectedTab = .dashboard
        appState.restorePermissionReturnTargetIfNeeded()

        #expect(appState.selectedTab == .dashboard)
    }

    @Test func permissionRefreshPollingIncludesScreenRecordingWhenRequired() throws {
        #expect(!PermissionRefreshPolicy.shouldStopPolling(
            dictationPermissionsGranted: false,
            screenRecordingGranted: true,
            includeScreenRecording: true
        ))
        #expect(!PermissionRefreshPolicy.shouldStopPolling(
            dictationPermissionsGranted: true,
            screenRecordingGranted: false,
            includeScreenRecording: true
        ))
        #expect(PermissionRefreshPolicy.shouldStopPolling(
            dictationPermissionsGranted: true,
            screenRecordingGranted: true,
            includeScreenRecording: true
        ))
        #expect(PermissionRefreshPolicy.shouldStopPolling(
            dictationPermissionsGranted: true,
            screenRecordingGranted: false,
            includeScreenRecording: false
        ))
    }

    @Test func agentModeCopyMatchesExpectedCapabilities() throws {
        #expect(AgentMode.off.summary.contains("No session memory"))
        #expect(AgentMode.off.summary.contains("Start Context, Talk, or Act"))
        #expect(!AgentMode.off.summary.localizedCaseInsensitiveContains("company"))
        #expect(AgentMode.context.summary.contains("No voice"))
        #expect(AgentMode.talk.summary.contains("Speak with Voiyce"))
        #expect(AgentMode.act.summary.contains("operate apps"))
        #expect(AgentMode.off.selfServeExplanation.contains("Nothing is listening"))
        #expect(AgentMode.context.selfServeExplanation.contains("private work timeline"))
        #expect(AgentMode.talk.selfServeExplanation.contains("voice plus context"))
        #expect(AgentMode.act.selfServeExplanation.contains("controlled app operation"))
        #expect(AgentMode.act.selfServeExplanation.contains("Confirmations"))
        #expect(AgentMode.context.selfServeControl.contains("Private Mode"))
        #expect(AgentMode.talk.selfServeControl.contains("tools confirm"))
        #expect(AgentMode.act.selfServeControl.contains("safety choice"))
        #expect(AgentMode.act.selfServeControl.contains("Accessibility"))
        #expect(AgentSafetyMode.strict.subtitle.contains("Confirm"))
        #expect(AgentSafetyMode.normal.subtitle.contains("sensitive actions"))
        #expect(AgentSafetyMode.unrestricted.subtitle.contains("full system deletion"))
    }

    @Test func agentModeRuntimeBoundariesAreExplicit() throws {
        #expect(!AgentMode.off.startsSessionContext)
        #expect(!AgentMode.off.startsRealtimeVoice)
        #expect(!AgentMode.off.enablesActions)

        #expect(AgentMode.context.startsSessionContext)
        #expect(!AgentMode.context.startsRealtimeVoice)
        #expect(!AgentMode.context.enablesActions)
        #expect(AgentMode.context.readyStatus == "Ready")
        #expect(AgentMode.context.status == "Keeping context")

        #expect(AgentMode.talk.startsSessionContext)
        #expect(AgentMode.talk.startsRealtimeVoice)
        #expect(!AgentMode.talk.enablesActions)

        #expect(AgentMode.act.startsSessionContext)
        #expect(AgentMode.act.startsRealtimeVoice)
        #expect(AgentMode.act.enablesActions)
    }

    @Test func agentCapabilityTierGatesModesAndStorage() throws {
        #expect(AgentCapabilityTier.defaultTier.supports(.context))
        #expect(AgentCapabilityTier.defaultTier.supports(.talk))
        #expect(!AgentCapabilityTier.defaultTier.supports(.act))
        #expect(AgentCapabilityTier.defaultTier.memoryStorageTier == .defaultTier)
        #expect(AgentCapabilityTier.defaultTier.contextCaptureProfile.contains("conservative"))
        #expect(!AgentCapabilityTier.defaultTier.contextCaptureProfile.localizedCaseInsensitiveContains("server"))

        #expect(AgentCapabilityTier.pro.supports(.act))
        #expect(AgentCapabilityTier.pro.memoryStorageTier == .pro)
        #expect(AgentCapabilityTier.pro.userFacingLimitSummary.contains("selected Act"))

        #expect(AgentCapabilityTier.power.supports(.act))
        #expect(AgentCapabilityTier.power.memoryStorageTier == .power)
        #expect(AgentCapabilityTier.power.userFacingLimitSummary.contains("long-running sessions"))
        #expect(!AgentCapabilityTier.power.contextCaptureProfile.localizedCaseInsensitiveContains("Computer Use"))
        #expect(!AgentCapabilityTier.power.userFacingLimitSummary.localizedCaseInsensitiveContains("Computer Use"))

        #expect(AgentCapabilityTier.fromBilling(
            hasActiveSubscription: false,
            hasBetaAccess: false,
            hasPentridgeSubscription: false,
            pentridgeTier: nil
        ) == .defaultTier)
        #expect(AgentCapabilityTier.fromBilling(
            hasActiveSubscription: true,
            hasBetaAccess: false,
            hasPentridgeSubscription: false,
            pentridgeTier: nil
        ) == .pro)
        #expect(AgentCapabilityTier.fromBilling(
            hasActiveSubscription: false,
            hasBetaAccess: true,
            hasPentridgeSubscription: false,
            pentridgeTier: nil
        ) == .pro)
        #expect(AgentCapabilityTier.fromBilling(
            hasActiveSubscription: false,
            hasBetaAccess: false,
            hasPentridgeSubscription: false,
            pentridgeTier: nil,
            hasTrialAccess: true
        ) == .pro)
        #expect(AgentCapabilityTier.fromBilling(
            hasActiveSubscription: false,
            hasBetaAccess: false,
            hasPentridgeSubscription: true,
            pentridgeTier: "power"
        ) == .power)
    }

    @Test @MainActor func appStateReconcilesUnsupportedPersistedAgentModeWithTier() throws {
        let originalMode = UserDefaults.standard.string(forKey: "agentMode")
        defer {
            if let originalMode {
                UserDefaults.standard.set(originalMode, forKey: "agentMode")
            } else {
                UserDefaults.standard.removeObject(forKey: "agentMode")
            }
        }

        let appState = AppState()
        appState.agentCapabilityTier = .defaultTier
        appState.agentMode = .act

        appState.enforceAgentCapabilityTier()

        #expect(appState.agentMode == .talk)
    }

    @Test func realtimeWebClientStopInvalidatesPendingConnectAndReleasesAudio() throws {
        #expect(realtimeHTML.contains("let connectionAttemptID = 0;"))
        #expect(realtimeHTML.contains("const attemptID = ++connectionAttemptID;"))
        #expect(realtimeHTML.contains("if (attemptID !== connectionAttemptID)"))
        #expect(realtimeHTML.contains("const peerConnection = new RTCPeerConnection();"))
        #expect(realtimeHTML.contains("handleConnectionState(peerConnection.connectionState, \"peer\")"))
        #expect(realtimeHTML.contains("releaseMediaStream(acquiredStream);"))
        #expect(realtimeHTML.contains("connectionAttemptID += 1;"))
        #expect(realtimeHTML.contains("releaseMediaStream(stream);"))
        #expect(realtimeHTML.contains("remoteAudio.srcObject = null;"))
    }

    @Test func realtimeWebClientConnectsMicrophonePeerAndRemoteAudioPath() throws {
        #expect(realtimeHTML.contains(#"<audio id="remoteAudio" autoplay></audio>"#))
        #expect(realtimeHTML.contains(#"navigator.mediaDevices.getUserMedia({ audio: true })"#))
        #expect(realtimeHTML.contains(#"emitTelemetry("microphone_ready")"#))
        #expect(realtimeHTML.contains(#"const peerConnection = new RTCPeerConnection();"#))
        #expect(realtimeHTML.contains(#"stream.getAudioTracks().forEach((track) => peerConnection.addTrack(track, stream));"#))
        #expect(realtimeHTML.contains(#"peerConnection.createOffer()"#))
        #expect(realtimeHTML.contains(#"fetch(`/realtime-session?mode=${encodeURIComponent(agentMode)}`"#))
        #expect(realtimeHTML.contains(#"headers: { "Content-Type": "application/sdp" }"#))
        #expect(realtimeHTML.contains(#"await peerConnection.setRemoteDescription({ type: "answer", sdp: answer });"#))
        #expect(realtimeHTML.contains(#"peerConnection.ontrack = (event) => { remoteAudio.srcObject = event.streams[0]; };"#))
        #expect(realtimeHTML.contains(#"emitTelemetry("audio_connection_ready")"#))
        #expect(realtimeHTML.contains(#"event.type === "response.audio.delta""#))
    }

    @Test func realtimeWebClientRegistersExpectedTalkTools() throws {
        let expectedToolNames = [
            "check_calendar",
            "read_calendar",
            "read_gmail",
            "open_app",
            "open_url",
            "draft_gmail",
            "insert_text",
            "inspect_screen",
            "inspect_focus_region",
            "request_screen_access",
            "videodb_memory_status",
            "search_session_memory",
            "summarize_session_memory",
            "search_long_term_memory",
            "summarize_long_term_memory",
            "save_long_term_memory"
        ]

        for toolName in expectedToolNames {
            #expect(realtimeHTML.contains("name: \"\(toolName)\""))
        }
        #expect(realtimeHTML.contains("Registered Gmail, Calendar, app, browser"))
        #expect(realtimeHTML.contains("screen, focus paint, tour guide"))
        #expect(realtimeHTML.contains("local memory, active-session context"))
    }

    @Test func realtimeWebClientSupportsConfirmationApproveCancelAndStop() throws {
        #expect(realtimeHTML.contains("result.needsConfirmation && result.confirmationID"))
        #expect(realtimeHTML.contains(#"confirm.textContent = "Confirm""#))
        #expect(realtimeHTML.contains(#"cancel.textContent = "Cancel""#))
        #expect(realtimeHTML.contains(#"stopSession.textContent = "Stop Session""#))
        #expect(realtimeHTML.contains(#"fetch("/agent-confirm""#))
        #expect(realtimeHTML.contains("approved: true"))
        #expect(realtimeHTML.contains("approved: false"))
        #expect(realtimeHTML.contains(#"decision: "stop_session""#))
        #expect(realtimeHTML.contains(#"name: "confirm_pending_action""#))
        #expect(realtimeHTML.contains(#"description: "Approve, cancel, or stop the session for a pending Voiyce confirmation after the user answers by voice."#))
        #expect(realtimeHTML.contains(#"decision: { type: "string", description: "approve, cancel, or stop_session." }"#))
    }

    @Test @MainActor func sessionContextCaptureScriptRecordsScreenMicrophoneAndSystemAudio() throws {
        let script = VideoDBAgentMemory.captureScriptForTesting

        #expect(script.contains(#"for permission in ("microphone", "screen_capture"):"#))
        #expect(script.contains(#"mic = getattr(getattr(channels, "mics", None), "default", None)"#))
        #expect(script.contains(#"display = getattr(displays, "primary", None) or getattr(displays, "default", None) if displays is not None else None"#))
        #expect(script.contains(#"system_audio = getattr(getattr(channels, "system_audio", None), "default", None)"#))
        #expect(script.contains(#"selected = [channel for channel in (mic, display, system_audio) if channel]"#))
        #expect(script.contains("channel.store = True"))
        #expect(script.contains("client.start_session("))
        #expect(script.contains("channels=selected"))
        #expect(script.contains("primary_video_channel_id=primary_id"))
        #expect(script.contains("async for ev in client.events():"))
    }

    @Test @MainActor func agentActivityStatusOnlyAppearsWhileRunning() throws {
        let appState = AppState()
        appState.agentMode = .context
        appState.isAgentRunning = false
        #expect(appState.agentActivityStatus == nil)

        appState.isAgentRunning = true
        #expect(appState.agentActivityStatus?.title == "Context active")
        #expect(appState.agentActivityStatus?.detail == "Keeping context")
        #expect(appState.agentActivityStatus?.symbol == AgentMode.context.symbol)

        appState.agentMode = .act
        #expect(appState.agentActivityStatus?.title == "Act active")
        #expect(appState.agentActivityStatus?.detail == "Working")
        #expect(appState.agentActivityStatus?.symbol == AgentMode.act.symbol)

        appState.agentMode = .off
        #expect(appState.agentActivityStatus == nil)
    }

    @Test @MainActor func actModeActivitySurvivesAgentLogAndSettingsNavigation() throws {
        let appState = AppState()
        appState.agentMode = .act
        appState.isAgentRunning = true
        appState.selectedTab = .agent

        appState.selectedTab = .agentLog
        #expect(appState.agentActivityStatus?.title == "Act active")
        #expect(appState.agentActivityStatus?.detail == "Working")
        #expect(appState.isAgentRunning)

        appState.selectedTab = .settings
        #expect(appState.agentActivityStatus?.title == "Act active")
        #expect(appState.agentActivityStatus?.symbol == AgentMode.act.symbol)
        #expect(appState.isAgentRunning)

        appState.selectedTab = .agent
        #expect(appState.agentActivityStatus?.title == "Act active")
    }

    @Test @MainActor func nativeActNavigationFromAgentLogAndSettingsPreservesActiveActState() async throws {
        let appState = AppState()
        appState.agentMode = .act
        appState.isAgentRunning = true
        appState.selectedTab = .agentLog

        let settingsResult = await NativeActExecutor.shared.openVoiyceSection("settings", appState: appState)
        #expect(settingsResult.ok)
        #expect(appState.selectedTab == .settings)
        #expect(appState.isAgentRunning)
        #expect(appState.agentActivityStatus?.title == "Act active")

        let agentLogResult = await NativeActExecutor.shared.openVoiyceSection("agent log", appState: appState)
        #expect(agentLogResult.ok)
        #expect(appState.selectedTab == .agentLog)
        #expect(appState.isAgentRunning)
        #expect(appState.agentActivityStatus?.detail == "Working")
    }

    @Test func agentPermissionRecoveryMatchesModeRequirements() throws {
        #expect(AgentPermissionRecovery.recovery(
            mode: .off,
            microphoneGranted: false,
            accessibilityGranted: false,
            screenRecordingGranted: false
        ) == nil)

        let contextScreenRecovery = try #require(AgentPermissionRecovery.recovery(
            mode: .context,
            microphoneGranted: true,
            accessibilityGranted: false,
            screenRecordingGranted: false
        ))
        #expect(contextScreenRecovery.permissionName == "Screen Recording")
        #expect(contextScreenRecovery.message == "Context needs Screen Recording permission before it can see the current screen.")
        #expect(contextScreenRecovery.nextStep.contains("quit and reopen Voiyce"))

        #expect(AgentPermissionRecovery.recovery(
            mode: .talk,
            microphoneGranted: true,
            accessibilityGranted: false,
            screenRecordingGranted: false
        ) == nil)

        let talkMicRecovery = try #require(AgentPermissionRecovery.recovery(
            mode: .talk,
            microphoneGranted: false,
            accessibilityGranted: true,
            screenRecordingGranted: true
        ))
        #expect(talkMicRecovery.permissionName == "Microphone")
        #expect(talkMicRecovery.message == "Talk needs Microphone permission before it can run.")

        let actAccessibilityRecovery = try #require(AgentPermissionRecovery.recovery(
            mode: .act,
            microphoneGranted: true,
            accessibilityGranted: false,
            screenRecordingGranted: true
        ))
        #expect(actAccessibilityRecovery.permissionName == "Accessibility")
        #expect(actAccessibilityRecovery.message == "Act needs Accessibility permission before it can click, type, or press keys.")

        let actScreenRecovery = try #require(AgentPermissionRecovery.recovery(
            mode: .act,
            microphoneGranted: true,
            accessibilityGranted: true,
            screenRecordingGranted: false
        ))
        #expect(actScreenRecovery.permissionName == "Screen Recording")
    }

    @Test func contextModeStartFailureDoesNotStayActive() throws {
        let failedContextResult = AgentToolResult(
            ok: false,
            message: "Live session context is paused by Private Mode.",
            data: ["next_step": "Turn off Private Mode, then start Context again."]
        )
        let failedTalkResult = AgentToolResult(
            ok: false,
            message: "Session context could not start.",
            data: ["next_step": "Try again."]
        )
        let runningContextResult = AgentToolResult(
            ok: true,
            message: "Session context is recording this Agent session.",
            data: nil
        )

        #expect(AgentSessionContextStartRecovery.shouldStopActiveAgent(mode: .context, result: failedContextResult))
        #expect(!AgentSessionContextStartRecovery.shouldStopActiveAgent(mode: .talk, result: failedTalkResult))
        #expect(!AgentSessionContextStartRecovery.shouldStopActiveAgent(mode: .act, result: failedTalkResult))
        #expect(!AgentSessionContextStartRecovery.shouldStopActiveAgent(mode: .context, result: runningContextResult))
        #expect(AgentSessionContextStartRecovery.nextStep(from: failedContextResult) == "Turn off Private Mode, then start Context again.")
        #expect(AgentSessionContextStartRecovery.nextStep(from: runningContextResult) == AgentSessionContextStartRecovery.defaultNextStep)
    }

    @Test @MainActor func appTerminationClearsTransientRuntimeState() throws {
        let appState = AppState()
        appState.recordingState = .processing
        appState.isDictationActive = true
        appState.currentTranscript = "do not keep active text"
        appState.agentMode = .act
        appState.isAgentRunning = true

        appState.clearTransientRuntimeStateForTermination()

        #expect(appState.recordingState == .idle)
        #expect(!appState.isDictationActive)
        #expect(appState.currentTranscript.isEmpty)
        #expect(!appState.isAgentRunning)
        #expect(appState.agentMode == .act)
    }

    @Test @MainActor func systemSleepClearsTransientRuntimeState() throws {
        let appState = AppState()
        appState.recordingState = .listening
        appState.isDictationActive = true
        appState.currentTranscript = "sleep should not keep active text"
        appState.agentMode = .context
        appState.isAgentRunning = true

        appState.clearTransientRuntimeStateForSystemSleep()

        #expect(appState.recordingState == .idle)
        #expect(!appState.isDictationActive)
        #expect(appState.currentTranscript.isEmpty)
        #expect(!appState.isAgentRunning)
        #expect(appState.agentMode == .context)
    }

    @Test @MainActor func accessLossClearsTransientRuntimeState() throws {
        let appState = AppState()
        appState.recordingState = .processing
        appState.isDictationActive = true
        appState.currentTranscript = "access loss should not keep active text"
        appState.agentMode = .act
        appState.isAgentRunning = true

        appState.clearTransientRuntimeStateForAccessLoss()

        #expect(appState.recordingState == .idle)
        #expect(!appState.isDictationActive)
        #expect(appState.currentTranscript.isEmpty)
        #expect(!appState.isAgentRunning)
        #expect(appState.agentMode == .act)
    }

    @Test func accessStateRecoveryCopyTellsUsersWhatToDoNext() throws {
        #expect(AccessState.signedOut.recoveryStep.contains("Sign in again"))
        #expect(AccessState.paymentRequired.recoveryStep.contains("Choose a plan"))
        #expect(AccessState.signedOut.recoveryStep.contains("restart"))
        #expect(AccessState.paymentRequired.recoveryStep.contains("restart"))
        #expect(!AccessState.signedOut.recoveryStep.localizedCaseInsensitiveContains("backend"))
        #expect(!AccessState.paymentRequired.recoveryStep.localizedCaseInsensitiveContains("server"))
    }

    @Test @MainActor func appTerminationStopsLocalSessionContextCapture() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-termination-context-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let eventStore = AgentEventStore(
            storageDirectory: directory.appendingPathComponent("AgentEvents", isDirectory: true)
        )
        let memory = VideoDBAgentMemory()
        memory.seedRunningSessionForTesting(sessionID: "termination-session", eventStore: eventStore)

        memory.stopLocalCaptureForTermination(eventStore: eventStore)

        #expect(!memory.isRunning)
        #expect(memory.sessionID == nil)
        #expect(memory.lastEvent == "Session context stopped because Voiyce quit.")
        #expect(eventStore.events.contains { event in
            event.title == "Session context capture stopped"
                && event.details.contains { $0.key == "Session" && $0.value == "termination-session" }
        })
    }

    @Test @MainActor func systemSleepStopsLocalSessionContextCapture() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-sleep-context-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let eventStore = AgentEventStore(
            storageDirectory: directory.appendingPathComponent("AgentEvents", isDirectory: true)
        )
        let memory = VideoDBAgentMemory()
        memory.seedRunningSessionForTesting(sessionID: "sleep-session", eventStore: eventStore)

        memory.stopLocalCaptureForSystemSleep(eventStore: eventStore)

        #expect(!memory.isRunning)
        #expect(memory.sessionID == nil)
        #expect(memory.lastEvent == "Session context stopped because the Mac went to sleep.")
        #expect(eventStore.events.contains { event in
            event.title == "Session context capture stopped"
                && event.details.contains { $0.key == "Session" && $0.value == "sleep-session" }
        })
    }

    @Test @MainActor func userStopEndsLocalSessionContextCaptureBeforeSummary() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-user-stop-context-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let eventStore = AgentEventStore(
            storageDirectory: directory.appendingPathComponent("AgentEvents", isDirectory: true)
        )
        let memory = VideoDBAgentMemory()
        memory.seedRunningSessionForTesting(
            sessionID: "user-stop-session",
            displayStreamID: "display-stream",
            micStreamID: "mic-stream",
            sceneIndexID: "scene-index",
            eventStore: eventStore
        )

        memory.stopLocalCaptureForUserStop(eventStore: eventStore)

        #expect(!memory.isRunning)
        #expect(memory.sessionID == "user-stop-session")
        #expect(memory.displayStreamID == "display-stream")
        #expect(memory.micStreamID == "mic-stream")
        #expect(memory.sceneIndexID == "scene-index")
        #expect(memory.lastEvent == "Session context capture stopped. Preparing the session summary...")
        #expect(eventStore.events.contains { event in
            event.title == "Session context capture stopped"
                && event.details.contains { $0.key == "Session" && $0.value == "user-stop-session" }
        })
    }

    @Test func displayConfigurationRecoveryStopsOnlyActiveActMode() throws {
        #expect(!DisplayConfigurationRecovery.shouldStopAgent(mode: .off, isAgentRunning: false))
        #expect(!DisplayConfigurationRecovery.shouldStopAgent(mode: .context, isAgentRunning: true))
        #expect(!DisplayConfigurationRecovery.shouldStopAgent(mode: .talk, isAgentRunning: true))
        #expect(!DisplayConfigurationRecovery.shouldStopAgent(mode: .act, isAgentRunning: false))
        #expect(DisplayConfigurationRecovery.shouldStopAgent(mode: .act, isAgentRunning: true))
        #expect(DisplayConfigurationRecovery.actStopSummary.localizedCaseInsensitiveContains("display layout changed"))
        #expect(DisplayConfigurationRecovery.actStopNextStep.localizedCaseInsensitiveContains("start Act again"))
    }

    @Test @MainActor func displayConfigurationChangeClearsSavedFocusRegion() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-display-change-focus-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let eventStore = AgentEventStore(
            storageDirectory: directory.appendingPathComponent("AgentEvents", isDirectory: true)
        )
        let annotation = FocusMarkAnnotation(
            mode: .rectangle,
            screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            region: CGRect(x: 120, y: 160, width: 320, height: 220),
            points: []
        )

        FocusHighlightOverlay.shared.completeSelection(annotation, eventStore: eventStore, showGuide: false)
        #expect(FocusHighlightOverlay.shared.lastRegion == annotation.region)

        FocusHighlightOverlay.shared.clearForDisplayConfigurationChange(eventStore: eventStore)

        #expect(FocusHighlightOverlay.shared.lastRegion == nil)
        #expect(FocusHighlightOverlay.shared.lastAnnotation == nil)
        #expect(eventStore.events.contains { event in
            event.title == "Focus region cleared after display change"
                && event.status == .cancelled
        })
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
        #expect(OnboardingPermissionCopy.screenRecordingGrantedDescription.localizedCaseInsensitiveContains("understand what is on your screen"))
        #expect(OnboardingPermissionCopy.requiredAccessNextStep.localizedCaseInsensitiveContains("Continue unlocks"))
        #expect(OnboardingPermissionCopy.agentScreenAccessMessage.localizedCaseInsensitiveContains("Dictation can continue"))
    }

    @Test func onboardingLaunchCopyStaysAgentContextPositioned() throws {
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
            "Realtime"
        ]

        for copy in OnboardingLaunchCopy.visibleStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(OnboardingLaunchCopy.overviewHeadline.localizedCaseInsensitiveContains("memory layer"))
        #expect(OnboardingLaunchCopy.overviewBody.localizedCaseInsensitiveContains("Context"))
        #expect(OnboardingLaunchCopy.overviewBody.localizedCaseInsensitiveContains("Talk"))
        #expect(OnboardingLaunchCopy.overviewBody.localizedCaseInsensitiveContains("Act"))
        #expect(OnboardingLaunchCopy.handoffDetail.localizedCaseInsensitiveContains("Codex"))
        #expect(OnboardingLaunchCopy.handoffDetail.localizedCaseInsensitiveContains("Claude Code"))
        #expect(OnboardingLaunchCopy.learnBodyWithPreview.localizedCaseInsensitiveContains("repeated explanations"))
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

    @Test func appMenuLaunchCopyStaysUserFacing() throws {
        let forbiddenTerms = [
            "Open" + "AI",
            "backend",
            "Computer Use",
            "VideoDB",
            "Realtime",
            "SDP",
            "tool call"
        ]

        for copy in AppMenuLaunchCopy.visibleStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(AppMenuLaunchCopy.openDashboard == "Open Dashboard")
        #expect(AppMenuLaunchCopy.openAgent == "Open Agent")
        #expect(AppMenuLaunchCopy.openAgentLog == "Open Agent Log")
        #expect(AppMenuLaunchCopy.openSettings == "Open Settings")
        #expect(AppMenuLaunchCopy.focusTools == "Focus Tools")
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

    @Test func agentLogLaunchCopyStaysSupportFacing() throws {
        let forbiddenTerms = [
            "Open" + "AI",
            "backend",
            "Computer Use",
            "VideoDB",
            "Realtime",
            "SDP",
            "tool call",
            "debugging",
            "debug",
            "Investigate",
            "Errors"
        ]

        for copy in AgentLogLaunchCopy.visibleStrings + [AgentLogCategory.errors.title] {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(AgentLogCategory.errors.title == "Issues")
        #expect(AgentLogLaunchCopy.supportExportTitle.localizedCaseInsensitiveContains("redacted"))
        #expect(AgentLogLaunchCopy.actionDetailsMessage.localizedCaseInsensitiveContains("recovery steps"))
        #expect(AgentLogLaunchCopy.emptyLogMessage.localizedCaseInsensitiveContains("issues"))
        #expect(AgentLogLaunchCopy.emptySearchMessage.localizedCaseInsensitiveContains("next-step"))
    }

    @Test func agentRuntimeLaunchCopyStaysRecoveryOriented() throws {
        let forbiddenTerms = [
            "Open" + "AI",
            "backend",
            "Computer Use",
            "VideoDB",
            "Realtime",
            "SDP",
            "tool call",
            "debugging",
            "debug",
            "Error"
        ]

        for copy in AgentRuntimeLaunchCopy.visibleStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(AgentRuntimeLaunchCopy.sessionContextFailedStatus == "Needs review")
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
        let blockedScreenMessage = "Screen Recording is blocked for this exact Voiyce build."

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

        #expect(SystemPermissionStatusCopy.description(
            for: .screenRecording,
            isGranted: true,
            surface: .settings
        ).localizedCaseInsensitiveContains("On"))
        #expect(SystemPermissionStatusCopy.description(
            for: .screenRecording,
            isGranted: false,
            screenRecordingStatusMessage: blockedScreenMessage,
            surface: .settings
        ) == blockedScreenMessage)
        #expect(SystemPermissionStatusCopy.description(
            for: .screenRecording,
            isGranted: false,
            surface: .onboarding
        ) == OnboardingPermissionCopy.screenRecordingMissingDescription)
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

    @Test @MainActor func dictationServiceFailuresStayUserFacingInAgentLog() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-dictation-service-failure-log-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        store.appendServiceFailure(
            feature: "Dictation",
            service: DictationRecoveryCopy.transcriptionServiceName,
            statusCode: 500,
            message: DictationRecoveryCopy.serviceUnavailableDetail,
            nextStep: DictationRecoveryCopy.serviceUnavailableNextStep
        )

        let event = try #require(store.events.first)
        let exportURL = try #require(store.exportSupportBundle())
        let exported = try String(contentsOf: exportURL, encoding: .utf8)
        let forbiddenTerms = [
            "Open" + "AI",
            "OPEN" + "AI_API_KEY",
            "backend",
            "server-side",
            "transcribe-audio",
            "billing credits",
            "monthly budget",
            "model limits"
        ]

        #expect(event.title == "\(DictationRecoveryCopy.transcriptionServiceName) failed")
        #expect(event.summary.contains("Dictation"))
        #expect(event.summary.contains(DictationRecoveryCopy.serviceUnavailableDetail))
        #expect(event.details.contains { $0.key == "Service" && $0.value == DictationRecoveryCopy.transcriptionServiceName })
        #expect(event.details.contains { $0.key == "Next step" && $0.value.contains("Try again later") })
        #expect(!exported.contains(DictationRecoveryCopy.supportEmail))

        for forbiddenTerm in forbiddenTerms {
            #expect(!exported.localizedCaseInsensitiveContains(forbiddenTerm))
        }
    }

    @Test func actModeRecoveryCopyStaysUserFacing() throws {
        let userFacingStrings = [
            ActModeRecoveryCopy.taskRequired,
            ActModeRecoveryCopy.taskRequiredNextStep,
            ActModeRecoveryCopy.authenticationRequired,
            ActModeRecoveryCopy.authenticationNextStep,
            ActModeRecoveryCopy.accessibilityPermissionRequired,
            ActModeRecoveryCopy.accessibilityNextStep,
            ActModeRecoveryCopy.screenRecordingPermissionRequired,
            ActModeRecoveryCopy.screenRecordingNextStep,
            ActModeRecoveryCopy.finishedWithoutActions,
            ActModeRecoveryCopy.confirmationRequired,
            ActModeRecoveryCopy.safetyCheckNextStep,
            ActModeRecoveryCopy.safetyCheckCannotResume("The action may send data externally."),
            ActModeRecoveryCopy.noLocalActions,
            ActModeRecoveryCopy.screenCaptureAfterActionFailed,
            ActModeRecoveryCopy.screenCaptureAfterActionFailedNextStep,
            ActModeRecoveryCopy.invalidActionNextStep,
            ActModeRecoveryCopy.textTargetNotSafe,
            ActModeRecoveryCopy.textTargetNotSafeNextStep,
            ActModeRecoveryCopy.invalidResponse,
            ActModeRecoveryCopy.accountUsageLimit,
            ActModeRecoveryCopy.unexpectedFailure,
            ActModeRecoveryCopy.unexpectedFailureNextStep,
            ActModeRecoveryCopy.unexpectedFailureMessage(
                for: NSError(
                    domain: "backend.OPENAI_API_KEY",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP 500 backend OPENAI_API_KEY"]
                )
            ),
            ActModeRecoveryCopy.stoppedAfterMaxSteps(6),
            ActModeRecoveryCopy.requestFailed(statusCode: 402),
            ActModeRecoveryCopy.requestFailed(statusCode: 429),
            ActModeRecoveryCopy.requestFailed(statusCode: 500),
            ActModeRecoveryCopy.serviceFailureNextStep(statusCode: 402),
            ActModeRecoveryCopy.serviceFailureNextStep(statusCode: 429),
            ActModeRecoveryCopy.serviceFailureNextStep(statusCode: 500)
        ]
        let forbiddenTerms = [
            "Open" + "AI",
            "OPEN" + "AI_API_KEY",
            "Computer Use",
            "backend",
            "server-side",
            "computer-use-step",
            "billing credits",
            "monthly budget",
            "model limits"
        ]

        for copy in userFacingStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }
        #expect(ActModeRecoveryCopy.requestFailed(statusCode: 402) == ActModeRecoveryCopy.accountUsageLimit)
        #expect(ActModeRecoveryCopy.requestFailed(statusCode: 429).contains("rate-limited"))
        #expect(ActModeRecoveryCopy.serviceFailureNextStep(statusCode: 402).contains(BackendUsageLimitCopy.supportEmail))
        #expect(ActModeRecoveryCopy.serviceFailureNextStep(statusCode: 500).contains("Agent Log"))
        #expect(ActModeRecoveryCopy.safetyCheckCannotResume("").contains("Stop this run"))
        #expect(ActModeRecoveryCopy.unexpectedFailureMessage(for: NSError(
            domain: "backend.OPENAI_API_KEY",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "HTTP 500 backend OPENAI_API_KEY"]
        )) == ActModeRecoveryCopy.unexpectedFailure)
    }

    @Test @MainActor func actTextTargetSafetyRejectsBlindTextInsertion() throws {
        #expect(ActTextTargetSafety.evaluate(
            role: kAXTextFieldRole as String,
            subrole: nil,
            isValueSettable: false
        ).isSafe)
        #expect(ActTextTargetSafety.evaluate(
            role: kAXTextAreaRole as String,
            subrole: nil,
            isValueSettable: false
        ).isSafe)
        #expect(ActTextTargetSafety.evaluate(
            role: kAXButtonRole as String,
            subrole: nil,
            isValueSettable: false
        ) == ActTextTargetSafety.unsafe("focused_\((kAXButtonRole as String).lowercased())"))
        #expect(ActTextTargetSafety.evaluate(
            role: nil,
            subrole: nil,
            isValueSettable: false
        ) == ActTextTargetSafety.unsafe("unknown_focus"))
        #expect(ActTextTargetSafety.evaluate(
            role: kAXGroupRole as String,
            subrole: "AXSearchField",
            isValueSettable: false
        ).isSafe)
        #expect(ActTextTargetSafety.evaluate(
            role: kAXGroupRole as String,
            subrole: nil,
            isValueSettable: true
        ).isSafe)
        #expect(ActModeRecoveryCopy.textTargetNotSafe.contains("focused text field"))
        #expect(ActModeRecoveryCopy.textTargetNotSafeNextStep.contains("Click into the field"))
    }

    @Test func talkModeRecoveryCopyStaysUserFacing() throws {
        let userFacingStrings = [
            TalkModeRecoveryCopy.serviceName,
            TalkModeRecoveryCopy.authenticationRequired,
            TalkModeRecoveryCopy.microphonePermissionRequired,
            TalkModeRecoveryCopy.microphonePermissionNextStep,
            TalkModeRecoveryCopy.invalidAudioConnection,
            TalkModeRecoveryCopy.invalidResponse,
            TalkModeRecoveryCopy.connectionFailed,
            TalkModeRecoveryCopy.rateLimited,
            TalkModeRecoveryCopy.accountUsageLimit,
            TalkModeRecoveryCopy.requestFailed(statusCode: 402),
            TalkModeRecoveryCopy.requestFailed(statusCode: 429),
            TalkModeRecoveryCopy.requestFailed(statusCode: 500),
            TalkModeRecoveryCopy.displayMessage(
                upstreamStatus: nil,
                fallbackStatus: 402,
                message: #"{"code":"usage_limit_reached"}"#
            ),
            TalkModeRecoveryCopy.displayMessage(
                upstreamStatus: 500,
                fallbackStatus: nil,
                message: "OpenAI Realtime failed because OPENAI_API_KEY is missing from the backend"
            ),
            TalkModeRecoveryCopy.displayMessage(
                upstreamStatus: 429,
                fallbackStatus: nil,
                message: "exceeded your current quota"
            ),
            TalkModeRecoveryCopy.serviceFailureNextStep(statusCode: 402),
            TalkModeRecoveryCopy.serviceFailureNextStep(statusCode: 429),
            TalkModeRecoveryCopy.serviceFailureNextStep(statusCode: 500)
        ]
        let forbiddenTerms = [
            "Open" + "AI",
            "OPEN" + "AI_API_KEY",
            "Realtime",
            "backend",
            "server-side",
            "billing credits",
            "monthly budget",
            "model limits"
        ]

        for copy in userFacingStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }
        #expect(TalkModeRecoveryCopy.requestFailed(statusCode: 402) == TalkModeRecoveryCopy.accountUsageLimit)
        #expect(TalkModeRecoveryCopy.requestFailed(statusCode: 429).contains("rate-limited"))
        #expect(TalkModeRecoveryCopy.serviceFailureNextStep(statusCode: 402).contains(BackendUsageLimitCopy.supportEmail))
        #expect(TalkModeRecoveryCopy.serviceFailureNextStep(statusCode: 500).contains("Agent Log"))
        #expect(TalkModeRecoveryCopy.microphonePermissionRequired.contains("Microphone access is off"))
    }

    @Test func screenContextRecoveryCopyStaysUserFacing() throws {
        let userFacingStrings = [
            ScreenContextRecoveryCopy.serviceName,
            ScreenContextRecoveryCopy.accountUsageLimit,
            ScreenContextRecoveryCopy.displayMessage(
                statusCode: 402,
                code: nil,
                serverDisplayMessage: nil,
                errorMessage: "Daily context usage cap reached"
            ),
            ScreenContextRecoveryCopy.displayMessage(
                statusCode: 503,
                code: "capability_disabled",
                serverDisplayMessage: "Screen context is temporarily paused. Please try again later.",
                errorMessage: nil
            ),
            ScreenContextRecoveryCopy.displayMessage(
                statusCode: 500,
                code: nil,
                serverDisplayMessage: nil,
                errorMessage: "OPENAI_API_KEY missing from backend"
            ),
            ScreenContextRecoveryCopy.invalidResponse,
            ScreenContextRecoveryCopy.requestFailed,
            ScreenContextRecoveryCopy.serviceFailureNextStep(statusCode: 402),
            ScreenContextRecoveryCopy.serviceFailureNextStep(statusCode: 500)
        ]
        let forbiddenTerms = [
            "Open" + "AI",
            "OPEN" + "AI_API_KEY",
            "backend",
            "server-side",
            "screen-context",
            "billing credits",
            "monthly budget",
            "model limits"
        ]

        for copy in userFacingStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }
        #expect(ScreenContextRecoveryCopy.displayMessage(statusCode: 402, code: nil, serverDisplayMessage: nil, errorMessage: nil) == ScreenContextRecoveryCopy.accountUsageLimit)
        #expect(ScreenContextRecoveryCopy.serviceFailureNextStep(statusCode: 402).contains(BackendUsageLimitCopy.supportEmail))
        #expect(ScreenContextProvider.screenContextData()["memory_source"] == "current_screen")
        #expect(ScreenContextProvider.screenContextData()["context_scope"] == "current_screen")
    }

    @Test func googleWorkspaceRecoveryCopyStaysPlainAndActionable() throws {
        let userFacingStrings = [
            GoogleWorkspaceRecoveryCopy.notConfigured,
            GoogleWorkspaceRecoveryCopy.callbackFailurePage,
            GoogleWorkspaceRecoveryCopy.callbackSuccessPage,
            GoogleWorkspaceRecoveryCopy.message(for: GoogleWorkspaceError.invalidOAuthURL),
            GoogleWorkspaceRecoveryCopy.message(for: GoogleWorkspaceError.oauthCallbackUnavailable),
            GoogleWorkspaceRecoveryCopy.message(for: GoogleWorkspaceError.invalidOAuthState),
            GoogleWorkspaceRecoveryCopy.message(for: GoogleWorkspaceError.missingOAuthCode),
            GoogleWorkspaceRecoveryCopy.message(for: GoogleWorkspaceError.notConnected),
            GoogleWorkspaceRecoveryCopy.message(for: GoogleWorkspaceError.invalidToken),
            GoogleWorkspaceRecoveryCopy.message(for: GoogleWorkspaceError.invalidResponse),
            GoogleWorkspaceRecoveryCopy.message(for: GoogleWorkspaceError.apiError(500, "HTTP backend OPENAI_API_KEY token")),
            GoogleWorkspaceRecoveryCopy.message(for: URLError(.notConnectedToInternet)),
            GoogleWorkspaceRecoveryCopy.message(
                for: NSError(
                    domain: "backend.OPENAI_API_KEY",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Google API HTTP 500 secret token"]
                )
            )
        ]
        let forbiddenTerms = [
            "Open" + "AI",
            "OPEN" + "AI_API_KEY",
            "OAuth",
            "API",
            "HTTP",
            "backend",
            "server",
            "token",
            "secret"
        ]

        for copy in userFacingStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(GoogleWorkspaceRecoveryCopy.message(for: GoogleWorkspaceError.notConnected).contains("Settings"))
        #expect(GoogleWorkspaceRecoveryCopy.message(for: GoogleWorkspaceError.invalidToken).contains("connect it again"))
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

    @Test func billingLimitCopyExplainsAgentCapsPlainly() throws {
        let userFacingStrings = [
            BillingLimitCopy.settingsSummary,
            BillingLimitCopy.checkoutSummary
        ]
        let requiredTerms = ["Pro", "Context", "Talk", "Act", "beta budgets"]
        let forbiddenTerms = [
            "boost productivity",
            "revolutionize",
            "unlock your potential",
            "AI-powered",
            "unlimited agents",
            "unlimited Act"
        ]

        for copy in userFacingStrings {
            for term in requiredTerms {
                #expect(copy.localizedCaseInsensitiveContains(term))
            }

            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(BillingLimitCopy.checkoutSummary.contains("Power-level Act limits are not sold"))
    }

    @Test @MainActor func agentToolBridgeFailuresStayPlainAndSupportUseful() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-agent-tool-plain-error-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removeObject(forKey: "agentSafetyMode")
            UserDefaults.standard.removeObject(forKey: "agentSafetyModeConfirmed")
        }

        let store = AgentEventStore(storageDirectory: directory)
        let bridge = RealtimeAgentActionBridge(
            showsNativeConfirmations: false,
            confirmationTimeoutSeconds: 1,
            eventStore: store
        )
        GoogleWorkspaceManager.shared.disconnect()
        UserDefaults.standard.set(AgentSafetyMode.unrestricted.rawValue, forKey: "agentSafetyMode")
        UserDefaults.standard.set(true, forKey: "agentSafetyModeConfirmed")
        let invalidRequest = await bridge.handle(Data("{".utf8))
        let unknownTool = await bridge.handle(Data(#"{"name":"unavailable_tool","arguments":{}}"#.utf8))
        let missingOpenApp = await bridge.handle(Data(#"{"name":"open_app","arguments":{}}"#.utf8))
        let disconnectedGoogle = await bridge.handle(Data(#"{"name":"send_gmail","arguments":{"recipient":"aki@example.com","subject":"Launch","body":"Ready"}}"#.utf8))
        let invalidConfirmation = await bridge.confirm(Data("{".utf8))
        let missingConfirmationID = await bridge.handle(Data(#"{"name":"confirm_pending_action","arguments":{}}"#.utf8))
        let missingMemorySummary = AgentLongTermMemoryStore(
            storageDirectory: directory.appendingPathComponent("Memory", isDirectory: true),
            userDefaults: UserDefaults.standard,
            createVaultOnInit: false,
            eventStore: store
        ).addRecord(source: "test", summary: "   ")
        let exported = try String(contentsOf: try #require(store.exportSupportBundle()), encoding: .utf8)
        let forbiddenTerms = [
            "Open" + "AI",
            "OPEN" + "AI_API_KEY",
            "backend",
            "provider",
            "Unknown tool",
            "localizedDescription"
        ]

        #expect(!invalidRequest.ok)
        #expect(invalidRequest.message == AgentToolRecoveryCopy.invalidRequest)
        #expect(invalidRequest.data?["next_step"] == AgentToolRecoveryCopy.invalidRequestNextStep)
        #expect(!unknownTool.ok)
        #expect(unknownTool.message == AgentToolRecoveryCopy.unsupportedRequest)
        #expect(!missingOpenApp.ok)
        #expect(missingOpenApp.data?["next_step"] == AgentToolRecoveryCopy.missingDetailNextStep)
        #expect(!disconnectedGoogle.ok)
        #expect(disconnectedGoogle.data?["requires"] == "google_oauth")
        #expect(disconnectedGoogle.data?["next_step"] == AgentToolRecoveryCopy.googleOAuthNextStep)
        #expect(!invalidConfirmation.ok)
        #expect(invalidConfirmation.message == AgentToolRecoveryCopy.invalidConfirmation)
        #expect(invalidConfirmation.data?["next_step"] == AgentToolRecoveryCopy.invalidConfirmationNextStep)
        #expect(!missingConfirmationID.ok)
        #expect(missingConfirmationID.data?["next_step"] == AgentToolRecoveryCopy.missingDetailNextStep)
        #expect(!missingMemorySummary.ok)
        #expect(missingMemorySummary.data?["next_step"] == AgentToolRecoveryCopy.missingDetailNextStep)
        let missingOpenAppNextStep = try #require(missingOpenApp.data?["next_step"])
        let missingOpenAppEvent = try #require(store.events.first { $0.summary == missingOpenApp.message })
        #expect(missingOpenAppEvent.details.contains { $0.key == "Next step" && $0.value == AgentToolRecoveryCopy.missingDetailNextStep })

        for forbiddenTerm in forbiddenTerms {
            #expect(!invalidRequest.message.localizedCaseInsensitiveContains(forbiddenTerm))
            #expect(!unknownTool.message.localizedCaseInsensitiveContains(forbiddenTerm))
            #expect(!missingOpenApp.message.localizedCaseInsensitiveContains(forbiddenTerm))
            #expect(!invalidConfirmation.message.localizedCaseInsensitiveContains(forbiddenTerm))
            #expect(!missingConfirmationID.message.localizedCaseInsensitiveContains(forbiddenTerm))
            #expect(!missingMemorySummary.message.localizedCaseInsensitiveContains(forbiddenTerm))
            #expect(missingOpenAppNextStep.range(of: forbiddenTerm, options: .caseInsensitive) == nil)
            #expect(!exported.localizedCaseInsensitiveContains(forbiddenTerm))
        }
    }

    @Test @MainActor func actUnexpectedFailuresStayPlainAndSupportUseful() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-act-unexpected-plain-error-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        let rawError = NSError(
            domain: "backend.OPENAI_API_KEY",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "HTTP 500 backend OPENAI_API_KEY token"]
        )
        let agent = ComputerUseAgent(
            accessTokenProvider: { "unit-test-token" },
            accessibilityTrusted: { true },
            screenshotProvider: {
                ComputerScreenshot(imageBase64: "AA==", width: 1, height: 1)
            },
            eventStore: store,
            cancellationCheck: {
                throw rawError
            }
        )

        let result = await agent.run(task: "click the current button", safetyMode: .normal)
        let event = try #require(store.events.first { $0.title == "Act mode failed" })
        let exported = try String(contentsOf: try #require(store.exportSupportBundle()), encoding: .utf8)
        let forbiddenTerms = [
            "Open" + "AI",
            "OPEN" + "AI_API_KEY",
            "HTTP",
            "backend",
            "token"
        ]

        #expect(!result.ok)
        #expect(result.message == ActModeRecoveryCopy.unexpectedFailure)
        #expect(event.summary == ActModeRecoveryCopy.unexpectedFailure)
        #expect(event.details.contains { $0.key == "Next step" && $0.value == ActModeRecoveryCopy.unexpectedFailureNextStep })

        for forbiddenTerm in forbiddenTerms {
            #expect(!result.message.localizedCaseInsensitiveContains(forbiddenTerm))
            #expect(!event.summary.localizedCaseInsensitiveContains(forbiddenTerm))
            #expect(!exported.localizedCaseInsensitiveContains(forbiddenTerm))
        }
    }

    @Test func talkLatencyTargetsClassifyLaunchQaThresholds() throws {
        #expect(TalkLatencyTargets.formattedDuration(milliseconds: 850) == "0.8s")
        #expect(TalkLatencyTargets.formattedDuration(milliseconds: 12_400) == "12s")
        #expect(TalkLatencyTargets.reviewLabel(
            elapsedMilliseconds: 3_200,
            good: TalkLatencyTargets.firstAudioGoodMilliseconds,
            needsReview: TalkLatencyTargets.firstAudioNeedsReviewMilliseconds
        ) == "Good")
        #expect(TalkLatencyTargets.reviewLabel(
            elapsedMilliseconds: 6_000,
            good: TalkLatencyTargets.firstAudioGoodMilliseconds,
            needsReview: TalkLatencyTargets.firstAudioNeedsReviewMilliseconds
        ) == "Watch")
        #expect(TalkLatencyTargets.reviewLabel(
            elapsedMilliseconds: 8_500,
            good: TalkLatencyTargets.firstAudioGoodMilliseconds,
            needsReview: TalkLatencyTargets.firstAudioNeedsReviewMilliseconds
        ) == "Needs review")
    }

    @Test @MainActor func realtimeTelemetryParsesAndWritesTalkLatencyAgentLogEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-realtime-telemetry-log-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        let firstAudioPayload: [String: Any] = [
            "type": "telemetry",
            "name": "first_audio_delta",
            "mode": "talk",
            "elapsed_ms": NSNumber(value: 4_250),
            "event_type": "response.audio.delta"
        ]
        let toolPayload: [String: Any] = [
            "type": "telemetry",
            "name": "tool_call_finished",
            "mode": "act",
            "elapsed_ms": NSNumber(value: 9_000),
            "tool_elapsed_ms": NSNumber(value: 2_600),
            "tool_name": "inspect_screen",
            "ok": true
        ]
        let interruptionPayload: [String: Any] = [
            "type": "telemetry",
            "name": "interruption_completed",
            "mode": "talk",
            "elapsed_ms": NSNumber(value: 7_000),
            "interruption_elapsed_ms": NSNumber(value: 1_650)
        ]

        let firstAudio = try #require(RealtimeTelemetryEvent(message: firstAudioPayload))
        let toolCall = try #require(RealtimeTelemetryEvent(message: toolPayload))
        let interruption = try #require(RealtimeTelemetryEvent(message: interruptionPayload))

        #expect(firstAudio.mode == .talk)
        #expect(firstAudio.elapsedMilliseconds == 4_250)
        #expect(firstAudio.eventType == "response.audio.delta")
        #expect(toolCall.mode == .act)
        #expect(toolCall.toolElapsedMilliseconds == 2_600)
        #expect(toolCall.toolName == "inspect_screen")
        #expect(interruption.mode == .talk)
        #expect(interruption.interruptionElapsedMilliseconds == 1_650)

        RealtimeTelemetryLogger.append(firstAudio, to: store)
        RealtimeTelemetryLogger.append(toolCall, to: store)
        RealtimeTelemetryLogger.append(interruption, to: store)

        let firstAudioEvent = try #require(store.events.first { $0.title == "Talk first response measured" })
        let toolEvent = try #require(store.events.first { $0.title == "Talk tool delay measured" })
        let interruptionEvent = try #require(store.events.first { $0.title == "Talk interruption measured" })

        #expect(firstAudioEvent.category == .voice)
        #expect(firstAudioEvent.summary.contains("4.2s"))
        #expect(firstAudioEvent.details.contains { $0.key == "Target" && $0.value == TalkLatencyTargets.firstResponseTarget })
        #expect(firstAudioEvent.details.contains { $0.key == "QA" && $0.value == "Watch" })
        #expect(toolEvent.summary.contains("inspect_screen"))
        #expect(toolEvent.details.contains { $0.key == "QA" && $0.value == "Review silence" })
        #expect(toolEvent.details.contains { $0.key == "Target" && $0.value == TalkLatencyTargets.toolDelayTarget })
        #expect(interruptionEvent.category == .voice)
        #expect(interruptionEvent.summary.contains("1.6s"))
        #expect(interruptionEvent.details.contains { $0.key == "QA" && $0.value == "Needs review" })
        #expect(interruptionEvent.details.contains { $0.key == "Target" && $0.value == TalkLatencyTargets.interruptionTarget })
    }

    @Test @MainActor func realtimeConnectionFailureTelemetryStopsAndExplainsRecovery() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-realtime-connection-failure-log-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        let microphonePayload: [String: Any] = [
            "type": "telemetry",
            "name": "connection_failed",
            "mode": "talk",
            "elapsed_ms": NSNumber(value: 320),
            "failure_reason": "NotAllowedError"
        ]
        let networkPayload: [String: Any] = [
            "type": "telemetry",
            "name": "connection_failed",
            "mode": "act",
            "elapsed_ms": NSNumber(value: 1_800),
            "failure_reason": "Failed to fetch"
        ]
        let lostConnectionPayload: [String: Any] = [
            "type": "telemetry",
            "name": "connection_lost",
            "mode": "talk",
            "elapsed_ms": NSNumber(value: 12_000),
            "failure_reason": "Talk connection failed (ice)."
        ]
        let actLostConnectionPayload: [String: Any] = [
            "type": "telemetry",
            "name": "connection_lost",
            "mode": "act",
            "elapsed_ms": NSNumber(value: 13_500),
            "failure_reason": "Act connection failed (peer)."
        ]

        let microphoneFailure = try #require(RealtimeTelemetryEvent(message: microphonePayload))
        let networkFailure = try #require(RealtimeTelemetryEvent(message: networkPayload))
        let lostConnection = try #require(RealtimeTelemetryEvent(message: lostConnectionPayload))
        let actLostConnection = try #require(RealtimeTelemetryEvent(message: actLostConnectionPayload))

        #expect(microphoneFailure.failureReason == "NotAllowedError")
        #expect(RealtimeConnectionFailureRecovery.shouldStopRunningAgent(for: microphoneFailure))
        #expect(RealtimeConnectionFailureRecovery.shouldStopRunningAgent(for: networkFailure))
        #expect(RealtimeConnectionFailureRecovery.shouldStopRunningAgent(for: lostConnection))
        #expect(RealtimeConnectionFailureRecovery.shouldStopRunningAgent(for: actLostConnection))

        let microphoneRecovery = RealtimeConnectionFailureRecovery.recovery(for: microphoneFailure)
        let networkRecovery = RealtimeConnectionFailureRecovery.recovery(for: networkFailure)
        let lostConnectionRecovery = RealtimeConnectionFailureRecovery.recovery(for: lostConnection)
        let actLostConnectionRecovery = RealtimeConnectionFailureRecovery.recovery(for: actLostConnection)
        #expect(microphoneRecovery.permissionName == "Microphone")
        #expect(microphoneRecovery.message == TalkModeRecoveryCopy.microphonePermissionRequired)
        #expect(microphoneRecovery.nextStep == TalkModeRecoveryCopy.microphonePermissionNextStep)
        #expect(networkRecovery.permissionName == nil)
        #expect(networkRecovery.message == TalkModeRecoveryCopy.connectionFailed)
        #expect(lostConnectionRecovery.permissionName == nil)
        #expect(lostConnectionRecovery.message == TalkModeRecoveryCopy.connectionFailed)
        #expect(actLostConnectionRecovery.permissionName == nil)
        #expect(actLostConnectionRecovery.message == TalkModeRecoveryCopy.connectionFailed)

        RealtimeTelemetryLogger.append(microphoneFailure, to: store)
        RealtimeTelemetryLogger.append(networkFailure, to: store)
        RealtimeTelemetryLogger.append(lostConnection, to: store)
        RealtimeTelemetryLogger.append(actLostConnection, to: store)

        let permissionEvent = try #require(store.events.first { $0.title == "Permission blocked" })
        let serviceEvents = store.events.filter { $0.title == "\(TalkModeRecoveryCopy.serviceName) failed" }
        let actServiceEvents = serviceEvents.filter { $0.details.contains { $0.key == "Feature" && $0.value == "Act Mode" } }
        let actServiceEvent = try #require(actServiceEvents.first)
        let talkServiceEvent = try #require(serviceEvents.first { $0.details.contains { $0.key == "Feature" && $0.value == "Talk Mode" } })

        #expect(permissionEvent.summary.contains(TalkModeRecoveryCopy.microphonePermissionRequired))
        #expect(permissionEvent.details.contains { $0.key == "Permission" && $0.value == "Microphone" })
        #expect(permissionEvent.details.contains { $0.key == "Next step" && $0.value == TalkModeRecoveryCopy.microphonePermissionNextStep })
        #expect(actServiceEvent.summary.contains(TalkModeRecoveryCopy.connectionFailed))
        #expect(actServiceEvents.count == 2)
        #expect(talkServiceEvent.summary.contains(TalkModeRecoveryCopy.connectionFailed))
    }

    @Test @MainActor func sessionContextCopyStaysUserFacing() async throws {
        let memory = VideoDBAgentMemory.shared
        let searchResult = await memory.search("what did we decide earlier")
        let summaryResult = await memory.summarize()
        var userFacingStrings = [
            memory.currentToolResult().message,
            searchResult.message,
            summaryResult.message,
            VideoDBAgentMemory.userFacingSessionContextMessage("VideoDB capture package installed, but videodb.capture could not be imported."),
            VideoDBAgentMemory.userFacingSessionContextMessage("VideoDB account has insufficient credit. Add VideoDB credits, then reconnect the agent."),
            VideoDBAgentMemory.userFacingSessionContextMessage("HTTP 500 backend returned OPENAI_API_KEY token clientToken rts-123"),
            VideoDBAgentMemory.userFacingSessionContextMessage("Session context log stream ended: backend token traceback")
        ]
        if let searchData = searchResult.data {
            userFacingStrings.append(contentsOf: searchData.values)
        }
        if let summaryData = summaryResult.data {
            userFacingStrings.append(contentsOf: summaryData.values)
        }

        let forbiddenTerms = [
            "VideoDB",
            "videodb",
            "Computer Use",
            "Open" + "AI",
            "backend",
            "runtime",
            "pip install",
            "capture package"
        ]

        for copy in userFacingStrings {
            for forbiddenTerm in forbiddenTerms {
                #expect(!copy.localizedCaseInsensitiveContains(forbiddenTerm))
            }
        }

        #expect(memory.currentToolResult().message.localizedCaseInsensitiveContains("Session context"))
        #expect(searchResult.message.localizedCaseInsensitiveContains("Session context"))
        #expect(summaryResult.message.localizedCaseInsensitiveContains("Session context"))
        #expect(memory.currentToolResult().data?["memory_source"] == "session_context")
        #expect(memory.currentToolResult().data?["context_scope"] == "active_session")
        #expect(searchResult.data?["memory_source"] == "session_context")
        #expect(summaryResult.data?["context_scope"] == "active_session")
    }

    @Test func safetyModeCopySeparatesStrictNormalAndUnrestricted() throws {
        #expect(AgentSafetyMode.strict.subtitle.contains("Confirm most"))
        #expect(AgentSafetyMode.normal.subtitle.contains("sensitive actions"))
        #expect(AgentSafetyMode.unrestricted.subtitle.contains("except full system deletion"))
    }

    @Test func agentModeAndSafetyModePersistAcrossAppStateInstances() throws {
        let originalMode = UserDefaults.standard.string(forKey: "agentMode")
        let originalSafetyMode = UserDefaults.standard.string(forKey: "agentSafetyMode")
        let originalSafetyModeConfirmed = UserDefaults.standard.object(forKey: "agentSafetyModeConfirmed") as? Bool
        defer {
            if let originalMode {
                UserDefaults.standard.set(originalMode, forKey: "agentMode")
            } else {
                UserDefaults.standard.removeObject(forKey: "agentMode")
            }

            if let originalSafetyMode {
                UserDefaults.standard.set(originalSafetyMode, forKey: "agentSafetyMode")
            } else {
                UserDefaults.standard.removeObject(forKey: "agentSafetyMode")
            }

            if let originalSafetyModeConfirmed {
                UserDefaults.standard.set(originalSafetyModeConfirmed, forKey: "agentSafetyModeConfirmed")
            } else {
                UserDefaults.standard.removeObject(forKey: "agentSafetyModeConfirmed")
            }
        }

        UserDefaults.standard.removeObject(forKey: "agentMode")
        UserDefaults.standard.removeObject(forKey: "agentSafetyMode")
        UserDefaults.standard.removeObject(forKey: "agentSafetyModeConfirmed")

        let first = AppState()
        first.agentMode = .act
        #expect(!first.hasConfirmedAgentSafetyMode)
        first.confirmAgentSafetyMode(.strict)

        let second = AppState()
        #expect(second.agentMode == .act)
        #expect(second.agentSafetyMode == .strict)
        #expect(second.hasConfirmedAgentSafetyMode)
    }

    @Test func actSafetyModeRequiresExplicitConfirmationBeforeFirstUse() throws {
        let originalSafetyMode = UserDefaults.standard.string(forKey: "agentSafetyMode")
        let originalSafetyModeConfirmed = UserDefaults.standard.object(forKey: "agentSafetyModeConfirmed") as? Bool
        defer {
            if let originalSafetyMode {
                UserDefaults.standard.set(originalSafetyMode, forKey: "agentSafetyMode")
            } else {
                UserDefaults.standard.removeObject(forKey: "agentSafetyMode")
            }

            if let originalSafetyModeConfirmed {
                UserDefaults.standard.set(originalSafetyModeConfirmed, forKey: "agentSafetyModeConfirmed")
            } else {
                UserDefaults.standard.removeObject(forKey: "agentSafetyModeConfirmed")
            }
        }

        UserDefaults.standard.removeObject(forKey: "agentSafetyMode")
        UserDefaults.standard.removeObject(forKey: "agentSafetyModeConfirmed")

        let appState = AppState()
        #expect(appState.agentSafetyMode == .normal)
        #expect(!appState.hasConfirmedAgentSafetyMode)

        appState.confirmAgentSafetyMode(.unrestricted)
        #expect(appState.agentSafetyMode == .unrestricted)
        #expect(appState.hasConfirmedAgentSafetyMode)
    }

    @Test func strictSafetyPolicyConfirmsDirectActionsAndSensitiveOperations() throws {
        let policy = AgentActionSafetyPolicy()
        let examples: [(name: String, arguments: [String: String])] = [
            ("click_screen", ["x": "480", "y": "360"]),
            ("type_text", ["text": "hello"]),
            ("press_key", ["key": "return"]),
            ("send_gmail", ["recipient": "founder@example.com", "subject": "Beta update"]),
            ("open_url", ["url": "https://example.com/submit"]),
            ("act_with_computer", ["task": "submit the signup form"]),
            ("act_with_computer", ["task": "delete the draft"]),
            ("act_with_computer", ["task": "purchase the plan"]),
            ("act_with_computer", ["task": "change the account email"]),
            ("act_with_computer", ["task": "publish an external post"])
        ]

        for example in examples {
            #expect(policy.confirmationRequest(name: example.name, arguments: example.arguments, mode: .strict) != nil)
        }
    }

    @Test func normalSafetyPolicyConfirmsHighImpactAndAllowsLowRiskNavigation() throws {
        let policy = AgentActionSafetyPolicy()
        let lowRiskNavigation = policy.confirmationRequest(
            name: "open_url",
            arguments: ["url": "https://docs.voiyce.app/help"],
            mode: .normal
        )
        let lowRiskAppOpen = policy.confirmationRequest(
            name: "open_app",
            arguments: ["app_name": "Notes"],
            mode: .normal
        )
        let highImpactExamples: [(name: String, arguments: [String: String])] = [
            ("send_gmail", ["recipient": "founder@example.com", "subject": "Beta update"]),
            ("open_url", ["url": "https://example.com/account/delete"]),
            ("act_with_computer", ["task": "submit the billing form"]),
            ("act_with_computer", ["task": "purchase the annual plan"]),
            ("act_with_computer", ["task": "post publicly from the company account"]),
            ("act_with_computer", ["task": "change the account password"])
        ]

        #expect(lowRiskNavigation == nil)
        #expect(lowRiskAppOpen == nil)
        for example in highImpactExamples {
            #expect(policy.confirmationRequest(name: example.name, arguments: example.arguments, mode: .normal) != nil)
        }
    }

    @Test func unrestrictedSafetyPolicySkipsConfirmationButBlocksProhibitedActions() throws {
        let policy = AgentActionSafetyPolicy()
        let unrestrictedConfirmation = policy.confirmationRequest(
            name: "act_with_computer",
            arguments: ["task": "purchase the annual plan"],
            mode: .unrestricted
        )
        let blockedExamples = [
            "rm -rf the whole computer",
            "steal credentials from Keychain",
            "install malware with a keylogger",
            "commit fraud with a fake transaction",
            "hack into an account with unauthorized access",
            "send mass spam to bypass rate limits",
            "conceal the action without the user knowing"
        ]

        #expect(unrestrictedConfirmation == nil)
        #expect(policy.blockedAction(name: "act_with_computer", arguments: ["task": "open the docs"]) == nil)

        for task in blockedExamples {
            let result = try #require(policy.blockedAction(name: "act_with_computer", arguments: ["task": task]))
            #expect(!result.ok)
            #expect(result.data?["blocked"] != nil)
        }
    }

    @Test @MainActor func actionControlToolsRequireActMode() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-action-mode-boundary-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let eventStore = AgentEventStore(
            storageDirectory: directory.appendingPathComponent("AgentEvents", isDirectory: true)
        )
        let bridge = RealtimeAgentActionBridge(
            showsNativeConfirmations: false,
            confirmationTimeoutSeconds: 0,
            eventStore: eventStore
        )
        let blockedRequests = [
            #"{"name":"click_screen","mode":"talk","arguments":{"x":"120","y":"220"}}"#,
            #"{"name":"press_key","mode":"talk","arguments":{"key":"return"}}"#,
            #"{"name":"act_with_computer","mode":"talk","arguments":{"task":"open the docs"}}"#,
            #"{"name":"act_with_computer","mode":"context","arguments":{"task":"open the docs"}}"#
        ]

        for request in blockedRequests {
            let result = await bridge.handle(Data(request.utf8))
            #expect(!result.ok)
            #expect(result.message.contains("Switch to Act mode"))
            #expect(result.data?["requires"] == "act_mode")
        }

        #expect(realtimeHTML.contains("body: JSON.stringify({ name, arguments: args, mode: currentMode })"))
    }

    @Test func confirmationCopyIncludesActionTargetAndConsequence() throws {
        let policy = AgentActionSafetyPolicy()
        let request = try #require(policy.confirmationRequest(
            name: "send_gmail",
            arguments: ["recipient": "founder@example.com", "subject": "Beta update"],
            mode: .normal
        ))

        #expect(request.details["Action"] == "Send Gmail")
        #expect(request.details["Target"]?.contains("founder@example.com") == true)
        #expect(request.details["Target"]?.contains("Beta update") == true)
        #expect(request.details["Consequence"]?.contains("leaves your Gmail account") == true)
        #expect(request.message.contains("founder@example.com"))
        #expect(request.message.contains("Beta update"))
    }

    @Test @MainActor func cancelledConfirmationCannotExecuteLaterAndCanStopSession() async throws {
        let originalSafetyMode = UserDefaults.standard.string(forKey: "agentSafetyMode")
        let originalSafetyModeConfirmed = UserDefaults.standard.object(forKey: "agentSafetyModeConfirmed") as? Bool
        defer {
            if let originalSafetyMode {
                UserDefaults.standard.set(originalSafetyMode, forKey: "agentSafetyMode")
            } else {
                UserDefaults.standard.removeObject(forKey: "agentSafetyMode")
            }

            if let originalSafetyModeConfirmed {
                UserDefaults.standard.set(originalSafetyModeConfirmed, forKey: "agentSafetyModeConfirmed")
            } else {
                UserDefaults.standard.removeObject(forKey: "agentSafetyModeConfirmed")
            }
        }

        UserDefaults.standard.set(AgentSafetyMode.strict.rawValue, forKey: "agentSafetyMode")
        UserDefaults.standard.set(true, forKey: "agentSafetyModeConfirmed")

        let bridge = RealtimeAgentActionBridge(showsNativeConfirmations: false)
        var stopNotificationCount = 0
        let observer = NotificationCenter.default.addObserver(
            forName: .voiyceAgentStopRequested,
            object: nil,
            queue: nil
        ) { _ in
            stopNotificationCount += 1
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        let requestBody = try JSONSerialization.data(withJSONObject: [
            "name": "open_url",
            "arguments": [
                "url": "https://example.com/account/delete"
            ]
        ])
        let confirmation = await bridge.handle(requestBody)
        let confirmationID = try #require(confirmation.confirmationID)

        #expect(confirmation.needsConfirmation == true)
        #expect(confirmation.data?["voice_approval"]?.localizedCaseInsensitiveContains("stop session") == true)

        let stopBody = try JSONSerialization.data(withJSONObject: [
            "confirmationID": confirmationID,
            "decision": "stop_session"
        ])
        let stopped = await bridge.confirm(stopBody)

        #expect(!stopped.ok)
        #expect(stopped.message == "Stopped the session and cancelled that action.")
        #expect(stopped.data?["confirmation_id"] == confirmationID)
        #expect(stopped.data?["next_step"] == "Start Talk or Act again when you are ready.")
        #expect(stopNotificationCount == 1)

        let approveBody = try JSONSerialization.data(withJSONObject: [
            "confirmationID": confirmationID,
            "approved": true
        ])
        let approvedAfterStop = await bridge.confirm(approveBody)

        #expect(!approvedAfterStop.ok)
        #expect(approvedAfterStop.message == "That confirmation is no longer available.")
        #expect(approvedAfterStop.data?["next_step"] == AgentToolRecoveryCopy.confirmationUnavailableNextStep)
        #expect(!AgentEventStore.shared.events.contains { event in
            event.title == "Action approved"
                && event.details.contains { $0.key == "Confirmation" && $0.value == confirmationID }
        })

        let cancelledEvent = try #require(AgentEventStore.shared.events.first { event in
            event.title == "Action cancelled and session stopped"
                && event.details.contains { $0.key == "Confirmation" && $0.value == confirmationID }
        })
        #expect(cancelledEvent.status == .cancelled)
        #expect(cancelledEvent.details.contains { $0.key == "Decision" && $0.value == AgentConfirmationDecisionAction.stopSession.logTitle })
        #expect(cancelledEvent.summary.localizedCaseInsensitiveContains("before the action ran"))
    }

    @Test @MainActor func staleConfirmationTimesOutAndCannotExecuteLater() async throws {
        let originalSafetyMode = UserDefaults.standard.string(forKey: "agentSafetyMode")
        let originalSafetyModeConfirmed = UserDefaults.standard.object(forKey: "agentSafetyModeConfirmed") as? Bool
        defer {
            if let originalSafetyMode {
                UserDefaults.standard.set(originalSafetyMode, forKey: "agentSafetyMode")
            } else {
                UserDefaults.standard.removeObject(forKey: "agentSafetyMode")
            }

            if let originalSafetyModeConfirmed {
                UserDefaults.standard.set(originalSafetyModeConfirmed, forKey: "agentSafetyModeConfirmed")
            } else {
                UserDefaults.standard.removeObject(forKey: "agentSafetyModeConfirmed")
            }
        }

        UserDefaults.standard.set(AgentSafetyMode.strict.rawValue, forKey: "agentSafetyMode")
        UserDefaults.standard.set(true, forKey: "agentSafetyModeConfirmed")

        let bridge = RealtimeAgentActionBridge(
            showsNativeConfirmations: false,
            confirmationTimeoutSeconds: 0.02
        )
        let requestBody = try JSONSerialization.data(withJSONObject: [
            "name": "open_url",
            "arguments": [
                "url": "https://example.com/billing"
            ]
        ])
        let confirmation = await bridge.handle(requestBody)
        let confirmationID = try #require(confirmation.confirmationID)

        #expect(confirmation.needsConfirmation == true)
        #expect(confirmation.message.localizedCaseInsensitiveContains("Strict safety asks") == true)
        #expect(confirmation.data?["confirmation_reason"]?.localizedCaseInsensitiveContains("Strict safety asks") == true)

        try await Task.sleep(nanoseconds: 200_000_000)

        let timeoutEvent = try #require(AgentEventStore.shared.events.first { event in
            event.title == "Confirmation timed out"
                && event.details.contains { $0.key == "Confirmation" && $0.value == confirmationID }
        })
        #expect(timeoutEvent.status == .cancelled)
        #expect(timeoutEvent.details.contains { $0.key == "Decision" && $0.value == AgentConfirmationDecisionAction.timedOut.logTitle })
        #expect(timeoutEvent.details.contains { $0.key == "Next step" && $0.value.localizedCaseInsensitiveContains("Ask Voiyce again") })

        let approveBody = try JSONSerialization.data(withJSONObject: [
            "confirmationID": confirmationID,
            "approved": true
        ])
        let approvedAfterTimeout = await bridge.confirm(approveBody)

        #expect(!approvedAfterTimeout.ok)
        #expect(approvedAfterTimeout.message == "That confirmation is no longer available.")
        #expect(approvedAfterTimeout.data?["next_step"] == AgentToolRecoveryCopy.confirmationUnavailableNextStep)
        #expect(!AgentEventStore.shared.events.contains { event in
            event.title == "Action approved"
                && event.details.contains { $0.key == "Confirmation" && $0.value == confirmationID }
        })
    }

    @Test @MainActor func realtimeToolSuccessWritesSupportSafeAgentLogEvent() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-realtime-tool-log-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let eventStore = AgentEventStore(storageDirectory: directory)
        let bridge = RealtimeAgentActionBridge(
            showsNativeConfirmations: false,
            eventStore: eventStore
        )
        let requestBody = try JSONSerialization.data(withJSONObject: [
            "name": "summarize_long_term_memory",
            "arguments": [
                "limit": "2"
            ]
        ])

        let result = await bridge.handle(requestBody)

        #expect(result.ok)

        let event = try #require(eventStore.events.first { event in
            event.title == "Tool completed"
                && event.details.contains { $0.key == "Tool" && $0.value == "summarize_long_term_memory" }
        })
        let dataFields = try #require(event.details.first { $0.key == "Data fields" })

        #expect(event.category == .memory)
        #expect(event.status == .done)
        #expect(event.summary == "Long-term memory result returned.")
        #expect(event.details.contains { $0.key == "Result" && $0.value == "Succeeded" })
        #expect(dataFields.value.contains("count"))
        #expect(!event.summary.contains(result.message))
        #expect(!event.details.contains { detail in detail.value.contains(result.message) })
    }

    @Test @MainActor func agentHotkeyTogglesOnlyOnPress() throws {
        let hotkeyManager = HotkeyManager()
        var toggleCount = 0
        hotkeyManager.onAgentToggle = {
            toggleCount += 1
        }

        hotkeyManager.pressAgentHotkey()
        #expect(toggleCount == 1)
        #expect(hotkeyManager.isAgentHotkeyPressed)

        hotkeyManager.pressAgentHotkey()
        #expect(toggleCount == 1)

        hotkeyManager.releaseAgentHotkey()
        #expect(toggleCount == 1)
        #expect(!hotkeyManager.isAgentHotkeyPressed)

        hotkeyManager.pressAgentHotkey()
        #expect(toggleCount == 2)
    }

    @Test @MainActor func focusHighlightShortcutsDispatchExpectedModes() throws {
        let hotkeyManager = HotkeyManager()
        var modes: [FocusMarkMode] = []
        hotkeyManager.onFocusHighlight = {
            modes.append(.rectangle)
        }
        hotkeyManager.onFocusPaint = {
            modes.append(.paint)
        }
        hotkeyManager.onFocusUnderline = {
            modes.append(.underline)
        }

        hotkeyManager.triggerFocusHighlightShortcut()
        hotkeyManager.triggerFocusPaintShortcut()
        hotkeyManager.triggerFocusUnderlineShortcut()

        #expect(modes == [.rectangle, .paint, .underline])
    }

    @Test func googleOAuthScopesMatchCurrentGmailCalendarFeatureSet() throws {
        #expect(AppConstants.googleOAuthScopes == [
            "openid",
            "email",
            "profile",
            "https://www.googleapis.com/auth/gmail.readonly",
            "https://www.googleapis.com/auth/gmail.compose",
            "https://www.googleapis.com/auth/gmail.send",
            "https://www.googleapis.com/auth/calendar.freebusy",
            "https://www.googleapis.com/auth/calendar.events.readonly"
        ])
        #expect(Set(AppConstants.googleOAuthScopes).count == AppConstants.googleOAuthScopes.count)
    }

    @Test @MainActor func privateModeSkipsLongTermMemoryWrites() throws {
        let store = AgentLongTermMemoryStore.shared
        let originalPrivateMode = store.isPrivateModeEnabled
        let originalExclusions = store.excludedPatternsText
        let originalRecordCount = store.records.count

        defer {
            store.isPrivateModeEnabled = originalPrivateMode
            store.excludedPatternsText = originalExclusions
        }

        store.isPrivateModeEnabled = true
        store.excludedPatternsText = ""

        let result = store.addRecord(
            source: "test",
            summary: "This should not persist while private mode is enabled.",
            searchableText: "private mode test",
            tags: ["test"],
            appHint: "Unit Test"
        )

        #expect(result.ok)
        #expect(result.data?["memory_skipped"] == "true")
        #expect(store.records.count == originalRecordCount)
    }

    @Test @MainActor func memoryExclusionsSkipMatchingAppsAndSites() throws {
        let store = AgentLongTermMemoryStore.shared
        let originalPrivateMode = store.isPrivateModeEnabled
        let originalExclusions = store.excludedPatternsText
        let originalRecordCount = store.records.count

        defer {
            store.isPrivateModeEnabled = originalPrivateMode
            store.excludedPatternsText = originalExclusions
        }

        store.isPrivateModeEnabled = false
        store.excludedPatternsText = "client portal, banking"

        let result = store.addRecord(
            source: "screen inspect",
            summary: "Visible notes from the client portal.",
            searchableText: "client portal intake",
            tags: ["test"],
            appHint: "Client Portal"
        )

        #expect(result.ok)
        #expect(result.data?["memory_skipped"] == "true")
        #expect(store.records.count == originalRecordCount)
    }

    @Test @MainActor func sensitiveContextsSkipLongTermMemoryWrites() throws {
        let store = AgentLongTermMemoryStore.shared
        let originalPrivateMode = store.isPrivateModeEnabled
        let originalExclusions = store.excludedPatternsText
        let originalRecordCount = store.records.count

        defer {
            store.isPrivateModeEnabled = originalPrivateMode
            store.excludedPatternsText = originalExclusions
        }

        store.isPrivateModeEnabled = false
        store.excludedPatternsText = ""

        let result = store.addRecord(
            source: "screen inspect",
            summary: "The visible screen includes a password manager item.",
            searchableText: "1Password credential screen",
            tags: ["test"],
            appHint: "1Password"
        )

        #expect(result.ok)
        #expect(result.data?["memory_skipped"] == "true")
        #expect(store.records.count == originalRecordCount)
    }

    @Test @MainActor func memoryClearRemovesStructuredStorageScreenshotsAndVaultNotes() throws {
        let fixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: fixture.directory, suiteName: fixture.suiteName)
        }

        fixture.store.memoryRetention = .forever
        fixture.store.screenshotRetention = .forever

        let result = fixture.store.addRecord(
            source: "unit test",
            summary: "Remember this launch checklist note.",
            searchableText: "launch checklist",
            tags: ["launch"],
            appHint: "Unit Test",
            rawScreenshotData: Data("fake screenshot".utf8)
        )

        let record = try #require(fixture.store.records.first)
        let screenshotPath = try #require(record.screenshotPath)
        let vaultNotePath = try #require(record.vaultNotePath)
        let recordsURL = fixture.directory.appendingPathComponent("long-term-memory.json")

        #expect(result.ok)
        #expect(FileManager.default.fileExists(atPath: recordsURL.path))
        #expect(FileManager.default.fileExists(atPath: screenshotPath))
        #expect(FileManager.default.fileExists(atPath: vaultNotePath))

        fixture.store.clear()

        #expect(fixture.store.records.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: recordsURL.path))
        #expect(!FileManager.default.fileExists(atPath: screenshotPath))
        #expect(!FileManager.default.fileExists(atPath: vaultNotePath))
    }

    @Test @MainActor func memoryRetentionModesPruneSessionOnlyThirtyNinetyAndForever() throws {
        let now = Date()

        let sessionFixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: sessionFixture.directory, suiteName: sessionFixture.suiteName)
        }
        sessionFixture.store.memoryRetention = .sessionOnly
        sessionFixture.store.screenshotRetention = .forever
        sessionFixture.store.addRecord(
            source: "unit test",
            summary: "Session-only memory.",
            searchableText: "session memory",
            tags: ["session"],
            appHint: "Unit Test",
            rawScreenshotData: Data("session screenshot".utf8),
            createdAt: now
        )
        #expect(sessionFixture.store.records.count == 1)
        #expect(sessionFixture.store.records[0].vaultNotePath == nil)
        #expect(sessionFixture.store.records[0].screenshotPath == nil)
        #expect(!FileManager.default.fileExists(atPath: sessionFixture.directory.appendingPathComponent("long-term-memory.json").path))
        #expect(fileCount(in: sessionFixture.directory.appendingPathComponent("Screenshots")) == 0)

        let thirtyFixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: thirtyFixture.directory, suiteName: thirtyFixture.suiteName)
        }
        thirtyFixture.store.memoryRetention = .thirtyDays
        thirtyFixture.store.screenshotRetention = .forever
        thirtyFixture.store.addRecord(
            source: "unit test",
            summary: "Expired thirty-day memory.",
            searchableText: "expired",
            tags: ["expired"],
            appHint: "Unit Test",
            rawScreenshotData: Data("old screenshot".utf8),
            createdAt: now.addingTimeInterval(-(31 * 24 * 60 * 60))
        )
        thirtyFixture.store.addRecord(
            source: "unit test",
            summary: "Current thirty-day memory.",
            searchableText: "current",
            tags: ["current"],
            appHint: "Unit Test",
            rawScreenshotData: Data("new screenshot".utf8),
            createdAt: now
        )
        #expect(thirtyFixture.store.records.map(\.summary) == ["Current thirty-day memory."])
        #expect(fileCount(in: thirtyFixture.directory.appendingPathComponent("Screenshots")) == 1)

        let ninetyFixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: ninetyFixture.directory, suiteName: ninetyFixture.suiteName)
        }
        ninetyFixture.store.memoryRetention = .ninetyDays
        ninetyFixture.store.addRecord(
            source: "unit test",
            summary: "Expired ninety-day memory.",
            searchableText: "expired",
            tags: ["expired"],
            appHint: "Unit Test",
            createdAt: now.addingTimeInterval(-(91 * 24 * 60 * 60))
        )
        ninetyFixture.store.addRecord(
            source: "unit test",
            summary: "Current ninety-day memory.",
            searchableText: "current",
            tags: ["current"],
            appHint: "Unit Test",
            createdAt: now
        )
        #expect(ninetyFixture.store.records.map(\.summary) == ["Current ninety-day memory."])

        let foreverFixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: foreverFixture.directory, suiteName: foreverFixture.suiteName)
        }
        foreverFixture.store.memoryRetention = .forever
        foreverFixture.store.addRecord(
            source: "unit test",
            summary: "Forever memory.",
            searchableText: "old retained",
            tags: ["forever"],
            appHint: "Unit Test",
            createdAt: now.addingTimeInterval(-(365 * 24 * 60 * 60))
        )
        #expect(foreverFixture.store.records.map(\.summary) == ["Forever memory."])
        #expect(FileManager.default.fileExists(atPath: foreverFixture.directory.appendingPathComponent("long-term-memory.json").path))
    }

    @Test @MainActor func screenshotRetentionIsSeparateFromSummaryRetention() throws {
        let fixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: fixture.directory, suiteName: fixture.suiteName)
        }

        fixture.store.memoryRetention = .forever
        fixture.store.screenshotRetention = .off
        fixture.store.addRecord(
            source: "unit test",
            summary: "Summary with screenshot retention off.",
            searchableText: "screenshot off",
            tags: ["privacy"],
            appHint: "Unit Test",
            rawScreenshotData: Data("discarded screenshot".utf8)
        )
        #expect(fixture.store.records.first?.screenshotPath == nil)

        fixture.store.screenshotRetention = .forever
        fixture.store.addRecord(
            source: "unit test",
            summary: "Summary with screenshot retention on.",
            searchableText: "screenshot on",
            tags: ["privacy"],
            appHint: "Unit Test",
            rawScreenshotData: Data("retained screenshot".utf8)
        )

        let retainedPath = try #require(fixture.store.records.first?.screenshotPath)
        #expect(FileManager.default.fileExists(atPath: retainedPath))
    }

    @Test @MainActor func memoryUsageSnapshotTracksCaptureFrequencyAndStorage() throws {
        let fixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: fixture.directory, suiteName: fixture.suiteName)
        }

        let yesterday = Date().addingTimeInterval(-(24 * 60 * 60))
        fixture.store.memoryRetention = .forever
        fixture.store.screenshotRetention = .forever

        fixture.store.addRecord(
            source: "unit test",
            summary: "Older memory with screenshot.",
            searchableText: "older storage usage",
            tags: ["usage"],
            appHint: "Unit Test",
            rawScreenshotData: Data("older screenshot bytes".utf8),
            createdAt: yesterday
        )
        let todayResult = fixture.store.addRecord(
            source: "unit test",
            summary: "Current memory with screenshot.",
            searchableText: "current storage usage",
            tags: ["usage"],
            appHint: "Unit Test",
            rawScreenshotData: Data("current screenshot bytes".utf8)
        )

        let snapshot = fixture.store.usageSnapshot
        let savedEvent = try #require(fixture.eventStore.events.last { $0.title == "Memory saved" })

        #expect(snapshot.recordCount == 2)
        #expect(snapshot.capturesToday == 1)
        #expect(snapshot.screenshotCount == 2)
        #expect(snapshot.screenshotBytes >= "older screenshot bytes".utf8.count + "current screenshot bytes".utf8.count)
        #expect(snapshot.vaultNoteCount == 2)
        #expect(snapshot.vaultNoteBytes > 0)
        #expect(snapshot.indexBytes > 0)
        #expect(snapshot.totalStorageBytes == snapshot.screenshotBytes + snapshot.vaultNoteBytes + snapshot.indexBytes)
        #expect(todayResult.data?["memory_record_count"] == "2")
        #expect(todayResult.data?["memory_captures_today"] == "1")
        #expect(todayResult.data?["memory_screenshot_count"] == "2")
        #expect(Int(todayResult.data?["memory_total_storage_bytes"] ?? "0") == snapshot.totalStorageBytes)
        let eventStorageBytes = try #require(savedEvent.details.first { $0.key == "Storage bytes" }.flatMap { Int($0.value) })
        #expect(eventStorageBytes > 0)
    }

    @Test @MainActor func memoryStorageQuotaLimitsDurableRecordsAndRawScreenshots() throws {
        let fixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: fixture.directory, suiteName: fixture.suiteName)
        }

        fixture.store.memoryRetention = .forever
        fixture.store.screenshotRetention = .forever
        fixture.store.configureStorageTier(.defaultTier)
        fixture.store.storageQuotaOverride = AgentMemoryStorageQuota(
            maxRecords: 1,
            maxScreenshotBytes: 8,
            maxTotalStorageBytes: 512
        )

        let first = fixture.store.addRecord(
            source: "unit test",
            summary: "First quota memory.",
            searchableText: "first quota memory",
            tags: ["quota"],
            appHint: "Unit Test",
            rawScreenshotData: Data("screenshot over quota".utf8)
        )

        #expect(first.ok)
        #expect(first.data?["memory_screenshot_skipped"] == "storage_limit")
        #expect(fixture.store.records.count == 1)
        #expect(fixture.store.records.first?.screenshotPath == nil)

        let second = fixture.store.addRecord(
            source: "unit test",
            summary: "Second quota memory.",
            searchableText: "second quota memory",
            tags: ["quota"],
            appHint: "Unit Test"
        )

        #expect(second.ok)
        #expect(second.data?["memory_skipped"] == "true")
        #expect(second.data?["memory_storage_limit_reached"] == "true")
        #expect(second.data?["memory_storage_tier"] == "default")
        #expect(fixture.store.records.count == 1)
        #expect(fixture.eventStore.events.contains { event in
            event.title == "Memory skipped"
                && event.summary.contains("local memory record limit")
        })
    }

    @Test @MainActor func privateModeSkipsPersistentMemoryAndScreenshots() throws {
        let fixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: fixture.directory, suiteName: fixture.suiteName)
        }

        fixture.store.screenshotRetention = .forever
        fixture.store.isPrivateModeEnabled = true

        let result = fixture.store.addRecord(
            source: "unit test",
            summary: "Private mode should skip this memory.",
            searchableText: "private screenshot",
            tags: ["privacy"],
            appHint: "Unit Test",
            rawScreenshotData: Data("private screenshot".utf8)
        )

        #expect(result.ok)
        #expect(result.data?["memory_skipped"] == "true")
        #expect(fixture.store.records.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fixture.directory.appendingPathComponent("long-term-memory.json").path))
        #expect(fileCount(in: fixture.directory.appendingPathComponent("Screenshots")) == 0)
        #expect(fileCount(in: fixture.directory.appendingPathComponent("Vault/Daily")) == 0)
    }

    @Test @MainActor func memoryExclusionsSkipPersistentMemoryAndScreenshots() throws {
        let fixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: fixture.directory, suiteName: fixture.suiteName)
        }

        fixture.store.screenshotRetention = .forever
        fixture.store.excludedPatternsText = "client portal"

        let result = fixture.store.addRecord(
            source: "screen inspect",
            summary: "Visible notes from the client portal.",
            searchableText: "client portal intake",
            tags: ["privacy"],
            appHint: "Client Portal",
            rawScreenshotData: Data("excluded screenshot".utf8)
        )

        #expect(result.ok)
        #expect(result.data?["memory_skipped"] == "true")
        #expect(fixture.store.records.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fixture.directory.appendingPathComponent("long-term-memory.json").path))
        #expect(fileCount(in: fixture.directory.appendingPathComponent("Screenshots")) == 0)
        #expect(fileCount(in: fixture.directory.appendingPathComponent("Vault/Daily")) == 0)
    }

    @Test @MainActor func privateModeAndExclusionsPauseLiveSessionContext() async throws {
        let privateFixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: privateFixture.directory, suiteName: privateFixture.suiteName)
        }

        privateFixture.store.isPrivateModeEnabled = true
        let privateResult = await VideoDBAgentMemory.shared.start(
            privacyStore: privateFixture.store,
            contextSnapshot: AgentSessionContextSnapshot(
                appName: "Notes",
                bundleIdentifier: "com.apple.Notes",
                windowTitle: "Launch checklist",
                url: nil
            ),
            eventStore: privateFixture.eventStore
        )

        #expect(!privateResult.ok)
        #expect(privateResult.data?["status"] == VideoDBMemoryStatus.idle.rawValue)
        #expect(privateResult.data?["next_step"]?.localizedCaseInsensitiveContains("Private Mode") == true)
        #expect(privateResult.message.localizedCaseInsensitiveContains("Private Mode"))
        #expect(privateResult.message.localizedCaseInsensitiveContains("live session context is paused"))
        #expect(privateFixture.eventStore.events.contains { event in
            event.title == "Session context paused"
                && event.summary.localizedCaseInsensitiveContains("Private Mode")
        })

        let exclusionFixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: exclusionFixture.directory, suiteName: exclusionFixture.suiteName)
        }

        exclusionFixture.store.excludedPatternsText = "client portal"
        let excludedResult = await VideoDBAgentMemory.shared.start(
            privacyStore: exclusionFixture.store,
            contextSnapshot: AgentSessionContextSnapshot(
                appName: "Google Chrome",
                bundleIdentifier: "com.google.Chrome",
                windowTitle: "Client Portal - Intake",
                url: nil
            ),
            eventStore: exclusionFixture.eventStore
        )

        #expect(!excludedResult.ok)
        #expect(excludedResult.data?["status"] == VideoDBMemoryStatus.idle.rawValue)
        #expect(excludedResult.data?["next_step"]?.localizedCaseInsensitiveContains("exclusions") == true)
        #expect(excludedResult.message.localizedCaseInsensitiveContains("memory exclusion"))
        #expect(excludedResult.message.localizedCaseInsensitiveContains("live session context is paused"))
        #expect(exclusionFixture.eventStore.events.contains { event in
            event.title == "Session context paused"
                && event.details.contains { $0.key == "App/site" && $0.value.contains("Client Portal") }
        })

        let sensitiveFixture = try makeIsolatedMemoryStore()
        defer { cleanupMemoryStore(directory: sensitiveFixture.directory, suiteName: sensitiveFixture.suiteName) }

        let sensitiveResult = await VideoDBAgentMemory.shared.start(
            privacyStore: sensitiveFixture.store,
            contextSnapshot: AgentSessionContextSnapshot(
                appName: "1Password",
                bundleIdentifier: "com.1password.1password",
                windowTitle: "Vault",
                url: nil
            ),
            eventStore: sensitiveFixture.eventStore
        )

        #expect(!sensitiveResult.ok)
        #expect(sensitiveResult.data?["status"] == VideoDBMemoryStatus.idle.rawValue)
        #expect(sensitiveResult.data?["next_step"]?.localizedCaseInsensitiveContains("sensitive screen") == true)
        #expect(sensitiveResult.message.localizedCaseInsensitiveContains("sensitive"))
        #expect(sensitiveResult.message.localizedCaseInsensitiveContains("live session context is paused"))
        #expect(sensitiveFixture.eventStore.events.contains { event in
            event.title == "Session context paused"
                && event.summary.localizedCaseInsensitiveContains("sensitive")
        })
    }

    @Test @MainActor func memorySearchFindsRelevantRecordsAndHandlesNoResults() throws {
        let fixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: fixture.directory, suiteName: fixture.suiteName)
        }

        fixture.store.memoryRetention = .forever
        fixture.store.addRecord(
            source: "unit test",
            summary: "Launch notes should mention the support export decision.",
            searchableText: "support export launch readiness",
            tags: ["launch"],
            appHint: "Unit Test"
        )
        fixture.store.addRecord(
            source: "unit test",
            summary: "Billing copy belongs to a separate review.",
            searchableText: "pricing billing",
            tags: ["billing"],
            appHint: "Unit Test"
        )

        let match = fixture.store.search("support export", limit: 1)
        #expect(match.ok)
        #expect(match.data?["matches"] == "1")
        #expect(match.data?["memory_source"] == "long_term")
        #expect(match.data?["context_scope"] == "previous_sessions")
        #expect(match.data?["answer_guidance"]?.localizedCaseInsensitiveContains("cite the date or session") == true)
        #expect(match.data?["answer_guidance"]?.localizedCaseInsensitiveContains("raw source fields") == true)
        #expect(match.message.contains("Launch notes should mention the support export decision."))

        let noMatch = fixture.store.search("unrelated browser automation")
        #expect(noMatch.ok)
        #expect(noMatch.data?["matches"] == "0")
        #expect(noMatch.data?["memory_source"] == "long_term")
        #expect(noMatch.data?["context_scope"] == "previous_sessions")
        #expect(noMatch.message.contains("I did not find that in saved memory yet."))
        #expect(!noMatch.message.localizedCaseInsensitiveContains("long-term memory"))
    }

    @Test @MainActor func longTermMemoryRecordsAreIsolatedByAccount() throws {
        let fixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: fixture.directory, suiteName: fixture.suiteName)
        }

        fixture.store.configureForAccount(userID: "account-a@example.com")
        let accountAStorage = fixture.store.activeStorageDirectory
        fixture.store.setVault(url: fixture.directory.appendingPathComponent("VaultA", isDirectory: true))
        fixture.store.memoryRetention = .forever
        fixture.store.addRecord(
            source: "unit test",
            summary: "Alpha account launch memory.",
            searchableText: "alphasentinel",
            tags: ["alpha"],
            appHint: "Unit Test"
        )

        #expect(accountAStorage.deletingLastPathComponent().lastPathComponent == "Accounts")
        #expect(accountAStorage.lastPathComponent.hasPrefix("user-"))
        #expect(!accountAStorage.lastPathComponent.contains("@"))
        #expect(fixture.store.search("alphasentinel").data?["matches"] == "1")

        fixture.store.configureForAccount(userID: "account-b@example.com")
        let accountBStorage = fixture.store.activeStorageDirectory
        fixture.store.setVault(url: fixture.directory.appendingPathComponent("VaultB", isDirectory: true))

        #expect(accountBStorage.deletingLastPathComponent().lastPathComponent == "Accounts")
        #expect(accountBStorage.path != accountAStorage.path)
        #expect(fixture.store.records.isEmpty)
        #expect(fixture.store.search("alphasentinel").data?["matches"] == "0")

        fixture.store.addRecord(
            source: "unit test",
            summary: "Beta account billing memory.",
            searchableText: "betasentinel",
            tags: ["beta"],
            appHint: "Unit Test"
        )
        #expect(fixture.store.search("betasentinel").data?["matches"] == "1")

        fixture.store.configureForAccount(userID: "account-a@example.com")
        #expect(fixture.store.search("alphasentinel").data?["matches"] == "1")
        #expect(fixture.store.search("betasentinel").data?["matches"] == "0")
    }

    @Test @MainActor func memoryPrivacySettingsAreScopedPerAccount() throws {
        let fixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: fixture.directory, suiteName: fixture.suiteName)
        }

        fixture.store.configureForAccount(userID: "account-a")
        fixture.store.memoryRetention = .thirtyDays
        fixture.store.screenshotRetention = .forever
        fixture.store.isVaultSyncEnabled = false
        fixture.store.isPrivateModeEnabled = true
        fixture.store.excludedPatternsText = "client portal"

        fixture.store.configureForAccount(userID: "account-b")
        #expect(fixture.store.memoryRetention == .ninetyDays)
        #expect(fixture.store.screenshotRetention == .off)
        #expect(fixture.store.isVaultSyncEnabled)
        #expect(!fixture.store.isPrivateModeEnabled)
        #expect(fixture.store.excludedPatternsText.isEmpty)

        fixture.store.memoryRetention = .sessionOnly
        fixture.store.isVaultSyncEnabled = true
        fixture.store.excludedPatternsText = "banking"

        fixture.store.configureForAccount(userID: "account-a")
        #expect(fixture.store.memoryRetention == .thirtyDays)
        #expect(fixture.store.screenshotRetention == .forever)
        #expect(!fixture.store.isVaultSyncEnabled)
        #expect(fixture.store.isPrivateModeEnabled)
        #expect(fixture.store.excludedPatterns == ["client portal"])
    }

    @Test @MainActor func vaultSyncCanBeDisabledWithoutDisablingStructuredMemory() throws {
        let fixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: fixture.directory, suiteName: fixture.suiteName)
        }

        fixture.store.memoryRetention = .forever
        fixture.store.isVaultSyncEnabled = false
        fixture.store.addRecord(
            source: "unit test",
            summary: "Structured memory without vault sync.",
            searchableText: "vault disabled searchable",
            tags: ["vault"],
            appHint: "Unit Test"
        )

        let localOnlyRecord = try #require(fixture.store.records.first)
        let recordsURL = fixture.directory.appendingPathComponent("long-term-memory.json")
        #expect(localOnlyRecord.vaultNotePath == nil)
        #expect(FileManager.default.fileExists(atPath: recordsURL.path))
        #expect(fixture.store.search("searchable").data?["matches"] == "1")
        #expect(fileCount(in: fixture.directory.appendingPathComponent("Vault/Daily")) == 0)

        fixture.store.isVaultSyncEnabled = true
        fixture.store.addRecord(
            source: "unit test",
            summary: "Structured memory with vault sync.",
            searchableText: "vault enabled searchable",
            tags: ["vault"],
            appHint: "Unit Test"
        )

        let syncedRecord = try #require(fixture.store.records.first)
        let vaultNotePath = try #require(syncedRecord.vaultNotePath)
        #expect(FileManager.default.fileExists(atPath: vaultNotePath))
    }

    @Test @MainActor func vaultNotesArePlainMarkdownAndDateOrganized() throws {
        let fixture = try makeIsolatedMemoryStore()
        defer {
            cleanupMemoryStore(directory: fixture.directory, suiteName: fixture.suiteName)
        }

        let createdAt = try #require(Calendar.current.date(
            from: DateComponents(year: 2026, month: 5, day: 17, hour: 10, minute: 15)
        ))

        fixture.store.memoryRetention = .forever
        let result = fixture.store.addRecord(
            source: "context",
            summary: "Readable Markdown memory.",
            searchableText: "Observed handoff details.",
            tags: ["launch", "codex"],
            appHint: "Codex",
            createdAt: createdAt
        )

        let record = try #require(fixture.store.records.first)
        let vaultNotePath = try #require(record.vaultNotePath)
        let content = try String(contentsOf: URL(fileURLWithPath: vaultNotePath), encoding: .utf8)

        #expect(result.ok)
        #expect(vaultNotePath.hasSuffix("/Vault/Daily/2026-05-17.md"))
        #expect(content.contains("date: 2026-05-17"))
        #expect(content.contains("source: Voiyce"))
        #expect(content.contains("source_modes:\n  - 'context'"))
        #expect(content.contains("apps:\n  - 'Codex'"))
        #expect(content.contains("tags:\n  - 'voiyce'\n  - 'codex'\n  - 'launch'"))
        #expect(content.contains("privacy_level: local_memory"))
        #expect(content.contains("screenshot_retention: off"))
        #expect(content.contains("account_scope: signed_out"))
        #expect(content.contains("Readable Markdown memory."))
        #expect(content.contains("Observed handoff details."))
        #expect(content.contains("App/site: Codex"))
        #expect(content.contains("[[launch]]"))
        #expect(content.contains("[[codex]]"))
    }

    @Test func supportExportRedactionRemovesSecretsAndEmails() throws {
        let fakeOpenAIKey = ["sk", "proj"].joined(separator: "-") + "-abcdefghijklmnopqrstuvwxyz"
        let redacted = AgentEventStore.redactedForSupport(
            "Email aki@example.com with bearer abcdefghijklmnop and \(fakeOpenAIKey)"
        )

        #expect(!redacted.contains("aki@example.com"))
        #expect(!redacted.lowercased().contains("bearer abcdefghijklmnop"))
        #expect(!redacted.contains(fakeOpenAIKey))
        #expect(redacted.contains("[redacted]"))
    }

    @Test @MainActor func agentLogStorageRedactsSensitiveEventPayloads() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-agent-log-storage-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let fakeOpenAIKey = ["sk", "proj"].joined(separator: "-") + "-abcdefghijklmnopqrstuvwxyz"
        let store = AgentEventStore(storageDirectory: directory)
        store.append(
            category: .errors,
            status: .failed,
            symbol: "exclamationmark.triangle",
            title: "Failure for aki@example.com",
            summary: "OpenAI key \(fakeOpenAIKey) and bearer abcdefghijklmnop were present.",
            details: [
                AgentLogEventDetail(key: "User aki@example.com", value: "Bearer abcdefghijklmnop")
            ]
        )

        let event = try #require(store.events.first)
        let storedJSON = try String(
            contentsOf: directory.appendingPathComponent("agent-events.json"),
            encoding: .utf8
        )

        #expect(!event.title.contains("aki@example.com"))
        #expect(!event.summary.contains(fakeOpenAIKey))
        #expect(!event.summary.lowercased().contains("bearer abcdefghijklmnop"))
        #expect(!event.details[0].key.contains("aki@example.com"))
        #expect(!event.details[0].value.lowercased().contains("bearer abcdefghijklmnop"))
        #expect(!storedJSON.contains("aki@example.com"))
        #expect(!storedJSON.contains(fakeOpenAIKey))
        #expect(!storedJSON.lowercased().contains("bearer abcdefghijklmnop"))
    }

    @Test @MainActor func supportExportFileRedactsEventPayloads() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-agent-log-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let fakeOpenAIKey = ["sk", "proj"].joined(separator: "-") + "-abcdefghijklmnopqrstuvwxyz"
        let store = AgentEventStore(storageDirectory: directory)
        store.append(
            category: .errors,
            status: .failed,
            symbol: "exclamationmark.triangle",
            title: "Quota failed for aki@example.com",
            summary: "Backend returned bearer abcdefghijklmnop and \(fakeOpenAIKey)",
            details: [
                AgentLogEventDetail(key: "User aki@example.com", value: "Authorization: Bearer abcdefghijklmnop")
            ]
        )

        let exportURL = try #require(store.exportSupportBundle())
        let exported = try String(contentsOf: exportURL, encoding: .utf8)

        #expect(!exported.contains("aki@example.com"))
        #expect(!exported.lowercased().contains("bearer abcdefghijklmnop"))
        #expect(!exported.contains(fakeOpenAIKey))
        #expect(exported.contains("[redacted]"))
    }

    @Test @MainActor func supportExportIncludesStableSchemaMetadataAndEventIds() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-agent-support-schema-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        store.append(
            category: .actions,
            status: .done,
            symbol: "cursorarrow.click",
            title: "Clicked Settings",
            summary: "Voiyce opened Settings from Act mode.",
            details: [
                AgentLogEventDetail(key: "Action", value: "Click"),
                AgentLogEventDetail(key: "Target", value: "Settings")
            ]
        )
        let loggedEvent = try #require(store.events.first)

        let exportURL = try #require(store.exportSupportBundle())
        let exportedData = try Data(contentsOf: exportURL)
        let object = try JSONSerialization.jsonObject(with: exportedData) as? [String: Any]
        let bundle = try #require(object)
        let events = try #require(bundle["events"] as? [[String: Any]])
        let event = try #require(events.first)

        #expect(bundle["schemaVersion"] as? Int == 1)
        #expect(bundle["bundleKind"] as? String == "voiyce-agent-support-log")
        #expect(bundle["eventCount"] as? Int == 1)
        #expect(event["id"] as? String == loggedEvent.id.uuidString)
        #expect(event["category"] as? String == AgentLogCategory.actions.rawValue)
        #expect(event["status"] as? String == AgentLogStatus.done.rawValue)
        #expect(event["title"] as? String == "Clicked Settings")
        #expect(event["summary"] as? String == "Voiyce opened Settings from Act mode.")
        #expect(event["timestamp"] is String)
        #expect(event["details"] is [[String: Any]])
    }

    @Test @MainActor func supportExportAndAgentLogRedactRawTranscriptAndScreenshotPayloads() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-agent-raw-context-redaction-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let privateTranscript = "private launch transcript: pricing plan and customer notes"
        let imageDataURL = "data:image/png;base64,\(String(repeating: "A", count: 180))"
        let rawScreenshotBlob = String(repeating: "B", count: 180)
        let store = AgentEventStore(storageDirectory: directory)
        store.append(
            category: .voice,
            status: .done,
            symbol: "waveform",
            title: "Captured working context",
            summary: "Screen payload \(imageDataURL)",
            details: [
                AgentLogEventDetail(key: "Transcript", value: privateTranscript),
                AgentLogEventDetail(key: "ScreenshotBase64", value: imageDataURL),
                AgentLogEventDetail(key: "Raw screenshot", value: rawScreenshotBlob)
            ]
        )

        let event = try #require(store.events.first)
        let storedJSON = try String(
            contentsOf: directory.appendingPathComponent("agent-events.json"),
            encoding: .utf8
        )
        let exportURL = try #require(store.exportSupportBundle())
        let exported = try String(contentsOf: exportURL, encoding: .utf8)

        #expect(event.details.map(\.value).allSatisfy { $0 == "[redacted]" })
        #expect(!event.summary.contains("data:image/png;base64"))
        #expect(!storedJSON.contains(privateTranscript))
        #expect(!storedJSON.contains("data:image/png;base64"))
        #expect(!storedJSON.contains(rawScreenshotBlob))
        #expect(storedJSON.contains("[redacted-image]"))
        #expect(storedJSON.contains("[redacted]"))
        #expect(!exported.contains(privateTranscript))
        #expect(!exported.contains("data:image/png;base64"))
        #expect(!exported.contains(rawScreenshotBlob))
        #expect(exported.contains("[redacted-image]"))
        #expect(exported.contains("[redacted]"))
    }

    @Test @MainActor func permissionBlocksWriteSupportUsefulAgentLogEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-agent-permission-log-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        store.appendPermissionBlock(
            feature: "Act mode",
            permission: "Accessibility",
            message: "Accessibility permission is required before Act mode can click, type, or press keys.",
            nextStep: "Enable Voiyce in Privacy & Security > Accessibility."
        )

        let event = try #require(store.events.first)
        let exportURL = try #require(store.exportSupportBundle())
        let exported = try String(contentsOf: exportURL, encoding: .utf8)

        #expect(event.category == .errors)
        #expect(event.status == .failed)
        #expect(event.title == "Permission blocked")
        #expect(event.summary.contains("Act mode"))
        #expect(event.summary.contains("Accessibility permission is required"))
        #expect(event.details.contains { $0.key == "Feature" && $0.value == "Act mode" })
        #expect(event.details.contains { $0.key == "Permission" && $0.value == "Accessibility" })
        #expect(event.details.contains { $0.key == "Next step" && $0.value == "Enable Voiyce in Privacy & Security > Accessibility." })
        #expect(exported.contains("Permission blocked"))
        #expect(exported.contains("Act mode"))
        #expect(exported.contains("Accessibility"))
        #expect(exported.contains("Next step"))
        #expect(!exported.contains("Computer Use"))
    }

    @Test @MainActor func serviceFailuresWriteSupportUsefulAgentLogEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-agent-service-failure-log-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        store.appendServiceFailure(
            feature: "Talk Mode",
            service: TalkModeRecoveryCopy.serviceName,
            statusCode: 429,
            message: TalkModeRecoveryCopy.requestFailed(statusCode: 429),
            nextStep: TalkModeRecoveryCopy.serviceFailureNextStep(statusCode: 429)
        )

        let event = try #require(store.events.first)
        let exportURL = try #require(store.exportSupportBundle())
        let exported = try String(contentsOf: exportURL, encoding: .utf8)

        #expect(event.category == .errors)
        #expect(event.status == .failed)
        #expect(event.title == "Quota or rate limit")
        #expect(event.summary.contains("Talk Mode"))
        #expect(event.summary.contains("rate-limited"))
        #expect(event.details.contains { $0.key == "Feature" && $0.value == "Talk Mode" })
        #expect(event.details.contains { $0.key == "Service" && $0.value == TalkModeRecoveryCopy.serviceName })
        #expect(event.details.contains { $0.key == "Upstream status" && $0.value == "HTTP 429" })
        #expect(event.details.contains { $0.key == "Next step" && $0.value == TalkModeRecoveryCopy.serviceFailureNextStep(statusCode: 429) })
        #expect(exported.contains("Quota or rate limit"))
        #expect(exported.contains(TalkModeRecoveryCopy.serviceName))
        #expect(exported.contains("HTTP 429"))
        #expect(exported.contains("Next step"))
        #expect(!exported.localizedCaseInsensitiveContains("OpenAI"))
        #expect(!exported.localizedCaseInsensitiveContains("backend"))
    }

    @Test @MainActor func usageLimitServiceFailuresAreLoggedAsQuotaEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-agent-usage-limit-log-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        store.appendServiceFailure(
            feature: "Act mode",
            service: "Act mode service",
            statusCode: 402,
            message: ActModeRecoveryCopy.accountUsageLimit,
            nextStep: ActModeRecoveryCopy.serviceFailureNextStep(statusCode: 402)
        )

        let event = try #require(store.events.first)
        let exportURL = try #require(store.exportSupportBundle())
        let exported = try String(contentsOf: exportURL, encoding: .utf8)

        #expect(event.category == .errors)
        #expect(event.status == .failed)
        #expect(event.title == "Quota or rate limit")
        #expect(event.summary.contains("Act mode"))
        #expect(event.summary.contains("current Act limit"))
        #expect(event.details.contains { $0.key == "Upstream status" && $0.value == "HTTP 402" })
        #expect(event.details.contains { $0.key == "Next step" && $0.value.contains("Try again later") })
        #expect(exported.contains("Quota or rate limit"))
        #expect(exported.contains("HTTP 402"))
        #expect(!exported.contains(BackendUsageLimitCopy.supportEmail))
        #expect(!exported.localizedCaseInsensitiveContains("backend"))
        #expect(!exported.localizedCaseInsensitiveContains("billing credits"))
    }

    @Test @MainActor func actSafetyChecksWriteRecoverableAgentLogEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-act-safety-check-log-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        let message = ActModeRecoveryCopy.safetyCheckCannotResume("The action may send data externally.")
        store.appendActSafetyCheckStopped(
            message: message,
            checks: [
                AgentLogEventDetail(key: "external_action", value: "The action may send data externally.")
            ],
            nextStep: ActModeRecoveryCopy.safetyCheckNextStep
        )

        let event = try #require(store.events.first)
        let exportURL = try #require(store.exportSupportBundle())
        let exported = try String(contentsOf: exportURL, encoding: .utf8)

        #expect(event.category == .actions)
        #expect(event.status == .failed)
        #expect(event.title == "Act mode safety check stopped")
        #expect(event.summary.contains("Act stopped at a safety check"))
        #expect(event.summary.contains("Stop this run"))
        #expect(event.details.contains { $0.key == "external_action" && $0.value.contains("send data externally") })
        #expect(event.details.contains { $0.key == "Next step" && $0.value == ActModeRecoveryCopy.safetyCheckNextStep })
        #expect(exported.contains("Act mode safety check stopped"))
        #expect(exported.contains("Next step"))
        #expect(!exported.localizedCaseInsensitiveContains("OpenAI"))
        #expect(!exported.localizedCaseInsensitiveContains("Computer Use"))
        #expect(!exported.localizedCaseInsensitiveContains("backend"))
    }

    @Test @MainActor func actModeAccessibilityDenialFailsSafelyAndWritesPermissionEvent() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-act-accessibility-denial-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        let agent = ComputerUseAgent(
            accessTokenProvider: { "unit-test-token" },
            accessibilityTrusted: { false },
            screenshotProvider: {
                ComputerScreenshot(imageBase64: "AA==", width: 1, height: 1)
            },
            eventStore: store
        )

        let result = await agent.run(task: "Click the current button", safetyMode: .normal)

        #expect(!result.ok)
        #expect(result.message == ActModeRecoveryCopy.accessibilityPermissionRequired)
        #expect(result.data?["requires"] == "accessibility_permission")
        #expect(result.data?["next_step"] == ActModeRecoveryCopy.accessibilityNextStep)

        let event = try #require(store.events.first { event in
            event.title == "Permission blocked"
                && event.details.contains { $0.key == "Permission" && $0.value == "Accessibility" }
        })
        #expect(event.status == .failed)
        #expect(event.summary.contains("Act mode"))
        #expect(event.details.contains { $0.key == "Next step" && $0.value.contains("Privacy & Security > Accessibility") })
    }

    @Test @MainActor func actModeScreenRecordingDenialFailsSafelyAndWritesPermissionEvent() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-act-screen-denial-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        let agent = ComputerUseAgent(
            accessTokenProvider: { "unit-test-token" },
            accessibilityTrusted: { true },
            screenshotProvider: { nil },
            eventStore: store
        )

        let result = await agent.run(task: "Look at the current screen", safetyMode: .normal)

        #expect(!result.ok)
        #expect(result.message == ActModeRecoveryCopy.screenRecordingPermissionRequired)
        #expect(result.data?["requires"] == "screen_recording_permission")
        #expect(result.data?["next_step"] == ActModeRecoveryCopy.screenRecordingNextStep)

        let event = try #require(store.events.first { event in
            event.title == "Permission blocked"
                && event.details.contains { $0.key == "Permission" && $0.value == "Screen Recording" }
        })
        #expect(event.status == .failed)
        #expect(event.summary.contains("Act mode"))
        #expect(event.details.contains { $0.key == "Next step" && $0.value == ActModeRecoveryCopy.screenRecordingNextStep })
    }

    @Test @MainActor func computerUseFailuresReturnStructuredNextSteps() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-act-next-step-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        let emptyTaskAgent = ComputerUseAgent(
            accessTokenProvider: { "unit-test-token" },
            accessibilityTrusted: { true },
            screenshotProvider: { ComputerScreenshot(imageBase64: "AA==", width: 1, height: 1) },
            eventStore: store
        )
        let emptyTaskResult = await emptyTaskAgent.run(task: "   ", safetyMode: AgentSafetyMode.normal)
        #expect(!emptyTaskResult.ok)
        #expect(emptyTaskResult.data?["next_step"] == ActModeRecoveryCopy.taskRequiredNextStep)

        let signedOutAgent = ComputerUseAgent(
            accessTokenProvider: { throw URLError(.userAuthenticationRequired) },
            accessibilityTrusted: { true },
            screenshotProvider: { ComputerScreenshot(imageBase64: "AA==", width: 1, height: 1) },
            eventStore: store
        )
        let signedOutResult = await signedOutAgent.run(task: "Click Settings.", safetyMode: AgentSafetyMode.normal)
        #expect(!signedOutResult.ok)
        #expect(signedOutResult.data?["requires"] == "auth")
        #expect(signedOutResult.data?["next_step"] == ActModeRecoveryCopy.authenticationNextStep)

        var screenshots = [
            ComputerScreenshot(imageBase64: "first-screen", width: 1200, height: 800)
        ]
        let screenCaptureFailureAgent = ComputerUseAgent(
            accessTokenProvider: { "unit-test-token" },
            accessibilityTrusted: { true },
            screenshotProvider: {
                screenshots.isEmpty ? nil : screenshots.removeFirst()
            },
            stepRequester: { _, _ in
                ComputerUseStepResponse(
                    responseID: "resp_1",
                    message: "Clicking.",
                    computerCalls: [
                        ComputerUseCall(
                            callID: "call_1",
                            actions: [ComputerUseAction(type: "click", x: 10, y: 20)],
                            pendingSafetyChecks: []
                        )
                    ]
                )
            },
            localActionRecorder: { _ in },
            eventStore: store,
            maxSteps: 1
        )
        let screenCaptureFailure = await screenCaptureFailureAgent.run(task: "Click Settings.", safetyMode: AgentSafetyMode.normal)
        #expect(!screenCaptureFailure.ok)
        #expect(screenCaptureFailure.message == ActModeRecoveryCopy.screenCaptureAfterActionFailed)
        #expect(screenCaptureFailure.data?["next_step"] == ActModeRecoveryCopy.screenCaptureAfterActionFailedNextStep)

        let safetyCheckAgent = ComputerUseAgent(
            accessTokenProvider: { "unit-test-token" },
            accessibilityTrusted: { true },
            screenshotProvider: { ComputerScreenshot(imageBase64: "AA==", width: 1, height: 1) },
            stepRequester: { _, _ in
                ComputerUseStepResponse(
                    responseID: "resp_1",
                    message: "Needs safety check.",
                    computerCalls: [
                        ComputerUseCall(
                            callID: "call_1",
                            actions: [],
                            pendingSafetyChecks: [
                                ComputerUseSafetyCheck(id: "safe_1", code: "external_action", message: "This may send data externally.")
                            ]
                        )
                    ]
                )
            },
            eventStore: store
        )
        let safetyCheckResult = await safetyCheckAgent.run(task: "Submit the form.", safetyMode: AgentSafetyMode.normal)
        #expect(!safetyCheckResult.ok)
        #expect(safetyCheckResult.data?["requires"] == "new_act_request")
        #expect(safetyCheckResult.data?["next_step"] == ActModeRecoveryCopy.safetyCheckNextStep)
    }

    @Test @MainActor func computerUseLoopSendsScreenshotsExecutesAllowedActionsAndContinues() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-computer-use-loop-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        var screenshots = [
            ComputerScreenshot(imageBase64: "first-screen", width: 1200, height: 800),
            ComputerScreenshot(imageBase64: "second-screen", width: 1200, height: 800)
        ]
        var requests: [(request: ComputerUseStepRequest, token: String)] = []
        let agent = ComputerUseAgent(
            accessTokenProvider: { "unit-test-token" },
            accessibilityTrusted: { true },
            screenshotProvider: {
                screenshots.isEmpty ? nil : screenshots.removeFirst()
            },
            stepRequester: { request, token in
                requests.append((request, token))
                if requests.count == 1 {
                    return ComputerUseStepResponse(
                        responseID: "resp_1",
                        message: "I will capture the next screen.",
                        computerCalls: [
                            ComputerUseCall(
                                callID: "call_1",
                                actions: [ComputerUseAction(type: "screenshot")],
                                pendingSafetyChecks: []
                            )
                        ]
                    )
                }

                return ComputerUseStepResponse(
                    responseID: "resp_2",
                    message: "Done.",
                    computerCalls: []
                )
            },
            eventStore: store,
            maxSteps: 3
        )

        let result = await agent.run(task: "Inspect the current screen.", safetyMode: .normal)

        #expect(result.ok)
        #expect(result.message == "Done.")
        #expect(result.data?["actions"] == "0")
        #expect(result.data?["steps"] == "2")
        #expect(requests.count == 2)
        #expect(requests[0].token == "unit-test-token")
        #expect(requests[0].request.task == "Inspect the current screen.")
        #expect(requests[0].request.previousResponseID == nil)
        #expect(requests[0].request.callID == nil)
        #expect(requests[0].request.screenshotBase64 == "first-screen")
        #expect(requests[0].request.safetyMode == AgentSafetyMode.normal.rawValue)
        #expect(requests[1].request.task == nil)
        #expect(requests[1].request.previousResponseID == "resp_1")
        #expect(requests[1].request.callID == "call_1")
        #expect(requests[1].request.screenshotBase64 == "second-screen")
        #expect(screenshots.isEmpty)

        let planned = try #require(store.events.first { $0.title == "Act mode planned actions" })
        #expect(planned.details.contains { $0.key == "Action types" && $0.value == "screenshot" })

        let localAction = try #require(store.events.first { $0.title == "Act mode action" })
        #expect(localAction.status == .done)
        #expect(localAction.summary == "Captured the current screen for the next action.")

        let finished = try #require(store.events.first { $0.title == "Act mode finished" && $0.summary == "Done." })
        #expect(finished.details.contains { $0.key == "Steps" && $0.value == "2" })
    }

    @Test @MainActor func computerUseLocalActionSurfaceCoversMouseScrollHotkeyAndText() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-computer-use-action-surface-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
            ActionCursorOverlay.shared.setEventRecorder(nil)
        }

        let store = AgentEventStore(storageDirectory: directory)
        var screenshots = [
            ComputerScreenshot(
                imageBase64: "first-screen",
                width: 100,
                height: 100,
                displayFrame: CGRect(x: 10, y: 20, width: 200, height: 200)
            ),
            ComputerScreenshot(
                imageBase64: "second-screen",
                width: 100,
                height: 100,
                displayFrame: CGRect(x: 10, y: 20, width: 200, height: 200)
            )
        ]
        var localEvents: [ComputerUseLocalActionEvent] = []
        var cursorEvents: [ActionCursorOverlayEvent] = []
        var typedText: [String] = []
        var requests: [ComputerUseStepRequest] = []
        ActionCursorOverlay.shared.setEventRecorder { event in
            cursorEvents.append(event)
        }

        let agent = ComputerUseAgent(
            accessTokenProvider: { "unit-test-token" },
            accessibilityTrusted: { true },
            screenshotProvider: {
                screenshots.isEmpty ? nil : screenshots.removeFirst()
            },
            textTargetSafetyProvider: {
                .safe
            },
            stepRequester: { request, _ in
                requests.append(request)
                if requests.count == 1 {
                    return ComputerUseStepResponse(
                        responseID: "resp_1",
                        message: "Running local actions.",
                        computerCalls: [
                            ComputerUseCall(
                                callID: "call_1",
                                actions: [
                                    ComputerUseAction(type: "click", x: 10, y: 20, button: "right"),
                                    ComputerUseAction(type: "double_click", x: 15, y: 25),
                                    ComputerUseAction(type: "scroll", scrollX: 12, scrollY: -48),
                                    ComputerUseAction(type: "keypress", keys: ["command+k"]),
                                    ComputerUseAction(type: "type", text: "launch-ready text")
                                ],
                                pendingSafetyChecks: []
                            )
                        ]
                    )
                }

                return ComputerUseStepResponse(responseID: "resp_2", message: "Done.", computerCalls: [])
            },
            localActionRecorder: { event in
                localEvents.append(event)
            },
            textInjectionHandler: { text in
                typedText.append(text)
            },
            eventStore: store,
            maxSteps: 2
        )

        let result = await agent.run(task: "Exercise local action surface.", safetyMode: .normal)

        #expect(result.ok)
        #expect(result.data?["actions"] == "5")
        #expect(requests.count == 2)
        #expect(typedText == ["launch-ready text"])
        #expect(cursorEvents.first?.kind == .beginActMode)
        #expect(cursorEvents.contains { $0.kind == .move && $0.status == "Looking" })
        #expect(cursorEvents.contains { $0.kind == .move && $0.status == "Clicking" })
        #expect(cursorEvents.contains { $0.kind == .move && $0.status == "Scrolling" })
        #expect(cursorEvents.contains { $0.kind == .move && $0.status == "Pressing keys" })
        #expect(cursorEvents.contains { $0.kind == .move && $0.status == "Typing" })
        #expect(cursorEvents.contains { $0.kind == .endActMode })

        let rightMouseDown = try #require(localEvents.first { event in
            event.kind == .mouseDown && event.mouseButton == "right"
        })
        #expect(rightMouseDown.point == CGPoint(x: 30, y: 60))

        let leftMouseDowns = localEvents.filter { event in
            event.kind == .mouseDown && event.mouseButton == "left"
        }
        #expect(leftMouseDowns.count == 2)
        #expect(leftMouseDowns.allSatisfy { $0.point == CGPoint(x: 40, y: 70) })

        let scroll = try #require(localEvents.first { $0.kind == .scroll })
        #expect(scroll.scrollX == 12)
        #expect(scroll.scrollY == -48)

        let keyDown = try #require(localEvents.first { $0.kind == .keyDown })
        let keyUp = try #require(localEvents.first { $0.kind == .keyUp })
        #expect(keyDown.keyCode == 0x28)
        #expect(keyUp.keyCode == 0x28)
        #expect(CGEventFlags(rawValue: keyDown.flags).contains(.maskCommand))
        #expect(CGEventFlags(rawValue: keyUp.flags).contains(.maskCommand))

        let planned = try #require(store.events.first { $0.title == "Act mode planned actions" })
        #expect(planned.details.contains { detail in
            detail.key == "Action types"
                && detail.value == "click, double_click, scroll, keypress, type"
        })
    }

    @Test @MainActor func nativeVoiyceActionsKeepActionCursorVisibleDuringNavigation() async throws {
        var cursorEvents: [ActionCursorOverlayEvent] = []
        ActionCursorOverlay.shared.setEventRecorder { event in
            cursorEvents.append(event)
        }
        defer {
            ActionCursorOverlay.shared.setEventRecorder(nil)
        }

        let appState = AppState()
        appState.selectedTab = .dashboard

        let result = await NativeActExecutor.shared.openVoiyceSection("settings", appState: appState)

        #expect(result.ok)
        #expect(appState.selectedTab == .settings)
        #expect(cursorEvents.first?.kind == .beginActMode)
        #expect(cursorEvents.contains { $0.kind == .move && $0.status == "Opening Settings" })
        #expect(cursorEvents.contains { $0.kind == .endActMode })
        #expect(cursorEvents.contains { event in
            event.kind == .hide && event.delay == 0.45
        })
    }

    @Test @MainActor func actModeCancellationStopsBeforeActionLoopAndWritesCancelledEvent() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-act-cancellation-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = AgentEventStore(storageDirectory: directory)
        let agent = ComputerUseAgent(
            accessTokenProvider: { "unit-test-token" },
            accessibilityTrusted: { true },
            screenshotProvider: {
                ComputerScreenshot(imageBase64: "AA==", width: 1, height: 1)
            },
            eventStore: store,
            cancellationCheck: {
                throw CancellationError()
            }
        )

        let result = await agent.run(task: "Click a button", safetyMode: .normal)

        #expect(!result.ok)
        #expect(result.message == "Act command stopped.")
        #expect(result.data?["status"] == "cancelled")
        #expect(result.data?["next_step"] == ActModeRecoveryCopy.cancelledNextStep)
        #expect(!store.events.contains { $0.title == "Act mode started" })

        let event = try #require(store.events.first { $0.title == "Act mode stopped" })
        #expect(event.category == .actions)
        #expect(event.status == .cancelled)
        #expect(event.summary.contains("stopped before it finished"))
        #expect(event.details.contains { $0.key == "Next step" && $0.value == ActModeRecoveryCopy.cancelledNextStep })
    }

    @Test @MainActor func actionCursorOverlayPolicyDoesNotStealFocusOrMouseInput() throws {
        let policy = ActionCursorOverlay.panelPolicy

        #expect(policy.styleMask.contains(.borderless))
        #expect(policy.styleMask.contains(.nonactivatingPanel))
        #expect(policy.ignoresMouseEvents)
        #expect(!policy.isOpaque)
        #expect(policy.level.rawValue == NSWindow.Level.screenSaver.rawValue)
        #expect(policy.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(policy.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(policy.collectionBehavior.contains(.stationary))
    }

    @Test func actionCursorLeadTimingGivesVisibleBeatBeforeLocalActions() throws {
        #expect(ActActionTiming.cursorLeadDelayNanoseconds >= 100_000_000)
        #expect(ActActionTiming.shortCursorLeadDelayNanoseconds >= 60_000_000)
        #expect(ActActionTiming.shortCursorLeadDelayNanoseconds < ActActionTiming.cursorLeadDelayNanoseconds)
        #expect(ActionCursorAnimationTiming.moveDuration >= 0.12)
        #expect(ActionCursorAnimationTiming.moveDuration <= 0.35)
    }

    @Test @MainActor func actionCursorPresentationPolicyOnlyShowsDuringActOrPreview() throws {
        let policy = ActionCursorOverlay.presentationPolicy

        #expect(!policy.canPresent(isActModeActive: false, isPreviewModeEnabled: false))
        #expect(policy.canPresent(isActModeActive: true, isPreviewModeEnabled: false))
        #expect(policy.canPresent(isActModeActive: false, isPreviewModeEnabled: true))
    }

    @Test func actionCursorGeometryClampsBadgeInsideVisibleDisplay() throws {
        let visibleFrame = CGRect(x: 1440, y: -120, width: 1280, height: 780)
        let badgeSize = CGSize(width: 216, height: 58)

        let rightEdgeOrigin = ActionCursorGeometry.clampedBadgeOrigin(
            for: CGPoint(x: 2698, y: 20),
            size: badgeSize,
            visibleFrame: visibleFrame
        )
        #expect(rightEdgeOrigin.x == visibleFrame.maxX - badgeSize.width - 14)
        #expect(rightEdgeOrigin.y >= visibleFrame.minY + 14)

        let leftEdgeOrigin = ActionCursorGeometry.clampedBadgeOrigin(
            for: CGPoint(x: 1400, y: -110),
            size: badgeSize,
            visibleFrame: visibleFrame
        )
        #expect(leftEdgeOrigin.x == visibleFrame.minX + 14)
        #expect(leftEdgeOrigin.y == visibleFrame.minY + 14)
    }

    @Test func computerUseCoordinateMapperUsesCapturedDisplayFrameForMultiDisplayScreenshots() throws {
        let screenshot = ComputerScreenshot(
            imageBase64: "AA==",
            width: 800,
            height: 450,
            displayFrame: CGRect(x: 1440, y: -120, width: 1600, height: 900)
        )

        let frame = ComputerUseCoordinateMapper.displayFrame(
            for: screenshot,
            fallbackFrame: CGRect(x: 0, y: 0, width: 800, height: 450)
        )
        let point = ComputerUseCoordinateMapper.point(x: 400, y: 225, screenshot: screenshot, displayFrame: frame)

        #expect(point.x == 2240)
        #expect(point.y == 330)
    }

    @Test func computerUseCoordinateMapperFallsBackWhenScreenshotHasNoDisplayFrame() throws {
        let screenshot = ComputerScreenshot(imageBase64: "AA==", width: 1000, height: 500)
        let frame = ComputerUseCoordinateMapper.displayFrame(
            for: screenshot,
            fallbackFrame: CGRect(x: 20, y: 40, width: 2000, height: 1000)
        )
        let point = ComputerUseCoordinateMapper.point(x: 250, y: 125, screenshot: screenshot, displayFrame: frame)

        #expect(point.x == 520)
        #expect(point.y == 290)
    }

    @Test @MainActor func focusHighlightOverlayPoliciesMatchDrawingAndPassiveGuideRoles() throws {
        let selectionPolicy = FocusHighlightOverlay.panelPolicy
        let guidePolicy = AgentVisualGuideOverlay.panelPolicy

        #expect(selectionPolicy.styleMask.contains(.borderless))
        #expect(selectionPolicy.styleMask.contains(.nonactivatingPanel))
        #expect(!selectionPolicy.ignoresMouseEvents)
        #expect(!selectionPolicy.isOpaque)
        #expect(selectionPolicy.level.rawValue == NSWindow.Level.screenSaver.rawValue)
        #expect(selectionPolicy.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(selectionPolicy.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(selectionPolicy.collectionBehavior.contains(.stationary))

        #expect(guidePolicy.styleMask.contains(.borderless))
        #expect(guidePolicy.styleMask.contains(.nonactivatingPanel))
        #expect(guidePolicy.ignoresMouseEvents)
        #expect(!guidePolicy.isOpaque)
        #expect(guidePolicy.level.rawValue == NSWindow.Level.screenSaver.rawValue)
        #expect(guidePolicy.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(guidePolicy.collectionBehavior.contains(.fullScreenAuxiliary))
        #expect(guidePolicy.collectionBehavior.contains(.stationary))
    }

    @Test func focusHighlightRectangleGeometryHandlesReverseDragAndScreenCoordinates() throws {
        let screenFrame = CGRect(x: 100, y: 50, width: 1200, height: 800)
        let annotation = try #require(FocusHighlightGeometry.rectangleAnnotation(
            screenFrame: screenFrame,
            start: CGPoint(x: 320, y: 260),
            end: CGPoint(x: 120, y: 110)
        ))

        #expect(annotation.mode == .rectangle)
        #expect(annotation.region == CGRect(x: 220, y: 590, width: 200, height: 150))
        #expect(annotation.points.isEmpty)
        #expect(FocusHighlightGeometry.rectangleAnnotation(
            screenFrame: screenFrame,
            start: CGPoint(x: 10, y: 10),
            end: CGPoint(x: 20, y: 20)
        ) == nil)
    }

    @Test func focusHighlightFreeformGeometryPadsRegionAndPreservesMarkedPoints() throws {
        let screenFrame = CGRect(x: -500, y: 100, width: 1000, height: 700)
        let points = [
            CGPoint(x: 160, y: 240),
            CGPoint(x: 200, y: 265),
            CGPoint(x: 260, y: 260)
        ]
        let annotation = try #require(FocusHighlightGeometry.freeformAnnotation(
            mode: .paint,
            screenFrame: screenFrame,
            points: points
        ))

        #expect(annotation.mode == .paint)
        #expect(annotation.region == CGRect(x: -358, y: 517, width: 136, height: 61))
        #expect(annotation.points == [
            CGPoint(x: -340, y: 560),
            CGPoint(x: -300, y: 535),
            CGPoint(x: -240, y: 540)
        ])
        #expect(FocusHighlightGeometry.freeformAnnotation(
            mode: .underline,
            screenFrame: screenFrame,
            points: [CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2)]
        ) == nil)
    }

    @Test func focusRegionCropRectScalesClipsAndRejectsOutOfDisplayRegions() throws {
        let displayFrame = CGRect(x: -500, y: 100, width: 1000, height: 700)
        let imageSize = CGSize(width: 2000, height: 1400)

        let centeredCrop = try #require(ScreenContextProvider.focusRegionCropRect(
            region: CGRect(x: -250, y: 450, width: 100, height: 80),
            displayFrame: displayFrame,
            imageSize: imageSize
        ))
        #expect(centeredCrop == CGRect(x: 500, y: 540, width: 200, height: 160))

        let clippedCrop = try #require(ScreenContextProvider.focusRegionCropRect(
            region: CGRect(x: 450, y: 760, width: 200, height: 100),
            displayFrame: displayFrame,
            imageSize: imageSize
        ))
        #expect(clippedCrop == CGRect(x: 1900, y: 0, width: 100, height: 80))

        #expect(ScreenContextProvider.focusRegionCropRect(
            region: CGRect(x: 700, y: 900, width: 50, height: 50),
            displayFrame: displayFrame,
            imageSize: imageSize
        ) == nil)
    }

    @Test func focusedRegionDisplaySelectionPrefersRegionDisplayThenMainDisplay() throws {
        let mainID = CGDirectDisplayID(10)
        let secondaryID = CGDirectDisplayID(20)
        let candidates = [
            ScreenContextProvider.DisplayCandidate(
                displayID: mainID,
                frame: CGRect(x: 0, y: 0, width: 1440, height: 900)
            ),
            ScreenContextProvider.DisplayCandidate(
                displayID: secondaryID,
                frame: CGRect(x: 1440, y: 0, width: 1280, height: 720)
            )
        ]

        let secondarySelection = ScreenContextProvider.bestDisplay(
            from: candidates,
            preferredRegion: CGRect(x: 1800, y: 220, width: 140, height: 80),
            mainDisplayID: mainID
        )
        #expect(secondarySelection?.displayID == secondaryID)

        let overlappingSelection = ScreenContextProvider.bestDisplay(
            from: candidates,
            preferredRegion: CGRect(x: 1360, y: 100, width: 160, height: 100),
            mainDisplayID: mainID
        )
        #expect(overlappingSelection?.displayID == mainID)

        let fallbackSelection = ScreenContextProvider.bestDisplay(
            from: candidates,
            preferredRegion: nil,
            mainDisplayID: mainID
        )
        #expect(fallbackSelection?.displayID == mainID)
    }

    @Test @MainActor func focusHighlightSelectionAndClearPersistStateAndAgentLogEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-focus-highlight-log-test-\(UUID().uuidString)", isDirectory: true)
        let store = AgentEventStore(storageDirectory: directory)
        defer {
            FocusHighlightOverlay.shared.clear(eventStore: store)
            try? FileManager.default.removeItem(at: directory)
        }

        let annotation = FocusMarkAnnotation(
            mode: .underline,
            screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            region: CGRect(x: 120, y: 280, width: 360, height: 44),
            points: [
                CGPoint(x: 140, y: 302),
                CGPoint(x: 460, y: 305)
            ]
        )

        FocusHighlightOverlay.shared.completeSelection(
            annotation,
            eventStore: store,
            showGuide: false
        )

        #expect(FocusHighlightOverlay.shared.lastRegion == annotation.region)
        #expect(FocusHighlightOverlay.shared.lastAnnotation?.mode == .underline)

        let markedEvent = try #require(store.events.first { $0.title == "Underline focus marked" })
        #expect(markedEvent.category == .memory)
        #expect(markedEvent.status == .done)
        #expect(markedEvent.symbol == "underline")
        #expect(markedEvent.summary.contains("next screen-aware request"))
        #expect(markedEvent.details.contains { $0.key == "Region" && $0.value == "120, 280, 360x44" })
        #expect(markedEvent.details.contains { $0.key == "Mode" && $0.value == "Underline" })

        FocusHighlightOverlay.shared.clear(eventStore: store)

        #expect(FocusHighlightOverlay.shared.lastRegion == nil)
        #expect(FocusHighlightOverlay.shared.lastAnnotation == nil)

        let clearedEvent = try #require(store.events.first { $0.title == "Focus region cleared" })
        #expect(clearedEvent.category == .memory)
        #expect(clearedEvent.status == .cancelled)
        #expect(clearedEvent.summary == "The saved screen focus region was cleared.")
    }

    @Test @MainActor func memoryErrorsWriteSupportUsefulAgentLogEvents() throws {
        let id = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-memory-error-log-test-\(id)", isDirectory: true)
        let suiteName = "voiyce-memory-error-log-test-\(id)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let eventStore = AgentEventStore(
            storageDirectory: directory.appendingPathComponent("Events", isDirectory: true)
        )
        let memoryStore = AgentLongTermMemoryStore(
            storageDirectory: directory.appendingPathComponent("Memory", isDirectory: true),
            userDefaults: defaults,
            createVaultOnInit: false,
            eventStore: eventStore
        )

        let blockedVaultPath = directory.appendingPathComponent("blocked-vault")
        try Data("not a directory".utf8).write(to: blockedVaultPath, options: .atomic)

        memoryStore.setVault(url: blockedVaultPath)

        let event = try #require(eventStore.events.first { event in
            event.title == "Memory error"
                && event.details.contains { $0.key == "Operation" && $0.value == "Create memory vault" }
        })
        let exportURL = try #require(eventStore.exportSupportBundle())
        let exported = try String(contentsOf: exportURL, encoding: .utf8)

        #expect(event.category == .errors)
        #expect(event.status == .failed)
        #expect(event.summary.contains("Create memory vault"))
        #expect(event.details.contains { $0.key == "Path" && $0.value == blockedVaultPath.path })
        #expect(event.details.contains { $0.key == "Next step" && $0.value == "Choose a writable vault folder in Settings." })
        #expect(!event.summary.localizedCaseInsensitiveContains("couldn"))
        #expect(!event.summary.localizedCaseInsensitiveContains("operation not permitted"))
        #expect(event.summary.contains("Voiyce could not finish this memory operation."))
        #expect(exported.contains("Memory error"))
        #expect(exported.contains("Create memory vault"))
        #expect(exported.contains("Next step"))
    }

    @MainActor
    private func makeIsolatedMemoryStore() throws -> (
        store: AgentLongTermMemoryStore,
        directory: URL,
        suiteName: String,
        eventStore: AgentEventStore
    ) {
        let id = UUID().uuidString
        let suiteName = "voiyce-memory-test-\(id)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce-memory-test-\(id)", isDirectory: true)
        let eventStore = AgentEventStore(
            storageDirectory: directory.appendingPathComponent("AgentEvents", isDirectory: true)
        )
        let store = AgentLongTermMemoryStore(
            storageDirectory: directory,
            userDefaults: defaults,
            createVaultOnInit: false,
            eventStore: eventStore
        )
        store.setVault(url: directory.appendingPathComponent("Vault", isDirectory: true))
        return (store, directory, suiteName, eventStore)
    }

    private func cleanupMemoryStore(directory: URL, suiteName: String) {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    private func fileCount(in directory: URL) -> Int {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).count) ?? 0
    }
}
