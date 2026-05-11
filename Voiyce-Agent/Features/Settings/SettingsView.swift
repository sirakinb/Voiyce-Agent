//
//  SettingsView.swift
//  Voiyce-Agent
//

import InsForgeAuth
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthenticationManager.self) private var authenticationManager
    @Environment(BillingManager.self) private var billingManager
    @Environment(PermissionsManager.self) private var permissions
    @State private var selectedSettingsTab = 0
    @State private var isBillingPlanPickerPresented = false
    @State private var betaAccessCode = ""
    @State private var isRedeemingBetaCode = false
    #if VOIYCE_PRO
    @State private var googleWorkspace = GoogleWorkspaceManager.shared
    #endif
    #if DEBUG
    @State private var onboardingResetStatus: String?
    #endif

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
                #if VOIYCE_PRO
                Text("Integrations").tag(1)
                #endif
                Text("Hotkeys").tag(2)
                Text("Permissions").tag(3)
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
        .onChange(of: selectedSettingsTab) { _, tab in
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
                    description: "Required for voice dictation.",
                    isGranted: permissions.microphoneGranted,
                    action: { permissions.requestMicrophonePermission() }
                )

                permissionRow(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: "Required for transcribing your voice to text.",
                    isGranted: permissions.speechRecognitionGranted,
                    action: { permissions.requestSpeechRecognitionPermission() }
                )

                permissionRow(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: permissions.accessibilityGranted
                        ? "Required for inserting text and global hotkeys."
                        : "If enabled in System Settings, restart Voiyce or toggle it off and on.",
                    isGranted: permissions.accessibilityGranted,
                    action: { permissions.requestAccessibilityPermission() }
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
            Text("Powered by Pentridge Media")
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
