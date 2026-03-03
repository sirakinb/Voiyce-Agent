import Speech
import AVFoundation
import Cocoa

@Observable
final class PermissionsManager {
    var microphoneGranted = false
    var speechRecognitionGranted = false
    var accessibilityGranted = false

    func checkAllPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        checkAccessibilityPermission()
    }

    // MARK: - Microphone

    func checkMicrophonePermission() {
        microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
    }

    func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                if granted {
                    self?.microphoneGranted = true
                } else {
                    // Permission denied or can't be determined - open Settings
                    self?.microphoneGranted = false
                    self?.openMicrophoneSettings()
                }
            }
        }
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
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
            }
        }
    }

    // MARK: - Accessibility

    func checkAccessibilityPermission() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        // kAXTrustedCheckOptionPrompt is a global constant of type Unmanaged<CFString>.
        // Use takeUnretainedValue() because we do not own this reference - it is a
        // framework-owned global constant, not a newly created object.
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        accessibilityGranted = trusted
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    var allPermissionsGranted: Bool {
        microphoneGranted && speechRecognitionGranted && accessibilityGranted
    }
}
