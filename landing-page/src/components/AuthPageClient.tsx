"use client";

import { Icon } from "@iconify/react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";

import { getInsForgeBrowserClient } from "@/lib/insforge-browser";
import {
  buildDownloadHref,
  buildAuthHref,
  normalizeIntent,
} from "@/lib/voiyce-config";

type AuthMode = "signIn" | "signUp";

function friendlyErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message;
  }

  return "Something went wrong. Please try again.";
}

function requiresEmailVerification(error: unknown): boolean {
  const message = friendlyErrorMessage(error).toLowerCase();
  return message.includes("verify") && message.includes("email");
}

function sessionUserFromResult(result: unknown): { email?: string | null } | null {
  const payload = result as {
    data?: {
      user?: { email?: string | null };
      session?: { user?: { email?: string | null } };
    };
  };

  return payload.data?.session?.user ?? payload.data?.user ?? null;
}

export default function AuthPageClient() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const intent = normalizeIntent(searchParams.get("intent"));
  const client = getInsForgeBrowserClient();

  const [authMode, setAuthMode] = useState<AuthMode>("signUp");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [verificationCode, setVerificationCode] = useState("");
  const [verificationEmail, setVerificationEmail] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [infoMessage, setInfoMessage] = useState<string | null>(null);
  const [isWorking, setIsWorking] = useState(false);

  const redirectHref = buildDownloadHref(intent);
  const showVerificationStep = verificationEmail !== null;

  useEffect(() => {
    let cancelled = false;

    async function restoreSession() {
      const result = await client.auth.getCurrentUser();
      const user = sessionUserFromResult(result);

      if (cancelled) {
        return;
      }

      if (user) {
        router.replace(redirectHref);
        return;
      }

    }

    void restoreSession();

    return () => {
      cancelled = true;
    };
  }, [client.auth, redirectHref, router]);

  async function beginOAuth(provider: "google") {
    setErrorMessage(null);
    setInfoMessage(null);
    setIsWorking(true);

    try {
      const redirectTo = new URL(redirectHref, window.location.origin).toString();
      await client.auth.signInWithOAuth({
        provider,
        redirectTo,
      });
    } catch (error) {
      setErrorMessage(friendlyErrorMessage(error));
      setIsWorking(false);
    }
  }

  async function submitCredentials(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrorMessage(null);
    setInfoMessage(null);
    setIsWorking(true);

    try {
      const trimmedEmail = email.trim().toLowerCase();

      if (authMode === "signUp") {
        const result = await client.auth.signUp({
          email: trimmedEmail,
          password,
          name: name.trim() || undefined,
        });

        if (result.error) {
          throw result.error;
        }

        if ((result.data as { requireEmailVerification?: boolean } | null)?.requireEmailVerification) {
          setVerificationEmail(trimmedEmail);
          setInfoMessage(`Enter the 6-digit code we sent to ${trimmedEmail}.`);
          setVerificationCode("");
          return;
        }
      } else {
        const result = await client.auth.signInWithPassword({
          email: trimmedEmail,
          password,
        });

        if (result.error) {
          throw result.error;
        }
      }

      router.push(redirectHref);
    } catch (error) {
      if (requiresEmailVerification(error)) {
        const pendingEmail = email.trim().toLowerCase();
        setVerificationEmail(pendingEmail);
        setInfoMessage(`Enter the 6-digit code we sent to ${pendingEmail}.`);
        setVerificationCode("");
      } else {
        setErrorMessage(friendlyErrorMessage(error));
      }
    } finally {
      setIsWorking(false);
    }
  }

  async function submitVerification(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!verificationEmail) {
      return;
    }

    setErrorMessage(null);
    setInfoMessage(null);
    setIsWorking(true);

    try {
      const result = await client.auth.verifyEmail({
        email: verificationEmail,
        otp: verificationCode.trim(),
      });

      if (result.error) {
        throw result.error;
      }

      router.push(redirectHref);
    } catch (error) {
      setErrorMessage(friendlyErrorMessage(error));
    } finally {
      setIsWorking(false);
    }
  }

  async function resendVerificationCode() {
    if (!verificationEmail) {
      return;
    }

    setErrorMessage(null);
    setInfoMessage(null);
    setIsWorking(true);

    try {
      const result = await client.auth.resendVerificationEmail({
        email: verificationEmail,
      });

      if (result.error) {
        throw result.error;
      }

      setInfoMessage(`We sent a fresh code to ${verificationEmail}.`);
    } catch (error) {
      setErrorMessage(friendlyErrorMessage(error));
    } finally {
      setIsWorking(false);
    }
  }

  return (
    <div className="min-h-screen bg-[#050505] text-white overflow-hidden">
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute -top-40 left-1/2 h-[36rem] w-[36rem] -translate-x-1/2 rounded-full bg-purple-500/10 blur-[140px]" />
        <div className="absolute inset-0 bg-[linear-gradient(to_bottom,rgba(255,255,255,0.04)_1px,transparent_1px),linear-gradient(to_right,rgba(255,255,255,0.04)_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(circle_at_top,black_25%,transparent_78%)]" />
      </div>

      <div className="relative flex min-h-screen items-center justify-center px-4 py-4 md:px-6 md:py-6">
        <div className="w-full max-w-[34rem]">
          <div className="mb-3 flex justify-center">
            <Link href="/" className="inline-flex items-center text-[#C9C9D1] transition-colors hover:text-white">
              <img
                src="/voiyce_logo.png"
                alt="Voiyce"
                className="block h-[168px] w-auto max-w-full object-contain md:h-[192px]"
              />
            </Link>
          </div>

          <div className="w-full rounded-[2rem] border border-white/10 bg-[#111117]/95 p-8 shadow-[0_20px_80px_-40px_rgba(0,0,0,0.9)] md:p-10">
            <div className="flex items-center justify-between gap-4">
              <div>
                <p className="text-sm font-medium uppercase tracking-[0.24em] text-[#73737D]">
                  Web Signup
                </p>
                <h2 className="mt-3 text-3xl font-semibold tracking-tight text-white">
                  {showVerificationStep ? "Verify your email" : "Create your account"}
                </h2>
              </div>
              <Link
                href={buildAuthHref(intent)}
                className="rounded-full border border-white/10 px-4 py-2 text-sm text-[#A5A5AF] transition-colors hover:border-white/20 hover:text-white"
              >
                Reset
              </Link>
            </div>

            <p className="mt-4 text-sm leading-7 text-[#90909A]">
              {showVerificationStep
                ? `Enter the 6-digit code we emailed to ${verificationEmail}.`
                : "Start with Google or email. Once you're in, we'll send you straight to the Mac installer page."}
            </p>

            {!showVerificationStep ? (
              <>
                <button
                  type="button"
                  onClick={() => void beginOAuth("google")}
                  disabled={isWorking}
                  className="mt-8 flex w-full items-center justify-center gap-3 rounded-2xl border border-white/10 bg-white/[0.04] px-5 py-4 text-base font-medium text-white transition-colors hover:bg-white/[0.08] disabled:cursor-not-allowed disabled:opacity-60"
                >
                  <Icon icon="logos:google-icon" className="h-5 w-5" />
                  Continue with Google
                </button>

                <div className="my-6 flex items-center gap-4 text-xs uppercase tracking-[0.28em] text-[#5F5F68]">
                  <div className="h-px flex-1 bg-white/10" />
                  or
                  <div className="h-px flex-1 bg-white/10" />
                </div>

                <div className="inline-flex rounded-full border border-white/10 bg-[#0C0C12] p-1">
                  <button
                    type="button"
                    onClick={() => setAuthMode("signUp")}
                    className={`rounded-full px-4 py-2 text-sm font-medium transition-colors ${
                      authMode === "signUp"
                        ? "bg-white text-black"
                        : "text-[#A2A2AA] hover:text-white"
                    }`}
                  >
                    Create account
                  </button>
                  <button
                    type="button"
                    onClick={() => setAuthMode("signIn")}
                    className={`rounded-full px-4 py-2 text-sm font-medium transition-colors ${
                      authMode === "signIn"
                        ? "bg-white text-black"
                        : "text-[#A2A2AA] hover:text-white"
                    }`}
                  >
                    Sign in
                  </button>
                </div>

                <form className="mt-6 space-y-4" onSubmit={submitCredentials}>
                  {authMode === "signUp" ? (
                    <label className="block">
                      <span className="mb-2 block text-sm font-medium text-[#CBCBD3]">
                        Full name
                      </span>
                      <input
                        type="text"
                        value={name}
                        onChange={(event) => setName(event.target.value)}
                        placeholder="Optional"
                        className="w-full rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-4 text-white outline-none transition-colors placeholder:text-[#666670] focus:border-white/20"
                      />
                    </label>
                  ) : null}

                  <label className="block">
                    <span className="mb-2 block text-sm font-medium text-[#CBCBD3]">Email</span>
                    <input
                      type="email"
                      value={email}
                      onChange={(event) => setEmail(event.target.value)}
                      placeholder="you@company.com"
                      autoComplete="email"
                      required
                      className="w-full rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-4 text-white outline-none transition-colors placeholder:text-[#666670] focus:border-white/20"
                    />
                  </label>

                  <label className="block">
                    <span className="mb-2 block text-sm font-medium text-[#CBCBD3]">Password</span>
                    <input
                      type="password"
                      value={password}
                      onChange={(event) => setPassword(event.target.value)}
                      placeholder="Minimum 6 characters"
                      autoComplete={authMode === "signUp" ? "new-password" : "current-password"}
                      required
                      minLength={6}
                      className="w-full rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-4 text-white outline-none transition-colors placeholder:text-[#666670] focus:border-white/20"
                    />
                  </label>

                  {errorMessage ? (
                    <p className="rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-100">
                      {errorMessage}
                    </p>
                  ) : null}

                  {infoMessage ? (
                    <p className="rounded-2xl border border-purple-400/20 bg-purple-500/10 px-4 py-3 text-sm text-purple-100">
                      {infoMessage}
                    </p>
                  ) : null}

                  <button
                    type="submit"
                    disabled={isWorking}
                    className="flex w-full items-center justify-center gap-3 rounded-2xl bg-white px-5 py-4 text-base font-semibold text-black transition-colors hover:bg-[#E8E8EC] disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    {isWorking ? "Working..." : authMode === "signUp" ? "Continue to download" : "Sign in and continue"}
                  </button>
                </form>
              </>
            ) : (
              <form className="mt-8 space-y-4" onSubmit={submitVerification}>
                <label className="block">
                  <span className="mb-2 block text-sm font-medium text-[#CBCBD3]">
                    6-digit code
                  </span>
                  <input
                    type="text"
                    inputMode="numeric"
                    value={verificationCode}
                    onChange={(event) => setVerificationCode(event.target.value)}
                    placeholder="123456"
                    required
                    maxLength={6}
                    className="w-full rounded-2xl border border-white/10 bg-white/[0.04] px-4 py-4 text-white outline-none transition-colors placeholder:text-[#666670] focus:border-white/20"
                  />
                </label>

                {errorMessage ? (
                  <p className="rounded-2xl border border-red-500/20 bg-red-500/10 px-4 py-3 text-sm text-red-100">
                    {errorMessage}
                  </p>
                ) : null}

                {infoMessage ? (
                  <p className="rounded-2xl border border-purple-400/20 bg-purple-500/10 px-4 py-3 text-sm text-purple-100">
                    {infoMessage}
                  </p>
                ) : null}

                <button
                  type="submit"
                  disabled={isWorking || verificationCode.trim().length < 6}
                  className="flex w-full items-center justify-center gap-3 rounded-2xl bg-white px-5 py-4 text-base font-semibold text-black transition-colors hover:bg-[#E8E8EC] disabled:cursor-not-allowed disabled:opacity-60"
                >
                  {isWorking ? "Verifying..." : "Verify and continue"}
                </button>

                <div className="flex items-center justify-between gap-4 text-sm">
                  <button
                    type="button"
                    onClick={() => void resendVerificationCode()}
                    disabled={isWorking}
                    className="text-[#C7C7D2] transition-colors hover:text-white disabled:opacity-60"
                  >
                    Resend code
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setVerificationEmail(null);
                      setVerificationCode("");
                      setInfoMessage(null);
                      setErrorMessage(null);
                    }}
                    className="text-[#8D8D97] transition-colors hover:text-white"
                  >
                    Back to sign in
                  </button>
                </div>
              </form>
            )}

            <p className="mt-8 text-xs leading-6 text-[#6F6F77]">
              By continuing, you agree to the{" "}
              <Link href="/terms" className="text-[#D8D8DE] underline decoration-white/20 underline-offset-4">
                Terms
              </Link>{" "}
              and{" "}
              <Link href="/privacy" className="text-[#D8D8DE] underline decoration-white/20 underline-offset-4">
                Privacy Policy
              </Link>
              .
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
