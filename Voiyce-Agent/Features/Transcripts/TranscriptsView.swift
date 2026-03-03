//
//  TranscriptsView.swift
//  Voiyce-Agent
//

import SwiftUI

// MARK: - Placeholder TranscriptItem

/// Temporary local struct for UI development. Will be replaced by SwiftData model.
struct TranscriptItem: Identifiable {
    let id: UUID
    let text: String
    let date: Date
    let appName: String

    nonisolated init(id: UUID = UUID(), text: String, date: Date, appName: String) {
        self.id = id
        self.text = text
        self.date = date
        self.appName = appName
    }

    var wordCount: Int {
        text.split(separator: " ").count
    }
}

struct TranscriptsView: View {
    @State private var searchText = ""
    @State private var transcripts: [TranscriptItem] = []

    private var filteredTranscripts: [TranscriptItem] {
        if searchText.isEmpty {
            return transcripts
        }
        return transcripts.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
            || $0.appName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedTranscripts: [(String, [TranscriptItem])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: filteredTranscripts) { item in
            formatter.string(from: item.date)
        }

        return grouped
            .sorted { lhs, rhs in
                guard let lhsDate = lhs.value.first?.date,
                      let rhsDate = rhs.value.first?.date else { return false }
                return lhsDate > rhsDate
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Transcripts")
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Text("\(transcripts.count) items")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)

                TextField("Search transcripts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textPrimary)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(AppTheme.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Content
            if filteredTranscripts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedTranscripts, id: \.0) { dateString, items in
                            Section {
                                ForEach(items) { item in
                                    TranscriptRow(transcript: item)
                                }
                            } header: {
                                Text(dateString)
                                    .font(AppTheme.captionFont)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(.top, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.backgroundPrimary)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "mic.slash")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.5))

            Text("No transcripts yet")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textSecondary)

            Text("Start dictating to see your transcripts here.")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary.opacity(0.7))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
