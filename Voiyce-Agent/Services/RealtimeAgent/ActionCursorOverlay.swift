#if VOIYCE_PRO
import AppKit
import QuartzCore
import SwiftUI

struct ActionCursorOverlayPanelPolicy {
    let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
    let level: NSWindow.Level = .screenSaver
    let ignoresMouseEvents = true
    let isOpaque = false
    let collectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .stationary
    ]
}

struct ActionCursorPresentationPolicy {
    let allowsPreviewMode: Bool = true

    func canPresent(isActModeActive: Bool, isPreviewModeEnabled: Bool) -> Bool {
        isActModeActive || (allowsPreviewMode && isPreviewModeEnabled)
    }
}

enum ActionCursorAnimationTiming {
    static let moveDuration: TimeInterval = 0.18
}

enum ActionCursorGeometry {
    static func pointerOrigin(for point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: point.x - size.width * 0.22, y: point.y - size.height * 0.72)
    }

    static func clampedBadgeOrigin(for point: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGPoint {
        let preferred = CGPoint(x: point.x + 22, y: point.y - size.height - 18)
        let x = min(max(preferred.x, visibleFrame.minX + 14), visibleFrame.maxX - size.width - 14)
        let y = min(max(preferred.y, visibleFrame.minY + 14), visibleFrame.maxY - size.height - 14)
        return CGPoint(x: x, y: y)
    }
}

struct ActionCursorOverlayEvent: Equatable {
    enum Kind: String {
        case beginActMode
        case endActMode
        case move
        case hide
    }

    let kind: Kind
    let status: String?
    let point: CGPoint?
    let delay: TimeInterval?
}

@MainActor
final class ActionCursorOverlay {
    static let shared = ActionCursorOverlay()
    static let panelPolicy = ActionCursorOverlayPanelPolicy()
    static let presentationPolicy = ActionCursorPresentationPolicy()

    private var badgePanel: NSPanel?
    private var pointerPanel: NSPanel?
    private var status = "Looking"
    private var isActModeActive = false
    private var isPreviewModeEnabled = false
    private var hideTask: Task<Void, Never>?
    private var eventRecorder: ((ActionCursorOverlayEvent) -> Void)?

    private init() {}

    func setEventRecorder(_ recorder: ((ActionCursorOverlayEvent) -> Void)?) {
        eventRecorder = recorder
    }

    func beginActMode() {
        isActModeActive = true
        hideTask?.cancel()
        record(.beginActMode)
    }

    func endActMode(after delay: TimeInterval = 0.45) {
        isActModeActive = false
        record(.endActMode, delay: delay)
        hide(after: delay)
    }

    func setPreviewModeEnabled(_ enabled: Bool) {
        isPreviewModeEnabled = enabled
        if !canPresent {
            hide(after: 0)
        }
    }

    func show(status: String) {
        move(to: NSEvent.mouseLocation, status: status)
    }

    func move(to point: CGPoint, status: String) {
        guard canPresent else {
            hide(after: 0)
            return
        }

        self.status = status
        record(.move, status: status, point: point)
        hideTask?.cancel()
        ensurePanels()
        guard let badgePanel, let pointerPanel else { return }

        let pointerSize = pointerPanel.frame.size
        pointerPanel.orderFrontRegardless()
        animate(pointerPanel, to: ActionCursorGeometry.pointerOrigin(for: point, size: pointerSize))

        let badgeSize = badgePanel.frame.size
        let origin = clampedBadgeOrigin(for: point, size: badgeSize)
        badgePanel.orderFrontRegardless()
        animate(badgePanel, to: origin)
    }

