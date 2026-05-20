#if VOIYCE_PRO
import SwiftUI
import WebKit

enum AgentRuntimeLaunchCopy {
    static let sessionContextFailedStatus = "Needs review"

    static let visibleStrings = [
        sessionContextFailedStatus
    ]
}

struct RealtimeAgentView: View {
    @Environment(AppState.self) private var appState
    @Environment(PermissionsManager.self) private var permissions
    @State private var server = RealtimeAgentServer.shared
    @State private var agentBridge = RealtimeAgentBridge.shared
    @State private var agentEvents = AgentEventStore.shared
    @State private var agentMemory = AgentLongTermMemoryStore.shared
    @State private var sessionContext = VideoDBAgentMemory.shared
    @State private var computerUseAgent = ComputerUseAgent()
    @State private var nativeActExecutor = NativeActExecutor.shared
    @State private var actCommand = ""
    @State private var actCommandStatus: String?
    @State private var agentRecoveryStatus: String?
    @State private var isActCommandRunning = false
    @State private var actCommandTask: Task<Void, Never>?

    private var mode: AgentMode { appState.agentMode }
    private var capabilityTier: AgentCapabilityTier { appState.agentCapabilityTier }
    private var availableModes: [AgentMode] { capabilityTier.supportedModes }
    private var isActive: Bool { (appState.isAgentRunning || isActCommandRunning) && mode != .off }
    private var actNeedsSafetyChoice: Bool { mode == .act && !appState.hasConfirmedAgentSafetyMode }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                modeSelector
                modeMap
                stage
                capabilitySummary
                contextConsentPanel

                if mode == .act {
                    safetyPanel
                    actCommandPanel
                }

