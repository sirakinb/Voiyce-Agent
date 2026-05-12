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
    private(set) var lastEvent: String = "VideoDB memory is idle."
    private(set) var lastError: String?

    var isRunning: Bool {
        if case .running = status { return true }
        if case .starting = status { return true }
        return false
    }

    func start() async {
        guard !isRunning else { return }

        status = .starting
        lastError = nil
        lastEvent = "Starting VideoDB screen and audio memory..."
        indexedStreamIDs.removeAll()

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
            lastEvent = "VideoDB memory is recording this agent session."
        } catch {
            status = .failed
            lastError = error.localizedDescription
            lastEvent = "VideoDB memory could not start."
        }
    }

    func stop() async {
        guard isRunning || captureProcess != nil || sessionID != nil else { return }

        status = .stopping
        lastEvent = "Stopping VideoDB memory..."

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
        lastEvent = "VideoDB memory stopped."
    }

    func search(_ query: String) async -> AgentToolResult {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AgentToolResult(ok: false, message: "query is required.", data: nil)
        }

        guard let displayStreamID, let sceneIndexID else {
            return AgentToolResult(
                ok: false,
                message: "VideoDB session memory is not indexed yet. Keep the agent active for a few more seconds, then try again.",
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
                message: response.summary ?? "Searched VideoDB session memory.",
                data: response.data ?? currentStateData()
            )
        } catch {
            return AgentToolResult(ok: false, message: "VideoDB memory search failed: \(error.localizedDescription)", data: currentStateData())
        }
    }

    func summarize() async -> AgentToolResult {
        guard displayStreamID != nil || micStreamID != nil else {
            return AgentToolResult(
                ok: false,
                message: "VideoDB memory has not received stream context yet.",
                data: currentStateData()
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
                message: response.summary ?? "Summarized VideoDB session memory.",
                data: response.data ?? currentStateData()
            )
        } catch {
            return AgentToolResult(ok: false, message: "VideoDB memory summary failed: \(error.localizedDescription)", data: currentStateData())
        }
    }

    func currentToolResult() -> AgentToolResult {
        AgentToolResult(ok: isRunning, message: lastEvent, data: currentStateData())
    }

    private func launchCaptureProcess(sessionID: String, clientToken: String) throws {
        guard captureProcess == nil else { return }

        let process = Process()
        process.executableURL = capturePythonURL
        process.arguments = ["-u", "-c", Self.captureScript]

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        environment["VIDEODB_CAPTURE_SESSION_ID"] = sessionID
        environment["VIDEODB_CLIENT_TOKEN"] = clientToken
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
                        self.lastError = "VideoDB capture helper exited with status \(terminatedProcess.terminationStatus)."
                    }
                }
            }
        }
    }

    private func ensureCaptureRuntime() async throws {
        try FileManager.default.createDirectory(at: captureRuntimeURL, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: capturePythonURL.path),
           try await canImportVideoDBCapture() {
            return
        }

        lastEvent = "Installing VideoDB capture runtime..."
        try await runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["python3", "-m", "venv", captureRuntimeURL.appendingPathComponent("venv").path]
        )
        lastEvent = "Updating VideoDB capture runtime..."
        try await runProcess(
            executableURL: capturePythonURL,
            arguments: ["-m", "pip", "install", "--upgrade", "pip"]
        )
        lastEvent = "Installing VideoDB capture support..."
        try await runProcess(
            executableURL: capturePythonURL,
            arguments: ["-m", "pip", "install", "videodb[capture]"]
        )

        guard try await canImportVideoDBCapture() else {
            throw VideoDBMemoryError.captureRuntimeUnavailable("VideoDB capture package installed, but videodb.capture could not be imported.")
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
                self?.handleCaptureOutput("VideoDB capture log stream ended: \(error.localizedDescription)", isError: true)
            }
        }
    }

    private func handleCaptureOutput(_ line: String, isError: Bool) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if isError {
            lastError = trimmed
            lastEvent = trimmed
            return
        }

        lastEvent = trimmed

        guard let data = trimmed.data(using: .utf8),
              let event = try? JSONDecoder().decode(VideoDBCaptureEvent.self, from: data) else {
            return
        }

        if let payload = event.payload {
            assignStreamIDs(from: payload)
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
                lastError = error.localizedDescription
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

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VideoDBMemoryError.invalidBackendResponse
        }

        if (200..<300).contains(httpResponse.statusCode) {
            return try JSONDecoder().decode(VideoDBBackendResponse.self, from: data)
        }

        let error = (try? JSONDecoder().decode(VideoDBBackendError.self, from: data).error)
            ?? String(decoding: data, as: UTF8.self)
        throw VideoDBMemoryError.backend("HTTP \(httpResponse.statusCode): \(error)")
    }

    private func currentStateData() -> [String: String] {
        [
            "status": status.rawValue,
            "session_id": sessionID ?? "",
            "display_stream_id": displayStreamID ?? "",
            "mic_stream_id": micStreamID ?? "",
            "scene_index_id": sceneIndexID ?? "",
            "last_event": lastEvent,
            "last_error": lastError ?? ""
        ]
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

async def main():
    try:
        from videodb.capture import CaptureClient
    except Exception as exc:
        emit("dependency_missing", {"message": "Install VideoDB capture support with: python3 -m pip install 'videodb[capture]'", "error": str(exc)})
        return 86

    try:
        client = CaptureClient(client_token=client_token)
    except TypeError:
        client = CaptureClient(session_token=client_token)

    try:
        for permission in ("microphone", "screen_capture", "screen"):
            try:
                await client.request_permission(permission)
            except Exception:
                pass

        channels = await client.list_channels()
        mic = getattr(getattr(channels, "mics", None), "default", None)
        displays = getattr(channels, "displays", None)
        display = getattr(displays, "primary", None) or getattr(displays, "default", None)
        if display is None:
            try:
                display = displays[1]
            except Exception:
                try:
                    display = displays[0]
                except Exception:
                    display = None
        system_audio = getattr(getattr(channels, "system_audio", None), "default", None)
        selected = [channel for channel in (mic, display, system_audio) if channel]

        if not selected:
            emit("error", {"message": "No VideoDB capture channels were available."})
            return 2

        primary_id = getattr(display, "name", None) or getattr(display, "id", None) if display else None
        emit("capture_starting", {"session_id": session_id, "primary_video_channel_id": primary_id})
        await client.start_session(
            capture_session_id=session_id,
            channels=selected,
            primary_video_channel_id=primary_id
        )
        emit("capture_started", {"session_id": session_id})

        async for ev in client.events():
            event_name = getattr(ev, "event", "event")
            payload = getattr(ev, "payload", {})
            emit(event_name, payload)
            if event_name in ("recording-complete", "error"):
                break
    except Exception as exc:
        emit("error", {"message": str(exc)})
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
            return "Authentication is required before VideoDB memory can start."
        case .invalidBackendResponse:
            return "VideoDB backend returned an invalid response."
        case .backend(let message):
            return message
        case .captureRuntimeUnavailable(let message):
            return "VideoDB capture runtime is unavailable: \(message)"
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

        enum CodingKeys: String, CodingKey {
            case id
            case rtstreamID = "rtstream_id"
            case streamID = "stream_id"
            case channelID = "channel_id"
            case channelName = "channel_name"
            case name
            case type
        }
    }
}
#endif
