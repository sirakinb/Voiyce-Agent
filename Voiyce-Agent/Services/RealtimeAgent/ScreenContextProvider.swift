#if VOIYCE_PRO
import AppKit
import CoreGraphics
import Foundation
import InsForge
import InsForgeAuth
import ScreenCaptureKit

@MainActor
final class ScreenContextProvider {
    private let client = InsForgeClientProvider.shared
    private let maxImageDimension: CGFloat = 1600
    private let jpegCompressionQuality: CGFloat = 0.72

    struct DisplayCandidate {
        let displayID: CGDirectDisplayID
        let frame: CGRect
    }

    func inspectScreen(prompt: String?) async -> AgentToolResult {
        await inspectImage(prompt: prompt, imageData: await captureMainDisplayJPEG(), missingImageMessage: "I could not capture the current screen even though Screen Recording appeared available.")
    }

    func inspectFocusedRegion(prompt: String?) async -> AgentToolResult {
        guard let region = FocusHighlightOverlay.shared.lastRegion else {
            return AgentToolResult(
                ok: false,
                message: "No focus region is marked yet. Use the focus highlight shortcut or Agent screen to mark part of the screen first.",
                data: Self.screenContextData(["requires": "focus_region"])
            )
        }

        return await inspectImage(
            prompt: prompt,
            imageData: await captureFocusedRegionJPEG(region: region),
            missingImageMessage: "I could not capture the marked focus region."
        )
    }

