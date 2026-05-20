#if VOIYCE_PRO
import AppKit
import SwiftUI

final class ClearOverlayHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        window?.backgroundColor = .clear
        window?.isOpaque = false
    }
}

enum AgentOverlaySnapshot {
    static func captureMainDisplay(screenFrame: CGRect) async -> NSImage? {
        guard let screenshot = await ScreenContextProvider().captureComputerScreenshot(),
              let data = Data(base64Encoded: screenshot.imageBase64),
              let image = NSImage(data: data) else {
            return nil
        }

        image.size = screenFrame.size
        return image
    }
}

enum FocusMarkMode: String, CaseIterable {
    case rectangle
    case paint
    case underline

    var title: String {
        switch self {
        case .rectangle: return "Focus"
        case .paint: return "Paint"
        case .underline: return "Underline"
        }
    }

    var symbol: String {
        switch self {
        case .rectangle: return "viewfinder"
        case .paint: return "paintbrush"
        case .underline: return "underline"
        }
    }

    var instruction: String {
        switch self {
        case .rectangle:
            return "Drag a box around the part Voiyce should use. Press Esc to cancel."
        case .paint:
            return "Paint over the area Voiyce should understand. Press Esc to cancel."
        case .underline:
            return "Drag under the text or control Voiyce should focus on. Press Esc to cancel."
        }
    }
}

struct FocusMarkAnnotation {
    let mode: FocusMarkMode
    let screenFrame: CGRect
    let region: CGRect
    let points: [CGPoint]
}

struct AgentVisualGuideOverlayPanelPolicy {
    let styleMask: NSWindow.StyleMask
    let level: NSWindow.Level
    let isOpaque: Bool
    let hasShadow: Bool
    let hidesOnDeactivate: Bool
    let ignoresMouseEvents: Bool
    let collectionBehavior: NSWindow.CollectionBehavior

    static let passiveGuide = AgentVisualGuideOverlayPanelPolicy(
        styleMask: [.borderless, .nonactivatingPanel],
        level: .screenSaver,
        isOpaque: false,
        hasShadow: false,
        hidesOnDeactivate: false,
        ignoresMouseEvents: true,
        collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    )

    func apply(to panel: NSPanel) {
        panel.level = level
        panel.backgroundColor = .clear
        panel.isOpaque = isOpaque
        panel.hasShadow = hasShadow
        panel.hidesOnDeactivate = hidesOnDeactivate
        panel.ignoresMouseEvents = ignoresMouseEvents
        panel.collectionBehavior = collectionBehavior
    }
}

enum AgentGuideStyle: String {
    case spotlight
    case underline
    case callout
    case preview
}

@MainActor
final class AgentVisualGuideOverlay {
    static let shared = AgentVisualGuideOverlay()

    private var calloutPanel: NSPanel?
    private var highlightPanel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    static let panelPolicy = AgentVisualGuideOverlayPanelPolicy.passiveGuide

    private init() {}

    func showFocusMark(_ annotation: FocusMarkAnnotation, duration: TimeInterval = 2.6) async {
        let title: String
        let message: String
        switch annotation.mode {
        case .rectangle:
            title = "Focus marked"
            message = "Voiyce will use this area for the next screen-aware request."
        case .paint:
            title = "Paint focus saved"
            message = "Ask about this painted area or tell Voiyce what to change here."
        case .underline:
            title = "Underline saved"
            message = "Voiyce will treat this underlined item as the focus target."
        }

        await show(
            AgentGuideModel(
                title: title,
                message: message,
                symbol: annotation.mode.symbol,
                style: annotation.mode == .underline ? .underline : .spotlight,
                targetRect: annotation.region,
                pointer: nil,
                annotation: annotation,
                dimsBackground: false
            ),
            duration: duration
        )
    }

    func showPreview(
        title: String,
        message: String,
        targetRect: CGRect? = nil,
        pointer: CGPoint? = nil,
        duration: TimeInterval = 0.9
    ) async {
        await show(
            AgentGuideModel(
                title: title,
                message: message,
                symbol: "cursorarrow.motionlines",
                style: .preview,
                targetRect: targetRect,
                pointer: pointer,
                annotation: nil,
                dimsBackground: false
            ),
            duration: duration
        )
    }

