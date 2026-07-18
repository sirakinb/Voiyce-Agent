#if VOIYCE_PRO
import AppKit
import ApplicationServices
import Foundation

struct AgentMemoryRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let source: String
    let summary: String
    let searchableText: String
    let tags: [String]
    let appHint: String?
    let screenshotPath: String?
    let vaultNotePath: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: String,
        summary: String,
        searchableText: String,
        tags: [String],
        appHint: String?,
        screenshotPath: String?,
        vaultNotePath: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.summary = summary
        self.searchableText = searchableText
        self.tags = tags
        self.appHint = appHint
        self.screenshotPath = screenshotPath
        self.vaultNotePath = vaultNotePath
    }
}

struct AgentMemoryUsageSnapshot: Equatable {
    let recordCount: Int
    let capturesToday: Int
    let screenshotCount: Int
    let screenshotBytes: Int
    let vaultNoteCount: Int
    let vaultNoteBytes: Int
    let indexBytes: Int

    var totalStorageBytes: Int {
        screenshotBytes + vaultNoteBytes + indexBytes
    }

    var toolData: [String: String] {
        [
            "memory_record_count": "\(recordCount)",
            "memory_captures_today": "\(capturesToday)",
            "memory_screenshot_count": "\(screenshotCount)",
            "memory_screenshot_bytes": "\(screenshotBytes)",
            "memory_vault_note_count": "\(vaultNoteCount)",
            "memory_vault_note_bytes": "\(vaultNoteBytes)",
            "memory_index_bytes": "\(indexBytes)",
            "memory_total_storage_bytes": "\(totalStorageBytes)"
        ]
    }
}

struct AgentMemoryStorageQuota: Equatable {
    let maxRecords: Int
    let maxScreenshotBytes: Int
    let maxTotalStorageBytes: Int
}

enum AgentMemoryStorageTier: String, CaseIterable, Codable, Identifiable {
    case defaultTier = "default"
    case pro
    case power

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultTier: "Default"
        case .pro: "Pro"
        case .power: "Power"
        }
    }

    var quota: AgentMemoryStorageQuota {
        switch self {
        case .defaultTier:
            AgentMemoryStorageQuota(
                maxRecords: 250,
                maxScreenshotBytes: 25 * 1024 * 1024,
                maxTotalStorageBytes: 50 * 1024 * 1024
            )
        case .pro:
            AgentMemoryStorageQuota(
                maxRecords: 2_500,
                maxScreenshotBytes: 250 * 1024 * 1024,
                maxTotalStorageBytes: 500 * 1024 * 1024
            )
        case .power:
            AgentMemoryStorageQuota(
                maxRecords: 10_000,
                maxScreenshotBytes: 1024 * 1024 * 1024,
                maxTotalStorageBytes: 2 * 1024 * 1024 * 1024
            )
        }
    }
}

enum AgentMemoryRetention: String, CaseIterable, Codable, Identifiable {
    case sessionOnly
    case thirtyDays
    case ninetyDays
    case forever

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sessionOnly: "Session only"
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .forever: "Forever"
        }
    }

    var subtitle: String {
        switch self {
        case .sessionOnly: "Do not keep long-term memory after quitting."
        case .thirtyDays: "Keep summaries for one month."
        case .ninetyDays: "Keep summaries for three months."
        case .forever: "Keep summaries until you delete them."
        }
    }

    var retentionInterval: TimeInterval? {
        switch self {
        case .sessionOnly: 0
        case .thirtyDays: 30 * 24 * 60 * 60
        case .ninetyDays: 90 * 24 * 60 * 60
        case .forever: nil
        }
    }
}

enum AgentScreenshotRetention: String, CaseIterable, Codable, Identifiable {
    case off
    case thirtyDays
    case ninetyDays
    case forever

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .forever: "Forever"
        }
    }

    var subtitle: String {
        switch self {
        case .off: "Keep summaries only. Raw screenshots are not saved."
        case .thirtyDays: "Keep raw screenshots for one month when useful."
        case .ninetyDays: "Keep raw screenshots for three months when useful."
        case .forever: "Keep raw screenshots until you delete them."
        }
    }

    var retentionInterval: TimeInterval? {
        switch self {
        case .off: 0
        case .thirtyDays: 30 * 24 * 60 * 60
        case .ninetyDays: 90 * 24 * 60 * 60
        case .forever: nil
        }
    }
}

struct AgentSessionContextSnapshot: Equatable {
    let appName: String?
    let bundleIdentifier: String?
    let windowTitle: String?
    let url: String?

    var displayName: String {
        [appName, windowTitle, url]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
    }

    var searchableText: String {
        [appName, bundleIdentifier, windowTitle, url]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
    }

    static func current() -> AgentSessionContextSnapshot {
        let app = NSWorkspace.shared.frontmostApplication
        let windowTitle = app.flatMap { focusedWindowTitle(for: $0.processIdentifier) }
        return AgentSessionContextSnapshot(
            appName: app?.localizedName,
            bundleIdentifier: app?.bundleIdentifier,
            windowTitle: windowTitle,
            url: nil
        )
    }

    private static func focusedWindowTitle(for processIdentifier: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let focusedWindow,
           let windowElement = axElement(from: focusedWindow),
           let title = copyStringAttribute(windowElement, kAXTitleAttribute),
           !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }

        var windows: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows) == .success,
              let windowElements = windows as? [AXUIElement] else {
            return nil
        }

        return windowElements
            .compactMap { copyStringAttribute($0, kAXTitleAttribute) }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func axElement(from value: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let element = value as! AXUIElement
        return element
    }

    private static func copyStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }
}

