"use client";

import { Icon } from "@iconify/react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";

import { getInsForgeBrowserClient } from "@/lib/insforge-browser";
import {
  buildAuthHref,
  downloadUrl,
  FlowIntent,
  intentBadge,
  normalizeIntent,
  trialLengthDays,
  trialWordLimit,
} from "@/lib/voiyce-config";

function sessionUserFromResult(result: unknown): { email?: string | null } | null {
  const payload = result as {
    data?: {
      user?: { email?: string | null };
      session?: { user?: { email?: string | null } };
    };
  };

  return payload.data?.session?.user ?? payload.data?.user ?? null;
}

function planSummary(intent: FlowIntent): string {
  switch (intent) {
    case "monthly":
      return "If Voiyce fits your workflow after the trial, continue with Pro Monthly at $12/month.";
    case "yearly":
      return "If Voiyce fits your workflow after the trial, continue with Pro Yearly at $120/year.";
    case "download":
      return "Your account is ready. Install the Mac app, sign in, and then finish the in-app setup.";
  }
}

export default function DownloadPageClient() {
  const client = getInsForgeBrowserClient();
  const router = useRouter();
  const searchParams = useSearchParams();

  const intent = normalizeIntent(searchParams.get("intent"));

  const [isCheckingSession, setIsCheckingSession] = useState(true);
  const [isSigningOut, setIsSigningOut] = useState(false);
  const [hasAutoStarted, setHasAutoStarted] = useState(false);
  const [accountEmail, setAccountEmail] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function restoreSession() {
      const result = await client.auth.getCurrentUser();
      const user = sessionUserFromResult(result);

      if (cancelled) {
        return;
      }

      if (!user) {
        router.replace(buildAuthHref(intent));
        return;
      }

      if (intent !== "download") {
        const sessionKey = `voiyce-plan-intent-saved:${intent}`;

        if (!window.sessionStorage.getItem(sessionKey)) {
          const { error } = await client.functions.invoke("save-plan-intent", {
            body: { plan: intent },
          });

          if (!error) {
            window.sessionStorage.setItem(sessionKey, "1");
          } else {
            console.error("Failed to persist plan intent", error);
          }
        }
      }

      if (cancelled) {
        return;
      }

      setAccountEmail(user.email ?? null);
      setIsCheckingSession(false);
    }

    void restoreSession();

    return () => {
      cancelled = true;
    };
  }, [client.auth, client.functions, intent, router]);

  useEffect(() => {
    if (isCheckingSession) {
      return;
    }

    const sessionKey = `voiyce-download-started:${intent}`;
    if (window.sessionStorage.getItem(sessionKey)) {
      return;
    }

    const frame = document.createElement("iframe");
    frame.style.display = "none";
    frame.src = downloadUrl;
    document.body.appendChild(frame);
    window.sessionStorage.setItem(sessionKey, "1");
    setHasAutoStarted(true);

    const cleanup = window.setTimeout(() => {
      frame.remove();
    }, 8000);

    return () => {
      window.clearTimeout(cleanup);
      frame.remove();
    };
  }, [intent, isCheckingSession]);

  async function signOut() {
    setIsSigningOut(true);

    try {
      await client.auth.signOut();
      router.replace(buildAuthHref(intent));
    } finally {
      setIsSigningOut(false);
    }
  }

  if (isCheckingSession) {
    return (
      <div className="min-h-screen bg-[#050505] text-white flex items-center justify-center px-6">
        <div className="rounded-[2rem] border border-white/10 bg-white/[0.03] px-8 py-10 text-center max-w-md w-full">
          <div className="mx-auto mb-6 h-12 w-12 rounded-full border border-white/10 border-t-white/70 animate-spin" />
          <h1 className="text-2xl font-semibold tracking-tight">Preparing your download</h1>
          <p className="mt-3 text-sm leading-relaxed text-[#9A9A9F]">
            Confirming your browser sign-in before we start the Mac installer.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#050505] text-white">
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute inset-y-0 right-0 w-1/2 bg-[radial-gradient(circle_at_top_right,rgba(168,85,247,0.16),transparent_48%)]" />
        <div className="absolute inset-0 bg-[linear-gradient(to_bottom,rgba(255,255,255,0.04)_1px,transparent_1px),linear-gradient(to_right,rgba(255,255,255,0.04)_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(circle_at_top,black_18%,transparent_76%)]" />
      </div>

      <div className="relative min-h-screen px-6 py-8 md:px-10 lg:px-14">
        <div className="mx-auto grid min-h-[calc(100vh-4rem)] max-w-7xl gap-6 lg:grid-cols-[1.1fr_0.9fr]">
          <section className="flex flex-col justify-between rounded-[2rem] border border-white/10 bg-[#09090D]/92 px-6 pb-8 pt-5 md:px-10 md:pb-10 md:pt-6">
            <div>
              <Link href="/" className="inline-flex items-center text-[#C9C9D1] transition-colors hover:text-white">
                <img
                  src="/voiyce_logo.png"
                  alt="Voiyce"
                  className="h-32 w-auto max-w-full object-contain object-left md:h-40 lg:h-48"
                />
              </Link>

              <div className="mt-3 max-w-2xl md:mt-4">
                <div className="inline-flex items-center rounded-full border border-purple-400/20 bg-purple-500/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.24em] text-purple-100">
                  Download Ready
                </div>

                <h1 className="mt-4 text-4xl font-semibold tracking-tight text-white md:mt-5 md:text-6xl">
                  Your account is ready. Install Voiyce on your Mac.
                </h1>

                <p className="mt-4 text-base leading-8 text-[#A0A0A9] md:text-lg">
                  {planSummary(intent)}
                </p>
              </div>

              <div className="mt-8 grid gap-4 md:grid-cols-2">
                {[
                  {
                    step: "01",
                    title: "Open your Downloads folder",
                    detail: "The DMG should already be downloading. If it did not start, use the button on the right to trigger it again.",
                  },
                  {
                    step: "02",
                    title: "Drag Voiyce into Applications",
                    detail: "Install the app like any other signed macOS download so the permissions prompts behave consistently.",
                  },
                  {
                    step: "03",
                    title: "Open the app and sign in again",
                    detail: "Use the same Google or email account from the website. The browser session does not automatically carry into the Mac app.",
                  },
                  {
                    step: "04",
                    title: "Finish onboarding",
                    detail: "Grant microphone, speech recognition, and accessibility, then run your first in-app dictation preview.",
                  },
                ].map((step) => (
                  <div key={step.step} className="rounded-[1.5rem] border border-white/10 bg-white/[0.03] p-5">
                    <div className="text-xs font-semibold uppercase tracking-[0.24em] text-[#72727A]">
                      Step {step.step}
                    </div>
                    <h2 className="mt-3 text-xl font-semibold text-white">{step.title}</h2>
                    <p className="mt-2 text-sm leading-7 text-[#9A9AA2]">{step.detail}</p>
                  </div>
                ))}
              </div>
            </div>

            <div className="mt-8 rounded-[1.5rem] border border-white/10 bg-white/[0.03] p-5 md:mt-10">
              <div className="flex items-center gap-3 text-[#D8D8DE]">
                <Icon icon="mdi:account-circle-outline" className="h-5 w-5 shrink-0 text-purple-200" />
                <span className="min-w-0 truncate font-medium">{accountEmail ?? "Signed in"}</span>
              </div>
              <p className="mt-3 text-sm leading-7 text-[#8E8E97]">
                {trialLengthDays}-day trial, up to {trialWordLimit.toLocaleString()} words, and no credit card required up front.
              </p>
              <div className="mt-4 border-t border-white/[0.08] pt-4">
                <button
                  type="button"
                  onClick={() => void signOut()}
                  disabled={isSigningOut}
                  className="group inline-flex w-full items-center justify-center gap-2 rounded-xl px-3 py-2.5 text-sm font-medium text-[#A8A8B3] transition-colors hover:bg-white/[0.06] hover:text-white disabled:opacity-50 sm:w-auto sm:justify-start"
                >
                  <Icon
                    icon="mdi:account-arrow-right-outline"
                    className="h-4 w-4 text-[#8B8B96] transition-colors group-hover:text-purple-200"
                  />
                  {isSigningOut ? "Signing out…" : "Sign out and use a different account"}
                </button>
              </div>
            </div>
          </section>

          <section className="flex flex-col justify-center rounded-[2rem] border border-white/10 bg-gradient-to-br from-[#13111A] via-[#101017] to-[#0B0B10] p-8 md:p-10">
            <div className="rounded-[2rem] border border-white/10 bg-black/25 p-6">
              <div className="inline-flex items-center rounded-full border border-white/10 bg-white/[0.04] px-3 py-1 text-xs font-semibold uppercase tracking-[0.24em] text-[#B7B7C0]">
                {intentBadge(intent)}
              </div>

              <h2 className="mt-6 text-3xl font-semibold tracking-tight text-white">
                Download should start automatically.
              </h2>

              <p className="mt-4 text-sm leading-7 text-[#A5A5AF]">
                {hasAutoStarted
                  ? "The installer request has already been sent from this page."
                  : "If the browser blocks the automatic request, use the manual download button below."}
              </p>

              <a
                href={downloadUrl}
                className="mt-8 flex w-full items-center justify-center gap-3 rounded-2xl bg-white px-5 py-4 text-base font-semibold text-black transition-colors hover:bg-[#E8E8EC]"
              >
                <Icon icon="mdi:apple" className="h-5 w-5" />
                Download Voiyce for Mac
              </a>

              <div className="mt-8 space-y-4 rounded-[1.5rem] border border-white/10 bg-white/[0.03] p-5">
                <div className="flex items-start gap-3">
                  <div className="mt-1 h-8 w-8 shrink-0 rounded-full bg-white/[0.06] flex items-center justify-center text-sm font-semibold text-white">
                    1
                  </div>
                  <div>
                    <h3 className="font-medium text-white">Download the DMG</h3>
                    <p className="mt-1 text-sm leading-7 text-[#9A9AA2]">
                      Safari usually places it in Downloads immediately. Chrome may show a save confirmation first.
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="mt-1 h-8 w-8 shrink-0 rounded-full bg-white/[0.06] flex items-center justify-center text-sm font-semibold text-white">
                    2
                  </div>
                  <div>
                    <h3 className="font-medium text-white">Install and open Voiyce</h3>
                    <p className="mt-1 text-sm leading-7 text-[#9A9AA2]">
                      Move it into Applications first. That keeps macOS permissions and future updates predictable.
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-3">
                  <div className="mt-1 h-8 w-8 shrink-0 rounded-full bg-white/[0.06] flex items-center justify-center text-sm font-semibold text-white">
                    3
                  </div>
                  <div>
                    <h3 className="font-medium text-white">Sign in again in the app</h3>
                    <p className="mt-1 text-sm leading-7 text-[#9A9AA2]">
                      Use the same account you just created here, then complete permissions and your first test recording inside the app.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
