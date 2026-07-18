#if VOIYCE_PRO
import AppKit
import ApplicationServices
import Foundation
import InsForge
import InsForgeAuth

enum ActActionTiming {
    static let cursorLeadDelayNanoseconds: UInt64 = 140_000_000
    static let shortCursorLeadDelayNanoseconds: UInt64 = 90_000_000
}

enum ComputerUseCoordinateMapper {
    static func displayFrame(for screenshot: ComputerScreenshot, fallbackFrame: CGRect) -> CGRect {
        screenshot.displayFrame ?? fallbackFrame
    }

    static func point(x: Double, y: Double, screenshot: ComputerScreenshot, displayFrame: CGRect) -> CGPoint {
        let scaleX = displayFrame.width / CGFloat(max(screenshot.width, 1))
        let scaleY = displayFrame.height / CGFloat(max(screenshot.height, 1))
        return CGPoint(
            x: displayFrame.minX + CGFloat(x) * scaleX,
            y: displayFrame.minY + CGFloat(y) * scaleY
        )
    }
}

struct ComputerUseLocalActionEvent: Equatable {
    enum Kind: String {
        case mouseMove
        case mouseDown
        case mouseUp
        case scroll
        case keyDown
        case keyUp
    }

    let kind: Kind
    let point: CGPoint?
    let mouseButton: String?
    let keyCode: CGKeyCode?
    let flags: UInt64
    let scrollX: Int32?
    let scrollY: Int32?
}

@MainActor
final class ComputerUseAgent {
    private let accessTokenProvider: @MainActor () async throws -> String
    private let accessibilityTrusted: @MainActor () -> Bool
    private let screenshotProvider: @MainActor () async -> ComputerScreenshot?
    private let textTargetSafetyProvider: @MainActor () -> ActTextTargetSafety
    private let stepRequester: (@MainActor (ComputerUseStepRequest, String) async throws -> ComputerUseStepResponse)?
    private let localActionRecorder: (@MainActor (ComputerUseLocalActionEvent) -> Void)?
    private let textInjectionHandler: (@MainActor (String) -> Void)?
    private let textInjector = TextInjector()
    private let eventStore: AgentEventStore
    private let maxSteps: Int
    private let cancellationCheck: () throws -> Void

    convenience init() {
        self.init(
            accessTokenProvider: {
                guard let session = try await InsForgeClientProvider.shared.auth.getSession() else {
                    throw ComputerUseAgentError.authenticationRequired
                }
                return session.accessToken
            },
            accessibilityTrusted: {
                AXIsProcessTrusted()
            },
            screenshotProvider: {
                await ScreenContextProvider().captureComputerScreenshot()
            },
            textTargetSafetyProvider: {
                ActTextTargetSafety.currentFromAccessibility()
            },
            eventStore: .shared
        )
    }

    init(
        accessTokenProvider: @escaping @MainActor () async throws -> String,
        accessibilityTrusted: @escaping @MainActor () -> Bool,
        screenshotProvider: @escaping @MainActor () async -> ComputerScreenshot?,
        textTargetSafetyProvider: @escaping @MainActor () -> ActTextTargetSafety = {
            ActTextTargetSafety.currentFromAccessibility()
        },
        stepRequester: (@MainActor (ComputerUseStepRequest, String) async throws -> ComputerUseStepResponse)? = nil,
        localActionRecorder: (@MainActor (ComputerUseLocalActionEvent) -> Void)? = nil,
        textInjectionHandler: (@MainActor (String) -> Void)? = nil,
        eventStore: AgentEventStore,
        maxSteps: Int = 6,
        cancellationCheck: @escaping () throws -> Void = {
            try Task.checkCancellation()
        }
    ) {
        self.accessTokenProvider = accessTokenProvider
        self.accessibilityTrusted = accessibilityTrusted
        self.screenshotProvider = screenshotProvider
        self.textTargetSafetyProvider = textTargetSafetyProvider
        self.stepRequester = stepRequester
        self.localActionRecorder = localActionRecorder
        self.textInjectionHandler = textInjectionHandler
        self.eventStore = eventStore
        self.maxSteps = max(1, maxSteps)
        self.cancellationCheck = cancellationCheck
    }

