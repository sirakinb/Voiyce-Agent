#if VOIYCE_PRO
import AppKit
import SwiftUI

enum AgentLogLaunchCopy {
    static let headerSubtitle = "See what Voiyce did, what it touched, and what to try next."
    static let timelineTitle = "Session timeline"
    static let timelineMessage = "Review what Voiyce did, saved, asked, or attempted."
    static let actionDetailsTitle = "Action details"
    static let actionDetailsMessage = "Expand events for targets, status, and recovery steps."
    static let supportExportTitle = "Redacted support export"
    static let supportExportMessage = "Export removes raw transcripts, screenshots, tokens, and secrets."
    static let searchPlaceholder = "Search events, details, or next steps..."
    static let issueStatTitle = "Needs review"
    static let issueStatSubtitle = "Review"
    static let noMatchingEventsTitle = "No matching events"
    static let emptySearchMessage = "Try another action, memory, target, status, or next-step term."
    static let emptyFilterMessage = "Switch filters or start Context, Talk, or Act to record new events."
    static let emptyLogMessage = "Start Context, Talk, or Act and Voiyce will record useful summaries, confirmations, issues, and recovery steps here."

    static let visibleStrings = [
        headerSubtitle,
        timelineTitle,
        timelineMessage,
        actionDetailsTitle,
        actionDetailsMessage,
        supportExportTitle,
        supportExportMessage,
        searchPlaceholder,
        issueStatTitle,
        issueStatSubtitle,
        noMatchingEventsTitle,
        emptySearchMessage,
        emptyFilterMessage,
        emptyLogMessage
    ]
}

struct AgentLogView: View {
    @Environment(AppState.self) private var appState
    @State private var agentEvents = AgentEventStore.shared
    @State private var selectedFilter: AgentLogCategory = .all
    @State private var expandedEventID: UUID?
    @State private var copiedEventID: UUID?
    @State private var supportExportStatus: String?
    @State private var query = ""

    private var filteredEvents: [AgentLogEvent] {
        agentEvents.events.filter { event in
            if selectedFilter != .all && event.category != selectedFilter {
                return false
            }

            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return true
            }

            return searchableText(for: event)
                .localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                activeAgentReturnBanner
                supportSummary
                toolbar
                stats
                dateLabel
                eventList
                endMarker
            }
            .frame(maxWidth: 980)
            .padding(.horizontal, 56)
            .padding(.vertical, 44)
            .frame(maxWidth: .infinity)
        }
        .background(GroovedBackground())
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.textSecondary.opacity(0.6))
                        .frame(width: 5, height: 5)
                    Text("Voiyce / Agent Log")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text("Agent Log")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(AgentLogLaunchCopy.headerSubtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    LogHeaderButton(title: "Export", systemImage: "square.and.arrow.down") {
                        exportSupportLog()
                    }
                    LogHeaderButton(title: "Clear log", systemImage: "trash", tint: AppTheme.destructive) {
                        agentEvents.clear()
                        expandedEventID = nil
                        copiedEventID = nil
                        supportExportStatus = "Agent Log cleared."
                    }
                }

                if let supportExportStatus {
                    Text(supportExportStatus)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 260, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var activeAgentReturnBanner: some View {
        if let activity = appState.agentActivityStatus {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(appState.agentMode.accent.opacity(0.16))
                        .frame(width: 36, height: 36)

                    Image(systemName: activity.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(appState.agentMode.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Voiyce keeps running while you review the log.")
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Button {
                    appState.selectedTab = .agent
                } label: {
                    HStack(spacing: 6) {
                        Text("Return to Agent")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(14)
            .background(AppTheme.backgroundSecondary.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(appState.agentMode.accent.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("agent-log-active-agent-return")
        }
    }

    private var supportSummary: some View {
        HStack(spacing: 8) {
            AgentLogCueCard(
                title: AgentLogLaunchCopy.timelineTitle,
                message: AgentLogLaunchCopy.timelineMessage,
                systemImage: "clock.arrow.circlepath"
            )
            .accessibilityIdentifier("agent-log-cue-timeline")

            AgentLogCueCard(
                title: AgentLogLaunchCopy.actionDetailsTitle,
                message: AgentLogLaunchCopy.actionDetailsMessage,
                systemImage: "scope"
            )
            .accessibilityIdentifier("agent-log-cue-details")

            AgentLogCueCard(
                title: AgentLogLaunchCopy.supportExportTitle,
                message: AgentLogLaunchCopy.supportExportMessage,
                systemImage: "lock.doc"
            )
            .accessibilityIdentifier("agent-log-cue-export")
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(AgentLogCategory.allCases) { filter in
                    filterButton(filter)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                TextField(AgentLogLaunchCopy.searchPlaceholder, text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.textPrimary)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 260, height: 32)
            .background(.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.ridge.opacity(0.8), lineWidth: 1))
        }
    }

    private func filterButton(_ filter: AgentLogCategory) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 7) {
                if filter != .all {
                    Circle()
                        .fill(filter.tint)
                        .frame(width: 6, height: 6)
                }
                Text(filter.title)
                Text("\(count(for: filter))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .background(.white.opacity(0.03))
                    .clipShape(Capsule())
            }
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? .white.opacity(0.05) : .clear)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? AppTheme.ridge : AppTheme.ridge.opacity(0.65), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var stats: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            AgentLogStatCard(title: "Events today", value: "\(agentEvents.todayEvents.count)", subtitle: "Last 24h")
            AgentLogStatCard(title: "Successful actions", value: "\(agentEvents.events.filter { $0.status == .done }.count)", subtitle: "Done")
            AgentLogStatCard(title: "Confirmation requests", value: "\(agentEvents.events.filter { $0.status == .waiting }.count)", subtitle: "Logged", tint: AgentLogStatus.waiting.tint)
            AgentLogStatCard(title: AgentLogLaunchCopy.issueStatTitle, value: "\(agentEvents.events.filter { $0.status == .failed }.count)", subtitle: AgentLogLaunchCopy.issueStatSubtitle, tint: AgentLogStatus.failed.tint)
        }
    }

    private var dateLabel: some View {
        HStack(spacing: 12) {
            Text("Today · \(Self.todayFormatter.string(from: Date()))")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.textSecondary)
            AppTheme.ridge.frame(height: 1)
            Text("\(filteredEvents.count) event\(filteredEvents.count == 1 ? "" : "s")")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.65))
        }
    }

    private var eventList: some View {
        VStack(spacing: 0) {
            ForEach(Array(filteredEvents.enumerated()), id: \.element.id) { index, event in
                AgentLogEventRow(
                    event: event,
                    isExpanded: expandedEventID == event.id,
                    isLast: index == filteredEvents.count - 1,
                    isEventIDCopied: copiedEventID == event.id
                ) {
                    expandedEventID = expandedEventID == event.id ? nil : event.id
                } onCopyEventID: {
                    copyEventID(event.id)
                }
            }

            if filteredEvents.isEmpty {
                VStack(spacing: 6) {
                    Text(emptyStateTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(emptyStateMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
    }

    private var emptyStateTitle: String {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return AgentLogLaunchCopy.noMatchingEventsTitle
        }

        if selectedFilter != .all {
            return "No \(selectedFilter.title.lowercased()) events yet"
        }

        return "No Agent Log events yet"
    }

    private var emptyStateMessage: String {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return AgentLogLaunchCopy.emptySearchMessage
        }

        if selectedFilter != .all {
            return AgentLogLaunchCopy.emptyFilterMessage
        }

        return AgentLogLaunchCopy.emptyLogMessage
    }

    private var endMarker: some View {
        HStack(spacing: 10) {
            AppTheme.ridge.frame(height: 1)
            Text("END OF LOG")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
            AppTheme.ridge.frame(height: 1)
        }
        .padding(.top, 12)
    }

    private func count(for category: AgentLogCategory) -> Int {
        if category == .all {
            return agentEvents.events.count
        }
        return agentEvents.events.filter { $0.category == category }.count
    }

    private func searchableText(for event: AgentLogEvent) -> String {
        let details = event.details
            .map { "\($0.key) \($0.value)" }
            .joined(separator: " ")

        return "\(event.title) \(event.summary) \(event.status.title) \(event.category.title) \(details)"
    }

    private func exportSupportLog() {
        guard let url = agentEvents.exportSupportBundle() else {
            supportExportStatus = "Could not export the redacted support log."
            return
        }

        supportExportStatus = "Redacted support log exported."
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyEventID(_ id: UUID) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(id.uuidString, forType: .string)
        copiedEventID = id
    }

    private static let todayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}

private struct AgentLogCueCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 28, height: 28)
                .background(AppTheme.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.ridge.opacity(0.75), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.015))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.ridge.opacity(0.75), lineWidth: 1))
    }
}

