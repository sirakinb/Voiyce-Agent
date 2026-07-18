import Foundation
import AVFoundation
import InsForge
import InsForgeCore
import InsForgeFunctions

final class WhisperService {
    private let client = InsForgeClientProvider.shared

    /// Transcribe an audio file using the authenticated InsForge function.
    func transcribe(audioFileURL: URL, duration: TimeInterval? = nil) async throws -> String {
        let uploadURL = try await Self.compressedAudioURL(for: audioFileURL)
        let audioData = try Data(contentsOf: uploadURL)
        let fileName = "recording.\(uploadURL.pathExtension.isEmpty ? "m4a" : uploadURL.pathExtension)"
        let mimeType = Self.mimeType(for: uploadURL)
        let request = TranscriptionFunctionRequest(
            audioBase64: audioData.base64EncodedString(),
            fileName: fileName,
            mimeType: mimeType,
            language: "en",
            durationSeconds: duration
        )

        print("[WhisperService] Sending \(audioData.count / 1024)KB \(mimeType) audio to InsForge transcription function...")

        let result: WhisperResponse

        do {
            result = try await client.functions.invoke("transcribe-audio", body: request)
        } catch let error as InsForgeError {
            throw Self.mappedError(for: error, logServiceFailure: logTranscriptionServiceFailure)
        } catch let error as URLError {
            throw Self.mappedError(for: error, logServiceFailure: logTranscriptionServiceFailure)
        } catch {
            throw Self.mappedError(for: error, logServiceFailure: logTranscriptionServiceFailure)
        }

        let transcriptionWordCount = DictationDebugLogCopy.wordCount(in: result.text)
        print(DictationDebugLogCopy.transcriptionCompleted(wordCount: transcriptionWordCount))
        return result.text
    }

    static func mappedError(
        for error: Error,
        logServiceFailure: (Int?, String, String?) -> Void = { _, _, _ in }
    ) -> WhisperError {
        if let insForgeError = error as? InsForgeError {
            switch insForgeError {
            case .authenticationRequired, .unauthorized:
                return .authenticationRequired
            case .networkError(let underlyingError as URLError):
                if let mappedError = mappedNetworkError(underlyingError, logServiceFailure: logServiceFailure) {
                    return mappedError
                }
                return .requestFailed(DictationRecoveryCopy.transcriptionFailedDetail)
            case .networkError:
                return .requestFailed(DictationRecoveryCopy.transcriptionFailedDetail)
            case .httpError(let statusCode, let message, let errorMessage, let nextActions):
                let fullMessage = [
                    errorMessage,
                    message.isEmpty ? nil : message,
                    nextActions
                ]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")

                if statusCode == 401 || statusCode == 403 {
                    return .authenticationRequired
                }

                if BackendUsageLimitCopy.isUsageLimit(statusCode: statusCode, message: fullMessage) {
                    logServiceFailure(
                        statusCode,
                        DictationRecoveryCopy.accountUsageLimitDetail,
                        BackendUsageLimitCopy.nextStep
                    )
                    return .serviceQuotaExceeded(DictationRecoveryCopy.accountUsageLimitDetail)
                }

                if fullMessage.localizedCaseInsensitiveContains("OPENAI_API_KEY") {
                    logServiceFailure(
                        statusCode,
                        DictationRecoveryCopy.serviceUnavailableDetail,
                        DictationRecoveryCopy.serviceUnavailableNextStep
                    )
                    return .transcriptionServiceUnavailable(DictationRecoveryCopy.serviceUnavailableDetail)
                }

                if statusCode == 429 || fullMessage.localizedCaseInsensitiveContains("exceeded your current quota") {
                    logServiceFailure(
                        statusCode,
                        DictationRecoveryCopy.serviceLimitDetail,
                        DictationRecoveryCopy.serviceLimitNextStep
                    )
                    return .serviceQuotaExceeded(DictationRecoveryCopy.serviceLimitDetail)
                }

                logServiceFailure(
                    statusCode,
                    DictationRecoveryCopy.transcriptionFailedDetail,
                    DictationRecoveryCopy.serviceFailureNextStep
                )
                return .apiError(statusCode, DictationRecoveryCopy.transcriptionFailedDetail)
            default:
                return .requestFailed(DictationRecoveryCopy.transcriptionFailedDetail)
            }
        }

        if let urlError = error as? URLError,
           let mappedError = mappedNetworkError(urlError, logServiceFailure: logServiceFailure) {
            return mappedError
        }

        return .requestFailed(DictationRecoveryCopy.transcriptionFailedDetail)
    }

    private static func mappedNetworkError(
        _ error: URLError,
        logServiceFailure: (Int?, String, String?) -> Void
    ) -> WhisperError? {
        guard error.code == .notConnectedToInternet || error.code == .networkConnectionLost else {
            return nil
        }

        logServiceFailure(
            nil,
            DictationRecoveryCopy.networkUnavailableDetail,
            DictationRecoveryCopy.networkUnavailableNextStep
        )
        return .noInternet
    }

    private static func compressedAudioURL(for sourceURL: URL) async throws -> URL {
        guard sourceURL.pathExtension.lowercased() != "m4a" else {
            return sourceURL
        }

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiyce_upload_\(UUID().uuidString).m4a")
        let asset = AVURLAsset(url: sourceURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            print("[WhisperService] Could not create m4a export session; uploading original audio.")
            return sourceURL
        }

        exportSession.shouldOptimizeForNetworkUse = true

        try await exportSession.export(to: destinationURL, as: .m4a)
        return destinationURL
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a":
            return "audio/mp4"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        default:
            return "application/octet-stream"
        }
    }

    private func logTranscriptionServiceFailure(statusCode: Int?, message: String, nextStep: String? = nil) {
        #if VOIYCE_PRO
        Task { @MainActor in
            AgentEventStore.shared.appendServiceFailure(
                feature: "Dictation",
                service: DictationRecoveryCopy.transcriptionServiceName,
                statusCode: statusCode,
                message: message,
                nextStep: nextStep
            )
        }
        #endif
    }
}

enum DictationDebugLogCopy {
    static func transcriptionCompleted(wordCount: Int) -> String {
        "[Dictation] Transcription completed (\(wordCount) words)."
    }

    static func transcriptReadyForInsertion(wordCount: Int) -> String {
        "[Dictation] Transcript ready for insertion (\(wordCount) words)."
    }

    static func operationFailed(_ operation: String) -> String {
        "[Dictation] \(operation) failed."
    }

    static func wordCount(in text: String) -> Int {
        text
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }
}

private struct TranscriptionFunctionRequest: Encodable {
    let audioBase64: String
    let fileName: String
    let mimeType: String
    let language: String
    let durationSeconds: TimeInterval?
}

struct WhisperResponse: Codable {
    let text: String
}

enum WhisperError: LocalizedError {
    case authenticationRequired
    case noInternet
    case requestFailed(String)
    case apiError(Int, String)
    case transcriptionServiceUnavailable(String)
    case serviceQuotaExceeded(String)

    nonisolated var errorDescription: String? {
        switch self {
        case .authenticationRequired: return "Your Voiyce session expired. Sign in again and retry."
        case .noInternet: return "No internet connection. Reconnect and try again."
        case .requestFailed: return "Voiyce could not complete the transcription request."
        case .apiError: return "Voiyce could not complete the transcription request."
        case .transcriptionServiceUnavailable(let message): return message
        case .serviceQuotaExceeded(let message): return message
        }
    }
}