    func showTour(
        title: String,
        message: String,
        targetRect: CGRect? = nil,
        pointer: CGPoint? = nil,
        style: AgentGuideStyle = .spotlight,
        duration: TimeInterval? = 8
    ) async {
        await show(
            AgentGuideModel(
                title: title.isEmpty ? "Voiyce Guide" : title,
                message: message,
                symbol: "sparkle.magnifyingglass",
                style: style,
                targetRect: targetRect,
                pointer: pointer,
                annotation: nil,
                dimsBackground: true
            ),
            duration: duration
        )
    }

    func clear() {
        dismissTask?.cancel()
        dismissTask = nil
        calloutPanel?.orderOut(nil)
        highlightPanel?.orderOut(nil)
    }

    private func show(_ model: AgentGuideModel, duration: TimeInterval?) async {
        dismissTask?.cancel()

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        showHighlight(for: model, screenFrame: screenFrame)
        showCallout(for: model, screenFrame: screenFrame)

        if let duration, duration > 0 {
            dismissTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await MainActor.run {
                    self?.clear()
                }
            }
        }
    }

    private func showCallout(for model: AgentGuideModel, screenFrame: CGRect) {
        let size = NSSize(width: 360, height: 124)
        let origin = calloutOrigin(for: model, size: size, screenFrame: screenFrame)
        let panel = ensureCalloutPanel(frame: NSRect(origin: origin, size: size))
        let hostingView = NSHostingView(rootView: AgentGuideCalloutView(model: model, size: size))
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.82).cgColor
        hostingView.layer?.cornerRadius = 12
        panel.contentView = hostingView
        panel.orderFrontRegardless()
    }

    private func showHighlight(for model: AgentGuideModel, screenFrame: CGRect) {
        guard let frame = highlightFrame(for: model, screenFrame: screenFrame) else {
            highlightPanel?.orderOut(nil)
            return
        }

        let panel = ensureHighlightPanel(frame: frame)
        let hostingView = NSHostingView(rootView: AgentGuideHighlightView(model: model, panelFrame: frame))
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.orderFrontRegardless()
    }

    private func ensureCalloutPanel(frame: CGRect) -> NSPanel {
        if let calloutPanel {
            calloutPanel.setFrame(frame, display: true)
            return calloutPanel
        }

        let panel = AgentGuidePanel(
            contentRect: frame,
            styleMask: Self.panelPolicy.styleMask,
            backing: .buffered,
            defer: false
        )
        panel.title = "Voiyce Guide"
        Self.panelPolicy.apply(to: panel)
        self.calloutPanel = panel
        return panel
    }

    private func ensureHighlightPanel(frame: CGRect) -> NSPanel {
        if let highlightPanel {
            highlightPanel.setFrame(frame, display: true)
            return highlightPanel
        }

        let panel = AgentGuidePanel(
            contentRect: frame,
            styleMask: Self.panelPolicy.styleMask,
            backing: .buffered,
            defer: false
        )
        panel.title = "Voiyce Guide Highlight"
        Self.panelPolicy.apply(to: panel)
        self.highlightPanel = panel
        return panel
    }

    private func highlightFrame(for model: AgentGuideModel, screenFrame: CGRect) -> CGRect? {
        let rect = model.targetRect ?? model.annotation?.region
        guard let rect else {
            if let pointer = model.pointer {
                return clamp(
                    CGRect(x: pointer.x - 30, y: pointer.y - 30, width: 60, height: 60),
                    within: screenFrame
                )
            }
            return nil
        }

        return clamp(rect.insetBy(dx: -18, dy: -18), within: screenFrame)
    }

    private func calloutOrigin(for model: AgentGuideModel, size: NSSize, screenFrame: CGRect) -> CGPoint {
        guard let anchor = anchorPoint(for: model) else {
            return CGPoint(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.maxY - size.height - 86
            )
        }

        let proposedX = anchor.x < screenFrame.midX ? anchor.x + 34 : anchor.x - size.width - 34
        let proposedY = anchor.y - size.height / 2
        return CGPoint(
            x: min(max(proposedX, screenFrame.minX + 18), screenFrame.maxX - size.width - 18),
            y: min(max(proposedY, screenFrame.minY + 18), screenFrame.maxY - size.height - 42)
        )
    }

    private func anchorPoint(for model: AgentGuideModel) -> CGPoint? {
        if let pointer = model.pointer {
            return pointer
        }
        if let rect = model.targetRect {
            return CGPoint(x: rect.midX, y: rect.midY)
        }
        if let annotation = model.annotation {
            return CGPoint(x: annotation.region.midX, y: annotation.region.midY)
        }
        return nil
    }

    private func clamp(_ rect: CGRect, within screenFrame: CGRect) -> CGRect {
        let width = min(rect.width, screenFrame.width)
        let height = min(rect.height, screenFrame.height)
        return CGRect(
            x: min(max(rect.minX, screenFrame.minX), screenFrame.maxX - width),
            y: min(max(rect.minY, screenFrame.minY), screenFrame.maxY - height),
            width: width,
            height: height
        )
    }
}