    func run(task: String, safetyMode: AgentSafetyMode) async -> AgentToolResult {
        let cleanedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTask.isEmpty else {
            return AgentToolResult(
                ok: false,
                message: ActModeRecoveryCopy.taskRequired,
                data: ["next_step": ActModeRecoveryCopy.taskRequiredNextStep]
            )
        }

        guard let accessToken = try? await accessTokenProvider() else {
            return AgentToolResult(
                ok: false,
                message: ActModeRecoveryCopy.authenticationRequired,
                data: [
                    "requires": "auth",
                    "next_step": ActModeRecoveryCopy.authenticationNextStep
                ]
            )
        }

        do {
            try cancellationCheck()

            guard accessibilityTrusted() else {
                let message = ActModeRecoveryCopy.accessibilityPermissionRequired
                eventStore.appendPermissionBlock(
                    feature: "Act mode",
                    permission: "Accessibility",
                    message: message,
                    nextStep: ActModeRecoveryCopy.accessibilityNextStep
                )
                return AgentToolResult(
                    ok: false,
                    message: message,
                    data: [
                        "requires": "accessibility_permission",
                        "next_step": ActModeRecoveryCopy.accessibilityNextStep
                    ]
                )
            }

            try cancellationCheck()

            guard let screenshot = await screenshotProvider() else {
                let message = ActModeRecoveryCopy.screenRecordingPermissionRequired
                let nextStep = ActModeRecoveryCopy.screenRecordingNextStep
                eventStore.appendPermissionBlock(
                    feature: "Act mode",
                    permission: "Screen Recording",
                    message: message,
                    nextStep: nextStep
                )
                return AgentToolResult(
                    ok: false,
                    message: message,
                    data: [
                        "requires": "screen_recording_permission",
                        "next_step": nextStep
                    ]
                )
            }

            try cancellationCheck()

            eventStore.append(
                category: .actions,
                status: .done,
                symbol: "cursorarrow.motionlines",
                title: "Act mode started",
                summary: cleanedTask,
                details: [
                    AgentLogEventDetail(key: "Safety", value: safetyMode.title),
                    AgentLogEventDetail(key: "Display", value: "\(screenshot.width)x\(screenshot.height)")
                ]
            )

            ActionCursorOverlay.shared.beginActMode()
            defer {
                ActionCursorOverlay.shared.endActMode()
            }

            var currentScreenshot = screenshot
            var previousResponseID: String?
            var pendingCallID: String?
            var finalMessage = ""
            var executedCount = 0
            ActionCursorOverlay.shared.show(status: "Looking")

            for step in 0..<maxSteps {
                try cancellationCheck()

                let stepResponse = try await requestStep(
                    task: step == 0 ? cleanedTask : nil,
                    previousResponseID: previousResponseID,
                    callID: pendingCallID,
                    screenshot: currentScreenshot,
                    safetyMode: safetyMode,
                    accessToken: accessToken
                )

                try cancellationCheck()

                if let responseID = stepResponse.responseID {
                    previousResponseID = responseID
                }
                if !stepResponse.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finalMessage = stepResponse.message
                }

                guard let computerCall = stepResponse.computerCalls.first else {
                    let message = finalMessage.isEmpty ? ActModeRecoveryCopy.finishedWithoutActions : finalMessage
                    eventStore.append(
                        category: .actions,
                        status: .done,
                        symbol: "checkmark.circle",
                        title: "Act mode finished",
                        summary: message,
                        details: [
                            AgentLogEventDetail(key: "Actions", value: "\(executedCount)"),
                            AgentLogEventDetail(key: "Steps", value: "\(step + 1)")
                        ]
                    )
                    ActionCursorOverlay.shared.hide()
                    return AgentToolResult(ok: true, message: message, data: ["actions": "\(executedCount)", "steps": "\(step + 1)"])
                }

                if !computerCall.pendingSafetyChecks.isEmpty && safetyMode != .unrestricted {
                    let message = computerCall.pendingSafetyChecks
                        .compactMap(\.message)
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    let recoveryMessage = ActModeRecoveryCopy.safetyCheckCannotResume(message)
                    let details = computerCall.pendingSafetyChecks.map {
                        AgentLogEventDetail(key: $0.code ?? "Safety", value: $0.message ?? $0.id)
                    }

                    eventStore.appendActSafetyCheckStopped(
                        message: recoveryMessage,
                        checks: details,
                        nextStep: ActModeRecoveryCopy.safetyCheckNextStep
                    )
                    return AgentToolResult(
                        ok: false,
                        message: recoveryMessage,
                        data: [
                            "requires": "new_act_request",
                            "call": computerCall.callID,
                            "next_step": ActModeRecoveryCopy.safetyCheckNextStep
                        ]
                    )
                }

                pendingCallID = computerCall.callID

                if computerCall.actions.isEmpty {
                    eventStore.append(
                        category: .actions,
                        status: .done,
                        symbol: "checkmark.circle",
                        title: "Act mode finished",
                        summary: ActModeRecoveryCopy.noLocalActions,
                        details: [
                            AgentLogEventDetail(key: "Call", value: computerCall.callID),
                            AgentLogEventDetail(key: "Actions", value: "0"),
                            AgentLogEventDetail(key: "Steps", value: "\(step + 1)")
                        ]
                    )
                    return AgentToolResult(ok: true, message: ActModeRecoveryCopy.noLocalActions, data: ["call": computerCall.callID])
                }

                logPlannedActions(computerCall.actions, callID: computerCall.callID, step: step + 1)

                for action in computerCall.actions {
                    try cancellationCheck()

                    let actionResult = try await execute(action, screenshot: currentScreenshot)
                    try cancellationCheck()

                    executedCount += actionResult.ok && action.type != "screenshot" ? 1 : 0

                    eventStore.append(
                        category: actionResult.ok ? .actions : .errors,
                        status: actionResult.ok ? .done : .failed,
                        symbol: actionResult.ok ? "cursorarrow.click" : "exclamationmark.triangle",
                        title: "Act mode action",
                        summary: actionResult.message,
                        details: [
                            AgentLogEventDetail(key: "Action", value: action.type),
                            AgentLogEventDetail(key: "Call", value: computerCall.callID)
                        ]
                    )

                    if !actionResult.ok {
                        return actionResult
                    }
                }

                try await Task.sleep(nanoseconds: 350_000_000)
                try cancellationCheck()

                guard let nextScreenshot = await screenshotProvider() else {
                    eventStore.append(
                        category: .errors,
                        status: .failed,
                        symbol: "rectangle.dashed.badge.record",
                        title: "Act mode screen capture failed",
                        summary: ActModeRecoveryCopy.screenCaptureAfterActionFailed,
                        details: [
                            AgentLogEventDetail(key: "Next step", value: ActModeRecoveryCopy.screenRecordingNextStep)
                        ]
                    )
                    return AgentToolResult(
                        ok: false,
                        message: ActModeRecoveryCopy.screenCaptureAfterActionFailed,
                        data: ["next_step": ActModeRecoveryCopy.screenCaptureAfterActionFailedNextStep]
                    )
                }
                currentScreenshot = nextScreenshot
            }

            let message = finalMessage.isEmpty ? ActModeRecoveryCopy.stoppedAfterMaxSteps(maxSteps) : finalMessage
            eventStore.append(
                category: .actions,
                status: .done,
                symbol: "checkmark.circle",
                title: "Act mode finished",
                summary: message,
                details: [
                    AgentLogEventDetail(key: "Actions", value: "\(executedCount)"),
                    AgentLogEventDetail(key: "Steps", value: "\(maxSteps)"),
                    AgentLogEventDetail(key: "Limit", value: "\(maxSteps) steps")
                ]
            )
            return AgentToolResult(
                ok: true,
                message: message,
                data: ["actions": "\(executedCount)", "steps": "\(maxSteps)"]
            )
        } catch {
            if Task.isCancelled || error is CancellationError {
                eventStore.append(
                    category: .actions,
                    status: .cancelled,
                    symbol: "stop.circle",
                    title: "Act mode stopped",
                    summary: "The active Act command was stopped before it finished.",
                    details: [
                        AgentLogEventDetail(key: "Next step", value: ActModeRecoveryCopy.cancelledNextStep)
                    ]
                )
                return AgentToolResult(
                    ok: false,
                    message: "Act command stopped.",
                    data: [
                        "status": "cancelled",
                        "next_step": ActModeRecoveryCopy.cancelledNextStep
                    ]
                )
            }

            let message = ActModeRecoveryCopy.unexpectedFailureMessage(for: error)
            eventStore.append(
                category: .errors,
                status: .failed,
                symbol: "exclamationmark.triangle",
                title: "Act mode failed",
                summary: message,
                details: [
                    AgentLogEventDetail(key: "Next step", value: ActModeRecoveryCopy.unexpectedFailureNextStep)
                ]
            )
            return AgentToolResult(ok: false, message: message, data: ["next_step": ActModeRecoveryCopy.unexpectedFailureNextStep])
        }
    }

    private func requestStep(
        task: String?,
        previousResponseID: String?,
        callID: String?,
        screenshot: ComputerScreenshot,
        safetyMode: AgentSafetyMode,
        accessToken: String
    ) async throws -> ComputerUseStepResponse {
        let payload = ComputerUseStepRequest(
            task: task,
            previousResponseID: previousResponseID,
            callID: callID,
            screenshotBase64: screenshot.imageBase64,
            width: screenshot.width,
            height: screenshot.height,
            safetyMode: safetyMode.rawValue
        )

        if let stepRequester {
            return try await stepRequester(payload, accessToken)
        }

        let body = try JSONEncoder().encode(payload)
        var request = URLRequest(
            url: AppConstants.insForgeBaseURL
                .appendingPathComponent("functions")
                .appendingPathComponent("computer-use-step")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ComputerUseAgentError.invalidResponse
        }

        if (200..<300).contains(httpResponse.statusCode) {
            return try JSONDecoder().decode(ComputerUseStepResponse.self, from: data)
        }

        let error = try? JSONDecoder().decode(ComputerUseStepErrorResponse.self, from: data)
        let displayMessage = error?.displayMessage(fallbackStatus: httpResponse.statusCode)
            ?? ActModeRecoveryCopy.requestFailed(statusCode: httpResponse.statusCode)
        let upstreamStatus = error?.upstreamStatus ?? httpResponse.statusCode
        eventStore.appendServiceFailure(
            feature: "Act mode",
            service: "Act mode service",
            statusCode: upstreamStatus,
            message: displayMessage,
            nextStep: ActModeRecoveryCopy.serviceFailureNextStep(statusCode: upstreamStatus)
        )
        throw ComputerUseAgentError.backend(displayMessage)
    }

    private func logPlannedActions(_ actions: [ComputerUseAction], callID: String, step: Int) {
        let actionTypes = actions
            .map(\.type)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let joinedTypes = actionTypes.isEmpty ? "unknown" : actionTypes.joined(separator: ", ")

        eventStore.append(
            category: .actions,
            status: .waiting,
            symbol: "list.bullet.clipboard",
            title: "Act mode planned actions",
            summary: "Act received \(actions.count) local action\(actions.count == 1 ? "" : "s") to run.",
            details: [
                AgentLogEventDetail(key: "Step", value: "\(step)"),
                AgentLogEventDetail(key: "Call", value: callID),
                AgentLogEventDetail(key: "Action types", value: joinedTypes)
            ]
        )
    }

    private func execute(_ action: ComputerUseAction, screenshot: ComputerScreenshot) async throws -> AgentToolResult {
        switch action.type {
        case "click":
            return try await click(action, screenshot: screenshot)
        case "double_click":
            let first = try await click(action, screenshot: screenshot)
            guard first.ok else { return first }
            return try await click(action, screenshot: screenshot)
        case "move":
            return try await move(action, screenshot: screenshot)
        case "scroll":
            return try await scroll(action)
        case "type":
            guard let text = action.text, !text.isEmpty else {
                return invalidActionResult("Act mode tried to type, but no text was provided.")
            }
            let focusSafety = textTargetSafetyProvider()
            guard focusSafety.isSafe else {
                return AgentToolResult(
                    ok: false,
                    message: focusSafety.message,
                    data: [
                        "target_focus": "unsafe",
                        "reason": focusSafety.reason,
                        "next_step": focusSafety.nextStep
                    ]
                )
            }
            await AgentVisualGuideOverlay.shared.showPreview(
                title: "Voiyce will type",
                message: "\(min(text.count, 140)) characters into the active field.",
                duration: 0.7
            )
            await previewPause()
            ActionCursorOverlay.shared.show(status: "Typing")
            try await actionCursorLeadPause()
            injectText(text)
            return AgentToolResult(ok: true, message: "Typed \(text.count) characters.", data: ["action": "type"])
        case "keypress":
            return try await keypress(action)
        case "screenshot":
            return AgentToolResult(ok: true, message: "Captured the current screen for the next action.", data: ["action": "screenshot"])
        case "drag":
            return try await drag(action, screenshot: screenshot)
        case "wait":
            ActionCursorOverlay.shared.show(status: "Waiting")
            try await actionCursorLeadPause(short: true)
            return AgentToolResult(ok: true, message: "Waited for the interface to update.", data: ["action": "wait"])
        default:
            return invalidActionResult("Act mode received an unsupported action: \(action.type).")
        }
    }

    private func click(_ action: ComputerUseAction, screenshot: ComputerScreenshot) async throws -> AgentToolResult {
        guard let point = point(from: action, screenshot: screenshot) else {
            return invalidActionResult("Act mode tried to click, but no screen position was provided.")
        }

        await AgentVisualGuideOverlay.shared.showPreview(
            title: action.type == "double_click" ? "Voiyce will double-click" : "Voiyce will click",
            message: "Guided preview before the pointer acts.",
            pointer: point,
            duration: 0.7
        )
        await previewPause()
        ActionCursorOverlay.shared.move(to: point, status: "Clicking")
        try await actionCursorLeadPause()
        let button = action.button?.lowercased() == "right" ? CGMouseButton.right : CGMouseButton.left
        let flags = flags(from: action.keys)
        postMouse(kind: .mouseMove, point: point, button: button, flags: flags)
        postMouse(kind: .mouseDown, point: point, button: button, flags: flags)
        postMouse(kind: .mouseUp, point: point, button: button, flags: flags)

        return AgentToolResult(ok: true, message: "Clicked \(Int(point.x)), \(Int(point.y)).", data: ["x": "\(Int(point.x))", "y": "\(Int(point.y))"])
    }

    private func move(_ action: ComputerUseAction, screenshot: ComputerScreenshot) async throws -> AgentToolResult {
        guard let point = point(from: action, screenshot: screenshot) else {
            return invalidActionResult("Act mode tried to move the pointer, but no screen position was provided.")
        }

        await AgentVisualGuideOverlay.shared.showPreview(
            title: "Voiyce will move here",
            message: "Guided pointer preview.",
            pointer: point,
            duration: 0.55
        )
        await previewPause(short: true)
        ActionCursorOverlay.shared.move(to: point, status: "Moving")
        try await actionCursorLeadPause(short: true)
        postMouse(kind: .mouseMove, point: point, button: .left, flags: [])

        return AgentToolResult(ok: true, message: "Moved pointer to \(Int(point.x)), \(Int(point.y)).", data: nil)
    }

    private func drag(_ action: ComputerUseAction, screenshot: ComputerScreenshot) async throws -> AgentToolResult {
        let rawPoints = action.path ?? {
            guard let x = action.x, let y = action.y else { return nil }
            let endX = x + (action.dx ?? 0)
            let endY = y + (action.dy ?? 0)
            return [ComputerUsePoint(x: x, y: y), ComputerUsePoint(x: endX, y: endY)]
        }()

        guard let rawPoints, rawPoints.count >= 2 else {
            return invalidActionResult("Act mode tried to drag, but no usable path was provided.")
        }

        let points = rawPoints.compactMap { point(from: $0, screenshot: screenshot) }
        guard points.count >= 2, let first = points.first, let last = points.last else {
            return invalidActionResult("Act mode could not map that drag path to the screen.")
        }

        await AgentVisualGuideOverlay.shared.showPreview(
            title: "Voiyce will drag",
            message: "Previewing the drag start before acting.",
            pointer: first,
            duration: 0.7
        )
        await previewPause()
        ActionCursorOverlay.shared.move(to: first, status: "Dragging")
        try await actionCursorLeadPause()
        postMouse(kind: .mouseMove, point: first, button: .left, flags: [])
        postMouse(kind: .mouseDown, point: first, button: .left, flags: [])

        for point in points.dropFirst() {
            postMouse(kind: .mouseMove, point: point, button: .left, flags: [])
            try? await Task.sleep(nanoseconds: 15_000_000)
        }

        postMouse(kind: .mouseUp, point: last, button: .left, flags: [])

        return AgentToolResult(ok: true, message: "Dragged from \(Int(first.x)), \(Int(first.y)) to \(Int(last.x)), \(Int(last.y)).", data: ["action": "drag"])
    }

    private func scroll(_ action: ComputerUseAction) async throws -> AgentToolResult {
        let dy = Int32(action.scrollY ?? action.dy ?? 0)
        let dx = Int32(action.scrollX ?? action.dx ?? 0)
        await AgentVisualGuideOverlay.shared.showPreview(
            title: "Voiyce will scroll",
            message: "Scrolling the visible interface.",
            duration: 0.55
        )
        await previewPause(short: true)
        ActionCursorOverlay.shared.show(status: "Scrolling")
        try await actionCursorLeadPause(short: true)
        postScroll(dx: dx, dy: dy)
        return AgentToolResult(ok: true, message: "Scrolled the visible interface.", data: ["dx": "\(dx)", "dy": "\(dy)"])
    }

    private func keypress(_ action: ComputerUseAction) async throws -> AgentToolResult {
        let keys = action.keys ?? action.text.map { [$0] } ?? []
        guard !keys.isEmpty else {
            return invalidActionResult("Act mode tried to press keys, but no keys were provided.")
        }

        await AgentVisualGuideOverlay.shared.showPreview(
            title: "Voiyce will press keys",
            message: keys.joined(separator: ", "),
            duration: 0.65
        )
        await previewPause()
        ActionCursorOverlay.shared.show(status: "Pressing keys")
        try await actionCursorLeadPause()
        for key in keys {
            let normalized = key.lowercased()
                .replacingOccurrences(of: "cmd", with: "command")
                .replacingOccurrences(of: "ctrl", with: "control")
            if normalized.contains("+") {
                let parts = normalized.split(separator: "+").map(String.init)
                let keyName = parts.last ?? normalized
                let modifiers = parts.dropLast().joined(separator: ",")
                _ = pressKey(keyName, modifiers: modifiers)
            } else {
                _ = pressKey(normalized, modifiers: "")
            }
        }

        return AgentToolResult(ok: true, message: "Pressed \(keys.joined(separator: ", ")).", data: ["keys": keys.joined(separator: ",")])
    }

    private func actionCursorLeadPause(short: Bool = false) async throws {
        await Task.yield()
        let nanoseconds = short
            ? ActActionTiming.shortCursorLeadDelayNanoseconds
            : ActActionTiming.cursorLeadDelayNanoseconds
        try await Task.sleep(nanoseconds: nanoseconds)
    }

    private func previewPause(short: Bool = false) async {
        let nanoseconds: UInt64 = short ? 280_000_000 : 450_000_000
        try? await Task.sleep(nanoseconds: nanoseconds)
        AgentVisualGuideOverlay.shared.clear()
    }

    private func invalidActionResult(_ message: String) -> AgentToolResult {
        AgentToolResult(
            ok: false,
            message: message,
            data: ["next_step": ActModeRecoveryCopy.invalidActionNextStep]
        )
    }

    private func point(from action: ComputerUseAction, screenshot: ComputerScreenshot) -> CGPoint? {
        guard let x = action.x, let y = action.y else {
            return nil
        }

        let frame = ComputerUseCoordinateMapper.displayFrame(
            for: screenshot,
            fallbackFrame: displayFrame(fallbackWidth: screenshot.width, fallbackHeight: screenshot.height)
        )
        return ComputerUseCoordinateMapper.point(x: x, y: y, screenshot: screenshot, displayFrame: frame)
    }

    private func point(from point: ComputerUsePoint, screenshot: ComputerScreenshot) -> CGPoint? {
        let frame = ComputerUseCoordinateMapper.displayFrame(
            for: screenshot,
            fallbackFrame: displayFrame(fallbackWidth: screenshot.width, fallbackHeight: screenshot.height)
        )
        return ComputerUseCoordinateMapper.point(x: point.x, y: point.y, screenshot: screenshot, displayFrame: frame)
    }

    private func displayFrame(fallbackWidth: Int, fallbackHeight: Int) -> NSRect {
        let displayBounds = CGDisplayBounds(CGMainDisplayID())
        if !displayBounds.isEmpty {
            return NSRect(
                x: displayBounds.origin.x,
                y: displayBounds.origin.y,
                width: displayBounds.width,
                height: displayBounds.height
            )
        }

        return NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: fallbackWidth, height: fallbackHeight)
    }

    private func pressKey(_ key: String, modifiers: String) -> Bool {
        guard let keyCode = keyCodes[key] else { return false }
        let flags = flags(from: modifiers.lowercased().split(separator: ",").map(String.init))

        postKey(keyCode: keyCode, isDown: true, flags: flags)
        postKey(keyCode: keyCode, isDown: false, flags: flags)
        return true
    }

    private func injectText(_ text: String) {
        if let textInjectionHandler {
            textInjectionHandler(text)
        } else {
            textInjector.injectText(text)
        }
    }

    private func postMouse(kind: ComputerUseLocalActionEvent.Kind, point: CGPoint, button: CGMouseButton, flags: CGEventFlags) {
        let event = ComputerUseLocalActionEvent(
            kind: kind,
            point: point,
            mouseButton: button == .right ? "right" : "left",
            keyCode: nil,
            flags: flags.rawValue,
            scrollX: nil,
            scrollY: nil
        )
        if let localActionRecorder {
            localActionRecorder(event)
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let mouseType: CGEventType = {
            switch kind {
            case .mouseMove:
                return .mouseMoved
            case .mouseDown:
                return button == .right ? .rightMouseDown : .leftMouseDown
            case .mouseUp:
                return button == .right ? .rightMouseUp : .leftMouseUp
            default:
                return .mouseMoved
            }
        }()
        let cgEvent = CGEvent(mouseEventSource: source, mouseType: mouseType, mouseCursorPosition: point, mouseButton: button)
        cgEvent?.flags = flags
        cgEvent?.post(tap: .cgSessionEventTap)
    }

    private func postScroll(dx: Int32, dy: Int32) {
        let event = ComputerUseLocalActionEvent(
            kind: .scroll,
            point: nil,
            mouseButton: nil,
            keyCode: nil,
            flags: 0,
            scrollX: dx,
            scrollY: dy
        )
        if let localActionRecorder {
            localActionRecorder(event)
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0)?
            .post(tap: .cgSessionEventTap)
    }

    private func postKey(keyCode: CGKeyCode, isDown: Bool, flags: CGEventFlags) {
        let event = ComputerUseLocalActionEvent(
            kind: isDown ? .keyDown : .keyUp,
            point: nil,
            mouseButton: nil,
            keyCode: keyCode,
            flags: flags.rawValue,
            scrollX: nil,
            scrollY: nil
        )
        if let localActionRecorder {
            localActionRecorder(event)
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let cgEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)
        cgEvent?.flags = flags
        cgEvent?.post(tap: .cgSessionEventTap)
    }

    private func flags(from keys: [String]?) -> CGEventFlags {
        var flags = CGEventFlags()
        for modifier in keys ?? [] {
            switch modifier.lowercased().trimmingCharacters(in: .whitespaces) {
            case "command", "cmd", "meta": flags.insert(.maskCommand)
            case "option", "alt": flags.insert(.maskAlternate)
            case "control", "ctrl": flags.insert(.maskControl)
            case "shift": flags.insert(.maskShift)
            default: break
            }
        }
        return flags
    }

    private var keyCodes: [String: CGKeyCode] {
        [
            "return": 0x24, "enter": 0x24, "tab": 0x30, "space": 0x31,
            "delete": 0x33, "backspace": 0x33, "escape": 0x35, "esc": 0x35,
            "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E,
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04,
            "g": 0x05, "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09,
            "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F,
            "y": 0x10, "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
            "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18, "9": 0x19,
            "7": 0x1A, "-": 0x1B, "8": 0x1C, "0": 0x1D, "]": 0x1E,
            "o": 0x1F, "u": 0x20, "[": 0x21, "i": 0x22, "p": 0x23,
            "l": 0x25, "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29,
            "\\": 0x2A, ",": 0x2B, "/": 0x2C, "n": 0x2D, "m": 0x2E,
            ".": 0x2F
        ]
    }
}

