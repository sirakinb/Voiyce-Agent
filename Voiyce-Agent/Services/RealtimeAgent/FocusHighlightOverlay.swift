#if VOIYCE_PRO
import AppKit
import SwiftUI

struct FocusHighlightOverlayPanelPolicy {
    let styleMask: NSWindow.StyleMask
    let level: NSWindow.Level
    let isOpaque: Bool
    let hidesOnDeactivate: Bool
    let ignoresMouseEvents: Bool
    let collectionBehavior: NSWindow.CollectionBehavior

    static let selection = FocusHighlightOverlayPanelPolicy(
        styleMask: [.borderless, .nonactivatingPanel],
        level: .screenSaver,
        isOpaque: false,
        hidesOnDeactivate: false,
        ignoresMouseEvents: false,
        collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    )

    func apply(to panel: NSPanel) {
        panel.level = level
        panel.backgroundColor = .clear
        panel.isOpaque = isOpaque
        panel.hidesOnDeactivate = hidesOnDeactivate
        panel.ignoresMouseEvents = ignoresMouseEvents
        panel.collectionBehavior = collectionBehavior
    }
}

enum FocusHighlightGeometry {
    static let minimumRectangleSize = CGSize(width: 12, height: 12)
    static let minimumFreeformSize = CGSize(width: 12, height: 8)
    private static let paintPadding: CGFloat = 18
    private static let underlinePadding: CGFloat = 12

    static func rectangleAnnotation(
        screenFrame: CGRect,
        start: CGPoint,
        end: CGPoint
    ) -> FocusMarkAnnotation? {
        let localRect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        guard localRect.width > minimumRectangleSize.width,
              localRect.height > minimumRectangleSize.height else {
            return nil
        }

        return FocusMarkAnnotation(
            mode: .rectangle,
            screenFrame: screenFrame,
            region: screenRect(fromLocal: localRect, screenFrame: screenFrame),
            points: []
        )
    }

    static func freeformAnnotation(
        mode: FocusMarkMode,
        screenFrame: CGRect,
        points: [CGPoint]
    ) -> FocusMarkAnnotation? {
        guard mode != .rectangle,
              points.count > 2,
              let localBounds = bounds(for: points) else {
            return nil
        }

        let padding = mode == .underline ? underlinePadding : paintPadding
        let padded = localBounds.insetBy(dx: -padding, dy: -padding)
        guard padded.width > minimumFreeformSize.width,
              padded.height > minimumFreeformSize.height else {
            return nil
        }

        return FocusMarkAnnotation(
            mode: mode,
            screenFrame: screenFrame,
            region: screenRect(fromLocal: padded, screenFrame: screenFrame),
            points: points.map { screenPoint(fromLocal: $0, screenFrame: screenFrame) }
        )
    }

