import Speech
import AVFoundation
import Cocoa

enum SystemPermissionKind: CaseIterable {
    case microphone
    case speechRecognition
    case accessibility
}

enum SystemPermissionSurface {
    case settings
    case onboarding
}

struct SystemPermissionStatusCopy {
    static func description(
        for permission: SystemPermissionKind,
        isGranted: Bool,
        surface: SystemPermissionSurface
    ) -> String {
        switch (permission, surface) {
        case (.microphone, .settings):
            return "Required for voice dictation."
        case (.microphone, .onboarding):
            return OnboardingPermissionCopy.microphoneDescription
        case (.speechRecognition, .settings):
            return "Required for transcribing your voice to text."
        case (.speechRecognition, .onboarding):
            return OnboardingPermissionCopy.speechRecognitionDescription
        case (.accessibility, .settings):
            return isGranted
                ? "On for global hotkeys and inserting text into other apps."
                : "Off for this Voiyce build. Enable the exact Voiyce entry in Privacy & Security > Accessibility."
        case (.accessibility, .onboarding):
            return isGranted
                ? OnboardingPermissionCopy.accessibilityGrantedDescription
                : OnboardingPermissionCopy.accessibilityMissingDescription
        }
    }
}

@Observable
final class PermissionsManager {
    var microphoneGranted = false
    var speechRecognitionGranted = false
    var accessibilityGranted = false
    private var permissionRefreshTimer: Timer?
    private var permissionRefreshTicks = 0
    private var notificationObservers: [NSObjectProtocol] = []

    private let permissionRefreshInterval: TimeInterval = 0.75
    private let maxPermissionRefreshTicks = 20

