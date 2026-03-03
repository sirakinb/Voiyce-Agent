//
//  AppConstants.swift
//  Voiyce-Agent
//

import Foundation

enum AppConstants {
    static let composioBaseURL = "https://backend.composio.dev/api/v3"
    static let keychainServiceName = "com.voiyce.agent"
    static let claudeAPIKeyKey = "claude_api_key"
    static let composioAPIKeyKey = "composio_api_key"
    static let openAIAPIKeyKey = "openai_api_key"
    static let defaultClaudeModel = "claude-sonnet-4-6-latest"
    static let maxDictationDuration: TimeInterval = 55
}
