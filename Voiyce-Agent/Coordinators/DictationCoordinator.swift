import SwiftData
import Cocoa
import ApplicationServices

@Observable
final class DictationCoordinator {
    private let voiceEngine = VoiceEngine()
    private let whisperService = WhisperService()
    private let textInjector = TextInjector()
    private var modelContext: ModelContext?
    private var pendingStopRequest: PendingStopRequest?
    private var targetAppBundleIdentifier: String?
    private var pasteTargetContext: PasteTargetContext?

    private var dictationStartTime: Date?
    private var targetAppName: String = ""
    var totalInjectedText = ""
    var latestTranscript = ""
    var isStarting = false
    var isTranscribing = false
    var errorState: DictationErrorState?
    var lastSuccessfulTranscriptionAt: Date?
    var lastErrorAt: Date?

    var isRecording: Bool { voiceEngine.isRecording }
    var isActive: Bool { isStarting || voiceEngine.isRecording || isTranscribing }

    func cancelForAppTermination() {
        cancelForRuntimeInterruption()
    }

    func cancelForSystemSleep() {
        cancelForRuntimeInterruption()
    }

    func cancelForAccessLoss() {
        cancelForRuntimeInterruption()
    }

    private func cancelForRuntimeInterruption() {
        pendingStopRequest = nil
        isStarting = false
        isTranscribing = false
        _ = voiceEngine.stopRecording()
        voiceEngine.cleanupRecording()
        dictationStartTime = nil
        targetAppBundleIdentifier = nil
        pasteTargetContext = nil
    }

    private struct PendingStopRequest {
        let injectText: Bool
        let persistTranscript: Bool
        let completion: ((Result<String, DictationErrorState>) -> Void)?
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startDictation(
        completion: ((Result<Void, DictationErrorState>) -> Void)? = nil
    ) {
        guard !isStarting, !voiceEngine.isRecording, !isTranscribing else {
            print("[DictationCoordinator] Ignoring duplicate start request")
            return
        }

        isStarting = true
        pendingStopRequest = nil
        dictationStartTime = Date()
        totalInjectedText = ""
        latestTranscript = ""
        errorState = nil
        let targetApplication = NSWorkspace.shared.frontmostApplication
        targetAppName = targetApplication?.localizedName ?? "Unknown"
        targetAppBundleIdentifier = targetApplication?.bundleIdentifier
        if let targetApplication {
            pasteTargetContext = PasteTargetContext(
                processID: targetApplication.processIdentifier,
                bundleIdentifier: targetApplication.bundleIdentifier,
                appName: targetAppName
            )
        } else {
            pasteTargetContext = nil
        }

        NSSound(named: "Tink")?.play()

        Task {
            let hasPermission = await voiceEngine.ensureMicrophonePermission()
            guard hasPermission else {
                isStarting = false
                let error = DictationErrorState.microphonePermissionDenied
                errorState = error
                lastErrorAt = Date()
                print("[DictationCoordinator] Microphone permission not granted")
                completion?(.failure(error))
                return
            }

            do {
                try voiceEngine.startRecording()
                isStarting = false
                if let pendingStopRequest {
                    let request = pendingStopRequest
                    self.pendingStopRequest = nil
                    print("[DictationCoordinator] Processing queued stop request")
                    stopDictation(
                        injectText: request.injectText,
                        persistTranscript: request.persistTranscript,
                        completion: request.completion
                    )
                    return
                }
                completion?(.success(()))
            } catch {
                isStarting = false
                pendingStopRequest = nil
                let mappedError = mapError(error)
                errorState = mappedError
                lastErrorAt = Date()
                print(DictationDebugLogCopy.operationFailed("start"))
                completion?(.failure(mappedError))
            }
        }
    }

