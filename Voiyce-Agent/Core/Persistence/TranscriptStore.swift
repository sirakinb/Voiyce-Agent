//
//  TranscriptStore.swift
//  Voiyce-Agent
//

import SwiftData
import Foundation

@Model
final class Transcript {
    var id: UUID
    var text: String
    var date: Date
    var appName: String
    var wordCount: Int
    var duration: TimeInterval

    init(text: String, appName: String, duration: TimeInterval = 0) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.appName = appName
        self.wordCount = text.split(separator: " ").count
        self.duration = duration
    }
}

@Model
final class AgentConversation {
    var id: UUID
    var title: String
    var date: Date
    var messages: [AgentMessage]

    init(title: String = "New Conversation") {
        self.id = UUID()
        self.title = title
        self.date = Date()
        self.messages = []
    }
}

struct AgentMessage: Codable, Identifiable, Hashable {
    var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    var toolName: String?
    var toolResult: String?

    init(role: MessageRole, content: String, toolName: String? = nil, toolResult: String? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.toolName = toolName
        self.toolResult = toolResult
    }

    enum MessageRole: String, Codable {
        case user
        case assistant
        case tool
    }
}