struct ComputerUseStepRequest: Encodable {
    let task: String?
    let previousResponseID: String?
    let callID: String?
    let screenshotBase64: String
    let width: Int
    let height: Int
    let safetyMode: String

    enum CodingKeys: String, CodingKey {
        case task
        case previousResponseID = "previousResponseId"
        case callID = "callId"
        case screenshotBase64
        case width
        case height
        case safetyMode
    }
}

struct ComputerUseStepResponse: Decodable {
    let responseID: String?
    let message: String
    let computerCalls: [ComputerUseCall]

    enum CodingKeys: String, CodingKey {
        case responseID = "responseId"
        case message
        case computerCalls
    }
}

struct ComputerUseCall: Decodable {
    let callID: String
    let actions: [ComputerUseAction]
    let pendingSafetyChecks: [ComputerUseSafetyCheck]

    enum CodingKeys: String, CodingKey {
        case callID = "callId"
        case actions
        case pendingSafetyChecks
    }
}

struct ComputerUseSafetyCheck: Decodable {
    let id: String
    let code: String?
    let message: String?
}

struct ComputerUseAction: Decodable {
    let type: String
    let x: Double?
    let y: Double?
    let dx: Double?
    let dy: Double?
    let scrollX: Double?
    let scrollY: Double?
    let text: String?
    let keys: [String]?
    let button: String?
    let path: [ComputerUsePoint]?

