import Speech
import AVFoundation
import Cocoa

@Observable
final class PermissionsManager {
    var microphoneGranted = false
    var speechRecognitionGranted = false
    var accessibilityGranted = false
    private var permissionRefreshTimer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []

    private let permissionRefreshInterval: TimeInterval = 0.75

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
        refreshPermissions()
    }

    // MARK: - Microphone

    func checkMicrophonePermission() {
        microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
    }

    func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
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

    var allPermissionsGranted: Bool {
        microphoneGranted && speechRecognitionGranted && accessibilityGranted
    }

    private func currentAccessibilityTrustState() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func refreshPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        checkAccessibilityPermission()
        updatePermissionRefreshState()
    }

    private func updatePermissionRefreshState() {
        if allPermissionsGranted {
            stopPermissionRefreshTimer()
        } else {
            startPermissionRefreshTimer()
        }
    }

    private func startPermissionRefreshTimer() {
        guard permissionRefreshTimer == nil else { return }

        let timer = Timer(timeInterval: permissionRefreshInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            self.refreshPermissions()
        }

        permissionRefreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPermissionRefreshTimer() {
        permissionRefreshTimer?.invalidate()
        permissionRefreshTimer = nil
    }
}