    private func inspectImage(prompt: String?, imageData: Data?, missingImageMessage: String) async -> AgentToolResult {
        guard hasScreenCaptureAccess() else {
            let message = "Screen Recording permission is required before I can inspect the screen."
            let nextStep = "Open Voiyce Settings > Permissions and click Grant for Screen Recording. If macOS already shows Voiyce as enabled but capture still fails, quit and reopen Voiyce so macOS refreshes the permission for this exact build."
            AgentEventStore.shared.appendPermissionBlock(
                feature: "Screen context",
                permission: "Screen Recording",
                message: message,
                nextStep: nextStep
            )
            return AgentToolResult(
                ok: false,
                message: message,
                data: [
                    "requires": "screen_recording_permission",
                    "next_step": nextStep
                ].merging(Self.screenContextData()) { current, _ in current }
            )
        }

        guard let imageData else {
            return AgentToolResult(
                ok: false,
                message: missingImageMessage,
                data: [
                    "next_step": "Toggle Voiyce off and on in Privacy & Security > Screen Recording, then quit and reopen Voiyce."
                ].merging(Self.screenContextData()) { current, _ in current }
            )
        }

        guard let session = try? await client.auth.getSession() else {
            return AgentToolResult(
                ok: false,
                message: "Authentication is required before I can inspect the screen.",
                data: Self.screenContextData(["requires": "auth"])
            )
        }

        do {
            let requestPayload = ScreenContextRequest(
                prompt: cleaned(prompt),
                imageBase64: imageData.base64EncodedString()
            )
            let body = try JSONEncoder().encode(requestPayload)
            var request = URLRequest(
                url: AppConstants.insForgeBaseURL
                    .appendingPathComponent("functions")
                    .appendingPathComponent("screen-context")
            )
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = body

            var (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return AgentToolResult(
                    ok: false,
                    message: ScreenContextRecoveryCopy.invalidResponse,
                    data: Self.screenContextData(["next_step": ScreenContextRecoveryCopy.serviceFailureNextStep(statusCode: nil)])
                )
            }

            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                let refreshed = try await client.auth.refreshAccessToken()
                guard let accessToken = refreshed.accessToken else {
                    return AgentToolResult(
                        ok: false,
                        message: "Authentication is required before I can inspect the screen.",
                        data: Self.screenContextData(["requires": "auth"])
                    )
                }

                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                (data, response) = try await URLSession.shared.data(for: request)
                guard let refreshedResponse = response as? HTTPURLResponse else {
                    return AgentToolResult(
                        ok: false,
                        message: ScreenContextRecoveryCopy.invalidResponse,
                        data: Self.screenContextData(["next_step": ScreenContextRecoveryCopy.serviceFailureNextStep(statusCode: nil)])
                    )
                }

                return decodeScreenContextResult(data: data, response: refreshedResponse)
            }

            return decodeScreenContextResult(data: data, response: httpResponse)
        } catch {
            return AgentToolResult(
                ok: false,
                message: ScreenContextRecoveryCopy.requestFailed,
                data: Self.screenContextData(["next_step": ScreenContextRecoveryCopy.serviceFailureNextStep(statusCode: nil)])
            )
        }
    }

    private func captureFocusedRegionJPEG(region: CGRect) async -> Data? {
        guard let capture = await captureDisplayImage(preferredRegion: region) else { return nil }
        let displayFrame = capture.displayFrame
        let imageSize = CGSize(width: capture.image.width, height: capture.image.height)

        guard let cropRect = Self.focusRegionCropRect(
                region: region,
                displayFrame: displayFrame,
                imageSize: imageSize
              ),
              cropRect.width > 2,
              cropRect.height > 2,
              let cropped = capture.image.cropping(to: cropRect) else {
            return nil
        }

        let image = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
        let resizedImage = resizeIfNeeded(image)
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: jpegCompressionQuality]
        )
    }

    private func decodeScreenContextResult(data: Data, response httpResponse: HTTPURLResponse) -> AgentToolResult {
        if (200..<300).contains(httpResponse.statusCode),
           let screenContext = try? JSONDecoder().decode(ScreenContextResponse.self, from: data) {
            return AgentToolResult(
                ok: true,
                message: screenContext.summary,
                data: [
                    "summary": screenContext.summary,
                    "visible_text": screenContext.visibleText,
                    "actionable_context": screenContext.actionableContext
                ].merging(Self.screenContextData()) { current, _ in current }
            )
        }

        let errorPayload = try? JSONDecoder().decode(ScreenContextErrorResponse.self, from: data)
        let displayMessage = ScreenContextRecoveryCopy.displayMessage(
            statusCode: httpResponse.statusCode,
            code: errorPayload?.code,
            serverDisplayMessage: errorPayload?.displayMessage,
            errorMessage: errorPayload?.error
        )
        let upstreamStatus = errorPayload?.upstreamStatus ?? httpResponse.statusCode
        AgentEventStore.shared.appendServiceFailure(
            feature: "Screen context",
            service: ScreenContextRecoveryCopy.serviceName,
            statusCode: upstreamStatus,
            message: displayMessage,
            nextStep: ScreenContextRecoveryCopy.serviceFailureNextStep(statusCode: upstreamStatus)
        )

        return AgentToolResult(
            ok: false,
            message: displayMessage,
            data: Self.screenContextData(["status": String(httpResponse.statusCode)])
        )
    }

    nonisolated static func screenContextData(_ values: [String: String] = [:]) -> [String: String] {
        values.merging([
            "memory_source": "current_screen",
            "context_scope": "current_screen",
            "context_kind": "screen_capture"
        ]) { current, _ in current }
    }

    func requestScreenCaptureAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func captureComputerScreenshot() async -> ComputerScreenshot? {
        guard hasScreenCaptureAccess() else {
            return nil
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = preferredComputerUseDisplay(from: content.displays) else {
                return nil
            }
            let displayFrame = CGDisplayBounds(display.displayID)

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = display.width
            configuration.height = display.height
            configuration.showsCursor = true
            configuration.capturesAudio = false

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return nil
            }

            return ComputerScreenshot(
                imageBase64: pngData.base64EncodedString(),
                width: cgImage.width,
                height: cgImage.height,
                displayID: display.displayID,
                displayFrame: displayFrame
            )
        } catch {
            return nil
        }
    }

    private func preferredComputerUseDisplay(from displays: [SCDisplay]) -> SCDisplay? {
        let mouseLocation = NSEvent.mouseLocation
        if let display = displays.first(where: { CGDisplayBounds($0.displayID).contains(mouseLocation) }) {
            return display
        }

        let mainDisplayID = CGMainDisplayID()
        return displays.first(where: { $0.displayID == mainDisplayID }) ?? displays.first
    }

    private func hasScreenCaptureAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    private func captureMainDisplayJPEG() async -> Data? {
        guard let capture = await captureDisplayImage() else { return nil }
        let image = NSImage(cgImage: capture.image, size: NSSize(width: capture.image.width, height: capture.image.height))
        let resizedImage = resizeIfNeeded(image)
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: jpegCompressionQuality]
        )
    }

    private func captureDisplayImage(preferredRegion: CGRect? = nil) async -> (image: CGImage, displayFrame: CGRect)? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let mainDisplayID = CGMainDisplayID()
            guard let display = Self.bestDisplay(
                from: content.displays,
                preferredRegion: preferredRegion,
                mainDisplayID: mainDisplayID
            ) else {
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = display.width
            configuration.height = display.height
            configuration.showsCursor = true
            configuration.capturesAudio = false

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )

            return (cgImage, CGDisplayBounds(display.displayID))
        } catch {
            return nil
        }
    }

    nonisolated static func bestDisplay(
        from candidates: [DisplayCandidate],
        preferredRegion: CGRect?,
        mainDisplayID: CGDirectDisplayID
    ) -> DisplayCandidate? {
        if let preferredRegion,
           !preferredRegion.isNull,
           !preferredRegion.isEmpty {
            var bestCandidate: DisplayCandidate?
            var bestArea: CGFloat = 0

            for candidate in candidates {
                let area = candidate.frame.intersection(preferredRegion).area
                if area > bestArea || (area == bestArea && area > 0 && candidate.displayID == mainDisplayID) {
                    bestArea = area
                    bestCandidate = candidate
                }
            }

            if bestArea > 0 {
                return bestCandidate
            }
        }

        return candidates.first(where: { $0.displayID == mainDisplayID }) ?? candidates.first
    }

    private nonisolated static func bestDisplay(
        from displays: [SCDisplay],
        preferredRegion: CGRect?,
        mainDisplayID: CGDirectDisplayID
    ) -> SCDisplay? {
        let candidates = displays.map {
            DisplayCandidate(displayID: $0.displayID, frame: CGDisplayBounds($0.displayID))
        }
        guard let selected = bestDisplay(
            from: candidates,
            preferredRegion: preferredRegion,
            mainDisplayID: mainDisplayID
        ) else {
            return nil
        }

        return displays.first(where: { $0.displayID == selected.displayID })
    }

    nonisolated static func focusRegionCropRect(
        region: CGRect,
        displayFrame: CGRect,
        imageSize: CGSize
    ) -> CGRect? {
        guard displayFrame.width > 0,
              displayFrame.height > 0,
              imageSize.width > 0,
              imageSize.height > 0 else {
            return nil
        }

        let boundedRegion = region.intersection(displayFrame)
        guard !boundedRegion.isNull,
              boundedRegion.width > 0,
              boundedRegion.height > 0 else {
            return nil
        }

        let scaleX = imageSize.width / displayFrame.width
        let scaleY = imageSize.height / displayFrame.height
        let imageBounds = CGRect(origin: .zero, size: imageSize)
        let cropRect = CGRect(
            x: (boundedRegion.minX - displayFrame.minX) * scaleX,
            y: (displayFrame.maxY - boundedRegion.maxY) * scaleY,
            width: boundedRegion.width * scaleX,
            height: boundedRegion.height * scaleY
        ).integral
            .intersection(imageBounds)

        guard !cropRect.isNull,
              cropRect.width > 0,
              cropRect.height > 0 else {
            return nil
        }

        return cropRect
    }

    private func resizeIfNeeded(_ image: NSImage) -> NSImage {
        let width = image.size.width
        let height = image.size.height
        let longestSide = max(width, height)

        guard longestSide > maxImageDimension else {
            return image
        }

        let scale = maxImageDimension / longestSide
        let targetSize = NSSize(width: width * scale, height: height * scale)
        let resized = NSImage(size: targetSize)

        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        resized.unlockFocus()

        return resized
    }

    private func cleaned(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}