    init(
        type: String,
        x: Double? = nil,
        y: Double? = nil,
        dx: Double? = nil,
        dy: Double? = nil,
        scrollX: Double? = nil,
        scrollY: Double? = nil,
        text: String? = nil,
        keys: [String]? = nil,
        button: String? = nil,
        path: [ComputerUsePoint]? = nil
    ) {
        self.type = type
        self.x = x
        self.y = y
        self.dx = dx
        self.dy = dy
        self.scrollX = scrollX
        self.scrollY = scrollY
        self.text = text
        self.keys = keys
        self.button = button
        self.path = path
    }

    enum CodingKeys: String, CodingKey {
        case type
        case x
        case y
        case dx
        case dy
        case scrollX = "scroll_x"
        case scrollY = "scroll_y"
        case text
        case keys
        case button
        case path
    }
}

struct ComputerUsePoint: Decodable {
    let x: Double
    let y: Double
}

private struct ComputerUseStepErrorResponse: Decodable {
    let error: String?
    let code: String?
    let serverDisplayMessage: String?
    let upstreamStatus: Int?

    enum CodingKeys: String, CodingKey {
        case error
        case code
        case serverDisplayMessage = "displayMessage"
        case upstreamStatus
    }

    func displayMessage(fallbackStatus: Int?) -> String {
        if BackendUsageLimitCopy.isUsageLimit(statusCode: fallbackStatus, code: code, message: error) {
            return ActModeRecoveryCopy.accountUsageLimit
        }

        if let serverDisplayMessage, !serverDisplayMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return serverDisplayMessage
        }

