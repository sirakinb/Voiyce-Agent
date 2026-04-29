import Foundation
import InsForge
import InsForgeCore
import InsForgeFunctions

final class WhisperService {
    private let client = InsForgeClientProvider.shared

    /// Transcribe an audio file using the authenticated InsForge function.
    func transcribe(audioFileURL: URL, duration: TimeInterval? = nil) async throws -> String {
        let audioData = try Data(contentsOf: audioFileURL)
        let request = TranscriptionFunctionRequest(
            audioBase64: audioData.base64EncodedString(),
            fileName: "recording.wav",
            mimeType: "audio/wav",
            language: "en",
            durationSeconds: duration
        )

        print("[WhisperService] Sending \(audioData.count / 1024)KB audio to InsForge transcription function...")

        let result: WhisperResponse

        do {
            result = try await client.functions.invoke("transcribe-audio", body: request)
        } catch let error as InsForgeError {
            switch error {
            case .authenticationRequired, .unauthorized:
                throw WhisperError.authenticationRequired
            case .networkError(let underlyingError as URLError):
                if underlyingError.code == .notConnectedToInternet || underlyingError.code == .networkConnectionLost {
                    throw WhisperError.noInternet
                }
                throw WhisperError.requestFailed(underlyingError.localizedDescription)
            case .networkError(let underlyingError):
                throw WhisperError.requestFailed(underlyingError.localizedDescription)
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
                    throw WhisperError.authenticationRequired
                }

                if fullMessage.localizedCaseInsensitiveContains("OPENAI_API_KEY") {
                    throw WhisperError.transcriptionServiceUnavailable(
                        "The server transcription service is not configured yet."
                    )
                }

                throw WhisperError.apiError(statusCode, fullMessage.isEmpty ? message : fullMessage)
            default:
                throw WhisperError.requestFailed(error.localizedDescription)
            }
        } catch let error as URLError {
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw WhisperError.noInternet
            }
            throw WhisperError.requestFailed(error.localizedDescription)
        } catch {
            throw WhisperError.requestFailed(error.localizedDescription)
        }

        print("[WhisperService] Transcription: \(result.text)")
        return result.text
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

    nonisolated var errorDescription: String? {
        switch self {
        case .authenticationRequired: return "Your Voiyce session expired. Sign in again and retry."
        case .noInternet: return "No internet connection. Reconnect and try again."
        case .requestFailed(let message): return "Transcription request failed: \(message)"
        case .apiError(let code, let msg): return "Transcription service error \(code): \(msg)"
        case .transcriptionServiceUnavailable(let message): return message
        }
    }
}