    func stopDictation(
        injectText: Bool = true,
        persistTranscript: Bool = true,
        completion: ((Result<String, DictationErrorState>) -> Void)? = nil
    ) {
        if isStarting {
            pendingStopRequest = PendingStopRequest(
                injectText: injectText,
                persistTranscript: persistTranscript,
                completion: completion
            )
            print("[DictationCoordinator] Queued stop request while recording is starting")
            return
        }

        guard !isTranscribing else {
            print("[DictationCoordinator] Ignoring duplicate stop request while transcribing")
            return
        }

        guard let audioURL = voiceEngine.stopRecording() else {
            let error = DictationErrorState.noAudioCaptured
            errorState = error
            lastErrorAt = Date()
            print("[DictationCoordinator] No audio file to transcribe")
            completion?(.failure(error))
            return
        }

        pendingStopRequest = nil
        NSSound(named: "Pop")?.play()
        isTranscribing = true
        let duration = dictationStartTime.map { Date().timeIntervalSince($0) }
        let targetAppBundleIdentifier = targetAppBundleIdentifier
        let targetAppName = targetAppName
        let pasteTargetContext = pasteTargetContext

        // Send audio to Whisper API for transcription
        Task {
            defer {
                voiceEngine.cleanupRecording()
                Task { @MainActor in
                    self.isTranscribing = false
                }
            }

            do {
                let transcript = try await whisperService.transcribe(audioFileURL: audioURL, duration: duration)

                guard !transcript.isEmpty else {
                    let error = DictationErrorState.emptyTranscript
                    await MainActor.run {
                        errorState = error
                        lastErrorAt = Date()
                        print("[DictationCoordinator] Empty transcript")
                        completion?(.failure(error))
                    }
                    return
                }

                let injectionOutcome: TextInjectionOutcome? = injectText
                    ? await textInjector.injectText(
                        transcript,
                        targetContext: pasteTargetContext,
                        targetBundleIdentifier: targetAppBundleIdentifier,
                        targetAppName: targetAppName
                    )
                    : nil

                await MainActor.run {
                    totalInjectedText = transcript
                    latestTranscript = transcript
                    let transcriptWordCount = DictationDebugLogCopy.wordCount(in: transcript)
                    print(DictationDebugLogCopy.transcriptReadyForInsertion(wordCount: transcriptWordCount))

                    // Preserve the words regardless of insertion outcome so a
                    // blocked paste never loses the user's dictation.
                    if persistTranscript {
                        saveDictation(text: transcript)
                    }

                    if let insertionError = Self.postTranscriptionState(
                        injectText: injectText,
                        injectionOutcome: injectionOutcome
                    ) {
                        errorState = insertionError
                        lastErrorAt = Date()
                        print(DictationDebugLogCopy.operationFailed("insertion"))
                        completion?(.failure(insertionError))
                    } else {
                        errorState = nil
                        lastSuccessfulTranscriptionAt = Date()
                        completion?(.success(transcript))
                    }
                }
            } catch {
                let mappedError = mapError(error)
                await MainActor.run {
                    errorState = mappedError
                    lastErrorAt = Date()
                    print(DictationDebugLogCopy.operationFailed("transcription"))
                    completion?(.failure(mappedError))
                }
            }
        }
    }

    private func saveDictation(text: String) {
        guard !text.isEmpty, let modelContext else { return }

        let duration = dictationStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let transcript = Transcript(text: text, appName: targetAppName, duration: duration)
        modelContext.insert(transcript)

        do {
            try modelContext.save()
        } catch {
            print(DictationDebugLogCopy.operationFailed("save"))
        }
    }

    /// Never report a successful dictation when the words could not actually be
    /// inserted. When injection is requested but Accessibility trust blocked it,
    /// surface the recovery state; otherwise there is no insertion error.
    static func postTranscriptionState(
        injectText: Bool,
        injectionOutcome: TextInjectionOutcome?
    ) -> DictationErrorState? {
        guard injectText else { return nil }
        switch injectionOutcome {
        case .accessibilityDenied:
            return .accessibilityInsertionBlocked
        case .clipboardUnavailable:
            return .textInsertionFailed
        case .pasteUnconfirmed:
            return .pasteUnconfirmed
        case .injected, .none:
            return nil
        }
    }

    /// User-initiated recovery after a failed publication: put the last
    /// transcript back on the clipboard through the verified seam. Only clears the
    /// error when the write is confirmed, so the UI never implies the words are on
    /// the clipboard unless they actually are. The transcript also remains in
    /// history regardless, so nothing is lost.
    @MainActor
    @discardableResult
    func copyLastTranscriptToClipboard() -> Bool {
        guard !latestTranscript.isEmpty else { return false }
        let didPublish = textInjector.copyToClipboard(latestTranscript)
        if didPublish, errorState == .textInsertionFailed || errorState == .pasteUnconfirmed {
            errorState = nil
        }
        return didPublish
    }

    /// Called when Voiyce becomes active again (e.g. returning from System
    /// Settings). If the only outstanding error was a blocked insertion and
    /// Accessibility is now trusted, clear it so the next dictation isn't gated
    /// by a stale error.
    func refreshAccessibilityRecovery() {
        guard errorState == .accessibilityInsertionBlocked else { return }
        if AXIsProcessTrusted() {
            errorState = nil
        }
    }

    private func mapError(_ error: Error) -> DictationErrorState {
        if let error = error as? DictationErrorState {
            return error
        }

        if let whisperError = error as? WhisperError {
            switch whisperError {
            case .authenticationRequired:
                return .authenticationRequired
            case .noInternet:
                return .noInternet
            case .serviceQuotaExceeded(let message):
                return .serviceQuotaExceeded(message)
            default:
                return .transcriptionFailed(DictationRecoveryCopy.transcriptionFailedDetail)
            }
        }

        return .transcriptionFailed(DictationRecoveryCopy.transcriptionFailedDetail)
    }
}

enum DictationErrorState: LocalizedError, Equatable {
    case microphonePermissionDenied
    case accessibilityInsertionBlocked
    case pasteUnconfirmed
    case textInsertionFailed
    case authenticationRequired
    case noInternet
    case noAudioCaptured
    case emptyTranscript
    case serviceQuotaExceeded(String)
    case transcriptionFailed(String)