        if let upstreamStatus {
            return ActModeRecoveryCopy.requestFailed(statusCode: upstreamStatus)
        }
        return ActModeRecoveryCopy.requestFailed(statusCode: fallbackStatus)
    }
}

private enum ComputerUseAgentError: LocalizedError {
    case authenticationRequired
    case invalidResponse
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return ActModeRecoveryCopy.authenticationRequired
        case .invalidResponse:
            return ActModeRecoveryCopy.invalidResponse
        case .backend(let message):
            return message
        }
    }
}

enum ActModeRecoveryCopy {
    static let taskRequired = "Describe what you want Act mode to do first."
    static let taskRequiredNextStep = "Try again with a specific app, site, or visible target."
    static let authenticationRequired = "Sign in before using Act mode."
    static let authenticationNextStep = "Sign in to Voiyce, then start Act again."
    static let accessibilityNextStep = "Enable the exact Voiyce entry in Privacy & Security > Accessibility."
    static let accessibilityPermissionRequired = "Accessibility permission is required before Act mode can click, type, or press keys. Enable the exact Voiyce entry in Privacy & Security > Accessibility."
    static let screenRecordingPermissionRequired = "Screen Recording permission is required before Act mode can see the current screen. Open Voiyce Settings > Permissions and grant Screen Recording for this exact Voiyce build."
    static let screenRecordingNextStep = "If System Settings already shows Voiyce enabled, quit and reopen Voiyce. If it still fails, toggle Voiyce off and on in Privacy & Security > Screen Recording."
    static let finishedWithoutActions = "Act mode finished without additional actions."
    static let confirmationRequired = "Act mode needs confirmation before continuing."
    static let safetyCheckNextStep = "Stop this run, describe the approved action more narrowly, and run Act again."
    static let noLocalActions = "Act mode did not find another local action to take."
    static let screenCaptureAfterActionFailed = "Could not capture the screen after that action."
    static let screenCaptureAfterActionFailedNextStep = "Open Voiyce Settings > Permissions, confirm Screen Recording is still enabled, then try Act again."
    static let invalidActionNextStep = "Try the Act command again with a clearer target."
    static let textTargetNotSafe = "Voiyce needs a focused text field before inserting text."
    static let textTargetNotSafeNextStep = "Click into the field you want Voiyce to type in, then try again."
    static let invalidResponse = "Act mode received an invalid action response. Try again, then contact support if it keeps happening."
    static let accountUsageLimit = "This account has reached its current Act limit."
    static let cancelledNextStep = "Start Act again when you are ready to continue."
    static let unexpectedFailure = "Act mode stopped because something went wrong. Try again, then export Agent Log if it keeps happening."
    static let unexpectedFailureNextStep = "Try the action again. If it keeps failing, export Agent Log and send it to support."

