import AppKit
import InsForgeAuth
import SwiftUI

enum SetupStage: String, CaseIterable, Identifiable {
    case signUp = "CONTEXT"
    case permissions = "ACCESS"
    case setup = "TRY IT"
    case learn = "PACE"
    case personalize = "READY"

    var id: String { rawValue }
}

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthenticationManager.self) private var authenticationManager
    @Environment(BillingManager.self) private var billingManager
    @Environment(PermissionsManager.self) private var permissions
    @Environment(DictationCoordinator.self) private var dictationCoordinator
    @Environment(NetworkMonitor.self) private var networkMonitor

    @State private var stepIndex = 0
    @State private var previewTranscript = ""
    @State private var previewDuration: TimeInterval = 0
    @State private var previewStartedAt: Date?
    @State private var isBillingPlanPickerPresented = false

    private let steps = OnboardingStep.allCases
    private let discoverySources = [
        "Friend / Team",
        "YouTube",
        "Social media",
        "Search",
        "Podcast",
        "Newsletter",
        "Article",
        "Other"
    ]
    private let roleOptions = [
        "Founder / CEO",
        "Product",
        "Developer",
        "Operator",
        "Sales",
        "Marketing",
        "Support",
        "Student",
        "Writer",
        "Other"
    ]

    private var currentStep: OnboardingStep {
        steps[stepIndex]
    }

    private var currentStage: SetupStage {
        currentStep.stage
    }

    private var canAdvance: Bool {
        switch currentStep {
        case .context:
            return !appState.onboardingDiscoverySource.isEmpty && !appState.onboardingRole.isEmpty
        case .overview:
            return true
        case .privacy:
            return appState.onboardingPrivacyPreference != .unset
        case .permissions:
            return permissions.allPermissionsGranted
        case .microphoneTest:
            return true
        case .learn:
            return true
        case .personalize:
            return true
        }
    }

    private var continueDisabled: Bool {
        (!canAdvance) || dictationCoordinator.isTranscribing
    }

    private var advanceTitle: String {
        switch currentStep {
        case .microphoneTest:
            return previewTranscript.isEmpty ? "Skip for Now" : "See Results"
        case .personalize:
            return "Open Voiyce"
        default:
            return "Continue"
        }
    }

    private var isReadyToRecord: Bool {
        permissions.microphoneGranted
            && permissions.speechRecognitionGranted
            && networkMonitor.isConnected
            && appState.accessState == .active
    }

    private var isRecordingPreview: Bool {
        dictationCoordinator.isActive && !dictationCoordinator.isTranscribing
    }

    private var previewWordCount: Int {
        previewTranscript.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var measuredWordsPerMinute: Int {
        guard previewWordCount > 0, previewDuration > 0 else {
            return 155
        }

        let wordsPerMinute = Int((Double(previewWordCount) / previewDuration) * 60)
        return max(wordsPerMinute, AppConstants.averageTypingWordsPerMinute + 10)
    }

    private var speedMultiplier: Double {
        let ratio = Double(measuredWordsPerMinute) / Double(AppConstants.averageTypingWordsPerMinute)
        return max(ratio, 1.1)
    }

    private var estimatedWeeklyHoursSaved: Double {
        let weeklyWords = 12000.0
        let typingHours = weeklyWords / Double(AppConstants.averageTypingWordsPerMinute) / 60
        let speakingHours = weeklyWords / Double(measuredWordsPerMinute) / 60
        return max(typingHours - speakingHours, 0.6)
    }

    private var trialTitle: String {
        if billingManager.hasActiveSubscription {
            return "\(billingManager.planTitle) is active"
        }

        if billingManager.requiresSubscription {
            return billingManager.paymentRequiredTitle
        }

        return "Your Pro trial is ready"
    }

    private var trialSubtitle: String {
        if let subtitle = billingManager.status.map({ _ in billingManager.planSubtitle }) {
            return subtitle
        }

        return "\(AppConstants.trialLengthDays) days and up to \(AppConstants.freeWordLimit) words are ready on this Mac. No credit card is required up front."
    }

    private var discoverySummary: String {
        appState.onboardingDiscoverySource.isEmpty ? "Not chosen yet" : appState.onboardingDiscoverySource
    }

    private var roleSummary: String {
        appState.onboardingRole.isEmpty ? "Not chosen yet" : appState.onboardingRole
    }

    private var privacySummary: String {
        appState.onboardingPrivacyPreference.title
    }

    private var statusColor: Color {
        if dictationCoordinator.isTranscribing {
            return AppTheme.warning
        }

        return isRecordingPreview ? AppTheme.accent : AppTheme.textSecondary
    }

    private var statusLabel: String {
        if dictationCoordinator.isTranscribing {
            return "Transcribing your preview..."
        }

        return isRecordingPreview ? "Recording now. Click again when you finish speaking." : "Ready for one short test sentence."
    }

    private var recorderButtonTitle: String {
        if dictationCoordinator.isTranscribing {
            return "Transcribing..."
        }

        return isRecordingPreview ? "Stop Recording" : "Start Recording"
    }

    private var recorderButtonIcon: String {
        isRecordingPreview ? "stop.fill" : "mic.fill"
    }

    private var missingTryPrerequisiteMessage: String {
        "The preview recorder stays disabled until microphone access, speech recognition, billing access, and connectivity are all ready."
    }

    private var tryStatusMessages: [SystemStatusMessage] {
        var messages: [SystemStatusMessage] = []

        if !permissions.microphoneGranted {
            messages.append(
                SystemStatusMessage(
                    id: "onboarding-microphone",
                    icon: "mic.slash.fill",
                    title: "Microphone Access Is Off",
                    detail: "Voiyce cannot record the preview because macOS has not granted microphone access.",
                    nextStep: "Click Grant Access. If macOS still shows it as blocked, open System Settings > Privacy & Security > Microphone, enable Voiyce, then return here.",
                    tone: .warning,
                    actionTitle: "Grant Access",
                    action: { permissions.requestMicrophonePermission() }
                )
            )
        }

        if !permissions.speechRecognitionGranted {
            messages.append(
                SystemStatusMessage(
                    id: "onboarding-speech-recognition",
                    icon: "waveform",
                    title: "Speech Recognition Access Is Off",
                    detail: "Voiyce still needs speech recognition authorization to finish setup cleanly on macOS.",
                    nextStep: "Click Open Settings, turn on Speech Recognition for Voiyce in Privacy & Security, then come back here.",
                    tone: .warning,
                    actionTitle: "Open Settings",
                    action: { permissions.openPrivacySettings() }
                )
            )
        }

        if !networkMonitor.isConnected {
            messages.append(
                SystemStatusMessage(
                    id: "onboarding-offline",
                    icon: "wifi.slash",
                    title: "No Internet Connection",
                    detail: "The preview recorder cannot transcribe audio while your Mac is offline.",
                    nextStep: "Reconnect to Wi-Fi or Ethernet, then start the preview again.",
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
                    id: "onboarding-signed-out",
                    icon: "person.crop.circle.badge.exclamationmark",
                    title: "Sign-In Required",
                    detail: "Sign in to start your \(AppConstants.trialLengthDays)-day Pro trial with up to \(AppConstants.freeWordLimit) words. No credit card required.",
                    nextStep: "Finish sign-in, then come back here and run the preview again.",
                    tone: .info,
                    actionTitle: nil,
                    action: nil
                )
            )
        case .paymentRequired:
            messages.append(
                SystemStatusMessage(
                    id: "onboarding-payment-required",
                    icon: "creditcard.trianglebadge.exclamationmark",
                    title: billingManager.paymentRequiredTitle,
                    detail: billingManager.paymentRequiredDetail,
                    nextStep: "Click \(billingManager.primaryActionTitle), finish checkout in Stripe, then return here and refresh billing access.",
                    tone: .info,
                    actionTitle: billingManager.primaryActionTitle,
                    action: { isBillingPlanPickerPresented = true }
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
                id: "onboarding-dictation-microphone",
                icon: error.icon,
                title: error.title,
                detail: "Voiyce tried to start the preview, but macOS blocked microphone access.",
                nextStep: "Click Grant Access. If macOS keeps it blocked, open System Settings > Privacy & Security > Microphone, enable Voiyce, then try again.",
                tone: .warning,
                actionTitle: "Grant Access",
                action: { permissions.requestMicrophonePermission() }
            )
        case .authenticationRequired:
            return SystemStatusMessage(
                id: "onboarding-dictation-auth",
                icon: error.icon,
                title: error.title,
                detail: "Voiyce could not transcribe the preview because your session is no longer valid.",
                nextStep: "Sign out, sign back in, then try the preview again.",
                tone: .warning,
                actionTitle: nil,
                action: nil
            )
        case .noInternet:
            return SystemStatusMessage(
                id: "onboarding-dictation-offline",
                icon: error.icon,
                title: error.title,
                detail: "The preview failed because the transcription request lost network access.",
                nextStep: "Reconnect to Wi-Fi or Ethernet, then run the preview again.",
                tone: .warning,
                actionTitle: nil,
                action: nil
            )
        case .noAudioCaptured:
            return SystemStatusMessage(
                id: "onboarding-no-audio",
                icon: error.icon,
                title: error.title,
                detail: "The preview stopped before usable audio was captured.",
                nextStep: "Click Start Recording, say one full sentence, then click Stop Recording only after you finish speaking.",
                tone: .warning,
                actionTitle: nil,
                action: nil
            )
        case .emptyTranscript:
            return SystemStatusMessage(
                id: "onboarding-empty-transcript",
                icon: error.icon,
                title: error.title,
                detail: "Voiyce recorded audio, but no speech was detected in the clip.",
                nextStep: "Move to a quieter place, speak clearly into the microphone, then try the preview again.",
                tone: .warning,
                actionTitle: nil,
                action: nil
            )
        case .transcriptionFailed(let message):
            return SystemStatusMessage(
                id: "onboarding-transcription-failed",
                icon: error.icon,
                title: error.title,
                detail: "The preview transcription request failed: \(message)",
                nextStep: "Make sure your Mac is online, then try the preview again. If it still fails, verify the server transcription function is deployed and its OpenAI secret is configured.",
                tone: .error,
                actionTitle: nil,
                action: nil
            )
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x08090D),
                    Color(hex: 0x111117),
                    Color(hex: 0x17131E)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let horizontalPadding = min(max(proxy.size.width * 0.04, 24), 48)
                    let contentWidth = min(proxy.size.width - (horizontalPadding * 2), 1260)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            JourneyHeader(
                                stage: currentStage,
                                stepIndex: stepIndex,
                                stepCount: steps.count
                            )

                            leftPanel
                                .frame(maxWidth: contentWidth, alignment: .leading)
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 24)
                        .frame(maxWidth: 1360, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.black.opacity(0.18))

                Divider()
                    .overlay(AppTheme.ridge)

                onboardingFooter
            }
        }
        .onAppear {
            permissions.checkAllPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.checkAllPermissions()
        }
        .billingPlanPicker(isPresented: $isBillingPlanPickerPresented)
    }

    @ViewBuilder
    private var leftPanel: some View {
        switch currentStep {
        case .context:
            contextStep
        case .overview:
            overviewStep
        case .privacy:
            privacyStep
        case .permissions:
            permissionsStep
        case .microphoneTest:
            microphoneTestStep
        case .learn:
            learnStep
        case .personalize:
            personalizeStep
        }
    }

    private var contextStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            StepEyebrow(stage: currentStage, step: "Quick Setup")

            Text("Set up Voiyce for this Mac.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Give us just enough context to shape the setup language and the first-run trial summary. Nothing here changes your account globally.")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    contextQuestionCard(title: "Where did you hear about Voiyce?") {
                        OptionGrid(options: discoverySources, selectedOption: appState.onboardingDiscoverySource) { source in
                            chooseDiscoverySource(source)
                        }
                    }

                    contextQuestionCard(title: "What kind of work do you do most days?") {
                        OptionGrid(options: roleOptions, selectedOption: appState.onboardingRole) { role in
                            chooseRole(role)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 18) {
                    contextQuestionCard(title: "Where did you hear about Voiyce?") {
                        OptionGrid(options: discoverySources, selectedOption: appState.onboardingDiscoverySource) { source in
                            chooseDiscoverySource(source)
                        }
                    }

                    contextQuestionCard(title: "What kind of work do you do most days?") {
                        OptionGrid(options: roleOptions, selectedOption: appState.onboardingRole) { role in
                            chooseRole(role)
                        }
                    }
                }
            }
        }
    }

    private var overviewStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepEyebrow(stage: currentStage, step: "How It Works")

            Text("Voiyce turns speech into text anywhere on your Mac.")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Hold the Control key, speak naturally, then release. Voiyce records your voice, transcribes the audio, and inserts the finished text into the app you were already using.")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 14) {
                FeatureCalloutCard(
                    icon: "waveform.badge.mic",
                    title: "Hold to record",
                    detail: "You do not have to click into a separate compose box before speaking."
                )
                FeatureCalloutCard(
                    icon: "text.bubble.fill",
                    title: "Clean transcript",
                    detail: "Voiyce turns audio into readable text you can actually send."
                )
                FeatureCalloutCard(
                    icon: "rectangle.and.pencil.and.ellipsis",
                    title: "Insert in place",
                    detail: "When you release the key, the result goes back into the app you were working in."
                )
            }
        }
    }

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepEyebrow(stage: currentStage, step: "Data Mode")

            Text("You control how Voiyce handles your data.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Pick the mode you want on this Mac. You can change it later in settings after onboarding.")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 14) {
                PrivacyChoiceCard(
                    title: "Help improve Voiyce",
                    description: "Allows product-improvement usage while you evaluate the app. Best if you want the default experience and future quality tuning.",
                    badge: "Recommended",
                    isSelected: appState.onboardingPrivacyPreference == .standard
                ) {
                    choosePrivacyPreference(.standard)
                }

                PrivacyChoiceCard(
                    title: "Privacy mode",
                    description: "Keeps your dictation data out of product-improvement training. Best if your work is sensitive and you want stricter data handling without changing the transcription engine.",
                    badge: "Private",
                    isSelected: appState.onboardingPrivacyPreference == .privateMode
                ) {
                    choosePrivacyPreference(.privateMode)
                }
            }

            Text(appState.onboardingPrivacyPreference.summary)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepEyebrow(stage: currentStage, step: "System Access")

            Text("Give Voiyce the permissions it needs to work everywhere.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Grant each permission below. When you return from System Settings, this screen refreshes automatically.")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 14) {
                PermissionStatusCard(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Lets Voiyce capture your voice while you dictate.",
                    isGranted: permissions.microphoneGranted,
                    primaryTitle: "Grant Access",
                    primaryAction: { permissions.requestMicrophonePermission() },
                    secondaryTitle: nil,
                    secondaryAction: nil
                )

                PermissionStatusCard(
                    icon: "waveform",
                    title: "Speech Recognition",
                    description: "Needed so macOS fully authorizes the dictation flow.",
                    isGranted: permissions.speechRecognitionGranted,
                    primaryTitle: "Grant Access",
                    primaryAction: { permissions.requestSpeechRecognitionPermission() },
                    secondaryTitle: "Open Settings",
                    secondaryAction: { permissions.openPrivacySettings() }
                )

                PermissionStatusCard(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: permissions.accessibilityGranted
                        ? "Allows Voiyce to type the finished transcript back into your active app."
                        : "If enabled in System Settings, restart Voiyce or toggle it off and on.",
                    isGranted: permissions.accessibilityGranted,
                    primaryTitle: "Grant Access",
                    primaryAction: { permissions.requestAccessibilityPermission() },
                    secondaryTitle: "Open Settings",
                    secondaryAction: { permissions.openAccessibilitySettings() }
                )
            }

            if !permissions.allPermissionsGranted {
                NoticeCard(
                    title: "Setup is blocked by missing permissions",
                    message: "Voiyce cannot finish onboarding because at least one required macOS permission is still off.",
                    nextStep: "Grant Microphone, Speech Recognition, and Accessibility above. Continue unlocks as soon as all three are enabled."
                )
            }
        }
    }

    private var microphoneTestStep: some View {
        return VStack(alignment: .leading, spacing: 20) {
            StepEyebrow(stage: currentStage, step: "Preview")

            Text("Run one short dictation test.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("This uses the same recording and transcription pipeline as the live app, but it keeps the text inside Voiyce so you can confirm everything works before the shortcut goes global.")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)

            if !tryStatusMessages.isEmpty {
                VStack(spacing: 12) {
                    ForEach(tryStatusMessages) { message in
                        SystemStatusCard(message: message)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)

                    Text(statusLabel)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)

                    if isRecordingPreview || dictationCoordinator.isTranscribing {
                        VoiceWaveformView(isActive: true)
                            .padding(.leading, 2)
                    }
                }

                Button(action: togglePreviewRecording) {
                    HStack(spacing: 10) {
                        Image(systemName: recorderButtonIcon)
                            .font(.system(size: 14, weight: .semibold))

                        Text(recorderButtonTitle)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(isDisabled: !isReadyToRecord || dictationCoordinator.isTranscribing))
                .disabled(!isReadyToRecord || dictationCoordinator.isTranscribing)

                if !isReadyToRecord {
                    Text(missingTryPrerequisiteMessage)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.warning)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Transcript Preview")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.04))

                        if previewTranscript.isEmpty {
                            Text("No preview transcript yet. Click Start Recording, say one short sentence, then click Stop Recording to confirm text appears here.")
                                .font(AppTheme.bodyFont)
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(18)
                        } else {
                            ScrollView {
                                Text(previewTranscript)
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(18)
                            }
                        }
                    }
                    .frame(minHeight: 180)
                }
            }
            .padding(22)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }

    private var learnStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepEyebrow(stage: currentStage, step: "Why It Helps")

            Text(previewTranscript.isEmpty ? "Speaking is still faster than typing." : "Nice job. Your voice is faster than your keyboard.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(
                previewTranscript.isEmpty
                ? "Even without a recorded sample, normal speech usually outpaces typing. Once you start dictating in real apps, the shortcut takes over the mechanical part."
                : "That short test already shows the difference between speaking one clean sentence and typing the same thought manually."
            )
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 14) {
                MetricCard(
                    title: "Typing speed",
                    value: "\(AppConstants.averageTypingWordsPerMinute)",
                    suffix: "wpm",
                    tone: .secondary
                )
                MetricCard(
                    title: previewTranscript.isEmpty ? "Typical speaking speed" : "Your speaking speed",
                    value: "\(measuredWordsPerMinute)",
                    suffix: "wpm",
                    tone: .accent
                )
            }

            NoticeCard(
                title: "Why this matters",
                message: String(format: "At this pace, dictation is about %.1fx faster than typing.", speedMultiplier),
                nextStep: String(
                    format: "If you dictate around 12,000 words in a week, that pace saves roughly %.1f hours versus typing them manually.",
                    estimatedWeeklyHoursSaved
                )
            )
        }
    }

    private var personalizeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepEyebrow(stage: currentStage, step: "Finish")

            Text(trialTitle)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(trialSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 14) {
                SummaryCard(
                    title: "Shortcut",
                    detail: "Hold \(appState.dictationHotkey) to record. Release it to transcribe and insert text.",
                    badge: appState.dictationHotkey
                )
                SummaryCard(
                    title: "Discovery source",
                    detail: discoverySummary,
                    badge: "Source"
                )
                SummaryCard(
                    title: "Role",
                    detail: roleSummary,
                    badge: "Role"
                )
                SummaryCard(
                    title: "Privacy mode",
                    detail: privacySummary,
                    badge: "Data"
                )
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

            Button(billingManager.primaryActionTitle) {
                handleBillingAction()
            }
            .buttonStyle(OnboardingSecondaryButtonStyle())
        }
    }

    private var onboardingFooter: some View {
        HStack {
            Button("Back") {
                withAnimation(.easeInOut(duration: 0.18)) {
                    stepIndex -= 1
                }
            }
            .buttonStyle(OnboardingSecondaryButtonStyle())
            .opacity(stepIndex == 0 ? 0 : 1)
            .disabled(stepIndex == 0)

            Spacer()

            Button(advanceTitle) {
                handleAdvance()
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(isDisabled: continueDisabled))
            .disabled(continueDisabled)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color.black.opacity(0.14))
    }

    private func chooseDiscoverySource(_ source: String) {
        appState.onboardingDiscoverySource = source
        persistOnboardingAnswers()
    }

    private func chooseRole(_ role: String) {
        appState.onboardingRole = role
        persistOnboardingAnswers()
    }

    private func choosePrivacyPreference(_ preference: OnboardingPrivacyPreference) {
        appState.onboardingPrivacyPreference = preference
        persistOnboardingAnswers()
    }

    private func persistOnboardingAnswers() {
        let userID = authenticationManager.currentUser?.id
        let defaults = UserDefaults.standard
        defaults.set(
            appState.onboardingDiscoverySource,
            forKey: AppConstants.accountScopedKey(AppConstants.onboardingDiscoverySourceKey, userID: userID)
        )
        defaults.set(
            appState.onboardingRole,
            forKey: AppConstants.accountScopedKey(AppConstants.onboardingRoleKey, userID: userID)
        )
        defaults.set(
            appState.onboardingPrivacyPreference.rawValue,
            forKey: AppConstants.accountScopedKey(AppConstants.onboardingPrivacyPreferenceKey, userID: userID)
        )
    }

    private func togglePreviewRecording() {
        guard !dictationCoordinator.isTranscribing else { return }

        if isRecordingPreview {
            dictationCoordinator.stopDictation(
                injectText: false,
                persistTranscript: false
            ) { result in
                previewDuration = previewStartedAt.map { Date().timeIntervalSince($0) } ?? 0
                previewStartedAt = nil

                switch result {
                case .success(let transcript):
                    previewTranscript = transcript
                    appState.currentTranscript = transcript
                case .failure:
                    previewTranscript = ""
                }
            }
        } else {
            previewTranscript = ""
            previewDuration = 0
            appState.currentTranscript = ""
            previewStartedAt = Date()

            dictationCoordinator.startDictation { result in
                if case .failure = result {
                    previewStartedAt = nil
                    previewTranscript = ""
                }
            }
        }
    }

    private func handleAdvance() {
        if currentStep == .personalize {
            finishOnboarding()
            return
        }

        guard canAdvance else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            stepIndex += 1
        }
    }

    private func handleBillingAction() {
        if billingManager.canManageSubscription {
            Task {
                await billingManager.openBillingPortal()
            }
            return
        }

        isBillingPlanPickerPresented = true
    }

    private func finishOnboarding() {
        persistOnboardingAnswers()
        UserDefaults.standard.set(
            true,
            forKey: AppConstants.accountScopedKey(
                AppConstants.onboardingCompleteKey,
                userID: authenticationManager.currentUser?.id
            )
        )
        appState.selectedTab = .dashboard
        appState.isOnboardingComplete = true
    }

    private func contextQuestionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            content()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case context
    case overview
    case privacy
    case permissions
    case microphoneTest
    case learn
    case personalize

    var stage: SetupStage {
        switch self {
        case .context, .overview:
            return .signUp
        case .privacy, .permissions:
            return .permissions
        case .microphoneTest:
            return .setup
        case .learn:
            return .learn
        case .personalize:
            return .personalize
        }
    }
}

