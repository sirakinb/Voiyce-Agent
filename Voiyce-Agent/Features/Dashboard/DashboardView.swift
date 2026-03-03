//
//  DashboardView.swift
//  Voiyce-Agent
//

import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(PermissionsManager.self) private var permissions

    private var timeSaved: String {
        let minutes = appState.wordsToday / 40
        if minutes < 1 {
            return "< 1 min"
        }
        return "\(minutes) min"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Welcome header
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(AppTheme.titleFont)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(formattedDate)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                // Stat cards
                HStack(spacing: AppTheme.spacing) {
                    StatCard(
                        icon: "text.word.spacing",
                        value: "\(appState.wordsToday)",
                        label: "Words Today"
                    )

                    StatCard(
                        icon: "checkmark.circle",
                        value: "\(appState.tasksCompleted)",
                        label: "Tasks Completed"
                    )

                    StatCard(
                        icon: "clock.arrow.circlepath",
                        value: timeSaved,
                        label: "Time Saved"
                    )
                }

                // Quick Start Guide
                quickStartSection

                // Permission warnings
                permissionWarningsSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.backgroundPrimary)
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            Text("Quick Start")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 8) {
                HotkeyInstructionRow(
                    icon: "mic.fill",
                    title: "Dictation Mode",
                    hotkey: appState.dictationHotkey,
                    description: "Hold to dictate text anywhere. Release to insert."
                )

                HotkeyInstructionRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Agent Mode",
                    hotkey: appState.agentHotkey,
                    description: "Press to activate the AI agent for tasks and questions."
                )
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var permissionWarningsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            Text("Permissions")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 8) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required for voice dictation and agent mode.",
                    isGranted: permissions.microphoneGranted,
                    action: { permissions.requestMicrophonePermission() }
                )

                PermissionRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: "Required for transcribing your voice to text.",
                    isGranted: permissions.speechRecognitionGranted,
                    action: { permissions.requestSpeechRecognitionPermission() }
                )

                PermissionRow(
                    icon: "universal.access",
                    title: "Accessibility",
                    description: "Required for inserting text and global hotkeys.",
                    isGranted: permissions.accessibilityGranted,
                    action: { permissions.requestAccessibilityPermission() }
                )
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Accent top border
            AppTheme.accent
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.accent)

                Spacer()
            }
            .padding(.top, 4)

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(label)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

// MARK: - HotkeyInstructionRow

private struct HotkeyInstructionRow: View {
    let icon: String
    let title: String
    let hotkey: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(hotkey)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(description)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(10)
        .background(AppTheme.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - PermissionRow

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isGranted ? AppTheme.success : AppTheme.warning)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(description)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.success)
            } else {
                Button("Grant") {
                    action()
                }
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(AppTheme.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
