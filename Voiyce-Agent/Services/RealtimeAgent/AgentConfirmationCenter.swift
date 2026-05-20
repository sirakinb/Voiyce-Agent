#if VOIYCE_PRO
import AppKit
import SwiftUI

struct AgentConfirmationDecision {
    let confirmationID: String
    let action: AgentConfirmationDecisionAction

    var approved: Bool {
        action == .approve
    }

    var shouldStopSession: Bool {
        action == .stopSession
    }

    init(confirmationID: String, approved: Bool) {
        self.confirmationID = confirmationID
        action = approved ? .approve : .cancel
    }

    init(confirmationID: String, action: AgentConfirmationDecisionAction) {
        self.confirmationID = confirmationID
        self.action = action
    }
}

enum AgentConfirmationDecisionAction: String {
    case approve
    case cancel
    case stopSession
    case timedOut = "timed_out"

    var logTitle: String {
        switch self {
        case .approve: "Approved"
        case .cancel: "Cancelled"
        case .stopSession: "Stopped session"
        case .timedOut: "Timed out"
        }
    }
}

extension Notification.Name {
    static let voiyceAgentConfirmationDecision = Notification.Name("voiyceAgentConfirmationDecision")
    static let voiyceFocusHighlightRequested = Notification.Name("voiyceFocusHighlightRequested")
}

@MainActor
final class AgentConfirmationCenter {
    static let shared = AgentConfirmationCenter()

    private var panel: NSPanel?
    private var currentConfirmationID: String?

    private init() {}

    func show(
        confirmationID: String,
        title: String,
        message: String,
        details: [String: String] = [:]
    ) {
        let view = AgentConfirmationCard(
            title: title,
            message: message,
            details: details,
            onApprove: { [weak self] in
                self?.postDecision(confirmationID: confirmationID, approved: true)
            },
            onCancel: { [weak self] in
                self?.postDecision(confirmationID: confirmationID, action: .cancel)
            },
            onStopSession: { [weak self] in
                self?.postDecision(confirmationID: confirmationID, action: .stopSession)
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 280),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Voiyce Confirmation"
        panel.level = .modalPanel
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true
        panel.titlebarAppearsTransparent = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: view)
        panel.center()
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        currentConfirmationID = confirmationID
        self.panel = panel
    }

    func hide(confirmationID: String? = nil) {
        if let confirmationID, confirmationID != currentConfirmationID {
            return
        }

        panel?.orderOut(nil)
        panel = nil
        currentConfirmationID = nil
    }

    private func postDecision(confirmationID: String, approved: Bool) {
        postDecision(confirmationID: confirmationID, action: approved ? .approve : .cancel)
    }

    private func postDecision(confirmationID: String, action: AgentConfirmationDecisionAction) {
        NotificationCenter.default.post(
            name: .voiyceAgentConfirmationDecision,
            object: AgentConfirmationDecision(confirmationID: confirmationID, action: action)
        )
        hide()
    }
}

private struct AgentConfirmationCard: View {
    let title: String
    let message: String
    let details: [String: String]
    let onApprove: () -> Void
    let onCancel: () -> Void
    let onStopSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xF8C04E))

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Text(message)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !details.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(details.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top) {
                            Text(key)
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 88, alignment: .leading)

                            Text(value)
                                .font(AppTheme.captionFont)
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(3)
                        }
                    }
                }
                .padding(10)
                .background(.white.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer(minLength: 0)

            HStack {
                Button("Stop Session", role: .destructive) {
                    onStopSession()
                }
                .keyboardShortcut(".", modifiers: [.command])

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Approve") {
                    onApprove()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 460)
        .frame(minHeight: 250)
        .background(AppTheme.backgroundSecondary)
    }
}
#endif