    func hide(after delay: TimeInterval = 0.45) {
        record(.hide, delay: delay)
        hideTask?.cancel()
        let badgePanel = badgePanel
        let pointerPanel = pointerPanel
        hideTask = Task { @MainActor in
            let nanoseconds = UInt64(max(delay, 0) * 1_000_000_000)
            if nanoseconds > 0 {
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            guard !Task.isCancelled else { return }
            badgePanel?.orderOut(nil)
            pointerPanel?.orderOut(nil)
        }
    }

    func handleDisplayConfigurationChange() {
        hideTask?.cancel()
        hideTask = nil
        record(.hide, delay: 0)
        badgePanel?.orderOut(nil)
        pointerPanel?.orderOut(nil)
    }

    private var canPresent: Bool {
        Self.presentationPolicy.canPresent(
            isActModeActive: isActModeActive,
            isPreviewModeEnabled: isPreviewModeEnabled
        )
    }

    private func ensurePanels() {
        if let badgePanel, let pointerPanel {
            badgePanel.contentView = NSHostingView(rootView: ActionCursorBadgeView(status: status))
            pointerPanel.contentView = NSHostingView(rootView: ActionCursorPointerView())
            return
        }

        let badgePanel = overlayPanel(
            contentRect: NSRect(x: 120, y: 120, width: 216, height: 58)
        )
        badgePanel.contentView = NSHostingView(rootView: ActionCursorBadgeView(status: status))

        let pointerPanel = overlayPanel(
            contentRect: NSRect(x: 120, y: 120, width: 68, height: 68)
        )
        pointerPanel.contentView = NSHostingView(rootView: ActionCursorPointerView())

        self.badgePanel = badgePanel
        self.pointerPanel = pointerPanel
    }

    private func overlayPanel(contentRect: NSRect) -> NSPanel {
        let policy = Self.panelPolicy
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: policy.styleMask,
            backing: .buffered,
            defer: false
        )
        panel.level = policy.level
        panel.backgroundColor = .clear
        panel.isOpaque = policy.isOpaque
        panel.ignoresMouseEvents = policy.ignoresMouseEvents
        panel.collectionBehavior = policy.collectionBehavior
        return panel
    }

    private func clampedBadgeOrigin(for point: CGPoint, size: CGSize) -> CGPoint {
        let screen = NSScreen.screens.first { screen in
            NSMouseInRect(point, screen.frame, false)
        } ?? NSScreen.main

        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        return ActionCursorGeometry.clampedBadgeOrigin(for: point, size: size, visibleFrame: visible)
    }

    private func animate(_ panel: NSPanel, to origin: CGPoint) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = ActionCursorAnimationTiming.moveDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(origin)
        }
    }

    private func record(
        _ kind: ActionCursorOverlayEvent.Kind,
        status: String? = nil,
        point: CGPoint? = nil,
        delay: TimeInterval? = nil
    ) {
        eventRecorder?(ActionCursorOverlayEvent(kind: kind, status: status, point: point, delay: delay))
    }
}

private struct ActionCursorPointerView: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(Color(hex: 0xF8C04E).opacity(0.16))
                .frame(width: 58, height: 58)
                .blur(radius: 8)
                .offset(x: 4, y: 5)

            Circle()
                .stroke(Color(hex: 0xF8C04E).opacity(0.72), lineWidth: 1.5)
                .frame(width: 42, height: 42)
                .offset(x: 15, y: 14)

            ActionCursorShape()
                .fill(.white)
                .frame(width: 36, height: 46)
                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                .overlay(
                    ActionCursorShape()
                        .stroke(Color(hex: 0xF8C04E).opacity(0.82), lineWidth: 1.4)
                        .frame(width: 36, height: 46)
                )
                .offset(x: 10, y: 5)

            Circle()
                .fill(Color(hex: 0xF8C04E))
                .frame(width: 8, height: 8)
                .shadow(color: Color(hex: 0xF8C04E).opacity(0.8), radius: 8)
                .offset(x: 47, y: 43)
        }
        .frame(width: 68, height: 68)
    }
}

private struct ActionCursorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.56))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.minY + rect.height * 0.61))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.minY + rect.height * 0.92))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.49, y: rect.minY + rect.height * 0.99))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + rect.height * 0.67))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.88))
        path.closeSubpath()
        return path
    }
}

private struct ActionCursorBadgeView: View {
    let status: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: 0xF8C04E).opacity(0.18))
                    .frame(width: 34, height: 34)

                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xF8C04E))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Voiyce is acting")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.7)

                Text(status)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(width: 216, height: 58)
        .background(.black.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color(hex: 0xF8C04E).opacity(0.48), lineWidth: 1))
        .shadow(color: Color(hex: 0xF8C04E).opacity(0.17), radius: 18)
        .shadow(color: .black.opacity(0.40), radius: 18, y: 8)
    }
}
#endif
