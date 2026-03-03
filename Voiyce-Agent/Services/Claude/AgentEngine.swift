import SwiftAnthropic
import Foundation

@Observable
final class AgentEngine {
    var isProcessing = false
    var currentMessages: [AgentMessage] = []
    var error: String?

    private let claudeService = ClaudeService()
    private let composioClient = ComposioClient()

    var onMessageAdded: ((AgentMessage) -> Void)?

    /// Process a user command through the agent loop
    func processCommand(_ command: String, claudeAPIKey: String, composioAPIKey: String) async {
        guard !command.isEmpty else { return }
        isProcessing = true
        error = nil

        // Add user message
        let userMessage = AgentMessage(role: .user, content: command)
        currentMessages.append(userMessage)
        onMessageAdded?(userMessage)

        do {
            // Try to get Composio tools, but don't fail if they're unavailable
            var claudeTools: [MessageParameter.Tool] = []
            if !composioAPIKey.isEmpty {
                do {
                    let composioTools = try await composioClient.getTools(apiKey: composioAPIKey)
                    claudeTools = AgentToolDefinitions.convertComposioTools(composioTools)
                } catch {
                    print("Composio tools unavailable: \(error). Proceeding without tools.")
                }
            }

            // Build message history for Claude
            var claudeMessages = currentMessages.compactMap { msg -> MessageParameter.Message? in
                switch msg.role {
                case .user:
                    return .init(role: .user, content: .text(msg.content))
                case .assistant:
                    return .init(role: .assistant, content: .text(msg.content))
                case .tool:
                    return nil
                }
            }

            // Agent loop - keeps running until Claude gives a final text response
            var continueLoop = true
            while continueLoop {
                let response = try await claudeService.sendMessage(
                    messages: claudeMessages,
                    tools: claudeTools.isEmpty ? nil : claudeTools,
                    apiKey: claudeAPIKey
                )

                // Process response content blocks
                var hasToolUse = false
                var assistantText = ""
                var assistantContentObjects: [MessageParameter.Message.Content.ContentObject] = []
                var toolUseItems: [(id: String, name: String, input: [String: MessageResponse.Content.DynamicContent])] = []

                for content in response.content {
                    switch content {
                    case .text(let text, _):
                        assistantText += text
                        assistantContentObjects.append(.text(text))
                    case .toolUse(let toolUse):
                        hasToolUse = true
                        assistantContentObjects.append(.toolUse(toolUse.id, toolUse.name, toolUse.input))
                        toolUseItems.append((id: toolUse.id, name: toolUse.name, input: toolUse.input))

                        // Show tool use in UI
                        let toolMessage = AgentMessage(
                            role: .tool,
                            content: "Executing: \(toolUse.name)",
                            toolName: toolUse.name
                        )
                        currentMessages.append(toolMessage)
                        onMessageAdded?(toolMessage)
                    default:
                        break
                    }
                }

                // Add assistant text to UI if present
                if !assistantText.isEmpty {
                    let assistantMessage = AgentMessage(role: .assistant, content: assistantText)
                    currentMessages.append(assistantMessage)
                    onMessageAdded?(assistantMessage)
                }

                if hasToolUse {
                    // Add assistant message with tool_use content to Claude history
                    claudeMessages.append(.init(role: .assistant, content: .list(assistantContentObjects)))

                    // Execute each tool and collect results
                    var toolResultObjects: [MessageParameter.Message.Content.ContentObject] = []
                    for toolUseItem in toolUseItems {
                        let inputData = try JSONEncoder().encode(toolUseItem.input)
                        let inputString = String(data: inputData, encoding: .utf8) ?? "{}"

                        let toolResult: String
                        do {
                            toolResult = try await composioClient.executeTool(
                                name: toolUseItem.name,
                                input: inputString,
                                apiKey: composioAPIKey
                            )
                        } catch {
                            toolResult = "Error executing tool: \(error.localizedDescription)"
                        }

                        toolResultObjects.append(.toolResult(toolUseItem.id, toolResult, nil, nil))

                        // Show result in UI
                        let resultMessage = AgentMessage(
                            role: .tool,
                            content: toolResult,
                            toolName: toolUseItem.name,
                            toolResult: toolResult
                        )
                        currentMessages.append(resultMessage)
                        onMessageAdded?(resultMessage)
                    }

                    // Add user message with tool results to Claude history
                    claudeMessages.append(.init(role: .user, content: .list(toolResultObjects)))
                }

                // Continue loop only if there was tool use
                continueLoop = hasToolUse && response.stopReason == "tool_use"
            }

        } catch {
            self.error = error.localizedDescription
            let errorMessage = AgentMessage(role: .assistant, content: "Error: \(error.localizedDescription)")
            currentMessages.append(errorMessage)
            onMessageAdded?(errorMessage)
        }

        isProcessing = false
    }

    func clearConversation() {
        currentMessages = []
        error = nil
    }
}
