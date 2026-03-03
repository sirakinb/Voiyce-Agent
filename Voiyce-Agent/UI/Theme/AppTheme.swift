//
//  AppTheme.swift
//  Voiyce-Agent
//

import SwiftUI

enum AppTheme {
    // Colors
    static let backgroundPrimary = Color(hex: 0x1C1C2E)
    static let backgroundSecondary = Color(hex: 0x2A2A3E)
    static let backgroundTertiary = Color(hex: 0x353548)
    static let accent = Color(hex: 0x5CE0D8)
    static let textPrimary = Color(hex: 0xE8E8F0)
    static let textSecondary = Color(hex: 0x8888A0)
    static let destructive = Color(hex: 0xFF6B6B)
    static let success = Color(hex: 0x6BCB77)
    static let warning = Color(hex: 0xFFD93D)

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
