import AppKit
import InsForgeAuth
import SwiftUI

enum OnboardingPermissionCopy {
    static let headline = "Let Voiyce hear you and type for you."
    static let body = "Turn on the access below. When you come back from System Settings, Voiyce checks again automatically."

    static let microphoneTitle = "Microphone"
    static let microphoneDescription = "Lets Voiyce hear your voice while you dictate or talk to it."

    static let speechRecognitionTitle = "Speech Recognition"
    static let speechRecognitionDescription = "Lets your Mac allow Voiyce to turn speech into text."
    static let speechRecognitionMissingDetail = "Voiyce still needs Speech Recognition access to finish setup cleanly on macOS."

    static let accessibilityTitle = "Accessibility"
    static let accessibilityGrantedDescription = "Lets Voiyce place finished text into whatever app you're typing in."
    static let accessibilityMissingDescription = "Turn on the exact Voiyce entry so your dictated text can land in other apps."

    static let screenRecordingTitle = "Screen Recording"
    static let screenRecordingGrantedDescription = "Lets Context, Talk, and Act understand what is on your screen when you ask."
    static let screenRecordingMissingDescription = "Needed for Context, Talk, and Act to understand the current screen. Dictation can continue without it."

    static let requiredAccessTitle = "Required access is still off"
    static let requiredAccessMessage = "Voiyce needs Microphone, Speech Recognition, and Accessibility to finish setup."
    static let requiredAccessNextStep = "Turn on the missing items above. Continue unlocks as soon as they are ready."

    static let agentScreenAccessTitle = "Screen access is still off"
    static let agentScreenAccessMessage = "Dictation can continue, but Context, Talk, and Act need Screen Recording before Voiyce can understand the current screen."
    static let agentScreenAccessNextStep = "Click Grant Access for Screen Recording, enable Voiyce in System Settings, then quit and reopen Voiyce if your Mac keeps showing the old state."

    static var allPlainLanguageStrings: [String] {
        [
            headline,
            body,
            microphoneTitle,
            microphoneDescription,
            speechRecognitionTitle,
            speechRecognitionDescription,
            speechRecognitionMissingDetail,
            accessibilityTitle,
            accessibilityGrantedDescription,
            accessibilityMissingDescription,
            screenRecordingTitle,
            screenRecordingGrantedDescription,
            screenRecordingMissingDescription,
            requiredAccessTitle,
            requiredAccessMessage,
            requiredAccessNextStep,
            agentScreenAccessTitle,
            agentScreenAccessMessage,
            agentScreenAccessNextStep
        ]
    }
}

enum OnboardingLaunchCopy {
    static let previewHeadline = "Say one line out loud."
    static let previewBody = "This runs the exact recording path your dictation uses, but keeps the text here inside Voiyce so you can confirm everything works before using it in other apps."
    static let learnHeadlineWithoutPreview = "You're set up to talk instead of type."
    static let learnHeadlineWithPreview = "Nice. That's your words, typed for you."
    static let learnBodyWithoutPreview = "Even without a recorded sample, the important part is in place: Voiyce can hear you and place finished text wherever you're typing."
    static let learnBodyWithPreview = "That short test proves Voiyce can capture your voice and turn it into clean text. The same hold-to-talk shortcut now works in every app on this Mac."
    static let learnNoticeTitle = "Why this matters"