private struct AgentGuideModel {
    let title: String
    let message: String
    let symbol: String
    let style: AgentGuideStyle
    let targetRect: CGRect?
    let pointer: CGPoint?
    let annotation: FocusMarkAnnotation?
    let dimsBackground: Bool
}

private final class AgentGuidePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct AgentGuideCalloutView: View {
    let model: AgentGuideModel
    let size: NSSize

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: model.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: 0xF8C04E))
                .frame(width: 32, height: 32)
                .background(Color(hex: 0xF8C04E).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0xF8C04E).opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 5) {
                Text(model.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                if !model.message.isEmpty {
                    Text(model.message)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(.black.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xF8C04E).opacity(0.46), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 18, y: 8)
    }
}

private struct AgentGuideHighlightView: View {
    let model: AgentGuideModel
    let panelFrame: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            if let annotation = model.annotation, !annotation.points.isEmpty {
                annotationPath(annotation)
                    .stroke(
                        Color(hex: 0xF8C04E),
                        style: StrokeStyle(
                            lineWidth: annotation.mode == .underline ? 6 : 5,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .shadow(color: Color(hex: 0xF8C04E).opacity(0.58), radius: 9)
            } else if let targetRect = model.targetRect ?? model.annotation?.region {
                highlight(for: targetRect)
            } else if let pointer = model.pointer {
                Circle()
                    .stroke(Color(hex: 0xF8C04E), lineWidth: 3)
                    .frame(width: 42, height: 42)
                    .position(localPoint(pointer))
                    .shadow(color: Color(hex: 0xF8C04E).opacity(0.5), radius: 10)
            }
        }
        .frame(width: panelFrame.width, height: panelFrame.height)
    }

    @ViewBuilder
    private func highlight(for rect: CGRect) -> some View {
        let local = localRect(rect)
        switch model.style {
        case .underline:
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: 0xF8C04E))
                .frame(width: max(local.width, 36), height: 5)
                .position(x: local.midX, y: local.maxY + 7)
                .shadow(color: Color(hex: 0xF8C04E).opacity(0.65), radius: 8)
        case .callout:
            Circle()
                .stroke(Color(hex: 0xF8C04E), lineWidth: 3)
                .frame(width: max(local.width, 46), height: max(local.height, 46))
                .position(x: local.midX, y: local.midY)
                .shadow(color: Color(hex: 0xF8C04E).opacity(0.52), radius: 10)
        case .spotlight, .preview:
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xF8C04E).opacity(model.style == .preview ? 0.11 : 0.14))
                .frame(width: max(local.width, 32), height: max(local.height, 32))
                .position(x: local.midX, y: local.midY)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: 0xF8C04E), lineWidth: model.style == .preview ? 2 : 3)
                        .frame(width: max(local.width, 32), height: max(local.height, 32))
                        .position(x: local.midX, y: local.midY)
                )
                .shadow(color: Color(hex: 0xF8C04E).opacity(0.42), radius: 12)
        }
    }

    private func annotationPath(_ annotation: FocusMarkAnnotation) -> Path {
        var path = Path()
        let points = annotation.points.map(localPoint)
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func localRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX - panelFrame.minX,
            y: panelFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func localPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x - panelFrame.minX,
            y: panelFrame.maxY - point.y
        )
    }
}