                footer
            }
            .frame(maxWidth: 880)
            .padding(.horizontal, 56)
            .padding(.vertical, 44)
            .frame(maxWidth: .infinity)
        }
        .background(GroovedBackground())
        .overlay(alignment: .bottomTrailing) {
            if let url = server.url {
                RealtimeAgentWebView(url: url, bridge: agentBridge)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            appState.enforceAgentCapabilityTier()
            server.start()
            permissions.checkAllPermissions()
            agentBridge.onRecoverableFailure = { event in
                handleRealtimeConnectionFailure(event)
            }
        }
        .onChange(of: appState.agentMode) { _, newMode in
            if newMode == .off {
                stopAgent()
            }
        }
        .onChange(of: appState.agentActivationNonce) { _, _ in
            toggleSelectedMode()
        }
        .onChange(of: permissions.microphoneGranted) { _, _ in
            handleActivePermissionChange()
        }
        .onChange(of: permissions.accessibilityGranted) { _, _ in
            handleActivePermissionChange()
        }
        .onChange(of: permissions.screenRecordingGranted) { _, _ in
            handleActivePermissionChange()
        }
        .onChange(of: agentMemory.isPrivateModeEnabled) { _, _ in
            enforceSessionContextPrivacy()
        }
        .onChange(of: agentMemory.excludedPatternsText) { _, _ in
            enforceSessionContextPrivacy()
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiyceAgentStopRequested)) { _ in
            stopAgent()
        }
    }

    private var statusTitle: String {
        guard isActive else {
            return agentRecoveryStatus == nil ? mode.readyStatus : "Needs attention"
        }
        if isSessionContextPaused, mode == .context {
            return "Paused"
        }
        if isSessionContextFailed, mode == .context {
            return AgentRuntimeLaunchCopy.sessionContextFailedStatus
        }
        return mode.status
    }

    private var statusHeadline: String {
        guard isActive else {
            return agentRecoveryStatus ?? mode.headline
        }
        if isSessionContextFailed {
            return sessionContext.lastError ?? sessionContext.lastEvent
        }
        if isSessionContextPaused {
            return sessionContext.lastEvent
        }
        return mode.headline
    }

    private var isSessionContextPaused: Bool {
        sessionContext.lastEvent.localizedCaseInsensitiveContains("live session context is paused")
    }

    private var isSessionContextFailed: Bool {
        sessionContext.status == .failed
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isActive ? mode.accent : AppTheme.textSecondary.opacity(0.6))
                        .frame(width: 5, height: 5)
                    Text("Voiyce / Agent")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text("Agent")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Choose how Voiyce works with you.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Text("Hotkey")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("⌥")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppTheme.ridge, lineWidth: 1))
                Text("toggles \(mode.title)")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.ridge.opacity(0.8), lineWidth: 1))
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 2) {
            ForEach(availableModes) { item in
                Button {
                    setMode(item)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(appState.agentMode == item ? item.accent : AppTheme.textSecondary.opacity(0.45))
                            .frame(width: 6, height: 6)
                            .shadow(color: appState.agentMode == item && appState.isAgentRunning && item != .off ? item.accent.opacity(0.65) : .clear, radius: 5)
                        Text(item.title)
                            .font(.system(size: 13.5, weight: .medium))
                    }
                    .foregroundStyle(appState.agentMode == item ? AppTheme.textPrimary : AppTheme.textSecondary)
                    .frame(minWidth: 92)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(appState.agentMode == item ? item.accent.opacity(item == .off ? 0.08 : 0.14) : .clear)
                    )
                    .overlay(
                        Capsule()
                            .stroke(appState.agentMode == item ? .white.opacity(0.08) : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("agent-mode-\(item.rawValue)")
            }
        }
        .padding(4)
        .background(.white.opacity(0.02))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppTheme.ridge.opacity(0.85), lineWidth: 1))
    }

    private var modeMap: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("AGENT MODE MAP")
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text("Start is explicit")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 10)], spacing: 10) {
                ForEach(AgentMode.allCases) { item in
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 8) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(item.accent)
                                .frame(width: 24, height: 24)
                                .background(item.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 7))

                            Text(item.title)
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }

                        Text(item.selfServeExplanation)
                            .font(.system(size: 12.5))
                            .lineSpacing(3)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(item.selfServeControl)
                            .font(.system(size: 11.5))
                            .lineSpacing(2)
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(14)
                    .background(appState.agentMode == item ? item.accent.opacity(0.055) : Color.white.opacity(0.014))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(appState.agentMode == item ? item.accent.opacity(0.22) : AppTheme.ridge.opacity(0.65), lineWidth: 1))
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.012))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.ridge.opacity(0.76), lineWidth: 1))
    }

    private var stage: some View {
        VStack(spacing: 14) {
            AgentHalo(mode: mode, isActive: isActive)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text("●")
                        .foregroundStyle(isActive ? mode.accent : AppTheme.textSecondary.opacity(0.7))
                    Text("STATUS")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text(statusTitle)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(statusHeadline)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.top, -36)

            HStack(spacing: 10) {
                if isActive {
                    AgentButton(title: "Stop", systemImage: "stop.fill", variant: .stop) {
                        stopAgent()
                    }
                    .accessibilityIdentifier("agent-primary-action")
                } else {
                    AgentButton(
                        title: "Start \(mode.title)",
                        systemImage: "play.fill",
                        variant: .primary(mode == .off ? AppTheme.textSecondary : mode.accent),
                        disabled: mode == .off || actNeedsSafetyChoice
                    ) {
                        startSelectedMode()
                    }
                    .accessibilityIdentifier("agent-primary-action")
                }

                AgentButton(title: "Set to Off", systemImage: nil, variant: .ghost) {
                    setMode(.off)
                }
                .accessibilityIdentifier("agent-set-off")
            }
            .padding(.top, 14)
        }
        .padding(.top, 20)
    }

    private var capabilitySummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(mode.title.uppercased()) · WHAT IT CAN DO")
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Text(capabilities.isEmpty ? "Nothing active" : "\(capabilities.count) capabilities")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
            }

            Text(mode.summary)
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(AppTheme.textSecondary)

            Text(capabilityTier.userFacingLimitSummary)
                .font(.system(size: 12.5))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.82))

            if !capabilities.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                    ForEach(capabilities) { capability in
                        HStack(spacing: 12) {
                            Image(systemName: capability.symbol)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(mode.accent)
                                .frame(width: 30, height: 30)
                                .background(mode.accent.opacity(0.13))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.08), lineWidth: 1))

                            Text(capability.title)
                                .font(.system(size: 13.5))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.ridge.opacity(0.65), lineWidth: 1))
                    }
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.015))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.ridge.opacity(0.8), lineWidth: 1))
    }

    private var contextConsentPanel: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: mode == .off ? "pause.circle" : "checkmark.shield")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(mode == .off ? AppTheme.textSecondary : mode.accent)
                .frame(width: 34, height: 34)
                .background((mode == .off ? AppTheme.textSecondary : mode.accent).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.08), lineWidth: 1))

            VStack(alignment: .leading, spacing: 6) {
                Text("Context stays off until you start.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Context, Talk, and Act begin capture only after you press Start or tap Option. Stop pauses capture. Private Mode pauses live context and skips saved memory/screenshots.")
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        consentChip("Start begins capture")
                        consentChip("Stop pauses capture")
                        consentChip("Private Mode pauses context")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        consentChip("Start begins capture")
                        consentChip("Stop pauses capture")
                        consentChip("Private Mode pauses context")
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background((mode == .off ? Color.white.opacity(0.012) : mode.accent.opacity(0.035)))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.ridge.opacity(0.72), lineWidth: 1))
    }

    private func consentChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(mode == .off ? AppTheme.textSecondary : mode.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background((mode == .off ? Color.white : mode.accent).opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppTheme.ridge.opacity(0.55), lineWidth: 1))
    }

    private var safetyPanel: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "shield")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AgentMode.act.accent)
                .frame(width: 36, height: 36)
                .background(AgentMode.act.accent.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AgentMode.act.accent.opacity(0.22), lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                Text(appState.hasConfirmedAgentSafetyMode ? "You stay in control." : "Choose Act safety first.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(appState.hasConfirmedAgentSafetyMode
                     ? appState.agentSafetyMode.subtitle
                     : "Pick how much approval Voiyce should ask for before Act can start. You can change this later in Settings.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 8) {
                    ForEach(AgentSafetyMode.allCases) { safetyMode in
                        let isSelected = appState.hasConfirmedAgentSafetyMode && appState.agentSafetyMode == safetyMode
                        Button {
                            appState.confirmAgentSafetyMode(safetyMode)
                            logSafetyModeChange(safetyMode)
                        } label: {
                            Label(safetyMode.title, systemImage: isSelected ? "checkmark.circle.fill" : safetyMode.symbol)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(isSelected ? safetyMode.tint : AppTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background((isSelected ? safetyMode.tint : Color.white).opacity(isSelected ? 0.12 : 0.05))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(isSelected ? safetyMode.tint.opacity(0.24) : AppTheme.ridge.opacity(0.6), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("agent-safety-\(safetyMode.rawValue)")
                    }
                }
            }
            Spacer()
        }
        .padding(20)
        .background(AgentMode.act.accent.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AgentMode.act.accent.opacity(0.16), lineWidth: 1))
    }

    private var actCommandPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "command")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AgentMode.act.accent)
                    .frame(width: 36, height: 36)
                    .background(AgentMode.act.accent.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AgentMode.act.accent.opacity(0.22), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Act command")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Run a bounded action pass on the current screen.")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                TextField("Example: click the Settings tab", text: $actCommand)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(.white.opacity(0.025))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.ridge.opacity(0.75), lineWidth: 1))
                    .onSubmit {
                        runActCommand()
                    }
                    .accessibilityIdentifier("act-command-field")

                AgentButton(
                    title: isActCommandRunning ? "Running" : "Run",
                    systemImage: isActCommandRunning ? "hourglass" : "arrow.up.right",
                    variant: .primary(AgentMode.act.accent),
                    disabled: isActCommandRunning
                        || !permissions.screenRecordingGranted
                        || !appState.hasConfirmedAgentSafetyMode
                        || actCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    runActCommand()
                }
                .accessibilityIdentifier("act-command-run")
            }

            if !appState.hasConfirmedAgentSafetyMode {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 12))
                        .foregroundStyle(AgentMode.act.accent)
                    Text("Choose Strict, Normal, or Unrestricted before running an Act command.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            if !permissions.screenRecordingGranted {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "rectangle.on.rectangle.slash")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.warning)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(permissions.screenRecordingStatusMessage ?? "Screen Recording is off for this Voiyce build.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.textSecondary)

                        HStack(spacing: 8) {
                            Button("Grant Screen Recording") {
                                rememberPermissionReturn()
                                permissions.requestScreenRecordingPermission()
                            }
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(AgentMode.act.accent)
                            .buttonStyle(.plain)

                            Button("Open Settings") {
                                rememberPermissionReturn()
                                permissions.openScreenRecordingSettings()
                            }
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()
                }
                .padding(12)
                .background(AppTheme.warning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.warning.opacity(0.18), lineWidth: 1))
            }

            if let actCommandStatus {
                Text(actCommandStatus)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(20)
        .background(.white.opacity(0.015))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.ridge.opacity(0.8), lineWidth: 1))
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 13))
                Text("Dictation stays separate. Hold Control as usual.")
                    .font(.system(size: 12.5))
            }
            .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Button {
                AgentFocusToolPaletteOverlay.shared.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Tools")
                }
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.ridge.opacity(0.8), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                FocusHighlightOverlay.shared.beginSelection()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Mark Focus")
                }
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.ridge.opacity(0.8), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                FocusHighlightOverlay.shared.beginSelection(mode: .paint)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paintbrush")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Paint")
                }
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.ridge.opacity(0.8), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                FocusHighlightOverlay.shared.beginSelection(mode: .underline)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "underline")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Underline")
                }
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.ridge.opacity(0.8), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                appState.selectedTab = .agentLog
            } label: {
                HStack(spacing: 6) {
                    Text("View Agent Log")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.ridge.opacity(0.8), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var capabilities: [AgentCapability] {
        switch mode {
        case .off:
            return []
        case .context:
            return [
                AgentCapability(symbol: "memorychip", title: "Remembers what you worked on"),
                AgentCapability(symbol: "clock", title: "Builds a private session timeline")
            ]
        case .talk:
            return [
                AgentCapability(symbol: "mic", title: "Hands-free voice conversation"),
                AgentCapability(symbol: "text.cursor", title: "Drafts text and replies"),
                AgentCapability(symbol: "envelope", title: "Uses Gmail and Calendar when connected")
            ]
        case .act:
            return [
                AgentCapability(symbol: "cursorarrow.click", title: "Click, type, navigate, and fill forms"),
                AgentCapability(symbol: "globe", title: "Open apps and websites"),
                AgentCapability(symbol: "shield", title: "Asks before sending, deleting, or purchasing")
            ]
        }
    }

    private func enforceSessionContextPrivacy() {
        guard appState.isAgentRunning, mode != .off, !AppConstants.isUITesting else { return }

        let contextSnapshot = AgentSessionContextSnapshot.current()
        guard agentMemory.liveSessionContextBlockReason(for: contextSnapshot) != nil else { return }

        Task { @MainActor in
            _ = await sessionContext.start(privacyStore: agentMemory, contextSnapshot: contextSnapshot)
        }
    }

    private func setMode(_ newMode: AgentMode) {
        let previousMode = appState.agentMode
        guard previousMode != newMode else { return }
        guard capabilityTier.supports(newMode) else {
            agentRecoveryStatus = "\(newMode.title) is not available on the \(capabilityTier.title) tier."
            return
        }

        agentRecoveryStatus = nil
        appState.agentMode = newMode
        agentEvents.append(
            category: category(for: newMode),
            status: .done,
            symbol: newMode.symbol,
            title: "Mode selected",
            summary: "Agent mode changed to \(newMode.title).",
            details: [
                AgentLogEventDetail(key: "Previous", value: previousMode.title),
                AgentLogEventDetail(key: "Current", value: newMode.title),
                AgentLogEventDetail(key: "Live update", value: appState.isAgentRunning && newMode != .off ? "Applied" : "Not running")
            ]
        )

        if newMode == .off {
            stopAgent(stoppedModeOverride: previousMode)
        } else if appState.isAgentRunning {
            updateRunningAgentMode(from: previousMode, to: newMode)
        }
    }

    private func updateRunningAgentMode(from previousMode: AgentMode, to newMode: AgentMode) {
        Task { @MainActor in
            switch newMode {
            case .off:
                return
            default:
                agentBridge.stop()
            }

            if newMode.startsSessionContext {
                let contextResult = await VideoDBAgentMemory.shared.start()
                if handleContextStartFailureIfNeeded(contextResult, for: newMode) {
                    return
                }
            }

            if newMode.startsRealtimeVoice {
                try? await Task.sleep(nanoseconds: 180_000_000)
                await agentBridge.connect(mode: newMode)
            }

            agentEvents.append(
                category: category(for: newMode),
                status: .done,
                symbol: newMode.symbol,
                title: "Running mode updated",
                summary: "Voiyce switched the active session from \(previousMode.title) to \(newMode.title).",
                details: [
                    AgentLogEventDetail(key: "Previous", value: previousMode.title),
                    AgentLogEventDetail(key: "Current", value: newMode.title)
                ]
            )
        }
    }

    private func toggleSelectedMode() {
        if appState.isAgentRunning {
            stopAgent()
        } else {
            startSelectedMode()
        }
    }

    private func startSelectedMode() {
        guard mode != .off else { return }
        guard !appState.isAgentRunning else { return }
        guard capabilityTier.supports(mode) else {
            agentRecoveryStatus = "\(mode.title) is not available on the \(capabilityTier.title) tier."
            return
        }
        guard mode != .act || appState.hasConfirmedAgentSafetyMode else {
            actCommandStatus = "Choose a safety mode before starting Act."
            return
        }
        guard !blockModeForMissingPermissionIfNeeded(mode) else { return }

        agentRecoveryStatus = nil
        appState.isAgentRunning = true
        appState.selectedTab = .agent
        logSessionStart(for: mode)
        let startedMode = mode

        Task {
            if AppConstants.isUITesting {
                return
            }

            if startedMode.startsSessionContext {
                let contextResult = await VideoDBAgentMemory.shared.start()
                if handleContextStartFailureIfNeeded(contextResult, for: startedMode) {
                    return
                }
            }

            if startedMode.startsRealtimeVoice {
                await agentBridge.connect(mode: startedMode)
            }
        }
    }

    @discardableResult
    private func handleContextStartFailureIfNeeded(_ result: AgentToolResult, for startedMode: AgentMode) -> Bool {
        guard AgentSessionContextStartRecovery.shouldStopActiveAgent(mode: startedMode, result: result) else {
            return false
        }
        guard appState.agentMode == startedMode, appState.isAgentRunning else {
            return true
        }

        let nextStep = AgentSessionContextStartRecovery.nextStep(from: result)
        appState.isAgentRunning = false
        agentRecoveryStatus = result.message
        agentEvents.append(
            category: category(for: startedMode),
            status: .failed,
            symbol: "exclamationmark.triangle",
            title: "\(startedMode.title) startup stopped",
            summary: result.message,
            details: [
                AgentLogEventDetail(key: "Mode", value: startedMode.title),
                AgentLogEventDetail(key: "Next step", value: nextStep)
            ]
        )
        return true
    }

    private func stopAgent(stoppedModeOverride: AgentMode? = nil) {
        let wasRunning = appState.isAgentRunning
        let wasActCommandRunning = isActCommandRunning
        let stoppedMode = stoppedModeOverride ?? mode
        actCommandTask?.cancel()
        actCommandTask = nil
        if wasActCommandRunning {
            isActCommandRunning = false
            actCommandStatus = "Act command stopped."
        }
        agentRecoveryStatus = nil
        appState.isAgentRunning = false
        agentBridge.stop()
        Task {
            if AppConstants.isUITesting {
                return
            }

            if stoppedMode != .off {
                VideoDBAgentMemory.shared.stopLocalCaptureForUserStop()
                let summary = await VideoDBAgentMemory.shared.summarize()
                if summary.ok, !summary.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    AgentLongTermMemoryStore.shared.addRecord(
                        source: "\(stoppedMode.title) session",
                        summary: summary.message,
                        searchableText: summary.data?["summary"] ?? "",
                        tags: ["session", stoppedMode.rawValue],
                        appHint: nil
                    )
                }
            }
            await VideoDBAgentMemory.shared.stop()
        }

        if wasActCommandRunning {
            agentEvents.append(
                category: .actions,
                status: .cancelled,
                symbol: "stop.fill",
                title: "Act command stopped",
                summary: "The user stopped the active Act command.",
                details: [
                    AgentLogEventDetail(key: "Mode", value: AgentMode.act.title),
                    AgentLogEventDetail(key: "Command", value: actCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not provided" : actCommand)
                ]
            )
        }

        if wasRunning {
            agentEvents.append(
                category: category(for: stoppedMode),
                status: .done,
                symbol: "stop.fill",
                title: "Session stopped",
                summary: "Voiyce paused \(stoppedMode.title) mode.",
                details: [
                    AgentLogEventDetail(key: "Mode", value: stoppedMode.title),
                    AgentLogEventDetail(key: "Memory", value: "Local session context retained")
                ]
            )
        }
    }

    private func handleRealtimeConnectionFailure(_ event: RealtimeTelemetryEvent) {
        guard event.mode.startsRealtimeVoice, event.mode == appState.agentMode else { return }
        guard appState.isAgentRunning else { return }

        let recovery = RealtimeConnectionFailureRecovery.recovery(for: event)
        appState.isAgentRunning = false
        agentRecoveryStatus = recovery.message
        agentBridge.stop()

        Task {
            if AppConstants.isUITesting {
                return
            }
            await VideoDBAgentMemory.shared.stop()
        }

        agentEvents.append(
            category: category(for: event.mode),
            status: .failed,
            symbol: "exclamationmark.triangle",
            title: "\(event.mode.title) startup stopped",
            summary: recovery.message,
            details: [
                AgentLogEventDetail(key: "Mode", value: event.mode.title),
                AgentLogEventDetail(key: "Reason", value: event.failureReason ?? "Connection failed"),
                AgentLogEventDetail(key: "Next step", value: recovery.nextStep)
            ]
        )
    }

    private func handleActivePermissionChange() {
        let activeMode = isActCommandRunning ? AgentMode.act : mode
        guard appState.isAgentRunning || isActCommandRunning else { return }
        guard let recovery = permissionRecovery(for: activeMode) else { return }

        if isActCommandRunning {
            actCommandTask?.cancel()
            actCommandTask = nil
            isActCommandRunning = false
            actCommandStatus = recovery.message
        }

        if appState.isAgentRunning {
            stopAgent(stoppedModeOverride: activeMode)
        }

        agentRecoveryStatus = recovery.message
        logPermissionRecovery(recovery, mode: activeMode)
    }

    @discardableResult
    private func blockModeForMissingPermissionIfNeeded(_ mode: AgentMode) -> Bool {
        guard let recovery = permissionRecovery(for: mode) else { return false }
        agentRecoveryStatus = recovery.message
        if mode == .act {
            actCommandStatus = recovery.message
        }
        logPermissionRecovery(recovery, mode: mode)
        rememberPermissionReturn()
        return true
    }

    private func permissionRecovery(for mode: AgentMode) -> AgentPermissionRecovery? {
        AgentPermissionRecovery.recovery(
            mode: mode,
            microphoneGranted: permissions.microphoneGranted,
            accessibilityGranted: permissions.accessibilityGranted,
            screenRecordingGranted: permissions.screenRecordingGranted
        )
    }

    private func logPermissionRecovery(_ recovery: AgentPermissionRecovery, mode: AgentMode) {
        agentEvents.appendPermissionBlock(
            feature: "\(mode.title) Mode",
            permission: recovery.permissionName,
            message: recovery.message,
            nextStep: recovery.nextStep
        )
    }

    private func logSessionStart(for mode: AgentMode) {
        let summary: String
        let details: [AgentLogEventDetail]

        switch mode {
        case .context:
            summary = "Voiyce quietly began keeping context for this work session."
            details = [
                AgentLogEventDetail(key: "Mode", value: mode.title),
                AgentLogEventDetail(key: "Memory", value: "Session context"),
                AgentLogEventDetail(key: "Actions", value: "Disabled")
            ]
        case .talk:
            summary = "Voice started with session context active."
            details = [
                AgentLogEventDetail(key: "Mode", value: mode.title),
                AgentLogEventDetail(key: "Voice", value: "Conversation"),
                AgentLogEventDetail(key: "Memory", value: "Session context")
            ]
        case .act:
            summary = "Voice started with action tools prepared."
            details = [
                AgentLogEventDetail(key: "Mode", value: mode.title),
                AgentLogEventDetail(key: "Safety", value: appState.agentSafetyMode.title),
                AgentLogEventDetail(key: "Executor", value: "Action tools ready")
            ]
        case .off:
            return
        }

        agentEvents.append(
            category: category(for: mode),
            status: .done,
            symbol: mode.symbol,
            title: "\(mode.title) session started",
            summary: summary,
            details: details
        )
    }

    private func logSafetyModeChange(_ safetyMode: AgentSafetyMode) {
        agentEvents.append(
            category: .memory,
            status: .done,
            symbol: safetyMode.symbol,
            title: "Safety mode changed",
            summary: "Agent safety mode is now \(safetyMode.title).",
            details: [
                AgentLogEventDetail(key: "Mode", value: safetyMode.title),
                AgentLogEventDetail(key: "Policy", value: safetyMode.subtitle)
            ]
        )
    }

    private func category(for mode: AgentMode) -> AgentLogCategory {
        switch mode {
        case .off:
            return .memory
        case .context:
            return .memory
        case .talk:
            return .voice
        case .act:
            return .actions
        }
    }

    private func rememberPermissionReturn() {
        appState.rememberPermissionReturnTarget(tab: .agent)
    }

    private func runActCommand() {
        let task = actCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty, !isActCommandRunning else { return }
        guard capabilityTier.supports(.act) else {
            actCommandStatus = "\(AgentMode.act.title) is not available on the \(capabilityTier.title) tier."
            return
        }
        guard appState.hasConfirmedAgentSafetyMode else {
            actCommandStatus = "Choose a safety mode before running Act."
            return
        }

        isActCommandRunning = true
        appState.agentMode = .act
        actCommandStatus = "Starting Act command..."
        agentEvents.append(
            category: .actions,
            status: .waiting,
            symbol: "cursorarrow.click",
            title: "Act command started",
            summary: task,
            details: [
                AgentLogEventDetail(key: "Safety", value: appState.agentSafetyMode.title),
                AgentLogEventDetail(key: "Stop", value: "Available")
            ]
        )

        if AppConstants.isUITesting && task.localizedCaseInsensitiveContains("hold active act command") {
            actCommandTask = Task {
                defer {
                    actCommandTask = nil
                }

                actCommandStatus = "Working on the action..."
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled else {
                    isActCommandRunning = false
                    actCommandStatus = "Act command stopped."
                    return
                }
                actCommandStatus = "Act command finished."
                isActCommandRunning = false
            }
            return
        }

        actCommandTask = Task {
            defer {
                actCommandTask = nil
            }

            guard !Task.isCancelled else {
                isActCommandRunning = false
                actCommandStatus = "Act command stopped."
                return
            }

            if let nativeResult = await nativeActExecutor.run(task: task, appState: appState) {
                guard !Task.isCancelled else {
                    isActCommandRunning = false
                    actCommandStatus = "Act command stopped."
                    return
                }
                actCommandStatus = nativeResult.message
                isActCommandRunning = false
                return
            }

            guard !Task.isCancelled else {
                isActCommandRunning = false
                actCommandStatus = "Act command stopped."
                return
            }

            guard permissions.screenRecordingGranted else {
                let message = "Screen Recording is off. Grant access for this Voiyce build, then quit and reopen Voiyce if macOS keeps showing the old permission state."
                actCommandStatus = message
                AgentEventStore.shared.appendPermissionBlock(
                    feature: "Act command",
                    permission: "Screen Recording",
                    message: message,
                    nextStep: "Open Voiyce Settings > Permissions, grant Screen Recording, then quit and reopen Voiyce if macOS keeps showing the old state."
                )
                rememberPermissionReturn()
                permissions.requestScreenRecordingPermission()
                isActCommandRunning = false
                return
            }

            actCommandStatus = "Working on the action..."
            let result = await computerUseAgent.run(task: task, safetyMode: appState.agentSafetyMode)
            guard !Task.isCancelled else {
                isActCommandRunning = false
                actCommandStatus = "Act command stopped."
                return
            }
            actCommandStatus = result.message
            isActCommandRunning = false
        }
    }
}

private struct AgentCapability: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
}

