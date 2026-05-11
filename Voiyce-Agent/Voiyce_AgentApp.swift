//
//  Voiyce_AgentApp.swift
//  Voiyce-Agent
//

import SwiftUI
import SwiftData

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
                    permissionsManager.checkAllPermissions()
                    setupHotkeysIfNeeded()
                }
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

    private func setupHotkeysIfNeeded() {
        guard appState.isOnboardingComplete, !hotkeysConfigured else { return }

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
        hotkeyManager.onAgentStart = { [self] in
            appState.selectedTab = .agent
            appState.agentActivationNonce += 1
            activateMainWindow()
        }

        hotkeyManager.onAgentStop = {
            NotificationCenter.default.post(name: .voiyceAgentStopRequested, object: nil)
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
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let otherInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID }

        guard let existingInstance = otherInstances.first else {
            return false
        }

        if isRunningFromXcode() {
            let currentBundleURL = Bundle.main.bundleURL.standardizedFileURL
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

        print("[Voiyce_AgentApp] Duplicate app instance detected. Activating existing instance and terminating current process.")
        existingInstance.activate(options: [.activateAllWindows])

        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }

        return true
    }

    private func isRunningFromXcode() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["__XCODE_BUILT_PRODUCTS_DIR_PATHS"] != nil
            || environment["OS_ACTIVITY_DT_MODE"] == "YES"
    }
}

extension Notification.Name {
    static let voiyceAgentStopRequested = Notification.Name("voiyceAgentStopRequested")
}
