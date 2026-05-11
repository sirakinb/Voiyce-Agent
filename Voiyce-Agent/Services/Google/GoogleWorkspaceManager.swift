import AppKit
import CryptoKit
import Foundation
import Security

@MainActor
@Observable
final class GoogleWorkspaceManager {
    static let shared = GoogleWorkspaceManager()

    private let tokenServiceName = "\(AppConstants.keychainServiceName).google"
    private let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    private let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!

    var connectedEmail: String?
    var isConnecting = false
    var infoMessage: String?
    var errorMessage: String?

    var clientID: String {
        AppConstants.googleOAuthClientID
    }

    var clientSecret: String {
        AppConstants.googleOAuthClientSecret
    }

    var isConfigured: Bool {
        !clientID.isEmpty
    }

    var isConnected: Bool {
        storedToken?.refreshToken?.isEmpty == false
    }

    private init() {
        connectedEmail = storedToken?.email
    }

    func connect() async {
        guard isConfigured else {
            errorMessage = "Google OAuth is not configured for this build yet."
            return
        }

        isConnecting = true
        infoMessage = nil
        errorMessage = nil
        defer { isConnecting = false }

        do {
            let verifier = Self.randomURLSafeString(byteCount: 48)
            let challenge = Self.codeChallenge(for: verifier)
            let state = Self.randomURLSafeString(byteCount: 24)
            let callback = try await OAuthLoopbackReceiver.start(expectedState: state)
            defer { callback.stop() }

            var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "redirect_uri", value: callback.redirectURI),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: AppConstants.googleOAuthScopes.joined(separator: " ")),
                URLQueryItem(name: "access_type", value: "offline"),
                URLQueryItem(name: "prompt", value: "consent"),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "state", value: state)
            ]

            guard let authURL = components.url else {
                throw GoogleWorkspaceError.invalidOAuthURL
            }

            NSWorkspace.shared.open(authURL)
            infoMessage = "Continue in your browser to connect Google."

            let code = try await callback.waitForCode()
            let token = try await exchangeCodeForToken(
                code: code,
                verifier: verifier,
                redirectURI: callback.redirectURI
            )
            let email = try await fetchGoogleEmail(accessToken: token.accessToken)
            let stored = GoogleOAuthToken(
                accessToken: token.accessToken,
                refreshToken: token.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(token.expiresIn)),
                email: email
            )
            try saveToken(stored)
            connectedEmail = email
            infoMessage = "Google connected: \(email)"
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func disconnect() {
        KeychainManager.delete(key: AppConstants.googleOAuthTokenKey, service: tokenServiceName)
        connectedEmail = nil
        infoMessage = "Google disconnected."
        errorMessage = nil
    }

    func readGmail(query: String, limit: Int) async -> AgentToolResult {
        do {
            let token = try await validAccessToken()
            var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
            components.queryItems = [
                URLQueryItem(name: "maxResults", value: String(max(1, min(limit, 10)))),
                query.isEmpty ? nil : URLQueryItem(name: "q", value: query)
            ].compactMap { $0 }

            let list: GmailMessageList = try await googleJSONRequest(url: components.url!, accessToken: token)
            let messages = try await list.messages.prefix(max(1, min(limit, 10))).asyncMap { message in
                try await fetchGmailMessage(id: message.id, accessToken: token)
            }

            let summary = messages.isEmpty
                ? "No matching Gmail messages found."
                : messages.map { "\($0.from) | \($0.subject) | \($0.snippet)" }.joined(separator: "\n")
            return AgentToolResult(ok: true, message: summary, data: ["count": String(messages.count)])
        } catch {
            return AgentToolResult(ok: false, message: friendlyMessage(for: error), data: ["requires": "google_oauth"])
        }
    }

    func draftGmail(recipient: String, subject: String, body: String) async -> AgentToolResult {
        do {
            let token = try await validAccessToken()
            let raw = Self.base64URLEncoded(Self.emailMessage(recipient: recipient, subject: subject, body: body))
            let payload = GmailDraftCreateRequest(message: GmailRawMessage(raw: raw))
            let data = try JSONEncoder().encode(payload)
            var request = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/drafts")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            let draft: GmailDraftResponse = try await sendJSONRequest(request)
            return AgentToolResult(
                ok: true,
                message: "Created Gmail draft for \(recipient). It has not been sent.",
                data: ["draft_id": draft.id, "recipient": recipient, "sent": "false"]
            )
        } catch {
            return AgentToolResult(ok: false, message: friendlyMessage(for: error), data: ["requires": "google_oauth"])
        }
    }

    func sendGmail(recipient: String, subject: String, body: String) async -> AgentToolResult {
        do {
            let token = try await validAccessToken()
            let raw = Self.base64URLEncoded(Self.emailMessage(recipient: recipient, subject: subject, body: body))
            let data = try JSONEncoder().encode(GmailRawMessage(raw: raw))
            var request = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            let response: GmailSendResponse = try await sendJSONRequest(request)
            return AgentToolResult(
                ok: true,
                message: "Sent Gmail message to \(recipient).",
                data: ["message_id": response.id, "recipient": recipient, "sent": "true"]
            )
        } catch {
            return AgentToolResult(ok: false, message: friendlyMessage(for: error), data: ["requires": "google_oauth"])
        }
    }

    func checkCalendar(date: Date, durationMinutes: Int) async -> AgentToolResult {
        do {
            let token = try await validAccessToken()
            let end = date.addingTimeInterval(TimeInterval(max(durationMinutes, 1) * 60))
            let payload = GoogleFreeBusyRequest(
                timeMin: Self.isoDateFormatter.string(from: date),
                timeMax: Self.isoDateFormatter.string(from: end),
                items: [GoogleCalendarItem(id: "primary")]
            )
            let data = try JSONEncoder().encode(payload)
            var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/freeBusy")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data
            let response: GoogleFreeBusyResponse = try await sendJSONRequest(request)
            let busy = response.calendars["primary"]?.busy ?? []
            let formatter = userFacingDateTimeFormatter()
            return AgentToolResult(
                ok: true,
                message: busy.isEmpty
                    ? "\(formatter.string(from: date)) is available."
                    : "\(formatter.string(from: date)) has \(busy.count) conflict(s).",
                data: ["available": String(busy.isEmpty), "conflict_count": String(busy.count)]
            )
        } catch {
            return AgentToolResult(ok: false, message: friendlyMessage(for: error), data: ["requires": "google_oauth"])
        }
    }

    func readCalendar(day: Date, limit: Int) async -> AgentToolResult {
        do {
            let token = try await validAccessToken()
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: day)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
            var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
            components.queryItems = [
                URLQueryItem(name: "timeMin", value: Self.isoDateFormatter.string(from: start)),
                URLQueryItem(name: "timeMax", value: Self.isoDateFormatter.string(from: end)),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
                URLQueryItem(name: "maxResults", value: String(max(1, min(limit, 20))))
            ]
            let response: GoogleEventsResponse = try await googleJSONRequest(url: components.url!, accessToken: token)
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            timeFormatter.dateStyle = .none
            let events = response.items.prefix(max(1, min(limit, 20))).map { event in
                "\(timeFormatter.string(from: event.start.dateValue)) \(event.summary ?? "Untitled")"
            }
            return AgentToolResult(
                ok: true,
                message: events.isEmpty ? "No Google Calendar events found for that day." : events.joined(separator: "\n"),
                data: ["event_count": String(events.count)]
            )
        } catch {
            return AgentToolResult(ok: false, message: friendlyMessage(for: error), data: ["requires": "google_oauth"])
        }
    }

    private var storedToken: GoogleOAuthToken? {
        guard let value = KeychainManager.retrieve(key: AppConstants.googleOAuthTokenKey, service: tokenServiceName),
              let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(GoogleOAuthToken.self, from: data)
    }

    private func saveToken(_ token: GoogleOAuthToken) throws {
        let data = try JSONEncoder().encode(token)
        guard let value = String(data: data, encoding: .utf8) else {
            throw GoogleWorkspaceError.invalidToken
        }
        try KeychainManager.save(key: AppConstants.googleOAuthTokenKey, value: value, service: tokenServiceName)
    }

    private func validAccessToken() async throws -> String {
        guard var token = storedToken else {
            throw GoogleWorkspaceError.notConnected
        }

        if token.expiresAt.timeIntervalSinceNow > 90 {
            return token.accessToken
        }

        guard let refreshToken = token.refreshToken, !refreshToken.isEmpty else {
            throw GoogleWorkspaceError.notConnected
        }

        let refreshed = try await refreshAccessToken(refreshToken)
        token.accessToken = refreshed.accessToken
        token.expiresAt = Date().addingTimeInterval(TimeInterval(refreshed.expiresIn))
        try saveToken(token)
        return token.accessToken
    }

    private func exchangeCodeForToken(code: String, verifier: String, redirectURI: String) async throws -> GoogleTokenResponse {
        var fields = [
            "code": code,
            "client_id": clientID,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        if !clientSecret.isEmpty {
            fields["client_secret"] = clientSecret
        }
        return try await tokenRequest(fields)
    }

    private func refreshAccessToken(_ refreshToken: String) async throws -> GoogleTokenResponse {
        var fields = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        if !clientSecret.isEmpty {
            fields["client_secret"] = clientSecret
        }
        return try await tokenRequest(fields)
    }

    private func tokenRequest(_ fields: [String: String]) async throws -> GoogleTokenResponse {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formURLEncoded(fields).data(using: .utf8)
        return try await sendJSONRequest(request)
    }

    private func fetchGoogleEmail(accessToken: String) async throws -> String {
        let profile: GmailProfile = try await googleJSONRequest(
            url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/profile")!,
            accessToken: accessToken
        )
        return profile.emailAddress
    }

    private func fetchGmailMessage(id: String, accessToken: String) async throws -> GmailMessageSummary {
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)")!
        components.queryItems = [
            URLQueryItem(name: "format", value: "metadata"),
            URLQueryItem(name: "metadataHeaders", value: "From"),
            URLQueryItem(name: "metadataHeaders", value: "Subject"),
            URLQueryItem(name: "metadataHeaders", value: "Date")
        ]
        let message: GmailMessageResponse = try await googleJSONRequest(url: components.url!, accessToken: accessToken)
        return GmailMessageSummary(
            from: message.header("From"),
            subject: message.header("Subject"),
            snippet: message.snippet
        )
    }

    private func googleJSONRequest<T: Decodable>(url: URL, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await sendJSONRequest(request)
    }

    private func sendJSONRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleWorkspaceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = String(decoding: data, as: UTF8.self)
            throw GoogleWorkspaceError.apiError(http.statusCode, payload)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func userFacingDateTimeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    private func friendlyMessage(for error: Error) -> String {
        if let error = error as? GoogleWorkspaceError {
            return error.localizedDescription
        }
        return error.localizedDescription
    }

    private static func emailMessage(recipient: String, subject: String, body: String) -> String {
        [
            "To: \(recipient)",
            "Subject: \(subject)",
            "Content-Type: text/plain; charset=\"UTF-8\"",
            "",
            body
        ].joined(separator: "\r\n")
    }

    private static func base64URLEncoded(_ value: String) -> String {
        Data(value.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formURLEncoded(_ fields: [String: String]) -> String {
        fields.map { key, value in
            "\(urlEncode(key))=\(urlEncode(value))"
        }.joined(separator: "&")
    }

    private static func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private final class OAuthLoopbackReceiver {
    let redirectURI: String
    private let socketFD: Int32
    private let expectedState: String
    private let queue = DispatchQueue(label: "business.voiyce.google-oauth-callback")
    private var continuation: CheckedContinuation<String, Error>?
    private var completed = false

    private init(socketFD: Int32, redirectURI: String, expectedState: String) {
        self.socketFD = socketFD
        self.redirectURI = redirectURI
        self.expectedState = expectedState
    }

    static func start(expectedState: String) async throws -> OAuthLoopbackReceiver {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            throw GoogleWorkspaceError.oauthCallbackUnavailable
        }

        var reuse = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(socketFD)
            throw GoogleWorkspaceError.oauthCallbackUnavailable
        }

        guard listen(socketFD, 1) == 0 else {
            close(socketFD)
            throw GoogleWorkspaceError.oauthCallbackUnavailable
        }

        var boundAddress = sockaddr_in()
        var boundLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socketFD, $0, &boundLength)
            }
        }
        guard nameResult == 0 else {
            close(socketFD)
            throw GoogleWorkspaceError.oauthCallbackUnavailable
        }

        let port = UInt16(bigEndian: boundAddress.sin_port)
        let receiver = OAuthLoopbackReceiver(
            socketFD: socketFD,
            redirectURI: "http://127.0.0.1:\(port)/oauth/google/callback",
            expectedState: expectedState
        )
        receiver.startAccepting()
        return receiver
    }

    func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func stop() {
        close(socketFD)
    }

    private func startAccepting() {
        queue.async { [weak self] in
            guard let self else { return }
            while !self.completed {
                let clientFD = accept(self.socketFD, nil, nil)
                guard clientFD >= 0 else { return }
                self.handle(clientFD)
                close(clientFD)
            }
        }
    }

    private func handle(_ clientFD: Int32) {
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        let count = read(clientFD, &buffer, buffer.count)
        guard count > 0, let text = String(bytes: buffer.prefix(count), encoding: .utf8) else {
            return
        }

        let requestLine = text.components(separatedBy: "\r\n").first ?? ""
        let path = requestLine.split(separator: " ").dropFirst().first.map(String.init) ?? ""
        let url = URL(string: "http://127.0.0.1\(path)")
        let components = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let items = components?.queryItems ?? []
        let code = items.first(where: { $0.name == "code" })?.value
        let state = items.first(where: { $0.name == "state" })?.value
        let error = items.first(where: { $0.name == "error" })?.value

        let body: String
        if let error {
            body = "Google connection failed: \(error)"
            finish(.failure(GoogleWorkspaceError.apiError(400, error)))
        } else if state != expectedState {
            body = "Google connection failed: invalid state."
            finish(.failure(GoogleWorkspaceError.invalidOAuthState))
        } else if let code {
            body = "Google is connected. You can return to Voiyce."
            finish(.success(code))
        } else {
            body = "Google connection failed: missing code."
            finish(.failure(GoogleWorkspaceError.missingOAuthCode))
        }

        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        _ = response.withCString { pointer in
            write(clientFD, pointer, strlen(pointer))
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard !completed else { return }
        completed = true
        switch result {
        case .success(let code):
            continuation?.resume(returning: code)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}

enum GoogleWorkspaceError: LocalizedError {
    case invalidOAuthURL
    case oauthCallbackUnavailable
    case invalidOAuthState
    case missingOAuthCode
    case notConnected
    case invalidToken
    case invalidResponse
    case apiError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidOAuthURL:
            "Could not create the Google OAuth URL."
        case .oauthCallbackUnavailable:
            "Could not start the local Google OAuth callback server."
        case .invalidOAuthState:
            "Google OAuth returned an invalid state."
        case .missingOAuthCode:
            "Google OAuth did not return an authorization code."
        case .notConnected:
            "Google is not connected. Open Settings and connect Google first."
        case .invalidToken:
            "The stored Google token could not be read."
        case .invalidResponse:
            "Google returned an invalid response."
        case .apiError(let status, let payload):
            "Google API \(status): \(payload)"
        }
    }
}

