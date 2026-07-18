//
//  AppConstants.swift
//  Voiyce-Agent
//

import Foundation

enum AppConstants {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
            || ProcessInfo.processInfo.environment["VOIYCE_UI_TESTING"] == "1"
    }

    static var uiTestingForcesSignedOut: Bool {
        isUITesting && ProcessInfo.processInfo.environment["VOIYCE_UI_TEST_SIGNED_OUT"] == "1"
    }

    static var uiTestingForcesOffline: Bool {
        isUITesting && ProcessInfo.processInfo.environment["VOIYCE_UI_TEST_OFFLINE"] == "1"
    }

    static let keychainServiceName = "com.voiyce.agent"
    static let onboardingCompleteKey = "onboarding_complete"
    static let onboardingDiscoverySourceKey = "onboarding_discovery_source"
    static let onboardingRoleKey = "onboarding_role"
    static let onboardingPrivacyPreferenceKey = "onboarding_privacy_preference"
    static let demoVideoSeenKey = "demo_video_seen"
    static let insForgeBaseURL = URL(string: "https://25565ha3.us-east.insforge.app")!
    static let insForgeAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3OC0xMjM0LTU2NzgtOTBhYi1jZGVmMTIzNDU2NzgiLCJlbWFpbCI6ImFub25AaW5zZm9yZ2UuY29tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0OTU3NzZ9.TNf0vhTmcr7vDUf5v9-ovbpLT6MAIbUOWJe2PMXMACg"
    static let insForgeRedirectScheme = "voiyceagent"
    static let insForgeRedirectURL = URL(string: "\(insForgeRedirectScheme)://auth/callback")!
    static let billingCallbackHost = "billing"
    static let billingCallbackURL = URL(string: "\(insForgeRedirectScheme)://\(billingCallbackHost)/refresh")!
    #if VOIYCE_PRO
    static let googleOAuthClientIDKey = "google_oauth_client_id"
    static let googleOAuthClientSecretKey = "google_oauth_client_secret"
    static let googleOAuthTokenKey = "google_oauth_token"
    static let googleOAuthClientIDInfoKey = "GoogleOAuthClientID"
    static let googleOAuthClientSecretInfoKey = "GoogleOAuthClientSecret"
    static let googleOAuthScopes = [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/gmail.compose",
        "https://www.googleapis.com/auth/gmail.send",
        "https://www.googleapis.com/auth/calendar.freebusy",
        "https://www.googleapis.com/auth/calendar.events.readonly"
    ]
    #endif
    static let freeWordLimit = 2500
    static let trialLengthDays = 7
    static let averageTypingWordsPerMinute = 45
    static let proMonthlyPriceDisplay = "$12/month"
    static let proYearlyPriceDisplay = "$120/year"
    static let proYearlyEffectiveMonthlyPriceDisplay = "$10/month"
    static let maxDictationDuration: TimeInterval = 55
    static let supportEmail = "aki.b@pentridgemedia.com"

    #if VOIYCE_PRO
    static var googleOAuthClientID: String {
        firstUsableConfigValue(
            ProcessInfo.processInfo.environment["GOOGLE_OAUTH_CLIENT_ID"],
            Bundle.main.object(forInfoDictionaryKey: googleOAuthClientIDInfoKey) as? String,
            UserDefaults.standard.string(forKey: googleOAuthClientIDKey)
        )
    }

    static var googleOAuthClientSecret: String {
        firstUsableConfigValue(
            ProcessInfo.processInfo.environment["GOOGLE_OAUTH_CLIENT_SECRET"],
            Bundle.main.object(forInfoDictionaryKey: googleOAuthClientSecretInfoKey) as? String,
            UserDefaults.standard.string(forKey: googleOAuthClientSecretKey)
        )
    }
    #endif

    static func accountScopedKey(_ baseKey: String, userID: String?) -> String {
        guard let userID, !userID.isEmpty else { return baseKey }
        return "\(baseKey)_\(userID)"
    }

    private static func firstUsableConfigValue(_ values: String?...) -> String {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty, !trimmed.hasPrefix("$(") {
                return trimmed
            }
        }

        return ""
    }

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

enum BackendUsageLimitCopy {
    static let code = "usage_limit_reached"
    static let supportEmail = AppConstants.supportEmail
    static let detail = "This account has reached its current Voiyce usage limit."
    static let nextStep = "Try again later. If this seems wrong, email \(supportEmail) with the time it happened."

    static func isUsageLimit(statusCode: Int?, code responseCode: String? = nil, message: String? = nil) -> Bool {
        if statusCode == 402 {
            return true
        }

        if responseCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == code {
            return true
        }

        let normalized = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.contains("usage cap reached")
            || normalized.contains("monthly cap reached")
            || normalized.contains("daily cap reached")
            || normalized.contains("spend cap reached")
            || normalized.contains("usage limit reached")
            || normalized.contains("account limit reached")
            || normalized.contains("current usage limit")
    }
}
