//
//  AppState.swift
//  Voiyce-Agent
//

import SwiftUI

// MARK: - SidebarTab

enum SidebarTab: String, CaseIterable, Identifiable {
    case dashboard
    case transcripts
    case agent
    case integrations
    case settings

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .transcripts: "Transcripts"
        case .agent: "Agent"
        case .integrations: "Integrations"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "house"
        case .transcripts: "doc.text"
        case .agent: "bubble.left.and.bubble.right"
        case .integrations: "square.grid.2x2"
        case .settings: "gearshape"
        }
    }
}

// MARK: - RecordingState

enum RecordingState {
    case idle
    case listening
    case processing

    var color: Color {
        switch self {
        case .idle: AppTheme.textSecondary
        case .listening: AppTheme.accent
        case .processing: AppTheme.warning
        }
    }

    var label: String {
        switch self {
        case .idle: "Idle"
        case .listening: "Listening..."
        case .processing: "Processing..."
        }
    }
}

// MARK: - AppState

@Observable
final class AppState {
    var selectedTab: SidebarTab = .dashboard
    var recordingState: RecordingState = .idle
    var isDictationActive: Bool = false
    var isAgentActive: Bool = false
    var currentTranscript: String = ""
    var wordsToday: Int = 0
    var tasksCompleted: Int = 0
    var claudeAPIKey: String = ""
    var composioAPIKey: String = ""
    var openAIAPIKey: String = ""
    var isOnboardingComplete: Bool = false
    var dictationHotkey: String = "Control"
    var agentHotkey: String = "Option+Space"
    var voiceOutputEnabled: Bool = false
}
