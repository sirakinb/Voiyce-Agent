import Foundation
import Observation
import InsForge
import InsForgeAuth
import InsForgeCore

@MainActor
@Observable
final class AuthenticationManager {
    private let client = InsForgeClientProvider.shared

    private var hasAttemptedRestore = false

    var currentUser: User?
    var pendingVerificationEmail: String?
    var isRestoringSession = true
    var isWorking = false
    var errorMessage: String?
    var infoMessage: String?

    var isAuthenticated: Bool {
        currentUser != nil
    }

    var currentUserDisplayName: String {
        currentUser?.name ?? currentUser?.email ?? "Unknown User"
    }

    var currentUserEmail: String {
        currentUser?.email ?? ""
    }

    var accountStatusLabel: String {
        isAuthenticated ? "Signed In" : "Signed Out"
    }

    var currentUserInitials: String {
        let source = currentUser?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? currentUser?.email
        ?? "V"

        let parts = source
            .split(whereSeparator: { $0.isWhitespace || $0 == "@" || $0 == "." || $0 == "_" || $0 == "-" })
            .prefix(2)

        let initials = parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return initials.isEmpty ? "V" : initials
    }

    func restoreSessionIfNeeded() async {
        guard !hasAttemptedRestore else { return }
        hasAttemptedRestore = true
        if AppConstants.isUITesting {
            restoreUITestingSession()
            return
        }
        await restoreSession()
    }

    func restoreSession() async {
        if AppConstants.isUITesting {
            restoreUITestingSession()
            return
        }

        isRestoringSession = true
        defer { isRestoringSession = false }

        do {
            guard let session = try await client.auth.getSession() else {
                currentUser = nil
                return
            }

            currentUser = session.user

            do {
                currentUser = try await client.auth.getCurrentUser()
            } catch let error as InsForgeError {
                if shouldInvalidateSession(for: error) {
                    try? await client.auth.signOut()
                    currentUser = nil
                } else {
                    currentUser = session.user
                }
            } catch {
                currentUser = session.user
            }
        } catch {
            currentUser = nil
        }
    }