private struct AgentGuideOverlayView: View {
    let model: AgentGuideModel
    let screenFrame: CGRect
    let backgroundImage: NSImage?

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

            Color.black.opacity(model.dimsBackground ? 0.16 : 0.04)
                .ignoresSafeArea()

            if let annotation = model.annotation, !annotation.points.isEmpty {
                annotationPath(annotation)
                    .stroke(
                        Color(hex: 0xF8C04E),
                        style: StrokeStyle(
                            lineWidth: annotation.mode == .underline ? 6 : 4,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .shadow(color: Color(hex: 0xF8C04E).opacity(0.45), radius: 8)
            }

            if let targetRect = model.targetRect {
                guideHighlight(for: targetRect)
            }

            if let anchor = anchorPoint {
                Path { path in
                    path.move(to: calloutAnchor)
                    path.addLine(to: localPoint(anchor))
                }
                .stroke(Color(hex: 0xF8C04E).opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            }

            callout
                .position(calloutPosition)
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
    }

    private var callout: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: model.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(hex: 0xF8C04E))
                .frame(width: 30, height: 30)
                .background(Color(hex: 0xF8C04E).opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: 0xF8C04E).opacity(0.24), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                if !model.message.isEmpty {
                    Text(model.message)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 330)
        .background(.black.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xF8C04E).opacity(0.38), lineWidth: 1))
        .shadow(color: .black.opacity(0.42), radius: 22, y: 10)
    }

    @ViewBuilder
    private func guideHighlight(for rect: CGRect) -> some View {
        let local = localRect(rect)
        switch model.style {
        case .underline:
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: 0xF8C04E))
                .frame(width: max(local.width, 36), height: 5)
                .position(x: local.midX, y: local.maxY + 7)
                .shadow(color: Color(hex: 0xF8C04E).opacity(0.6), radius: 8)
        case .callout:
            Circle()
                .stroke(Color(hex: 0xF8C04E), lineWidth: 3)
                .frame(width: max(local.width, 42), height: max(local.height, 42))
                .position(x: local.midX, y: local.midY)
                .shadow(color: Color(hex: 0xF8C04E).opacity(0.5), radius: 10)
        case .spotlight, .preview:
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: 0xF8C04E).opacity(model.style == .preview ? 0.07 : 0.10))
                .frame(width: local.width, height: local.height)
                .position(x: local.midX, y: local.midY)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: 0xF8C04E), lineWidth: model.style == .preview ? 2 : 3)
                        .frame(width: local.width, height: local.height)
                        .position(x: local.midX, y: local.midY)
                )
                .shadow(color: Color(hex: 0xF8C04E).opacity(0.35), radius: 12)
        }
    }

    private func annotationPath(_ annotation: FocusMarkAnnotation) -> Path {
        var path = Path()
        let points = annotation.points.map(localPoint)
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private var anchorPoint: CGPoint? {
        if let pointer = model.pointer {
            return pointer
        }
        if let rect = model.targetRect {
            return CGPoint(x: rect.midX, y: rect.midY)
        }
        if let annotation = model.annotation {
            return CGPoint(x: annotation.region.midX, y: annotation.region.midY)
        }
        return nil
    }

    private var calloutPosition: CGPoint {
        guard let anchorPoint else {
            return CGPoint(x: min(screenFrame.width - 190, max(190, screenFrame.width * 0.72)), y: 118)
        }

        let local = localPoint(anchorPoint)
        let preferredX = local.x + (local.x < screenFrame.width * 0.62 ? 210 : -210)
        let preferredY = local.y > 150 ? local.y - 84 : local.y + 118
        return CGPoint(
            x: min(max(preferredX, 185), screenFrame.width - 185),
            y: min(max(preferredY, 80), screenFrame.height - 80)
        )
    }

    private var calloutAnchor: CGPoint {
        CGPoint(x: calloutPosition.x, y: calloutPosition.y + 38)
    }

    private func localRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX - screenFrame.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private func localPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x - screenFrame.minX,
            y: screenFrame.maxY - point.y
        )
    }
}
#endif
