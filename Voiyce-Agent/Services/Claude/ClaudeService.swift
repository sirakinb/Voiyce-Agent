import SwiftAnthropic
import Foundation

final class ClaudeService {
    private(set) var isConfigured = false

    var model: String = AppConstants.defaultClaudeModel
    var systemPrompt: String = """
    You are Voiyce, an AI assistant for knowledge work. You help users manage their email, calendar, \
    documents, and other productivity tools through voice commands. Be concise and action-oriented. \
    When using tools, explain briefly what you're doing. When showing results, format them clearly.
    """

    func configure(apiKey: String) {
        isConfigured = !apiKey.isEmpty
    }

    func sendMessage(
        messages: [MessageParameter.Message],
        tools: [MessageParameter.Tool]? = nil,
        apiKey: String
    ) async throws -> MessageResponse {
        print("[ClaudeService] Sending message with model: \(model), key prefix: \(String(apiKey.prefix(12)))..., messages: \(messages.count), tools: \(tools?.count ?? 0)")

        let service = AnthropicServiceFactory.service(apiKey: apiKey, betaHeaders: nil)

        let parameters = MessageParameter(
            model: .other(model),
            messages: messages,
            maxTokens: 4096,
            system: .text(systemPrompt),
            tools: tools
        )

        do {
            let response = try await service.createMessage(parameters)
            print("[ClaudeService] Response received, stop reason: \(response.stopReason ?? "nil")")
            return response
        } catch let error as APIError {
            print("[ClaudeService] APIError: \(error.displayDescription)")
            throw error
        } catch {
            print("[ClaudeService] Error: \(error)")
            throw error
        }
    }
}
