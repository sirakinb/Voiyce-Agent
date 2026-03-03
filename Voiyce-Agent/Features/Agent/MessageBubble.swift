//
//  MessageBubble.swift
//  Voiyce-Agent
//

import SwiftUI

struct MessageBubble: View {
    let message: AgentMessage

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: message.timestamp)
    }

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        case .tool:
            toolBubble
        }
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 80)

            VStack(alignment: .trailing, spacing: 4) {
                Text(message.content)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

                Text(timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Assistant Bubble

    private var assistantBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.accent)

                    Text("Voiyce")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                }

                Text(message.content)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

                Text(timeString)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 80)
        }
    }

    // MARK: - Tool Bubble

    private var toolBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.warning)

                Text(message.toolName ?? "Tool Execution")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.warning)
            }

            Text(message.content)
                .font(AppTheme.monoFont)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

            Text(timeString)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}
