import Cocoa
#if VOIYCE_PRO
import HotKey
#endif

@Observable
final class HotkeyManager {
    var isDictationHotkeyPressed = false
    #if VOIYCE_PRO
    var isAgentHotkeyPressed = false
    #endif

    var onDictationStart: (() -> Void)?
    var onDictationStop: (() -> Void)?
    #if VOIYCE_PRO
    var onAgentToggle: (() -> Void)?
    var onFocusHighlight: (() -> Void)?
    var onFocusPaint: (() -> Void)?
    var onFocusUnderline: (() -> Void)?
    var onFocusToolPalette: (() -> Void)?
    #endif

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pendingDictationStartTask: Task<Void, Never>?
    #if VOIYCE_PRO
    private var focusHotKey: HotKey?
    private var paintHotKey: HotKey?
    private var underlineHotKey: HotKey?
    private var focusToolPalettePrimaryHotKey: HotKey?
    private var focusToolPaletteFallbackHotKey: HotKey?
    private var focusToolPaletteLegacyHotKey: HotKey?
    private var focusPaletteEventTap: CFMachPort?
    private var focusPaletteRunLoopSource: CFRunLoopSource?
    private var lastFocusPaletteShortcutDate = Date.distantPast
    #endif

    func setup() {
        teardown()
        setupControlKeyMonitor()
        #if VOIYCE_PRO
        setupGlobalActionHotkeys()
        setupFocusPaletteEventTap()
        #endif
        print("[HotkeyManager] Hotkeys registered. Accessibility: \(AXIsProcessTrusted())")
    }

    func teardown() {
        pendingDictationStartTask?.cancel()
        pendingDictationStartTask = nil
        isDictationHotkeyPressed = false
        #if VOIYCE_PRO
        isAgentHotkeyPressed = false
        focusHotKey = nil
        paintHotKey = nil
        underlineHotKey = nil
        focusToolPalettePrimaryHotKey = nil
        focusToolPaletteFallbackHotKey = nil
        focusToolPaletteLegacyHotKey = nil
        if let focusPaletteEventTap {
            CGEvent.tapEnable(tap: focusPaletteEventTap, enable: false)
            CFMachPortInvalidate(focusPaletteEventTap)
        }
        if let focusPaletteRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), focusPaletteRunLoopSource, .commonModes)
        }
        focusPaletteEventTap = nil
        focusPaletteRunLoopSource = nil
        #endif
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

    #if VOIYCE_PRO
    private func setupGlobalActionHotkeys() {
        focusHotKey = HotKey(key: .f, modifiers: [.command, .shift])
        focusHotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                print("[HotkeyManager] Command+Shift+F pressed - starting focus highlight")
                self?.triggerFocusHighlightShortcut()
            }
        }

        paintHotKey = HotKey(key: .p, modifiers: [.command, .shift])
        paintHotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                print("[HotkeyManager] Command+Shift+P pressed - starting focus paint")
                self?.triggerFocusPaintShortcut()
            }
        }

        underlineHotKey = HotKey(key: .u, modifiers: [.command, .shift])
        underlineHotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                print("[HotkeyManager] Command+Shift+U pressed - starting focus underline")
                self?.triggerFocusUnderlineShortcut()
            }
        }

        focusToolPalettePrimaryHotKey = HotKey(key: .a, modifiers: [.control, .command])
        focusToolPalettePrimaryHotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.triggerFocusPaletteShortcut(source: "global Control+Command+A")
            }
        }

        focusToolPaletteFallbackHotKey = HotKey(key: .a, modifiers: [.control, .shift])
        focusToolPaletteFallbackHotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.triggerFocusPaletteShortcut(source: "global Control+Shift+A")
            }
        }

        // Keep the older shortcut for users who already learned it, but the
        // user-facing shortcut is Control+Command+A because many apps reserve
        // Command+Shift+A for their own UI.
        focusToolPaletteLegacyHotKey = HotKey(key: .a, modifiers: [.command, .shift])
        focusToolPaletteLegacyHotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                self?.triggerFocusPaletteShortcut(source: "global Command+Shift+A")
            }
        }
    }
    #endif

    #if VOIYCE_PRO
    private func setupFocusPaletteEventTap() {
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: HotkeyManager.focusPaletteEventTapCallback,
            userInfo: userInfo
        ) else {
            print("[HotkeyManager] WARNING: Focus palette event tap failed. Check Accessibility permission.")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        focusPaletteEventTap = eventTap
        focusPaletteRunLoopSource = runLoopSource
    }

    private static let focusPaletteEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async {
                if let eventTap = manager.focusPaletteEventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        manager.handleFocusPaletteCGEvent(event)
        return Unmanaged.passUnretained(event)
    }

    private func handleFocusPaletteCGEvent(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        guard keyCode == 0, !isRepeat else { return }

        let flags = event.flags
        let controlCommandA = flags.contains(.maskControl) && flags.contains(.maskCommand) && !flags.contains(.maskShift)
        let controlShiftA = flags.contains(.maskControl) && flags.contains(.maskShift) && !flags.contains(.maskCommand)

        guard !flags.contains(.maskAlternate), controlCommandA || controlShiftA else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.triggerFocusPaletteShortcut(source: "event tap")
        }
    }
    #endif

    private func handleEvent(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            handleModifierKeys(event)
        case .keyDown:
            #if VOIYCE_PRO
            handleFocusPaletteShortcut(event)
            #endif
        default:
            break
        }
    }

    #if VOIYCE_PRO
    private func handleFocusPaletteShortcut(_ event: NSEvent) {
        guard !event.isARepeat else { return }

        let keyIsA = event.keyCode == 0 || event.charactersIgnoringModifiers?.lowercased() == "a"
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let controlCommandA = flags.contains(.control) && flags.contains(.command) && !flags.contains(.shift)
        let controlShiftA = flags.contains(.control) && flags.contains(.shift) && !flags.contains(.command)

        guard keyIsA, !flags.contains(.option), controlCommandA || controlShiftA else {
            return
        }

        triggerFocusPaletteShortcut(source: "event monitor")
    }

    private func triggerFocusPaletteShortcut(source: String) {
        let now = Date()
        guard now.timeIntervalSince(lastFocusPaletteShortcutDate) > 0.28 else { return }
        lastFocusPaletteShortcutDate = now

        pendingDictationStartTask?.cancel()
        pendingDictationStartTask = nil

        Task { @MainActor in
            print("[HotkeyManager] Control palette shortcut pressed via \(source) - toggling focus tools")
            self.onFocusToolPalette?()
        }
    }
    #endif

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

            #if VOIYCE_PRO
            let optionPressed = event.modifierFlags.contains(.option)
            if optionPressed {
                self.pressAgentHotkey()
            } else {
                self.releaseAgentHotkey()
            }
            #endif
        }
    }

    #if VOIYCE_PRO
    @MainActor
    func triggerFocusHighlightShortcut() {
        onFocusHighlight?()
    }

    @MainActor
    func triggerFocusPaintShortcut() {
        onFocusPaint?()
    }

    @MainActor
    func triggerFocusUnderlineShortcut() {
        onFocusUnderline?()
    }

    @MainActor
    func pressAgentHotkey() {
        guard !isAgentHotkeyPressed else { return }
        isAgentHotkeyPressed = true
        print("[HotkeyManager] Option pressed - toggling agent")
        onAgentToggle?()
    }

    @MainActor
    func releaseAgentHotkey() {
        guard isAgentHotkeyPressed else { return }
        isAgentHotkeyPressed = false
        print("[HotkeyManager] Option released - agent toggle unchanged")
    }
    #endif

}