struct AgentSessionContextStartRecovery {
    static let defaultNextStep = "Review the Agent status, then try again."

    static func shouldStopActiveAgent(mode: AgentMode, result: AgentToolResult) -> Bool {
        mode == .context && !result.ok
    }

    static func nextStep(from result: AgentToolResult) -> String {
        let trimmed = result.data?["next_step"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? defaultNextStep : trimmed
    }
}

struct AgentPermissionRecovery: Equatable {
    let permissionName: String
    let message: String
    let nextStep: String

    static func recovery(
        mode: AgentMode,
        microphoneGranted: Bool,
        accessibilityGranted: Bool,
        screenRecordingGranted: Bool
    ) -> AgentPermissionRecovery? {
        switch mode {
        case .off:
            return nil
        case .context:
            if !microphoneGranted {
                return microphone(mode: mode)
            }
            if !screenRecordingGranted {
                return screenRecording(mode: mode)
            }
            return nil
        case .talk:
            return microphoneGranted ? nil : microphone(mode: mode)
        case .act:
            if !microphoneGranted {
                return microphone(mode: mode)
            }
            if !screenRecordingGranted {
                return screenRecording(mode: mode)
            }
            if !accessibilityGranted {
                return accessibility(mode: mode)
            }
            return nil
        }
    }

