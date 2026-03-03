//
//  IntegrationsView.swift
//  Voiyce-Agent
//

import SwiftUI

// MARK: - IntegrationItem

struct IntegrationItem: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let description: String
    var isConnected: Bool

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        description: String,
        isConnected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
        self.isConnected = isConnected
    }
}

struct IntegrationsView: View {
    @State private var searchText = ""
    @State private var integrations: [IntegrationItem] = [
        IntegrationItem(
            name: "Gmail",
            icon: "envelope.fill",
            description: "Send, read, and manage emails.",
            isConnected: false
        ),
        IntegrationItem(
            name: "Google Calendar",
            icon: "calendar",
            description: "View and create calendar events.",
            isConnected: false
        ),
        IntegrationItem(
            name: "Google Drive",
            icon: "externaldrive.fill",
            description: "Access and manage files in Drive.",
            isConnected: false
        ),
        IntegrationItem(
            name: "Slack",
            icon: "number",
            description: "Send messages and manage channels.",
            isConnected: false
        ),
        IntegrationItem(
            name: "Notion",
            icon: "doc.richtext",
            description: "Create and update Notion pages.",
            isConnected: false
        ),
        IntegrationItem(
            name: "GitHub",
            icon: "chevron.left.forwardslash.chevron.right",
            description: "Manage repos, issues, and pull requests.",
            isConnected: false
        ),
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: AppTheme.spacing)
    ]

    private var filteredIntegrations: [IntegrationItem] {
        if searchText.isEmpty {
            return integrations
        }
        return integrations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Integrations")
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Text("\(integrations.filter(\.isConnected).count) connected")
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

                TextField("Search integrations...", text: $searchText)
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

            // Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: AppTheme.spacing) {
                    ForEach(filteredIntegrations) { item in
                        IntegrationCard(
                            integration: item,
                            onToggle: { toggleConnection(for: item.id) }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.backgroundPrimary)
    }

    private func toggleConnection(for id: UUID) {
        if let index = integrations.firstIndex(where: { $0.id == id }) {
            integrations[index].isConnected.toggle()
        }
    }
}
