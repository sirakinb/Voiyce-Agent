import Speech
import AVFoundation
import Cocoa
import CoreGraphics
import ScreenCaptureKit

enum SystemPermissionKind: CaseIterable {
    case microphone
    case speechRecognition
    case accessibility
    case screenRecording
}

enum SystemPermissionSurface {
    case settings
    case onboarding
}

struct SystemPermissionStatusCopy {
    static func description(
        for permission: SystemPermissionKind,
        isGranted: Bool,
        screenRecordingStatusMessage: String? = nil,
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
        case (.screenRecording, .settings):
            return isGranted
                ? "On for screen-aware Agent and Act mode."
                : screenRecordingStatusMessage ?? "Off for screen-aware Agent and Act mode."
        case (.screenRecording, .onboarding):
            return isGranted
                ? OnboardingPermissionCopy.screenRecordingGrantedDescription
                : screenRecordingStatusMessage ?? OnboardingPermissionCopy.screenRecordingMissingDescription
        }
    }
}

@Observable
final class PermissionsManager {
    var microphoneGranted = false
    var speechRecognitionGranted = false
    var accessibilityGranted = false
    var screenRecordingGranted = false
    var screenRecordingStatusMessage: String?
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
            await checkScreenRecordingPermission()
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
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.speechRecognitionGranted = (status == .authorized)
                self?.refreshPermissions()
            }
        }
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

    // MARK: - Screen Recording

    func checkScreenRecordingPermission() async {
        guard !AppConstants.isUITesting else {
            screenRecordingGranted = true
            screenRecordingStatusMessage = nil
            return
        }

        guard CGPreflightScreenCaptureAccess() else {
            screenRecordingGranted = false
            screenRecordingStatusMessage = "Screen Recording is off for this exact Voiyce build. Click Grant Access, enable Voiyce in Privacy & Security, then quit and reopen Voiyce if macOS keeps showing the old state."
            updatePermissionRefreshState()
            return
        }

        if await canCaptureScreenFrame() {
            screenRecordingGranted = true
            screenRecordingStatusMessage = nil
        } else {
            screenRecordingGranted = false
            screenRecordingStatusMessage = "Screen Recording appears enabled, but macOS still blocked screen capture. Quit and reopen Voiyce; if it persists, toggle Voiyce off and on in Privacy & Security > Screen Recording."
        }

        updatePermissionRefreshState()
    }

    func requestScreenRecordingPermission() {
        screenRecordingGranted = CGRequestScreenCaptureAccess()
        if screenRecordingGranted {
            screenRecordingStatusMessage = nil
        } else {
            screenRecordingStatusMessage = "macOS did not grant Screen Recording yet. Enable Voiyce in Privacy & Security > Screen Recording."
            openScreenRecordingSettings()
        }

        startPermissionRefreshTimer()
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            await checkScreenRecordingPermission()
        }
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        } else {
            openPrivacySettings()
        }

        startPermissionRefreshTimer()
    }

    var dictationPermissionsGranted: Bool {
        microphoneGranted && speechRecognitionGranted && accessibilityGranted
    }

    var agentPermissionsGranted: Bool {
        dictationPermissionsGranted && screenRecordingGranted
    }

    var allPermissionsGranted: Bool {
        dictationPermissionsGranted
    }

    private var shouldIncludeScreenRecordingInRefreshCompletion: Bool {
        #if VOIYCE_PRO
        true
        #else
        false
        #endif
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
        screenRecordingGranted = true
        screenRecordingStatusMessage = nil
        updatePermissionRefreshState()
    }

    private func canCaptureScreenFrame() async -> Bool {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let mainDisplayID = CGMainDisplayID()
            guard let display = content.displays.first(where: { $0.displayID == mainDisplayID }) ?? content.displays.first else {
                return false
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = min(display.width, 640)
            configuration.height = min(display.height, 360)
            configuration.showsCursor = false
            configuration.capturesAudio = false
            _ = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            return true
        } catch {
            return false
        }
    }

    func writeDiagnostics(reason: String) async {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let accessibilityPromptOptions = [promptKey: false] as CFDictionary
        let screenPreflight = CGPreflightScreenCaptureAccess()
        let screenCaptureWorks = screenPreflight ? await canCaptureScreenFrame() : false
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
            "screenRecordingPreflight": screenPreflight,
            "screenCaptureWorks": screenCaptureWorks,
            "managerMicrophoneGranted": microphoneGranted,
            "managerSpeechRecognitionGranted": speechRecognitionGranted,
            "managerAccessibilityGranted": accessibilityGranted,
            "managerScreenRecordingGranted": screenRecordingGranted,
            "managerScreenRecordingStatusMessage": screenRecordingStatusMessage ?? "",
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
            dictationPermissionsGranted: dictationPermissionsGranted,
            screenRecordingGranted: screenRecordingGranted,
            includeScreenRecording: shouldIncludeScreenRecordingInRefreshCompletion
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
                await self.checkScreenRecordingPermission()
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
        dictationPermissionsGranted: Bool,
        screenRecordingGranted: Bool,
        includeScreenRecording: Bool
    ) -> Bool {
        guard dictationPermissionsGranted else {
            return false
        }

        guard includeScreenRecording else {
            return true
        }

        return screenRecordingGranted
    }
}
