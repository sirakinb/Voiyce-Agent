//
//  AppState.swift
//  Voiyce-Agent
//

import SwiftUI

// MARK: - SidebarTab

enum SidebarTab: String, CaseIterable, Identifiable {
    case dashboard
    #if VOIYCE_PRO
    case agent
    case agentLog
    #endif
    case settings

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        #if VOIYCE_PRO
        case .agent: "Agent"
        case .agentLog: "Agent Log"
        #endif
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "house"
        #if VOIYCE_PRO
        case .agent: "circle.hexagongrid.circle"
        case .agentLog: "list.bullet.rectangle"
        #endif
        case .settings: "gearshape"
        }
    }
}

#if VOIYCE_PRO
enum AgentCapabilityTier: String, CaseIterable, Identifiable {
    case defaultTier = "default"
    case pro
    case power

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultTier: "Default"
        case .pro: "Pro"
        case .power: "Power"
        }
    }

    var supportedModes: [AgentMode] {
        switch self {
        case .defaultTier:
            return [.off, .context, .talk]
        case .pro, .power:
            return AgentMode.allCases
        }
    }

    var fallbackMode: AgentMode {
        supportedModes.contains(.talk) ? .talk : .off
    }

    var memoryStorageTier: AgentMemoryStorageTier {
        switch self {
        case .defaultTier: .defaultTier
        case .pro: .pro
        case .power: .power
        }
    }

    var contextCaptureProfile: String {
        switch self {
        case .defaultTier:
            return "Limited context capture with conservative daily limits."
        case .pro:
            return "Higher Context and Talk limits with beta Act budgets."
        case .power:
            return "Full Act, long-running context, and higher memory limits."
        }
    }

    var userFacingLimitSummary: String {
        switch self {
        case .defaultTier:
            return "Default includes dictation plus limited Context and Talk. Act is a Pro/Power capability."
        case .pro:
            return "Pro keeps dictation active and enables Context, Talk, and selected Act capabilities under beta budgets."
        case .power:
            return "Power is reserved for full Act, long-running sessions, and the highest local memory limits."
        }
    }

    func supports(_ mode: AgentMode) -> Bool {
        supportedModes.contains(mode)
    }

    static func fromBilling(
        hasActiveSubscription: Bool,
        hasBetaAccess: Bool,
        hasPentridgeSubscription: Bool,
        pentridgeTier: String?,
        hasTrialAccess: Bool = false
    ) -> AgentCapabilityTier {
        if pentridgeTier?.lowercased() == "power" {
            return .power
        }

        if hasActiveSubscription || hasBetaAccess || hasPentridgeSubscription || hasTrialAccess {
            return .pro
        }

        return .defaultTier
    }
}

enum AgentMode: String, CaseIterable, Identifiable {
    case off
    case context
    case talk
    case act

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .context: "Context"
        case .talk: "Talk"
        case .act: "Act"
        }
    }

    var status: String {
        switch self {
        case .off: "Off"
        case .context: "Keeping context"
        case .talk: "Listening"
        case .act: "Working"
        }
    }

    var readyStatus: String {
        self == .off ? "Off" : "Ready"
    }

    var startsSessionContext: Bool {
        self != .off
    }

    var startsRealtimeVoice: Bool {
        switch self {
        case .talk, .act:
            return true
        case .off, .context:
            return false
        }
    }

    var enablesActions: Bool {
        self == .act
    }

    var headline: String {
        switch self {
        case .off: "Voiyce is quiet."
        case .context: "Quietly keeping context."
        case .talk: "Listening. Speak naturally."
        case .act: "Operating apps with your approval."
        }
    }

    var summary: String {
        switch self {
        case .off:
            return "No session memory, voice, or actions are active. Start Context, Talk, or Act when you want Voiyce to help."
        case .context:
            return "Voiyce keeps track of your work session so you can ask about it later. No voice. No actions."
        case .talk:
            return "Speak with Voiyce while you work. It can answer questions, help draft text, and use connected apps."
        case .act:
            return "Voiyce can help operate apps and websites for you. Sensitive actions require confirmation."
        }
    }

    var selfServeExplanation: String {
        switch self {
        case .off:
            return "Nothing is listening, watching, remembering, or acting."
        case .context:
            return "Keeps a private work timeline after you press Start. No voice or actions."
        case .talk:
            return "Starts voice plus context so you can ask about the screen, connected Google, and saved work."
        case .act:
            return "Adds controlled app operation. Confirmations and safety mode decide what can run."
        }
    }

    var selfServeControl: String {
        switch self {
        case .off:
            return "Use when you want Voiyce fully quiet."
        case .context:
            return "Stop pauses capture; Private Mode blocks durable memory."
        case .talk:
            return "Requires Microphone. Screen and Google access are used only when tools confirm them."
        case .act:
            return "Requires a safety choice, Screen Recording, and Accessibility before actions."
        }
    }

    var accent: Color {
        switch self {
        case .off: AppTheme.textSecondary
        case .context: Color(hex: 0x4DD3FF)
        case .talk: AppTheme.accent
        case .act: Color(hex: 0xF8C04E)
        }
    }

    var symbol: String {
        switch self {
        case .off: "circle"
        case .context: "moon"
        case .talk: "waveform"
        case .act: "cursorarrow"
        }
    }
}

