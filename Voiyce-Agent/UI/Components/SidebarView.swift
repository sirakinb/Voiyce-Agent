//
//  SidebarView.swift
//  Voiyce-Agent
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedTab: SidebarTab
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App name header
            Text("Voiyce")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, AppTheme.cardPadding)
                .padding(.top, 20)
                .padding(.bottom, 24)

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

            // Recording state indicator
            Divider()
                .background(AppTheme.backgroundTertiary)

            HStack(spacing: 8) {
                StatusIndicator(recordingState: appState.recordingState)
            }
            .padding(AppTheme.cardPadding)
        }
        .frame(width: AppTheme.sidebarWidth)
        .background(AppTheme.backgroundSecondary)
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
