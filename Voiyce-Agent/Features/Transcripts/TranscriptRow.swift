//
//  TranscriptRow.swift
//  Voiyce-Agent
//

import SwiftUI

struct TranscriptRow: View {
    let transcript: TranscriptItem

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: transcript.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // App name
                HStack(spacing: 6) {
                    Image(systemName: "app.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.accent)

                    Text(transcript.appName)
                        .font(AppTheme.captionFont)
                        .foregroundStyle(AppTheme.accent)
                }

                Spacer()

                // Timestamp
                Text(timeString)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            // Transcript preview
            Text(transcript.text)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)

            // Word count
            HStack {
                Spacer()

                Text("\(transcript.wordCount) words")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(AppTheme.cardPadding)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}
