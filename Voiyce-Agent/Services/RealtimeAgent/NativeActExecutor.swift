#if VOIYCE_PRO
import AppKit
import Foundation

@MainActor
final class NativeActExecutor {
    static let shared = NativeActExecutor()

    private let eventStore = AgentEventStore.shared

    private init() {}

    func run(task: String, appState: AppState?) async -> AgentToolResult? {
        let cleanedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTask.isEmpty else {
            return AgentToolResult(
                ok: false,
                message: ActModeRecoveryCopy.taskRequired,
                data: ["next_step": AgentToolRecoveryCopy.missingDetailNextStep]
            )
        }

        if let tab = tabIntent(from: cleanedTask) {
            return await openVoiyceSection(tab, appState: appState, source: cleanedTask)
        }

        return nil
    }

    func openVoiyceSection(_ section: String, appState: AppState?) async -> AgentToolResult {
        guard let tab = tab(for: section) else {
            return AgentToolResult(
                ok: false,
                message: "Unknown Voiyce section: \(section).",
                data: [
                    "section": section,
                    "next_step": "Try Dashboard, Agent, Settings, or Transcript History."
                ]
            )
        }

        return await openVoiyceSection(tab, appState: appState, source: section)
    }

    private func openVoiyceSection(_ tab: SidebarTab, appState: AppState?, source: String) async -> AgentToolResult {
        ActionCursorOverlay.shared.beginActMode()
        defer { ActionCursorOverlay.shared.endActMode() }

        let targetRect = frameForVoiyceButton(title: tab.title)
        await AgentVisualGuideOverlay.shared.showPreview(
            title: "Opening \(tab.title)",
            message: "Native Voiyce action preview.",
            targetRect: targetRect,
            duration: 0.75
        )
        try? await Task.sleep(nanoseconds: 280_000_000)
        AgentVisualGuideOverlay.shared.clear()

        if let targetRect {
            ActionCursorOverlay.shared.move(
                to: CGPoint(x: targetRect.midX, y: targetRect.midY),
                status: "Opening \(tab.title)"
            )
        } else {
            ActionCursorOverlay.shared.show(status: "Opening \(tab.title)")
        }
        try? await Task.sleep(nanoseconds: ActActionTiming.shortCursorLeadDelayNanoseconds)

        if let appState {
            appState.selectedTab = tab
        } else {
            NotificationCenter.default.post(name: .voiyceOpenTabRequested, object: tab.rawValue)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)

        eventStore.append(
            category: .actions,
            status: .done,
            symbol: tab.icon,
            title: "Native action",
            summary: "Opened \(tab.title).",
            details: [
                AgentLogEventDetail(key: "Source", value: source),
                AgentLogEventDetail(key: "Handler", value: "Native Voiyce navigation")
            ]
        )

        return AgentToolResult(
            ok: true,
            message: "Opened \(tab.title).",
            data: [
                "section": tab.rawValue,
                "handled_by": "native"
            ]
        )
    }

    private func tabIntent(from task: String) -> SidebarTab? {
        let text = normalized(task)
        guard containsAny(text, ["click", "open", "go to", "show", "navigate", "switch", "select", "pull up", "take me"]) else {
            return nil
        }

        if containsAny(text, ["agent log", "logs", "log screen", "activity log"]) {
            return .agentLog
        }
        if containsAny(text, ["settings", "setting", "preferences", "permissions"]) {
            return .settings
        }
        if containsAny(text, ["dashboard", "home"]) {
            return .dashboard
        }
        if containsAny(text, ["agent"]) {
            return .agent
        }

        return nil
    }

    private func tab(for section: String) -> SidebarTab? {
        let text = normalized(section)
        if containsAny(text, ["agent log", "logs", "log"]) {
            return .agentLog
        }
        if containsAny(text, ["settings", "setting", "preferences", "permissions"]) {
            return .settings
        }
        if containsAny(text, ["dashboard", "home"]) {
            return .dashboard
        }
        if containsAny(text, ["agent"]) {
            return .agent
        }
        return SidebarTab(rawValue: text)
    }

    private func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private func frameForVoiyceButton(title: String) -> CGRect? {
        let appElement = AXUIElementCreateApplication(ProcessInfo.processInfo.processIdentifier)
        return findButtonFrame(in: appElement, title: title, depth: 0)
    }

    private func findButtonFrame(in element: AXUIElement, title: String, depth: Int) -> CGRect? {
        guard depth < 8 else { return nil }

        if copyStringAttribute(element, kAXRoleAttribute) == kAXButtonRole as String {
            let elementTitle = copyStringAttribute(element, kAXTitleAttribute)
                ?? copyStringAttribute(element, kAXDescriptionAttribute)
                ?? ""
            if elementTitle.localizedCaseInsensitiveContains(title),
               let frame = copyFrame(element) {
                return frame
            }
        }

        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else {
            return nil
        }

        for child in children {
            if let frame = findButtonFrame(in: child, title: title, depth: depth + 1) {
                return frame
            }
        }

        return nil
    }

    private func copyStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func copyFrame(_ element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        let positionAXValue = positionValue as! AXValue
        let sizeAXValue = sizeValue as! AXValue
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAXValue, .cgPoint, &position),
              AXValueGetValue(sizeAXValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }
}
#endif