    private static func microphone(mode: AgentMode) -> AgentPermissionRecovery {
        AgentPermissionRecovery(
            permissionName: "Microphone",
            message: "\(mode.title) needs Microphone permission before it can run.",
            nextStep: "Open Voiyce Settings > Permissions, grant Microphone access, then start \(mode.title) again."
        )
    }

    private static func screenRecording(mode: AgentMode) -> AgentPermissionRecovery {
        AgentPermissionRecovery(
            permissionName: "Screen Recording",
            message: "\(mode.title) needs Screen Recording permission before it can see the current screen.",
            nextStep: "Open Voiyce Settings > Permissions, grant Screen Recording, then quit and reopen Voiyce if macOS keeps showing the old state."
        )
    }

    private static func accessibility(mode: AgentMode) -> AgentPermissionRecovery {
        AgentPermissionRecovery(
            permissionName: "Accessibility",
            message: "\(mode.title) needs Accessibility permission before it can click, type, or press keys.",
            nextStep: "Open Voiyce Settings > Permissions, grant Accessibility access, then start \(mode.title) again."
        )
    }
}

private struct AgentHalo: View {
    let mode: AgentMode
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (isActive ? mode.accent : .white).opacity(isActive ? 0.20 : 0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 170
                    )
                )
                .frame(width: 420, height: 420)
                .blur(radius: 14)

