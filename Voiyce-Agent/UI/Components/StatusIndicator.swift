//
//  StatusIndicator.swift
//  Voiyce-Agent
//

import SwiftUI

struct StatusIndicator: View {
    let recordingState: RecordingState
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(recordingState.color)
                .frame(width: 8, height: 8)
                .opacity(isPulsing ? 0.4 : 1.0)
                .animation(
                    recordingState == .listening
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: isPulsing
                )

            Text(recordingState.label)
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .onChange(of: recordingState) { _, newValue in
            isPulsing = newValue == .listening
        }
        .onAppear {
            isPulsing = recordingState == .listening
        }
    }
}
