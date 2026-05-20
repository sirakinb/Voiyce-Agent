#if VOIYCE_PRO
import Foundation
import InsForge
import InsForgeAuth

@MainActor
@Observable
final class VideoDBAgentMemory {
    static let shared = VideoDBAgentMemory()

    private let client = InsForgeClientProvider.shared
    private var captureProcess: Process?
    private var stdoutTask: Task<Void, Never>?
    private var stderrTask: Task<Void, Never>?
    private var privacyMonitorTask: Task<Void, Never>?
    private var activeEventStore: AgentEventStore?
    private var localCaptureStoppedBeforeBackendStop = false
    private var indexedStreamIDs = Set<String>()
    private var appSupportURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL.appendingPathComponent("Voiyce-Agent", isDirectory: true)
    }
    private var captureRuntimeURL: URL {
        appSupportURL.appendingPathComponent("videodb-capture", isDirectory: true)
    }
    private var capturePythonURL: URL {
        captureRuntimeURL.appendingPathComponent("venv/bin/python")
    }

    private(set) var status: VideoDBMemoryStatus = .idle
    private(set) var sessionID: String?
    private(set) var displayStreamID: String?
    private(set) var micStreamID: String?
    private(set) var sceneIndexID: String?
    private(set) var lastEvent: String = "Session context is idle."
    private(set) var lastError: String?

    var isRunning: Bool {
        if case .running = status { return true }
        if case .starting = status { return true }
        return false
    }

    @discardableResult
    func start() async -> AgentToolResult {
        await start(privacyStore: .shared, contextSnapshot: .current(), eventStore: .shared)
    }

    @discardableResult
    func start(
        privacyStore: AgentLongTermMemoryStore,
        contextSnapshot: AgentSessionContextSnapshot
    ) async -> AgentToolResult {
        await start(privacyStore: privacyStore, contextSnapshot: contextSnapshot, eventStore: .shared)
    }

    @discardableResult
    func start(
        privacyStore: AgentLongTermMemoryStore,
        contextSnapshot: AgentSessionContextSnapshot,
        eventStore: AgentEventStore
    ) async -> AgentToolResult {
        if let pausedResult = await pauseIfSessionContextBlocked(
            privacyStore: privacyStore,
            contextSnapshot: contextSnapshot,
            eventStore: eventStore
        ) {
            return pausedResult
        }

        guard !isRunning else { return currentToolResult() }

        status = .starting
        lastError = nil
        lastEvent = "Starting session context capture..."
        sessionID = nil
        displayStreamID = nil
        micStreamID = nil
        sceneIndexID = nil
        indexedStreamIDs.removeAll()
        localCaptureStoppedBeforeBackendStop = false

        do {
            let response = try await requestBackend(
                VideoDBBackendRequest(action: "create", sessionID: nil, displayStreamID: nil, micStreamID: nil, sceneIndexID: nil, query: nil)
            )
            guard let sessionID = response.sessionID, let token = response.clientToken else {
                throw VideoDBMemoryError.invalidBackendResponse
            }

            self.sessionID = sessionID
            try await ensureCaptureRuntime()
            try launchCaptureProcess(sessionID: sessionID, clientToken: token)
            status = .running
            lastEvent = "Session context is recording this Agent session."
            activeEventStore = eventStore
            logSessionContextStarted(sessionID: sessionID, eventStore: eventStore)
            startPrivacyMonitor(privacyStore: privacyStore, eventStore: eventStore)
        } catch {
            status = .failed
            lastError = Self.userFacingSessionContextMessage(error.localizedDescription)
            lastEvent = "Session context could not start."
            logSessionContextFailed(message: lastError ?? lastEvent, eventStore: eventStore)
            return AgentToolResult(
                ok: false,
                message: lastError ?? lastEvent,
                data: currentStateData(nextStep: Self.sessionContextNextStep)
            )
        }

        return currentToolResult()
    }

    func stop() async {
        await stop(eventStore: activeEventStore ?? .shared)
    }

    func stop(eventStore: AgentEventStore) async {
        guard isRunning || captureProcess != nil || sessionID != nil else { return }

        let stoppedSessionID = sessionID
        status = .stopping
        lastEvent = "Stopping session context..."

        privacyMonitorTask?.cancel()
        privacyMonitorTask = nil
        captureProcess?.terminate()
        captureProcess = nil
        stdoutTask?.cancel()
        stderrTask?.cancel()
        stdoutTask = nil
        stderrTask = nil

        if let sessionID {
            _ = try? await requestBackend(
                VideoDBBackendRequest(action: "stop", sessionID: sessionID, displayStreamID: nil, micStreamID: nil, sceneIndexID: nil, query: nil)
            )
        }

        status = .idle
        lastEvent = "Session context stopped."
        sessionID = nil
        displayStreamID = nil
        micStreamID = nil
        sceneIndexID = nil
        activeEventStore = nil
        if !localCaptureStoppedBeforeBackendStop {
            logSessionContextStopped(sessionID: stoppedSessionID, eventStore: eventStore)
        }
        localCaptureStoppedBeforeBackendStop = false
    }

    func stopLocalCaptureForUserStop(eventStore: AgentEventStore? = nil) {
        guard isRunning || captureProcess != nil || privacyMonitorTask != nil else { return }

        stopLocalCaptureRuntime(
            startingEvent: "Stopping session context because the Agent session stopped...",
            stoppedEvent: "Session context capture stopped. Preparing the session summary...",
            clearsSessionIDs: false
        )
        localCaptureStoppedBeforeBackendStop = true
        logSessionContextStopped(sessionID: sessionID, eventStore: eventStore ?? activeEventStore ?? .shared)
    }

    func stopLocalCaptureForTermination(eventStore: AgentEventStore? = nil) {
        stopLocalCapture(
            startingEvent: "Stopping session context because Voiyce is quitting...",
            stoppedEvent: "Session context stopped because Voiyce quit.",
            eventStore: eventStore ?? .shared
        )
    }

    func stopLocalCaptureForSystemSleep(eventStore: AgentEventStore? = nil) {
        stopLocalCapture(
            startingEvent: "Stopping session context because the Mac is going to sleep...",
            stoppedEvent: "Session context stopped because the Mac went to sleep.",
            eventStore: eventStore ?? .shared
        )
    }

    private func stopLocalCapture(
        startingEvent: String,
        stoppedEvent: String,
        eventStore: AgentEventStore
    ) {
        guard isRunning || captureProcess != nil || sessionID != nil || privacyMonitorTask != nil else { return }

        let stoppedSessionID = sessionID
        stopLocalCaptureRuntime(startingEvent: startingEvent, stoppedEvent: stoppedEvent, clearsSessionIDs: true)
        logSessionContextStopped(sessionID: stoppedSessionID, eventStore: eventStore)
    }

    private func stopLocalCaptureRuntime(
        startingEvent: String,
        stoppedEvent: String,
        clearsSessionIDs: Bool
    ) {
        status = .stopping
        lastEvent = startingEvent

        privacyMonitorTask?.cancel()
        privacyMonitorTask = nil
        captureProcess?.terminate()
        captureProcess = nil
        stdoutTask?.cancel()
        stderrTask?.cancel()
        stdoutTask = nil
        stderrTask = nil

        status = clearsSessionIDs ? .idle : .stopping
        lastEvent = stoppedEvent
        if clearsSessionIDs {
            sessionID = nil
            displayStreamID = nil
            micStreamID = nil
            sceneIndexID = nil
            activeEventStore = nil
            localCaptureStoppedBeforeBackendStop = false
        }
    }

    func search(_ query: String) async -> AgentToolResult {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AgentToolResult(
                ok: false,
                message: "Ask with a specific Session context search query.",
                data: currentStateData(nextStep: AgentToolRecoveryCopy.missingDetailNextStep)
            )
        }

        guard let displayStreamID, let sceneIndexID else {
            return AgentToolResult(
                ok: false,
                message: "Session context is not ready yet. Keep the Agent active for a few more seconds, then try again.",
                data: currentStateData()
            )
        }

        do {
            let response = try await requestBackend(
                VideoDBBackendRequest(
                    action: "search",
                    sessionID: sessionID,
                    displayStreamID: displayStreamID,
                    micStreamID: micStreamID,
                    sceneIndexID: sceneIndexID,
                    query: query
                )
            )

            return AgentToolResult(
                ok: true,
                message: response.summary ?? "Searched this session's context.",
                data: response.data ?? currentStateData()
            )
        } catch {
            return AgentToolResult(
                ok: false,
                message: "Session context search failed: \(Self.userFacingSessionContextMessage(error.localizedDescription))",
                data: currentStateData(nextStep: Self.sessionContextNextStep)
            )
        }
    }

    func summarize() async -> AgentToolResult {
        guard displayStreamID != nil || micStreamID != nil else {
            return AgentToolResult(
                ok: false,
                message: "Session context has not received screen or microphone context yet.",
                data: currentStateData(nextStep: "Keep the Agent active for a few more seconds, then try again.")
            )
        }

        do {
            let response = try await requestBackend(
                VideoDBBackendRequest(
                    action: "summary",
                    sessionID: sessionID,
                    displayStreamID: displayStreamID,
                    micStreamID: micStreamID,
                    sceneIndexID: sceneIndexID,
                    query: nil
                )
            )

            return AgentToolResult(
                ok: true,
                message: response.summary ?? "Summarized this session's context.",
                data: response.data ?? currentStateData()
            )
        } catch {
            return AgentToolResult(
                ok: false,
                message: "Session context summary failed: \(Self.userFacingSessionContextMessage(error.localizedDescription))",
                data: currentStateData(nextStep: Self.sessionContextNextStep)
            )
        }
    }

    func currentToolResult() -> AgentToolResult {
        AgentToolResult(ok: isRunning, message: lastEvent, data: currentStateData())
    }

    private func pauseIfSessionContextBlocked(
        privacyStore: AgentLongTermMemoryStore,
        contextSnapshot: AgentSessionContextSnapshot,
        eventStore: AgentEventStore
    ) async -> AgentToolResult? {
        guard let blockReason = privacyStore.liveSessionContextBlockReason(for: contextSnapshot) else {
            return nil
        }

        let shouldLogPause = lastEvent != blockReason
        if isRunning || captureProcess != nil || sessionID != nil {
            await stop(eventStore: eventStore)
        }
        status = .idle
        lastError = nil
        lastEvent = blockReason
        if shouldLogPause {
            logSessionContextPaused(reason: blockReason, contextSnapshot: contextSnapshot, eventStore: eventStore)
        }
        return AgentToolResult(
            ok: false,
            message: lastEvent,
            data: currentStateData(nextStep: Self.sessionContextPausedNextStep)
        )
    }

    private func startPrivacyMonitor(privacyStore: AgentLongTermMemoryStore, eventStore: AgentEventStore) {
        privacyMonitorTask?.cancel()
        privacyMonitorTask = Task { @MainActor [weak self, weak privacyStore, weak eventStore] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, let self, let privacyStore, let eventStore, self.isRunning else { return }

                let contextSnapshot = AgentSessionContextSnapshot.current()
                if await self.pauseIfSessionContextBlocked(
                    privacyStore: privacyStore,
                    contextSnapshot: contextSnapshot,
                    eventStore: eventStore
                ) != nil {
                    return
                }
            }
        }
    }

    private func logSessionContextStarted(sessionID: String, eventStore: AgentEventStore) {
        eventStore.append(
            category: .memory,
            status: .done,
            symbol: "record.circle",
            title: "Session context capture started",
            summary: "Voiyce started recording active session context.",
            details: [
                AgentLogEventDetail(key: "Session", value: sessionID)
            ]
        )
    }

    private func logSessionContextStopped(sessionID: String?, eventStore: AgentEventStore) {
        eventStore.append(
            category: .memory,
            status: .done,
            symbol: "stop.circle",
            title: "Session context capture stopped",
            summary: "Voiyce stopped active session context capture.",
            details: [
                AgentLogEventDetail(key: "Session", value: sessionID ?? "Not available")
            ]
        )
    }

    private func logSessionContextFailed(message: String, eventStore: AgentEventStore) {
        eventStore.append(
            category: .errors,
            status: .failed,
            symbol: "exclamationmark.triangle",
            title: "Session context capture failed",
            summary: message,
            details: [
                AgentLogEventDetail(key: "Feature", value: "Session context"),
                AgentLogEventDetail(key: "Next step", value: "Try again, then contact support if it keeps happening.")
            ]
        )
    }

    private func logSessionContextPaused(
        reason: String,
        contextSnapshot: AgentSessionContextSnapshot,
        eventStore: AgentEventStore
    ) {
        eventStore.append(
            category: .memory,
            status: .cancelled,
            symbol: "hand.raised",
            title: "Session context paused",
            summary: reason,
            details: [
                AgentLogEventDetail(
                    key: "App/site",
                    value: contextSnapshot.displayName.isEmpty ? "Not available" : contextSnapshot.displayName
                )
            ]
        )
    }

    #if DEBUG
    func seedRunningSessionForTesting(
        sessionID: String,
        displayStreamID: String? = nil,
        micStreamID: String? = nil,
        sceneIndexID: String? = nil,
        eventStore: AgentEventStore
    ) {
        status = .running
        self.sessionID = sessionID
        self.displayStreamID = displayStreamID
        self.micStreamID = micStreamID
        self.sceneIndexID = sceneIndexID
        activeEventStore = eventStore
        lastEvent = "Session context is recording this Agent session."
    }
    #endif

    private func launchCaptureProcess(sessionID: String, clientToken: String) throws {
        guard captureProcess == nil else { return }

        removeStaleCaptureLocks()

        let process = Process()
        process.executableURL = capturePythonURL
        process.arguments = ["-u", "-c", Self.captureScript]

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        environment["VIDEODB_CAPTURE_SESSION_ID"] = sessionID
        environment["VIDEODB_CLIENT_TOKEN"] = clientToken
        environment["NO_PROXY"] = "*"
        environment["no_proxy"] = "*"
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        stdoutTask = readPipe(stdout, isError: false)
        stderrTask = readPipe(stderr, isError: true)

        try process.run()
        captureProcess = process

        process.terminationHandler = { terminatedProcess in
            Task { @MainActor [weak self] in
                guard let self, self.captureProcess === terminatedProcess else { return }
                self.captureProcess = nil
                if self.status == .running {
                    self.status = terminatedProcess.terminationStatus == 0 ? .idle : .failed
                    if terminatedProcess.terminationStatus != 0 {
                        if self.lastError == nil {
                            self.lastError = "Session context helper exited with status \(terminatedProcess.terminationStatus)."
                        }
                    }
                }
            }
        }
    }

    private func removeStaleCaptureLocks() {
        guard captureProcess == nil else { return }
        for path in ["/tmp/capture.lock", "/private/tmp/capture.lock"] {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    private func ensureCaptureRuntime() async throws {
        try FileManager.default.createDirectory(at: captureRuntimeURL, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: capturePythonURL.path),
           try await canImportVideoDBCapture() {
            return
        }

        lastEvent = "Installing session context capture support..."
        try await runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["python3", "-m", "venv", captureRuntimeURL.appendingPathComponent("venv").path]
        )
        lastEvent = "Updating session context capture support..."
        try await runProcess(
            executableURL: capturePythonURL,
            arguments: ["-m", "pip", "install", "--upgrade", "pip"]
        )
        lastEvent = "Installing session context capture support..."
        try await runProcess(
            executableURL: capturePythonURL,
            arguments: ["-m", "pip", "install", "videodb[capture]"]
        )

        guard try await canImportVideoDBCapture() else {
            throw VideoDBMemoryError.captureRuntimeUnavailable("Session context capture support installed, but could not be loaded.")
        }
    }

    private func canImportVideoDBCapture() async throws -> Bool {
        do {
            try await runProcess(
                executableURL: capturePythonURL,
                arguments: ["-c", "from videodb.capture import CaptureClient"]
            )
            return true
        } catch {
            return false
        }
    }

    private func runProcess(executableURL: URL, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments
            process.environment = ProcessInfo.processInfo.environment.merging(
                ["PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"],
                uniquingKeysWith: { _, newValue in newValue }
            )

            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { completedProcess in
                if completedProcess.terminationStatus == 0 {
                    continuation.resume()
                    return
                }

                continuation.resume(throwing: VideoDBMemoryError.captureRuntimeUnavailable(
                    "Command failed with status \(completedProcess.terminationStatus)."
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func readPipe(_ pipe: Pipe, isError: Bool) -> Task<Void, Never> {
        Task { [weak self] in
            do {
                for try await line in pipe.fileHandleForReading.bytes.lines {
                    self?.handleCaptureOutput(line, isError: isError)
                }
            } catch {
                self?.handleCaptureOutput(
                    "Session context capture logging stopped. Restart the Agent if live context stops updating.",
                    isError: true
                )
            }
        }
    }

    private func handleCaptureOutput(_ line: String, isError: Bool) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let data = trimmed.data(using: .utf8),
           let event = try? JSONDecoder().decode(VideoDBCaptureEvent.self, from: data) {
            handleCaptureEvent(event)
            return
        }

        if isError {
            let message = Self.userFacingSessionContextMessage(trimmed)
            lastError = message
            lastEvent = message
            return
        }

        lastEvent = Self.userFacingSessionContextMessage(trimmed)
    }

    private func handleCaptureEvent(_ event: VideoDBCaptureEvent) {
        if event.event == "error", let message = event.payload?.message {
            let userMessage = Self.userFacingSessionContextMessage(message)
            lastError = userMessage
            lastEvent = userMessage
            return
        }

        if let payload = event.payload {
            assignStreamIDs(from: payload)
        }

        switch event.event {
        case "dependency_missing":
            let message = Self.userFacingSessionContextMessage(
                event.payload?.message ?? "Session context capture support is missing. Contact support, then reconnect the Agent."
            )
            lastError = message
            lastEvent = message
        case "permission_warning":
            lastEvent = "Session context is waiting for Microphone and Screen Recording permission."
        case "capture_starting":
            lastEvent = "Session context capture is starting."
        case "capture_started":
            lastEvent = "Session context is recording this Agent session."
        case "recording-complete":
            lastEvent = "Session context finished recording this Agent session."
        default:
            lastEvent = "Session context is receiving screen and audio context."
        }
    }

    private func assignStreamIDs(from payload: VideoDBCaptureEvent.Payload) {
        let streamID = payload.rtstreamID ?? payload.streamID ?? payload.id
        guard let streamID, streamID.hasPrefix("rts-") else { return }

        let channelText = [
            payload.channelID,
            payload.channelName,
            payload.name,
            payload.type
        ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if channelText.contains("display") || channelText.contains("screen") || channelText.contains("video") {
            displayStreamID = streamID
            startIndexIfNeeded(streamID: streamID, isDisplay: true)
        } else if channelText.contains("mic") || channelText.contains("audio") {
            micStreamID = streamID
            startIndexIfNeeded(streamID: streamID, isDisplay: false)
        }
    }

    private func startIndexIfNeeded(streamID: String, isDisplay: Bool) {
        guard !indexedStreamIDs.contains(streamID) else { return }
        indexedStreamIDs.insert(streamID)

        Task {
            do {
                let response = try await requestBackend(
                    VideoDBBackendRequest(
                        action: isDisplay ? "start_scene_index" : "start_transcription",
                        sessionID: sessionID,
                        displayStreamID: isDisplay ? streamID : nil,
                        micStreamID: isDisplay ? nil : streamID,
                        sceneIndexID: nil,
                        query: nil
                    )
                )

                if isDisplay, let sceneIndexID = response.sceneIndexID {
                    self.sceneIndexID = sceneIndexID
                }
            } catch {
                lastError = Self.userFacingSessionContextMessage(error.localizedDescription)
            }
        }
    }

    private func requestBackend(_ payload: VideoDBBackendRequest) async throws -> VideoDBBackendResponse {
        guard let session = try await client.auth.getSession() else {
            throw VideoDBMemoryError.authenticationRequired
        }

        let body = try JSONEncoder().encode(payload)
        var request = URLRequest(
            url: AppConstants.insForgeBaseURL
                .appendingPathComponent("functions")
                .appendingPathComponent("videodb-session")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        var (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VideoDBMemoryError.invalidBackendResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            let refreshed = try await client.auth.refreshAccessToken()
            guard let accessToken = refreshed.accessToken else {
                throw VideoDBMemoryError.authenticationRequired
            }

            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            (data, response) = try await URLSession.shared.data(for: request)
            guard let refreshedResponse = response as? HTTPURLResponse else {
                throw VideoDBMemoryError.invalidBackendResponse
            }

            return try decodeBackendResponse(data: data, response: refreshedResponse)
        }

        return try decodeBackendResponse(data: data, response: httpResponse)
    }

    private func decodeBackendResponse(data: Data, response httpResponse: HTTPURLResponse) throws -> VideoDBBackendResponse {
        if (200..<300).contains(httpResponse.statusCode) {
            return try JSONDecoder().decode(VideoDBBackendResponse.self, from: data)
        }

        let error = (try? JSONDecoder().decode(VideoDBBackendError.self, from: data).error)
            ?? String(decoding: data, as: UTF8.self)
        throw VideoDBMemoryError.backend("HTTP \(httpResponse.statusCode): \(error)")
    }

    nonisolated static func userFacingSessionContextMessage(_ message: String) -> String {
        var sanitized = message
        let lowerMessage = message.lowercased()

        if lowerMessage.contains("insufficient credit") || lowerMessage.contains("payment required") {
            return "Session context capture is temporarily unavailable because the connected capture account needs attention. Contact support, then reconnect the Agent."
        }

        let replacements = [
            "VideoDB session memory": "Session context",
            "VideoDB screen and audio memory": "Session context capture",
            "VideoDB screen memory": "Session context",
            "VideoDB memory": "Session context",
            "VideoDB capture runtime": "Session context capture support",
            "VideoDB capture support": "Session context capture support",
            "VideoDB capture package": "Session context capture support",
            "VideoDB capture": "Session context capture",
            "VideoDB account": "Session context service account",
            "VideoDB rejected capture": "Session context capture was rejected",
            "VideoDB backend": "Session context service",
            "videodb.capture": "session context capture support",
            "videodb[capture]": "session context capture support",
            "VideoDB": "Session context service"
        ]

        for (providerTerm, userFacingTerm) in replacements {
            sanitized = sanitized.replacingOccurrences(of: providerTerm, with: userFacingTerm)
        }

        sanitized = sanitized
            .replacingOccurrences(of: "Session context service capture package", with: "Session context capture support")
            .replacingOccurrences(of: "Session context capture package", with: "Session context capture support")
            .replacingOccurrences(of: "session context capture package", with: "session context capture support")

        let forbiddenTerms = [
            "http",
            "backend",
            "server",
            "api",
            "token",
            "secret",
            "authorization",
            "traceback",
            "stack trace",
            "key",
            "clienttoken",
            "rts-"
        ]

        if forbiddenTerms.contains(where: { sanitized.localizedCaseInsensitiveContains($0) }) {
            return "Session context capture could not finish. Check your connection and permissions, then restart the Agent."
        }

        return sanitized
    }

    private static let sessionContextNextStep = "Restart the Agent. If it keeps failing, export Agent Log and send it to support."
    private static let sessionContextPausedNextStep = "Adjust Private Mode, app/site exclusions, or the current sensitive screen, then start Context again."

    private func currentStateData(nextStep: String? = nil) -> [String: String] {
        var data = [
            "memory_source": "session_context",
            "context_scope": "active_session",
            "context_kind": "screen_and_audio",
            "status": status.rawValue,
            "session_id": sessionID ?? "",
            "display_stream_id": displayStreamID ?? "",
            "mic_stream_id": micStreamID ?? "",
            "scene_index_id": sceneIndexID ?? "",
            "last_event": lastEvent,
            "last_error": lastError ?? ""
        ]
        if let nextStep, !nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["next_step"] = nextStep
        }
        return data
    }

    private static let captureScript = #"""
import asyncio
import json
import os
import sys

session_id = os.environ["VIDEODB_CAPTURE_SESSION_ID"]
client_token = os.environ["VIDEODB_CLIENT_TOKEN"]

def emit(event, payload=None):
    print(json.dumps({"event": event, "payload": jsonable(payload or {})}), flush=True)

def jsonable(value):
    try:
        json.dumps(value)
        return value
    except Exception:
        if hasattr(value, "__dict__"):
            return {key: jsonable(item) for key, item in value.__dict__.items() if not key.startswith("_")}
        return str(value)

def error_message(exc):
    value = str(exc)
    if "Insufficient credit" in value:
        return "Session context capture is temporarily unavailable because the connected capture account needs attention. Contact support, then reconnect the Agent."
    if "Payment Required" in value:
        return "Session context capture is temporarily unavailable because the connected capture account needs attention. Contact support, then reconnect the Agent."
    if "Permission denied" in value or "PERMISSION_DENIED" in value:
        return "Session context capture needs Microphone and Screen Recording permission."
    return value

async def main():
    os.environ["NO_PROXY"] = "*"
    os.environ["no_proxy"] = "*"

    try:
        from videodb.capture import CaptureClient
    except Exception as exc:
        emit("dependency_missing", {"message": "Session context capture support is missing. Contact support, then reconnect the Agent.", "error": str(exc)})
        return 86

    try:
        client = CaptureClient(client_token=client_token)
    except TypeError:
        client = CaptureClient(session_token=client_token)

    try:
        for permission in ("microphone", "screen_capture"):
            try:
                await asyncio.wait_for(client.request_permission(permission), timeout=8)
            except Exception as exc:
                emit("permission_warning", {"permission": permission, "message": str(exc)})

        channels = await asyncio.wait_for(client.list_channels(), timeout=12)
        mic = getattr(getattr(channels, "mics", None), "default", None)
        displays = getattr(channels, "displays", None)
        display = getattr(displays, "primary", None) or getattr(displays, "default", None) if displays is not None else None
        if display is None:
            try:
                display = displays[0]
            except Exception:
                try:
                    display = displays[1]
                except Exception:
                    display = None
        system_audio = getattr(getattr(channels, "system_audio", None), "default", None)
        selected = [channel for channel in (mic, display, system_audio) if channel]

        if display is None:
            emit("error", {"message": "Session context could not see an available display. Grant Screen Recording permission, then reconnect the Agent."})
            return 2

        for channel in selected:
            try:
                channel.store = True
            except Exception:
                pass
        try:
            display.is_primary = True
        except Exception:
            pass

        primary_id = getattr(display, "id", None) or getattr(display, "name", None) if display else None
        emit("capture_starting", {"session_id": session_id, "primary_video_channel_id": primary_id})
        await asyncio.wait_for(
            client.start_session(
                capture_session_id=session_id,
                channels=selected,
                primary_video_channel_id=primary_id
            ),
            timeout=20
        )
        emit("capture_started", {"session_id": session_id})

        async for ev in client.events():
            if isinstance(ev, dict):
                event_name = ev.get("event") or ev.get("type") or "event"
                payload = ev.get("payload") or ev.get("result") or ev
            else:
                event_name = getattr(ev, "event", "event")
                payload = getattr(ev, "payload", {})
            emit(event_name, payload)
            if event_name in ("recording-complete", "error"):
                break
    except Exception as exc:
        emit("error", {"message": error_message(exc), "detail": str(exc)})
        return 1
    finally:
        try:
            await client.stop_session()
        except Exception:
            pass
        try:
            await client.shutdown()
        except Exception:
            pass
    return 0

if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
"""#

    static var captureScriptForTesting: String {
        captureScript
    }
}

enum VideoDBMemoryStatus: String {
    case idle
    case starting
    case running
    case stopping
    case failed
}

private enum VideoDBMemoryError: LocalizedError {
    case authenticationRequired
    case invalidBackendResponse
    case backend(String)
    case captureRuntimeUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Sign in to Voiyce before starting session context."
        case .invalidBackendResponse:
            return "Session context received an unexpected response. Try again, then contact support if it keeps happening."
        case .backend(let message):
            return VideoDBAgentMemory.userFacingSessionContextMessage(message)
        case .captureRuntimeUnavailable(let message):
            return "Session context capture is unavailable: \(VideoDBAgentMemory.userFacingSessionContextMessage(message))"
        }
    }
}

private struct VideoDBBackendRequest: Encodable {
    let action: String
    let sessionID: String?
    let displayStreamID: String?
    let micStreamID: String?
    let sceneIndexID: String?
    let query: String?
}

private struct VideoDBBackendResponse: Decodable {
    let ok: Bool
    let sessionID: String?
    let clientToken: String?
    let displayStreamID: String?
    let micStreamID: String?
    let sceneIndexID: String?
    let summary: String?
    let data: [String: String]?
}

private struct VideoDBBackendError: Decodable {
    let error: String
}

private struct VideoDBCaptureEvent: Decodable {
    let event: String
    let payload: Payload?

    struct Payload: Decodable {
        let id: String?
        let rtstreamID: String?
        let streamID: String?
        let channelID: String?
        let channelName: String?
        let name: String?
        let type: String?
        let message: String?

        enum CodingKeys: String, CodingKey {
            case id
            case rtstreamID = "rtstream_id"
            case streamID = "stream_id"
            case channelID = "channel_id"
            case channelName = "channel_name"
            case name
            case type
            case message
        }
    }
}
#endif