            Circle()
                .stroke(.white.opacity(isActive ? 0.08 : 0.05), lineWidth: 1)
                .frame(width: 280, height: 280)

            Circle()
                .stroke(.white.opacity(isActive ? 0.06 : 0.04), lineWidth: 1)
                .frame(width: 220, height: 220)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (isActive ? mode.accent : .white).opacity(isActive ? 0.80 : 0.08),
                            .black.opacity(0.55)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 4,
                        endRadius: 92
                    )
                )
                .frame(width: 160, height: 160)
                .shadow(color: isActive ? mode.accent.opacity(0.55) : .clear, radius: 32)
                .overlay(Circle().stroke(.white.opacity(0.05), lineWidth: 1))

            if mode == .talk && isActive {
                VoiceBars(color: mode.accent)
            } else {
                Image(systemName: mode.symbol)
                    .font(.system(size: mode == .act ? 28 : 26, weight: .medium))
                    .foregroundStyle(isActive ? .white : AppTheme.textSecondary)
            }
        }
        .frame(width: 340, height: 340)
    }
}

private struct VoiceBars: View {
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 3, height: CGFloat([14, 22, 28, 18, 26, 20, 15][index]))
            }
        }
    }
}

private enum AgentButtonVariant {
    case primary(Color)
    case stop
    case ghost
}