    static var visibleStrings: [String] {
        [
            previewHeadline,
            previewBody,
            learnHeadlineWithoutPreview,
            learnHeadlineWithPreview,
            learnBodyWithoutPreview,
            learnBodyWithPreview,
            learnNoticeTitle
        ]
    }
}

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
        if billingManager.hasPentridgeSubscription || billingManager.hasActiveSubscription {
            return "\(billingManager.planTitle) is active"
        }

        if billingManager.requiresSubscription {
            return billingManager.paymentRequiredTitle
        }

        return "Voiyce is ready on this Mac"
    }

    private var trialSubtitle: String {
        if let subtitle = billingManager.status.map({ _ in billingManager.planSubtitle }) {
            return subtitle
        }

        return "Your Pentridge Labs membership unlocks dictation on this Mac. Standard includes 10,000 words a month; Pro is unlimited."
    }

    private var discoverySummary: String {
        appState.onboardingDiscoverySource.isEmpty ? "Not chosen yet" : appState.onboardingDiscoverySource
    }

    private var roleSummary: String {
        appState.onboardingRole.isEmpty ? "Not chosen yet" : appState.onboardingRole
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
                    detail: OnboardingPermissionCopy.speechRecognitionMissingDetail,
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
                    detail: "Sign in with your Pentridge Labs account to unlock dictation on this Mac.",
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
        case .serviceQuotaExceeded:
            return SystemStatusMessage(
                id: "onboarding-service-limit-reached",
                icon: error.icon,
                title: error.title,
                detail: DictationRecoveryCopy.serviceLimitDetail,
                nextStep: DictationRecoveryCopy.serviceLimitNextStep,
                tone: .error,
                actionTitle: nil,
                action: nil
            )
        case .transcriptionFailed:
            return SystemStatusMessage(
                id: "onboarding-transcription-failed",
                icon: error.icon,
                title: error.title,
                detail: DictationRecoveryCopy.transcriptionFailedDetail,
                nextStep: DictationRecoveryCopy.previewTranscriptionFailedNextStep,
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

            // Soft accent bloom so the flat panel reads as lit rather than painted.
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.16), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 620
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            .allowsHitTesting(false)

            RadialGradient(
                colors: [Color(hex: 0x4B2E83).opacity(0.13), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 560
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            .allowsHitTesting(false)

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
                                .id(stepIndex)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .offset(y: 12)),
                                        removal: .opacity
                                    )
                                )
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
        VStack(alignment: .leading, spacing: 30) {
            VStack(alignment: .leading, spacing: 16) {
                StepEyebrow(stage: currentStage, step: "Quick Setup")

                GradientHeadline(
                    leading: "Let's tune Voiyce",
                    accent: "to you."
                )

                Text("Two quick questions. They shape the language you'll see during setup — nothing here changes your account.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 620, alignment: .leading)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    discoveryCard
                    roleCard
                }
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 20) {
                    discoveryCard
                    roleCard
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var discoveryCard: some View {
        QuestionCard(
            index: "01",
            title: "Where did you hear about Voiyce?",
            isAnswered: !appState.onboardingDiscoverySource.isEmpty
        ) {
            OptionGrid(options: discoverySources, selectedOption: appState.onboardingDiscoverySource) { source in
                chooseDiscoverySource(source)
            }
        }
    }

    private var roleCard: some View {
        QuestionCard(
            index: "02",
            title: "What kind of work do you do most days?",
            isAnswered: !appState.onboardingRole.isEmpty
        ) {
            OptionGrid(options: roleOptions, selectedOption: appState.onboardingRole) { role in
                chooseRole(role)
            }
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepEyebrow(stage: currentStage, step: "System Access")

            Text(OnboardingPermissionCopy.headline)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(OnboardingPermissionCopy.body)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 14) {
                PermissionStatusCard(
                    icon: "mic.fill",
                    title: OnboardingPermissionCopy.microphoneTitle,
                    description: SystemPermissionStatusCopy.description(
                        for: .microphone,
                        isGranted: permissions.microphoneGranted,
                        surface: .onboarding
                    ),
                    isGranted: permissions.microphoneGranted,
                    primaryTitle: "Grant Access",
                    primaryAction: { permissions.requestMicrophonePermission() },
                    secondaryTitle: nil,
                    secondaryAction: nil
                )

                PermissionStatusCard(
                    icon: "waveform",
                    title: OnboardingPermissionCopy.speechRecognitionTitle,
                    description: SystemPermissionStatusCopy.description(
                        for: .speechRecognition,
                        isGranted: permissions.speechRecognitionGranted,
                        surface: .onboarding
                    ),
                    isGranted: permissions.speechRecognitionGranted,
                    primaryTitle: "Grant Access",
                    primaryAction: { permissions.requestSpeechRecognitionPermission() },
                    secondaryTitle: "Open Settings",
                    secondaryAction: { permissions.openPrivacySettings() }
                )

                PermissionStatusCard(
                    icon: "accessibility",
                    title: OnboardingPermissionCopy.accessibilityTitle,
                    description: SystemPermissionStatusCopy.description(
                        for: .accessibility,
                        isGranted: permissions.accessibilityGranted,
                        surface: .onboarding
                    ),
                    isGranted: permissions.accessibilityGranted,
                    primaryTitle: "Grant Access",
                    primaryAction: { permissions.requestAccessibilityPermission() },
                    secondaryTitle: "Open Settings",
                    secondaryAction: { permissions.openAccessibilitySettings() }
                )

            }

            if !permissions.allPermissionsGranted {
                NoticeCard(
                    title: OnboardingPermissionCopy.requiredAccessTitle,
                    message: OnboardingPermissionCopy.requiredAccessMessage,
                    nextStep: OnboardingPermissionCopy.requiredAccessNextStep
                )
            }
        }
    }

    private var microphoneTestStep: some View {
        return VStack(alignment: .leading, spacing: 20) {
            StepEyebrow(stage: currentStage, step: "Preview")

            Text(OnboardingLaunchCopy.previewHeadline)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(OnboardingLaunchCopy.previewBody)
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

            Text(previewTranscript.isEmpty ? OnboardingLaunchCopy.learnHeadlineWithoutPreview : OnboardingLaunchCopy.learnHeadlineWithPreview)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(
                previewTranscript.isEmpty
                ? OnboardingLaunchCopy.learnBodyWithoutPreview
                : OnboardingLaunchCopy.learnBodyWithPreview
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
                title: OnboardingLaunchCopy.learnNoticeTitle,
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

}

private enum OnboardingStep: Int, CaseIterable {
    case context
    case permissions
    case microphoneTest
    case learn
    case personalize

    var stage: SetupStage {
        switch self {
        case .context:
            return .signUp
        case .permissions:
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
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(AppTheme.accent.opacity(0.14))
                )
                .overlay(
                    Capsule().stroke(AppTheme.accent.opacity(0.28), lineWidth: 1)
                )

            Text(step.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
        }
    }
}

/// Two-tone display headline: the accent clause is filled with the brand gradient.
private struct GradientHeadline: View {
    let leading: String
    let accent: String

    var body: some View {
        (
            Text(leading + " ")
                .foregroundStyle(AppTheme.textPrimary)
            + Text(accent)
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accent, Color(hex: 0xB79BFF)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .font(.system(size: 40, weight: .bold))
        .tracking(-0.8)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Glass question card with a numbered index that fills in once answered.
private struct QuestionCard<Content: View>: View {
    let index: String
    let title: String
    let isAnswered: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text(index)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isAnswered ? Color.white : AppTheme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(
                            isAnswered
                            ? AnyShapeStyle(LinearGradient(
                                colors: [AppTheme.accent, Color(hex: 0x8B6BF2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            : AnyShapeStyle(Color.white.opacity(0.06))
                        )
                    )
                    .overlay(
                        Circle().stroke(
                            isAnswered ? AppTheme.accent.opacity(0.5) : AppTheme.ridge,
                            lineWidth: 1
                        )
                    )

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            content

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: isAnswered
                        ? [AppTheme.accent.opacity(0.4), AppTheme.accent.opacity(0.08)]
                        : [Color.white.opacity(0.10), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .animation(.easeOut(duration: 0.22), value: isAnswered)
    }
}

private struct JourneyHeader: View {
    let stage: SetupStage
    let stepIndex: Int
    let stepCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    Text(stage.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.6)
                        .foregroundStyle(AppTheme.accent)

                    Circle()
                        .fill(AppTheme.textSecondary.opacity(0.35))
                        .frame(width: 3, height: 3)

                    Text("Step \(stepIndex + 1) of \(stepCount)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Text("Voiyce setup")
                    .font(.system(size: 11.5, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
            }

            GeometryReader { proxy in
                let spacing: CGFloat = 6
                let segment = (proxy.size.width - (spacing * CGFloat(stepCount - 1))) / CGFloat(stepCount)

                HStack(spacing: spacing) {
                    ForEach(0..<stepCount, id: \.self) { index in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.07))

                            if index <= stepIndex {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.accent, Color(hex: 0x9B7BFF)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(segment, 0))
                                    .opacity(index == stepIndex ? 1 : 0.45)
                                    .shadow(
                                        color: index == stepIndex ? AppTheme.accent.opacity(0.5) : .clear,
                                        radius: 6
                                    )
                            }
                        }
                        .frame(width: max(segment, 0), height: 4)
                    }
                }
            }
            .frame(height: 4)
            .animation(.easeInOut(duration: 0.3), value: stepIndex)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct OptionGrid: View {
    let options: [String]
    let selectedOption: String
    let onSelect: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 132), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) {
                        onSelect(option)
                    }
                } label: {
                    Text(option)
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
            .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? Color.white : AppTheme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(
                            colors: [AppTheme.accent.opacity(0.85), Color(hex: 0x7C58EB).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(Color.white.opacity(configuration.isPressed ? 0.09 : 0.045))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(
                        isSelected ? AppTheme.accent.opacity(0.9) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? AppTheme.accent.opacity(0.32) : .clear,
                radius: 10,
                y: 3
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
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