@MainActor
@Observable
final class AgentLongTermMemoryStore {
    static let shared = AgentLongTermMemoryStore(
        storageDirectory: AgentLongTermMemoryStore.defaultStorageDirectory(),
        userDefaults: .standard,
        createVaultOnInit: false,
        eventStore: .shared
    )

    private static let vaultPathDefaultsKey = "agentMemoryVaultPath"
    private static let memoryRetentionDefaultsKey = "agentMemoryRetention"
    private static let screenshotRetentionDefaultsKey = "agentScreenshotRetention"
    private static let storageTierDefaultsKey = "agentMemoryStorageTier"
    private static let vaultSyncEnabledDefaultsKey = "agentMemoryVaultSyncEnabled"
    private static let privateModeDefaultsKey = "agentMemoryPrivateMode"
    private static let exclusionsDefaultsKey = "agentMemoryExcludedPatterns"
    private static let legacyVaultName = "Voiyce Memory"
    private static let signedOutScopeName = "SignedOut"
    private static let accountsDirectoryName = "Accounts"
    private static let sensitiveCapturePatterns = [
        "1password", "lastpass", "bitwarden", "dashlane", "password",
        "bank", "banking", "credit card", "ssn", "social security",
        "health", "medical", "private browsing", "incognito"
    ]
    private let userDefaults: UserDefaults
    private let baseStorageDirectory: URL
    private var storageDirectory: URL
    private var recordsURL: URL
    private var screenshotsDirectory: URL
    private let eventStore: AgentEventStore
    private let maximumSearchResults = 8
    private let createVaultOnAccountConfigure: Bool
    private var currentUserID: String?
    private var isConfiguringAccount = false
    var storageQuotaOverride: AgentMemoryStorageQuota?

    private(set) var records: [AgentMemoryRecord] = []
    private(set) var lastStatus: String = "Memory ready."
    var storageTier: AgentMemoryStorageTier {
        didSet {
            userDefaults.set(storageTier.rawValue, forKey: scopedDefaultsKey(Self.storageTierDefaultsKey))
            guard !isConfiguringAccount else { return }
            lastStatus = "Memory storage tier set to \(storageTier.title)."
            logPrivacySettingChanged("Memory storage tier", value: storageTier.title)
        }
    }
    var memoryRetention: AgentMemoryRetention {
        didSet {
            userDefaults.set(memoryRetention.rawValue, forKey: scopedDefaultsKey(Self.memoryRetentionDefaultsKey))
            guard !isConfiguringAccount else { return }
            if memoryRetention == .sessionOnly {
                deletePersistentIndex()
                deleteScreenshots()
                deleteVaultDailyNotes()
            } else {
                pruneExpiredRecords()
                save()
            }
            logPrivacySettingChanged("Summary retention", value: memoryRetention.title)
        }
    }
    var screenshotRetention: AgentScreenshotRetention {
        didSet {
            userDefaults.set(screenshotRetention.rawValue, forKey: scopedDefaultsKey(Self.screenshotRetentionDefaultsKey))
            guard !isConfiguringAccount else { return }
            pruneExpiredScreenshots()
            logPrivacySettingChanged("Screenshot retention", value: screenshotRetention.title)
        }
    }
    var isVaultSyncEnabled: Bool {
        didSet {
            userDefaults.set(isVaultSyncEnabled, forKey: scopedDefaultsKey(Self.vaultSyncEnabledDefaultsKey))
            guard !isConfiguringAccount else { return }
            lastStatus = isVaultSyncEnabled
                ? "Vault notes are on. New durable memories can be written as Markdown."
                : "Vault notes are off. New memories stay in the local index only."
            logPrivacySettingChanged("Vault notes", value: isVaultSyncEnabled ? "On" : "Off")
        }
    }
    var isPrivateModeEnabled: Bool {
        didSet {
            userDefaults.set(isPrivateModeEnabled, forKey: scopedDefaultsKey(Self.privateModeDefaultsKey))
            guard !isConfiguringAccount else { return }
            lastStatus = isPrivateModeEnabled
                ? "Private mode is on. Durable memory is paused."
                : "Private mode is off. Memory capture can resume."
            logPrivacySettingChanged("Private mode", value: isPrivateModeEnabled ? "On" : "Off")
        }
    }
    var excludedPatternsText: String {
        didSet {
            userDefaults.set(excludedPatternsText, forKey: scopedDefaultsKey(Self.exclusionsDefaultsKey))
            guard !isConfiguringAccount else { return }
            logPrivacySettingChanged("Memory exclusions", value: excludedPatterns.isEmpty ? "None" : "\(excludedPatterns.count) patterns")
        }
    }

