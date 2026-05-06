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

        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = true

        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: destinationURL)
                case .failed, .cancelled:
                    let error = exportSession.error ?? WhisperError.requestFailed("Audio compression failed.")
                    continuation.resume(throwing: error)
                default:
                    continuation.resume(throwing: WhisperError.requestFailed("Audio compression did not finish."))
                }
            }
        }
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
