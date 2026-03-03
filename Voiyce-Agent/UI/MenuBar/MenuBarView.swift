//
//  MenuBarView.swift
//  Voiyce-Agent
//

import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Recording state
            HStack(spacing: 8) {
                StatusIndicator(recordingState: appState.recordingState)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Dashboard button
            Button {
                appState.selectedTab = .dashboard
                activateApp()
            } label: {
                Label("Dashboard", systemImage: "house")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // Settings button
            Button {
                appState.selectedTab = .settings
                activateApp()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()

            // Quit button
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
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Voiyce Agent" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
