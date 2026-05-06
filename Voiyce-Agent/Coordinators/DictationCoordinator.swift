import SwiftData
import Cocoa

@Observable
final class DictationCoordinator {
    private let voiceEngine = VoiceEngine()
    private let whisperService = WhisperService()
    private let textInjector = TextInjector()
    private var modelContext: ModelContext?
    private var pendingStopRequest: PendingStopRequest?
    private var targetAppBundleIdentifier: String?

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
                print("[DictationCoordinator] Failed to start: \(error)")
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

                await MainActor.run {
                    totalInjectedText = transcript
                    latestTranscript = transcript
                    errorState = nil
                    lastSuccessfulTranscriptionAt = Date()
                    print("[DictationCoordinator] Transcribed: \(transcript)")
                    if injectText {
                        textInjector.injectText(
                            transcript,
                            targetBundleIdentifier: targetAppBundleIdentifier,
                            targetAppName: targetAppName
                        )
                    }
                    if persistTranscript {
                        saveDictation(text: transcript)
                    }
                    completion?(.success(transcript))
                }
            } catch {
                let mappedError = mapError(error)
                await MainActor.run {
                    errorState = mappedError
                    lastErrorAt = Date()
                    print("[DictationCoordinator] Transcription error: \(error)")
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
            print("[DictationCoordinator] Failed to save: \(error)")
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
            default:
                return .transcriptionFailed(whisperError.localizedDescription)
            }
        }

        return .transcriptionFailed(error.localizedDescription)
    }
}

enum DictationErrorState: LocalizedError {
    case microphonePermissionDenied
    case authenticationRequired
    case noInternet
    case noAudioCaptured
    case emptyTranscript
    case transcriptionFailed(String)

    var title: String {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone Access Needed"
        case .authenticationRequired:
            return "Sign In Required"
        case .noInternet:
            return "No Internet Connection"
        case .noAudioCaptured:
            return "Nothing Was Recorded"
        case .emptyTranscript:
            return "No Speech Detected"
        case .transcriptionFailed:
            return "Transcription Failed"
        }
    }

    var icon: String {
        switch self {
        case .microphonePermissionDenied:
            return "mic.slash.fill"
        case .authenticationRequired:
            return "person.crop.circle.badge.exclamationmark"
        case .noInternet:
            return "wifi.slash"
        case .noAudioCaptured:
            return "record.circle"
        case .emptyTranscript:
            return "waveform.slash"
        case .transcriptionFailed:
            return "exclamationmark.bubble.fill"
        }
    }

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Enable microphone access before starting dictation."
        case .authenticationRequired:
            return "Your Voiyce session is no longer valid. Sign in again before transcribing."
        case .noInternet:
            return "Voiyce needs an internet connection to send audio for transcription."
        case .noAudioCaptured:
            return "No audio was captured. Try recording again."
        case .emptyTranscript:
            return "No speech was detected. Try speaking a little louder."
        case .transcriptionFailed(let message):
            return message
        }
    }
}
