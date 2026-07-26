import Cocoa

@Observable
final class HotkeyManager {
    var isDictationHotkeyPressed = false

    var onDictationStart: (() -> Void)?
    var onDictationStop: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pendingDictationStartTask: Task<Void, Never>?

    func setup() {
        teardown()
        setupControlKeyMonitor()
        print("[HotkeyManager] Hotkeys registered. Accessibility: \(AXIsProcessTrusted())")
    }

    func teardown() {
        pendingDictationStartTask?.cancel()
        pendingDictationStartTask = nil
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

    // MARK: - Modifier keys - hold to talk

    private func setupControlKeyMonitor() {
        // Global monitor: captures events when OTHER apps are focused.
        // Requires Accessibility permission.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
        }

        // Local monitor: captures events when THIS app is focused.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handleEvent(event)
            return event
        }

        if globalMonitor == nil {
            print("[HotkeyManager] WARNING: Global monitor failed to register. Check Accessibility permission.")
        }
    }



    private func handleEvent(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            handleModifierKeys(event)
        default:
            break
        }
    }


    private func handleModifierKeys(_ event: NSEvent) {
        let controlPressed = event.modifierFlags.contains(.control)
        let shortcutModifierPressed = event.modifierFlags.contains(.command)
            || event.modifierFlags.contains(.shift)
            || event.modifierFlags.contains(.option)

        Task { @MainActor in
            if controlPressed && !shortcutModifierPressed && !self.isDictationHotkeyPressed && self.pendingDictationStartTask == nil {
                self.pendingDictationStartTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 140_000_000)
                    guard let self, !Task.isCancelled else { return }

                    let currentFlags = CGEventSource.flagsState(.hidSystemState)
                    guard currentFlags.contains(.maskControl),
                          !currentFlags.contains(.maskCommand),
                          !currentFlags.contains(.maskShift),
                          !currentFlags.contains(.maskAlternate) else {
                        self.pendingDictationStartTask = nil
                        return
                    }

                    self.pendingDictationStartTask = nil
                    self.isDictationHotkeyPressed = true
                    print("[HotkeyManager] Control pressed - starting dictation")
                    self.onDictationStart?()
                }
            } else if !controlPressed || shortcutModifierPressed {
                self.pendingDictationStartTask?.cancel()
                self.pendingDictationStartTask = nil
            }

            if !controlPressed && self.isDictationHotkeyPressed {
                self.isDictationHotkeyPressed = false
                print("[HotkeyManager] Control released - stopping dictation")
                self.onDictationStop?()
            }

        }
    }


}
