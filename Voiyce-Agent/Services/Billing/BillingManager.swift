import AppKit
import Foundation
import Observation
import InsForge
import InsForgeCore
import InsForgeDatabase
import InsForgeFunctions

/// Decoded from the backend billing status for internal compatibility. Voiyce is
/// sold only through Pentridge Labs, so plans are no longer surfaced or chosen in
/// the app — this type carries no user-facing display copy.
enum BillingPlan: String, CaseIterable, Identifiable, Decodable, Sendable {
    case monthly
    case yearly

    var id: String { rawValue }
}

struct BillingStatusSnapshot: Decodable, Sendable {
    let freeWordsLimit: Int
    let freeWordsUsed: Int
    let freeWordsRemaining: Int
    let hasActiveSubscription: Bool
    let subscriptionStatus: String
    let stripeCustomerID: String?
    let currentPeriodEnd: Date?
    let cancelAtPeriodEnd: Bool
    let trialEndsAt: Date?
    let needsSubscription: Bool
    let preferredPlan: BillingPlan?
    let activePlan: BillingPlan?
    let hasBetaAccess: Bool
    let betaMonthlySpendLimitUSD: Decimal
    let betaMonthlySpendUsedUSD: Decimal
    let betaMonthlySpendRemainingUSD: Decimal
    let betaMonthlyCapReached: Bool
    let pentridgeSubscriptionActive: Bool
    let pentridgeTier: String?
    let pentridgeWordLimit: Int
    let pentridgeWordsUsed: Int
    let pentridgeWordsRemaining: Int
    let pentridgeCapReached: Bool

    enum CodingKeys: String, CodingKey {
        case freeWordsLimit = "free_words_limit"
        case freeWordsUsed = "free_words_used"
        case freeWordsRemaining = "free_words_remaining"
        case hasActiveSubscription = "has_active_subscription"
        case subscriptionStatus = "subscription_status"
        case stripeCustomerID = "stripe_customer_id"
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case trialEndsAt = "trial_ends_at"
        case needsSubscription = "needs_subscription"
        case preferredPlan = "preferred_plan"
        case activePlan = "active_plan"
        case hasBetaAccess = "has_beta_access"
        case betaMonthlySpendLimitUSD = "beta_monthly_spend_limit_usd"
        case betaMonthlySpendUsedUSD = "beta_monthly_spend_used_usd"
        case betaMonthlySpendRemainingUSD = "beta_monthly_spend_remaining_usd"
        case betaMonthlyCapReached = "beta_monthly_cap_reached"
        case pentridgeSubscriptionActive = "pentridge_subscription_active"
        case pentridgeTier = "pentridge_tier"
        case pentridgeWordLimit = "pentridge_word_limit"
        case pentridgeWordsUsed = "pentridge_words_used"
        case pentridgeWordsRemaining = "pentridge_words_remaining"
        case pentridgeCapReached = "pentridge_cap_reached"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        freeWordsLimit = try container.decode(Int.self, forKey: .freeWordsLimit)
        freeWordsUsed = try container.decode(Int.self, forKey: .freeWordsUsed)
        freeWordsRemaining = try container.decode(Int.self, forKey: .freeWordsRemaining)
        hasActiveSubscription = try container.decode(Bool.self, forKey: .hasActiveSubscription)
        subscriptionStatus = try container.decode(String.self, forKey: .subscriptionStatus)
        stripeCustomerID = try container.decodeIfPresent(String.self, forKey: .stripeCustomerID)
        currentPeriodEnd = try container.decodeIfPresent(Date.self, forKey: .currentPeriodEnd)
        cancelAtPeriodEnd = try container.decode(Bool.self, forKey: .cancelAtPeriodEnd)
        trialEndsAt = try container.decodeIfPresent(Date.self, forKey: .trialEndsAt)
        needsSubscription = try container.decode(Bool.self, forKey: .needsSubscription)
        preferredPlan = try container.decodeIfPresent(BillingPlan.self, forKey: .preferredPlan)
        activePlan = try container.decodeIfPresent(BillingPlan.self, forKey: .activePlan)
        hasBetaAccess = try container.decodeIfPresent(Bool.self, forKey: .hasBetaAccess) ?? false
        betaMonthlySpendLimitUSD = try container.decodeIfPresent(Decimal.self, forKey: .betaMonthlySpendLimitUSD) ?? 20
        betaMonthlySpendUsedUSD = try container.decodeIfPresent(Decimal.self, forKey: .betaMonthlySpendUsedUSD) ?? 0
        betaMonthlySpendRemainingUSD = try container.decodeIfPresent(Decimal.self, forKey: .betaMonthlySpendRemainingUSD) ?? 20
        betaMonthlyCapReached = try container.decodeIfPresent(Bool.self, forKey: .betaMonthlyCapReached) ?? false
        pentridgeSubscriptionActive = try container.decodeIfPresent(Bool.self, forKey: .pentridgeSubscriptionActive) ?? false
        pentridgeTier = try container.decodeIfPresent(String.self, forKey: .pentridgeTier)
        pentridgeWordLimit = try container.decodeIfPresent(Int.self, forKey: .pentridgeWordLimit) ?? 0
        pentridgeWordsUsed = try container.decodeIfPresent(Int.self, forKey: .pentridgeWordsUsed) ?? 0
        pentridgeWordsRemaining = try container.decodeIfPresent(Int.self, forKey: .pentridgeWordsRemaining) ?? 0
        pentridgeCapReached = try container.decodeIfPresent(Bool.self, forKey: .pentridgeCapReached) ?? false
    }
}