    init() {
        let center = NotificationCenter.default

        notificationObservers.append(
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.checkAllPermissions()
            }
        )
    }

    deinit {
        permissionRefreshTimer?.invalidate()

        let center = NotificationCenter.default
        for observer in notificationObservers {
            center.removeObserver(observer)
        }
    }

    func checkAllPermissions() {
        guard !AppConstants.isUITesting else {
            markAllPermissionsGrantedForUITesting()
            return
        }

        refreshPermissions()
        Task {
            await writeDiagnostics(reason: "checkAllPermissions")
        }
    }

    // MARK: - Microphone

    func checkMicrophonePermission() {
        guard !AppConstants.isUITesting else {
            microphoneGranted = true
            return
        }

        microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
    }

    func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor [weak self] in
                self?.microphoneGranted = granted
                if !granted {
                    self?.openMicrophoneSettings()
                } else {
                    self?.refreshPermissions()
                }
            }
        }
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }

        startPermissionRefreshTimer()
    }

    // MARK: - Speech Recognition

    func checkSpeechRecognitionPermission() {
        guard !AppConstants.isUITesting else {
            speechRecognitionGranted = true
            return
        }

        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechRecognitionGranted = true
        case .notDetermined:
            speechRecognitionGranted = false
        case .denied, .restricted:
            speechRecognitionGranted = false
        @unknown default:
            speechRecognitionGranted = false
        }
    }

    func requestSpeechRecognitionPermission() {
        switch SpeechRecognitionRequestPolicy.action(for: SFSpeechRecognizer.authorizationStatus()) {
        case .alreadyAuthorized:
            speechRecognitionGranted = true
            refreshPermissions()
        case .openSettings:
            // The system only presents its authorization dialog once. Once the
            // user has denied (or the state is restricted), re-requesting is a
            // silent no-op, so send them to System Settings instead.
            openSpeechRecognitionSettings()
        case .prompt:
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.speechRecognitionGranted = (status == .authorized)
                    if status == .authorized {
                        self?.refreshPermissions()
                    } else {
                        self?.openSpeechRecognitionSettings()
                    }
                }
            }
        }
    }

    func openSpeechRecognitionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
            NSWorkspace.shared.open(url)
        }

        startPermissionRefreshTimer()
    }

    // MARK: - Accessibility

    func checkAccessibilityPermission() {
        guard !AppConstants.isUITesting else {
            accessibilityGranted = true
            return
        }

        accessibilityGranted = currentAccessibilityTrustState()
    }

    func requestAccessibilityPermission() {
        // kAXTrustedCheckOptionPrompt is a global constant of type Unmanaged<CFString>.
        // Use takeUnretainedValue() because we do not own this reference - it is a
        // framework-owned global constant, not a newly created object.
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        accessibilityGranted = trusted

        updatePermissionRefreshState()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        startPermissionRefreshTimer()
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }

        startPermissionRefreshTimer()
    }

    var dictationPermissionsGranted: Bool {
        microphoneGranted && speechRecognitionGranted && accessibilityGranted
    }

    var allPermissionsGranted: Bool {
        dictationPermissionsGranted
    }

    private func currentAccessibilityTrustState() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: false] as CFDictionary
        return AXIsProcessTrusted() || AXIsProcessTrustedWithOptions(options)
    }

    private func markAllPermissionsGrantedForUITesting() {
        microphoneGranted = true
        speechRecognitionGranted = true
        accessibilityGranted = true
        updatePermissionRefreshState()
    }

    func writeDiagnostics(reason: String) async {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let accessibilityPromptOptions = [promptKey: false] as CFDictionary
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        let runningInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .map { app in
                [
                    "pid": "\(app.processIdentifier)",
                    "bundleURL": app.bundleURL?.standardizedFileURL.path ?? "unknown"
                ]
            }

        let diagnostics: [String: Any] = [
            "reason": reason,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "pid": ProcessInfo.processInfo.processIdentifier,
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "unknown",
            "bundlePath": bundleURL.path,
            "executablePath": Bundle.main.executablePath ?? "unknown",
            "isInstalledBundle": bundleURL.path == "/Applications/Voiyce.app",
            "microphoneGranted": AVAudioApplication.shared.recordPermission == .granted,
            "speechRecognitionStatus": speechRecognitionStatusDescription(),
            "speechRecognitionGranted": SFSpeechRecognizer.authorizationStatus() == .authorized,
            "accessibilityTrusted": AXIsProcessTrusted(),
            "accessibilityTrustedNoPrompt": AXIsProcessTrustedWithOptions(accessibilityPromptOptions),
            "managerMicrophoneGranted": microphoneGranted,
            "managerSpeechRecognitionGranted": speechRecognitionGranted,
            "managerAccessibilityGranted": accessibilityGranted,
            "runningVoiyceInstances": runningInstances
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys])
            let directory = FileManager.default
                .homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Voiyce", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("permission-diagnostics.json")
            try data.write(to: url, options: [.atomic])
            print("[PermissionDiagnostics] Wrote \(url.path)")
        } catch {
            print("[PermissionDiagnostics] Failed to write diagnostics.")
        }
    }

    private func speechRecognitionStatusDescription() -> String {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return "authorized"
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        @unknown default:
            return "unknown"
        }
    }

    private func refreshPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        checkAccessibilityPermission()
        updatePermissionRefreshState()
    }

    private func updatePermissionRefreshState() {
        if PermissionRefreshPolicy.shouldStopPolling(
            dictationPermissionsGranted: dictationPermissionsGranted
        ) {
            stopPermissionRefreshTimer()
        }
    }

    private func startPermissionRefreshTimer() {
        guard permissionRefreshTimer == nil else { return }
        permissionRefreshTicks = 0

        let timer = Timer(timeInterval: permissionRefreshInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            self.permissionRefreshTicks += 1
            if self.permissionRefreshTicks > self.maxPermissionRefreshTicks {
                self.stopPermissionRefreshTimer()
                return
            }

            Task {
                await MainActor.run {
                    self.refreshPermissions()
                }
            }
        }

        permissionRefreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPermissionRefreshTimer() {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = nil
        permissionRefreshTicks = 0
    }
}

struct PermissionRefreshPolicy {
    static func shouldStopPolling(
        dictationPermissionsGranted: Bool
    ) -> Bool {
        dictationPermissionsGranted
    }
}

/// What tapping "Grant" for Speech Recognition should do, given the current
/// authorization status. Pure so the routing can be unit-tested without the
/// Speech framework.
enum SpeechAuthorizationAction: Equatable {
    case alreadyAuthorized
    case prompt
    case openSettings
}

struct SpeechRecognitionRequestPolicy {
    static func action(for status: SFSpeechRecognizerAuthorizationStatus) -> SpeechAuthorizationAction {
        switch status {
        case .authorized:
            return .alreadyAuthorized
        case .notDetermined:
            return .prompt
        case .denied, .restricted:
            return .openSettings
        @unknown default:
            return .openSettings
        }
    }
}
