//
//  AgentChatView.swift
//  Voiyce-Agent
//

import SwiftUI

// MARK: - AgentChatView

struct AgentChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(AgentCoordinator.self) private var agentCoordinator
    @State private var inputText = ""

    private let suggestionChips = [
        "Draft an email",
        "Summarize my calendar",
        "Create a task",
        "Search my docs",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Agent")
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if agentCoordinator.agentEngine.isProcessing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.accent)

                        Text("Thinking...")
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()
                .background(AppTheme.backgroundTertiary)

            // Messages area
            if agentCoordinator.agentEngine.currentMessages.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(agentCoordinator.agentEngine.currentMessages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(24)
                    }
                    .onChange(of: agentCoordinator.agentEngine.currentMessages.count) { _, _ in
                        if let lastMessage = agentCoordinator.agentEngine.currentMessages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            Divider()
                .background(AppTheme.backgroundTertiary)

            // Input area
            inputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundPrimary)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.5))

            Text("Ask me anything")
                .font(AppTheme.headlineFont)
                .foregroundStyle(AppTheme.textPrimary)

            Text("I can help you draft emails, manage tasks, search documents, and more.")
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            // Suggestion chips
            HStack(spacing: 8) {
                ForEach(suggestionChips, id: \.self) { chip in
                    Button {
                        inputText = chip
                        sendMessage()
                    } label: {
                        Text(chip)
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $inputText)
                .textFieldStyle(.plain)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(10)
                .background(AppTheme.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit {
                    sendMessage()
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AppTheme.textSecondary
                            : AppTheme.accent
                    )
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agentCoordinator.agentEngine.isProcessing)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AppTheme.backgroundSecondary)
    }

    // MARK: - Actions

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        inputText = ""
        agentCoordinator.claudeAPIKey = appState.claudeAPIKey
        agentCoordinator.composioAPIKey = appState.composioAPIKey
        agentCoordinator.voiceOutputEnabled = appState.voiceOutputEnabled

        Task {
            await agentCoordinator.sendTextCommand(trimmed)
            appState.tasksCompleted += 1
        }
    }
}