    init(
        storageDirectory: URL,
        userDefaults: UserDefaults = .standard,
        createVaultOnInit: Bool = true,
        eventStore: AgentEventStore
    ) {
        self.userDefaults = userDefaults
        self.baseStorageDirectory = storageDirectory
        self.storageDirectory = storageDirectory
        self.eventStore = eventStore
        self.createVaultOnAccountConfigure = createVaultOnInit
        self.recordsURL = storageDirectory.appendingPathComponent("long-term-memory.json")
        self.screenshotsDirectory = storageDirectory.appendingPathComponent("Screenshots", isDirectory: true)
        storageTier = AgentMemoryStorageTier(
            rawValue: userDefaults.string(forKey: AppConstants.accountScopedKey(Self.storageTierDefaultsKey, userID: nil)) ?? ""
        ) ?? .defaultTier
        memoryRetention = AgentMemoryRetention(
            rawValue: userDefaults.string(forKey: AppConstants.accountScopedKey(Self.memoryRetentionDefaultsKey, userID: nil)) ?? ""
        ) ?? .ninetyDays
        screenshotRetention = AgentScreenshotRetention(
            rawValue: userDefaults.string(forKey: AppConstants.accountScopedKey(Self.screenshotRetentionDefaultsKey, userID: nil)) ?? ""
        ) ?? .off
        isVaultSyncEnabled = AgentLongTermMemoryStore.boolDefault(
            userDefaults,
            key: AppConstants.accountScopedKey(Self.vaultSyncEnabledDefaultsKey, userID: nil),
            defaultValue: true
        )
        isPrivateModeEnabled = userDefaults.bool(forKey: AppConstants.accountScopedKey(Self.privateModeDefaultsKey, userID: nil))
        excludedPatternsText = userDefaults.string(forKey: AppConstants.accountScopedKey(Self.exclusionsDefaultsKey, userID: nil)) ?? ""

        createDirectory(
            at: screenshotsDirectory,
            operation: "Create screenshot directory",
            nextStep: "Check disk access for the local Voiyce memory folder."
        )
        load()
        pruneExpiredRecords()
        pruneExpiredScreenshots()
        if createVaultOnInit {
            _ = ensureVault()
        }
    }

    var activeStorageDirectory: URL {
        storageDirectory
    }

    var activeAccountScopeDescription: String {
        currentUserID.map { "Account \($0)" } ?? "Signed out"
    }

    var activeAccountScopeValue: String {
        currentUserID == nil ? "signed_out" : "signed_in"
    }

    func configureForAccount(userID: String?) {
        let normalizedUserID = normalizedAccountID(userID)
        let scopedDirectory = storageDirectory(for: normalizedUserID)
        guard normalizedUserID != currentUserID || scopedDirectory.standardizedFileURL.path != storageDirectory.standardizedFileURL.path else {
            return
        }

        currentUserID = normalizedUserID
        storageDirectory = scopedDirectory
        recordsURL = storageDirectory.appendingPathComponent("long-term-memory.json")
        screenshotsDirectory = storageDirectory.appendingPathComponent("Screenshots", isDirectory: true)

        loadPrivacySettingsForCurrentAccount()
        createDirectory(
            at: screenshotsDirectory,
            operation: "Create screenshot directory",
            nextStep: "Check disk access for the local Voiyce memory folder."
        )
        load()
        pruneExpiredRecords()
        pruneExpiredScreenshots()

        if createVaultOnAccountConfigure, normalizedUserID != nil {
            _ = ensureVault()
        }

        lastStatus = normalizedUserID == nil
            ? "Memory ready for signed-out state."
            : "Memory ready for this account."
    }

    func configureStorageTier(_ tier: AgentMemoryStorageTier) {
        storageTier = tier
    }

    var vaultURL: URL? {
        guard let path = userDefaults.string(forKey: scopedDefaultsKey(Self.vaultPathDefaultsKey)), !path.isEmpty else {
            return nil
        }

        let url = URL(fileURLWithPath: path, isDirectory: true)
        if isLegacyDefaultVault(url), let migratedURL = migrateLegacyVaultIfPossible(from: url) {
            return migratedURL
        }

        return url
    }

    var memoryCountText: String {
        "\(records.count) memories"
    }

    var usageSnapshot: AgentMemoryUsageSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let capturesToday = records.filter { record in
            calendar.startOfDay(for: record.createdAt) == today
        }.count
        let screenshotURLs = existingFileURLs(
            records.compactMap(\.screenshotPath).map { URL(fileURLWithPath: $0) }
        )
        let vaultNoteURLs = existingFileURLs(
            Set(records.compactMap(\.vaultNotePath)).map { URL(fileURLWithPath: $0) }
        )

