import AppKit
import Foundation
import Observation
import InsForge
import InsForgeCore
import InsForgeDatabase
import InsForgeFunctions

enum BillingPlan: String, CaseIterable, Identifiable, Decodable, Sendable {
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly:
            return "Pro Monthly"
        case .yearly:
            return "Pro Yearly"
        }
    }

    var priceDisplay: String {
        switch self {
        case .monthly:
            return AppConstants.proMonthlyPriceDisplay
        case .yearly:
            return AppConstants.proYearlyPriceDisplay
        }
    }

    var subtitle: String {
        switch self {
        case .monthly:
            return "Unlimited dictation with flexible monthly billing."
        case .yearly:
            return "Unlimited dictation for the year at \(AppConstants.proYearlyEffectiveMonthlyPriceDisplay) effective."
        }
    }

    var badge: String? {
        switch self {
        case .monthly:
            return nil
        case .yearly:
            return "Best value"
        }
    }
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
    }
}

private struct BillingURLResponse: Decodable {
    let url: String
}

private struct SyncBillingResponse: Decodable {
    let synced: Bool
    let hasSubscription: Bool
}

@MainActor
@Observable
final class BillingManager {
    private let client = InsForgeClientProvider.shared

    var status: BillingStatusSnapshot?
    var isRefreshing = false
    var isOpeningCheckout = false
    var isOpeningPortal = false
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

    var betaMonthlySpendRemainingDisplay: String {
        currencyDisplay(status?.betaMonthlySpendRemainingUSD ?? 0)
    }

    var betaMonthlySpendUsedDisplay: String {
        currencyDisplay(status?.betaMonthlySpendUsedUSD ?? 0)
    }

    var betaMonthlySpendLimitDisplay: String {
        currencyDisplay(status?.betaMonthlySpendLimitUSD ?? 20)
    }

    var preferredPlan: BillingPlan? {
        status?.preferredPlan
    }

    var activePlan: BillingPlan? {
        status?.activePlan
    }

    var checkoutDefaultPlan: BillingPlan {
        preferredPlan ?? .yearly
    }

    private var preferredPlanTitle: String? {
        preferredPlan?.title
    }

    private var activeSubscriptionPlan: BillingPlan? {
        activePlan ?? preferredPlan
    }

    var requiresSubscription: Bool {
        if status?.needsSubscription == true {
            return true
        }

        if hasBetaAccess && !betaMonthlyCapReached {
            return false
        }

        guard !hasActiveSubscription, let trialEndsAt = status?.trialEndsAt else {
            return false
        }

        return Date() >= trialEndsAt
    }

    var isInTrial: Bool {
        !hasActiveSubscription && !requiresSubscription
    }

    var planTitle: String {
        if hasActiveSubscription {
            if let activeSubscriptionPlan {
                return "Voiyce \(activeSubscriptionPlan.title)"
            }

            return "Voiyce Pro"
        }

        if hasBetaAccess {
            return betaMonthlyCapReached ? "Beta Cap Reached" : "Voiyce Beta"
        }

        if requiresSubscription {
            return "Trial Ended"
        }

        return "Pro Trial"
    }

    var planSubtitle: String {
        if hasActiveSubscription {
            if let activeSubscriptionPlan, cancelAtPeriodEnd, let renewalDateLabel {
                return "\(activeSubscriptionPlan.title) is active through \(renewalDateLabel). Subscription ends at period close."
            }

            if let activeSubscriptionPlan, let renewalDateLabel {
                return "\(activeSubscriptionPlan.title) is active. Renews on \(renewalDateLabel)."
            }

            if let activeSubscriptionPlan {
                return "\(activeSubscriptionPlan.title) is active. Manage or cancel anytime from billing."
            }

            if cancelAtPeriodEnd, let renewalDateLabel {
                return "Active through \(renewalDateLabel). Subscription ends at period close."
            }

            if let renewalDateLabel {
                return "Unlimited dictation is active. Renews on \(renewalDateLabel)."
            }

            return "Unlimited dictation is active. Manage or cancel anytime from billing."
        }

        if hasBetaAccess {
            return "Beta access is active."
        }

        if requiresSubscription {
            if let preferredPlanTitle {
                return "Your \(AppConstants.trialLengthDays)-day Pro trial ended. \(preferredPlanTitle) is already saved from the website and will be preselected in checkout."
            }

            return "Your \(AppConstants.trialLengthDays)-day Pro trial ended. Choose Monthly or Yearly to keep dictating."
        }

        if let preferredPlanTitle {
            return "\(freeWordsRemaining) of \(AppConstants.freeWordLimit) trial words remaining. \(preferredPlanTitle) is saved from the website if you decide to upgrade."
        }

        return "\(freeWordsRemaining) of \(AppConstants.freeWordLimit) trial words remaining. No credit card required during trial."
    }