    func signIn(email: String, password: String) async {
        let normalizedEmail = normalized(email)
        clearFeedback()
        isWorking = true
        defer { isWorking = false }

        do {
            let response = try await client.auth.signIn(email: normalizedEmail, password: password)
            currentUser = response.user
            pendingVerificationEmail = nil
        } catch let error as InsForgeError {
            if requiresEmailVerification(error) {
                beginVerification(
                    for: normalizedEmail,
                    message: "Enter the 6-digit verification code sent to \(normalizedEmail)."
                )
                return
            }

            errorMessage = friendlyMessage(for: error)
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func signUp(email: String, password: String, name: String?) async {
        let normalizedEmail = normalized(email)
        clearFeedback()
        isWorking = true
        defer { isWorking = false }

        do {
            let response = try await client.auth.signUp(
                email: normalizedEmail,
                password: password,
                name: cleaned(name)
            )

            if response.needsEmailVerification {
                beginVerification(
                    for: normalizedEmail,
                    message: "We sent a 6-digit verification code to \(normalizedEmail)."
                )
                return
            }

            currentUser = response.user
            pendingVerificationEmail = nil
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func verifyEmail(code: String) async {
        guard let pendingVerificationEmail else { return }

        clearFeedback()
        isWorking = true
        defer { isWorking = false }

        do {
            let response = try await client.auth.verifyEmail(
                email: pendingVerificationEmail,
                otp: code.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            currentUser = response.user
            self.pendingVerificationEmail = nil
            infoMessage = nil
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func resendVerificationCode() async {
        guard let pendingVerificationEmail else { return }

        clearFeedback()
        isWorking = true
        defer { isWorking = false }

        do {
            try await client.auth.sendEmailVerification(email: pendingVerificationEmail)
            infoMessage = "A new verification code was sent to \(pendingVerificationEmail)."
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func cancelEmailVerification() {
        pendingVerificationEmail = nil
        infoMessage = nil
        errorMessage = nil
    }

    func signInWithGoogle() async {
        clearFeedback()
        isWorking = true
        defer { isWorking = false }

        do {
            let response = try await client.auth.signInWithOAuthView(
                provider: .google,
                redirectTo: AppConstants.insForgeRedirectURL.absoluteString
            )

            if let response {
                currentUser = response.user
                pendingVerificationEmail = nil
                infoMessage = nil
            } else {
                infoMessage = "Continue in your browser to finish signing in with Google."
            }
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func handleAuthCallback(_ url: URL) async {
        guard url.scheme?.lowercased() == AppConstants.insForgeRedirectScheme else { return }

        clearFeedback()
        isWorking = true
        defer { isWorking = false }

        do {
            let response = try await client.auth.handleAuthCallback(url)
            currentUser = response.user
            pendingVerificationEmail = nil
            infoMessage = nil
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func signOut() async {
        if AppConstants.isUITesting {
            currentUser = nil
            return
        }

        clearFeedback()
        isWorking = true
        defer { isWorking = false }

        do {
            try await client.auth.signOut()
            currentUser = nil
            pendingVerificationEmail = nil
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func beginVerification(for email: String, message: String) {
        pendingVerificationEmail = email
        currentUser = nil
        errorMessage = nil
        infoMessage = message
    }

    private func restoreUITestingSession() {
        isRestoringSession = false
        if AppConstants.uiTestingForcesSignedOut {
            currentUser = nil
            pendingVerificationEmail = nil
            errorMessage = nil
            infoMessage = nil
            return
        }

        currentUser = User(
            id: "ui-test-user",
            email: "ui-test@voiyce.local",
            emailVerified: true,
            profile: UserProfile(name: "Voiyce Test User")
        )
        pendingVerificationEmail = nil
        errorMessage = nil
        infoMessage = nil
    }

    private func clearFeedback() {
        errorMessage = nil
        if pendingVerificationEmail == nil {
            infoMessage = nil
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func requiresEmailVerification(_ error: InsForgeError) -> Bool {
        guard case let .httpError(statusCode, message, _, nextActions) = error else {
            return false
        }

        guard statusCode == 403 else { return false }
        let combinedMessage = "\(message) \(nextActions ?? "")".lowercased()
        return combinedMessage.contains("verify") && combinedMessage.contains("email")
    }

    private func shouldInvalidateSession(for error: InsForgeError) -> Bool {
        switch error {
        case .authenticationRequired, .unauthorized:
            return true
        case let .httpError(statusCode, message, apiError, _):
            let combinedMessage = [
                message.lowercased(),
                apiError?.lowercased()
            ]
                .compactMap { $0 }
                .joined(separator: " ")

            return statusCode == 401
                || combinedMessage.contains("auth_unauthorized")
                || combinedMessage.contains("invalid token")
        default:
            return false
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        AuthenticationRecoveryCopy.message(for: error)
    }
}

enum AuthenticationRecoveryCopy {
    static let generic = "Voiyce could not complete sign-in. Check your connection and try again."
    static let configurationMissing = "Sign-in is not configured for this build. Contact support if this should be available."
    static let invalidCredentials = "Invalid email or password."
    static let signInRequired = "Sign in to continue."

    static func message(for error: Error) -> String {
        guard let error = error as? InsForgeError else {
            if let urlError = error as? URLError,
               urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                return "Voiyce could not reach sign-in. Check your internet connection, then try again."
            }
            return generic
        }

        switch error {
        case .unauthorized:
            return invalidCredentials
        case .authenticationRequired:
            return signInRequired
        case .validationError(let message):
            return sanitized(message, fallback: "Check your email and password, then try again.")
        case .networkError:
            return "Voiyce could not reach sign-in. Check your internet connection, then try again."
        case .httpError(let statusCode, let message, _, let nextActions):
            if statusCode == 401 || statusCode == 403 {
                return invalidCredentials
            }
            let combined = [message, nextActions].compactMap { $0 }.joined(separator: " ")
            return sanitized(combined, fallback: generic)
        case .missingConfiguration:
            return configurationMissing
        case .invalidURL, .invalidResponse, .decodingError, .encodingError, .unknown:
            return generic
        case .notFound:
            return "That sign-in route is unavailable. Try again, then contact support if it keeps happening."
        case .conflict(let message):
            return sanitized(message, fallback: "That account state could not be updated. Try again, then contact support if it keeps happening.")
        }
    }

    private static func sanitized(_ message: String, fallback: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        let forbiddenTerms = [
            "HTTP", "backend", "server", "API", "token", "secret", "key",
            "OPENAI", "INSFORGE", "function", "database", "SQL"
        ]
        if forbiddenTerms.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
            return fallback
        }

        return trimmed
    }
}