private struct SyncBillingResponse: Decodable {
    let synced: Bool
    let hasSubscription: Bool
}

private struct PentridgeSubscriptionResponse: Decodable {
    let hasSubscription: Bool
    let tier: String?

    enum CodingKeys: String, CodingKey {
        case hasSubscription = "has_subscription"
        case tier
    }
}

@MainActor
@Observable
final class BillingManager {
    private let client = InsForgeClientProvider.shared

    var status: BillingStatusSnapshot?
    var isRefreshing = false
    var errorMessage: String?
    var infoMessage: String?

    var freeWordsUsed: Int {
        status?.freeWordsUsed ?? 0
    }

    var freeWordsRemaining: Int {
        max(status?.freeWordsRemaining ?? AppConstants.freeWordLimit, 0)
    }

    var hasActiveSubscription: Bool {
        status?.hasActiveSubscription ?? false
    }

    var hasBetaAccess: Bool {
        status?.hasBetaAccess ?? false
    }

    var betaMonthlyCapReached: Bool {
        status?.betaMonthlyCapReached ?? false
    }

    var hasPentridgeSubscription: Bool {
        status?.pentridgeSubscriptionActive ?? false
    }

    var pentridgeCapReached: Bool {
        status?.pentridgeCapReached ?? false
    }

    var pentridgeTier: String? {
        status?.pentridgeTier
    }

    var pentridgeTierDisplay: String {
        switch pentridgeTier {
        case "pro":
            return "Pro"
        case "standard":
            return "Standard"
        default:
            return "Unknown"
        }
    }

    var pentridgeWordLimitDisplay: String {
        guard let tier = pentridgeTier else { return "" }
        return tier == "pro" ? "Unlimited" : "10,000 words/month"
    }


    var requiresSubscription: Bool {
        // No snapshot yet (e.g. network failure at launch): fail closed so a
        // brand-new unlock is never granted without a billing check.
        guard let status else {
            return true
        }

        if status.pentridgeSubscriptionActive && !status.pentridgeCapReached {
            return false
        }

        if status.needsSubscription {
            return true
        }

        if status.hasBetaAccess && !status.betaMonthlyCapReached {
            return false
        }

        guard !status.hasActiveSubscription, let trialEndsAt = status.trialEndsAt else {
            return false
        }

        return Date() >= trialEndsAt
    }

    var isInTrial: Bool {
        !hasActiveSubscription && !requiresSubscription
    }

    var planTitle: String {
        if hasPentridgeSubscription {
            return "Voiyce Included \(pentridgeTierDisplay)"
        }

        if hasActiveSubscription {
            return "Voiyce Pro"
        }

        if requiresSubscription {
            return "Trial Ended"
        }

        return "Pro Trial"
    }

    var planSubtitle: String {
        if hasPentridgeSubscription {
            if pentridgeCapReached {
                return "Voiyce is included in your Pentridge Labs subscription, but you've used your 10,000 monthly words. Dictation resumes next month."
            }

            if pentridgeTier == "standard", let status {
                return "Voiyce is included in your Pentridge Labs subscription. \(status.pentridgeWordsRemaining) of 10,000 words left this month."
            }

            return "Voiyce is included in your Pentridge Labs subscription. \(pentridgeWordLimitDisplay) dictation."
        }

        if hasActiveSubscription {
            if cancelAtPeriodEnd, let renewalDateLabel {
                return "Voiyce Pro is active through \(renewalDateLabel). It ends at period close."
            }

            if let renewalDateLabel {
                return "Voiyce Pro is active. Renews on \(renewalDateLabel)."
            }

            return "Voiyce Pro is active."
        }

        if requiresSubscription {
            return "Your \(AppConstants.trialLengthDays)-day trial ended. Get Voiyce at Pentridge Labs to keep dictating."
        }

        return "\(freeWordsRemaining) of \(AppConstants.freeWordLimit) trial words remaining."
    }

    var primaryActionTitle: String {
        hasActiveSubscription ? "Manage on Pentridge Labs" : "Get Voiyce"
    }

    var paymentRequiredTitle: String {
        "Your Trial Has Ended"
    }

    var paymentRequiredDetail: String {
        "Voiyce is now part of the Pentridge suite. Get it at pentridgemedia.com/labs to keep dictating."
    }

    var inactiveTrialFooter: String {
        "Your trial ends after \(AppConstants.trialLengthDays) days or when you reach \(AppConstants.freeWordLimit) words, whichever comes first."
    }

    var canManageSubscription: Bool {
        hasActiveSubscription && !(status?.stripeCustomerID?.isEmpty ?? true)
    }

