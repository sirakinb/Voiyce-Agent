//
//  AppState.swift
//  Voiyce-Agent
//

import SwiftUI

// MARK: - SidebarTab

enum SidebarTab: String, CaseIterable, Identifiable {
    case dashboard
    case settings

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "house"
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

enum AccessState {
    case active
    case signedOut
    case paymentRequired
}

enum OnboardingPrivacyPreference: String {
    case unset
    case standard
    case privateMode

    var title: String {
        switch self {
        case .unset:
            return "Not Chosen"
        case .standard:
            return "Help Improve Voiyce"
        case .privateMode:
            return "Privacy Mode"
        }
    }

    var summary: String {
        switch self {
        case .unset:
            return "Pick the data mode that fits your comfort level."
        case .standard:
            return "Allows anonymized usage improvements while you evaluate the product."
        case .privateMode:
            return "Keeps your dictation data out of product-improvement training while still using Voiyce transcription."
        }
    }
}

// MARK: - AppState

@Observable
final class AppState {
    var selectedTab: SidebarTab = .dashboard
    var recordingState: RecordingState = .idle
    var isDictationActive: Bool = false
    var currentTranscript: String = ""
    var wordsToday: Int = 0
    var dictationSessionsToday: Int = 0
    var isOnboardingComplete: Bool = false
    var dictationHotkey: String = "Control"
    var accessState: AccessState = .signedOut
    var onboardingDiscoverySource: String = ""
    var onboardingRole: String = ""
    var onboardingPrivacyPreference: OnboardingPrivacyPreference = .unset
}