struct AgentActivityStatus: Equatable {
    let title: String
    let detail: String
    let symbol: String
}

enum AgentSafetyMode: String, CaseIterable, Identifiable {
    case strict
    case normal
    case unrestricted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strict: "Strict"
        case .normal: "Normal"
        case .unrestricted: "Unrestricted"
        }
    }

    var subtitle: String {
        switch self {
        case .strict:
            return "Confirm most app, browser, email, file, and account actions."
        case .normal:
            return "Confirm sensitive actions while routine navigation can run faster."
        case .unrestricted:
            return "Allow broad computer control except full system deletion and prohibited actions."
        }
    }

    var symbol: String {
        switch self {
        case .strict: "lock.shield"
        case .normal: "shield"
        case .unrestricted: "exclamationmark.triangle"
        }
    }

    var tint: Color {
        switch self {
        case .strict: AppTheme.success
        case .normal: AppTheme.accent
        case .unrestricted: Color(hex: 0xF8C04E)
        }
    }
}

struct DisplayConfigurationRecovery {
    static let actStopSummary = "Voiyce paused Act because the display layout changed and screen coordinates may no longer match."
    static let actStopNextStep = "Review the screen, then start Act again."

    static func shouldStopAgent(mode: AgentMode, isAgentRunning: Bool) -> Bool {
        isAgentRunning && mode == .act
    }
}
#endif

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
            return "Sign in again, then restart Dictation, Context, Talk, or Act."
        case .paymentRequired:
            return "Choose a plan or refresh billing, then restart Dictation, Context, Talk, or Act."
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
    #if VOIYCE_PRO
    private static let agentModeDefaultsKey = "agentMode"
    private static let agentSafetyModeDefaultsKey = "agentSafetyMode"
    private static let agentSafetyModeConfirmedDefaultsKey = "agentSafetyModeConfirmed"
    #endif

    var selectedTab: SidebarTab = .dashboard
    var selectedSettingsTab: Int = 0
    var recordingState: RecordingState = .idle
    var isDictationActive: Bool = false
    var currentTranscript: String = ""
    var wordsToday: Int = 0
    var dictationSessionsToday: Int = 0
    var isOnboardingComplete: Bool = false
    var dictationHotkey: String = "Control"
    #if VOIYCE_PRO
    var agentHotkey: String = "Option"
    var agentActivationNonce: Int = 0
    var agentCapabilityTier: AgentCapabilityTier = .defaultTier
    var agentMode: AgentMode = .talk {
        didSet {
            UserDefaults.standard.set(agentMode.rawValue, forKey: Self.agentModeDefaultsKey)
        }
    }
    var agentSafetyMode: AgentSafetyMode = .normal {
        didSet {
            UserDefaults.standard.set(agentSafetyMode.rawValue, forKey: Self.agentSafetyModeDefaultsKey)
        }
    }
    var hasConfirmedAgentSafetyMode: Bool = false {
        didSet {
            UserDefaults.standard.set(hasConfirmedAgentSafetyMode, forKey: Self.agentSafetyModeConfirmedDefaultsKey)
        }
    }
    var isAgentRunning: Bool = false

    var agentActivityStatus: AgentActivityStatus? {
        guard isAgentRunning, agentMode != .off else { return nil }
        return AgentActivityStatus(
            title: "\(agentMode.title) active",
            detail: agentMode.status,
            symbol: agentMode.symbol
        )
    }
    #endif
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
        #if VOIYCE_PRO
        isAgentRunning = false
        #endif
    }

    init() {
        #if VOIYCE_PRO
        if AppConstants.isUITesting,
           ProcessInfo.processInfo.arguments.contains("--reset-agent-safety-choice") {
            UserDefaults.standard.removeObject(forKey: Self.agentSafetyModeConfirmedDefaultsKey)
            UserDefaults.standard.removeObject(forKey: Self.agentSafetyModeDefaultsKey)
        }
        if let rawMode = UserDefaults.standard.string(forKey: Self.agentModeDefaultsKey),
           let savedMode = AgentMode(rawValue: rawMode) {
            agentMode = savedMode
        }
        if let rawSafetyMode = UserDefaults.standard.string(forKey: Self.agentSafetyModeDefaultsKey),
           let savedSafetyMode = AgentSafetyMode(rawValue: rawSafetyMode) {
            agentSafetyMode = savedSafetyMode
        }
        hasConfirmedAgentSafetyMode = UserDefaults.standard.bool(forKey: Self.agentSafetyModeConfirmedDefaultsKey)
        #endif
    }

    #if VOIYCE_PRO
    func confirmAgentSafetyMode(_ mode: AgentSafetyMode) {
        agentSafetyMode = mode
        hasConfirmedAgentSafetyMode = true
    }

    func enforceAgentCapabilityTier() {
        if !agentCapabilityTier.supports(agentMode) {
            agentMode = agentCapabilityTier.fallbackMode
        }
    }
    #endif

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
