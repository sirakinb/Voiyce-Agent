#if VOIYCE_PRO
import SwiftUI
import WebKit

struct RealtimeAgentView: View {
    @Environment(AppState.self) private var appState
    @State private var server = RealtimeAgentServer()
    @State private var agentBridge = RealtimeAgentBridge()
    @State private var videoDBMemory = VideoDBAgentMemory.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Realtime Agent")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("A desktop-hosted WebRTC voice agent using OpenAI Realtime, snapshot vision, and VideoDB session memory. Speak naturally; native tools handle apps, websites, text, clicks, keys, confirmations, Gmail, Calendar, and screen-aware context.")
                    .font(AppTheme.bodyFont)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            shortcutPanel
                .padding(.horizontal, 24)

            videoDBMemoryPanel
                .padding(.horizontal, 24)

            if let url = server.url {
                RealtimeAgentWebView(url: url, bridge: agentBridge)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.ridge, lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(server.lastError ?? "Starting local Realtime endpoint...")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GroovedBackground())
        .onAppear {
            server.start()
        }
        .onChange(of: appState.agentActivationNonce) { _, _ in
            agentBridge.connect()
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiyceAgentStopRequested)) { _ in
            agentBridge.stop()
        }
    }

    private var shortcutPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hold \(appState.agentHotkey) to talk to the Agent")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text("The Agent uses the same backend OpenAI key as dictation. Release \(appState.agentHotkey) to stop the Realtime session.")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var videoDBMemoryPanel: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(videoDBMemory.status == .running ? AppTheme.accent : AppTheme.textSecondary.opacity(0.6))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text("VideoDB Session Memory")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(videoDBMemory.lastError ?? videoDBMemory.lastEvent)
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(videoDBMemory.status.rawValue.capitalized)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.ridge, lineWidth: 1)
        )
    }
}

@MainActor
@Observable
final class RealtimeAgentBridge {
    weak var webView: WKWebView?
    private var pendingConnect = false

    func attach(_ webView: WKWebView) {
        self.webView = webView
        if pendingConnect {
            connect()
        }
    }

    func connect() {
        guard let webView else {
            pendingConnect = true
            return
        }

        pendingConnect = false
        Task {
            await VideoDBAgentMemory.shared.start()
            _ = try? await webView.evaluateJavaScript("window.voiyceAgentConnect && window.voiyceAgentConnect();")
        }
    }

    func stop() {
        pendingConnect = false
        webView?.evaluateJavaScript("window.voiyceAgentStop && window.voiyceAgentStop();")
        Task {
            await VideoDBAgentMemory.shared.stop()
        }
    }
}

struct RealtimeAgentWebView: NSViewRepresentable {
    let url: URL
    let bridge: RealtimeAgentBridge

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        bridge.attach(webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        private let bridge: RealtimeAgentBridge

        init(bridge: RealtimeAgentBridge) {
            self.bridge = bridge
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            bridge.attach(webView)
        }

        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.grant)
        }
    }
}
#endif
