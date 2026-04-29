//
//  AppConstants.swift
//  Voiyce-Agent
//

import Foundation

enum AppConstants {
    static let keychainServiceName = "com.voiyce.agent"
    static let onboardingCompleteKey = "onboarding_complete"
    static let onboardingDiscoverySourceKey = "onboarding_discovery_source"
    static let onboardingRoleKey = "onboarding_role"
    static let onboardingPrivacyPreferenceKey = "onboarding_privacy_preference"
    static let insForgeBaseURL = URL(string: "https://25565ha3.us-east.insforge.app")!
    static let insForgeAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3OC0xMjM0LTU2NzgtOTBhYi1jZGVmMTIzNDU2NzgiLCJlbWFpbCI6ImFub25AaW5zZm9yZ2UuY29tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0OTU3NzZ9.TNf0vhTmcr7vDUf5v9-ovbpLT6MAIbUOWJe2PMXMACg"
    static let insForgeRedirectScheme = "voiyceagent"
    static let insForgeRedirectURL = URL(string: "\(insForgeRedirectScheme)://auth/callback")!
    static let billingCallbackHost = "billing"
    static let billingCallbackURL = URL(string: "\(insForgeRedirectScheme)://\(billingCallbackHost)/refresh")!
    static let freeWordLimit = 2500
    static let trialLengthDays = 7
    static let averageTypingWordsPerMinute = 45
    static let proMonthlyPriceDisplay = "$12/month"
    static let proYearlyPriceDisplay = "$120/year"
    static let proYearlyEffectiveMonthlyPriceDisplay = "$10/month"
    static let maxDictationDuration: TimeInterval = 55

    static func bundledResourceURL(named name: String, fileExtension: String) -> URL? {
        if let directURL = Bundle.main.url(forResource: name, withExtension: fileExtension) {
            return directURL
        }

        if let nestedURL = Bundle.main.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Resources"
        ) {
            return nestedURL
        }

        guard let resourcesDirectory = Bundle.main.resourceURL?.appendingPathComponent("Resources", isDirectory: true) else {
            return nil
        }

        let fallbackURL = resourcesDirectory.appendingPathComponent("\(name).\(fileExtension)")
        return FileManager.default.fileExists(atPath: fallbackURL.path) ? fallbackURL : nil
    }
}
