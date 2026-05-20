//
//  Voiyce_AgentApp.swift
//  Voiyce-Agent
//

import AppKit
import SwiftUI
import SwiftData

enum AppMenuLaunchCopy {
    static let openDashboard = "Open Dashboard"
    static let openAgent = "Open Agent"
    static let openAgentLog = "Open Agent Log"
    static let openSettings = "Open Settings"
    static let focusTools = "Focus Tools"

    static let visibleStrings = [
        openDashboard,
        openAgent,
        openAgentLog,
        openSettings,
        focusTools
    ]
}

@main
struct Voiyce_AgentApp: App {
    @State private var appState = AppState()
    @State private var authenticationManager = AuthenticationManager()
    @State private var billingManager = BillingManager()
    @State private var permissionsManager = PermissionsManager()
    @State private var hotkeyManager = HotkeyManager()
    @State private var dictationCoordinator = DictationCoordinator()
    @State private var networkMonitor = NetworkMonitor()
    @State private var usageTracker = UsageTracker()
    @State private var hotkeysConfigured = false
    #if VOIYCE_PRO
    @State private var agentModeStoppedForSystemSleep: AgentMode?
    #endif
    private let owlOverlay = OwlOverlayPanel()

    var body: some Scene {
        WindowGroup("Voiyce") {
            ContentView()
                .environment(appState)
                .environment(authenticationManager)
                .environment(billingManager)
                .environment(permissionsManager)
                .environment(dictationCoordinator)
                .environment(networkMonitor)
                .environment(usageTracker)
                .onAppear {
                    guard !terminateIfDuplicateInstanceIsRunning() else { return }
                    loadPersistedState()
                    appState.restorePermissionReturnTargetIfNeeded()
                    permissionsManager.checkAllPermissions()
                    setupHotkeysIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    appState.restorePermissionReturnTargetIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    cleanupBeforeTermination()
                }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in
                    cleanupBeforeSystemSleep()
                }
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
                    handleWakeAfterSystemSleep()
                }
                #if VOIYCE_PRO
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
                    handleDisplayConfigurationChange()
                }
                #endif
                .onChange(of: appState.isOnboardingComplete) { _, isComplete in
                    if isComplete {
                        setupHotkeysIfNeeded()
                    } else {
                        hotkeyManager.teardown()
                        hotkeysConfigured = false
                        owlOverlay.hide()
                        appState.recordingState = .idle
                        appState.isDictationActive = false
                        appState.currentTranscript = ""
                    }
                }
                .onDisappear {
                    hotkeyManager.teardown()
                    hotkeysConfigured = false
                }
        }
        .modelContainer(for: [Transcript.self])
        .commands {
            CommandGroup(after: .appInfo) {
                Button(AppMenuLaunchCopy.openDashboard) {
                    navigateTo(.dashboard)
                }
                .keyboardShortcut("1", modifiers: [.command])

                #if VOIYCE_PRO
                Button(AppMenuLaunchCopy.openAgent) {
                    navigateTo(.agent)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button(AppMenuLaunchCopy.openAgentLog) {
                    navigateTo(.agentLog)
                }
                .keyboardShortcut("3", modifiers: [.command])
                #endif

                Button(AppMenuLaunchCopy.openSettings) {
                    navigateTo(.settings)
                }
                .keyboardShortcut(",", modifiers: [.command])

                #if VOIYCE_PRO
                Divider()

                Button(AppMenuLaunchCopy.focusTools) {
                    AgentFocusToolPaletteOverlay.shared.toggle()
                }
                #endif
            }
        }

        MenuBarExtra("Voiyce", systemImage: "mic.fill") {
            MenuBarView()
                .environment(appState)
                .environment(authenticationManager)
                .environment(billingManager)
        }
    }

    private func loadPersistedState() {
        let defaults = UserDefaults.standard

        appState.isOnboardingComplete = defaults.bool(forKey: AppConstants.onboardingCompleteKey)
        appState.onboardingDiscoverySource = defaults.string(
            forKey: AppConstants.onboardingDiscoverySourceKey
        ) ?? ""
        appState.onboardingRole = defaults.string(
            forKey: AppConstants.onboardingRoleKey
        ) ?? ""

        if let persistedPrivacyPreference = defaults.string(
            forKey: AppConstants.onboardingPrivacyPreferenceKey
        ),
           let privacyPreference = OnboardingPrivacyPreference(rawValue: persistedPrivacyPreference) {
            appState.onboardingPrivacyPreference = privacyPreference
        }

        let todayStats = usageTracker.todayStats()
        appState.wordsToday = todayStats.words
        appState.dictationSessionsToday = todayStats.dictationSessions
    }

    private func navigateTo(_ tab: SidebarTab) {
        appState.selectedTab = tab
        activateMainWindow()
    }

    private func stopLocalRuntimeBeforeInterruption() {
        hotkeyManager.teardown()
        hotkeysConfigured = false
        owlOverlay.hide()
    }

    private func cleanupBeforeTermination() {
        #if VOIYCE_PRO
        let wasAgentRunning = appState.isAgentRunning
        let stoppedAgentMode = appState.agentMode
        #endif

        stopLocalRuntimeBeforeInterruption()
        dictationCoordinator.cancelForAppTermination()
        appState.clearTransientRuntimeStateForTermination()

        #if VOIYCE_PRO
        RealtimeAgentBridge.shared.stop()
        RealtimeAgentServer.shared.stop()
        VideoDBAgentMemory.shared.stopLocalCaptureForTermination()

        if wasAgentRunning {
            AgentEventStore.shared.append(
                category: agentLogCategory(for: stoppedAgentMode),
                status: .done,
                symbol: "power",
                title: "Session stopped on app quit",
                summary: "Voiyce stopped \(stoppedAgentMode.title) mode before quitting.",
                details: [
                    AgentLogEventDetail(key: "Mode", value: stoppedAgentMode.title),
                    AgentLogEventDetail(key: "Reason", value: "App quit")
                ]
            )
        }
        #endif
    }

    private func cleanupBeforeSystemSleep() {
        #if VOIYCE_PRO
        let wasAgentRunning = appState.isAgentRunning
        let stoppedAgentMode = appState.agentMode
        if wasAgentRunning {
            agentModeStoppedForSystemSleep = stoppedAgentMode
        }
        #endif

        stopLocalRuntimeBeforeInterruption()
        dictationCoordinator.cancelForSystemSleep()
        appState.clearTransientRuntimeStateForSystemSleep()

        #if VOIYCE_PRO
        RealtimeAgentBridge.shared.stop()
        RealtimeAgentServer.shared.stop()
        VideoDBAgentMemory.shared.stopLocalCaptureForSystemSleep()

        if wasAgentRunning {
            AgentEventStore.shared.append(
                category: agentLogCategory(for: stoppedAgentMode),
                status: .done,
                symbol: "moon.zzz",
                title: "Session stopped for sleep",
                summary: "Voiyce stopped \(stoppedAgentMode.title) mode before the Mac slept.",
                details: [
                    AgentLogEventDetail(key: "Mode", value: stoppedAgentMode.title),
                    AgentLogEventDetail(key: "Reason", value: "System sleep")
                ]
            )
        }
        #endif
    }

    private func handleWakeAfterSystemSleep() {
        permissionsManager.checkAllPermissions()
        appState.restorePermissionReturnTargetIfNeeded()
        setupHotkeysIfNeeded()

        #if VOIYCE_PRO
        guard let stoppedMode = agentModeStoppedForSystemSleep else { return }
        agentModeStoppedForSystemSleep = nil
        AgentEventStore.shared.append(
            category: agentLogCategory(for: stoppedMode),
            status: .done,
            symbol: "sun.max",
            title: "Ready after wake",
            summary: "Voiyce is awake. Start \(stoppedMode.title) again when you want it to resume.",
            details: [
                AgentLogEventDetail(key: "Mode", value: stoppedMode.title),
                AgentLogEventDetail(key: "Active state", value: "Off")
            ]
        )
        #endif
    }

    #if VOIYCE_PRO
    private func handleDisplayConfigurationChange() {
        AgentFocusToolPaletteOverlay.shared.hide()
        ActionCursorOverlay.shared.handleDisplayConfigurationChange()
        AgentVisualGuideOverlay.shared.clear()
        FocusHighlightOverlay.shared.clearForDisplayConfigurationChange()

        let mode = appState.agentMode
        let wasRunning = appState.isAgentRunning
        guard DisplayConfigurationRecovery.shouldStopAgent(mode: mode, isAgentRunning: wasRunning) else {
            if wasRunning {
                AgentEventStore.shared.append(
                    category: agentLogCategory(for: mode),
                    status: .done,
                    symbol: "display.2",
                    title: "Display layout changed",
                    summary: "Voiyce detected a display change and cleared transient screen overlays.",
                    details: [
                        AgentLogEventDetail(key: "Mode", value: mode.title),
                        AgentLogEventDetail(key: "Action", value: "Continue with fresh screen context")
                    ]
                )
            }
            return
        }

        appState.isAgentRunning = false
        RealtimeAgentBridge.shared.stop()
        RealtimeAgentServer.shared.stop()
        Task {
            await VideoDBAgentMemory.shared.stop()
        }

        AgentEventStore.shared.append(
            category: agentLogCategory(for: mode),
            status: .cancelled,
            symbol: "display.2",
            title: "Act stopped after display change",
            summary: DisplayConfigurationRecovery.actStopSummary,
            details: [
                AgentLogEventDetail(key: "Mode", value: mode.title),
                AgentLogEventDetail(key: "Next step", value: DisplayConfigurationRecovery.actStopNextStep)
            ]
        )
    }

    private func agentLogCategory(for mode: AgentMode) -> AgentLogCategory {
        switch mode {
        case .off, .context:
            return .memory
        case .talk:
            return .voice
        case .act:
            return .actions
        }
    }
    #endif

    private func setupHotkeysIfNeeded() {
        guard !hotkeysConfigured else { return }

        // Wire dictation hotkey: hold Control to dictate
        hotkeyManager.onDictationStart = { [self] in
            let currentAccessState = billingManager.accessState(
                isAuthenticated: authenticationManager.isAuthenticated
            )
            appState.accessState = currentAccessState

            guard currentAccessState == .active else {
                appState.selectedTab = .dashboard
                activateMainWindow()
                return
            }

            appState.recordingState = .listening
            appState.currentTranscript = ""
            dictationCoordinator.startDictation { result in
                switch result {
                case .success:
                    appState.isDictationActive = true
                    appState.dictationSessionsToday += 1
                    owlOverlay.show()
                    usageTracker.addDictationSession()
                case .failure:
                    appState.recordingState = .idle
                    appState.isDictationActive = false
                }
            }
        }

        hotkeyManager.onDictationStop = { [self] in
            appState.recordingState = .processing
            appState.isDictationActive = false
            owlOverlay.showProcessing()
            dictationCoordinator.stopDictation { result in
                switch result {
                case .success(let transcript):
                    appState.currentTranscript = transcript

                    let words = transcript.split(separator: " ").count
                    if words > 0 {
                        appState.wordsToday += words
                        usageTracker.addWords(words)

                        let previousAccessState = appState.accessState
                        Task { @MainActor in
                            await billingManager.recordWordUsage(words)
                            appState.accessState = billingManager.accessState(
                                isAuthenticated: authenticationManager.isAuthenticated
                            )

                            if previousAccessState == .active && appState.accessState == .paymentRequired {
                                appState.selectedTab = .dashboard
                                activateMainWindow()
                            }
                        }
                    }
                case .failure:
                    break
                }

                appState.recordingState = .idle
                owlOverlay.hide()
            }
        }

        #if VOIYCE_PRO
        hotkeyManager.onAgentToggle = { [self] in
            let currentAccessState = billingManager.accessState(
                isAuthenticated: authenticationManager.isAuthenticated
            )
            appState.accessState = currentAccessState

            guard currentAccessState == .active else {
                appState.selectedTab = .dashboard
                activateMainWindow()
                return
            }

            appState.selectedTab = .agent
            appState.agentActivationNonce += 1
            activateMainWindow()
        }

        hotkeyManager.onFocusHighlight = {
            FocusHighlightOverlay.shared.beginSelection()
            AgentEventStore.shared.append(
                category: .memory,
                status: .done,
                symbol: "viewfinder",
                title: "Focus highlight started",
                summary: "Drag over the part of the screen Voiyce should use."
            )
        }

        hotkeyManager.onFocusPaint = {
            FocusHighlightOverlay.shared.beginSelection(mode: .paint)
            AgentEventStore.shared.append(
                category: .memory,
                status: .done,
                symbol: "paintbrush",
                title: "Focus paint started",
                summary: "Draw over the part of the screen Voiyce should use."
            )
        }

        hotkeyManager.onFocusUnderline = {
            FocusHighlightOverlay.shared.beginSelection(mode: .underline)
            AgentEventStore.shared.append(
                category: .memory,
                status: .done,
                symbol: "underline",
                title: "Focus underline started",
                summary: "Underline the part of the screen Voiyce should use."
            )
        }

        hotkeyManager.onFocusToolPalette = {
            AgentFocusToolPaletteOverlay.shared.toggle()
        }
        #endif

        hotkeyManager.setup()
        hotkeysConfigured = true
    }

    private func activateMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @discardableResult
    private func terminateIfDuplicateInstanceIsRunning() -> Bool {
        guard !AppConstants.isUITesting else {
            return false
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let currentBundleURL = Bundle.main.bundleURL.standardizedFileURL
        let installedBundleURL = URL(fileURLWithPath: "/Applications/Voiyce.app").standardizedFileURL
        let currentIsInstalledApp = currentBundleURL == installedBundleURL

        let otherInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID }

        guard !otherInstances.isEmpty else {
            return false
        }

        if currentIsInstalledApp {
            if let installedDuplicate = otherInstances.first(where: { $0.bundleURL?.standardizedFileURL == installedBundleURL }) {
                print("[Voiyce_AgentApp] Installed app duplicate detected. Activating existing installed instance and terminating current process.")
                installedDuplicate.activate(options: [.activateAllWindows])
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
                return true
            }

            print("[Voiyce_AgentApp] Installed app is running. Terminating non-installed duplicate instance(s).")
            terminate(otherInstances)
            return false
        }

        if let installedInstance = otherInstances.first(where: { $0.bundleURL?.standardizedFileURL == installedBundleURL }) {
            print("[Voiyce_AgentApp] Installed app is already running. Activating it and terminating this non-installed process.")
            installedInstance.activate(options: [.activateAllWindows])
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
            return true
        }

        if isRunningFromXcode() {
            let matchingInstances = otherInstances.filter {
                $0.bundleURL?.standardizedFileURL == currentBundleURL
            }

            if matchingInstances.isEmpty {
                print("[Voiyce_AgentApp] Another app instance is already running, but allowing launch because this session was started from Xcode.")
            } else {
                print("[Voiyce_AgentApp] Xcode relaunch detected. Terminating matching existing instance(s) and continuing startup.")
                matchingInstances.forEach { $0.terminate() }
            }

            return false
        }

        guard let existingInstance = otherInstances.first else {
            return false
        }

        print("[Voiyce_AgentApp] Duplicate app instance detected. Activating existing instance and terminating current process.")
        existingInstance.activate(options: [.activateAllWindows])

        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }

        return true
    }

    private func terminate(_ applications: [NSRunningApplication]) {
        for application in applications {
            application.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !application.isTerminated {
                    application.forceTerminate()
                }
            }
        }
    }

    private func isRunningFromXcode() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] != nil
            || environment["OS_ACTIVITY_DT_MODE"] == "YES"
    }
}

extension Notification.Name {
    static let voiyceAgentStopRequested = Notification.Name("voiyceAgentStopRequested")
    static let voiyceOpenTabRequested = Notification.Name("voiyceOpenTabRequested")
}