private struct StepEyebrow: View {
    let stage: SetupStage
    let step: String

    var body: some View {
        HStack(spacing: 10) {
            Text(stage.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(Capsule())

            Text(step.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

private struct JourneyHeader: View {
    let stage: SetupStage
    let stepIndex: Int
    let stepCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stage.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)

                    Text("Step \(stepIndex + 1) of \(stepCount)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Text("Voiyce setup")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(progressColor(for: index))
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func progressColor(for index: Int) -> Color {
        if index < stepIndex {
            return AppTheme.accent.opacity(0.35)
        }

        if index == stepIndex {
            return AppTheme.accent
        }

        return Color.white.opacity(0.08)
    }
}

private struct OptionGrid: View {
    let options: [String]
    let selectedOption: String
    let onSelect: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    onSelect(option)
                }
                .buttonStyle(OptionChipButtonStyle(isSelected: option == selectedOption))
            }
        }
    }
}

private struct OptionChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AppTheme.accent.opacity(0.14) : Color.white.opacity(configuration.isPressed ? 0.07 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.6) : AppTheme.ridge, lineWidth: 1)
            )
    }
}

private struct FeatureCalloutCard: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(detail)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct PrivacyChoiceCard: View {
    let title: String
    let description: String
    let badge: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Text(badge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((isSelected ? AppTheme.accent : AppTheme.textSecondary).opacity(0.14))
                        .clipShape(Capsule())
                }

