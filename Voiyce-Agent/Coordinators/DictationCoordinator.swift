import SwiftData
import Cocoa

@Observable
final class DictationCoordinator {
    private let voiceEngine = VoiceEngine()
    private let whisperService = WhisperService()
    private let textInjector = TextInjector()
    private var modelContext: ModelContext?

    private var dictationStartTime: Date?
    private var targetAppName: String = ""
    var totalInjectedText = ""
    var isTranscribing = false

    var openAIAPIKey: String = ""

    var isActive: Bool { voiceEngine.isRecording || isTranscribing }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startDictation() {
        dictationStartTime = Date()
        totalInjectedText = ""
        targetAppName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"

        NSSound(named: "Tink")?.play()

        Task {
            let hasPermission = await voiceEngine.ensureMicrophonePermission()
            guard hasPermission else {
                print("[DictationCoordinator] Microphone permission not granted")
                return
            }

            do {
                try voiceEngine.startRecording()
            } catch {
                print("[DictationCoordinator] Failed to start: \(error)")
            }
        }
    }

    func stopDictation() {
        guard let audioURL = voiceEngine.stopRecording() else {
            print("[DictationCoordinator] No audio file to transcribe")
            return
        }

        NSSound(named: "Pop")?.play()
        isTranscribing = true

        // Send audio to Whisper API for transcription
        Task {
            defer {
                isTranscribing = false
                voiceEngine.cleanupRecording()
            }

            do {
                let transcript = try await whisperService.transcribe(
                    audioFileURL: audioURL,
                    apiKey: openAIAPIKey
                )

                guard !transcript.isEmpty else {
                    print("[DictationCoordinator] Empty transcript")
                    return
                }

                totalInjectedText = transcript
                print("[DictationCoordinator] Injecting: \(transcript)")
                textInjector.injectText(transcript)
                saveDictation(text: transcript)
            } catch {
                print("[DictationCoordinator] Transcription error: \(error)")
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
}
