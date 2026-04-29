import Speech
import AVFoundation

@Observable
final class VoiceEngine {
    var isRecording = false
    var currentTranscript = ""
    var error: String?

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private(set) var recordingURL: URL?

    nonisolated init() {}

    /// Ensure microphone permission is granted before recording
    func ensureMicrophonePermission() async -> Bool {
        let permission = AVAudioApplication.shared.recordPermission
        print("[VoiceEngine] Mic permission: \(permission.rawValue)")

        if permission == .granted { return true }

        if permission == .undetermined {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        return false
    }

    /// Start recording audio to a temporary WAV file
    func startRecording() throws {
        _ = stopRecording()
        currentTranscript = ""
        error = nil

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 else {
            error = "Microphone not available"
            print("[VoiceEngine] ERROR: Sample rate is 0")
            return
        }

        // Create a 16kHz mono format for smaller file size
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            error = "Failed to create audio format"
            return
        }

        // Create temp file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("voiyce_recording_\(UUID().uuidString).wav")
        recordingURL = fileURL

        let audioFile = try AVAudioFile(forWriting: fileURL, settings: outputFormat.settings)
        self.audioFile = audioFile

        // Install tap with format conversion
        guard let converter = AVAudioConverter(from: recordingFormat, to: outputFormat) else {
            error = "Failed to create audio converter"
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
            let frameCount = AVAudioFrameCount(outputFormat.sampleRate * Double(buffer.frameLength) / recordingFormat.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }

            var error: NSError?
            var didProvideInput = false
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                guard !didProvideInput else {
                    outStatus.pointee = .noDataNow
                    return nil
                }

                didProvideInput = true
                outStatus.pointee = .haveData
                return buffer
            }

            do {
                try audioFile.write(from: convertedBuffer)
            } catch {
                print("[VoiceEngine] Write error: \(error)")
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        self.audioEngine = audioEngine
        self.isRecording = true
        print("[VoiceEngine] Recording started to: \(fileURL.lastPathComponent)")
    }

    /// Stop recording and return the audio file URL
    func stopRecording() -> URL? {
        guard isRecording || audioEngine != nil else {
            return nil
        }

        let url = recordingURL

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioFile = nil
        audioEngine = nil

        if isRecording {
            print("[VoiceEngine] Recording stopped")
        }
        isRecording = false
        return url
    }

    /// Clean up the temporary recording file
    func cleanupRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }
}