    var title: String {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone Access Needed"
        case .accessibilityInsertionBlocked:
            return "Accessibility Access Needed"
        case .pasteUnconfirmed:
            return "Paste Not Confirmed"
        case .textInsertionFailed:
            return "Couldn't Insert Text"
        case .authenticationRequired:
            return "Sign In Required"
        case .noInternet:
            return "No Internet Connection"
        case .noAudioCaptured:
            return "Nothing Was Recorded"
        case .emptyTranscript:
            return "No Speech Detected"
        case .serviceQuotaExceeded:
            return "Service Limit Reached"
        case .transcriptionFailed:
            return "Transcription Failed"
        }
    }

    var icon: String {
        switch self {
        case .microphonePermissionDenied:
            return "mic.slash.fill"
        case .accessibilityInsertionBlocked:
            return "hand.raised.slash.fill"
        case .pasteUnconfirmed:
            return "doc.on.clipboard"
        case .textInsertionFailed:
            return "doc.on.clipboard.fill"
        case .authenticationRequired:
            return "person.crop.circle.badge.exclamationmark"
        case .noInternet:
            return "wifi.slash"
        case .noAudioCaptured:
            return "record.circle"
        case .emptyTranscript:
            return "waveform.slash"
        case .serviceQuotaExceeded:
            return "creditcard.trianglebadge.exclamationmark"
        case .transcriptionFailed:
            return "exclamationmark.bubble.fill"
        }
    }

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Enable microphone access before starting dictation."
        case .accessibilityInsertionBlocked:
            return DictationRecoveryCopy.accessibilityInsertionBlockedDetail
        case .pasteUnconfirmed:
            return DictationRecoveryCopy.pasteUnconfirmedDetail
        case .textInsertionFailed:
            return DictationRecoveryCopy.textInsertionFailedDetail
        case .authenticationRequired:
            return "Your Voiyce session is no longer valid. Sign in again before transcribing."
        case .noInternet:
            return "Voiyce needs an internet connection to send audio for transcription."
        case .noAudioCaptured:
            return "No audio was captured. Try recording again."
        case .emptyTranscript:
            return "No speech was detected. Try speaking a little louder."
        case .serviceQuotaExceeded:
            return DictationRecoveryCopy.serviceLimitDetail
        case .transcriptionFailed:
            return DictationRecoveryCopy.transcriptionFailedDetail
        }
    }
}

enum DictationRecoveryCopy {
    static let supportEmail = AppConstants.supportEmail

    static let transcriptionServiceName = "Transcription service"
    static let accountUsageLimitDetail = "This account has reached its current transcription limit."

    static let accessibilityInsertionBlockedDetail = "Voiyce transcribed your words, but macOS blocked inserting them because Accessibility access is off. Your last dictation is on the clipboard — press Command-V to paste it now."
    static let accessibilityInsertionBlockedNextStep = "Click Open Accessibility Settings, turn on Voiyce under Privacy & Security > Accessibility, then hold Control again. Your last dictation is on the clipboard — press Command-V to paste it now."

    static let pasteUnconfirmedDetail = "Voiyce couldn't confirm the automatic paste. If the words are not visible, press Command-V; they are on the clipboard."
    static let pasteUnconfirmedNextStep = "If the words are not visible in the field, press Command-V to paste your last dictation. Your words are also saved in History."

    static let textInsertionFailedDetail = "Voiyce transcribed your words, but couldn't insert them into the app or copy them for you. Your last dictation is saved in History so it isn't lost."
    static let textInsertionFailedNextStep = "Click Copy Transcript to put your last dictation on the clipboard, then press Command-V to paste it. Your words are also saved in History."
    static let serviceLimitDetail = "Voiyce transcription is temporarily unavailable because the beta service limit was reached."
    static let serviceLimitNextStep = "Try again later. If this blocks setup, email \(supportEmail) with the time it happened."

    static let serviceUnavailableDetail = "Voiyce transcription is temporarily unavailable."
    static let serviceUnavailableNextStep = "Try again later. If this blocks setup, email \(supportEmail) with the time it happened."

    static let transcriptionFailedDetail = "Voiyce could not complete the transcription request."
    static let networkUnavailableDetail = "Voiyce lost internet access before transcription finished."
    static let networkUnavailableNextStep = "Reconnect to Wi-Fi or Ethernet, then hold Control again and retry dictation."
    static let serviceFailureNextStep = "Make sure your Mac is online, then try dictation again. If it still fails, email \(supportEmail) with the time it happened."
    static let previewTranscriptionFailedNextStep = "Make sure your Mac is online, then try the preview again. If it still fails, email \(supportEmail) with the time it happened."
    static let dashboardTranscriptionFailedNextStep = "Make sure your Mac is online, then hold Control again. If it still fails, email \(supportEmail) with the time it happened."
}
