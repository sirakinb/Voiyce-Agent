//
//  OwlOverlayPanel.swift
//  Voiyce-Agent
//
//  Floating owl video that appears during dictation with background removed.
//

import AppKit
import AVFoundation
import CoreImage
import SwiftUI

final class OwlOverlayPanel {
    private var panel: NSPanel?
    private var player: AVPlayer?
    private var playerLooper: Any?  // holds strong ref to observer
    private var renderView: ChromaKeyVideoView?

    func show() {
        guard panel == nil else { return }

        guard let url = AppConstants.bundledResourceURL(named: "talking_voice_owl", fileExtension: "mp4") else {
            print("[OwlOverlay] talking_voice_owl.mp4 not found in bundle")
            return
        }

        let size = NSSize(width: 200, height: 200)

        // Detect background color from first frame
        let asset = AVURLAsset(url: url)
        let bgColor = detectBackgroundColor(asset: asset)
        print("[OwlOverlay] Detected background: \(bgColor)")

        // Set up player with video output
        let item = AVPlayerItem(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
        item.add(output)

        let avPlayer = AVPlayer(playerItem: item)
        self.player = avPlayer

        // Loop: observe when playback ends and seek back to start
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak avPlayer] _ in
            avPlayer?.seek(to: .zero)
            avPlayer?.play()
        }
        self.playerLooper = observer

        // Create rendering view
        let view = ChromaKeyVideoView(frame: NSRect(origin: .zero, size: size))
        view.videoOutput = output
        view.targetBgColor = bgColor
        view.buildFilter()
        view.wantsLayer = true
        view.layer?.cornerRadius = 100
        view.layer?.masksToBounds = true
        self.renderView = view

        // Create panel
        let overlayPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        overlayPanel.isOpaque = false
        overlayPanel.backgroundColor = .clear
        overlayPanel.hasShadow = false
        overlayPanel.level = .floating
        overlayPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayPanel.isMovableByWindowBackground = true
        overlayPanel.contentView = view

        // Position bottom-right
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - size.width - 24
            let y = screenFrame.minY + 24
            overlayPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        overlayPanel.orderFrontRegardless()
        avPlayer.play()
        view.startRendering()

        // Pop-in animation
        overlayPanel.alphaValue = 0
        overlayPanel.setFrame(
            overlayPanel.frame.insetBy(dx: 20, dy: 20),
            display: false
        )
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            overlayPanel.animator().alphaValue = 1
            overlayPanel.animator().setFrame(
                overlayPanel.frame.insetBy(dx: -20, dy: -20),
                display: true
            )
        }

        self.panel = overlayPanel
    }

    func showProcessing() {
        let size = NSSize(width: 260, height: 92)
        let view = NSHostingView(rootView: ProcessingOverlayView())
        view.frame = NSRect(origin: .zero, size: size)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        stopVideoRendering()

        if let panel {
            panel.contentView = view
            panel.setContentSize(size)
            position(panel, size: size)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            return
        }

        let overlayPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        overlayPanel.isOpaque = false
        overlayPanel.backgroundColor = .clear
        overlayPanel.hasShadow = true
        overlayPanel.level = .floating
        overlayPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlayPanel.isMovableByWindowBackground = true
        overlayPanel.contentView = view
        position(overlayPanel, size: size)
        overlayPanel.orderFrontRegardless()

        overlayPanel.alphaValue = 0
        overlayPanel.setFrame(
            overlayPanel.frame.insetBy(dx: 12, dy: 12),
            display: false
        )
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            overlayPanel.animator().alphaValue = 1
            overlayPanel.animator().setFrame(
                overlayPanel.frame.insetBy(dx: -12, dy: -12),
                display: true
            )
        }

        self.panel = overlayPanel
    }

    func hide() {
        guard let panel = panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.stopVideoRendering()
            panel.orderOut(nil)
            self?.panel = nil
        })
    }

    var isVisible: Bool { panel != nil }

    // MARK: - Background Detection

    private func detectBackgroundColor(asset: AVAsset) -> NSColor {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

        guard let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) else {
            print("[OwlOverlay] Could not generate image from asset")
            return .black
        }

        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else { return .black }

        guard let context = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .black }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = context.data else { return .black }
        let ptr = data.bindMemory(to: UInt8.self, capacity: w * h * 4)

        // Sample corners and edges
        let corners = [
            (0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
            (w / 4, 0), (3 * w / 4, 0), (0, h / 2), (w - 1, h / 2)
        ]

        var rT = 0, gT = 0, bT = 0
        for (x, y) in corners {
            let off = (y * w + x) * 4
            rT += Int(ptr[off])
            gT += Int(ptr[off + 1])
            bT += Int(ptr[off + 2])
        }
        let n = CGFloat(corners.count)
        let color = NSColor(
            red: CGFloat(rT) / n / 255,
            green: CGFloat(gT) / n / 255,
            blue: CGFloat(bT) / n / 255,
            alpha: 1
        )
        print("[OwlOverlay] BG color: R=\(rT/corners.count) G=\(gT/corners.count) B=\(bT/corners.count)")
        return color
    }

    private func position(_ panel: NSPanel, size: NSSize) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - size.width - 24
        let y = screenFrame.minY + 24
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func stopVideoRendering() {
        renderView?.stopRendering()
        player?.pause()
        if let obs = playerLooper {
            NotificationCenter.default.removeObserver(obs)
        }
        player = nil
        playerLooper = nil
        renderView = nil
    }
}

