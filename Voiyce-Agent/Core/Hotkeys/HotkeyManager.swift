import HotKey
import Cocoa

@Observable
final class HotkeyManager {
    var isDictationHotkeyPressed = false
    var isAgentHotkeyPressed = false

    var onDictationStart: (() -> Void)?
    var onDictationStop: (() -> Void)?
    var onAgentStart: (() -> Void)?
    var onAgentStop: (() -> Void)?

    private var agentHotKey: HotKey?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func setup() {
        setupControlKeyMonitor()
        setupAgentHotkey()
        print("[HotkeyManager] Hotkeys registered. Accessibility: \(AXIsProcessTrusted())")
    }

    func teardown() {
        agentHotKey = nil
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

    // MARK: - Option+Space (agent mode) - press to toggle

    private func setupAgentHotkey() {
        agentHotKey = HotKey(key: .space, modifiers: [.option])

        agentHotKey?.keyDownHandler = { [weak self] in
            guard let self else { return }
            if !self.isAgentHotkeyPressed {
                self.isAgentHotkeyPressed = true
                print("[HotkeyManager] Option+Space pressed - starting agent")
                self.onAgentStart?()
            } else {
                self.isAgentHotkeyPressed = false
                print("[HotkeyManager] Option+Space pressed - stopping agent")
                self.onAgentStop?()
            }
        }
    }
}
