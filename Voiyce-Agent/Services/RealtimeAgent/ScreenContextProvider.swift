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

    func inspectScreen(prompt: String?) async -> AgentToolResult {
        guard hasScreenCaptureAccess() else {
            return AgentToolResult(
                ok: false,
                message: "Screen Recording permission is required before I can inspect the screen.",
                data: [
                    "requires": "screen_recording_permission",
                    "next_step": "Open System Settings > Privacy & Security > Screen Recording and enable Voiyce."
                ]
            )
        }

        guard let imageData = await captureMainDisplayJPEG() else {
            return AgentToolResult(
                ok: false,
                message: "I could not capture the current screen.",
                data: nil
            )
        }

        guard let session = try? await client.auth.getSession() else {
            return AgentToolResult(
                ok: false,
                message: "Authentication is required before I can inspect the screen.",
                data: ["requires": "auth"]
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

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return AgentToolResult(ok: false, message: "Screen context service returned an invalid response.", data: nil)
            }

            if (200..<300).contains(httpResponse.statusCode),
               let screenContext = try? JSONDecoder().decode(ScreenContextResponse.self, from: data) {
                return AgentToolResult(
                    ok: true,
                    message: screenContext.summary,
                    data: [
                        "summary": screenContext.summary,
                        "visible_text": screenContext.visibleText,
                        "actionable_context": screenContext.actionableContext
                    ]
                )
            }

            let errorPayload = try? JSONDecoder().decode(ScreenContextErrorResponse.self, from: data)
            return AgentToolResult(
                ok: false,
                message: errorPayload?.error ?? "Screen context request failed with HTTP \(httpResponse.statusCode).",
                data: ["status": String(httpResponse.statusCode)]
            )
        } catch {
            return AgentToolResult(
                ok: false,
                message: "Screen context request failed: \(error.localizedDescription)",
                data: nil
            )
        }
    }

    func requestScreenCaptureAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    private func hasScreenCaptureAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    private func captureMainDisplayJPEG() async -> Data? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let mainDisplayID = CGMainDisplayID()
            guard let display = content.displays.first(where: { $0.displayID == mainDisplayID }) ?? content.displays.first else {
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
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            let resizedImage = resizeIfNeeded(image)
            guard let tiffData = resizedImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                return nil
            }

            return bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: jpegCompressionQuality]
            )
        } catch {
            return nil
        }
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
}
#endif