private struct ProcessingOverlayView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.16))
                    .frame(width: 48, height: 48)

                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .scaleEffect(isAnimating ? 1.12 : 0.92)
                    .opacity(isAnimating ? 1 : 0.72)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Processing...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Transcribing your audio")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)

            ProgressView()
                .controlSize(.small)
                .tint(AppTheme.accent)
        }
        .padding(.horizontal, 16)
        .frame(width: 260, height: 92)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.backgroundSecondary.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.24), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Chroma Key Video View

final class ChromaKeyVideoView: NSView {
    var videoOutput: AVPlayerItemVideoOutput?
    var targetBgColor: NSColor = .black

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var colorCubeFilter: CIFilter?
    private var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func buildFilter() {
        colorCubeFilter = buildChromaKeyCube(targetColor: targetBgColor, tolerance: 0.35)
    }

    func startRendering() {
        // Use a timer at ~30fps for reliable frame delivery
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.renderFrame()
        }
    }

    func stopRendering() {
        timer?.invalidate()
        timer = nil
    }

    private func renderFrame() {
        guard let output = videoOutput else { return }

        let time = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: time),
              let pixelBuffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else {
            return
        }

        var image = CIImage(cvPixelBuffer: pixelBuffer)

        if let filter = colorCubeFilter {
            filter.setValue(image, forKey: kCIInputImageKey)
            if let result = filter.outputImage {
                image = result
            }
        }

        // Scale to fit view
        let extent = image.extent
        let scaleX = bounds.width / extent.width
        let scaleY = bounds.height / extent.height
        let scale = min(scaleX, scaleY)

        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let dx = (bounds.width - scaled.extent.width) / 2 - scaled.extent.origin.x
        let dy = (bounds.height - scaled.extent.height) / 2 - scaled.extent.origin.y
        let final_ = scaled.transformed(by: CGAffineTransform(translationX: dx, y: dy))

        if let cgImage = ciContext.createCGImage(final_, from: CGRect(origin: .zero, size: bounds.size)) {
            layer?.contents = cgImage
        }
    }

    // MARK: - Color Cube

    private func buildChromaKeyCube(targetColor: NSColor, tolerance: Float) -> CIFilter? {
        let rgb = targetColor.usingColorSpace(.deviceRGB) ?? targetColor
        let tR = Float(rgb.redComponent)
        let tG = Float(rgb.greenComponent)
        let tB = Float(rgb.blueComponent)

        let size = 64
        let count = size * size * size * 4
        var cubeData = [Float](repeating: 0, count: count)

        for z in 0..<size {
            let b = Float(z) / Float(size - 1)
            for y in 0..<size {
                let g = Float(y) / Float(size - 1)
                for x in 0..<size {
                    let r = Float(x) / Float(size - 1)
                    let offset = (z * size * size + y * size + x) * 4

                    let dist = sqrtf(
                        (r - tR) * (r - tR) +
                        (g - tG) * (g - tG) +
                        (b - tB) * (b - tB)
                    )

                    let alpha: Float
                    if dist < tolerance * 0.5 {
                        alpha = 0
                    } else if dist < tolerance {
                        alpha = (dist - tolerance * 0.5) / (tolerance * 0.5)
                    } else {
                        alpha = 1
                    }

                    cubeData[offset]     = r * alpha
                    cubeData[offset + 1] = g * alpha
                    cubeData[offset + 2] = b * alpha
                    cubeData[offset + 3] = alpha
                }
            }
        }

        let data = Data(bytes: cubeData, count: count * MemoryLayout<Float>.size)
        let filter = CIFilter(name: "CIColorCube")
        filter?.setValue(size, forKey: "inputCubeDimension")
        filter?.setValue(data, forKey: "inputCubeData")
        return filter
    }
}
