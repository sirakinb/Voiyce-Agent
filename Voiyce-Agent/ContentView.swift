//
//  ContentView.swift
//  Voiyce-Agent
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthenticationManager.self) private var authenticationManager
    @Environment(BillingManager.self) private var billingManager
    @Environment(DictationCoordinator.self) private var dictationCoordinator
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

            if authenticationManager.isAuthenticated {
                await billingManager.refreshStatus()
                appState.accessState = billingManager.accessState(isAuthenticated: true)
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
                if isAuthenticated {
                    await billingManager.refreshStatus()
                    appState.accessState = billingManager.accessState(isAuthenticated: true)
                } else {
                    billingManager.reset()
                    appState.accessState = .signedOut
                }
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
}
