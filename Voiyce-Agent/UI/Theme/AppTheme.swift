//
//  AppTheme.swift
//  Voiyce-Agent
//

import SwiftUI

enum AppTheme {
    // Colors — purple & black aesthetic
    static let backgroundPrimary = Color(hex: 0x0E0E10)
    static let backgroundSecondary = Color(hex: 0x1E1E22)
    static let backgroundTertiary = Color(hex: 0x222226)
    static let accent = Color(hex: 0x9B6DFF)
    static let textPrimary = Color(hex: 0xE8E8EC)
    static let textSecondary = Color(hex: 0x6B6B7B)
    static let destructive = Color(hex: 0xFF6B6B)
    static let success = Color(hex: 0x6BCB77)
    static let warning = Color(hex: 0xFFD93D)
    static let ridge = Color(hex: 0x2A2A2E)

    // Dimensions
    static let cornerRadius: CGFloat = 12
    static let sidebarWidth: CGFloat = 220
    static let cardPadding: CGFloat = 16
    static let spacing: CGFloat = 12

    // Fonts
    static let titleFont = Font.system(size: 20, weight: .semibold)
    static let headlineFont = Font.system(size: 16, weight: .medium)
    static let bodyFont = Font.system(size: 14, weight: .regular)
    static let captionFont = Font.system(size: 12, weight: .regular)
    static let monoFont = Font.system(size: 13, weight: .regular, design: .monospaced)
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Grooved Background

/// Subtle horizontal ridge texture over a dark background.
struct GroovedBackground: View {
    var base: Color = AppTheme.backgroundPrimary

    var body: some View {
        Canvas { context, size in
            // Fill base
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(base)
            )
            // Draw fine horizontal grooves
            let spacing: CGFloat = 4
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.white.opacity(0.018)))
                y += spacing
            }
        }
        .ignoresSafeArea()
    }
}
