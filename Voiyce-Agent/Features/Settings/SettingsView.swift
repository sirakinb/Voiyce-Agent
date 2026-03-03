//
//  SettingsView.swift
//  Voiyce-Agent
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSettingsTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Settings")
                .font(AppTheme.titleFont)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Tab picker
            Picker("", selection: $selectedSettingsTab) {
                Text("General").tag(0)
                Text("Hotkeys").tag(1)
                Text("Permissions").tag(2)
                Text("API Keys").tag(3)
                Text("About").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacing) {
                    switch selectedSettingsTab {
                    case 0: generalTab
                    case 1: hotkeysTab
                    case 2: permissionsTab
                    case 3: apiKeysTab
                    case 4: aboutTab
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.backgroundPrimary)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            settingsSection(title: "Startup") {
                settingsRow(icon: "power", title: "Launch at Login", subtitle: "Start Voiyce when you log in") {
                    Toggle("", isOn: .constant(false))
                        .toggleStyle(.switch)
                        .tint(AppTheme.accent)
                }
            }

            settingsSection(title: "Voice") {
                @Bindable var state = appState
                settingsRow(icon: "speaker.wave.2", title: "Voice Output", subtitle: "Enable spoken responses from the agent") {
                    Toggle("", isOn: $state.voiceOutputEnabled)
                        .toggleStyle(.switch)
                        .tint(AppTheme.accent)
                }
            }
        }
    }

    // MARK: - Hotkeys Tab

    private var hotkeysTab: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            settingsSection(title: "Keyboard Shortcuts") {
                settingsRow(icon: "mic.fill", title: "Dictation Mode", subtitle: "Hold to activate voice dictation") {
                    hotkeyBadge(appState.dictationHotkey)
                }

                settingsRow(icon: "bubble.left.and.bubble.right.fill", title: "Agent Mode", subtitle: "Press to activate the AI agent") {
                    hotkeyBadge(appState.agentHotkey)
                }
            }

            Text("Hotkey customization will be available in a future update.")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 4)
        }
    }

    // MARK: - Permissions Tab

    private var permissionsTab: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            settingsSection(title: "System Permissions") {
                permissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Required for voice dictation and agent mode."
                )

                permissionRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: "Required for transcribing your voice to text."
                )

                permissionRow(
                    icon: "universal.access",
                    title: "Accessibility",
                    description: "Required for inserting text and global hotkeys."
                )
            }

            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))

                    Text("Open System Settings")
                        .font(AppTheme.bodyFont)
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - API Keys Tab

    @State private var claudeSaveStatus: String?
    @State private var composioSaveStatus: String?
    @State private var openAISaveStatus: String?

    private var apiKeysTab: some View {
        @Bindable var state = appState

        return VStack(alignment: .leading, spacing: AppTheme.spacing) {
            settingsSection(title: "OpenAI API (Whisper Speech-to-Text)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)

                    SecureField("Enter your OpenAI API key", text: $state.openAIAPIKey)
                        .textFieldStyle(.plain)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(10)
                        .background(AppTheme.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack {
                        if let status = openAISaveStatus {
                            Text(status)
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.success)
                        }
                        Spacer()
                        Button("Save") {
                            do {
                                try KeychainManager.save(
                                    key: AppConstants.openAIAPIKeyKey,
                                    value: appState.openAIAPIKey
                                )
                                openAISaveStatus = "Saved!"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    openAISaveStatus = nil
                                }
                            } catch {
                                openAISaveStatus = "Error saving"
                            }
                        }
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                    }
                }
            }

            settingsSection(title: "Claude API") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)

                    SecureField("Enter your Claude API key", text: $state.claudeAPIKey)
                        .textFieldStyle(.plain)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(10)
                        .background(AppTheme.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack {
                        if let status = claudeSaveStatus {
                            Text(status)
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.success)
                        }
                        Spacer()
                        Button("Save") {
                            do {
                                try KeychainManager.save(
                                    key: AppConstants.claudeAPIKeyKey,
                                    value: appState.claudeAPIKey
                                )
                                claudeSaveStatus = "Saved!"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    claudeSaveStatus = nil
                                }
                            } catch {
                                claudeSaveStatus = "Error saving"
                            }
                        }
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                    }
                }
            }

            settingsSection(title: "Composio API") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)

                    SecureField("Enter your Composio API key", text: $state.composioAPIKey)
                        .textFieldStyle(.plain)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(10)
                        .background(AppTheme.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack {
                        if let status = composioSaveStatus {
                            Text(status)
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.success)
                        }
                        Spacer()
                        Button("Save") {
                            do {
                                try KeychainManager.save(
                                    key: AppConstants.composioAPIKeyKey,
                                    value: appState.composioAPIKey
                                )
                                composioSaveStatus = "Saved!"
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    composioSaveStatus = nil
                                }
                            } catch {
                                composioSaveStatus = "Error saving"
                            }
                        }
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            settingsSection(title: "Voiyce Agent") {
                VStack(alignment: .leading, spacing: 12) {
                    infoRow(label: "Version", value: "1.0.0")
                    infoRow(label: "Build", value: "1")
                    infoRow(label: "Platform", value: "macOS")
                }
            }

            settingsSection(title: "Credits") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Built with Swift and SwiftUI")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Powered by Claude AI (Anthropic) and Composio")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Reusable Components

    private func settingsSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 1) {
                content()
            }
            .background(AppTheme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }

    private func settingsRow<Accessory: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(subtitle)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            accessory()
        }
        .padding(AppTheme.cardPadding)
    }

    private func permissionRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.warning)
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

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.warning)
        }
        .padding(AppTheme.cardPadding)
    }

    private func hotkeyBadge(_ key: String) -> some View {
        Text(key)
            .font(AppTheme.captionFont)
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppTheme.accent.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Text(value)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, AppTheme.cardPadding)
    }
}
