//
//  ContentView.swift
//  Voiyce-Agent
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView(selectedTab: $appState.selectedTab)
                .navigationSplitViewColumnWidth(AppTheme.sidebarWidth)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.backgroundPrimary)
        }
        .navigationSplitViewStyle(.prominentDetail)
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedTab {
        case .dashboard:
            DashboardView()
        case .transcripts:
            TranscriptsView()
        case .agent:
            AgentChatView()
        case .integrations:
            IntegrationsView()
        case .settings:
            SettingsView()
        }
    }
}
