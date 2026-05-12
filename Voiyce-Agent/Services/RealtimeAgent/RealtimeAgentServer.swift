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
    private let client = InsForgeClientProvider.shared
    private let actionBridge = RealtimeAgentActionBridge()
    private var listener: NWListener?
    private(set) var url: URL?
    private(set) var lastError: String?

    var isRunning: Bool { listener != nil && url != nil }

    func start() {
        guard listener == nil else { return }

        do {
            let listener = try NWListener(using: .tcp, on: .any)
            listener.newConnectionHandler = { [weak self] connection in
                Task {
                    await self?.handle(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        if let port = listener.port {
                            self?.url = URL(string: "http://127.0.0.1:\(port.rawValue)/")
                            self?.lastError = nil
                        }
                    case .failed(let error):
                        self?.lastError = error.localizedDescription
                        self?.stop()
                    default:
                        break
                    }
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
        } catch {
            lastError = error.localizedDescription
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
            let body = Data((error.localizedDescription).utf8)
            let response = httpResponse(status: "500 Internal Server Error", contentType: "text/plain", body: body)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func route(_ request: HTTPRequest) async throws -> Data {
        if request.method == "OPTIONS" {
            return httpResponse(status: "204 No Content", contentType: "text/plain", body: Data())
        }

        if request.method == "GET", request.path == "/" {
            return httpResponse(status: "200 OK", contentType: "text/html; charset=utf-8", body: Data(realtimeHTML.utf8))
        }

        if request.method == "POST", request.path == "/realtime-session" {
            let sdp = String(decoding: request.body, as: UTF8.self)
            let answer = try await createRealtimeCallAnswer(for: sdp)
            return httpResponse(status: "200 OK", contentType: "application/sdp", body: Data(answer.utf8))
        }

        if request.method == "POST", request.path == "/agent-tool" {
            let result = try await actionBridge.handle(request.body)
            let body = try JSONEncoder().encode(result)
            return httpResponse(status: "200 OK", contentType: "application/json", body: body)
        }

        if request.method == "POST", request.path == "/agent-confirm" {
            let result = try await actionBridge.confirm(request.body)
            let body = try JSONEncoder().encode(result)
            return httpResponse(status: "200 OK", contentType: "application/json", body: body)
        }

        return httpResponse(status: "404 Not Found", contentType: "text/plain", body: Data("Not found".utf8))
    }

    private func createRealtimeCallAnswer(for sdp: String) async throws -> String {
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
            model: ProcessInfo.processInfo.environment["OPENAI_REALTIME_MODEL"]
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

        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw RealtimeAgentServerError.invalidFunctionResponse
        }

        if (200..<300).contains(httpResponse.statusCode) {
            return try JSONDecoder().decode(RealtimeSessionResponse.self, from: data).sdp
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw RealtimeAgentServerError.authenticationRequired
        }

        let errorPayload = try? JSONDecoder().decode(RealtimeSessionErrorResponse.self, from: data)
        throw RealtimeAgentServerError.functionError(
            httpResponse.statusCode,
            errorPayload?.displayMessage ?? String(decoding: data, as: UTF8.self)
        )
    }
}

@MainActor
private final class RealtimeAgentActionBridge {
    private let textInjector = TextInjector()
    private let googleWorkspace = GoogleWorkspaceManager.shared
    private let screenContextProvider = ScreenContextProvider()
    private let videoDBMemory = VideoDBAgentMemory.shared
    private var pendingActions: [String: PendingAgentAction] = [:]

    func handle(_ body: Data) async throws -> AgentToolResult {
        let request = try JSONDecoder().decode(AgentToolRequest.self, from: body)
        let arguments = request.arguments ?? [:]

        switch request.name {
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
        case "draft_gmail":
            return await draftGmail(arguments)
        case "send_gmail":
            return requestSendGmailConfirmation(arguments)
        case "insert_text":
            return insertText(arguments)
        case "type_text":
            return insertText(arguments)
        case "click_screen":
            return clickScreen(arguments)
        case "press_key":
            return pressKey(arguments)
        case "inspect_screen":
            return await screenContextProvider.inspectScreen(prompt: cleaned(arguments["prompt"]))
        case "request_screen_access":
            return requestScreenAccess()
        case "videodb_memory_status":
            return videoDBMemory.currentToolResult()
        case "search_session_memory":
            return await videoDBMemory.search(cleaned(arguments["query"]))
        case "summarize_session_memory":
            return await videoDBMemory.summarize()
        default:
            return AgentToolResult(
                ok: false,
                message: "Unknown tool: \(request.name)",
                data: nil
            )
        }
    }

    func confirm(_ body: Data) async throws -> AgentToolResult {
        let request = try JSONDecoder().decode(AgentConfirmationRequest.self, from: body)
        guard let action = pendingActions.removeValue(forKey: request.confirmationID) else {
            return AgentToolResult(ok: false, message: "That confirmation is no longer available.", data: nil)
        }

        switch action.name {
        case "send_gmail":
            return await sendGmail(action.arguments)
        default:
            return AgentToolResult(ok: false, message: "Unknown pending action: \(action.name)", data: nil)
        }
    }

    private func checkCalendar(_ arguments: [String: String]) async throws -> AgentToolResult {
        let dateText = cleaned(arguments["date"])
        let timeText = cleaned(arguments["time"])
        let durationMinutes = parseInteger(arguments["duration_minutes"], defaultValue: 30)

        guard let start = parseDateTime(date: dateText, time: timeText) else {
            return AgentToolResult(
                ok: false,
                message: "I could not understand that calendar date and time.",
                data: ["date": dateText, "time": timeText]
            )
        }

        return await googleWorkspace.checkCalendar(date: start, durationMinutes: durationMinutes)
    }

    private func readCalendar(_ arguments: [String: String]) async throws -> AgentToolResult {
        let dateText = cleaned(arguments["date"])
        let limit = parseInteger(arguments["limit"], defaultValue: 10)
        guard let day = parseDateOnly(dateText) else {
            return AgentToolResult(ok: false, message: "date is required. Use today, tomorrow, or YYYY-MM-DD.", data: nil)
        }

        return await googleWorkspace.readCalendar(day: day, limit: limit)
    }

    private func openApp(_ arguments: [String: String]) -> AgentToolResult {
        let appName = cleaned(arguments["app_name"])
        guard !appName.isEmpty else {
            return AgentToolResult(ok: false, message: "app_name is required.", data: nil)
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
            data: result.message.map { ["error": $0] }
        )
    }

    private func openURL(_ arguments: [String: String]) -> AgentToolResult {
        let urlText = cleaned(arguments["url"])
        guard !urlText.isEmpty else {
            return AgentToolResult(ok: false, message: "url is required.", data: nil)
        }

        let normalized = urlText.contains("://") ? urlText : "https://\(urlText)"
        guard let url = URL(string: normalized), NSWorkspace.shared.open(url) else {
            return AgentToolResult(ok: false, message: "Could not open \(urlText).", data: nil)
        }

        return AgentToolResult(ok: true, message: "Opened \(normalized).", data: ["url": normalized])
    }

    private func draftGmail(_ arguments: [String: String]) async -> AgentToolResult {
        let recipient = cleaned(arguments["recipient"])
        let subject = cleaned(arguments["subject"])
        let body = cleaned(arguments["body"])

        guard !recipient.isEmpty else {
            return AgentToolResult(ok: false, message: "recipient is required.", data: nil)
        }

        return openVisibleGmailCompose(recipient: recipient, subject: subject, body: body)
    }

    private func requestSendGmailConfirmation(_ arguments: [String: String]) -> AgentToolResult {
        guard googleWorkspace.isConnected else {
            return AgentToolResult(
                ok: false,
                message: "Google is not connected. Open Settings and connect Google before using send_gmail.",
                data: ["requires": "google_oauth"]
            )
        }

        let recipient = cleaned(arguments["recipient"])
        let subject = cleaned(arguments["subject"])
        let body = cleaned(arguments["body"])

        guard !recipient.isEmpty else {
            return AgentToolResult(ok: false, message: "recipient is required.", data: nil)
        }

        let id = UUID().uuidString
        pendingActions[id] = PendingAgentAction(
            name: "send_gmail",
            arguments: [
                "recipient": recipient,
                "subject": subject,
                "body": body
            ]
        )

        return AgentToolResult(
            ok: false,
            message: "Confirm before sending Gmail to \(recipient) with subject \"\(subject)\".",
            data: ["recipient": recipient, "subject": subject],
            needsConfirmation: true,
            confirmationID: id
        )
    }

    private func sendGmail(_ arguments: [String: String]) async -> AgentToolResult {
        let recipient = cleaned(arguments["recipient"])
        let subject = cleaned(arguments["subject"])
        let body = cleaned(arguments["body"])

        guard !recipient.isEmpty else {
            return AgentToolResult(ok: false, message: "recipient is required.", data: nil)
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
            return AgentToolResult(ok: false, message: "Could not build the Gmail compose URL.", data: nil)
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
            data: result.message.map { ["error": $0] }
        )
    }

    private func insertText(_ arguments: [String: String]) -> AgentToolResult {
        let text = cleaned(arguments["text"].isEmptyOrNil ? arguments["value"] : arguments["text"])
        guard !text.isEmpty else {
            return AgentToolResult(ok: false, message: "text is required.", data: nil)
        }

        textInjector.injectText(text)
        return AgentToolResult(ok: true, message: "Inserted text into the active app.", data: ["text": text])
    }

    private func clickScreen(_ arguments: [String: String]) -> AgentToolResult {
        guard let x = Double(cleaned(arguments["x"])),
              let y = Double(cleaned(arguments["y"])) else {
            return AgentToolResult(ok: false, message: "x and y screen coordinates are required.", data: nil)
        }

        let point = CGPoint(x: x, y: y)
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
            return AgentToolResult(ok: false, message: "Unsupported key: \(key).", data: nil)
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
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)

        return AgentToolResult(ok: true, message: "Pressed \(key).", data: ["key": key, "modifiers": cleaned(arguments["modifiers"])])
    }

    private func requestScreenAccess() -> AgentToolResult {
        let openedPrompt = screenContextProvider.requestScreenCaptureAccess()
        return AgentToolResult(
            ok: openedPrompt,
            message: openedPrompt
                ? "Requested Screen Recording permission. If macOS opens System Settings, enable Voiyce and restart the app."
                : "Screen Recording permission is already granted or macOS did not show a prompt.",
            data: ["permission": "screen_recording"]
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
}

private struct AgentConfirmationRequest: Decodable {
    let confirmationID: String
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

private struct PendingAgentAction {
    let name: String
    let arguments: [String: String]
}

private extension Optional where Wrapped == String {
    var isEmptyOrNil: Bool {
        self?.isEmpty ?? true
    }
}

private struct RealtimeSessionRequest: Encodable {
    let sdp: String
    let model: String?
}

private struct RealtimeSessionResponse: Decodable {
    let sdp: String
}

private struct RealtimeSessionErrorResponse: Decodable {
    let error: String?
    let upstreamStatus: Int?
    let upstreamBody: String?

    var displayMessage: String {
        let message = error?.trimmingCharacters(in: .whitespacesAndNewlines)
        let upstreamBody = upstreamBody?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let upstreamStatus {
            if let message, !message.isEmpty {
                return "OpenAI Realtime \(upstreamStatus): \(message)"
            }
            if let upstreamBody, !upstreamBody.isEmpty {
                return "OpenAI Realtime \(upstreamStatus): \(upstreamBody)"
            }
        }

        if let message, !message.isEmpty {
            return message
        }

        return "Realtime session request failed."
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
            return "Missing SDP offer."
        case .invalidSDP(let length):
            return "Invalid SDP offer generated locally. Length: \(length)."
        case .authenticationRequired:
            return "Authentication required"
        case .invalidFunctionResponse:
            return "Realtime session function returned an invalid response."
        case .functionError(let status, let message):
            return "HTTP \(status): \(message)"
        }
    }
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

nonisolated(unsafe) private let realtimeHTML = """
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

    function setStatus(text) { statusEl.textContent = text; }
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
      confirm.onclick = async () => {
        confirm.disabled = true;
        cancel.disabled = true;
        try {
          const response = await fetch("/agent-confirm", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ confirmationID: result.confirmationID })
          });
          finishToolCall(callId, await response.json());
        } catch (error) {
          finishToolCall(callId, { ok: false, message: error.message || "Confirmation failed." });
        }
      };
      cancel.onclick = () => {
        confirm.disabled = true;
        cancel.disabled = true;
        finishToolCall(callId, { ok: false, cancelled: true, message: "User cancelled the action." });
      };
      actions.append(confirm, cancel);
      div.append(actions);
      if (logsEl.textContent === "No events yet.") logsEl.innerHTML = "";
      logsEl.prepend(div);
    }
    async function runTool(name, callId, rawArguments) {
      if (!callId || handledCalls.has(callId)) return;
      handledCalls.add(callId);
      let args = {};
      try { args = JSON.parse(rawArguments || "{}"); } catch { log("Tool call had invalid JSON arguments."); }

      try {
        const response = await fetch("/agent-tool", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ name, arguments: args })
        });
        const result = await response.json();
        if (result.needsConfirmation && result.confirmationID) {
          return confirmToolCall(callId, result);
        }
        finishToolCall(callId, result);
      } catch (error) {
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
              name: "videodb_memory_status",
              description: "Check whether VideoDB active-session screen/audio memory is recording and indexed.",
              parameters: {
                type: "object",
                properties: {},
                required: []
              }
            },
            {
              type: "function",
              name: "search_session_memory",
              description: "Search the active VideoDB screen memory for something the user saw or mentioned earlier in this agent session.",
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
              description: "Summarize recent VideoDB screen and microphone memory for this active agent session.",
              parameters: {
                type: "object",
                properties: {},
                required: []
              }
            }
          ],
          tool_choice: "auto"
        }
      });
      log("Registered Gmail, Calendar, app, browser, text, click, key, screen, VideoDB memory, and confirmation tools.");
    }
    function handleEvent(event) {
      if (event.type === "error") return log(`Error: ${event.error?.message || "Unknown realtime error"}`);
      if (event.type === "session.created") return log("Realtime session created.");
      if (event.type === "response.output_audio_transcript.done" && event.transcript) return log(event.transcript);
      if (event.type === "response.function_call_arguments.done") return runTool(event.name, event.call_id, event.arguments);
      if (event.type === "response.done") {
        (event.response?.output || [])
          .filter((item) => item.type === "function_call")
          .forEach((item) => runTool(item.name, item.call_id, item.arguments));
      }
    }
    async function connect() {
      if (pc) return;
      try {
        setStatus("Requesting microphone");
        connectButton.disabled = true;
        stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        pc = new RTCPeerConnection();
        pc.ontrack = (event) => { remoteAudio.srcObject = event.streams[0]; };
        pc.onconnectionstatechange = () => setStatus(pc.connectionState);
        stream.getAudioTracks().forEach((track) => pc.addTrack(track, stream));
        dc = pc.createDataChannel("oai-events");
        dc.onopen = registerTools;
        dc.onmessage = (message) => {
          try { handleEvent(JSON.parse(message.data)); } catch { log("Received invalid realtime event JSON."); }
        };
        setStatus("Creating offer");
        const offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        await waitForIceGatheringComplete(pc);
        const localSdp = pc.localDescription?.sdp || offer.sdp || "";
        if (!localSdp.trim() || !localSdp.includes("v=0") || !localSdp.includes("m=audio")) {
          throw new Error(`Could not create a usable WebRTC offer. SDP length: ${localSdp.length}`);
        }
        log(`Created SDP offer (${localSdp.length} chars).`);
        const response = await fetch("/realtime-session", {
          method: "POST",
          headers: { "Content-Type": "application/sdp" },
          body: localSdp
        });
        const answer = await response.text();
        if (!response.ok) throw new Error(answer || "Failed to create realtime call.");
        await pc.setRemoteDescription({ type: "answer", sdp: answer });
        setStatus("Connecting");
      } catch (error) {
        log(error.message || "Unable to connect.");
        disconnect();
      }
    }
    function disconnect() {
      dc?.close();
      pc?.close();
      stream?.getTracks().forEach((track) => track.stop());
      dc = null;
      pc = null;
      stream = null;
      handledCalls.clear();
      connectButton.disabled = false;
      setStatus("Idle");
    }
    connectButton.onclick = connect;
    stopButton.onclick = disconnect;
    window.voiyceAgentConnect = connect;
    window.voiyceAgentStop = disconnect;
  </script>
</body>
</html>
"""
#endif
