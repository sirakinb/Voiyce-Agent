//
//  SidebarView.swift
//  Voiyce-Agent
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    @Environment(AppState.self) private var appState
    @Environment(AuthenticationManager.self) private var authenticationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            if let logoURL = AppConstants.bundledResourceURL(named: "voiyce_logo", fileExtension: "png"),
               let logoImage = NSImage(contentsOf: logoURL) {
                Image(nsImage: logoImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 320)
                    .padding(.horizontal, 8)
                    .padding(.top, -30)
                    .padding(.bottom, -70)
            }

            // Navigation items
            VStack(spacing: 4) {
                ForEach(SidebarTab.allCases) { tab in
                    SidebarItem(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            accountSection

            // Dark grey ridges
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { _ in
                    AppTheme.ridge.frame(height: 1)
                    AppTheme.backgroundPrimary.frame(height: 3)
                }
            }
            .padding(.bottom, 4)

            // Recording state indicator
            HStack(spacing: 8) {
                StatusIndicator(recordingState: appState.recordingState)
            }
            .padding(AppTheme.cardPadding)
        }
        .frame(width: AppTheme.sidebarWidth)
        .background(GroovedBackground(base: AppTheme.backgroundSecondary))
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppTheme.ridge.frame(height: 1)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.18))
                        .frame(width: 34, height: 34)

                    Text(authenticationManager.currentUserInitials)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(authenticationManager.currentUserDisplayName)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    Text(authenticationManager.currentUserEmail)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }

            Button {
                Task {
                    await authenticationManager.signOut()
                    selectedTab = .settings
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 12, weight: .semibold))

                    Text(authenticationManager.isWorking ? "Signing Out..." : "Sign Out")
                        .font(AppTheme.captionFont)

                    Spacer()
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(authenticationManager.isWorking)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

// MARK: - SidebarItem

private struct SidebarItem: View {
    let tab: SidebarTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15))
                    .frame(width: 20)

                Text(tab.title)
                    .font(AppTheme.bodyFont)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textSecondary)
            .background(
                isSelected
                    ? AppTheme.accent.opacity(0.15)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
