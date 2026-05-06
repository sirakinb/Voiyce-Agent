//
//  DashboardView.swift
//  Voiyce-Agent
//

import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(BillingManager.self) private var billingManager
    @Environment(PermissionsManager.self) private var permissions
    @Environment(DictationCoordinator.self) private var dictationCoordinator
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Environment(UsageTracker.self) private var usageTracker
    @State private var weeklyData: [DailyUsage] = []
    @State private var isBillingPlanPickerPresented = false

    private var wordsToday: Int {
        max(appState.wordsToday, usageTracker.todayStats().words)
    }

    private var sessionsToday: Int {
        max(appState.dictationSessionsToday, usageTracker.todayStats().dictationSessions)
    }

    private var timeSaved: String {
        let minutes = wordsToday / 40
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

    private var totalWordsThisWeek: Int {
        weeklyData.reduce(0) { $0 + $1.words }
    }

    private var totalSessionsThisWeek: Int {
        weeklyData.reduce(0) { $0 + $1.dictationSessions }
    }

    private var averageWordsPerDay: Int {
        weeklyData.isEmpty ? 0 : totalWordsThisWeek / weeklyData.count
    }

    private var averageWordsPerSession: Int {
        totalSessionsThisWeek == 0 ? 0 : totalWordsThisWeek / totalSessionsThisWeek
    }

    private var activeDaysThisWeek: Int {
        weeklyData.filter { $0.dictationSessions > 0 }.count
    }

    private var freeWordsProgress: Double {
        guard AppConstants.freeWordLimit > 0 else { return 0 }
        return min(Double(billingManager.freeWordsUsed) / Double(AppConstants.freeWordLimit), 1)
    }

    private var betaSpendProgress: Double {
        guard let status = billingManager.status,
              status.betaMonthlySpendLimitUSD > 0 else {
            return 0
        }

        let used = NSDecimalNumber(decimal: status.betaMonthlySpendUsedUSD).doubleValue
        let limit = NSDecimalNumber(decimal: status.betaMonthlySpendLimitUSD).doubleValue
        return min(used / limit, 1)
    }

    private var billingActionTitle: String {
        billingManager.primaryActionTitle
    }

    private var statusMessages: [SystemStatusMessage] {
        var messages: [SystemStatusMessage] = []

        if !permissions.microphoneGranted {
            messages.append(
                SystemStatusMessage(
                    id: "missing-microphone",
                    icon: "mic.slash.fill",
                    title: "Microphone Access Is Off",
                    detail: "Voiyce cannot start recording because macOS has not granted microphone access.",
                    nextStep: "Click Grant Access. If macOS still blocks it, open System Settings > Privacy & Security > Microphone, enable Voiyce, then try dictating again.",
                    tone: .warning,
                    actionTitle: "Grant Access",
                    action: { permissions.requestMicrophonePermission() }
                )
            )
        }

        if !networkMonitor.isConnected {
            messages.append(
                SystemStatusMessage(
                    id: "offline",
                    icon: "wifi.slash",
                    title: "No Internet Connection",
                    detail: "Voiyce can capture audio, but server transcription will fail while your Mac is offline.",
                    nextStep: "Reconnect to Wi-Fi or Ethernet, then hold Control again to retry the dictation.",
                    tone: .warning,
                    actionTitle: nil,
                    action: nil
                )
            )
        }

        switch appState.accessState {
        case .active:
            break
        case .signedOut:
            messages.append(
                SystemStatusMessage(
                    id: "signed-out",
                    icon: "person.crop.circle.badge.exclamationmark",
                    title: "Sign-In Required",
                    detail: "Sign in to start your \(AppConstants.trialLengthDays)-day Pro trial with up to \(AppConstants.freeWordLimit) words. No credit card required.",
                    nextStep: "Open the app, complete sign-in, then return here and start dictating again.",
                    tone: .info,
                    actionTitle: nil,
                    action: nil
                )
            )
        case .paymentRequired:
            messages.append(
                SystemStatusMessage(
                    id: "payment-required",
                    icon: "creditcard.trianglebadge.exclamationmark",
                    title: billingManager.paymentRequiredTitle,
                    detail: billingManager.paymentRequiredDetail,
                    nextStep: "Click \(billingActionTitle), finish checkout in Stripe, then return to Voiyce and refresh billing access.",
                    tone: .info,
                    actionTitle: billingActionTitle,
                    action: { openBillingDestination() }
                )
            )
        }

        if let dictationErrorMessage {
            messages.append(dictationErrorMessage)
        }

        return messages
    }

    private var dictationErrorMessage: SystemStatusMessage? {
        guard let error = dictationCoordinator.errorState else { return nil }
        if let lastErrorAt = dictationCoordinator.lastErrorAt,
           let lastSuccessfulTranscriptionAt = dictationCoordinator.lastSuccessfulTranscriptionAt,
           lastSuccessfulTranscriptionAt >= lastErrorAt {
            return nil
        }

        switch error {
        case .microphonePermissionDenied where !permissions.microphoneGranted:
            return nil
        case .authenticationRequired where appState.accessState == .signedOut:
            return nil
        case .noInternet where !networkMonitor.isConnected:
            return nil
        case .microphonePermissionDenied:
            return SystemStatusMessage(
                id: "dictation-microphone-denied",
                icon: error.icon,
                title: error.title,
                detail: "Voiyce tried to start dictation, but macOS blocked microphone access.",
                nextStep: "Click Grant Access. If macOS keeps it blocked, open System Settings > Privacy & Security > Microphone, enable Voiyce, then hold Control again.",
                tone: .warning,
                actionTitle: "Grant Access",
                action: { permissions.requestMicrophonePermission() }
            )
        case .authenticationRequired:
            return SystemStatusMessage(
                id: "dictation-auth-required",
                icon: error.icon,
                title: error.title,
                detail: "The last dictation could not be transcribed because your Voiyce session is no longer valid.",
                nextStep: "Open Settings, sign out, sign back in, then hold Control again to retry the dictation.",
                tone: .warning,
                actionTitle: "Open Settings",
                action: { appState.selectedTab = .settings }
            )
        case .noInternet:
            return SystemStatusMessage(
                id: "dictation-offline",
                icon: error.icon,
                title: error.title,
                detail: "The last dictation could not be sent for transcription because the network request failed offline.",
                nextStep: "Reconnect to Wi-Fi or Ethernet, then hold Control again and retry the dictation.",
                tone: .warning,
                actionTitle: nil,
                action: nil
            )
        case .noAudioCaptured:
            return SystemStatusMessage(
                id: "no-audio-captured",
                icon: error.icon,
                title: error.title,
                detail: "The last dictation ended before any usable audio was recorded.",
                nextStep: "Hold Control, start speaking right away, then release the key only after you finish the sentence.",
                tone: .warning,
                actionTitle: nil,
                action: nil
            )
        case .emptyTranscript:
            return SystemStatusMessage(
                id: "empty-transcript",
                icon: error.icon,
                title: error.title,
                detail: "Voiyce recorded audio, but the transcription service did not detect spoken words in the clip.",
                nextStep: "Move to a quieter place, speak clearly a little closer to the microphone, then hold Control again.",
                tone: .warning,
                actionTitle: nil,
                action: nil
            )
        case .transcriptionFailed(let message):
            return SystemStatusMessage(
                id: "transcription-failed",
                icon: error.icon,
                title: error.title,
                detail: "The last transcription request failed: \(message)",
                nextStep: "Make sure your Mac is online, then hold Control again. If it still fails, verify the server transcription function is deployed and its OpenAI secret is configured.",
                tone: .error,
                actionTitle: nil,
                action: nil
            )
        }
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

                if !statusMessages.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(statusMessages) { message in
                            SystemStatusCard(message: message)
                        }
                    }
                }

                billingOverviewCard

                // Stat cards
                HStack(spacing: AppTheme.spacing) {
                    StatCard(
                        icon: "text.word.spacing",
                        value: "\(wordsToday)",
                        label: "Words Today"
                    )

                    StatCard(
                        icon: "waveform",
                        value: "\(sessionsToday)",
                        label: "Sessions Today"
                    )

                    StatCard(
                        icon: "clock.arrow.circlepath",
                        value: timeSaved,
                        label: "Time Saved"
                    )
                }

                // Charts row
                HStack(spacing: AppTheme.spacing) {
                    weeklyWordsChart
                    weeklySessionsChart
                }

                // Dictation summary
                HStack(spacing: AppTheme.spacing) {
                    dictationSummaryCard
                    activitySummary
                }

                // Quick Start Guide
                quickStartSection

                // Permission warnings
                permissionWarningsSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GroovedBackground())
        .onAppear {
            refreshWeeklyData()
            permissions.checkAllPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.checkAllPermissions()
        }
        .onChange(of: appState.wordsToday) { _, _ in
            refreshWeeklyData()
        }
        .onChange(of: appState.dictationSessionsToday) { _, _ in
            refreshWeeklyData()
        }
        .billingPlanPicker(isPresented: $isBillingPlanPickerPresented)
    }

    private var billingOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(billingManager.planTitle)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(billingManager.planSubtitle)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

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
            }

            if billingManager.hasPentridgeSubscription {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Pentridge Labs \(billingManager.pentridgeTierDisplay)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Text(billingManager.pentridgeWordLimitDisplay)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Text("Voiyce is included in your Pentridge Labs subscription. No individual billing required.")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else if billingManager.hasBetaAccess {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(billingManager.betaMonthlySpendRemainingDisplay) total beta budget left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Text("\(billingManager.betaMonthlySpendUsedDisplay) / \(billingManager.betaMonthlySpendLimitDisplay) used")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    ProgressView(value: betaSpendProgress)
                        .progressViewStyle(.linear)
                        .tint(billingManager.betaMonthlyCapReached ? AppTheme.warning : AppTheme.accent)

                    Text(billingManager.inactiveTrialFooter)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else if !billingManager.hasActiveSubscription {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(billingManager.freeWordsRemaining) trial words left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Text("\(billingManager.freeWordsUsed) / \(AppConstants.freeWordLimit) used")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    ProgressView(value: freeWordsProgress)
                        .progressViewStyle(.linear)
                        .tint(billingManager.requiresSubscription ? AppTheme.warning : AppTheme.accent)

                    Text(billingManager.inactiveTrialFooter)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    // MARK: - Weekly Words Chart

    private var weeklyWordsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Words Dictated")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            Chart(weeklyData) { day in
                BarMark(
                    x: .value("Day", day.dayLabel),
                    y: .value("Words", day.words)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accent.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                        .foregroundStyle(AppTheme.ridge)
                    AxisValueLabel()
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(height: 180)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    // MARK: - Weekly Sessions Chart

    private var weeklySessionsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dictation Sessions")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            Chart(weeklyData) { day in
                LineMark(
                    x: .value("Day", day.dayLabel),
                    y: .value("Sessions", day.dictationSessions)
                )
                .foregroundStyle(AppTheme.success)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Day", day.dayLabel),
                    y: .value("Sessions", day.dictationSessions)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.success.opacity(0.25), AppTheme.success.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", day.dayLabel),
                    y: .value("Sessions", day.dictationSessions)
                )
                .foregroundStyle(AppTheme.success)
                .symbolSize(30)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                        .foregroundStyle(AppTheme.ridge)
                    AxisValueLabel()
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(height: 180)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    // MARK: - Sessions Breakdown

    private var dictationSummaryCard: some View {
        return VStack(alignment: .leading, spacing: 12) {
            Text("Dictation This Week")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 16) {
                Text("\(totalSessionsThisWeek)")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("sessions logged over the last 7 days")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)

                summaryRow(
                    label: "Active Days",
                    value: "\(activeDaysThisWeek)/7",
                    icon: "calendar"
                )
                summaryRow(
                    label: "Avg Words/Session",
                    value: "\(averageWordsPerSession)",
                    icon: "textformat.abc"
                )
                summaryRow(
                    label: "Daily Average",
                    value: "\(averageWordsPerDay) words",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    // MARK: - Activity Summary

    private var activitySummary: some View {
        return VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Summary")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 10) {
                summaryRow(label: "Total Words", value: "\(totalWordsThisWeek)", icon: "text.word.spacing")
                summaryRow(label: "Total Sessions", value: "\(totalSessionsThisWeek)", icon: "waveform")
                summaryRow(label: "Avg Words/Day", value: "\(averageWordsPerDay)", icon: "chart.bar")
                summaryRow(label: "Avg Words/Session", value: "\(averageWordsPerSession)", icon: "text.alignleft")
                summaryRow(label: "Time Saved", value: "\(totalWordsThisWeek / 40) min", icon: "clock")
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func summaryRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 16)

            Text(label)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Quick Start

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            Text("Quick Start")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            HotkeyInstructionRow(
                icon: "mic.fill",
                title: "Dictation Mode",
                hotkey: appState.dictationHotkey,
                description: "Hold to dictate text anywhere. Release to transcribe and insert."
            )
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    // MARK: - Permissions

    private var permissionWarningsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacing) {
            Text("Permissions")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 8) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to capture your voice during dictation.",
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
                    icon: "accessibility",
                    title: "Accessibility",
                    description: permissions.accessibilityGranted
                        ? "Required for global hotkeys and inserting dictated text."
                        : "If enabled in System Settings, restart Voiyce or toggle it off and on.",
                    isGranted: permissions.accessibilityGranted,
                    action: { permissions.requestAccessibilityPermission() }
                )
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func refreshWeeklyData() {
        weeklyData = usageTracker.weeklyData()
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
}

// MARK: - StatCard

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