private struct AgentButton: View {
    let title: String
    let systemImage: String?
    let variant: AgentButtonVariant
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
            .shadow(color: shadow, radius: 16, y: 8)
            .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var foreground: Color {
        switch variant {
        case .primary:
            return .white
        case .stop:
            return AppTheme.textPrimary
        case .ghost:
            return AppTheme.textSecondary
        }
    }

    private var background: Color {
        switch variant {
        case .primary(let color):
            return color
        case .stop:
            return .white.opacity(0.04)
        case .ghost:
            return .clear
        }
    }

    private var border: Color {
        switch variant {
        case .primary:
            return .white.opacity(0.10)
        case .stop, .ghost:
            return AppTheme.ridge.opacity(0.85)
        }
    }

    private var shadow: Color {
        switch variant {
        case .primary(let color):
            return color.opacity(0.30)
        case .stop, .ghost:
            return .clear
        }
    }
}

@MainActor
@Observable
final class RealtimeAgentBridge {
    static let shared = RealtimeAgentBridge()

    weak var webView: WKWebView?
    var onRecoverableFailure: ((RealtimeTelemetryEvent) -> Void)?
    private var pendingConnect = false
    private var pendingMode: AgentMode = .talk

    func attach(_ webView: WKWebView) {
        self.webView = webView
        if pendingConnect {
            Task {
                await connect(mode: pendingMode)
            }
        }
    }

