export type FlowIntent = "download" | "monthly" | "yearly";

const DEFAULT_INSFORGE_URL = "https://25565ha3.us-east.insforge.app";
const DEFAULT_INSFORGE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3OC0xMjM0LTU2NzgtOTBhYi1jZGVmMTIzNDU2NzgiLCJlbWFpbCI6ImFub25AaW5zZm9yZ2UuY29tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0OTU3NzZ9.TNf0vhTmcr7vDUf5v9-ovbpLT6MAIbUOWJe2PMXMACg";
const DEFAULT_DOWNLOAD_URL = "https://pub-4e78e629768e4c8fa39fdab493de9a41.r2.dev/Voiyce.dmg";

export const insforgeBaseUrl =
  process.env.NEXT_PUBLIC_INSFORGE_URL ?? DEFAULT_INSFORGE_URL;

export const insforgeAnonKey =
  process.env.NEXT_PUBLIC_INSFORGE_ANON_KEY ?? DEFAULT_INSFORGE_ANON_KEY;

export const downloadUrl =
  process.env.NEXT_PUBLIC_DOWNLOAD_URL ?? DEFAULT_DOWNLOAD_URL;

export const trialLengthDays = 7;
export const trialWordLimit = 2500;

export function normalizeIntent(value: string | null | undefined): FlowIntent {
  if (value === "monthly" || value === "yearly") {
    return value;
  }

  return "download";
}

export function buildAuthHref(intent: FlowIntent): string {
  return `/auth?intent=${intent}`;
}

export function buildDownloadHref(intent: FlowIntent): string {
  return `/download?intent=${intent}`;
}

export function intentHeadline(intent: FlowIntent): string {
  switch (intent) {
    case "monthly":
      return "You’re starting with Pro Monthly after the trial.";
    case "yearly":
      return "You’re aiming for the best-value yearly plan.";
    case "download":
      return "Create your account, then install Voiyce on your Mac.";
  }
}

export function intentSupportingCopy(intent: FlowIntent): string {
  switch (intent) {
    case "monthly":
      return "Your account still begins with a 7-day trial and up to 2,500 words. If Voiyce earns a place in your workflow, continue with Pro Monthly at $12/month.";
    case "yearly":
      return "Your account still begins with a 7-day trial and up to 2,500 words. If Voiyce earns a place in your workflow, continue with Pro Yearly at $120/year.";
    case "download":
      return "Create your account now, download the Mac app next, then sign in inside the app to finish permissions and setup.";
  }
}

export function intentBadge(intent: FlowIntent): string {
  switch (intent) {
    case "monthly":
      return "Pro Monthly";
    case "yearly":
      return "Pro Yearly";
    case "download":
      return "No card required";
  }
}
