//
//  SettingsView.swift
//  Voiyce-Agent
//

import AppKit
import InsForgeAuth
import SwiftUI

enum SettingsLaunchCopy {
    static let supportExportSubtitle = "Creates a local redacted Agent Log bundle for support."
    static let supportExportFailed = "Could not export the redacted support log."
    static let supportExportedPrefix = "Redacted support log exported:"

    static var visibleStrings: [String] {
        [
            supportExportSubtitle,
            supportExportFailed,
            supportExportedPrefix
        ]
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthenticationManager.self) private var authenticationManager
    @Environment(BillingManager.self) private var billingManager
    @Environment(PermissionsManager.self) private var permissions
    @State private var permissionRefreshStatus: String?
    #if DEBUG
    @State private var onboardingResetStatus: String?
    #endif

    var body: some View {
        @Bindable var appState = appState

        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Settings")
                .font(AppTheme.titleFont)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Tab picker
            Picker("", selection: $appState.selectedSettingsTab) {
                Text("General").tag(0).accessibilityIdentifier("settings-tab-general")
                Text("Hotkeys").tag(1).accessibilityIdentifier("settings-tab-hotkeys")
                Text("Permissions").tag(2).accessibilityIdentifier("settings-tab-permissions")
                Text("About").tag(3).accessibilityIdentifier("settings-tab-about")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings-tabs")
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacing) {
                    switch appState.selectedSettingsTab {
                    case 0: generalTab
                    case 1: hotkeysTab
                    case 2: permissionsTab
                    case 3: aboutTab
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GroovedBackground())
        .onAppear {
            permissions.checkAllPermissions()
        }
        .onChange(of: appState.selectedSettingsTab) { _, tab in
            if tab == 2 {
                permissions.checkAllPermissions()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.checkAllPermissions()
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            settingsSection(title: "Account") {
                settingsRow(
                    icon: "person.crop.circle.fill",
                    title: authenticationManager.currentUserDisplayName,
                    subtitle: authenticationManager.currentUserEmail.isEmpty
                        ? "No signed-in account"
                        : authenticationManager.currentUserEmail
                ) {
                    if authenticationManager.isWorking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Sign Out") {
                            Task {
                                await authenticationManager.signOut()
                            }
                        }
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                    }
                }
            }

            settingsSection(title: "Billing") {
                settingsRow(
                    icon: "creditcard.fill",
                    title: billingManager.planTitle,
                    subtitle: billingManager.planSubtitle
                ) {
                    Button(billingActionTitle) {
                        openBillingDestination()
                    }
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
                    .disabled(isBillingBusy)
                }

                settingsRow(
                    icon: "gauge.with.dots.needle",
                    title: "Usage Limits",
                    subtitle: billingManager.usageLimitSummary
                ) {
                    EmptyView()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Usage Limits. \(billingManager.usageLimitSummary)")
                .accessibilityIdentifier("settings-billing-limits")
            }

            if let infoMessage = authenticationManager.infoMessage {
                Text(infoMessage)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if let errorMessage = authenticationManager.errorMessage {
                Text(errorMessage)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.destructive)
            }

            if let infoMessage = billingManager.infoMessage {
                Text(infoMessage)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if let errorMessage = billingManager.errorMessage {
                Text(errorMessage)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.destructive)
            }

            settingsSection(title: "Startup") {
                settingsRow(icon: "power", title: "Launch at Login", subtitle: "Start Voiyce when you log in") {
                    Toggle("", isOn: .constant(false))
                        .toggleStyle(.switch)
                        .tint(AppTheme.accent)
                }
            }

            settingsSection(title: "Dictation") {
                settingsRow(
                    icon: "text.word.spacing",
                    title: "Current Hotkey",
                    subtitle: "Hold the control key anywhere to start dictating"
                ) {
                    hotkeyBadge(appState.dictationHotkey)
                }
            }

            settingsSection(title: "Help") {
                settingsRow(
                    icon: "play.rectangle.fill",
                    title: "Demo Video",
                    subtitle: "Replay the Voiyce walkthrough."
                ) {
                    Button("View") {
                        appState.isDemoVideoPresented = true
                    }
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
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
                    description: SystemPermissionStatusCopy.description(
                        for: .microphone,
                        isGranted: permissions.microphoneGranted,
                        surface: .settings
                    ),
                    isGranted: permissions.microphoneGranted,
                    accessibilityIdentifier: "permission-row-microphone",
                    action: {
                        rememberPermissionReturn()
                        permissions.requestMicrophonePermission()
                    }
                )

                permissionRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: SystemPermissionStatusCopy.description(
                        for: .speechRecognition,
                        isGranted: permissions.speechRecognitionGranted,
                        surface: .settings
                    ),
                    isGranted: permissions.speechRecognitionGranted,
                    accessibilityIdentifier: "permission-row-speech-recognition",
                    action: {
                        rememberPermissionReturn()
                        permissions.requestSpeechRecognitionPermission()
                    }
                )

                permissionRow(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: SystemPermissionStatusCopy.description(
                        for: .accessibility,
                        isGranted: permissions.accessibilityGranted,
                        surface: .settings
                    ),
                    isGranted: permissions.accessibilityGranted,
                    accessibilityIdentifier: "permission-row-accessibility",
                    action: {
                        rememberPermissionReturn()
                        permissions.requestAccessibilityPermission()
                    }
                )

            }

            Button {
                refreshPermissionStatus()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))

                    Text("Refresh Status")
                        .font(AppTheme.bodyFont)
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("permissions-refresh")

            Button {
                rememberPermissionReturn()
                permissions.openPrivacySettings()
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
            .accessibilityIdentifier("permissions-open-system-settings")

            if let permissionRefreshStatus {
                Text(permissionRefreshStatus)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            // App info
            VStack(alignment: .leading, spacing: 16) {
                Text("Voiyce")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                HStack(spacing: 24) {
                    aboutDetail(label: "Version", value: "1.0.0")
                    aboutDetail(label: "Build", value: "14")
                    aboutDetail(label: "Platform", value: "macOS")
                }
            }

            AppTheme.ridge.frame(height: 1)

            // Credits
            Text("Independent Voiyce platform")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)

            #if DEBUG
            AppTheme.ridge.frame(height: 1)

            settingsSection(title: "Testing") {
                settingsRow(
                    icon: "arrow.counterclockwise.circle.fill",
                    title: "Replay Onboarding",
                    subtitle: "Clears the local onboarding flag and returns this Mac to the setup flow."
                ) {
                    Button("Replay") {
                        replayOnboardingForTesting()
                    }
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
                }
            }

            if let onboardingResetStatus {
                Text(onboardingResetStatus)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            #endif
        }
    }

    #if DEBUG
    private func replayOnboardingForTesting() {
        let userID = authenticationManager.currentUser?.id
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AppConstants.accountScopedKey(AppConstants.onboardingCompleteKey, userID: userID))
        defaults.removeObject(forKey: AppConstants.accountScopedKey(AppConstants.onboardingDiscoverySourceKey, userID: userID))
        defaults.removeObject(forKey: AppConstants.accountScopedKey(AppConstants.onboardingRoleKey, userID: userID))
        defaults.removeObject(forKey: AppConstants.accountScopedKey(AppConstants.onboardingPrivacyPreferenceKey, userID: userID))
        defaults.removeObject(forKey: AppConstants.accountScopedKey(AppConstants.demoVideoSeenKey, userID: userID))
        appState.selectedTab = .dashboard
        appState.recordingState = .idle
        appState.isDictationActive = false
        appState.currentTranscript = ""
        appState.isOnboardingComplete = false
        appState.onboardingDiscoverySource = ""
        appState.onboardingRole = ""
        appState.onboardingPrivacyPreference = .unset
        onboardingResetStatus = "Onboarding reset for this Mac."
    }
    #endif

    private func aboutDetail(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private var isBillingBusy: Bool {
        billingManager.isRefreshing
    }

    private var billingActionTitle: String {
        billingManager.primaryActionTitle
    }

    private func openBillingDestination() {
        billingManager.openPurchasePage()
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

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            accessory()
        }
        .padding(AppTheme.cardPadding)
    }

    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        isGranted: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
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
                    .font(.system(size: 15))
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
        .padding(AppTheme.cardPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isGranted ? "Granted" : "Not granted"). \(description)")
        .accessibilityIdentifier(accessibilityIdentifier)
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

    private func rememberPermissionReturn() {
        appState.rememberPermissionReturnTarget(tab: .settings, settingsTab: 2)
    }

    private func refreshPermissionStatus() {
        permissions.checkAllPermissions()
        permissionRefreshStatus = "Permission status refreshed."
    }
}