                Text(description)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppTheme.accent.opacity(0.12) : Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.55) : AppTheme.ridge, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

private struct MetricCard: View {
    enum Tone {
        case accent
        case secondary
    }

    let title: String
    let value: String
    let suffix: String
    let tone: Tone

    private var accentColor: Color {
        switch tone {
        case .accent:
            return AppTheme.accent
        case .secondary:
            return AppTheme.textSecondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(suffix)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(accentColor.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct SummaryCard: View {
    let title: String
    let detail: String
    let badge: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Text(badge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(detail)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct DataModeCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isActive: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 58, height: 58)
                .background(tint.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(isActive ? tint.opacity(0.12) : Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(isActive ? tint.opacity(0.55) : AppTheme.ridge, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

private struct PermissionStatePill: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Text(isGranted ? "Granted" : "Required")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isGranted ? AppTheme.success : AppTheme.warning)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((isGranted ? AppTheme.success : AppTheme.warning).opacity(0.14))
                .clipShape(Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct ComparisonBar: View {
    let label: String
    let value: Double
    let maxValue: Double
    var highlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Text("\(Int(value)) wpm")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(highlight ? AppTheme.accent : AppTheme.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))

                    RoundedRectangle(cornerRadius: 10)
                        .fill(highlight ? AppTheme.accent : AppTheme.textSecondary.opacity(0.45))
                        .frame(width: geometry.size.width * max(min(value / max(maxValue, 1), 1), 0.12))
                }
            }
            .frame(height: 18)
        }
    }
}

private struct NoticeCard: View {
    let title: String
    let message: String
    let nextStep: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(message)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)

            Text(nextStep)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct PermissionStatusCard: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill((isGranted ? AppTheme.success : AppTheme.accent).opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isGranted ? AppTheme.success : AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(isGranted ? "Granted" : "Required")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(isGranted ? AppTheme.success : AppTheme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((isGranted ? AppTheme.success : AppTheme.warning).opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(description)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 16)

            HStack(spacing: 10) {
                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(OnboardingSecondaryButtonStyle())
                }

                if !isGranted {
                    Button(primaryTitle, action: primaryAction)
                        .buttonStyle(OnboardingPrimaryButtonStyle())
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(isDisabled ? 0.6 : 1))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDisabled ? AppTheme.accent.opacity(0.35) : AppTheme.accent.opacity(configuration.isPressed ? 0.8 : 1))
            )
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.textPrimary.opacity(configuration.isPressed ? 0.8 : 1))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.08 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppTheme.ridge, lineWidth: 1)
            )
    }
}
