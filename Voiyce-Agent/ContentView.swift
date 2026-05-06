//
//  ContentView.swift
//  Voiyce-Agent
//

import SwiftUI
import SwiftData
import InsForgeAuth

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthenticationManager.self) private var authenticationManager
    @Environment(BillingManager.self) private var billingManager
    @Environment(DictationCoordinator.self) private var dictationCoordinator
    @Environment(UsageTracker.self) private var usageTracker
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var appState = appState

        Group {
            if authenticationManager.isRestoringSession {
                loadingView
            } else if !authenticationManager.isAuthenticated {
                AuthView()
            } else if appState.isOnboardingComplete {
                NavigationSplitView {
                    SidebarView(selectedTab: $appState.selectedTab)
                        .navigationSplitViewColumnWidth(AppTheme.sidebarWidth)
                } detail: {
                    detailView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(GroovedBackground())
                }
                .navigationSplitViewStyle(.prominentDetail)
            } else {
                OnboardingView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .task {
            dictationCoordinator.configure(modelContext: modelContext)
            await authenticationManager.restoreSessionIfNeeded()
            refreshAccountScopedState()

            if authenticationManager.isAuthenticated {
                await billingManager.checkPentridgeSubscription()
                await billingManager.refreshStatus()
                appState.accessState = billingManager.accessState(isAuthenticated: true)
                presentDemoVideoIfNeeded()
            } else {
                billingManager.reset()
                appState.accessState = .signedOut
            }
        }
        .onOpenURL { url in
            Task {
                switch url.host?.lowercased() {
                case "auth":
                    await authenticationManager.handleAuthCallback(url)
                case AppConstants.billingCallbackHost:
                    await billingManager.handleCallback(url, isAuthenticated: authenticationManager.isAuthenticated)
                    appState.accessState = billingManager.accessState(isAuthenticated: authenticationManager.isAuthenticated)
                    appState.selectedTab = .dashboard
                default:
                    break
                }
            }
        }
        .onChange(of: authenticationManager.isAuthenticated) { _, isAuthenticated in
            Task {
                refreshAccountScopedState()

                if isAuthenticated {
                    await billingManager.checkPentridgeSubscription()
                    await billingManager.refreshStatus()
                    appState.accessState = billingManager.accessState(isAuthenticated: true)
                    presentDemoVideoIfNeeded()
                } else {
                    billingManager.reset()
                    appState.accessState = .signedOut
                }
            }
        }
        .onChange(of: authenticationManager.currentUser?.id) { _, _ in
            refreshAccountScopedState()
            presentDemoVideoIfNeeded()
        }
        .onChange(of: appState.isOnboardingComplete) { _, isComplete in
            if isComplete {
                presentDemoVideoIfNeeded()
            }
        }
        .sheet(isPresented: $appState.isDemoVideoPresented, onDismiss: markDemoVideoSeenForCurrentAccount) {
            DemoVideoSheet {
                markDemoVideoSeenForCurrentAccount()
                appState.isDemoVideoPresented = false
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedTab {
        case .dashboard:
            DashboardView()
        case .settings:
            SettingsView()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text("Restoring your session...")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            Text("Voiyce is checking for an existing InsForge sign-in before it enables the app.")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GroovedBackground())
    }

    private func refreshAccountScopedState() {
        let userID = authenticationManager.currentUser?.id
        usageTracker.configure(userID: userID)
        loadOnboardingForCurrentAccount(userID: userID)

        let todayStats = usageTracker.todayStats()
        appState.wordsToday = todayStats.words
        appState.dictationSessionsToday = todayStats.dictationSessions
    }

    private func loadOnboardingForCurrentAccount(userID: String?) {
        guard let userID else {
            appState.isOnboardingComplete = false
            appState.onboardingDiscoverySource = ""
            appState.onboardingRole = ""
            appState.onboardingPrivacyPreference = .unset
            return
        }

        let defaults = UserDefaults.standard
        appState.isOnboardingComplete = defaults.bool(
            forKey: AppConstants.accountScopedKey(AppConstants.onboardingCompleteKey, userID: userID)
        )
        appState.onboardingDiscoverySource = defaults.string(
            forKey: AppConstants.accountScopedKey(AppConstants.onboardingDiscoverySourceKey, userID: userID)
        ) ?? ""
        appState.onboardingRole = defaults.string(
            forKey: AppConstants.accountScopedKey(AppConstants.onboardingRoleKey, userID: userID)
        ) ?? ""

        if let persistedPrivacyPreference = defaults.string(
            forKey: AppConstants.accountScopedKey(AppConstants.onboardingPrivacyPreferenceKey, userID: userID)
        ),
           let privacyPreference = OnboardingPrivacyPreference(rawValue: persistedPrivacyPreference) {
            appState.onboardingPrivacyPreference = privacyPreference
        } else {
            appState.onboardingPrivacyPreference = .unset
        }
    }

    private func presentDemoVideoIfNeeded() {
        guard authenticationManager.isAuthenticated,
              appState.isOnboardingComplete,
              !appState.isDemoVideoPresented,
              let userID = authenticationManager.currentUser?.id else { return }

        let seenKey = AppConstants.accountScopedKey(AppConstants.demoVideoSeenKey, userID: userID)
        guard !UserDefaults.standard.bool(forKey: seenKey) else { return }

        UserDefaults.standard.set(true, forKey: seenKey)
        DispatchQueue.main.async {
            appState.isDemoVideoPresented = true
        }
    }

    private func markDemoVideoSeenForCurrentAccount() {
        guard let userID = authenticationManager.currentUser?.id else { return }
        UserDefaults.standard.set(
            true,
            forKey: AppConstants.accountScopedKey(AppConstants.demoVideoSeenKey, userID: userID)
        )
    }
}