    func connect(mode: AgentMode) async {
        guard mode.startsRealtimeVoice else {
            pendingConnect = false
            pendingMode = mode
            return
        }

        guard let webView else {
            pendingConnect = true
            pendingMode = mode
            return
        }

        pendingConnect = false
        pendingMode = mode
        if mode.startsSessionContext {
            await VideoDBAgentMemory.shared.start()
        }
        _ = try? await webView.evaluateJavaScript("window.voiyceAgentConnect && window.voiyceAgentConnect('\(mode.rawValue)');")
    }

    func stop() {
        pendingConnect = false
        webView?.evaluateJavaScript("window.voiyceAgentStop && window.voiyceAgentStop();")
    }

    func handleTelemetryMessage(_ message: Any) {
        guard let event = RealtimeTelemetryEvent(message: message) else { return }
        RealtimeTelemetryLogger.append(event, to: .shared)
        if RealtimeConnectionFailureRecovery.shouldStopRunningAgent(for: event) {
            onRecoverableFailure?(event)
        }
    }
}

struct TalkLatencyTargets {
    static let firstAudioGoodMilliseconds = 4_000
    static let firstAudioNeedsReviewMilliseconds = 8_000
    static let audioConnectionGoodMilliseconds = 3_000
    static let audioConnectionNeedsReviewMilliseconds = 6_000
    static let interruptionGoodMilliseconds = 800
    static let interruptionNeedsReviewMilliseconds = 1_500
    static let toolCallNeedsSpokenUpdateMilliseconds = 2_000

    static let firstResponseTarget = "Good <= 4s, review > 8s"
    static let connectionTarget = "Good <= 3s, review > 6s"
    static let interruptionTarget = "Good <= 0.8s, review > 1.5s"
    static let toolDelayTarget = "Speak/check in by 2s; review long silent calls"

    static func reviewLabel(elapsedMilliseconds: Int, good: Int, needsReview: Int) -> String {
        if elapsedMilliseconds <= good {
            return "Good"
        }
        if elapsedMilliseconds > needsReview {
            return "Needs review"
        }
        return "Watch"
    }

    static func formattedDuration(milliseconds: Int) -> String {
        let seconds = Double(milliseconds) / 1_000
        if seconds < 10 {
            return String(format: "%.1fs", seconds)
        }
        return "\(Int(seconds.rounded()))s"
    }
}

struct RealtimeTelemetryEvent: Equatable {
    let name: String
    let mode: AgentMode
    let elapsedMilliseconds: Int?
    let toolName: String?
    let toolElapsedMilliseconds: Int?
    let interruptionElapsedMilliseconds: Int?
    let eventType: String?
    let failureReason: String?
    let ok: Bool?

    init(
        name: String,
        mode: AgentMode,
        elapsedMilliseconds: Int? = nil,
        toolName: String? = nil,
        toolElapsedMilliseconds: Int? = nil,
        interruptionElapsedMilliseconds: Int? = nil,
        eventType: String? = nil,
        failureReason: String? = nil,
        ok: Bool? = nil
    ) {
        self.name = name
        self.mode = mode
        self.elapsedMilliseconds = elapsedMilliseconds
        self.toolName = toolName
        self.toolElapsedMilliseconds = toolElapsedMilliseconds
        self.interruptionElapsedMilliseconds = interruptionElapsedMilliseconds
        self.eventType = eventType
        self.failureReason = failureReason
        self.ok = ok
    }

    init?(message: Any) {
        guard let payload = message as? [String: Any] else { return nil }
        guard (payload["type"] as? String) == "telemetry" else { return nil }
        guard let name = payload["name"] as? String, !name.isEmpty else { return nil }
        let mode = (payload["mode"] as? String).flatMap(AgentMode.init(rawValue:)) ?? .talk

        self.init(
            name: name,
            mode: mode,
            elapsedMilliseconds: Self.integerValue(payload["elapsed_ms"]),
            toolName: payload["tool_name"] as? String,
            toolElapsedMilliseconds: Self.integerValue(payload["tool_elapsed_ms"]),
            interruptionElapsedMilliseconds: Self.integerValue(payload["interruption_elapsed_ms"]),
            eventType: payload["event_type"] as? String,
            failureReason: payload["failure_reason"] as? String,
            ok: payload["ok"] as? Bool
        )
    }

    private static func integerValue(_ value: Any?) -> Int? {
        switch value {
        case let value as Int:
            return value
        case let value as Double:
            return Int(value.rounded())
        case let value as NSNumber:
            return value.intValue
        case let value as String:
            return Int(value)
        default:
            return nil
        }
    }
}

struct RealtimeConnectionFailureRecovery: Equatable {
    let message: String
    let nextStep: String
    let permissionName: String?

    static func shouldStopRunningAgent(for event: RealtimeTelemetryEvent) -> Bool {
        (event.name == "connection_failed" || event.name == "connection_lost") && event.mode.startsRealtimeVoice
    }

    static func recovery(for event: RealtimeTelemetryEvent) -> RealtimeConnectionFailureRecovery {
        recovery(failureReason: event.failureReason)
    }

    static func recovery(failureReason: String?) -> RealtimeConnectionFailureRecovery {
        if isMicrophonePermissionFailure(failureReason) {
            return RealtimeConnectionFailureRecovery(
                message: TalkModeRecoveryCopy.microphonePermissionRequired,
                nextStep: TalkModeRecoveryCopy.microphonePermissionNextStep,
                permissionName: "Microphone"
            )
        }

        return RealtimeConnectionFailureRecovery(
            message: TalkModeRecoveryCopy.connectionFailed,
            nextStep: TalkModeRecoveryCopy.serviceFailureNextStep(statusCode: nil),
            permissionName: nil
        )
    }

