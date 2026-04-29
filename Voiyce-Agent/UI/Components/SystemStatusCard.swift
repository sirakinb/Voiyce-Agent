import SwiftUI

enum SystemStatusTone {
    case info
    case warning
    case error

    var accentColor: Color {
        switch self {
        case .info:
            return AppTheme.accent
        case .warning:
            return AppTheme.warning
        case .error:
            return AppTheme.destructive
        }
    }
}

struct SystemStatusMessage: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let nextStep: String
    let tone: SystemStatusTone
    let actionTitle: String?
    let action: (() -> Void)?
}

struct SystemStatusCard: View {
    let message: SystemStatusMessage

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(message.tone.accentColor.opacity(0.14))
                    .frame(width: 46, height: 46)

                Image(systemName: message.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(message.tone.accentColor)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(message.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Issue")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(message.tone.accentColor)

                Text(message.detail)
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)

                Text("What to do")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(message.nextStep)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 16)

            if let actionTitle = message.actionTitle, let action = message.action {
                Button(actionTitle, action: action)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(message.tone.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(message.tone.accentColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(AppTheme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
