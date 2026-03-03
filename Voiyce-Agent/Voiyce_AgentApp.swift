//
//  Voiyce_AgentApp.swift
//  Voiyce-Agent
//

import SwiftUI
import SwiftData

@main
struct Voiyce_AgentApp: App {
    @State private var appState = AppState()
    @State private var permissionsManager = PermissionsManager()
    @State private var hotkeyManager = HotkeyManager()
    @State private var dictationCoordinator = DictationCoordinator()
    @State private var agentCoordinator = AgentCoordinator()

    var body: some Scene {
        WindowGroup("Voiyce Agent") {
            ContentView()
                .environment(appState)
                .environment(permissionsManager)
                .environment(agentCoordinator)
                .onAppear {
                    loadAPIKeys()
                    permissionsManager.checkAllPermissions()
                    setupHotkeys()
                }
        }
        .modelContainer(for: [Transcript.self, AgentConversation.self])

        MenuBarExtra("Voiyce", systemImage: "mic.fill") {
            MenuBarView()
                .environment(appState)
        }
    }

    private func loadAPIKeys() {
        if let claudeKey = KeychainManager.retrieve(key: AppConstants.claudeAPIKeyKey) {
            appState.claudeAPIKey = claudeKey
        }
        if let composioKey = KeychainManager.retrieve(key: AppConstants.composioAPIKeyKey) {
            appState.composioAPIKey = composioKey
        }
        if let openAIKey = KeychainManager.retrieve(key: AppConstants.openAIAPIKeyKey) {
            appState.openAIAPIKey = openAIKey
        }
    }

    private func setupHotkeys() {
        // Wire dictation hotkey: hold Control to dictate
        hotkeyManager.onDictationStart = { [self] in
            appState.recordingState = .listening
            appState.isDictationActive = true
            dictationCoordinator.openAIAPIKey = appState.openAIAPIKey
            dictationCoordinator.startDictation()
        }

        hotkeyManager.onDictationStop = { [self] in
            appState.recordingState = .processing
            appState.isDictationActive = false
            dictationCoordinator.stopDictation()

            // Update word count after a delay (transcription is async)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                let words = dictationCoordinator.totalInjectedText
                    .split(separator: " ").count
                if words > 0 {
                    appState.wordsToday += words
                }
                appState.recordingState = .idle
            }
        }

        // Wire agent hotkey: Option+Space to toggle agent listening
        hotkeyManager.onAgentStart = { [self] in
            appState.recordingState = .listening
            appState.isAgentActive = true
            agentCoordinator.claudeAPIKey = appState.claudeAPIKey
            agentCoordinator.composioAPIKey = appState.composioAPIKey
            agentCoordinator.voiceOutputEnabled = appState.voiceOutputEnabled
            agentCoordinator.startListening()
        }

        hotkeyManager.onAgentStop = { [self] in
            agentCoordinator.stopListening()
            appState.isAgentActive = false
            appState.recordingState = .processing
        }

        hotkeyManager.setup()
    }
}
