#if VOIYCE_PRO
import AppKit
import SwiftUI

@MainActor
final class AgentFocusToolPaletteOverlay {
    static let shared = AgentFocusToolPaletteOverlay()

    private let size = CGSize(width: 448, height: 72)
    private var panel: AgentFocusToolPalettePanel?

    private init() {}

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        ensurePanel()
        positionAsFloatingBar()
        panel?.makeKeyAndOrderFront(nil)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func ensurePanel() {
        if let panel {
            panel.contentView = NSHostingView(rootView: paletteView)
            return
        }

        let panel = AgentFocusToolPalettePanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: paletteView)
        self.panel = panel
    }

    private var paletteView: some View {
        AgentFocusToolPaletteView(
            onFocus: { [weak self] in self?.begin(.rectangle) },
            onPaint: { [weak self] in self?.begin(.paint) },
            onUnderline: { [weak self] in self?.begin(.underline) },
            onClear: { [weak self] in
                FocusHighlightOverlay.shared.clear()
                self?.hide()
            },
            onClose: { [weak self] in self?.hide() }
        )
    }

    private func begin(_ mode: FocusMarkMode) {
        hide()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 90_000_000)
            FocusHighlightOverlay.shared.beginSelection(mode: mode)
            AgentEventStore.shared.append(
                category: .memory,
                status: .done,
                symbol: mode.symbol,
                title: "\(mode.title) tool selected",
                summary: mode.instruction
            )
        }
    }

    private func positionAsFloatingBar() {
        guard let panel else { return }

        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let x = visible.midX - size.width / 2
        let y = visible.minY + 34

        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}

private final class AgentFocusToolPalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            orderOut(nil)
            return
        }

        super.keyDown(with: event)
    }
}

private struct AgentFocusToolPaletteView: View {
    let onFocus: () -> Void
    let onPaint: () -> Void
    let onUnderline: () -> Void
    let onClear: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            toolButton(title: "Focus", key: "⌘⇧F", systemImage: "viewfinder", action: onFocus)
            toolButton(title: "Paint", key: "⌘⇧P", systemImage: "paintbrush", action: onPaint)
            toolButton(title: "Underline", key: "⌘⇧U", systemImage: "underline", action: onUnderline)

            Divider()
                .frame(height: 30)
                .overlay(AppTheme.ridge.opacity(0.8))

            iconButton(systemImage: "xmark.circle", action: onClear)
            iconButton(systemImage: "chevron.down", action: onClose)
        }
        .padding(.horizontal, 12)
        .frame(width: 448, height: 72)
        .background(.black.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: 0xF8C04E).opacity(0.34), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0xF8C04E).opacity(0.20), radius: 24)
        .shadow(color: .black.opacity(0.42), radius: 20, y: 10)
    }

    private func toolButton(
        title: String,
        key: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xF8C04E))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(key)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 42)
            .background(.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func iconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
#endif
