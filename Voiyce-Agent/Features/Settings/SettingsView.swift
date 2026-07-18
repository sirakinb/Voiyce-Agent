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
    @State private var isBillingPlanPickerPresented = false
    @State private var betaAccessCode = ""
    @State private var isRedeemingBetaCode = false
    @State private var permissionRefreshStatus: String?
    #if VOIYCE_PRO
    @State private var googleWorkspace = GoogleWorkspaceManager.shared
    @State private var agentMemory = AgentLongTermMemoryStore.shared
    @State private var supportExportStatus: String?
    #endif
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
                #if VOIYCE_PRO
                Text("Integrations").tag(1).accessibilityIdentifier("settings-tab-integrations")
                #endif
                Text("Hotkeys").tag(2).accessibilityIdentifier("settings-tab-hotkeys")
                Text("Permissions").tag(3).accessibilityIdentifier("settings-tab-permissions")
                Text("About").tag(4).accessibilityIdentifier("settings-tab-about")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings-tabs")
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            #if VOIYCE_PRO
            activeAgentReturnBanner
                .padding(.horizontal, 24)
                .padding(.bottom, appState.agentActivityStatus == nil ? 0 : 18)
            #endif

            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacing) {
                    switch appState.selectedSettingsTab {
                    case 0: generalTab
                    #if VOIYCE_PRO
                    case 1: integrationsTab
                    #endif
                    case 2: hotkeysTab
                    case 3: permissionsTab
                    case 4: aboutTab
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
            if tab == 3 {
                permissions.checkAllPermissions()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.checkAllPermissions()
        }
        .billingPlanPicker(isPresented: $isBillingPlanPickerPresented)
    }

    // MARK: - General Tab

    #if VOIYCE_PRO
    @ViewBuilder
    private var activeAgentReturnBanner: some View {
        if let activity = appState.agentActivityStatus {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(appState.agentMode.accent.opacity(0.16))
                        .frame(width: 36, height: 36)

                    Image(systemName: activity.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(appState.agentMode.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Voiyce keeps running while you change settings.")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Button {
                    appState.selectedTab = .agent
                } label: {
                    HStack(spacing: 6) {
                        Text("Return to Agent")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(14)
            .background(AppTheme.backgroundSecondary.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(appState.agentMode.accent.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("settings-active-agent-return")
        }
    }
    #endif

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

            settingsSection(title: "PROMO CODE") {
                settingsRow(
                    icon: "sparkles",
                    title: betaAccessTitle,
                    subtitle: betaAccessSubtitle
                ) {
                    HStack(spacing: 8) {
                        TextField("Code", text: $betaAccessCode)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .disabled(billingManager.hasBetaAccess || isRedeemingBetaCode)
                            .onSubmit {
                                redeemBetaAccessCode()
                            }

                        Button(betaAccessButtonTitle) {
                            redeemBetaAccessCode()
                        }
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                        .disabled(
                            billingManager.hasBetaAccess
                            || isRedeemingBetaCode
                            || betaAccessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                }
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

            #if VOIYCE_PRO
            settingsSection(title: "Agent Safety") {
                VStack(spacing: 1) {
                    ForEach(AgentSafetyMode.allCases) { mode in
                        safetyModeRow(mode)
                    }
                }
            }

            settingsSection(title: "Agent Memory") {
                settingsRow(
                    icon: "brain",
                    title: "Local Memory",
                    subtitle: "\(agentMemory.memoryCountText). \(agentMemory.privacySummary)"
                ) {
                    HStack(spacing: 8) {
                        Button(agentMemory.vaultURL == nil ? "Create Vault" : "Open Vault") {
                            agentMemory.revealVault()
                        }
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)

                        Button("Choose Folder") {
                            chooseAgentMemoryVault()
                        }
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)

                        Button("Clear") {
                            agentMemory.clear()
                        }
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.destructive)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.destructive.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                    }
                }

                if let vaultURL = agentMemory.vaultURL {
                    infoRow(label: "Vault", value: vaultURL.path)
                }
            }

            settingsSection(title: "Agent Privacy") {
                settingsRow(
                    icon: "hand.raised.fill",
                    title: "Private Mode",
                    subtitle: "Pause durable memory and raw screenshot storage."
                ) {
                    Toggle("", isOn: Binding(
                        get: { agentMemory.isPrivateModeEnabled },
                        set: { agentMemory.isPrivateModeEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .tint(AppTheme.accent)
                }

                settingsRow(
                    icon: "clock.arrow.circlepath",
                    title: "Memory Retention",
                    subtitle: agentMemory.memoryRetention.subtitle
                ) {
                    Picker("", selection: Binding(
                        get: { agentMemory.memoryRetention },
                        set: { agentMemory.memoryRetention = $0 }
                    )) {
                        ForEach(AgentMemoryRetention.allCases) { retention in
                            Text(retention.title).tag(retention)
                        }
                    }
                    .frame(width: 150)
                    .labelsHidden()
                }

                settingsRow(
                    icon: "note.text",
                    title: "Vault Notes",
                    subtitle: agentMemory.isVaultSyncEnabled
                        ? "Write durable memories to local Markdown daily notes."
                        : "Keep durable memories in the local index without Markdown notes."
                ) {
                    Toggle("", isOn: Binding(
                        get: { agentMemory.isVaultSyncEnabled },
                        set: { agentMemory.isVaultSyncEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .tint(AppTheme.accent)
                }

                settingsRow(
                    icon: "photo.on.rectangle",
                    title: "Raw Screenshots",
                    subtitle: agentMemory.screenshotRetention.subtitle
                ) {
                    Picker("", selection: Binding(
                        get: { agentMemory.screenshotRetention },
                        set: { agentMemory.screenshotRetention = $0 }
                    )) {
                        ForEach(AgentScreenshotRetention.allCases) { retention in
                            Text(retention.title).tag(retention)
                        }
                    }
                    .frame(width: 150)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("App/Site Exclusions")
                                .font(AppTheme.bodyFont)
                                .foregroundStyle(AppTheme.textPrimary)

                            Text("Comma or line separated names Voiyce should not remember.")
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()
                    }

                    TextField("1Password, bank, private client portal", text: Binding(
                        get: { agentMemory.excludedPatternsText },
                        set: { agentMemory.excludedPatternsText = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(AppTheme.bodyFont)
                }
                .padding(AppTheme.cardPadding)
            }
            #endif

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

                #if VOIYCE_PRO
                settingsRow(
                    icon: "square.and.arrow.up",
                    title: "Export Support Log",
                    subtitle: SettingsLaunchCopy.supportExportSubtitle
                ) {
                    Button("Export") {
                        exportSupportLog()
                    }
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
                }

                if let supportExportStatus {
                    Text(supportExportStatus)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppTheme.cardPadding)
                        .padding(.bottom, 10)
                }
                #endif
            }
        }
    }

    #if VOIYCE_PRO
    // MARK: - Integrations Tab

    private var integrationsTab: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            settingsSection(title: "Google") {
                googleConnectionCard(
                    icon: "envelope.fill",
                    title: "Gmail",
                    subtitle: "Read Gmail, create drafts, and send confirmed messages."
                )

                googleConnectionCard(
                    icon: "calendar",
                    title: "Google Calendar",
                    subtitle: "Check availability and read upcoming calendar events."
                )

                if googleWorkspace.isConnected {
                    settingsRow(
                        icon: "g.circle.fill",
                        title: "Google Account",
                        subtitle: googleWorkspace.connectedEmail ?? "Connected"
                    ) {
                        Button("Disconnect") {
                            googleWorkspace.disconnect()
                        }
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.destructive)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.destructive.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)
                    }
                }
            }

            if let infoMessage = googleWorkspace.infoMessage {
                Text(infoMessage)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if let errorMessage = googleWorkspace.errorMessage {
                Text(errorMessage)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.destructive)
            }
        }
    }
    #endif

    // MARK: - Hotkeys Tab

    private var hotkeysTab: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            settingsSection(title: "Keyboard Shortcuts") {
                settingsRow(icon: "mic.fill", title: "Dictation Mode", subtitle: "Hold to activate voice dictation") {
                    hotkeyBadge(appState.dictationHotkey)
                }

                #if VOIYCE_PRO
                settingsRow(icon: "circle.hexagongrid.circle", title: "Agent Mode", subtitle: "Tap Option once to start or stop the selected Agent mode") {
                    hotkeyBadge("⌥")
                }

                settingsRow(icon: "rectangle.3.group", title: "Focus Tools Bar", subtitle: "Open Focus, Paint, and Underline from any app") {
                    hotkeyBadge("⌃⌘A")
                }

                settingsRow(icon: "viewfinder", title: "Focus Highlight", subtitle: "Mark a screen region for Talk or Act") {
                    hotkeyBadge("⌘⇧F")
                }
                #endif
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

                #if VOIYCE_PRO
                permissionRow(
                    icon: "rectangle.on.rectangle",
                    title: "Screen Recording",
                    description: SystemPermissionStatusCopy.description(
                        for: .screenRecording,
                        isGranted: permissions.screenRecordingGranted,
                        screenRecordingStatusMessage: permissions.screenRecordingStatusMessage,
                        surface: .settings
                    ),
                    isGranted: permissions.screenRecordingGranted,
                    accessibilityIdentifier: "permission-row-screen-recording",
                    action: {
                        rememberPermissionReturn()
                        permissions.requestScreenRecordingPermission()
                    }
                )
                #endif
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

    #if VOIYCE_PRO
    private func chooseAgentMemoryVault() {
        let panel = NSOpenPanel()
        panel.title = "Choose Voiyce Memory Vault"
        panel.prompt = "Use Folder"
        panel.message = "Choose a folder where Voiyce can write local Markdown memory notes."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            agentMemory.setVault(url: url)
        }
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
        billingManager.isRefreshing || billingManager.isOpeningCheckout || billingManager.isOpeningPortal
    }

    private var billingActionTitle: String {
        if billingManager.isOpeningCheckout {
            return "Opening Checkout..."
        }

        if billingManager.isOpeningPortal {
            return "Opening Portal..."
        }

        return billingManager.primaryActionTitle
    }

    private var betaAccessTitle: String {
        if billingManager.hasBetaAccess {
            return billingManager.betaMonthlyCapReached ? "Monthly Budget Used" : "Unlocked"
        }

        return "Redeem Code"
    }

    private var betaAccessSubtitle: String {
        if billingManager.hasBetaAccess {
            return "Rate limits may apply."
        }

        return ""
    }

    private var betaAccessButtonTitle: String {
        isRedeemingBetaCode ? "Unlocking..." : "Unlock"
    }

    private func openBillingDestination() {
        if billingManager.canManageSubscription {
            Task {
                await billingManager.openBillingPortal()
            }
            return
        }

        isBillingPlanPickerPresented = true
    }

    private func redeemBetaAccessCode() {
        guard !isRedeemingBetaCode else { return }

        isRedeemingBetaCode = true
        Task {
            await billingManager.redeemBetaAccessCode(betaAccessCode)
            appState.accessState = billingManager.accessState(
                isAuthenticated: authenticationManager.isAuthenticated
            )

            if billingManager.hasBetaAccess {
                betaAccessCode = ""
            }

            isRedeemingBetaCode = false
        }
    }

    #if VOIYCE_PRO
    private func googleConnectionCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(googleWorkspace.isConnected ? AppTheme.success : AppTheme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(googleWorkspace.isConnected ? googleWorkspace.connectedEmail ?? "Connected" : subtitle)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            if googleWorkspace.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Connected")
                        .font(AppTheme.captionFont)
                }
                .foregroundStyle(AppTheme.success)
            } else {
                Button(googleWorkspace.isConnecting ? "Opening..." : "Connect") {
                    Task {
                        await googleWorkspace.connect()
                    }
                }
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)
                .disabled(googleWorkspace.isConnecting)
            }
        }
        .padding(AppTheme.cardPadding)
    }
    #endif

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

    #if VOIYCE_PRO
    private func safetyModeRow(_ mode: AgentSafetyMode) -> some View {
        let isSelected = appState.hasConfirmedAgentSafetyMode && appState.agentSafetyMode == mode

        return Button {
            appState.confirmAgentSafetyMode(mode)
            AgentEventStore.shared.append(
                category: .memory,
                status: .done,
                symbol: mode.symbol,
                title: "Safety mode changed",
                summary: "Agent safety mode is now \(mode.title).",
                details: [
                    AgentLogEventDetail(key: "Mode", value: mode.title),
                    AgentLogEventDetail(key: "Policy", value: mode.subtitle)
                ]
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(mode.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(mode.subtitle)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(isSelected ? mode.tint : AppTheme.textSecondary.opacity(0.55))
            }
            .padding(AppTheme.cardPadding)
            .background(isSelected ? mode.tint.opacity(0.06) : .clear)
        }
        .buttonStyle(.plain)
    }

    private func exportSupportLog() {
        guard let url = AgentEventStore.shared.exportSupportBundle() else {
            supportExportStatus = SettingsLaunchCopy.supportExportFailed
            return
        }

        supportExportStatus = "\(SettingsLaunchCopy.supportExportedPrefix) \(url.lastPathComponent)."
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    #endif

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
        appState.rememberPermissionReturnTarget(tab: .settings, settingsTab: 3)
    }

    private func refreshPermissionStatus() {
        permissions.checkAllPermissions()
        permissionRefreshStatus = "Permission status refreshed."
    }
}