    static func stoppedAfterMaxSteps(_ maxSteps: Int) -> String {
        "Act mode stopped after \(maxSteps) steps."
    }

    static func requestFailed(statusCode: Int?) -> String {
        if BackendUsageLimitCopy.isUsageLimit(statusCode: statusCode) {
            return accountUsageLimit
        }

        if statusCode == 429 {
            return "Act mode is temporarily rate-limited. Try again later."
        }

        return "Act mode could not complete that action request. Try again, then contact support if it keeps happening."
    }

    static func serviceFailureNextStep(statusCode: Int?) -> String {
        if BackendUsageLimitCopy.isUsageLimit(statusCode: statusCode) {
            return BackendUsageLimitCopy.nextStep
        }

        if statusCode == 429 {
            return "Try again later. If this blocks your work, export Agent Log and send it to support."
        }

        return "Try the action again. If it keeps failing, export Agent Log and send it to support."
    }

    static func safetyCheckCannotResume(_ reason: String) -> String {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedReason.isEmpty {
            return "Act stopped at a safety check. \(safetyCheckNextStep)"
        }

        return "Act stopped at a safety check: \(trimmedReason) \(safetyCheckNextStep)"
    }

    static func unexpectedFailureMessage(for error: Error) -> String {
        if let agentError = error as? ComputerUseAgentError {
            switch agentError {
            case .authenticationRequired:
                return authenticationRequired
            case .invalidResponse:
                return invalidResponse
            case .backend(let message):
                return message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? unexpectedFailure
                    : message
            }
        }

        if let urlError = error as? URLError,
           urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            return "Act mode lost its connection. Check your internet connection, then try again."
        }

