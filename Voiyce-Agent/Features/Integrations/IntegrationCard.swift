//
//  IntegrationCard.swift
//  Voiyce-Agent
//

import SwiftUI

struct IntegrationCard: View {
    let integration: IntegrationItem
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: integration.icon)
                .font(.system(size: 28))
                .foregroundStyle(
                    integration.isConnected ? AppTheme.accent : AppTheme.textSecondary
                )
                .frame(height: 40)

            // Name
            Text(integration.name)
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            // Description
            Text(integration.description)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Status badge
            HStack(spacing: 4) {
                Circle()
                    .fill(integration.isConnected ? AppTheme.success : AppTheme.textSecondary.opacity(0.5))
                    .frame(width: 6, height: 6)

                Text(integration.isConnected ? "Connected" : "Not Connected")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        integration.isConnected ? AppTheme.success : AppTheme.textSecondary
                    )
            }

            // Connect / Disconnect button
            Button(action: onToggle) {
                Text(integration.isConnected ? "Disconnect" : "Connect")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(
                        integration.isConnected ? AppTheme.destructive : AppTheme.accent
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        integration.isConnected
                            ? AppTheme.destructive.opacity(0.12)
                            : AppTheme.accent.opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(AppTheme.cardPadding)
        .background(isHovered ? AppTheme.backgroundTertiary : AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