    static func bounds(for points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func screenRect(fromLocal rect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.minX + rect.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    static func screenPoint(fromLocal point: CGPoint, screenFrame: CGRect) -> CGPoint {
        CGPoint(
            x: screenFrame.minX + point.x,
            y: screenFrame.maxY - point.y
        )
    }
}

enum FocusHighlightLog {
    @MainActor
    static func appendMarked(_ annotation: FocusMarkAnnotation) {
        appendMarked(annotation, to: .shared)
    }

    @MainActor
    static func appendMarked(_ annotation: FocusMarkAnnotation, to eventStore: AgentEventStore) {
        eventStore.append(
            category: .memory,
            status: .done,
            symbol: annotation.mode.symbol,
            title: "\(annotation.mode.title) focus marked",
            summary: "Saved a visible \(annotation.mode.title.lowercased()) region for the next screen-aware request.",
            details: [
                AgentLogEventDetail(key: "Region", value: regionDescription(annotation.region)),
                AgentLogEventDetail(key: "Mode", value: annotation.mode.title)
            ]
        )
    }

    @MainActor
    static func appendCleared() {
        appendCleared(to: .shared)
    }

    @MainActor
    static func appendCleared(to eventStore: AgentEventStore) {
        eventStore.append(
            category: .memory,
            status: .cancelled,
            symbol: "viewfinder.circle",
            title: "Focus region cleared",
            summary: "The saved screen focus region was cleared."
        )
    }

    static func regionDescription(_ region: CGRect) -> String {
        "\(Int(region.origin.x)), \(Int(region.origin.y)), \(Int(region.width))x\(Int(region.height))"
    }
}

@MainActor
@Observable
final class FocusHighlightOverlay {
    static let shared = FocusHighlightOverlay()

    private var panel: NSPanel?
    private(set) var lastRegion: CGRect?
    private(set) var lastAnnotation: FocusMarkAnnotation?
    static let panelPolicy = FocusHighlightOverlayPanelPolicy.selection

    private init() {}

    func beginSelection(mode: FocusMarkMode = .rectangle) {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        Task { @MainActor in
            let backgroundImage = await AgentOverlaySnapshot.captureMainDisplay(screenFrame: screenFrame)
            presentSelection(mode: mode, screenFrame: screenFrame, backgroundImage: backgroundImage)
        }
    }

    private func presentSelection(mode: FocusMarkMode, screenFrame: CGRect, backgroundImage: NSImage?) {
        let view = FocusSelectionView(screenFrame: screenFrame, mode: mode, backgroundImage: backgroundImage) { [weak self] annotation in
            self?.completeSelection(annotation)
        } onCancel: { [weak self] in
            self?.hide()
        }

        let panel = FocusSelectionPanel(
            contentRect: screenFrame,
            styleMask: Self.panelPolicy.styleMask,
            backing: .buffered,
            defer: false
        )
        panel.onCancel = { [weak self] in
            self?.hide()
        }
        panel.title = "Voiyce Focus Highlight"
        Self.panelPolicy.apply(to: panel)
        panel.contentView = ClearOverlayHostingView(rootView: view)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func completeSelection(
        _ annotation: FocusMarkAnnotation,
        showGuide: Bool = true
    ) {
        completeSelection(annotation, eventStore: .shared, showGuide: showGuide)
    }

    func completeSelection(
        _ annotation: FocusMarkAnnotation,
        eventStore: AgentEventStore,
        showGuide: Bool = true
    ) {
        lastRegion = annotation.region
        lastAnnotation = annotation
        hide()
        if showGuide {
            Task {
                await AgentVisualGuideOverlay.shared.showFocusMark(annotation)
            }
        }
        FocusHighlightLog.appendMarked(annotation, to: eventStore)
    }

    func clear() {
        clear(eventStore: .shared)
    }

    func clear(eventStore: AgentEventStore) {
        lastRegion = nil
        lastAnnotation = nil
        hide()
        AgentVisualGuideOverlay.shared.clear()
        FocusHighlightLog.appendCleared(to: eventStore)
    }

    func clearForDisplayConfigurationChange(eventStore: AgentEventStore? = nil) {
        let hadFocusState = lastRegion != nil || lastAnnotation != nil || panel != nil
        lastRegion = nil
        lastAnnotation = nil
        hide()
        AgentVisualGuideOverlay.shared.clear()

        guard hadFocusState else { return }
        (eventStore ?? .shared).append(
            category: .memory,
            status: .cancelled,
            symbol: "display.2",
            title: "Focus region cleared after display change",
            summary: "Voiyce cleared the saved screen focus region because the display layout changed."
        )
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private final class FocusSelectionPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        super.keyDown(with: event)
    }
}

private struct FocusSelectionView: View {
    let screenFrame: CGRect
    let mode: FocusMarkMode
    let backgroundImage: NSImage?
    let onComplete: (FocusMarkAnnotation) -> Void
    let onCancel: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?
    @State private var points: [CGPoint] = []

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let backgroundImage {
                Image(nsImage: backgroundImage)
                    .resizable()
                    .frame(width: screenFrame.width, height: screenFrame.height)
                    .clipped()
            } else {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
            }

            Color.black.opacity(0.18)
                .ignoresSafeArea()

            if mode == .rectangle, let selection {
                rectangleSelection(selection)
            }

            if mode != .rectangle, points.count > 1 {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    Color(hex: 0xF8C04E),
                    style: StrokeStyle(
                        lineWidth: mode == .underline ? 6 : 5,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .shadow(color: Color(hex: 0xF8C04E).opacity(0.48), radius: 8)
            }

            HStack(spacing: 10) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xF8C04E))

                Text(mode.instruction)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
            }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.black.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(18)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = value.startLocation
                    }
                    dragEnd = value.location
                    if mode != .rectangle {
                        appendPoint(value.location)
                    }
                }
                .onEnded { value in
                    dragEnd = value.location
                    completeSelection()
                }
        )
        .onExitCommand {
            onCancel()
        }
    }

    @ViewBuilder
    private func rectangleSelection(_ selection: CGRect) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: selection.width, height: selection.height)
            .position(x: selection.midX, y: selection.midY)
            .overlay(
                Rectangle()
                    .stroke(Color(hex: 0xF8C04E), lineWidth: 2)
                    .frame(width: selection.width, height: selection.height)
                    .position(x: selection.midX, y: selection.midY)
            )
            .background(
                Rectangle()
                    .fill(Color(hex: 0xF8C04E).opacity(0.08))
                    .frame(width: selection.width, height: selection.height)
                    .position(x: selection.midX, y: selection.midY)
            )
    }

    private var selection: CGRect? {
        guard let dragStart, let dragEnd else { return nil }
        return CGRect(
            x: min(dragStart.x, dragEnd.x),
            y: min(dragStart.y, dragEnd.y),
            width: abs(dragEnd.x - dragStart.x),
            height: abs(dragEnd.y - dragStart.y)
        )
    }

    private func appendPoint(_ point: CGPoint) {
        guard let last = points.last else {
            points = [point]
            return
        }

        let distance = hypot(point.x - last.x, point.y - last.y)
        if distance >= 3 {
            points.append(point)
        }
    }

    private func completeSelection() {
        if mode == .rectangle {
            guard let dragStart,
                  let dragEnd,
                  let annotation = FocusHighlightGeometry.rectangleAnnotation(
                    screenFrame: screenFrame,
                    start: dragStart,
                    end: dragEnd
                  ) else {
                onCancel()
                return
            }

            onComplete(annotation)
            return
        }

        guard let annotation = FocusHighlightGeometry.freeformAnnotation(
            mode: mode,
            screenFrame: screenFrame,
            points: points
        ) else {
            onCancel()
            return
        }

        onComplete(annotation)
    }

}
#endif
