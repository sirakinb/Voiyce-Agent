import Cocoa

@Observable
final class HotkeyManager {
    var isDictationHotkeyPressed = false

    var onDictationStart: (() -> Void)?
    var onDictationStop: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    func setup() {
        teardown()
        setupControlKeyMonitor()
        print("[HotkeyManager] Hotkeys registered. Accessibility: \(AXIsProcessTrusted())")
    }

    func teardown() {
        isDictationHotkeyPressed = false
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    // MARK: - Control key (dictation) - hold to talk

    private func setupControlKeyMonitor() {
        // Global monitor: captures events when OTHER apps are focused.
        // Requires Accessibility permission.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleControlKey(event)
        }

        // Local monitor: captures events when THIS app is focused.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleControlKey(event)
            return event
        }

        if globalMonitor == nil {
            print("[HotkeyManager] WARNING: Global monitor failed to register. Check Accessibility permission.")
        }
    }

    private func handleControlKey(_ event: NSEvent) {
        let controlPressed = event.modifierFlags.contains(.control)
        Task { @MainActor in
            if controlPressed && !self.isDictationHotkeyPressed {
                self.isDictationHotkeyPressed = true
                print("[HotkeyManager] Control pressed - starting dictation")
                self.onDictationStart?()
            } else if !controlPressed && self.isDictationHotkeyPressed {
                self.isDictationHotkeyPressed = false
                print("[HotkeyManager] Control released - stopping dictation")
                self.onDictationStop?()
            }
        }
    }
}
