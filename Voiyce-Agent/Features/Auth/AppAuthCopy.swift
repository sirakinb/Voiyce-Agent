import Foundation

/// User-facing auth copy for the macOS app. Wording stays aligned with the
/// voiyce.us sign-in flow: website unlocks download, app sign-in secures this Mac.
enum AppAuthCopy {
    static let signInTitle = "Welcome back"
    static let signInSubtitle =
        "Use the same Google or Pentridge account from voiyce.us. This sign-in keeps your session secure on this Mac and unlocks permissions, mic testing, and your live shortcut."

    static let verificationTitle = "Verify your email"

    static func verificationSubtitle(email: String) -> String {
        "Enter the 6-digit code we emailed to \(email)."
    }

    static let twoStepTitle = "Why sign in twice?"
    static let twoStepDetail =
        "The website unlocks your download. This app sign-in keeps your Mac session secure without depending on a browser session transfer."

    static let googleButton = "Continue with Google"
    static let signInButton = "Sign in and continue"
    static let createAccountButton = "Create account"
    static let verifyButton = "Verify and continue"
    static let emailSignInFootnote =
        "Google opens a secure browser handoff. Email sign-in happens directly in the app."
    static let emailSignUpFootnote =
        "Email sign-up uses a 6-digit verification code before the first session starts."

    static let resendCode = "Resend code"
    static let backToSignIn = "Back to sign in"

    static let noAccountPrompt = "Don't have an account?"
    static let signUpLinkTitle = "Get Voiyce at Pentridge Labs"

    static var visibleStrings: [String] {
        [
            signInTitle,
            signInSubtitle,
            verificationTitle,
            verificationSubtitle(email: "you@example.com"),
            twoStepTitle,
            twoStepDetail,
            googleButton,
            signInButton,
            createAccountButton,
            verifyButton,
            emailSignInFootnote,
            emailSignUpFootnote,
            resendCode,
            backToSignIn,
            noAccountPrompt,
            signUpLinkTitle
        ]
    }
}