        return AgentMemoryUsageSnapshot(
            recordCount: records.count,
            capturesToday: capturesToday,
            screenshotCount: screenshotURLs.count,
            screenshotBytes: totalFileBytes(screenshotURLs),
            vaultNoteCount: vaultNoteURLs.count,
            vaultNoteBytes: totalFileBytes(vaultNoteURLs),
            indexBytes: fileByteCount(recordsURL)
        )
    }

    var privacySummary: String {
        if isPrivateModeEnabled {
            return "Private mode on. Durable memory is paused."
        }

        let exclusions = excludedPatterns.count
        return "Summaries: \(memoryRetention.title). Screenshots: \(screenshotRetention.title). Vault: \(isVaultSyncEnabled ? "On" : "Off"). Exclusions: \(exclusions)."
    }

    var excludedPatterns: [String] {
        excludedPatternsText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    func liveSessionContextBlockReason(for context: AgentSessionContextSnapshot) -> String? {
        if isPrivateModeEnabled {
            return "Private Mode is on, so live session context is paused."
        }

        let haystack = context.searchableText
        if let sensitive = Self.sensitiveCapturePatterns.first(where: { haystack.contains($0) }) {
            return "This screen looks sensitive (\(sensitive)), so live session context is paused."
        }

        if let excluded = excludedPatterns.first(where: { haystack.contains($0) }) {
            return "This matches your memory exclusion (\(excluded)), so live session context is paused."
        }

        return nil
    }

    @discardableResult
    func ensureVault() -> URL? {
        if let vaultURL {
            guard createDirectory(
                at: vaultURL,
                operation: "Create memory vault",
                nextStep: "Choose a writable vault folder in Settings."
            ) else {
                lastStatus = "Could not create memory vault at \(vaultURL.path)."
                return nil
            }
            return vaultURL
        }

        let vault = preferredObsidianMemoryURL()
            ?? legacyDefaultVaultURL()

        do {
            try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
            userDefaults.set(vault.path, forKey: scopedDefaultsKey(Self.vaultPathDefaultsKey))
            writeVaultReadmeIfNeeded(vault)
            lastStatus = "Created memory vault at \(vault.path)."
            return vault
        } catch {
            lastStatus = "Could not create memory vault. Choose a writable vault folder in Settings."
            appendMemoryError(
                operation: "Create memory vault",
                error: error,
                path: vault.path,
                nextStep: "Choose a writable vault folder in Settings."
            )
            return nil
        }
    }

    func setVault(url: URL) {
        guard createDirectory(
            at: url,
            operation: "Create memory vault",
            nextStep: "Choose a writable vault folder in Settings."
        ) else {
            lastStatus = "Could not create memory vault at \(url.path)."
            return
        }
        userDefaults.set(url.path, forKey: scopedDefaultsKey(Self.vaultPathDefaultsKey))
        writeVaultReadmeIfNeeded(url)
        lastStatus = "Using memory vault at \(url.path)."
    }

    func revealVault() {
        guard let vault = ensureVault() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([vault])
    }

    @discardableResult
    func addRecord(
        source: String,
        summary: String,
        searchableText: String = "",
        tags: [String] = [],
        appHint: String? = nil,
        rawScreenshotData: Data? = nil,
        createdAt: Date = Date()
    ) -> AgentToolResult {
        let cleanSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSummary.isEmpty else {
            return AgentToolResult(
                ok: false,
                message: "Memory summary is required.",
                data: longTermMemoryData(["next_step": AgentToolRecoveryCopy.missingDetailNextStep])
            )
        }

        let cleanText = searchableText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let blockReason = memoryBlockReason(source: source, summary: cleanSummary, searchableText: cleanText, appHint: appHint) {
            lastStatus = blockReason
            eventStore.append(
                category: .memory,
                status: .cancelled,
                symbol: "hand.raised",
                title: "Memory skipped",
                summary: blockReason,
                details: [
                    AgentLogEventDetail(key: "Source", value: source),
                    AgentLogEventDetail(key: "App/site", value: appHint ?? "Not provided")
                ]
            )
            return AgentToolResult(
                ok: true,
                message: blockReason,
                data: longTermMemoryData(["memory_skipped": "true"])
            )
        }

        let cleanTags = normalizedTags(tags.isEmpty ? inferredTags(from: cleanSummary + " " + cleanText) : tags)
        let shouldPersist = memoryRetention != .sessionOnly
        if shouldPersist, let storageBlockReason = durableMemoryStorageBlockReason() {
            lastStatus = storageBlockReason
            eventStore.append(
                category: .memory,
                status: .cancelled,
                symbol: "internaldrive",
                title: "Memory skipped",
                summary: storageBlockReason,
                details: [
                    AgentLogEventDetail(key: "Tier", value: storageTier.title),
                    AgentLogEventDetail(key: "Records", value: "\(usageSnapshot.recordCount)"),
                    AgentLogEventDetail(key: "Storage bytes", value: "\(usageSnapshot.totalStorageBytes)")
                ]
            )
            return AgentToolResult(
                ok: true,
                message: storageBlockReason,
                data: longTermMemoryData([
                    "memory_skipped": "true",
                    "memory_storage_limit_reached": "true",
                    "memory_storage_tier": storageTier.rawValue
                ])
            )
        }

        var screenshotStorageNote: String?
        let screenshotData = screenshotDataAllowedByStorageQuota(rawScreenshotData, note: &screenshotStorageNote)
        let screenshotPath = storeScreenshot(screenshotData)
        let notePath = shouldPersist ? appendVaultNote(
            source: source,
            summary: cleanSummary,
            searchableText: cleanText,
            tags: cleanTags,
            appHint: appHint,
            screenshotPath: screenshotPath,
            createdAt: createdAt
        ) : nil

        let record = AgentMemoryRecord(
            createdAt: createdAt,
            source: source,
            summary: cleanSummary,
            searchableText: cleanText,
            tags: cleanTags,
            appHint: appHint,
            screenshotPath: screenshotPath,
            vaultNotePath: notePath
        )

        records.insert(record, at: 0)
        if shouldPersist {
            pruneExpiredRecords()
            save()
            lastStatus = "Saved memory."
        } else {
            lastStatus = "Saved memory for this session only."
        }

        eventStore.append(
            category: .memory,
            status: .done,
            symbol: "brain",
            title: "Memory saved",
            summary: shouldPersist ? cleanSummary : "\(cleanSummary) (session only)",
            details: [
                AgentLogEventDetail(key: "Source", value: source),
                AgentLogEventDetail(key: "Retention", value: memoryRetention.title),
                AgentLogEventDetail(key: "Screenshot retention", value: screenshotRetention.title),
                AgentLogEventDetail(key: "Storage tier", value: storageTier.title),
                AgentLogEventDetail(key: "Screenshot", value: screenshotStorageNote ?? (screenshotPath == nil ? "Not written" : "Written")),
                AgentLogEventDetail(key: "Vault", value: notePath ?? "Not written"),
                AgentLogEventDetail(key: "Records", value: "\(usageSnapshot.recordCount)"),
                AgentLogEventDetail(key: "Storage bytes", value: "\(usageSnapshot.totalStorageBytes)")
            ]
        )

        return AgentToolResult(
            ok: true,
            message: "Saved that to local memory.",
            data: [
                "memory_id": record.id.uuidString,
                "vault_note": notePath ?? "",
                "tags": cleanTags.joined(separator: ", "),
                "memory_storage_tier": storageTier.rawValue,
                "memory_screenshot_skipped": screenshotStorageNote == nil ? "false" : "storage_limit"
            ]
            .merging(usageSnapshot.toolData) { current, _ in current }
            .merging(longTermMemoryData()) { current, _ in current }
        )
    }

    func search(_ query: String, limit: Int? = nil) -> AgentToolResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AgentToolResult(
                ok: false,
                message: "Ask with a specific saved-memory search query.",
                data: longTermMemoryData(["next_step": AgentToolRecoveryCopy.missingDetailNextStep])
            )
        }

        let tokens = searchTokens(trimmed)
        let scoredRecords: [(record: AgentMemoryRecord, score: Int)] = records.map { record in
            (record: record, score: score(record, tokens: tokens))
        }
        let filteredRecords = scoredRecords.filter { item in
            item.score > 0
        }
        let sortedRecords = filteredRecords.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.record.createdAt > rhs.record.createdAt
            }
            return lhs.score > rhs.score
        }
        let resultLimit = limit ?? maximumSearchResults
        let matches = Array(sortedRecords.prefix(resultLimit).map { item in
            item.record
        })

        guard !matches.isEmpty else {
            return AgentToolResult(
                ok: true,
                message: "I did not find that in saved memory yet.",
                data: longTermMemoryData(["query": trimmed, "matches": "0"])
            )
        }

        let body = matches.map { record in
            "- \(dateTimeFormatter.string(from: record.createdAt)): \(record.summary)"
        }.joined(separator: "\n")

        eventStore.append(
            category: .memory,
            status: .done,
            symbol: "magnifyingglass",
            title: "Memory searched",
            summary: trimmed,
            details: [
                AgentLogEventDetail(key: "Matches", value: "\(matches.count)")
            ]
        )

        return AgentToolResult(
            ok: true,
            message: body,
            data: [
                "query": trimmed,
                "matches": String(matches.count),
                "results": body,
                "answer_guidance": "Use these saved-memory results only when relevant. Cite the date or session in natural language and do not say raw source fields."
            ].merging(longTermMemoryData()) { current, _ in current }
        )
    }

    func summarizeRecent(limit: Int = 12) -> AgentToolResult {
        guard !records.isEmpty else {
            return AgentToolResult(
                ok: true,
                message: "No saved memories are available yet.",
                data: longTermMemoryData(["count": "0"])
            )
        }

        let recent = records.prefix(limit)
        let summary = recent.map { record in
            "- \(dateTimeFormatter.string(from: record.createdAt)): \(record.summary)"
        }.joined(separator: "\n")

        return AgentToolResult(
            ok: true,
            message: summary,
            data: longTermMemoryData([
                "count": "\(recent.count)",
                "summary": summary,
                "answer_guidance": "Use these saved-memory results only when relevant. Cite the date or session in natural language and do not say raw source fields."
            ])
        )
    }

    func clear() {
        records = []
        deletePersistentIndex()
        deleteScreenshots()
        deleteVaultDailyNotes()
        lastStatus = "Long-term memory cleared."
        eventStore.append(
            category: .memory,
            status: .cancelled,
            symbol: "trash",
            title: "Memory cleared",
            summary: "Local memory index, screenshots, and Voiyce-written daily vault notes were cleared."
        )
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: recordsURL.path) else {
            records = []
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: recordsURL)
        } catch {
            records = []
            appendMemoryError(
                operation: "Load memory index",
                error: error,
                path: recordsURL.path,
                nextStep: "Check disk access for the local Voiyce memory folder."
            )
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            records = try decoder.decode([AgentMemoryRecord].self, from: data)
        } catch {
            records = []
            appendMemoryError(
                operation: "Decode memory index",
                error: error,
                path: recordsURL.path,
                nextStep: "Export support logs, then clear local memory if the index is corrupt."
            )
        }
    }

    private func save() {
        guard createDirectory(
            at: storageDirectory,
            operation: "Create memory directory",
            nextStep: "Check disk access for the local Voiyce memory folder."
        ) else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(records)
            try data.write(to: recordsURL, options: .atomic)
        } catch {
            appendMemoryError(
                operation: "Save memory index",
                error: error,
                path: recordsURL.path,
                nextStep: "Check disk space and write access for the local Voiyce memory folder."
            )
        }
    }

    private func existingFileURLs(_ urls: [URL]) -> [URL] {
        urls.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func totalFileBytes(_ urls: [URL]) -> Int {
        urls.reduce(0) { partialResult, url in
            partialResult + fileByteCount(url)
        }
    }

    private func fileByteCount(_ url: URL) -> Int {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey]) else {
            return 0
        }

        return values.fileSize ?? values.totalFileAllocatedSize ?? 0
    }

    private func storeScreenshot(_ data: Data?) -> String? {
        guard memoryRetention != .sessionOnly else { return nil }
        guard screenshotRetention != .off, !isPrivateModeEnabled else { return nil }
        guard let data, !data.isEmpty else { return nil }
        let filename = "\(screenshotFormatter.string(from: Date()))-\(UUID().uuidString.prefix(8)).jpg"
        let url = screenshotsDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            appendMemoryError(
                operation: "Save memory screenshot",
                error: error,
                path: url.path,
                nextStep: "Check disk space and screenshot-retention settings."
            )
            return nil
        }
    }

    private var activeStorageQuota: AgentMemoryStorageQuota {
        storageQuotaOverride ?? storageTier.quota
    }

    private func durableMemoryStorageBlockReason() -> String? {
        let snapshot = usageSnapshot
        let quota = activeStorageQuota
        if snapshot.recordCount >= quota.maxRecords {
            return "This \(storageTier.title) account has reached its local memory record limit. Delete older memories or change retention before saving more."
        }
        if snapshot.totalStorageBytes >= quota.maxTotalStorageBytes {
            return "This \(storageTier.title) account has reached its local memory storage limit. Delete older memories or change retention before saving more."
        }
        return nil
    }

    private func screenshotDataAllowedByStorageQuota(_ data: Data?, note: inout String?) -> Data? {
        guard screenshotRetention != .off, memoryRetention != .sessionOnly, let data, !data.isEmpty else {
            return data
        }

        let snapshot = usageSnapshot
        let quota = activeStorageQuota
        let projectedScreenshotBytes = snapshot.screenshotBytes + data.count
        let projectedStorageBytes = snapshot.totalStorageBytes + data.count
        if projectedScreenshotBytes > quota.maxScreenshotBytes || projectedStorageBytes > quota.maxTotalStorageBytes {
            note = "Skipped because this \(storageTier.title) account has reached its local screenshot storage limit."
            return nil
        }

        return data
    }

    private func appendVaultNote(
        source: String,
        summary: String,
        searchableText: String,
        tags: [String],
        appHint: String?,
        screenshotPath: String?,
        createdAt: Date
    ) -> String? {
        guard isVaultSyncEnabled else { return nil }
        guard let vault = ensureVault() else { return nil }

        let dailyDirectory = vault.appendingPathComponent("Daily", isDirectory: true)
        guard createDirectory(
            at: dailyDirectory,
            operation: "Create vault daily notes directory",
            nextStep: "Choose a writable vault folder in Settings."
        ) else { return nil }

        let noteURL = dailyDirectory.appendingPathComponent("\(dayFormatter.string(from: createdAt)).md")

        if !FileManager.default.fileExists(atPath: noteURL.path) {
            let header = """
            ---
            date: \(dayFormatter.string(from: createdAt))
            source: Voiyce
            \(yamlListBlock(key: "source_modes", values: [source]))
            \(yamlListBlock(key: "apps", values: appHint.map { [$0] } ?? []))
            \(yamlListBlock(key: "tags", values: ["voiyce"] + tags))
            privacy_level: local_memory
            screenshot_retention: \(screenshotRetention.rawValue)
            account_scope: \(activeAccountScopeValue)
            ---

            # \(displayDayFormatter.string(from: createdAt))

            """
            do {
                try header.write(to: noteURL, atomically: true, encoding: .utf8)
            } catch {
                appendMemoryError(
                    operation: "Create vault daily note",
                    error: error,
                    path: noteURL.path,
                    nextStep: "Choose a writable vault folder in Settings."
                )
                return nil
            }
        }

        let relatedLinks = tags.map { "[[\($0)]]" }.joined(separator: " ")
        let textBlock = searchableText.isEmpty ? "" : "\n\n\(searchableText)"
        let screenshotLine = screenshotPath.map { "\nScreenshot: \($0)" } ?? ""
        let appLine = appHint.map { "\nApp/site: \($0)" } ?? ""
        let entry = """

        ## \(timeFormatter.string(from: createdAt)) - \(source)

        \(summary)
        \(textBlock)
        \(appLine)
        \(screenshotLine)

        Related: \(relatedLinks.isEmpty ? "[[Voiyce]]" : relatedLinks)

        """

        do {
            let handle = try FileHandle(forWritingTo: noteURL)
            defer { try? handle.close() }
            _ = try handle.seekToEnd()
            guard let data = entry.data(using: .utf8) else {
                appendMemoryError(
                    operation: "Encode vault note entry",
                    message: "Could not encode memory entry as UTF-8.",
                    path: noteURL.path,
                    nextStep: "Try saving the memory again."
                )
                return nil
            }
            handle.write(data)
        } catch {
            appendMemoryError(
                operation: "Append vault note",
                error: error,
                path: noteURL.path,
                nextStep: "Choose a writable vault folder in Settings."
            )
            return nil
        }

        return noteURL.path
    }

    private func yamlListBlock(key: String, values: [String]) -> String {
        let cleanValues = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seenValues = Set<String>()
        let uniqueValues = cleanValues.filter { seenValues.insert($0).inserted }
        guard !uniqueValues.isEmpty else { return "\(key): []" }

        let list = uniqueValues
            .map { "  - '\(yamlSingleQuotedValue($0))'" }
            .joined(separator: "\n")
        return "\(key):\n\(list)"
    }

    private func yamlSingleQuotedValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "'", with: "''")
    }

    private func memoryBlockReason(
        source: String,
        summary: String,
        searchableText: String,
        appHint: String?
    ) -> String? {
        if isPrivateModeEnabled {
            return "Private mode is on, so I did not save this to long-term memory."
        }

        let haystack = [
            source,
            summary,
            searchableText,
            appHint ?? ""
        ].joined(separator: " ").lowercased()

        if let sensitive = Self.sensitiveCapturePatterns.first(where: { haystack.contains($0) }) {
            return "This looked sensitive (\(sensitive)), so I did not save it to long-term memory."
        }

        if let excluded = excludedPatterns.first(where: { haystack.contains($0) }) {
            return "This matched your memory exclusion (\(excluded)), so I did not save it."
        }

        return nil
    }

    private func pruneExpiredRecords() {
        guard let interval = memoryRetention.retentionInterval else { return }
        if interval == 0 {
            records = []
            deletePersistentIndex()
            return
        }

        let cutoff = Date().addingTimeInterval(-interval)
        let expired = records.filter { $0.createdAt < cutoff }
        guard !expired.isEmpty else { return }

        for record in expired {
            if let screenshotPath = record.screenshotPath {
                try? FileManager.default.removeItem(atPath: screenshotPath)
            }
            if let vaultNotePath = record.vaultNotePath {
                removeVaultNoteIfVoiyceWritten(atPath: vaultNotePath)
            }
        }

        records = records.filter { $0.createdAt >= cutoff }
    }

    private func pruneExpiredScreenshots() {
        guard screenshotRetention != .off else {
            deleteScreenshots()
            return
        }
        guard let interval = screenshotRetention.retentionInterval else { return }

        let cutoff = Date().addingTimeInterval(-interval)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: screenshotsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in urls {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = values?.contentModificationDate ?? .distantPast
            if modified < cutoff {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func deletePersistentIndex() {
        guard FileManager.default.fileExists(atPath: recordsURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: recordsURL)
        } catch {
            appendMemoryError(
                operation: "Delete memory index",
                error: error,
                path: recordsURL.path,
                nextStep: "Check disk access for the local Voiyce memory folder."
            )
        }
    }

    private func deleteScreenshots() {
        if FileManager.default.fileExists(atPath: screenshotsDirectory.path) {
            do {
                try FileManager.default.removeItem(at: screenshotsDirectory)
            } catch {
                appendMemoryError(
                    operation: "Delete memory screenshots",
                    error: error,
                    path: screenshotsDirectory.path,
                    nextStep: "Check disk access for the local Voiyce memory folder."
                )
            }
        }

        createDirectory(
            at: screenshotsDirectory,
            operation: "Create screenshot directory",
            nextStep: "Check disk access for the local Voiyce memory folder."
        )
    }

    private func deleteVaultDailyNotes() {
        guard let vault = vaultURL else { return }
        let dailyDirectory = vault.appendingPathComponent("Daily", isDirectory: true)
        guard FileManager.default.fileExists(atPath: dailyDirectory.path) else { return }

        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: dailyDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            appendMemoryError(
                operation: "List vault daily notes",
                error: error,
                path: dailyDirectory.path,
                nextStep: "Check disk access for the selected vault folder."
            )
            return
        }

        for url in urls where url.pathExtension.lowercased() == "md" && isVoiyceDailyNote(url) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                appendMemoryError(
                    operation: "Delete vault daily note",
                    error: error,
                    path: url.path,
                    nextStep: "Check disk access for the selected vault folder."
                )
            }
        }
    }

    private func isVoiyceDailyNote(_ url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return content.contains("source: Voiyce")
            && (
                content.contains("- voiyce")
                || content.contains("- 'voiyce'")
                || content.contains("- \"voiyce\"")
            )
    }

    private func removeVaultNoteIfVoiyceWritten(atPath path: String) {
        let url = URL(fileURLWithPath: path)
        guard url.pathExtension.lowercased() == "md", isVoiyceDailyNote(url) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            appendMemoryError(
                operation: "Delete expired vault note",
                error: error,
                path: url.path,
                nextStep: "Check disk access for the selected vault folder."
            )
        }
    }

    private func logPrivacySettingChanged(_ setting: String, value: String) {
        eventStore.append(
            category: .memory,
            status: .done,
            symbol: "lock.shield",
            title: "Memory privacy updated",
            summary: "\(setting): \(value)",
            details: [
                AgentLogEventDetail(key: "Setting", value: setting),
                AgentLogEventDetail(key: "Value", value: value)
            ]
        )
    }

    private func writeVaultReadmeIfNeeded(_ vault: URL) {
        let readme = vault.appendingPathComponent("README.md")
        guard !FileManager.default.fileExists(atPath: readme.path) else { return }

        let content = """
        # Voiyce Memory

        This local vault is written by Voiyce. Daily notes live in `Daily/`.

        Voiyce stores distilled summaries by default. Raw screenshots may be linked when they materially help recall.
        """
        do {
            try content.write(to: readme, atomically: true, encoding: .utf8)
        } catch {
            appendMemoryError(
                operation: "Write vault readme",
                error: error,
                path: readme.path,
                nextStep: "Choose a writable vault folder in Settings."
            )
        }
    }

    private func longTermMemoryData(_ values: [String: String] = [:]) -> [String: String] {
        values.merging([
            "memory_source": "long_term",
            "context_scope": "previous_sessions",
            "account_scope": activeAccountScopeValue
        ]) { current, _ in current }
    }

    private func loadPrivacySettingsForCurrentAccount() {
        isConfiguringAccount = true
        defer { isConfiguringAccount = false }

        storageTier = AgentMemoryStorageTier(
            rawValue: userDefaults.string(forKey: scopedDefaultsKey(Self.storageTierDefaultsKey)) ?? ""
        ) ?? .defaultTier
        memoryRetention = AgentMemoryRetention(
            rawValue: userDefaults.string(forKey: scopedDefaultsKey(Self.memoryRetentionDefaultsKey)) ?? ""
        ) ?? .ninetyDays
        screenshotRetention = AgentScreenshotRetention(
            rawValue: userDefaults.string(forKey: scopedDefaultsKey(Self.screenshotRetentionDefaultsKey)) ?? ""
        ) ?? .off
        isVaultSyncEnabled = Self.boolDefault(
            userDefaults,
            key: scopedDefaultsKey(Self.vaultSyncEnabledDefaultsKey),
            defaultValue: true
        )
        isPrivateModeEnabled = userDefaults.bool(forKey: scopedDefaultsKey(Self.privateModeDefaultsKey))
        excludedPatternsText = userDefaults.string(forKey: scopedDefaultsKey(Self.exclusionsDefaultsKey)) ?? ""
    }

    private static func boolDefault(_ defaults: UserDefaults, key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private func scopedDefaultsKey(_ baseKey: String) -> String {
        AppConstants.accountScopedKey(baseKey, userID: currentUserID)
    }

    private func storageDirectory(for userID: String?) -> URL {
        guard let userID else {
            return baseStorageDirectory.appendingPathComponent(Self.signedOutScopeName, isDirectory: true)
        }

        return baseStorageDirectory
            .appendingPathComponent(Self.accountsDirectoryName, isDirectory: true)
            .appendingPathComponent(userID, isDirectory: true)
    }

    private func normalizedAccountID(_ userID: String?) -> String? {
        let trimmed = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }

        let encoded = trimmed.utf8.map { byte in
            let hex = String(byte, radix: 16)
            return byte < 16 ? "0\(hex)" : hex
        }.joined()

        return encoded.isEmpty ? nil : "user-\(encoded)"
    }

    private func legacyDefaultVaultURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let root = (documentsDirectory ?? baseStorageDirectory)
            .appendingPathComponent(Self.legacyVaultName, isDirectory: true)

        guard let currentUserID else { return root }
        return root
            .appendingPathComponent(Self.accountsDirectoryName, isDirectory: true)
            .appendingPathComponent(currentUserID, isDirectory: true)
    }

    private func preferredObsidianMemoryURL() -> URL? {
        guard let root = activeObsidianVaultRoot() else { return nil }
        let memoryRoot = root.appendingPathComponent(Self.legacyVaultName, isDirectory: true)
        guard let currentUserID else { return memoryRoot }
        return memoryRoot
            .appendingPathComponent(Self.accountsDirectoryName, isDirectory: true)
            .appendingPathComponent(currentUserID, isDirectory: true)
    }

    private func activeObsidianVaultRoot() -> URL? {
        let configURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("obsidian", isDirectory: true)
            .appendingPathComponent("obsidian.json")

        guard let configURL,
              let data = try? Data(contentsOf: configURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vaults = object["vaults"] as? [String: [String: Any]] else {
            return nil
        }

        let selectedVault = vaults.values.first { value in
            value["open"] as? Bool == true
        } ?? vaults.values.first

        guard let path = selectedVault?["path"] as? String, !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func isLegacyDefaultVault(_ url: URL) -> Bool {
        url.standardizedFileURL.path == legacyDefaultVaultURL().standardizedFileURL.path
    }

    private func migrateLegacyVaultIfPossible(from legacyURL: URL) -> URL? {
        guard let preferredURL = preferredObsidianMemoryURL(),
              preferredURL.standardizedFileURL.path != legacyURL.standardizedFileURL.path else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(at: preferredURL, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: legacyURL.path) {
                try mergeDirectoryContents(from: legacyURL, to: preferredURL)
            }
            writeVaultReadmeIfNeeded(preferredURL)
            userDefaults.set(preferredURL.path, forKey: scopedDefaultsKey(Self.vaultPathDefaultsKey))
            lastStatus = "Using Obsidian memory at \(preferredURL.path)."
            return preferredURL
        } catch {
            lastStatus = "Could not move memory into Obsidian. Check the selected Obsidian vault permissions."
            appendMemoryError(
                operation: "Move memory into Obsidian",
                error: error,
                path: preferredURL.path,
                nextStep: "Check the selected Obsidian vault permissions."
            )
            return nil
        }
    }

    @discardableResult
    private func createDirectory(at url: URL, operation: String, nextStep: String) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            appendMemoryError(operation: operation, error: error, path: url.path, nextStep: nextStep)
            return false
        }
    }

    private func appendMemoryError(
        operation: String,
        error: Error,
        path: String,
        nextStep: String
    ) {
        appendMemoryError(
            operation: operation,
            message: "Voiyce could not finish this memory operation.",
            path: path,
            nextStep: nextStep
        )
    }

    private func appendMemoryError(
        operation: String,
        message: String,
        path: String,
        nextStep: String
    ) {
        eventStore.appendMemoryError(
            operation: operation,
            message: message,
            path: path,
            nextStep: nextStep
        )
    }

    private func mergeDirectoryContents(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for item in contents {
            let target = destination.appendingPathComponent(item.lastPathComponent, isDirectory: item.hasDirectoryPath)
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
                try mergeDirectoryContents(from: item, to: target)
            } else if !fileManager.fileExists(atPath: target.path) {
                try fileManager.copyItem(at: item, to: target)
            }
        }
    }

    private func inferredTags(from text: String) -> [String] {
        let lower = text.lowercased()
        let candidates = [
            "gmail", "calendar", "billing", "settings", "agent", "voice",
            "website", "email", "meeting", "permissions", "memory"
        ]

        return candidates.filter { lower.contains($0) }
    }

    private func normalizedTags(_ tags: [String]) -> [String] {
        Array(Set(tags.map {
            $0.lowercased()
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: " ", with: "-")
                .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        }.filter { !$0.isEmpty })).sorted()
    }

    private func searchTokens(_ query: String) -> [String] {
        query.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 }
    }

    private func score(_ record: AgentMemoryRecord, tokens: [String]) -> Int {
        let haystack = [
            record.summary,
            record.searchableText,
            record.tags.joined(separator: " "),
            record.appHint ?? "",
            record.source
        ].joined(separator: " ").lowercased()

        return tokens.reduce(0) { total, token in
            total + (haystack.contains(token) ? 1 : 0)
        }
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private var displayDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }

    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    private var screenshotFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }

    private static func defaultStorageDirectory() -> URL {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return supportDirectory
            .appendingPathComponent("Voiyce-Agent", isDirectory: true)
            .appendingPathComponent("Memory", isDirectory: true)
    }
}
#endif