    var primaryActionTitle: String {
        if hasActiveSubscription {
            return "Manage Subscription"
        }

        if let preferredPlan {
            switch preferredPlan {
            case .monthly:
                return requiresSubscription ? "Choose Monthly Plan" : "View Monthly Plan"
            case .yearly:
                return requiresSubscription ? "Choose Yearly Plan" : "View Yearly Plan"
            }
        }

        if requiresSubscription {
            return "Choose Plan"
        }

        return "View Plans"
    }

    var paymentRequiredTitle: String {
        guard let preferredPlanTitle else {
            return "Choose A Plan"
        }

        return "Finish \(preferredPlanTitle)"
    }

    var paymentRequiredDetail: String {
        guard let preferredPlanTitle else {
            return "Your Pro trial has ended. Pick Monthly or Yearly to keep dictating with unlimited words."
        }

        return "Your Pro trial has ended. \(preferredPlanTitle) is already selected from the website, so you can finish checkout and keep dictating with unlimited words."
    }

    var inactiveTrialFooter: String {
        if hasBetaAccess {
            return "The promo code unlocks dictation. Rate limits may apply."
        }

        let base = "Your Pro trial ends after \(AppConstants.trialLengthDays) days or when you reach \(AppConstants.freeWordLimit) words, whichever comes first."

        guard !hasActiveSubscription, let preferredPlanTitle else {
            return base
        }

        return "\(base) \(preferredPlanTitle) is saved from the website and will be preselected if you upgrade."
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

    private func currencyDisplay(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$\(value)"
    }

    func reset() {
        status = nil
        errorMessage = nil
        infoMessage = nil
    }

    func accessState(isAuthenticated: Bool) -> AccessState {
        guard isAuthenticated else { return .signedOut }

        if requiresSubscription {
            return .paymentRequired
        }

        return .active
    }

    func refreshStatus() async {
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

    func redeemBetaAccessCode(_ code: String) async {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else {
            errorMessage = "Enter a beta code."
            return
        }

        clearMessages()

        do {
            status = try await client.database
                .rpc("redeem_beta_access_code", args: ["p_code": normalizedCode])
                .executeSingle()
            infoMessage = "Beta access unlocked."
        } catch {
            errorMessage = "That beta code is not valid."
        }
    }

    func recordWordUsage(_ wordCount: Int) async {
        guard wordCount > 0 else { return }

        do {
            status = try await client.database
                .rpc("record_word_usage", args: ["p_word_count": wordCount])
                .executeSingle()
            errorMessage = nil
        } catch {
            print("[BillingManager] Failed to record word usage: \(error.localizedDescription)")
            errorMessage = "Couldn't update your free-word count just now."
        }
    }

    func beginCheckout(plan: BillingPlan = .monthly) async {
        guard !isOpeningCheckout else { return }

        clearMessages()
        isOpeningCheckout = true
        defer { isOpeningCheckout = false }

        do {
            let response: BillingURLResponse = try await client.functions.invoke(
                "create-checkout-session",
                body: ["plan": plan.rawValue]
            )
            try openExternalURL(from: response.url)
            infoMessage = "Stripe Checkout opened in your browser."
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func openBillingPortal() async {
        guard !isOpeningPortal else { return }

        clearMessages()
        isOpeningPortal = true
        defer { isOpeningPortal = false }

        do {
            let response: BillingURLResponse = try await client.functions.invoke("create-portal-session")
            try openExternalURL(from: response.url)
            infoMessage = "Stripe billing portal opened in your browser."
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
            infoMessage = "Billing completed. Refreshing your access now."
        case "cancelled":
            infoMessage = "Checkout was cancelled."
        case "portal":
            infoMessage = "Billing portal closed. Refreshing your access now."
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
            throw InsForgeError.unknown("Billing URL is invalid.")
        }

        NSWorkspace.shared.open(url)
    }

    private func friendlyMessage(for error: Error) -> String {
        if let insforgeError = error as? InsForgeError {
            return insforgeError.localizedDescription
        }

        return error.localizedDescription
    }
}
