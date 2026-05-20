#if VOIYCE_PRO
import Foundation
import Network
import InsForge
import InsForgeAuth
import AppKit
import ApplicationServices

@MainActor
@Observable
final class RealtimeAgentServer {
    static let shared = RealtimeAgentServer()

    private let client = InsForgeClientProvider.shared
    private let actionBridge = RealtimeAgentActionBridge()
    private var listener: NWListener?
    private(set) var url: URL?
    private(set) var lastError: String?

    var isRunning: Bool { listener != nil && url != nil }

    private init() {}

    func start() {
        guard listener == nil else { return }

        do {
            let listener = try NWListener(using: .tcp, on: .any)
            let listenerConnectionFailed = TalkModeRecoveryCopy.connectionFailed
            listener.newConnectionHandler = { [weak self] connection in
                Task {
                    await self?.handle(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                let event: ListenerEvent
                switch state {
                case .ready:
                    event = .ready(port: listener?.port?.rawValue)
                case .failed:
                    event = .failed(listenerConnectionFailed)
                default:
                    event = .other
                }

                Task { @MainActor [weak self] in
                    switch event {
                    case .ready(let port):
                        if let port {
                            self?.url = URL(string: "http://127.0.0.1:\(port)/")
                            self?.lastError = nil
                        }
                    case .failed(let errorDescription):
                        self?.lastError = errorDescription
                        self?.stop()
                    case .other:
                        break
                    }
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
        } catch {
            lastError = TalkModeRecoveryCopy.connectionFailed
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        url = nil
    }

    private func handle(_ connection: NWConnection) async {
        connection.start(queue: .global(qos: .userInitiated))

        do {
            let request = try await readHTTPRequest(from: connection)
            let response = try await route(request)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        } catch {
            let body = Data(TalkModeRecoveryCopy.connectionFailed.utf8)
            let response = httpResponse(status: "500 Internal Server Error", contentType: "text/plain", body: body)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func route(_ request: HTTPRequest) async throws -> Data {
        let routePath = request.path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? request.path

        if request.method == "OPTIONS" {
            return httpResponse(status: "204 No Content", contentType: "text/plain", body: Data())
        }

        if request.method == "GET", routePath == "/" {
            return httpResponse(status: "200 OK", contentType: "text/html; charset=utf-8", body: Data(realtimeHTML.utf8))
        }

        if request.method == "POST", routePath == "/realtime-session" {
            let sdp = String(decoding: request.body, as: UTF8.self)
            let mode = queryValue("mode", in: request.path)
            let answer = try await createRealtimeCallAnswer(for: sdp, mode: mode)
            return httpResponse(status: "200 OK", contentType: "application/sdp", body: Data(answer.utf8))
        }

        if request.method == "POST", routePath == "/agent-tool" {
            let result = await actionBridge.handle(request.body)
            let body = try JSONEncoder().encode(result)
            return httpResponse(status: "200 OK", contentType: "application/json", body: body)
        }

        if request.method == "POST", routePath == "/agent-confirm" {
            let result = await actionBridge.confirm(request.body)
            let body = try JSONEncoder().encode(result)
            return httpResponse(status: "200 OK", contentType: "application/json", body: body)
        }

        return httpResponse(status: "404 Not Found", contentType: "text/plain", body: Data("Not found".utf8))
    }

    private func createRealtimeCallAnswer(for sdp: String, mode: String?) async throws -> String {
        let trimmedSDP = sdp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSDP.isEmpty else {
            throw RealtimeAgentServerError.missingSDP
        }
        guard trimmedSDP.contains("v=0"), trimmedSDP.contains("m=audio") else {
            throw RealtimeAgentServerError.invalidSDP(trimmedSDP.count)
        }

        guard let session = try await client.auth.getSession() else {
            throw RealtimeAgentServerError.authenticationRequired
        }

        let payload = RealtimeSessionRequest(
            sdp: sdp,
            model: ProcessInfo.processInfo.environment["OPENAI_REALTIME_MODEL"],
            mode: mode
        )
        let body = try JSONEncoder().encode(payload)
        var request = URLRequest(
            url: AppConstants.insForgeBaseURL
                .appendingPathComponent("functions")
                .appendingPathComponent("realtime-session")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        var (data, urlResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw RealtimeAgentServerError.invalidFunctionResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            let refreshed = try await client.auth.refreshAccessToken()
            guard let accessToken = refreshed.accessToken else {
                throw RealtimeAgentServerError.authenticationRequired
            }

            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            (data, urlResponse) = try await URLSession.shared.data(for: request)
            guard let refreshedResponse = urlResponse as? HTTPURLResponse else {
                throw RealtimeAgentServerError.invalidFunctionResponse
            }

            return try decodeRealtimeAnswer(data: data, response: refreshedResponse)
        }

        return try decodeRealtimeAnswer(data: data, response: httpResponse)
    }

    private func decodeRealtimeAnswer(data: Data, response httpResponse: HTTPURLResponse) throws -> String {
        if (200..<300).contains(httpResponse.statusCode) {
            return try JSONDecoder().decode(RealtimeSessionResponse.self, from: data).sdp
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw RealtimeAgentServerError.authenticationRequired
        }

        let errorPayload = try? JSONDecoder().decode(RealtimeSessionErrorResponse.self, from: data)
        let rawFallback = String(decoding: data, as: UTF8.self)
        let displayMessage = errorPayload?.displayMessage(fallbackStatus: httpResponse.statusCode)
            ?? TalkModeRecoveryCopy.displayMessage(
                upstreamStatus: nil,
                fallbackStatus: httpResponse.statusCode,
                message: rawFallback
            )
        let upstreamStatus = errorPayload?.upstreamStatus ?? httpResponse.statusCode
        AgentEventStore.shared.appendServiceFailure(
            feature: "Talk Mode",
            service: TalkModeRecoveryCopy.serviceName,
            statusCode: upstreamStatus,
            message: displayMessage,
            nextStep: TalkModeRecoveryCopy.serviceFailureNextStep(statusCode: upstreamStatus)
        )
        throw RealtimeAgentServerError.functionError(
            httpResponse.statusCode,
            displayMessage
        )
    }
}

@MainActor
final class RealtimeAgentActionBridge {
    private let textInjector = TextInjector()
    private let googleWorkspace = GoogleWorkspaceManager.shared
    private let screenContextProvider = ScreenContextProvider()
    private let videoDBMemory = VideoDBAgentMemory.shared
    private let computerUseAgent = ComputerUseAgent()
    private let nativeActExecutor = NativeActExecutor.shared
    private let longTermMemory = AgentLongTermMemoryStore.shared
    private let safetyPolicy = AgentActionSafetyPolicy()
    private let eventStore: AgentEventStore
    private let showsNativeConfirmations: Bool
    private let confirmationTimeoutNanoseconds: UInt64
    private var confirmationObserver: NSObjectProtocol?
    private var pendingActions: [String: PendingAgentAction] = [:]
    private var confirmationTimeoutTasks: [String: Task<Void, Never>] = [:]

    convenience init(
        showsNativeConfirmations: Bool = true,
        confirmationTimeoutSeconds: TimeInterval = 120
    ) {
        self.init(
            showsNativeConfirmations: showsNativeConfirmations,
            confirmationTimeoutSeconds: confirmationTimeoutSeconds,
            eventStore: .shared
        )
    }

    init(
        showsNativeConfirmations: Bool = true,
        confirmationTimeoutSeconds: TimeInterval = 120,
        eventStore: AgentEventStore
    ) {
        self.eventStore = eventStore
        self.showsNativeConfirmations = showsNativeConfirmations
        let clampedTimeout = min(max(confirmationTimeoutSeconds, 0), Double(UInt64.max) / 1_000_000_000)
        confirmationTimeoutNanoseconds = UInt64(clampedTimeout * 1_000_000_000)
        confirmationObserver = NotificationCenter.default.addObserver(
            forName: .voiyceAgentConfirmationDecision,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let decision = notification.object as? AgentConfirmationDecision else { return }
            Task { @MainActor in
                await self?.resolveConfirmation(id: decision.confirmationID, action: decision.action)
            }
        }
    }

    deinit {
        if let confirmationObserver {
            NotificationCenter.default.removeObserver(confirmationObserver)
        }
        confirmationTimeoutTasks.values.forEach { $0.cancel() }
    }

    func handle(_ body: Data) async -> AgentToolResult {
        guard let request = try? JSONDecoder().decode(AgentToolRequest.self, from: body) else {
            return AgentToolResult(
                ok: false,
                message: AgentToolRecoveryCopy.invalidRequest,
                data: ["next_step": AgentToolRecoveryCopy.invalidRequestNextStep]
            )
        }
        let arguments = request.arguments ?? [:]
        let mode = request.mode.flatMap(AgentMode.init(rawValue:)) ?? .talk

        do {
            let result = try await handleTool(name: request.name, arguments: arguments, mode: mode, bypassConfirmation: false)
            logToolResultIfNeeded(name: request.name, result: result)
            return result
        } catch {
            let result = AgentToolResult(
                ok: false,
                message: AgentToolRecoveryCopy.failed,
                data: ["next_step": AgentToolRecoveryCopy.nextStep]
            )
            eventStore.append(
                category: .errors,
                status: .failed,
                symbol: "wrench.and.screwdriver",
                title: "Tool call failed",
                summary: result.message,
                details: [
                    AgentLogEventDetail(key: "Tool", value: request.name),
                    AgentLogEventDetail(key: "Next step", value: AgentToolRecoveryCopy.nextStep)
                ]
            )
            return result
        }
    }

    private func handleTool(name: String, arguments: [String: String], mode: AgentMode, bypassConfirmation: Bool) async throws -> AgentToolResult {
        if name == "confirm_pending_action" {
            return await confirmPendingAction(arguments)
        }

        if let blockedResult = actionToolModeBoundaryResult(name: name, mode: mode) {
            return blockedResult
        }

        if let missingRequiredDetail = missingRequiredDetailResult(for: name, arguments: arguments) {
            return missingRequiredDetail
        }

        if !bypassConfirmation {
            if let blocked = blockedAction(name: name, arguments: arguments) {
                return blocked
            }

            if let request = confirmationRequest(for: name, arguments: arguments) {
                return requestConfirmation(
                    name: name,
                    arguments: arguments,
                    title: request.title,
                    message: request.message,
                    details: request.details
                )
            }
        }

        switch name {
        case "check_calendar":
            return try await checkCalendar(arguments)
        case "read_calendar":
            return try await readCalendar(arguments)
        case "read_gmail":
            return await googleWorkspace.readGmail(
                query: cleaned(arguments["query"]),
                limit: parseInteger(arguments["limit"], defaultValue: 5)
            )
        case "open_app":
            return openApp(arguments)
        case "open_url":
            return openURL(arguments)
        case "open_voiyce_section":
            return await nativeActExecutor.openVoiyceSection(cleaned(arguments["section"]), appState: nil)
        case "draft_gmail":
            return await draftGmail(arguments)
        case "send_gmail":
            return (bypassConfirmation || currentSafetyMode() == .unrestricted)
                ? await sendGmail(arguments)
                : requestSendGmailConfirmation(arguments)
        case "insert_text":
            return insertText(arguments)
        case "type_text":
            return insertText(arguments)
        case "click_screen":
            return clickScreen(arguments)
        case "press_key":
            return pressKey(arguments)
        case "inspect_screen":
            let result = await screenContextProvider.inspectScreen(prompt: cleaned(arguments["prompt"]))
            if result.ok {
                saveScreenMemory(result, source: "screen inspect")
            }
            return result
        case "inspect_focus_region":
            let result = await screenContextProvider.inspectFocusedRegion(prompt: cleaned(arguments["prompt"]))
            if result.ok {
                saveScreenMemory(result, source: "focus region")
            }
            return result
        case "request_screen_access":
            return requestScreenAccess()
        case "start_focus_highlight":
            let mode = focusMarkMode(from: cleaned(arguments["mode"]))
            FocusHighlightOverlay.shared.beginSelection(mode: mode)
            return AgentToolResult(ok: true, message: "\(mode.title) focus is ready. Mark the part of the screen you want me to use.", data: ["mode": mode.rawValue])
        case "start_focus_paint":
            FocusHighlightOverlay.shared.beginSelection(mode: .paint)
            return AgentToolResult(ok: true, message: "Freeform paint is ready. Paint over the part of the screen you want me to use.", data: ["mode": FocusMarkMode.paint.rawValue])
        case "start_focus_underline":
            FocusHighlightOverlay.shared.beginSelection(mode: .underline)
            return AgentToolResult(ok: true, message: "Underline focus is ready. Drag under the item you want me to use.", data: ["mode": FocusMarkMode.underline.rawValue])
        case "clear_focus_highlight":
            FocusHighlightOverlay.shared.clear()
            return AgentToolResult(ok: true, message: "Cleared the focus highlight.", data: nil)
        case "show_tour_guide":
            return await showTourGuide(arguments)
        case "clear_tour_guide":
            AgentVisualGuideOverlay.shared.clear()
            return AgentToolResult(ok: true, message: "Cleared the tour guide visuals.", data: nil)
        case "act_with_computer":
            let task = cleaned(arguments["task"])
            if let nativeResult = await nativeActExecutor.run(task: task, appState: nil) {
                return nativeResult
            }
            return await computerUseAgent.run(
                task: task,
                safetyMode: currentSafetyMode()
            )
        case "videodb_memory_status":
            return videoDBMemory.currentToolResult()
        case "search_session_memory":
            return await videoDBMemory.search(cleaned(arguments["query"]))
        case "summarize_session_memory":
            return await videoDBMemory.summarize()
        case "search_long_term_memory":
            return longTermMemory.search(cleaned(arguments["query"]), limit: parseInteger(arguments["limit"], defaultValue: 8))
        case "summarize_long_term_memory":
            return longTermMemory.summarizeRecent(limit: parseInteger(arguments["limit"], defaultValue: 12))
        case "save_long_term_memory":
            return longTermMemory.addRecord(
                source: cleaned(arguments["source"]).isEmpty ? "voice note" : cleaned(arguments["source"]),
                summary: cleaned(arguments["summary"]),
                searchableText: cleaned(arguments["text"]),
                tags: cleaned(arguments["tags"]).split(separator: ",").map { String($0) },
                appHint: cleaned(arguments["app_hint"]).isEmpty ? nil : cleaned(arguments["app_hint"])
            )
        default:
            return AgentToolResult(
                ok: false,
                message: AgentToolRecoveryCopy.unsupportedRequest,
                data: nil
            )
        }
    }

    private func missingRequiredDetailResult(for name: String, arguments: [String: String]) -> AgentToolResult? {
        func missing(_ message: String) -> AgentToolResult {
            AgentToolResult(
                ok: false,
                message: message,
                data: ["next_step": AgentToolRecoveryCopy.missingDetailNextStep]
            )
        }

        switch name {
        case "open_app":
            return cleaned(arguments["app_name"]).isEmpty ? missing("app_name is required.") : nil
        case "open_url":
            return cleaned(arguments["url"]).isEmpty ? missing("url is required.") : nil
        case "insert_text", "type_text":
            let text = cleaned(arguments["text"].isEmptyOrNil ? arguments["value"] : arguments["text"])
            return text.isEmpty ? missing("text is required.") : nil
        case "click_screen":
            let hasX = Double(cleaned(arguments["x"])) != nil
            let hasY = Double(cleaned(arguments["y"])) != nil
            return hasX && hasY ? nil : missing("x and y screen coordinates are required.")
        case "press_key":
            return cleaned(arguments["key"]).isEmpty ? missing("key is required.") : nil
        case "act_with_computer":
            return cleaned(arguments["task"]).isEmpty ? missing(ActModeRecoveryCopy.taskRequired) : nil
        case "send_gmail":
            return cleaned(arguments["recipient"]).isEmpty ? missing("recipient is required.") : nil
        default:
            return nil
        }
    }

    private func actionToolModeBoundaryResult(name: String, mode: AgentMode) -> AgentToolResult? {
        guard ["click_screen", "press_key", "act_with_computer"].contains(name), mode != .act else { return nil }
        return AgentToolResult(
            ok: false,
            message: "Switch to Act mode before asking Voiyce to click, press keys, or operate apps directly.",
            data: [
                "requires": "act_mode",
                "current_mode": mode.rawValue,
                "next_step": "Choose Act mode, pick a safety mode, then start the Agent again."
            ]
        )
    }

    func confirm(_ body: Data) async -> AgentToolResult {
        guard let request = try? JSONDecoder().decode(AgentConfirmationRequest.self, from: body) else {
            return AgentToolResult(
                ok: false,
                message: AgentToolRecoveryCopy.invalidConfirmation,
                data: ["next_step": AgentToolRecoveryCopy.invalidConfirmationNextStep]
            )
        }
        guard let action = confirmationDecisionAction(approved: request.approved, decision: request.decision) else {
            return AgentToolResult(
                ok: false,
                message: "Choose approve, cancel, or stop session for this pending action.",
                data: [
                    "confirmation_id": request.confirmationID,
                    "next_step": AgentToolRecoveryCopy.missingDetailNextStep
                ]
            )
        }

        return await resolveConfirmation(id: request.confirmationID, action: action)
    }

    private func checkCalendar(_ arguments: [String: String]) async throws -> AgentToolResult {
        let dateText = cleaned(arguments["date"])
        let timeText = cleaned(arguments["time"])
        let durationMinutes = parseInteger(arguments["duration_minutes"], defaultValue: 30)

        guard let start = parseDateTime(date: dateText, time: timeText) else {
            return AgentToolResult(
                ok: false,
                message: "I could not understand that calendar date and time.",
                data: [
                    "date": dateText,
                    "time": timeText,
                    "next_step": "Try again with a date like today, tomorrow, or YYYY-MM-DD and a time like 3:30 PM."
                ]
            )
        }

        return await googleWorkspace.checkCalendar(date: start, durationMinutes: durationMinutes)
    }

    private func readCalendar(_ arguments: [String: String]) async throws -> AgentToolResult {
        let dateText = cleaned(arguments["date"])
        let limit = parseInteger(arguments["limit"], defaultValue: 10)
        guard let day = parseDateOnly(dateText) else {
            return AgentToolResult(
                ok: false,
                message: "date is required. Use today, tomorrow, or YYYY-MM-DD.",
                data: ["next_step": AgentToolRecoveryCopy.missingDetailNextStep]
            )
        }

        return await googleWorkspace.readCalendar(day: day, limit: limit)
    }

    private func openApp(_ arguments: [String: String]) -> AgentToolResult {
        let appName = cleaned(arguments["app_name"])
        guard !appName.isEmpty else {
            return AgentToolResult(
                ok: false,
                message: "app_name is required.",
                data: ["next_step": AgentToolRecoveryCopy.missingDetailNextStep]
            )
        }

        let workspace = NSWorkspace.shared
        let candidates = candidateAppNames(for: appName)

        for candidate in candidates {
            if let bundleIdentifier = bundleIdentifierAliases[candidate.lowercased()],
               let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                return AgentToolResult(ok: true, message: "Opened \(appName).", data: ["app_name": appName])
            }

            for path in ["/Applications/\(candidate).app", "/System/Applications/\(candidate).app"] {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: url.path) {
                    workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                    return AgentToolResult(ok: true, message: "Opened \(candidate).", data: ["app_name": candidate])
                }
            }
        }

        let script = """
        tell application \(appleScriptString(appName))
          activate
        end tell
        """
        let result = runAppleScript(script)
        if result.ok {
            return AgentToolResult(ok: true, message: "Opened \(appName).", data: ["app_name": appName])
        }

        return AgentToolResult(
            ok: false,
            message: "Could not open \(appName).",
            data: ["next_step": AgentToolRecoveryCopy.openAppNextStep]
        )
    }

    private func openURL(_ arguments: [String: String]) -> AgentToolResult {
        let urlText = cleaned(arguments["url"])
        guard !urlText.isEmpty else {
            return AgentToolResult(
                ok: false,
                message: "url is required.",
                data: ["next_step": AgentToolRecoveryCopy.missingDetailNextStep]
            )
        }

        let normalized = urlText.contains("://") ? urlText : "https://\(urlText)"
        guard let url = URL(string: normalized), NSWorkspace.shared.open(url) else {
            return AgentToolResult(
                ok: false,
                message: "Could not open \(urlText).",
                data: ["next_step": AgentToolRecoveryCopy.openURLNextStep]
            )
        }

        return AgentToolResult(ok: true, message: "Opened \(normalized).", data: ["url": normalized])
    }

    private func draftGmail(_ arguments: [String: String]) async -> AgentToolResult {
        let recipient = cleaned(arguments["recipient"])
        let subject = cleaned(arguments["subject"])
        let body = cleaned(arguments["body"])

        guard !recipient.isEmpty else {
            return AgentToolResult(
                ok: false,
                message: "recipient is required.",
                data: ["next_step": AgentToolRecoveryCopy.missingDetailNextStep]
            )
        }

        return openVisibleGmailCompose(recipient: recipient, subject: subject, body: body)
    }

    private func requestSendGmailConfirmation(_ arguments: [String: String]) -> AgentToolResult {
        guard googleWorkspace.isConnected else {
            return AgentToolResult(
                ok: false,
                message: "Google is not connected. Open Settings and connect Google before using send_gmail.",
                data: [
                    "requires": "google_oauth",
                    "next_step": AgentToolRecoveryCopy.googleOAuthNextStep
                ]
            )
        }

        let recipient = cleaned(arguments["recipient"])
        let subject = cleaned(arguments["subject"])
        let body = cleaned(arguments["body"])

        guard !recipient.isEmpty else {
            return AgentToolResult(
                ok: false,
                message: "recipient is required.",
                data: ["next_step": AgentToolRecoveryCopy.missingDetailNextStep]
            )
        }

        return requestConfirmation(
            name: "send_gmail",
            arguments: [
                "recipient": recipient,
                "subject": subject,
                "body": body
            ],
            title: "Confirm sensitive action",
            message: "Voiyce is ready to send an email to \(recipient) with subject \"\(subject)\".",
            details: [
                "Action": "Send Gmail",
                "Target": "\(recipient) — \(subject)",
                "Consequence": "This leaves your Gmail account after approval."
            ]
        )
    }

    private func sendGmail(_ arguments: [String: String]) async -> AgentToolResult {
        guard googleWorkspace.isConnected else {
            return AgentToolResult(
                ok: false,
                message: "Google is not connected. Open Settings and connect Google before using send_gmail.",
                data: [
                    "requires": "google_oauth",
                    "next_step": AgentToolRecoveryCopy.googleOAuthNextStep
                ]
            )
        }

        let recipient = cleaned(arguments["recipient"])
        let subject = cleaned(arguments["subject"])
        let body = cleaned(arguments["body"])

        guard !recipient.isEmpty else {
            return AgentToolResult(
                ok: false,
                message: "recipient is required.",
                data: ["next_step": AgentToolRecoveryCopy.missingDetailNextStep]
            )
        }

        return await googleWorkspace.sendGmail(recipient: recipient, subject: subject, body: body)
    }

    private func openVisibleGmailCompose(recipient: String, subject: String, body: String) -> AgentToolResult {
        var components = URLComponents(string: "https://mail.google.com/mail/")!
        components.queryItems = [
            URLQueryItem(name: "view", value: "cm"),
            URLQueryItem(name: "fs", value: "1"),
            URLQueryItem(name: "tf", value: "1"),
            URLQueryItem(name: "to", value: recipient),
            URLQueryItem(name: "su", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url?.absoluteString else {
            return AgentToolResult(
                ok: false,
                message: "Could not build the Gmail draft.",
                data: ["next_step": AgentToolRecoveryCopy.gmailDraftNextStep]
            )
        }

        let script = """
        tell application "Google Chrome"
            activate
            if not (exists window 1) then make new window
            tell window 1 to make new tab with properties {URL:\(appleScriptString(url))}
        end tell
        """
        let result = runAppleScript(script)
        if result.ok {
            return AgentToolResult(
                ok: true,
                message: "Opened Gmail in Chrome with a visible draft for \(recipient). Review it before sending.",
                data: ["recipient": recipient, "subject": subject, "visible": "true", "sent": "false"]
            )
        }

        if let chromeURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome"),
           let composeURL = URL(string: url) {
            NSWorkspace.shared.open([composeURL], withApplicationAt: chromeURL, configuration: NSWorkspace.OpenConfiguration())
            return AgentToolResult(
                ok: true,
                message: "Opened Gmail in Chrome with a visible draft for \(recipient). Review it before sending.",
                data: ["recipient": recipient, "subject": subject, "visible": "true", "sent": "false"]
            )
        }

        return AgentToolResult(
            ok: false,
            message: "Could not open Google Chrome for the Gmail draft.",
            data: ["next_step": AgentToolRecoveryCopy.gmailDraftNextStep]
        )
    }

    private func insertText(_ arguments: [String: String]) -> AgentToolResult {
        let text = cleaned(arguments["text"].isEmptyOrNil ? arguments["value"] : arguments["text"])
        guard !text.isEmpty else {
            return AgentToolResult(
                ok: false,
                message: "text is required.",
                data: ["next_step": AgentToolRecoveryCopy.missingDetailNextStep]
            )
        }

        guard AXIsProcessTrusted() else {
            let message = "Accessibility permission is required before Voiyce can insert text into another app."
            eventStore.appendPermissionBlock(
                feature: "Text insertion",
                permission: "Accessibility",
                message: message,
                nextStep: "Enable the exact Voiyce entry in Privacy & Security > Accessibility."
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

        let focusSafety = ActTextTargetSafety.currentFromAccessibility()
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

        ActionCursorOverlay.shared.beginActMode()
        defer { ActionCursorOverlay.shared.endActMode() }
        ActionCursorOverlay.shared.show(status: "Typing")
        textInjector.injectText(text)
        return AgentToolResult(ok: true, message: "Inserted text into the active app.", data: ["text": text])
    }

    private func clickScreen(_ arguments: [String: String]) -> AgentToolResult {
        guard let x = Double(cleaned(arguments["x"])),
              let y = Double(cleaned(arguments["y"])) else {
            return AgentToolResult(
                ok: false,
                message: "x and y screen coordinates are required.",
                data: ["next_step": "Ask Voiyce to inspect the screen or mark a focus area before clicking."]
            )
        }

        guard AXIsProcessTrusted() else {
            let message = "Accessibility permission is required before Voiyce can click the screen."
            eventStore.appendPermissionBlock(
                feature: "Screen click",
                permission: "Accessibility",
                message: message,
                nextStep: "Enable the exact Voiyce entry in Privacy & Security > Accessibility."
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

        let point = CGPoint(x: x, y: y)
        ActionCursorOverlay.shared.beginActMode()
        defer { ActionCursorOverlay.shared.endActMode() }
        ActionCursorOverlay.shared.move(to: point, status: "Clicking")
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cgSessionEventTap)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cgSessionEventTap)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cgSessionEventTap)

        return AgentToolResult(ok: true, message: "Clicked screen at \(Int(x)), \(Int(y)).", data: ["x": String(x), "y": String(y)])
    }

    private func pressKey(_ arguments: [String: String]) -> AgentToolResult {
        let key = cleaned(arguments["key"]).lowercased()
        guard let keyCode = keyCodes[key] else {
            return AgentToolResult(
                ok: false,
                message: "Unsupported key: \(key).",
                data: ["next_step": "Try a standard key name such as return, tab, escape, or a single letter."]
            )
        }

        guard AXIsProcessTrusted() else {
            let message = "Accessibility permission is required before Voiyce can press keys in another app."
            eventStore.appendPermissionBlock(
                feature: "Key press",
                permission: "Accessibility",
                message: message,
                nextStep: "Enable the exact Voiyce entry in Privacy & Security > Accessibility."
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

        var flags = CGEventFlags()
        for modifier in cleaned(arguments["modifiers"]).lowercased().split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            switch modifier {
            case "command", "cmd": flags.insert(.maskCommand)
            case "option", "alt": flags.insert(.maskAlternate)
            case "control", "ctrl": flags.insert(.maskControl)
            case "shift": flags.insert(.maskShift)
            default: break
            }
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags = flags
        ActionCursorOverlay.shared.beginActMode()
        defer { ActionCursorOverlay.shared.endActMode() }
        ActionCursorOverlay.shared.show(status: "Pressing keys")
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)

        return AgentToolResult(ok: true, message: "Pressed \(key).", data: ["key": key, "modifiers": cleaned(arguments["modifiers"])])
    }

    private func requestScreenAccess() -> AgentToolResult {
        AppState.rememberPermissionReturnTarget(tab: .agent)
        let openedPrompt = screenContextProvider.requestScreenCaptureAccess()
        return AgentToolResult(
            ok: openedPrompt,
            message: openedPrompt
                ? "Requested Screen Recording permission. Enable Voiyce in Privacy & Security > Screen Recording, then quit and reopen Voiyce if macOS keeps showing the old state."
                : "macOS did not show a Screen Recording prompt. Open Voiyce Settings > Permissions, use Screen Recording > Grant, and verify the exact Voiyce entry is enabled.",
            data: [
                "permission": "screen_recording",
                "settings": "Privacy & Security > Screen Recording"
            ]
        )
    }

    private func showTourGuide(_ arguments: [String: String]) async -> AgentToolResult {
        let title = cleaned(arguments["title"])
        let message = cleaned(arguments["message"])
        let style = AgentGuideStyle(rawValue: cleaned(arguments["style"]).lowercased()) ?? .spotlight
        let duration = Double(cleaned(arguments["duration_seconds"])) ?? 8
        let target = guideTarget(from: arguments)
        let pointer = guidePointer(from: arguments)

        await AgentVisualGuideOverlay.shared.showTour(
            title: title,
            message: message.isEmpty ? "I am pointing this out without taking action." : message,
            targetRect: target,
            pointer: pointer,
            style: style,
            duration: duration
        )

        eventStore.append(
            category: .actions,
            status: .done,
            symbol: "sparkle.magnifyingglass",
            title: "Tour guide shown",
            summary: message.isEmpty ? title : message,
            details: [
                AgentLogEventDetail(key: "Style", value: style.rawValue),
                AgentLogEventDetail(key: "Duration", value: "\(Int(duration))s")
            ]
        )

        return AgentToolResult(
            ok: true,
            message: "Showed tour guide visuals.",
            data: [
                "style": style.rawValue,
                "duration_seconds": "\(duration)"
            ]
        )
    }

    private func guideTarget(from arguments: [String: String]) -> CGRect? {
        guard let x = Double(cleaned(arguments["x"])),
              let y = Double(cleaned(arguments["y"])),
              let width = Double(cleaned(arguments["width"])),
              let height = Double(cleaned(arguments["height"])),
              width > 0,
              height > 0 else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func guidePointer(from arguments: [String: String]) -> CGPoint? {
        guard let x = Double(cleaned(arguments["x"])),
              let y = Double(cleaned(arguments["y"])) else {
            return nil
        }

        return CGPoint(x: x, y: y)
    }

    private func focusMarkMode(from rawValue: String) -> FocusMarkMode {
        switch rawValue.lowercased() {
        case "paint", "freeform", "freeform_paint":
            return .paint
        case "underline", "underlined":
            return .underline
        default:
            return .rectangle
        }
    }

    private func currentSafetyMode() -> AgentSafetyMode {
        guard UserDefaults.standard.bool(forKey: "agentSafetyModeConfirmed") else {
            return .strict
        }
        guard let rawValue = UserDefaults.standard.string(forKey: "agentSafetyMode"),
              let mode = AgentSafetyMode(rawValue: rawValue) else {
            return .normal
        }

        return mode
    }

    private func confirmPendingAction(_ arguments: [String: String]) async -> AgentToolResult {
        let confirmationID = cleaned(arguments["confirmation_id"].isEmptyOrNil ? arguments["confirmationID"] : arguments["confirmation_id"])
        let action = confirmationDecisionAction(approved: nil, decision: arguments["decision"])

        guard !confirmationID.isEmpty else {
            return AgentToolResult(
                ok: false,
                message: "confirmation_id is required.",
                data: ["next_step": AgentToolRecoveryCopy.missingDetailNextStep]
            )
        }

        guard let action else {
            return AgentToolResult(
                ok: false,
                message: "Say yes/approve, no/cancel, or stop session for this pending action.",
                data: [
                    "confirmation_id": confirmationID,
                    "next_step": AgentToolRecoveryCopy.invalidConfirmationNextStep
                ]
            )
        }

        return await resolveConfirmation(id: confirmationID, action: action)
    }

    @discardableResult
    private func resolveConfirmation(id: String, action decision: AgentConfirmationDecisionAction) async -> AgentToolResult {
        guard let pendingAction = pendingActions.removeValue(forKey: id) else {
            confirmationTimeoutTasks.removeValue(forKey: id)?.cancel()
            AgentConfirmationCenter.shared.hide(confirmationID: id)
            return AgentToolResult(
                ok: false,
                message: "That confirmation is no longer available.",
                data: [
                    "confirmation_id": id,
                    "next_step": AgentToolRecoveryCopy.confirmationUnavailableNextStep
                ]
            )
        }

        confirmationTimeoutTasks.removeValue(forKey: id)?.cancel()
        AgentConfirmationCenter.shared.hide(confirmationID: id)

        if decision != .approve {
            if decision == .stopSession {
                NotificationCenter.default.post(name: .voiyceAgentStopRequested, object: nil)
            }

            eventStore.append(
                category: .actions,
                status: .cancelled,
                symbol: "xmark.circle",
                title: cancelledConfirmationTitle(for: decision),
                summary: cancelledConfirmationSummary(for: decision, pendingAction: pendingAction),
                details: [
                    AgentLogEventDetail(key: "Tool", value: pendingAction.name),
                    AgentLogEventDetail(key: "Confirmation", value: id),
                    AgentLogEventDetail(key: "Decision", value: decision.logTitle),
                    AgentLogEventDetail(key: "Next step", value: cancelledConfirmationNextStep(for: decision))
                ]
            )
            return AgentToolResult(
                ok: false,
                message: cancelledConfirmationMessage(for: decision),
                data: [
                    "confirmation_id": id,
                    "next_step": cancelledConfirmationNextStep(for: decision)
                ]
            )
        }

        eventStore.append(
            category: .actions,
            status: .done,
            symbol: "checkmark.shield",
            title: "Action approved",
            summary: pendingAction.summary,
            details: [
                AgentLogEventDetail(key: "Tool", value: pendingAction.name),
                AgentLogEventDetail(key: "Confirmation", value: id),
                AgentLogEventDetail(key: "Decision", value: decision.logTitle),
                AgentLogEventDetail(key: "Reason", value: pendingAction.reason)
            ]
        )

        do {
            let result = try await handleTool(name: pendingAction.name, arguments: pendingAction.arguments, mode: .act, bypassConfirmation: true)
            logToolResultIfNeeded(name: pendingAction.name, result: result)
            return result
        } catch {
            let result = AgentToolResult(
                ok: false,
                message: AgentToolRecoveryCopy.confirmedActionFailed,
                data: ["next_step": AgentToolRecoveryCopy.nextStep]
            )
            logToolFailureIfNeeded(name: pendingAction.name, result: result)
            return result
        }
    }

    private func requestConfirmation(
        name: String,
        arguments: [String: String],
        title: String,
        message: String,
        details: [String: String]
    ) -> AgentToolResult {
        let id = UUID().uuidString
        pendingActions[id] = PendingAgentAction(
            name: name,
            arguments: arguments,
            summary: message,
            reason: confirmationReason(for: name)
        )
        scheduleConfirmationTimeout(id: id)
        let reason = confirmationReason(for: name)
        let consequence = details["Consequence"] ?? "Voiyce will run this action after approval."

        if showsNativeConfirmations {
            AgentConfirmationCenter.shared.show(
                confirmationID: id,
                title: title,
                message: message,
                details: details
            )
        }

        eventStore.append(
            category: .actions,
            status: .waiting,
            symbol: "shield",
            title: "Confirmation requested",
            summary: message,
            details: [
                AgentLogEventDetail(key: "Tool", value: name),
                AgentLogEventDetail(key: "Confirmation", value: id),
                AgentLogEventDetail(key: "Safety", value: currentSafetyMode().title),
                AgentLogEventDetail(key: "Reason", value: reason),
                AgentLogEventDetail(key: "Consequence", value: consequence)
            ]
        )

        return AgentToolResult(
            ok: false,
            message: "\(message) \(reason) Say yes to approve, no to cancel, or stop session to end the session.",
            data: [
                "confirmation_id": id,
                "tool": name,
                "confirmation_reason": reason,
                "consequence": consequence,
                "voice_approval": "Say yes/approve to run it, no/cancel to skip it, or stop session to end the session."
            ],
            needsConfirmation: true,
            confirmationID: id
        )
    }

    private func scheduleConfirmationTimeout(id: String) {
        confirmationTimeoutTasks[id]?.cancel()
        let timeout = confirmationTimeoutNanoseconds
        guard timeout > 0 else { return }

        confirmationTimeoutTasks[id] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: timeout)
            guard !Task.isCancelled else { return }
            self?.expireConfirmation(id: id)
        }
    }

    private func expireConfirmation(id: String) {
        confirmationTimeoutTasks.removeValue(forKey: id)
        guard let pendingAction = pendingActions.removeValue(forKey: id) else { return }

        AgentConfirmationCenter.shared.hide(confirmationID: id)
        eventStore.append(
            category: .actions,
            status: .cancelled,
            symbol: "clock.badge.exclamationmark",
            title: "Confirmation timed out",
            summary: "\(pendingAction.summary) The action did not run because approval timed out.",
            details: [
                AgentLogEventDetail(key: "Tool", value: pendingAction.name),
                AgentLogEventDetail(key: "Confirmation", value: id),
                AgentLogEventDetail(key: "Decision", value: AgentConfirmationDecisionAction.timedOut.logTitle),
                AgentLogEventDetail(key: "Reason", value: pendingAction.reason),
                AgentLogEventDetail(key: "Next step", value: cancelledConfirmationNextStep(for: .timedOut))
            ]
        )
    }

    private func confirmationReason(for name: String) -> String {
        if name == "send_gmail" {
            return "Normal safety asks before messages leave a connected account."
        }

        switch currentSafetyMode() {
        case .strict:
            return "Strict safety asks before direct computer actions."
        case .normal:
            return "Normal safety asks before sensitive or high-impact actions."
        case .unrestricted:
            return "This action still needs approval before it can run."
        }
    }

    private func cancelledConfirmationTitle(for decision: AgentConfirmationDecisionAction) -> String {
        switch decision {
        case .approve:
            return "Action approved"
        case .cancel:
            return "Action cancelled"
        case .stopSession:
            return "Action cancelled and session stopped"
        case .timedOut:
            return "Confirmation timed out"
        }
    }

    private func cancelledConfirmationSummary(
        for decision: AgentConfirmationDecisionAction,
        pendingAction: PendingAgentAction
    ) -> String {
        switch decision {
        case .approve:
            return pendingAction.summary
        case .cancel:
            return pendingAction.summary
        case .stopSession:
            return "\(pendingAction.summary) The session was stopped before the action ran."
        case .timedOut:
            return "\(pendingAction.summary) The action did not run because approval timed out."
        }
    }

    private func cancelledConfirmationMessage(for decision: AgentConfirmationDecisionAction) -> String {
        switch decision {
        case .approve:
            return "Approved that action."
        case .cancel:
            return "Cancelled that action."
        case .stopSession:
            return "Stopped the session and cancelled that action."
        case .timedOut:
            return "That confirmation timed out before the action ran."
        }
    }

    private func cancelledConfirmationNextStep(for decision: AgentConfirmationDecisionAction) -> String {
        switch decision {
        case .approve:
            return "Voiyce will run the approved action."
        case .cancel:
            return "Ask Voiyce again if you still want this action."
        case .stopSession:
            return "Start Talk or Act again when you are ready."
        case .timedOut:
            return "Ask Voiyce again if you still want this action."
        }
    }

    private func confirmationDecisionAction(
        approved: Bool?,
        decision: String?
    ) -> AgentConfirmationDecisionAction? {
        if let approved {
            return approved ? .approve : .cancel
        }

        let cleanedDecision = cleaned(decision).lowercased()
        if ["approve", "approved", "yes", "confirm", "confirmed", "send", "do it"].contains(cleanedDecision) {
            return .approve
        }
        if ["cancel", "cancelled", "no", "stop", "deny", "denied"].contains(cleanedDecision) {
            return .cancel
        }
        if ["stop session", "stop_session", "end session", "end_session"].contains(cleanedDecision) {
            return .stopSession
        }

        return nil
    }

    private func logToolResultIfNeeded(name: String, result: AgentToolResult) {
        if result.ok {
            logToolSuccessIfNeeded(name: name, result: result)
        } else {
            logToolFailureIfNeeded(name: name, result: result)
        }
    }

    private func logToolSuccessIfNeeded(name: String, result: AgentToolResult) {
        guard result.ok else { return }
        guard result.needsConfirmation != true else { return }
        guard shouldLogSuccessfulTool(name) else { return }

        var details = [
            AgentLogEventDetail(key: "Tool", value: name),
            AgentLogEventDetail(key: "Result", value: "Succeeded")
        ]

        let dataKeys = result.data?.keys.sorted() ?? []
        if !dataKeys.isEmpty {
            details.append(AgentLogEventDetail(key: "Data fields", value: dataKeys.joined(separator: ", ")))
        }

        eventStore.append(
            category: logCategory(forTool: name),
            status: .done,
            symbol: logSymbol(forTool: name),
            title: "Tool completed",
            summary: safeToolSuccessSummary(for: name, result: result),
            details: details
        )
    }

    private func shouldLogSuccessfulTool(_ name: String) -> Bool {
        !["confirm_pending_action", "show_tour_guide", "videodb_memory_status"].contains(name)
    }

    private func logCategory(forTool name: String) -> AgentLogCategory {
        switch name {
        case "check_calendar", "read_calendar", "read_gmail",
             "inspect_screen", "inspect_focus_region", "request_screen_access":
            return .voice
        case "search_session_memory", "summarize_session_memory",
             "search_long_term_memory", "summarize_long_term_memory", "save_long_term_memory":
            return .memory
        case "open_app", "open_url", "open_voiyce_section", "draft_gmail", "send_gmail",
             "insert_text", "type_text", "click_screen", "press_key",
             "start_focus_highlight", "start_focus_paint", "start_focus_underline",
             "clear_focus_highlight", "clear_tour_guide", "act_with_computer":
            return .actions
        default:
            return .voice
        }
    }

    private func logSymbol(forTool name: String) -> String {
        switch name {
        case "check_calendar", "read_calendar":
            return "calendar"
        case "read_gmail", "draft_gmail", "send_gmail":
            return "envelope"
        case "open_app", "open_url", "open_voiyce_section":
            return "arrow.up.right.square"
        case "insert_text", "type_text":
            return "text.cursor"
        case "click_screen", "press_key", "act_with_computer":
            return "cursorarrow.click.2"
        case "inspect_screen", "inspect_focus_region", "request_screen_access":
            return "rectangle.dashed"
        case "start_focus_highlight", "start_focus_paint", "start_focus_underline", "clear_focus_highlight":
            return "scope"
        case "search_session_memory", "summarize_session_memory",
             "search_long_term_memory", "summarize_long_term_memory", "save_long_term_memory":
            return "brain"
        default:
            return "wrench.and.screwdriver"
        }
    }

    private func safeToolSuccessSummary(for name: String, result: AgentToolResult) -> String {
        switch name {
        case "check_calendar", "read_calendar":
            return "Calendar result returned."
        case "read_gmail":
            return "Gmail result returned."
        case "open_app":
            return "Opened the requested app."
        case "open_url":
            return "Opened the requested URL."
        case "open_voiyce_section":
            return "Opened the requested Voiyce section."
        case "draft_gmail":
            return "Opened a visible Gmail draft for review."
        case "send_gmail":
            return "Sent an approved Gmail message."
        case "insert_text", "type_text":
            return "Inserted text into the active app."
        case "click_screen":
            return "Clicked the requested screen location."
        case "press_key":
            return "Pressed the requested key."
        case "inspect_screen", "inspect_focus_region":
            return "Screen context returned."
        case "request_screen_access":
            return "Screen Recording recovery path shown."
        case "start_focus_highlight", "start_focus_paint", "start_focus_underline":
            return "Focus highlight capture started."
        case "clear_focus_highlight":
            return "Focus highlight cleared."
        case "clear_tour_guide":
            return "Tour guide visuals cleared."
        case "act_with_computer":
            return "Computer-use action loop completed."
        case "search_session_memory", "summarize_session_memory":
            return "Session memory result returned."
        case "search_long_term_memory", "summarize_long_term_memory":
            return "Long-term memory result returned."
        case "save_long_term_memory":
            if result.data?["memory_skipped"] == "true" {
                return "Memory write skipped by privacy rules."
            }
            return "Memory record saved."
        default:
            return "Tool result returned."
        }
    }

    private func logToolFailureIfNeeded(name: String, result: AgentToolResult) {
        guard !result.ok else { return }
        guard result.needsConfirmation != true else { return }
        guard result.data?["blocked"] == nil else { return }

        var details = [AgentLogEventDetail(key: "Tool", value: name)]
        if let requires = result.data?["requires"] {
            details.append(AgentLogEventDetail(key: "Requires", value: requires))
        }
        if let nextStep = result.data?["next_step"],
           !nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details.append(AgentLogEventDetail(key: "Next step", value: nextStep))
        }

        eventStore.append(
            category: .errors,
            status: result.message.localizedCaseInsensitiveContains("cancel") ? .cancelled : .failed,
            symbol: "wrench.and.screwdriver",
            title: "Tool call failed",
            summary: result.message,
            details: details
        )
    }

    private func confirmationRequest(for name: String, arguments: [String: String]) -> AgentConfirmationCopy? {
        safetyPolicy.confirmationRequest(name: name, arguments: arguments, mode: currentSafetyMode())
    }

    private func blockedAction(name: String, arguments: [String: String]) -> AgentToolResult? {
        guard let blocked = safetyPolicy.blockedAction(name: name, arguments: arguments) else { return nil }

        eventStore.append(
            category: .errors,
            status: .failed,
            symbol: "hand.raised",
            title: "Action blocked",
            summary: blocked.message,
            details: [AgentLogEventDetail(key: "Tool", value: name)]
        )

        return blocked
    }

    private func saveScreenMemory(_ result: AgentToolResult, source: String) {
        let summary = result.data?["summary"] ?? result.message
        let visibleText = result.data?["visible_text"] ?? ""
        let actionableContext = result.data?["actionable_context"] ?? ""
        _ = longTermMemory.addRecord(
            source: source,
            summary: summary,
            searchableText: [visibleText, actionableContext].filter { !$0.isEmpty }.joined(separator: "\n\n"),
            tags: ["screen", "agent"],
            appHint: NSWorkspace.shared.frontmostApplication?.localizedName
        )
    }

    private func candidateAppNames(for appName: String) -> [String] {
        let aliases = [
            "gmail": ["Google Chrome", "Safari"],
            "chrome": ["Google Chrome"],
            "google chrome": ["Google Chrome"],
            "calendar": ["Calendar"],
            "notes": ["Notes"],
            "safari": ["Safari"],
            "finder": ["Finder"]
        ]

        return aliases[appName.lowercased()] ?? [appName]
    }

    private var bundleIdentifierAliases: [String: String] {
        [
            "google chrome": "com.google.Chrome",
            "safari": "com.apple.Safari",
            "calendar": "com.apple.iCal",
            "notes": "com.apple.Notes",
            "finder": "com.apple.finder"
        ]
    }

    private func parseDateOnly(_ value: String) -> Date? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let calendar = Calendar.current
        if text.isEmpty || text == "today" {
            return Date()
        }
        if text == "tomorrow" {
            return calendar.date(byAdding: .day, value: 1, to: Date())
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }

    private func parseDateTime(date: String, time: String) -> Date? {
        guard let day = parseDateOnly(date) else { return nil }
        let text = time.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let calendar = Calendar.current
        let normalized = text
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: " ", with: "")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let datePrefix = formatter.string(from: day)

        for pattern in ["yyyy-MM-ddh:mma", "yyyy-MM-ddha", "yyyy-MM-ddHH:mm", "yyyy-MM-ddHH"] {
            let parser = DateFormatter()
            parser.locale = Locale(identifier: "en_US_POSIX")
            parser.dateFormat = pattern
            if let parsed = parser.date(from: datePrefix + normalized.uppercased()) {
                return parsed
            }
        }

        if let hour = Int(normalized), (0...23).contains(hour) {
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
        }

        return nil
    }

    private func userFacingDateTimeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    private func parseInteger(_ value: String?, defaultValue: Int) -> Int {
        Int(cleaned(value)) ?? defaultValue
    }

    private func runAppleScript(_ source: String) -> (ok: Bool, value: String, message: String?) {
        var error: NSDictionary?
        guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error) else {
            let message = (error?[NSAppleScript.errorMessage] as? String)
                ?? (error?.description)
                ?? "AppleScript failed."
            return (false, "", message)
        }
        return (true, result.stringValue ?? "", nil)
    }

    private func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }

    private func cleaned(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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

private struct AgentToolRequest: Decodable {
    let name: String
    let arguments: [String: String]?
    let mode: String?
}

private struct AgentConfirmationRequest: Decodable {
    let confirmationID: String
    let approved: Bool?
    let decision: String?

    enum CodingKeys: String, CodingKey {
        case confirmationID
        case approved
        case decision
    }
}

struct AgentToolResult: Codable {
    let ok: Bool
    let message: String
    let data: [String: String]?
    let needsConfirmation: Bool?
    let confirmationID: String?

    init(
        ok: Bool,
        message: String,
        data: [String: String]?,
        needsConfirmation: Bool? = nil,
        confirmationID: String? = nil
    ) {
        self.ok = ok
        self.message = message
        self.data = data
        self.needsConfirmation = needsConfirmation
        self.confirmationID = confirmationID
    }
}

enum AgentToolRecoveryCopy {
    static let invalidRequest = "Voiyce could not read that Agent request. Try again."
    static let invalidConfirmation = "Voiyce could not read that confirmation response. Try the action again."
    static let unsupportedRequest = "Voiyce received a request it cannot run yet. Try rephrasing it."
    static let failed = "Voiyce could not complete that Agent request. Try again, then open Agent Log if it keeps happening."
    static let confirmedActionFailed = "The approved action failed before it could finish. Try again, then open Agent Log if it keeps happening."
    static let nextStep = "Try again. If it keeps failing, open Agent Log and contact support."
    static let invalidRequestNextStep = "Ask again from the Agent session so Voiyce can send a complete tool request."
    static let invalidConfirmationNextStep = "Use the confirmation controls again, or stop the session and retry the action."
    static let confirmationUnavailableNextStep = "Ask Voiyce to start the action again if you still want it done."
    static let missingDetailNextStep = "Try again with the missing detail included."
    static let openAppNextStep = "Check that the app is installed, then try again with its full app name."
    static let openURLNextStep = "Check the URL, then try again."
    static let gmailDraftNextStep = "Open Chrome and sign in to Gmail, then try again."
    static let googleOAuthNextStep = "Open Voiyce Settings, connect Google, then try the Gmail action again."
}

private struct PendingAgentAction {
    let name: String
    let arguments: [String: String]
    let summary: String
    let reason: String
}

struct AgentConfirmationCopy {
    let title: String
    let message: String
    let details: [String: String]
}

struct AgentActionSafetyPolicy {
    func confirmationRequest(name: String, arguments: [String: String], mode: AgentSafetyMode) -> AgentConfirmationCopy? {
        guard mode != .unrestricted else { return nil }

        let text = searchableActionText(name: name, arguments: arguments)
        let highImpact = containsAny(text, highImpactTerms)

        if mode == .strict, strictConfirmationTools.contains(name) {
            return AgentConfirmationCopy(
                title: "Approve this action?",
                message: confirmationMessage(name: name, arguments: arguments),
                details: confirmationDetails(name: name, arguments: arguments)
            )
        }

        if name == "send_gmail" || highImpact {
            return AgentConfirmationCopy(
                title: "Confirm sensitive action",
                message: confirmationMessage(name: name, arguments: arguments),
                details: confirmationDetails(name: name, arguments: arguments)
            )
        }

        return nil
    }

    func blockedAction(name: String, arguments: [String: String]) -> AgentToolResult? {
        let text = searchableActionText(name: name, arguments: arguments)
        guard let block = blockedActionGroups.first(where: { containsAny(text, $0.terms) }) else {
            return nil
        }

        return AgentToolResult(
            ok: false,
            message: block.message,
            data: ["blocked": block.category]
        )
    }

    private func confirmationMessage(name: String, arguments: [String: String]) -> String {
        switch name {
        case "send_gmail":
            return "Voiyce is ready to send an email to \(confirmationTarget(name: name, arguments: arguments))."
        case "act_with_computer":
            return "Voiyce is ready to operate the computer for: \(confirmationTarget(name: name, arguments: arguments))."
        case "insert_text", "type_text":
            return "Voiyce is ready to insert \(cleaned(arguments["text"]).count) characters into the active app."
        case "click_screen":
            return "Voiyce is ready to click \(confirmationTarget(name: name, arguments: arguments))."
        case "press_key":
            return "Voiyce is ready to press \(cleaned(arguments["key"])) in the active app."
        case "open_url":
            return "Voiyce is ready to open \(confirmationTarget(name: name, arguments: arguments))."
        case "open_app":
            return "Voiyce is ready to open \(confirmationTarget(name: name, arguments: arguments))."
        default:
            return "Voiyce is ready to run \(name) on \(confirmationTarget(name: name, arguments: arguments))."
        }
    }

    private func confirmationDetails(name: String, arguments: [String: String]) -> [String: String] {
        var details = [
            "Action": confirmationAction(name),
            "Target": confirmationTarget(name: name, arguments: arguments),
            "Consequence": confirmationConsequence(name: name, arguments: arguments)
        ]

        for (key, value) in arguments where !cleaned(value).isEmpty {
            let clipped = value.count > 260 ? "\(value.prefix(260))..." : value
            details[key] = clipped
        }

        return details
    }

    private func confirmationAction(_ name: String) -> String {
        switch name {
        case "send_gmail": "Send Gmail"
        case "act_with_computer": "Operate computer"
        case "insert_text", "type_text": "Insert text"
        case "click_screen": "Click screen"
        case "press_key": "Press key"
        case "open_url": "Open URL"
        case "open_app": "Open app"
        default: name
        }
    }

    private func confirmationTarget(name: String, arguments: [String: String]) -> String {
        switch name {
        case "send_gmail":
            let recipient = cleaned(arguments["recipient"])
            let subject = cleaned(arguments["subject"])
            let subjectText = subject.isEmpty ? "no subject" : "subject \"\(subject)\""
            return recipient.isEmpty ? subjectText : "\(recipient) with \(subjectText)"
        case "act_with_computer":
            let task = cleaned(arguments["task"])
            return task.isEmpty ? "the requested task" : task
        case "insert_text", "type_text":
            return "the active app text cursor"
        case "click_screen":
            return "screen coordinate \(cleaned(arguments["x"])), \(cleaned(arguments["y"]))"
        case "press_key":
            return "the active app"
        case "open_url":
            let url = cleaned(arguments["url"])
            return url.isEmpty ? "the requested URL" : url
        case "open_app":
            let appName = cleaned(arguments["app_name"])
            return appName.isEmpty ? "the requested app" : appName
        default:
            let target = cleaned(arguments["target"])
            return target.isEmpty ? "the requested target" : target
        }
    }

    private func confirmationConsequence(name: String, arguments: [String: String]) -> String {
        switch name {
        case "send_gmail":
            "The message leaves your Gmail account and may be seen by its recipients."
        case "act_with_computer":
            "Voiyce may click, type, or navigate in apps to complete this task."
        case "insert_text", "type_text":
            "The text will be inserted wherever the active cursor is focused."
        case "click_screen":
            "The focused app may select, open, submit, or change content at that location."
        case "press_key":
            "The active app will receive that keyboard input."
        case "open_url":
            "The URL will open in your browser and may navigate to an external site."
        case "open_app":
            "The app will be brought forward or launched."
        default:
            "This may change the active app, account, data, or external service."
        }
    }

    private func searchableActionText(name: String, arguments: [String: String]) -> String {
        ([name] + arguments.flatMap { [$0.key, $0.value] }).joined(separator: " ").lowercased()
    }

    private var strictConfirmationTools: Set<String> {
        [
            "send_gmail", "insert_text", "type_text", "click_screen", "press_key",
            "open_url", "open_app", "act_with_computer"
        ]
    }

    private var highImpactTerms: [String] {
        [
            "send", "submit", "delete", "remove", "purchase", "buy", "checkout",
            "billing", "payment", "account", "account change", "change account",
            "password", "credential", "credentials", "post publicly",
            "public post", "external post", "publish", "sign", "unsubscribe",
            "cancel subscription", "transfer", "refund", "invoice", "charge"
        ]
    }

    private var blockedActionGroups: [(category: String, terms: [String], message: String)] {
        let message = "I cannot help with catastrophic deletion, credential theft, malware, fraud, illegal access, hidden actions, or platform-abusive actions."
        return [
            (
                "catastrophic_system_action",
                [
                    "delete all files", "erase disk", "format disk", "wipe the computer",
                    "wipe this mac", "rm -rf", "remove everything", "factory reset",
                    "delete system", "erase all data", "delete system files"
                ],
                message
            ),
            (
                "credential_theft",
                [
                    "credential theft", "steal credentials", "steal password",
                    "copy passwords", "dump keychain", "extract api keys",
                    "exfiltrate credentials", "passwords without permission"
                ],
                message
            ),
            (
                "malware",
                [
                    "install malware", "keylogger", "ransomware", "trojan",
                    "backdoor", "virus payload", "malicious payload"
                ],
                message
            ),
            (
                "fraud",
                [
                    "commit fraud", "phishing", "fake transaction", "chargeback fraud",
                    "card testing", "stolen card"
                ],
                message
            ),
            (
                "illegal_access",
                [
                    "illegal access", "unauthorized access", "hack into",
                    "break into account", "bypass login", "bypass 2fa",
                    "crack password"
                ],
                message
            ),
            (
                "platform_abuse",
                [
                    "platform abuse", "bypass rate limit", "bypass rate limits",
                    "mass spam", "spam users", "fake reviews", "evade ban",
                    "bot accounts"
                ],
                message
            ),
            (
                "hidden_action",
                [
                    "without the user knowing", "hide this from user",
                    "conceal the action", "silently without permission",
                    "hidden action"
                ],
                message
            )
        ]
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private func cleaned(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private extension Optional where Wrapped == String {
    var isEmptyOrNil: Bool {
        self?.isEmpty ?? true
    }
}

private struct RealtimeSessionRequest: Encodable {
    let sdp: String
    let model: String?
    let mode: String?
}

private struct RealtimeSessionResponse: Decodable {
    let sdp: String
}

private struct RealtimeSessionErrorResponse: Decodable {
    let error: String?
    let code: String?
    let serverDisplayMessage: String?
    let upstreamStatus: Int?
    let upstreamBody: String?

    enum CodingKeys: String, CodingKey {
        case error
        case code
        case serverDisplayMessage = "displayMessage"
        case upstreamStatus
        case upstreamBody
    }

    func displayMessage(fallbackStatus: Int?) -> String {
        let message = error?.trimmingCharacters(in: .whitespacesAndNewlines)
        let upstreamBody = upstreamBody?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawFailure = [message, upstreamBody]
            .compactMap { $0 }
            .joined(separator: " ")

        if BackendUsageLimitCopy.isUsageLimit(statusCode: fallbackStatus, code: code, message: rawFailure) {
            return TalkModeRecoveryCopy.accountUsageLimit
        }

        if let serverDisplayMessage, !serverDisplayMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return serverDisplayMessage
        }

        return TalkModeRecoveryCopy.displayMessage(
            upstreamStatus: upstreamStatus,
            fallbackStatus: fallbackStatus,
            message: rawFailure
        )
    }
}

enum TalkModeRecoveryCopy {
    static let serviceName = "Talk service"
    static let authenticationRequired = "Sign in to Voiyce before starting Talk."
    static let microphonePermissionRequired = "Microphone access is off. Grant access in macOS Settings, then start Talk again."
    static let microphonePermissionNextStep = "Open macOS Settings > Privacy & Security > Microphone, allow Voiyce, then start Talk again."
    static let invalidAudioConnection = "Talk could not start the audio connection. Stop and try again."
    static let invalidResponse = "Talk received an unexpected response. Try again, then open Agent Log if it keeps happening."
    static let connectionFailed = "Talk could not connect. Check your internet connection, then try again."
    static let rateLimited = "Talk is temporarily rate-limited. Try again later."
    static let accountUsageLimit = "This account has reached its current Talk limit."

    static func requestFailed(statusCode: Int?) -> String {
        if BackendUsageLimitCopy.isUsageLimit(statusCode: statusCode) {
            return accountUsageLimit
        }

        if statusCode == 429 {
            return rateLimited
        }

        return connectionFailed
    }

    static func displayMessage(upstreamStatus: Int?, fallbackStatus: Int?, message: String?) -> String {
        let rawMessage = message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let combinedStatus = upstreamStatus ?? fallbackStatus

        if BackendUsageLimitCopy.isUsageLimit(statusCode: combinedStatus, message: rawMessage) {
            return accountUsageLimit
        }

        if combinedStatus == 429
            || rawMessage.localizedCaseInsensitiveContains("quota")
            || rawMessage.localizedCaseInsensitiveContains("rate limit")
            || rawMessage.localizedCaseInsensitiveContains("rate-limit") {
            return rateLimited
        }

        return requestFailed(statusCode: combinedStatus)
    }

    static func serviceFailureNextStep(statusCode: Int?) -> String {
        if BackendUsageLimitCopy.isUsageLimit(statusCode: statusCode) {
            return BackendUsageLimitCopy.nextStep
        }

        if statusCode == 429 {
            return "Wait a few minutes and try Talk again. If it keeps happening, open Agent Log and contact support."
        }

        return "Check your internet connection and try Talk again. If it keeps happening, open Agent Log and contact support."
    }
}

private struct HTTPRequest {
    let method: String
    let path: String
    let body: Data
}

private enum RealtimeAgentServerError: LocalizedError {
    case missingSDP
    case invalidSDP(Int)
    case authenticationRequired
    case invalidFunctionResponse
    case functionError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingSDP:
            return TalkModeRecoveryCopy.invalidAudioConnection
        case .invalidSDP:
            return TalkModeRecoveryCopy.invalidAudioConnection
        case .authenticationRequired:
            return TalkModeRecoveryCopy.authenticationRequired
        case .invalidFunctionResponse:
            return TalkModeRecoveryCopy.invalidResponse
        case .functionError(_, let message):
            return message
        }
    }
}

nonisolated private func queryValue(_ key: String, in path: String) -> String? {
    guard let query = path.split(separator: "?", maxSplits: 1).dropFirst().first else {
        return nil
    }

    for pair in query.split(separator: "&") {
        let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.first == key else { continue }
        let rawValue = parts.indices.contains(1) ? parts[1] : ""
        return rawValue.removingPercentEncoding ?? rawValue
    }

    return nil
}

nonisolated private func readHTTPRequest(from connection: NWConnection) async throws -> HTTPRequest {
    var data = Data()

    while true {
        let chunk = try await connection.receiveData(minimumIncompleteLength: 1, maximumLength: 64 * 1024)
        data.append(chunk)

        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            continue
        }

        let headerData = data[..<headerRange.lowerBound]
        let headerText = String(decoding: headerData, as: UTF8.self)
        let lines = headerText.components(separatedBy: "\r\n")
        let requestLine = lines.first?.split(separator: " ") ?? []
        let method = requestLine.indices.contains(0) ? String(requestLine[0]) : ""
        let path = requestLine.indices.contains(1) ? String(requestLine[1]) : ""
        let contentLength = lines.compactMap { line -> Int? in
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, parts[0].lowercased() == "content-length" else { return nil }
            return Int(parts[1])
        }.first ?? 0

        let bodyStart = headerRange.upperBound
        let bodyBytesAvailable = data.count - bodyStart
        if bodyBytesAvailable >= contentLength {
            let body = data.subdata(in: bodyStart..<(bodyStart + contentLength))
            return HTTPRequest(method: method, path: path, body: body)
        }
    }
}

private extension NWConnection {
    nonisolated func receiveData(minimumIncompleteLength: Int, maximumLength: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            receive(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(returning: Data())
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }
}

private enum ListenerEvent: Sendable {
    case ready(port: UInt16?)
    case failed(String)
    case other
}

nonisolated private func httpResponse(status: String, contentType: String, body: Data) -> Data {
    var response = Data()
    response.append(Data("HTTP/1.1 \(status)\r\n".utf8))
    response.append(Data("Content-Type: \(contentType)\r\n".utf8))
    response.append(Data("Content-Length: \(body.count)\r\n".utf8))
    response.append(Data("Access-Control-Allow-Origin: *\r\n".utf8))
    response.append(Data("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n".utf8))
    response.append(Data("Access-Control-Allow-Headers: Content-Type\r\n".utf8))
    response.append(Data("Connection: close\r\n\r\n".utf8))
    response.append(body)
    return response
}

let realtimeHTML = """
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Voiyce Realtime Agent</title>
  <style>
    :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; }
    body { margin: 0; background: #101012; color: #f4f1fb; }
    main { max-width: 820px; margin: 0 auto; padding: 44px 28px; }
    h1 { font-size: 36px; margin: 0 0 12px; letter-spacing: 0; }
    p { color: rgba(244, 241, 251, .68); line-height: 1.6; }
    .panel { border: 1px solid rgba(255,255,255,.10); background: rgba(255,255,255,.045); border-radius: 8px; padding: 20px; margin-top: 18px; }
    .row { display: flex; gap: 12px; align-items: center; justify-content: space-between; flex-wrap: wrap; }
    button { border: 0; border-radius: 7px; padding: 11px 15px; font-weight: 700; cursor: pointer; }
    button.primary { background: #9b6cff; color: white; }
    button.secondary { background: rgba(255,255,255,.10); color: white; }
    button.danger { background: #ff6b6b; color: white; }
    button.mini { padding: 8px 10px; font-size: 12px; margin-right: 8px; }
    button:disabled { opacity: .48; cursor: not-allowed; }
    #status { font-size: 24px; font-weight: 750; }
    #logs { display: grid; gap: 10px; margin-top: 14px; }
    .log { background: rgba(0,0,0,.24); border-radius: 7px; padding: 10px 12px; color: rgba(244,241,251,.76); font-size: 13px; white-space: pre-wrap; }
    .confirm { border: 1px solid rgba(255,107,107,.45); background: rgba(255,107,107,.08); }
  </style>
</head>
<body>
  <main>
    <h1>Voiyce Realtime Agent</h1>
    <p>Hold Option from anywhere in Voiyce to talk to the Agent. It can open apps and sites, fill text, click or press keys, and use Gmail after Google OAuth is connected.</p>
    <section class="panel row">
      <div>
        <div style="color:rgba(244,241,251,.52);font-size:12px;text-transform:uppercase;letter-spacing:.16em;">Status</div>
        <div id="status">Idle</div>
      </div>
      <div>
        <button id="connect" class="primary">Connect</button>
        <button id="stop" class="secondary">Stop</button>
      </div>
    </section>
    <section class="panel">
      <strong>Events</strong>
      <div id="logs"><div class="log">No events yet.</div></div>
    </section>
    <audio id="remoteAudio" autoplay></audio>
  </main>
  <script>
    const statusEl = document.getElementById("status");
    const logsEl = document.getElementById("logs");
    const connectButton = document.getElementById("connect");
    const stopButton = document.getElementById("stop");
    const remoteAudio = document.getElementById("remoteAudio");
    let pc = null;
    let dc = null;
    let stream = null;
    const handledCalls = new Set();
    const knownModes = new Set(["talk", "act"]);
    let sessionStartedAt = 0;
    let currentMode = "talk";
    let firstAudioSignalSent = false;
    let firstResponseCompleteSent = false;
    let peerConnectedSent = false;
    let connectionProblemSent = false;
    let userDisconnecting = false;
    let connectionLostTimer = null;
    let activeResponseID = null;
    let interruptionStartedAt = 0;
    let connectionAttemptID = 0;
    const toolStartTimes = new Map();

    function setStatus(text) { statusEl.textContent = text; }
    function nowMs() { return performance.now ? performance.now() : Date.now(); }
    function elapsedFrom(start) { return Math.max(0, Math.round(nowMs() - start)); }
    function sessionElapsed() { return sessionStartedAt ? elapsedFrom(sessionStartedAt) : 0; }
    function emitTelemetry(name, data = {}) {
      try {
        window.webkit?.messageHandlers?.voiyceAgent?.postMessage({
          type: "telemetry",
          name,
          mode: currentMode,
          elapsed_ms: sessionElapsed(),
          ...data
        });
      } catch {}
    }
    function resetTelemetry(mode) {
      sessionStartedAt = nowMs();
      currentMode = knownModes.has(mode) ? mode : "talk";
      firstAudioSignalSent = false;
      firstResponseCompleteSent = false;
      peerConnectedSent = false;
      connectionProblemSent = false;
      userDisconnecting = false;
      clearConnectionLostTimer();
      activeResponseID = null;
      interruptionStartedAt = 0;
      toolStartTimes.clear();
      emitTelemetry("session_start");
    }
    function log(text) {
      if (logsEl.textContent === "No events yet.") logsEl.innerHTML = "";
      const div = document.createElement("div");
      div.className = "log";
      div.textContent = text;
      logsEl.prepend(div);
      while (logsEl.children.length > 10) logsEl.removeChild(logsEl.lastChild);
    }
    function sendEvent(event) {
      if (dc && dc.readyState === "open") dc.send(JSON.stringify(event));
    }
    function releaseMediaStream(mediaStream) {
      mediaStream?.getTracks().forEach((track) => track.stop());
    }
    async function waitForIceGatheringComplete(peerConnection) {
      if (peerConnection.iceGatheringState === "complete") return;
      await new Promise((resolve) => {
        const timeout = setTimeout(resolve, 2500);
        peerConnection.addEventListener("icegatheringstatechange", () => {
          if (peerConnection.iceGatheringState === "complete") {
            clearTimeout(timeout);
            resolve();
          }
        });
      });
    }
    function clearConnectionLostTimer() {
      if (connectionLostTimer) {
        clearTimeout(connectionLostTimer);
        connectionLostTimer = null;
      }
    }
    function emitConnectionLost(reason) {
      if (connectionProblemSent || userDisconnecting) return;
      connectionProblemSent = true;
      clearConnectionLostTimer();
      log(reason);
      emitTelemetry("connection_lost", { failure_reason: reason });
      disconnect(false);
    }
    function scheduleConnectionLost(reason) {
      if (connectionProblemSent || userDisconnecting || connectionLostTimer) return;
      connectionLostTimer = setTimeout(() => emitConnectionLost(reason), 5000);
    }
    function handleConnectionState(state, source) {
      if (userDisconnecting) return;
      setStatus(state);
      if (state === "connected" || state === "completed") {
        clearConnectionLostTimer();
      }
      if (source === "peer" && state === "connected" && !peerConnectedSent) {
        peerConnectedSent = true;
        emitTelemetry("peer_connected");
      }
      if (state === "failed") {
        emitConnectionLost(`Talk connection failed (${source}).`);
      }
      if (state === "disconnected") {
        scheduleConnectionLost(`Talk connection was disconnected (${source}).`);
      }
    }
    function finishToolCall(callId, result) {
      sendEvent({ type: "conversation.item.create", item: { type: "function_call_output", call_id: callId, output: JSON.stringify(result) } });
      sendEvent({ type: "response.create" });
      log(result.message || "Tool finished.");
    }
    function confirmToolCall(callId, result) {
      const div = document.createElement("div");
      div.className = "log confirm";
      div.textContent = result.message || "Confirm this action.";
      const actions = document.createElement("div");
      actions.style.marginTop = "10px";
      const confirm = document.createElement("button");
      confirm.className = "danger mini";
      confirm.textContent = "Confirm";
      const cancel = document.createElement("button");
      cancel.className = "secondary mini";
      cancel.textContent = "Cancel";
      const stopSession = document.createElement("button");
      stopSession.className = "secondary mini";
      stopSession.textContent = "Stop Session";
      const setConfirmButtonsDisabled = (disabled) => {
        confirm.disabled = disabled;
        cancel.disabled = disabled;
        stopSession.disabled = disabled;
      };
      confirm.onclick = async () => {
        setConfirmButtonsDisabled(true);
        try {
          const response = await fetch("/agent-confirm", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ confirmationID: result.confirmationID, approved: true })
          });
          const confirmed = await response.json();
          log(confirmed.message || "Confirmed.");
          sendEvent({ type: "conversation.item.create", item: { type: "message", role: "user", content: [{ type: "input_text", text: `I approved confirmation ${result.confirmationID}. ${confirmed.message || ""}` }] } });
          sendEvent({ type: "response.create" });
        } catch (error) {
          log(error.message || "Confirmation failed.");
        }
      };
      cancel.onclick = async () => {
        setConfirmButtonsDisabled(true);
        try {
          await fetch("/agent-confirm", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ confirmationID: result.confirmationID, approved: false })
          });
        } catch {}
        log("User cancelled the action.");
        sendEvent({ type: "conversation.item.create", item: { type: "message", role: "user", content: [{ type: "input_text", text: `I cancelled confirmation ${result.confirmationID}.` }] } });
        sendEvent({ type: "response.create" });
      };
      stopSession.onclick = async () => {
        setConfirmButtonsDisabled(true);
        try {
          await fetch("/agent-confirm", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ confirmationID: result.confirmationID, decision: "stop_session" })
          });
        } catch {}
        log("User stopped the session before the action ran.");
        sendEvent({ type: "conversation.item.create", item: { type: "message", role: "user", content: [{ type: "input_text", text: `I stopped the session for confirmation ${result.confirmationID}.` }] } });
        sendEvent({ type: "response.create" });
      };
      actions.append(confirm, cancel, stopSession);
      div.append(actions);
      if (logsEl.textContent === "No events yet.") logsEl.innerHTML = "";
      logsEl.prepend(div);
    }
    async function runTool(name, callId, rawArguments) {
      if (!callId || handledCalls.has(callId)) return;
      handledCalls.add(callId);
      toolStartTimes.set(callId, nowMs());
      emitTelemetry("tool_call_started", { tool_name: name });
      let args = {};
      try { args = JSON.parse(rawArguments || "{}"); } catch { log("Tool call had invalid JSON arguments."); }

      try {
        const response = await fetch("/agent-tool", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ name, arguments: args, mode: currentMode })
        });
        const result = await response.json();
        emitTelemetry("tool_call_finished", {
          tool_name: name,
          tool_elapsed_ms: elapsedFrom(toolStartTimes.get(callId) || nowMs()),
          ok: Boolean(result.ok)
        });
        toolStartTimes.delete(callId);
        if (result.needsConfirmation && result.confirmationID) {
          confirmToolCall(callId, result);
          return finishToolCall(callId, result);
        }
        finishToolCall(callId, result);
      } catch (error) {
        emitTelemetry("tool_call_finished", {
          tool_name: name,
          tool_elapsed_ms: elapsedFrom(toolStartTimes.get(callId) || nowMs()),
          ok: false
        });
        toolStartTimes.delete(callId);
        finishToolCall(callId, { ok: false, message: error.message || `Failed to run ${name}.` });
      }
    }
    function registerTools() {
      sendEvent({
        type: "session.update",
        session: {
          type: "realtime",
          tools: [
            {
              type: "function",
              name: "check_calendar",
              description: "Check the user's connected Google Calendar for availability at a requested date and time.",
              parameters: {
                type: "object",
                properties: {
                  date: { type: "string", description: "Requested date, such as 2026-05-12 or tomorrow." },
                  time: { type: "string", description: "Requested time, such as 09:00 or 2:30 PM." },
                  duration_minutes: { type: "string", description: "Optional duration in minutes. Default is 30." }
                },
                required: ["date", "time"]
              }
            },
            {
              type: "function",
              name: "read_calendar",
              description: "Read the user's connected Google Calendar events for a day.",
              parameters: {
                type: "object",
                properties: {
                  date: { type: "string", description: "Day to read, such as today, tomorrow, or 2026-05-12." },
                  limit: { type: "string", description: "Maximum events to return." }
                },
                required: ["date"]
              }
            },
            {
              type: "function",
              name: "read_gmail",
              description: "Read recent matching Gmail messages. Requires Google OAuth; do not use Apple Mail as a fallback.",
              parameters: {
                type: "object",
                properties: {
                  query: { type: "string", description: "Optional search text for sender, subject, or body." },
                  limit: { type: "string", description: "Maximum messages to return." }
                },
                required: []
              }
            },
            {
              type: "function",
              name: "open_app",
              description: "Open or activate a macOS app by name. Use this for low-risk app launching only.",
              parameters: {
                type: "object",
                properties: {
                  app_name: { type: "string", description: "The app name, such as Safari, Notes, Calendar, Chrome, Finder, or Gmail." }
                },
                required: ["app_name"]
              }
            },
            {
              type: "function",
              name: "open_url",
              description: "Open a URL in the user's default browser.",
              parameters: {
                type: "object",
                properties: {
                  url: { type: "string", description: "The URL or domain to open." }
                },
                required: ["url"]
              }
            },
            {
              type: "function",
              name: "open_voiyce_section",
              description: "Navigate Voiyce's own UI to Dashboard, Agent, Agent Log, or Settings. Use this instead of clicking screen coordinates when the user asks to switch Voiyce tabs.",
              parameters: {
                type: "object",
                properties: {
                  section: { type: "string", description: "One of dashboard, agent, agent log, or settings." }
                },
                required: ["section"]
              }
            },
            {
              type: "function",
              name: "draft_gmail",
              description: "Open Gmail in Google Chrome with a visible compose draft already filled in. Use this when the user asks to draft an email. Do not use Apple Mail as a fallback.",
              parameters: {
                type: "object",
                properties: {
                  recipient: { type: "string", description: "Email address or recipient text." },
                  subject: { type: "string", description: "Email subject." },
                  body: { type: "string", description: "Email body draft." }
                },
                required: ["recipient", "subject", "body"]
              }
            },
            {
              type: "function",
              name: "send_gmail",
              description: "Send an email through the Gmail API, but only after Voiyce shows a confirmation button and the user confirms. Requires Google OAuth.",
              parameters: {
                type: "object",
                properties: {
                  recipient: { type: "string", description: "Email address." },
                  subject: { type: "string", description: "Email subject." },
                  body: { type: "string", description: "Email body." }
                },
                required: ["recipient", "subject", "body"]
              }
            },
            {
              type: "function",
              name: "insert_text",
              description: "Insert text into the currently active app using Voiyce text insertion.",
              parameters: {
                type: "object",
                properties: {
                  text: { type: "string", description: "The exact text to insert." }
                },
                required: ["text"]
              },
            },
            {
              type: "function",
              name: "click_screen",
              description: "Click a visible screen coordinate. Do not use for purchase, delete, or send buttons unless the user has explicitly confirmed the exact action.",
              parameters: {
                type: "object",
                properties: {
                  x: { type: "string", description: "Global screen x coordinate." },
                  y: { type: "string", description: "Global screen y coordinate." }
                },
                required: ["x", "y"]
              }
            },
            {
              type: "function",
              name: "press_key",
              description: "Press a keyboard key, optionally with modifiers, for app or website control.",
              parameters: {
                type: "object",
                properties: {
                  key: { type: "string", description: "Key name such as tab, return, escape, a, c, v, left, right, up, or down." },
                  modifiers: { type: "string", description: "Comma-separated modifiers: command, option, control, shift." }
                },
                required: ["key"]
              }
            },
            {
              type: "function",
              name: "inspect_screen",
              description: "Inspect the user's current main display and return visible UI, visible text, and actionable context. Use this before acting on what the user is seeing.",
              parameters: {
                type: "object",
                properties: {
                  prompt: { type: "string", description: "Optional focus question, such as summarize the visible email or identify the button to click." }
                },
                required: []
              }
            },
            {
              type: "function",
              name: "inspect_focus_region",
              description: "Inspect only the user-marked focus region. Use this when the user says this area, this box, or the highlighted part.",
              parameters: {
                type: "object",
                properties: {
                  prompt: { type: "string", description: "Optional focus question for the marked region." }
                },
                required: []
              }
            },
            {
              type: "function",
              name: "start_focus_highlight",
              description: "Start the focus highlight overlay so the user can mark a visible screen region. Use mode=paint for freeform highlighted areas and mode=underline when the user wants to underline text or a control.",
              parameters: {
                type: "object",
                properties: {
                  mode: { type: "string", description: "rectangle, paint, or underline. Defaults to rectangle." }
                },
                required: []
              }
            },
            {
              type: "function",
              name: "start_focus_paint",
              description: "Start a freeform paint highlight. Use this when the user says paint this, mark this, circle this, or wants Voiyce to act on a rough visual area.",
              parameters: {
                type: "object",
                properties: {},
                required: []
              }
            },
            {
              type: "function",
              name: "start_focus_underline",
              description: "Start an underline focus mark. Use this when the user says underline this, this line, this word, or wants to point at text without selecting a full box.",
              parameters: {
                type: "object",
                properties: {},
                required: []
              }
            },
            {
              type: "function",
              name: "clear_focus_highlight",
              description: "Clear the currently marked focus region.",
              parameters: {
                type: "object",
                properties: {},
                required: []
              }
            },
            {
              type: "function",
              name: "show_tour_guide",
              description: "Show non-clicking tour-guide visuals on screen. Use this to point at something, explain what the user should look at, or guide step by step without taking action.",
              parameters: {
                type: "object",
                properties: {
                  title: { type: "string", description: "Short label for the guide callout." },
                  message: { type: "string", description: "One short explanation of what the user should notice or do." },
                  x: { type: "string", description: "Optional global screen x coordinate for the target or target rectangle." },
                  y: { type: "string", description: "Optional global screen y coordinate for the target or target rectangle." },
                  width: { type: "string", description: "Optional target rectangle width." },
                  height: { type: "string", description: "Optional target rectangle height." },
                  style: { type: "string", description: "spotlight, underline, or callout." },
                  duration_seconds: { type: "string", description: "How long to keep the guide visible. Defaults to 8." }
                },
                required: ["message"]
              }
            },
            {
              type: "function",
              name: "clear_tour_guide",
              description: "Clear any visible tour-guide, preview, paint, underline, or callout visual.",
              parameters: {
                type: "object",
                properties: {},
                required: []
              }
            },
            {
              type: "function",
              name: "request_screen_access",
              description: "Ask macOS for Screen Recording permission so Voiyce can inspect the current screen.",
              parameters: {
                type: "object",
                properties: {},
                required: []
              }
            },
            {
              type: "function",
              name: "act_with_computer",
              description: "Run a bounded app and website operation pass on the visible macOS UI for a specific user task after the user asks Voiyce to act.",
              parameters: {
                type: "object",
                properties: {
                  task: { type: "string", description: "A concise task grounded in the current visible screen, such as click the visible Settings button or open the first unread email." }
                },
                required: ["task"]
              }
            },
            {
              type: "function",
              name: "confirm_pending_action",
              description: "Approve, cancel, or stop the session for a pending Voiyce confirmation after the user answers by voice. Use the confirmation_id returned by the pending tool result.",
              parameters: {
                type: "object",
                properties: {
                  confirmation_id: { type: "string", description: "The pending confirmation id." },
                  decision: { type: "string", description: "approve, cancel, or stop_session." }
                },
                required: ["confirmation_id", "decision"]
              }
            },
            {
              type: "function",
              name: "videodb_memory_status",
              description: "Check whether active-session screen and audio context is recording and ready.",
              parameters: {
                type: "object",
                properties: {},
                required: []
              }
            },
            {
              type: "function",
              name: "search_session_memory",
              description: "Search active-session context for something the user saw or mentioned earlier in this Agent session.",
              parameters: {
                type: "object",
                properties: {
                  query: { type: "string", description: "Natural language search query over recent screen context, such as the visible date, an error message, or the email content from earlier." }
                },
                required: ["query"]
              }
            },
            {
              type: "function",
              name: "summarize_session_memory",
              description: "Summarize recent screen and microphone context for this active Agent session.",
              parameters: {
                type: "object",
                properties: {},
                required: []
              }
            },
            {
              type: "function",
              name: "search_long_term_memory",
              description: "Search local long-term memory across previous Voiyce sessions.",
              parameters: {
                type: "object",
                properties: {
                  query: { type: "string", description: "Natural language query over prior memories." },
                  limit: { type: "string", description: "Optional maximum results." }
                },
                required: ["query"]
              }
            },
            {
              type: "function",
              name: "summarize_long_term_memory",
              description: "Summarize recent local long-term memories.",
              parameters: {
                type: "object",
                properties: {
                  limit: { type: "string", description: "Optional maximum memories to summarize." }
                },
                required: []
              }
            },
            {
              type: "function",
              name: "save_long_term_memory",
              description: "Save a useful user-approved fact, preference, project detail, or work-session note to local long-term memory.",
              parameters: {
                type: "object",
                properties: {
                  summary: { type: "string", description: "Short memory summary." },
                  text: { type: "string", description: "Optional longer searchable text." },
                  source: { type: "string", description: "Where this memory came from." },
                  tags: { type: "string", description: "Comma-separated tags." },
                  app_hint: { type: "string", description: "Optional app or site hint." }
                },
                required: ["summary"]
              }
            }
          ],
          tool_choice: "auto"
        }
      });
      log("Registered Gmail, Calendar, app, browser, Voiyce navigation, text, click, key, screen, focus paint, tour guide, app operation, local memory, active-session context, and confirmation tools.");
    }
    function handleEvent(event) {
      if (event.type === "error") return log(`Error: ${event.error?.message || "Unknown realtime error"}`);
      if (event.type === "session.created") return log("Realtime session created.");
      if (event.type === "response.created") activeResponseID = event.response?.id || "active";
      if (!firstAudioSignalSent && (event.type === "response.audio.delta" || event.type === "response.output_audio.delta")) {
        firstAudioSignalSent = true;
        emitTelemetry("first_audio_delta", { event_type: event.type });
      }
      if (event.type === "input_audio_buffer.speech_started" && activeResponseID && !interruptionStartedAt) {
        interruptionStartedAt = nowMs();
        emitTelemetry("interruption_detected");
      }
      if (event.type === "response.output_audio_transcript.done" && event.transcript) {
        if (!firstResponseCompleteSent) {
          firstResponseCompleteSent = true;
          emitTelemetry("first_response_complete", {
            event_type: event.type,
            transcript_chars: event.transcript.length
          });
        }
        return log(event.transcript);
      }
      if (event.type === "response.function_call_arguments.done") return runTool(event.name, event.call_id, event.arguments);
      if (event.type === "response.done") {
        if (interruptionStartedAt) {
          emitTelemetry("interruption_completed", {
            interruption_elapsed_ms: elapsedFrom(interruptionStartedAt)
          });
          interruptionStartedAt = 0;
        }
        activeResponseID = null;
        (event.response?.output || [])
          .filter((item) => item.type === "function_call")
          .forEach((item) => runTool(item.name, item.call_id, item.arguments));
      }
    }
    async function connect(mode = "talk") {
      if (pc) return;
      const agentMode = knownModes.has(mode) ? mode : "talk";
      const attemptID = ++connectionAttemptID;
      try {
        resetTelemetry(agentMode);
        setStatus("Requesting microphone");
        connectButton.disabled = true;
        const acquiredStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        if (attemptID !== connectionAttemptID) {
          releaseMediaStream(acquiredStream);
          return;
        }
        stream = acquiredStream;
        emitTelemetry("microphone_ready");
        const peerConnection = new RTCPeerConnection();
        pc = peerConnection;
        peerConnection.ontrack = (event) => { remoteAudio.srcObject = event.streams[0]; };
        peerConnection.onconnectionstatechange = () => {
          handleConnectionState(peerConnection.connectionState, "peer");
        };
        peerConnection.oniceconnectionstatechange = () => {
          handleConnectionState(peerConnection.iceConnectionState, "ice");
        };
        stream.getAudioTracks().forEach((track) => peerConnection.addTrack(track, stream));
        dc = peerConnection.createDataChannel("oai-events");
        dc.onopen = registerTools;
        dc.onmessage = (message) => {
          try { handleEvent(JSON.parse(message.data)); } catch { log("Received invalid realtime event JSON."); }
        };
        setStatus("Creating offer");
        const offer = await peerConnection.createOffer();
        if (attemptID !== connectionAttemptID) return;
        await peerConnection.setLocalDescription(offer);
        await waitForIceGatheringComplete(peerConnection);
        if (attemptID !== connectionAttemptID) return;
        const localSdp = peerConnection.localDescription?.sdp || offer.sdp || "";
        if (!localSdp.trim() || !localSdp.includes("v=0") || !localSdp.includes("m=audio")) {
          throw new Error(`Could not create a usable WebRTC offer. SDP length: ${localSdp.length}`);
        }
        emitTelemetry("local_offer_created");
        log(`Created SDP offer (${localSdp.length} chars).`);
        const response = await fetch(`/realtime-session?mode=${encodeURIComponent(agentMode)}`, {
          method: "POST",
          headers: { "Content-Type": "application/sdp" },
          body: localSdp
        });
        const answer = await response.text();
        if (attemptID !== connectionAttemptID) return;
        if (!response.ok) throw new Error(answer || "Failed to create realtime call.");
        await peerConnection.setRemoteDescription({ type: "answer", sdp: answer });
        emitTelemetry("audio_connection_ready");
        setStatus("Connecting");
      } catch (error) {
        log(error.message || "Unable to connect.");
        emitTelemetry("connection_failed", {
          failure_reason: error.name || error.message || "Unknown connection error"
        });
        disconnect(false);
      }
    }
    function disconnect(userInitiated = true) {
      connectionAttemptID += 1;
      userDisconnecting = Boolean(userInitiated);
      clearConnectionLostTimer();
      dc?.close();
      pc?.close();
      releaseMediaStream(stream);
      remoteAudio.srcObject = null;
      dc = null;
      pc = null;
      stream = null;
      handledCalls.clear();
      toolStartTimes.clear();
      emitTelemetry("session_stopped");
      connectButton.disabled = false;
      setStatus("Idle");
    }
    connectButton.onclick = () => connect();
    stopButton.onclick = () => disconnect(true);
    window.voiyceAgentConnect = connect;
    window.voiyceAgentStop = () => disconnect(true);
  </script>
</body>
</html>
"""
#endif