    var cancelAtPeriodEnd: Bool {
        status?.cancelAtPeriodEnd ?? false
    }

    private var renewalDateLabel: String? {
        guard let currentPeriodEnd else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: currentPeriodEnd)
    }

    private var currentPeriodEnd: Date? {
        status?.currentPeriodEnd
    }

    func reset() {
        status = nil
        errorMessage = nil
        infoMessage = nil
    }

    func accessState(isAuthenticated: Bool) -> AccessState {
        guard isAuthenticated else { return .signedOut }

        if AppConstants.isUITesting {
            return .active
        }

        if requiresSubscription {
            return .paymentRequired
        }

        return .active
    }

    func refreshStatus() async {
        guard !AppConstants.isUITesting else { return }
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            status = try await client.database
                .rpc("get_billing_status")
                .executeSingle()
            errorMessage = nil
        } catch let error as InsForgeError {
            if case .authenticationRequired = error {
                reset()
            } else {
                errorMessage = friendlyMessage(for: error)
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func checkPentridgeSubscription() async {
        guard !AppConstants.isUITesting else { return }

        do {
            let _: PentridgeSubscriptionResponse = try await client.functions.invoke("check-pentridge-subscription")
        } catch {
            print("[BillingManager] Pentridge subscription check failed.")
        }
    }

    func syncStatusWithStripe() async {
        errorMessage = nil

        do {
            let response: SyncBillingResponse = try await client.functions.invoke("sync-billing-status")
            if response.synced {
                infoMessage = response.hasSubscription
                    ? "Billing access refreshed."
                    : "Billing status refreshed."
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
        }

        await refreshStatus()
    }

    func recordWordUsage(_ wordCount: Int) async {
        guard wordCount > 0 else { return }

        do {
            status = try await client.database
                .rpc("record_word_usage", args: ["p_word_count": wordCount])
                .executeSingle()
            errorMessage = nil
        } catch {
            print("[BillingManager] Failed to record word usage.")
            errorMessage = "Couldn't update your free-word count just now. Try again in a moment."
        }
    }

    /// Voiyce is sold only through Pentridge Labs, so every purchase/upgrade/
    /// manage action opens that page in the browser instead of an in-app
    /// Stripe checkout or billing portal.
    func openPurchasePage() {
        clearMessages()

        do {
            try openExternalURL(from: AppConstants.pentridgeLabsPurchaseURL)
            infoMessage = "Opening Pentridge Labs in your browser."
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func handleCallback(_ url: URL, isAuthenticated: Bool) async {
        guard url.scheme?.lowercased() == AppConstants.insForgeRedirectScheme,
              url.host?.lowercased() == AppConstants.billingCallbackHost else {
            return
        }

        let state = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "state" })?
            .value?
            .lowercased()

        switch state {
        case "success":
            infoMessage = "Refreshing your access now."
        case "cancelled":
            infoMessage = "No changes made. Refreshing your access."
        default:
            infoMessage = "Refreshing your billing access."
        }

        if isAuthenticated {
            await syncStatusWithStripe()
        }
    }

    private func clearMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    private func openExternalURL(from rawURL: String) throws {
        guard let url = URL(string: rawURL) else {
            throw InsForgeError.unknown(BillingRecoveryCopy.checkoutLinkInvalid)
        }

        NSWorkspace.shared.open(url)
    }

    private func friendlyMessage(for error: Error) -> String {
        BillingRecoveryCopy.message(for: error)
    }
}

enum BillingRecoveryCopy {
    static let checkoutLinkInvalid = "Voiyce could not open Pentridge Labs. Try again, then contact support if it keeps happening."
    static let generic = "Billing could not update just now. Try again, then contact support if it keeps happening."

    static func message(for error: Error) -> String {
        guard let error = error as? InsForgeError else {
            if let urlError = error as? URLError,
               urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                return "Billing could not connect. Check your internet connection, then try again."
            }
            return generic
        }

        switch error {
        case .authenticationRequired, .unauthorized:
            return "Sign in before managing billing."
        case .networkError:
            return "Billing could not connect. Check your internet connection, then try again."
        case .validationError(let message), .conflict(let message):
            return sanitized(message, fallback: generic)
        case .httpError(let statusCode, let message, _, let nextActions):
            if statusCode == 401 || statusCode == 403 {
                return "Sign in before managing billing."
            }
            let combined = [message, nextActions].compactMap { $0 }.joined(separator: " ")
            return sanitized(combined, fallback: generic)
        case .missingConfiguration:
            return "Billing is not configured for this build. Contact support if this should be available."
        case .invalidURL, .invalidResponse, .decodingError, .encodingError, .notFound, .unknown:
            return generic
        }
    }

    private static func sanitized(_ message: String, fallback: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        let forbiddenTerms = [
            "HTTP", "backend", "server", "API", "token", "secret", "key",
            "OPENAI", "INSFORGE", "function", "database", "SQL", "Stripe"
        ]
        if forbiddenTerms.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
            return fallback
        }

        return trimmed
    }
}