struct ComputerScreenshot {
    let imageBase64: String
    let width: Int
    let height: Int
    let displayID: CGDirectDisplayID?
    let displayFrame: CGRect?

    init(
        imageBase64: String,
        width: Int,
        height: Int,
        displayID: CGDirectDisplayID? = nil,
        displayFrame: CGRect? = nil
    ) {
        self.imageBase64 = imageBase64
        self.width = width
        self.height = height
        self.displayID = displayID
        self.displayFrame = displayFrame
    }
}

private struct ScreenContextRequest: Encodable {
    let prompt: String?
    let imageBase64: String
}

private struct ScreenContextResponse: Decodable {
    let summary: String
    let visibleText: String
    let actionableContext: String
}

private struct ScreenContextErrorResponse: Decodable {
    let error: String?
    let code: String?
    let displayMessage: String?
    let upstreamStatus: Int?
}

enum ScreenContextRecoveryCopy {
    static let serviceName = "Screen context service"
    static let accountUsageLimit = "This account has reached its current screen context limit."
    static let invalidResponse = "Screen context received an unexpected response. Try again, then export Agent Log if it keeps happening."
    static let requestFailed = "Screen context could not inspect the screen. Check your internet connection, then try again."

    static func displayMessage(
        statusCode: Int?,
        code: String?,
        serverDisplayMessage: String?,
        errorMessage: String?
    ) -> String {
        if BackendUsageLimitCopy.isUsageLimit(statusCode: statusCode, code: code, message: errorMessage) {
            return accountUsageLimit
        }

        if let serverDisplayMessage, !serverDisplayMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return serverDisplayMessage
        }

        if statusCode == 429 {
            return "Screen context is temporarily rate-limited. Try again later."
        }

        return "Screen context could not inspect the screen. Try again, then contact support if it keeps happening."
    }

    static func serviceFailureNextStep(statusCode: Int?) -> String {
        if BackendUsageLimitCopy.isUsageLimit(statusCode: statusCode) {
            return BackendUsageLimitCopy.nextStep
        }

        if statusCode == 429 {
            return "Try again later. If this blocks your work, export Agent Log and send it to support."
        }

        return "Try screen context again. If it keeps failing, export Agent Log and send it to support."
    }
}

private extension CGRect {
    nonisolated var area: CGFloat {
        guard !isNull,
              width > 0,
              height > 0 else {
            return 0
        }

        return width * height
    }
}
#endif
