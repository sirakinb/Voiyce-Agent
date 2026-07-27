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

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .signedOut:
            return "Signed out"
        case .paymentRequired:
            return "Payment required"
        }
    }

    var recoveryStep: String {
        switch self {
        case .active:
            return "Continue using Voiyce."
        case .signedOut:
            return "Sign in again, then restart Dictation."
        case .paymentRequired:
            return "Get Voiyce at Pentridge Labs or refresh billing, then restart Dictation."
        }
    }
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
    private static let permissionReturnTabDefaultsKey = "permissionReturnTab"
    private static let permissionReturnSettingsTabDefaultsKey = "permissionReturnSettingsTab"
    nonisolated(unsafe) private static var pendingPermissionReturnTab: SidebarTab?
    nonisolated(unsafe) private static var pendingPermissionReturnSettingsTab: Int?

    var selectedTab: SidebarTab = .dashboard
    var selectedSettingsTab: Int = 0
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
    var isDemoVideoPresented: Bool = false

    func clearTransientRuntimeStateForTermination() {
        clearTransientRuntimeStateForInterruption()
    }

    func clearTransientRuntimeStateForSystemSleep() {
        clearTransientRuntimeStateForInterruption()
    }

    func clearTransientRuntimeStateForAccessLoss() {
        clearTransientRuntimeStateForInterruption()
    }

    private func clearTransientRuntimeStateForInterruption() {
        recordingState = .idle
        isDictationActive = false
        currentTranscript = ""
    }

    func rememberPermissionReturnTarget(tab: SidebarTab, settingsTab: Int? = nil) {
        Self.rememberPermissionReturnTarget(tab: tab, settingsTab: settingsTab)
    }

    static func rememberPermissionReturnTarget(tab: SidebarTab, settingsTab: Int? = nil) {
        pendingPermissionReturnTab = tab
        pendingPermissionReturnSettingsTab = settingsTab
        UserDefaults.standard.set(tab.rawValue, forKey: Self.permissionReturnTabDefaultsKey)
        if let settingsTab {
            UserDefaults.standard.set(settingsTab, forKey: Self.permissionReturnSettingsTabDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.permissionReturnSettingsTabDefaultsKey)
        }
        UserDefaults.standard.synchronize()
    }

    func restorePermissionReturnTargetIfNeeded() {
        if let pendingTab = Self.pendingPermissionReturnTab {
            selectedTab = pendingTab
            if let pendingSettingsTab = Self.pendingPermissionReturnSettingsTab {
                selectedSettingsTab = pendingSettingsTab
            }
            Self.clearPermissionReturnTarget()
            return
        }

        guard let rawTab = UserDefaults.standard.string(forKey: Self.permissionReturnTabDefaultsKey),
              let tab = SidebarTab(rawValue: rawTab) else {
            return
        }

        selectedTab = tab
        if UserDefaults.standard.object(forKey: Self.permissionReturnSettingsTabDefaultsKey) != nil {
            selectedSettingsTab = UserDefaults.standard.integer(forKey: Self.permissionReturnSettingsTabDefaultsKey)
        }

        Self.clearPermissionReturnTarget()
    }

    private static func clearPermissionReturnTarget() {
        pendingPermissionReturnTab = nil
        pendingPermissionReturnSettingsTab = nil
        UserDefaults.standard.removeObject(forKey: Self.permissionReturnTabDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.permissionReturnSettingsTabDefaultsKey)
        UserDefaults.standard.synchronize()
    }
}
