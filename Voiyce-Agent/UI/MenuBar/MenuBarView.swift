//
//  MenuBarView.swift
//  Voiyce-Agent
//

import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthenticationManager.self) private var authenticationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Recording state
            HStack(spacing: 8) {
                StatusIndicator(recordingState: appState.recordingState)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(authenticationManager.accountStatusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(authenticationManager.isAuthenticated
                    ? authenticationManager.currentUserDisplayName
                    : "Open Voiyce to sign in")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                if authenticationManager.isAuthenticated && !authenticationManager.currentUserEmail.isEmpty {
                    Text(authenticationManager.currentUserEmail)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            Button {
                appState.selectedTab = authenticationManager.isAuthenticated ? .dashboard : .settings
                activateApp()
            } label: {
                Label(authenticationManager.isAuthenticated ? "Dashboard" : "Sign In", systemImage: authenticationManager.isAuthenticated ? "house" : "person.badge.key")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Button {
                appState.selectedTab = .settings
                activateApp()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()

            if authenticationManager.isAuthenticated {
                Button {
                    Task {
                        await authenticationManager.signOut()
                        appState.selectedTab = .settings
                        activateApp()
                    }
                } label: {
                    Label(authenticationManager.isWorking ? "Signing Out..." : "Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .foregroundStyle(AppTheme.accent)
                .disabled(authenticationManager.isWorking)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

                Divider()
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Voiyce", systemImage: "xmark.circle")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .padding(.vertical, 4)
    }

    private func activateApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
