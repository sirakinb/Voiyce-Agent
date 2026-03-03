import AVFoundation
import Cocoa

@Observable
final class AgentCoordinator {
    let agentEngine = AgentEngine()
    private let voiceEngine = VoiceEngine()
    private let whisperService = WhisperService()
    private var synthesizer: NSSpeechSynthesizer?

    var isListening: Bool { voiceEngine.isRecording }
    var isProcessing: Bool { agentEngine.isProcessing }

    var claudeAPIKey: String = ""
    var composioAPIKey: String = ""
    var openAIAPIKey: String = ""
    var voiceOutputEnabled: Bool = false

    var lastResponse: String?

    func startListening() {
        NSSound(named: "Tink")?.play()

        do {
            try voiceEngine.startRecording()
        } catch {
            print("[AgentCoordinator] Failed to start listening: \(error)")
        }
    }

    func stopListening() {
        guard let audioURL = voiceEngine.stopRecording() else { return }
        NSSound(named: "Pop")?.play()

        // Transcribe with Whisper then send to Claude
        Task {
            defer { voiceEngine.cleanupRecording() }

            do {
                let transcript = try await whisperService.transcribe(
                    audioFileURL: audioURL,
                    apiKey: openAIAPIKey
                )
                guard !transcript.isEmpty else { return }
                await processCommand(transcript)
            } catch {
                print("[AgentCoordinator] Transcription error: \(error)")
            }
        }
    }

    func processCommand(_ command: String) async {
        guard !claudeAPIKey.isEmpty else {
            lastResponse = "Please set your Claude API key in Settings."
            return
        }

        await agentEngine.processCommand(
            command,
            claudeAPIKey: claudeAPIKey,
            composioAPIKey: composioAPIKey
        )

        if let lastAssistant = agentEngine.currentMessages.last(where: { $0.role == .assistant }) {
            lastResponse = lastAssistant.content

            if voiceOutputEnabled {
                speakResponse(lastAssistant.content)
            }
        }
    }

    /// Send a text command directly (from chat input)
    func sendTextCommand(_ command: String) async {
        await processCommand(command)
    }

    private func speakResponse(_ text: String) {
        synthesizer?.stopSpeaking()
        synthesizer = NSSpeechSynthesizer()
        synthesizer?.startSpeaking(text)
    }

    func stopSpeaking() {
        synthesizer?.stopSpeaking()
    }
}
