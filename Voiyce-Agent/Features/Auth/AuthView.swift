import AppKit
import SwiftUI

private enum AuthMode: String, CaseIterable, Identifiable {
    case signIn = "Sign In"
    case signUp = "Create Account"

    var id: String { rawValue }
}

struct AuthView: View {
    @Environment(AuthenticationManager.self) private var authenticationManager

    @State private var authMode: AuthMode = .signIn
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var verificationCode = ""
    @State private var localErrorMessage: String?

    private var isShowingVerification: Bool {
        authenticationManager.pendingVerificationEmail != nil
    }

    private var bundledLogoImage: NSImage? {
        guard let logoURL = AppConstants.bundledResourceURL(named: "voiyce_logo", fileExtension: "png") else {
            return nil
        }

        return NSImage(contentsOf: logoURL)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x09090C),
                    Color(hex: 0x111117),
                    Color(hex: 0x17131E)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let horizontalPadding = min(max(proxy.size.width * 0.04, 24), 44)
                let authWidth = min(max(proxy.size.width * 0.42, 460), 560)
                let brandHeight = max(proxy.size.height - 72, 520)

                ScrollView {
                    HStack(alignment: .top, spacing: 32) {
                        authColumn
                            .frame(width: authWidth, alignment: .leading)

                        brandColumn
                            .frame(maxWidth: .infinity, minHeight: brandHeight, alignment: .center)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 1380, maxHeight: .infinity, alignment: .top)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.black.opacity(0.18))
        }
        .onChange(of: authenticationManager.pendingVerificationEmail) { _, pendingEmail in
            if let pendingEmail {
                email = pendingEmail
                verificationCode = ""
            } else {
                verificationCode = ""
            }
        }
    }

    private var authColumn: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(isShowingVerification ? "Verify your email" : "Finish signing in on your Mac")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(
                    isShowingVerification
                    ? "Enter the 6-digit code we sent so Voiyce can continue setup on this Mac."
                    : "Use the same Google or email account you created on voiyce.com. The browser signup unlocks the download, and this sign-in unlocks permissions, mic testing, and your live shortcut."
                )
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if isShowingVerification {
                verificationCard
            } else {
                credentialsCard
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Website sign-in and app sign-in stay separate by design.", systemImage: "arrow.triangle.branch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("That extra sign-in is what lets macOS keep the app session secure on this device without depending on a browser session transfer.")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("", selection: $authMode) {
                ForEach(AuthMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            googleButton

            HStack(spacing: 10) {
                Rectangle()
                    .fill(AppTheme.ridge)
                    .frame(height: 1)

                Text("or")
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.textSecondary)

                Rectangle()
                    .fill(AppTheme.ridge)
                    .frame(height: 1)
            }

            if authMode == .signUp {
                styledField {
                    TextField("Full name (optional)", text: $fullName)
                        .textFieldStyle(.plain)
                }
            }

            styledField {
                TextField("Email", text: $email)
                    .textFieldStyle(.plain)
            }

            styledField {
                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
            }

            if authMode == .signUp {
                styledField {
                    SecureField("Confirm password", text: $confirmPassword)
                        .textFieldStyle(.plain)
                }
            }

            feedbackView

            Button(action: submitCredentials) {
                HStack(spacing: 10) {
                    if authenticationManager.isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }

                    Text(authMode == .signIn ? "Sign In to Voiyce" : "Create Account")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(authenticationManager.isWorking)

            Text(
                authMode == .signUp
                ? "Email sign-up uses a 6-digit InsForge verification code before the first session starts."
                : "Google opens a secure browser handoff. Email sign-in happens directly in the app."
            )
            .font(AppTheme.captionFont)
            .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(24)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var verificationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("We sent a 6-digit code to \(authenticationManager.pendingVerificationEmail ?? email).")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)

            styledField {
                TextField("6-digit code", text: $verificationCode)
                    .textFieldStyle(.plain)
            }

            feedbackView

            Button {
                Task {
                    await authenticationManager.verifyEmail(code: verificationCode)
                }
            } label: {
                HStack(spacing: 10) {
                    if authenticationManager.isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }

                    Text("Verify and Continue")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .foregroundStyle(.white)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(
                authenticationManager.isWorking
                || verificationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

            HStack(spacing: 14) {
                Button("Resend Code") {
                    Task {
                        await authenticationManager.resendVerificationCode()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accent)

                Button("Back to Sign In") {
                    authenticationManager.cancelEmailVerification()
                    authMode = .signIn
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.textSecondary)
            }
            .font(AppTheme.captionFont)
        }
        .padding(24)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var googleButton: some View {
        Button {
            Task {
                await authenticationManager.signInWithGoogle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))

                Text("Continue with Google")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(AppTheme.textPrimary)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(authenticationManager.isWorking)
    }

    @ViewBuilder
    private var feedbackView: some View {
        if let localErrorMessage {
            feedbackPill(localErrorMessage, color: AppTheme.destructive)
        } else if let errorMessage = authenticationManager.errorMessage {
            feedbackPill(errorMessage, color: AppTheme.destructive)
        } else if let infoMessage = authenticationManager.infoMessage {
            feedbackPill(infoMessage, color: AppTheme.accent)
        }
    }

    private func feedbackPill(_ message: String, color: Color) -> some View {
        Text(message)
            .font(AppTheme.captionFont)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var brandColumn: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 34)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }

            Circle()
                .fill(AppTheme.accent.opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: 180, y: -120)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 84)
                .offset(x: -150, y: 210)

            Group {
                if let logoImage = bundledLogoImage {
                    Image(nsImage: logoImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 640, maxHeight: 460)
                        .shadow(color: AppTheme.accent.opacity(0.32), radius: 40, y: 20)
                } else {
                    Text("Voiyce")
                        .font(.system(size: 92, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(40)
        }
    }

    private func submitCredentials() {
        localErrorMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            localErrorMessage = "Email is required."
            return
        }

        guard !password.isEmpty else {
            localErrorMessage = "Password is required."
            return
        }

        if authMode == .signUp {
            guard password == confirmPassword else {
                localErrorMessage = "Passwords do not match."
                return
            }
        }

        Task {
            if authMode == .signIn {
                await authenticationManager.signIn(email: trimmedEmail, password: password)
            } else {
                await authenticationManager.signUp(
                    email: trimmedEmail,
                    password: password,
                    name: fullName
                )
            }
        }
    }

    private func styledField<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(AppTheme.bodyFont)
            .foregroundStyle(AppTheme.textPrimary)
            .padding(13)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
