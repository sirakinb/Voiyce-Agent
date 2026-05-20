#if VOIYCE_PRO
import Foundation
import SwiftUI

enum AgentLogCategory: String, CaseIterable, Codable, Identifiable {
    case all
    case voice
    case actions
    case memory
    case errors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .voice: "Voice"
        case .actions: "Actions"
        case .memory: "Memory"
        case .errors: "Issues"
        }
    }

    var tint: Color {
        switch self {
        case .all: AppTheme.textSecondary
        case .voice: AppTheme.accent
        case .actions: Color(hex: 0xF8C04E)
        case .memory: Color(hex: 0x4DD3FF)
        case .errors: AppTheme.destructive
        }
    }
}

enum AgentLogStatus: String, Codable {
    case done
    case waiting
    case failed
    case cancelled

    var title: String {
        switch self {
        case .done: "Done"
        case .waiting: "Waiting"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    var tint: Color {
        switch self {
        case .done: AppTheme.success
        case .waiting: Color(hex: 0xF8C04E)
        case .failed: AppTheme.destructive
        case .cancelled: AppTheme.textSecondary
        }
    }
}

struct AgentLogEventDetail: Codable, Identifiable, Hashable {
    let id: UUID
    let key: String
    let value: String

    init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

struct AgentLogEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let category: AgentLogCategory
    let symbol: String
    let title: String
    let summary: String
    let status: AgentLogStatus
    let details: [AgentLogEventDetail]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: AgentLogCategory,
        symbol: String,
        title: String,
        summary: String,
        status: AgentLogStatus,
        details: [AgentLogEventDetail] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.symbol = symbol
        self.title = title
        self.summary = summary
        self.status = status
        self.details = details
    }

    var time: String {
        Self.timeFormatter.string(from: timestamp)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

@MainActor
@Observable
final class AgentEventStore {
    static let shared = AgentEventStore(storageDirectory: AgentEventStore.defaultStorageDirectory())

    private(set) var events: [AgentLogEvent] = []
    private let maximumEvents = 500
    private let storageDirectory: URL
    private let fileURL: URL

    init(storageDirectory: URL) {
        try? FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true
        )

        self.storageDirectory = storageDirectory
        fileURL = storageDirectory.appendingPathComponent("agent-events.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            events = []
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let loadedEvents = (try? decoder.decode([AgentLogEvent].self, from: data)) ?? []
        let redactedEvents = loadedEvents.map(Self.redactedForLogStorage)
        events = redactedEvents

        if redactedEvents != loadedEvents {
            save()
        }
    }

    func append(
        category: AgentLogCategory,
        status: AgentLogStatus,
        symbol: String,
        title: String,
        summary: String,
        details: [AgentLogEventDetail] = []
    ) {
        let event = Self.redactedForLogStorage(AgentLogEvent(
            category: category,
            symbol: symbol,
            title: title,
            summary: summary,
            status: status,
            details: details
        ))

        events.insert(event, at: 0)
        if events.count > maximumEvents {
            events.removeLast(events.count - maximumEvents)
        }

        save()
    }

    func appendPermissionBlock(
        feature: String,
        permission: String,
        message: String,
        nextStep: String? = nil
    ) {
        var details = [
            AgentLogEventDetail(key: "Feature", value: feature),
            AgentLogEventDetail(key: "Permission", value: permission)
        ]

        if let nextStep, !nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details.append(AgentLogEventDetail(key: "Next step", value: nextStep))
        }

        append(
            category: .errors,
            status: .failed,
            symbol: "lock.trianglebadge.exclamationmark",
            title: "Permission blocked",
            summary: "\(feature): \(message)",
            details: details
        )
    }

    func appendServiceFailure(
        feature: String,
        service: String,
        statusCode: Int? = nil,
        message: String,
        nextStep: String? = nil
    ) {
        let cleanedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        var details = [
            AgentLogEventDetail(key: "Feature", value: feature),
            AgentLogEventDetail(key: "Service", value: service)
        ]

        if let statusCode {
            details.append(AgentLogEventDetail(key: "Upstream status", value: "HTTP \(statusCode)"))
        }

        if let nextStep, !nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details.append(AgentLogEventDetail(key: "Next step", value: nextStep))
        }

        let isQuotaOrRateLimit = statusCode == 429
            || statusCode == 402
            || cleanedMessage.localizedCaseInsensitiveContains("quota")
            || cleanedMessage.localizedCaseInsensitiveContains("rate limit")
            || cleanedMessage.localizedCaseInsensitiveContains("rate-limit")
            || cleanedMessage.localizedCaseInsensitiveContains("usage limit")
            || cleanedMessage.localizedCaseInsensitiveContains("usage cap")

        append(
            category: .errors,
            status: .failed,
            symbol: isQuotaOrRateLimit ? "speedometer" : "exclamationmark.triangle",
            title: isQuotaOrRateLimit ? "Quota or rate limit" : "\(service) failed",
            summary: "\(feature): \(cleanedMessage.isEmpty ? "\(service) failed." : cleanedMessage)",
            details: details
        )
    }

    func appendActSafetyCheckStopped(
        message: String,
        checks: [AgentLogEventDetail],
        nextStep: String
    ) {
        let cleanedNextStep = nextStep.trimmingCharacters(in: .whitespacesAndNewlines)
        var details = checks

        if !cleanedNextStep.isEmpty {
            details.append(AgentLogEventDetail(key: "Next step", value: cleanedNextStep))
        }

        append(
            category: .actions,
            status: .failed,
            symbol: "shield",
            title: "Act mode safety check stopped",
            summary: message,
            details: details
        )
    }

    func appendMemoryError(
        operation: String,
        message: String,
        path: String? = nil,
        nextStep: String? = nil
    ) {
        let cleanedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        var details = [
            AgentLogEventDetail(key: "Operation", value: operation)
        ]

        if let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details.append(AgentLogEventDetail(key: "Path", value: path))
        }

        if let nextStep, !nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details.append(AgentLogEventDetail(key: "Next step", value: nextStep))
        }