private struct LogHeaderButton: View {
    let title: String
    let systemImage: String
    var tint: Color = AppTheme.textSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 12.5))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.ridge.opacity(0.8), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct AgentLogStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    var tint: Color = AppTheme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11.5, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(tint)
            Text(subtitle)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.015))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.ridge.opacity(0.75), lineWidth: 1))
    }
}

private struct AgentLogEventRow: View {
    let event: AgentLogEvent
    let isExpanded: Bool
    let isLast: Bool
    let isEventIDCopied: Bool
    let onToggle: () -> Void
    let onCopyEventID: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.time)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                Image(systemName: event.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(event.category.tint)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.ridge.opacity(0.75), lineWidth: 1))
                if !isLast {
                    AppTheme.ridge
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.leading, 14)
                }
            }
            .frame(width: 78, alignment: .topLeading)
            .padding(.top, 10)

            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(event.summary)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Spacer()

                        HStack(spacing: 10) {
                            AgentLogStatusBadge(status: event.status)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    if isExpanded {
                        VStack(alignment: .leading, spacing: 10) {
                            AppTheme.ridge.frame(height: 1)
                                .padding(.top, 14)
                            Text("DETAILS")
                                .font(.system(size: 10.5, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(AppTheme.textSecondary)

                            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                                ForEach(event.details, id: \.key) { detail in
                                    GridRow {
                                        Text(detail.key)
                                            .font(.system(size: 12.5))
                                            .foregroundStyle(AppTheme.textSecondary)
                                        Text(detail.value)
                                            .font(.system(size: 12.5, design: .monospaced))
                                            .foregroundStyle(AppTheme.textPrimary)
                                    }
                                }
                            }

                            Button(action: onCopyEventID) {
                                HStack(spacing: 6) {
                                    Image(systemName: isEventIDCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 11))
                                    Text(isEventIDCopied ? "Copied event ID" : "Copy event ID")
                                        .font(.system(size: 11.5))
                                }
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.white.opacity(0.025))
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).stroke(AppTheme.ridge.opacity(0.75), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(14)
                .background(.white.opacity(isExpanded ? 0.025 : 0.015))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.ridge.opacity(0.75), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
    }
}

private struct AgentLogStatusBadge: View {
    let status: AgentLogStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.tint)
                .frame(width: 5, height: 5)
            Text(status.title)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 2)
        .background(status.tint.opacity(0.10))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(status.tint.opacity(0.20), lineWidth: 1))
    }
}

#endif
