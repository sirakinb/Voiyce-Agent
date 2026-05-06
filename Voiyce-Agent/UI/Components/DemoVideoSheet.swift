//
//  DemoVideoSheet.swift
//  Voiyce-Agent
//

import AVKit
import SwiftUI

struct DemoVideoSheet: View {
    let onClose: () -> Void

    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to Use Voiyce")
                        .font(AppTheme.titleFont)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Watch this quick walkthrough before you start dictating.")
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Group {
                if let player {
                    DemoPlayerView(player: player)
                        .onAppear {
                            player.play()
                        }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "play.slash.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(AppTheme.warning)

                        Text("The demo video could not be loaded.")
                            .font(AppTheme.bodyFont)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.backgroundSecondary)
                }
            }
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

            HStack {
                Spacer()

                Button("Done") {
                    onClose()
                }
                .font(AppTheme.bodyFont)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 760)
        .background(GroovedBackground())
        .onAppear {
            if let url = AppConstants.bundledResourceURL(named: "voiyce_demo", fileExtension: "mp4") {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
}

private struct DemoPlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .floating
        playerView.videoGravity = .resizeAspect
        playerView.player = player
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