struct GoogleOAuthToken: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var email: String?
}

private struct GoogleTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct GmailProfile: Decodable {
    let emailAddress: String
}

private struct GmailMessageList: Decodable {
    let messages: [GmailMessageReference]
}

private struct GmailMessageReference: Decodable {
    let id: String
}

private struct GmailMessageResponse: Decodable {
    let snippet: String
    let payload: GmailPayload?

    func header(_ name: String) -> String {
        payload?.headers.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })?.value ?? ""
    }
}

private struct GmailPayload: Decodable {
    let headers: [GmailHeader]
}

private struct GmailHeader: Decodable {
    let name: String
    let value: String
}

private struct GmailMessageSummary {
    let from: String
    let subject: String
    let snippet: String
}

private struct GmailRawMessage: Codable {
    let raw: String
}

private struct GmailDraftCreateRequest: Codable {
    let message: GmailRawMessage
}

private struct GmailDraftResponse: Decodable {
    let id: String
}

private struct GmailSendResponse: Decodable {
    let id: String
}

private struct GoogleFreeBusyRequest: Encodable {
    let timeMin: String
    let timeMax: String
    let items: [GoogleCalendarItem]
}

private struct GoogleCalendarItem: Codable {
    let id: String
}

private struct GoogleFreeBusyResponse: Decodable {
    let calendars: [String: GoogleBusyCalendar]
}

private struct GoogleBusyCalendar: Decodable {
    let busy: [GoogleBusyBlock]
}

private struct GoogleBusyBlock: Decodable {
    let start: String
    let end: String
}

private struct GoogleEventsResponse: Decodable {
    let items: [GoogleCalendarEvent]
}

private struct GoogleCalendarEvent: Decodable {
    let summary: String?
    let start: GoogleEventDate
}

private struct GoogleEventDate: Decodable {
    let dateTime: String?
    let date: String?

    var dateValue: Date {
        if let dateTime, let parsed = ISO8601DateFormatter().date(from: dateTime) {
            return parsed
        }
        if let date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: date) ?? Date()
        }
        return Date()
    }
}

private extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var values: [T] = []
        for element in self {
            try await values.append(transform(element))
        }
        return values
    }
}