        return unexpectedFailure
    }
}

struct ActTextTargetSafety: Equatable {
    let isSafe: Bool
    let reason: String
    let message: String
    let nextStep: String

    static let safe = ActTextTargetSafety(
        isSafe: true,
        reason: "focused_text_target",
        message: "Text target is focused.",
        nextStep: ""
    )

    static func unsafe(_ reason: String) -> ActTextTargetSafety {
        ActTextTargetSafety(
            isSafe: false,
            reason: reason,
            message: ActModeRecoveryCopy.textTargetNotSafe,
            nextStep: ActModeRecoveryCopy.textTargetNotSafeNextStep
        )
    }

    static func evaluate(role: String?, subrole: String?, isValueSettable: Bool) -> ActTextTargetSafety {
        let normalizedRole = role?.lowercased() ?? ""
        let normalizedSubrole = subrole?.lowercased() ?? ""
        let textRoles = [
            (kAXTextFieldRole as String).lowercased(),
            (kAXTextAreaRole as String).lowercased(),
            (kAXComboBoxRole as String).lowercased()
        ]

        if textRoles.contains(normalizedRole)
            || normalizedSubrole.contains("search")
            || normalizedSubrole.contains("text")
            || isValueSettable {
            return .safe
        }

        if normalizedRole.isEmpty {
            return unsafe("unknown_focus")
        }

        return unsafe("focused_\(normalizedRole)")
    }

    @MainActor
    static func currentFromAccessibility() -> ActTextTargetSafety {
        let systemElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
              let focusedElement = focusedValue else {
            return unsafe("unknown_focus")
        }

        let element = focusedElement as! AXUIElement
        let role = copyStringAttribute(element, kAXRoleAttribute)
        let subrole = copyStringAttribute(element, kAXSubroleAttribute)
        var isSettable = DarwinBoolean(false)
        let settableStatus = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isSettable)
        return evaluate(
            role: role,
            subrole: subrole,
            isValueSettable: settableStatus == .success && isSettable.boolValue
        )
    }

    private static func copyStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }
}
#endif
