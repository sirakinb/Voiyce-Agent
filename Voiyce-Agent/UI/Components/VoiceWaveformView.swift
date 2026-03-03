//
//  VoiceWaveformView.swift
//  Voiyce-Agent
//

import SwiftUI

struct VoiceWaveformView: View {
    let isActive: Bool

    @State private var barHeights: [CGFloat] = [0.3, 0.3, 0.3, 0.3, 0.3]

    private let barCount = 5
    private let maxHeight: CGFloat = 32
    private let minHeight: CGFloat = 6
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.accent)
                    .frame(
                        width: barWidth,
                        height: isActive
                            ? barHeights[index] * maxHeight
                            : minHeight
                    )
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.5)
                            .delay(Double(index) * 0.05),
                        value: barHeights[index]
                    )
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.6),
                        value: isActive
                    )
            }
        }
        .frame(height: maxHeight)
        .onAppear {
            startAnimating()
        }
        .onChange(of: isActive) { _, active in
            if active {
                startAnimating()
            }
        }
    }

    private func startAnimating() {
        guard isActive else { return }
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            if !isActive {
                timer.invalidate()
                return
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                for i in 0..<barCount {
                    barHeights[i] = CGFloat.random(in: 0.2...1.0)
                }
            }
        }
    }
}
