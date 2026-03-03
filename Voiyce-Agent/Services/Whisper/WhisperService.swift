import Foundation

final class WhisperService {
    private let endpoint = "https://api.openai.com/v1/audio/transcriptions"
    private let session = URLSession.shared

    /// Transcribe an audio file using OpenAI Whisper API
    func transcribe(audioFileURL: URL, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw WhisperError.missingAPIKey
        }

        guard let url = URL(string: endpoint) else {
            throw WhisperError.invalidURL
        }

        // Build multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let audioData = try Data(contentsOf: audioFileURL)
        var body = Data()

        // model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // response_format field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        // language field (optional, helps accuracy)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)

        // audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("[WhisperService] Sending \(audioData.count / 1024)KB audio to Whisper API...")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[WhisperService] API error \(httpResponse.statusCode): \(errorBody)")
            throw WhisperError.apiError(httpResponse.statusCode, errorBody)
        }

        let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
        print("[WhisperService] Transcription: \(result.text)")
        return result.text
    }
}

struct WhisperResponse: Codable {
    let text: String
}

enum WhisperError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(Int, String)

    nonisolated var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "OpenAI API key not set. Add it in Settings."
        case .invalidURL: return "Invalid Whisper API URL"
        case .invalidResponse: return "Invalid response from Whisper API"
        case .apiError(let code, let msg): return "Whisper API error \(code): \(msg)"
        }
    }
}