        append(
            category: .errors,
            status: .failed,
            symbol: "externaldrive.badge.exclamationmark",
            title: "Memory error",
            summary: "\(operation): \(cleanedMessage.isEmpty ? "Memory operation failed." : cleanedMessage)",
            details: details
        )
    }

    func clear() {
        events = []
        save()
    }

    func exportSupportBundle() -> URL? {
        let supportDirectory = storageDirectory.appendingPathComponent("Support", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

        let url = supportDirectory.appendingPathComponent("voiyce-agent-support-\(Self.fileDateFormatter.string(from: Date())).json")
        let bundle = AgentSupportBundle(
            schemaVersion: AgentSupportBundleSchema.version,
            bundleKind: AgentSupportBundleSchema.kind,
            exportedAt: Date(),
            eventCount: events.count,
            events: events.map { event in
                AgentSupportEvent(
                    id: event.id.uuidString,
                    timestamp: event.timestamp,
                    category: event.category.rawValue,
                    status: event.status.rawValue,
                    title: Self.redactedForSupport(event.title),
                    summary: Self.redactedForSupport(event.summary),
                    details: event.details.map { Self.redactedSupportDetail($0) }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(bundle) else {
            return nil
        }

        do {
            try data.write(to: url, options: .atomic)
            append(
                category: .memory,
                status: .done,
                symbol: "square.and.arrow.up",
                title: "Support log exported",
                summary: "Redacted support log exported.",
                details: [AgentLogEventDetail(key: "Path", value: url.path)]
            )
            return url
        } catch {
            append(
                category: .errors,
                status: .failed,
                symbol: "exclamationmark.triangle",
                title: "Support log export failed",
                summary: "Voiyce could not write the support log. Check disk space and folder permissions, then try again."
            )
            return nil
        }
    }

    var todayEvents: [AgentLogEvent] {
        events.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    nonisolated static func redactedForSupport(_ value: String) -> String {
        var redacted = value
        let patterns = [
            (#"(?i)data:image/[a-z0-9.+-]+;base64,[A-Za-z0-9+/=\r\n]{24,}"#, "[redacted-image]"),
            (#"sk-proj-[A-Za-z0-9_\-]{12,}"#, "[redacted]"),
            (#"sk-[A-Za-z0-9_\-]{12,}"#, "[redacted]"),
            (#"(?i)bearer\s+[A-Za-z0-9_\-\.]{12,}"#, "[redacted]"),
            (#"(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, "[redacted]"),
            (#"[A-Za-z0-9+/]{160,}={0,2}"#, "[redacted-blob]")
        ]

        for (pattern, replacement) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(redacted.startIndex..<redacted.endIndex, in: redacted)
            redacted = regex.stringByReplacingMatches(
                in: redacted,
                options: [],
                range: range,
                withTemplate: replacement
            )
        }

        return redacted
    }

    private static func redactedSupportDetail(_ detail: AgentLogEventDetail) -> AgentSupportEventDetail {
        AgentSupportEventDetail(
            key: redactedForSupport(detail.key),
            value: redactedDetailValue(key: detail.key, value: detail.value)
        )
    }

    private static func redactedForLogStorage(_ event: AgentLogEvent) -> AgentLogEvent {
        AgentLogEvent(
            id: event.id,
            timestamp: event.timestamp,
            category: event.category,
            symbol: event.symbol,
            title: redactedForSupport(event.title),
            summary: redactedForSupport(event.summary),
            status: event.status,
            details: event.details.map { redactedLogDetail($0) }
        )
    }

    private static func redactedLogDetail(_ detail: AgentLogEventDetail) -> AgentLogEventDetail {
        AgentLogEventDetail(
            id: detail.id,
            key: redactedForSupport(detail.key),
            value: redactedDetailValue(key: detail.key, value: detail.value)
        )
    }

    private static func redactedDetailValue(key: String, value: String) -> String {
        if shouldRedactDetailValue(for: key) {
            return "[redacted]"
        }

        return redactedForSupport(value)
    }

    private static func shouldRedactDetailValue(for key: String) -> Bool {
        let normalizedKey = key.lowercased().filter { $0.isLetter || $0.isNumber }
        let sensitiveContextMarkers = [
            "transcript",
            "dictation",
            "spokentext",
            "audiotext",
            "screenshot",
            "screencapture",
            "image",
            "imagebase64",
            "base64",
            "rawscreen",
            "rawimage",
            "rawcontext"
        ]

        return sensitiveContextMarkers.contains { normalizedKey.contains($0) }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(events) else {
            return
        }

        try? data.write(to: fileURL, options: .atomic)
    }

    private static func defaultStorageDirectory() -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("Voiyce-Agent", isDirectory: true)

        let fallbackDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("Voiyce-Agent", isDirectory: true)

        return directory ?? fallbackDirectory
    }

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private enum AgentSupportBundleSchema {
    static let version = 1
    static let kind = "voiyce-agent-support-log"
}

private struct AgentSupportBundle: Encodable {
    let schemaVersion: Int
    let bundleKind: String
    let exportedAt: Date
    let eventCount: Int
    let events: [AgentSupportEvent]
}

private struct AgentSupportEvent: Encodable {
    let id: String
    let timestamp: Date
    let category: String
    let status: String
    let title: String
    let summary: String
    let details: [AgentSupportEventDetail]
}

private struct AgentSupportEventDetail: Encodable {
    let key: String
    let value: String
}
#endif