    static func isMicrophonePermissionFailure(_ reason: String?) -> Bool {
        let cleaned = reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !cleaned.isEmpty else { return false }
        return cleaned.localizedCaseInsensitiveContains("notallowed")
            || cleaned.localizedCaseInsensitiveContains("permission")
            || cleaned.localizedCaseInsensitiveContains("microphone")
            || cleaned.localizedCaseInsensitiveContains("permission denied")
    }
}

enum RealtimeTelemetryLogger {
    @MainActor
    static func append(_ event: RealtimeTelemetryEvent, to eventStore: AgentEventStore) {
        switch event.name {
        case "audio_connection_ready", "peer_connected":
            guard let elapsed = event.elapsedMilliseconds else { return }
            let label = TalkLatencyTargets.reviewLabel(
                elapsedMilliseconds: elapsed,
                good: TalkLatencyTargets.audioConnectionGoodMilliseconds,
                needsReview: TalkLatencyTargets.audioConnectionNeedsReviewMilliseconds
            )
            appendMetric(
                title: "Talk connection measured",
                summary: "Audio connection became ready in \(TalkLatencyTargets.formattedDuration(milliseconds: elapsed)).",
                mode: event.mode,
                elapsedMilliseconds: elapsed,
                target: TalkLatencyTargets.connectionTarget,
                reviewLabel: label,
                eventStore: eventStore
            )
        case "first_audio_delta", "first_response_complete":
            guard let elapsed = event.elapsedMilliseconds else { return }
            let label = TalkLatencyTargets.reviewLabel(
                elapsedMilliseconds: elapsed,
                good: TalkLatencyTargets.firstAudioGoodMilliseconds,
                needsReview: TalkLatencyTargets.firstAudioNeedsReviewMilliseconds
            )
            appendMetric(
                title: "Talk first response measured",
                summary: "First response signal arrived in \(TalkLatencyTargets.formattedDuration(milliseconds: elapsed)).",
                mode: event.mode,
                elapsedMilliseconds: elapsed,
                target: TalkLatencyTargets.firstResponseTarget,
                reviewLabel: label,
                extraDetails: event.eventType.map { [AgentLogEventDetail(key: "Event", value: $0)] } ?? [],
                eventStore: eventStore
            )
        case "tool_call_finished":
            guard let elapsed = event.toolElapsedMilliseconds ?? event.elapsedMilliseconds else { return }
            let label = elapsed > TalkLatencyTargets.toolCallNeedsSpokenUpdateMilliseconds ? "Review silence" : "Good"
            appendMetric(
                title: "Talk tool delay measured",
                summary: "\(event.toolName ?? "Tool") returned in \(TalkLatencyTargets.formattedDuration(milliseconds: elapsed)).",
                mode: event.mode,
                elapsedMilliseconds: elapsed,
                target: TalkLatencyTargets.toolDelayTarget,
                reviewLabel: label,
                extraDetails: [
                    AgentLogEventDetail(key: "Tool", value: event.toolName ?? "unknown"),
                    AgentLogEventDetail(key: "Result", value: event.ok == false ? "Failed" : "Finished")
                ],
                eventStore: eventStore
            )
        case "interruption_completed":
            guard let elapsed = event.interruptionElapsedMilliseconds else { return }
            let label = TalkLatencyTargets.reviewLabel(
                elapsedMilliseconds: elapsed,
                good: TalkLatencyTargets.interruptionGoodMilliseconds,
                needsReview: TalkLatencyTargets.interruptionNeedsReviewMilliseconds
            )
            appendMetric(
                title: "Talk interruption measured",
                summary: "User interruption settled in \(TalkLatencyTargets.formattedDuration(milliseconds: elapsed)).",
                mode: event.mode,
                elapsedMilliseconds: elapsed,
                target: TalkLatencyTargets.interruptionTarget,
                reviewLabel: label,
                eventStore: eventStore
            )
        case "connection_failed", "connection_lost":
            appendConnectionFailure(event, to: eventStore)
        default:
            break
        }
    }

    @MainActor
    private static func appendConnectionFailure(_ event: RealtimeTelemetryEvent, to eventStore: AgentEventStore) {
        let recovery = RealtimeConnectionFailureRecovery.recovery(for: event)

        if let permissionName = recovery.permissionName {
            eventStore.appendPermissionBlock(
                feature: "\(event.mode.title) Mode",
                permission: permissionName,
                message: recovery.message,
                nextStep: recovery.nextStep
            )
            return
        }

        eventStore.appendServiceFailure(
            feature: "\(event.mode.title) Mode",
            service: TalkModeRecoveryCopy.serviceName,
            message: recovery.message,
            nextStep: recovery.nextStep
        )
    }

    @MainActor
    private static func appendMetric(
        title: String,
        summary: String,
        mode: AgentMode,
        elapsedMilliseconds: Int,
        target: String,
        reviewLabel: String,
        extraDetails: [AgentLogEventDetail] = [],
        eventStore: AgentEventStore
    ) {
        eventStore.append(
            category: .voice,
            status: .done,
            symbol: "waveform",
            title: title,
            summary: summary,
            details: [
                AgentLogEventDetail(key: "Mode", value: mode.title),
                AgentLogEventDetail(key: "Elapsed", value: TalkLatencyTargets.formattedDuration(milliseconds: elapsedMilliseconds)),
                AgentLogEventDetail(key: "Target", value: target),
                AgentLogEventDetail(key: "QA", value: reviewLabel)
            ] + extraDetails
        )
    }
}

struct RealtimeAgentWebView: NSViewRepresentable {
    let url: URL
    let bridge: RealtimeAgentBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(context.coordinator, name: "voiyceAgent")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        bridge.attach(webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
        private let bridge: RealtimeAgentBridge

        init(bridge: RealtimeAgentBridge) {
            self.bridge = bridge
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            bridge.attach(webView)
        }

        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.grant)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "voiyceAgent" else { return }
            bridge.handleTelemetryMessage(message.body)
        }
    }
}
#endif
